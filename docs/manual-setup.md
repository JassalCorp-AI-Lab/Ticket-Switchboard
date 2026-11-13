# Manual setup — building Ticket Switchboard in the AWS Console

A click-by-click walkthrough of the same architecture the Terraform deploys,
for learning how the pieces fit together by hand.

Allow about 90 minutes. Everything is in **US East (N. Virginia) `us-east-1`**
— check the region selector before every step.

> **IAM note:** this guide attaches AWS managed policies to keep the click
> count down. They are broader than a production setup should use.

## Contents

1. [Before you start](#1-before-you-start)
2. [DynamoDB table](#2-dynamodb-table)
3. [SNS team topics](#3-sns-team-topics)
4. [SES sender identity](#4-ses-sender-identity)
5. [Handler Lambda](#5-handler-lambda)
6. [API Gateway](#6-api-gateway)
7. [S3 website bucket](#7-s3-website-bucket)
8. [CloudFront distribution](#8-cloudfront-distribution)
9. [Cognito user pool](#9-cognito-user-pool)
10. [Secure the API](#10-secure-the-api)
11. [Notifier Lambda](#11-notifier-lambda)
12. [Upload the front end](#12-upload-the-front-end)
13. [Test it](#13-test-it)
14. [Clean up](#14-clean-up)

Keep a notepad open. You will collect six values along the way:

| Value | Collected in |
|---|---|
| Five SNS topic ARNs | Step 3 |
| API Invoke URL | Step 6 |
| S3 website endpoint | Step 7 |
| CloudFront domain | Step 8 |
| User Pool ID, SPA Client ID, Cognito domain | Step 9 |

---

## 1. Before you start

- An AWS account with permission to create the services below.
- An email address you can open — it is verified in SES, subscribed to five
  SNS topics, and used for the test user.
- The front-end file from this repo: `terraform/frontend/index.html.tftpl`.
  Copy it to `index.html`; you will fill in its config block in step 12.

Nothing needs enabling in the Bedrock console. Serverless models are
subscribed automatically on first invocation.

---

## 2. DynamoDB table

1. Open **DynamoDB** → **Tables** → **Create table**.
2. Set:

   | Setting | Value |
   |---|---|
   | Table name | `ticket-switchboard-tickets` |
   | Partition key | `ticket_id` — type **String** |
   | Sort key | leave empty |
   | Table settings | Default (On-demand) |

3. **Create table**, wait for status **Active**.
4. Open the table → **Exports and streams** tab.
5. Under **DynamoDB stream details** click **Turn on**.
6. Choose view type **New image** → **Turn on stream**.

> **New image** is required. The notifier reads the ticket's fields from the
> stream record; the other view types do not include them.

---

## 3. SNS team topics

Create five **Standard** topics — one per team the model can assign to.

1. Open **SNS** → **Topics** → **Create topic** → type **Standard**.
2. Create each of these, leaving all other settings default:

   - `ticket-switchboard-support-team`
   - `ticket-switchboard-dev-team`
   - `ticket-switchboard-prod-team`
   - `ticket-switchboard-ops-team`
   - `ticket-switchboard-security-team`

3. For **each** topic: open it → **Create subscription** → Protocol **Email**
   → Endpoint = your email → **Create subscription**.
4. Check your inbox and click **Confirm subscription** in all five emails.
   Check spam. Status must read **Confirmed**, not *Pending confirmation*.
5. Copy all five **topic ARNs** to your notepad.

> Doing this early gives the confirmation emails time to arrive while you work
> through the rest.

---

## 4. SES sender identity

1. Open **Amazon SES** → **Configuration** → **Identities** → **Create
   identity**.
2. Choose **Email address**, enter your address, **Create identity**.
3. Click the verification link in your inbox. Status becomes **Verified**.

---

## 5. Handler Lambda

1. Open **Lambda** → **Create function** → **Author from scratch**.

   | Setting | Value |
   |---|---|
   | Function name | `ticket-switchboard-handler` |
   | Runtime | **Python 3.12** |

2. **Create function**.
3. In **Code source**, replace everything in `lambda_function.py` with the
   contents of `terraform/lambda/handler/lambda_function.py` from this repo.
   Click **Deploy**.
4. **Configuration** → **Environment variables** → **Edit** → add:

   | Key | Value |
   |---|---|
   | `TABLE_NAME` | `ticket-switchboard-tickets` |
   | `BEDROCK_MODEL_ID` | `mistral.ministral-3-8b-instruct` |
   | `BEDROCK_MAX_TOKENS` | `500` |
   | `BEDROCK_TEMPERATURE` | `0.1` |
   | `IT_STAFF_GROUP` | `it-staff` |
   | `ALLOWED_ORIGIN` | `*` |

5. **Configuration** → **General configuration** → **Edit** → set
   **Timeout** to **1 min 0 sec**. Save.

   > The 3-second default is the most common failure here. Model inference
   > regularly takes longer, and the function is killed mid-call.

6. **Configuration** → **Permissions** → click the **execution role** name.
7. In IAM: **Add permissions** → **Attach policies** → attach
   **`AmazonBedrockFullAccess`** and **`AmazonDynamoDBFullAccess`**.

---

## 6. API Gateway

1. Open **API Gateway** → **Create an API** → under **REST API** click
   **Build**.

   | Setting | Value |
   |---|---|
   | API name | `ticket-switchboard-api` |
   | API endpoint type | **Regional** |

2. **Create API**.
3. **Create resource**: Resource name `tickets` → **Create resource**.
4. Select `/tickets` → **Create method**:

   | Setting | Value |
   |---|---|
   | Method type | **POST** |
   | Integration type | **Lambda function** |
   | Lambda proxy integration | **ON** |
   | Lambda function | `ticket-switchboard-handler` |

5. **Create method**. Repeat for a **GET** method with identical settings.
6. Select `/tickets` → **Enable CORS**. Tick **GET** and **POST** (OPTIONS is
   automatic), keep `*` as the allowed origin → **Save**.
7. **Deploy API** → **New stage** → name `prod` → **Deploy**.
8. Copy the **Invoke URL** to your notepad. Your endpoint is that URL plus
   `/tickets`.

> **Leave OPTIONS unauthenticated.** Browsers send the CORS preflight with no
> `Authorization` header. Putting an authorizer on OPTIONS makes every
> cross-origin call fail.

---

## 7. S3 website bucket

1. Open **S3** → **Create bucket**. Bucket names are globally unique — use
   something like `ticket-switchboard-<your-initials>-<random-number>`.
2. Leave the defaults → **Create bucket**.
3. Open the bucket → **Permissions** → **Block public access** → **Edit** →
   untick **Block all public access** → **Save** → type `confirm`.
4. Still in **Permissions** → **Bucket policy** → **Edit** → paste, replacing
   `YOUR-BUCKET-NAME`:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "PublicReadGetObject",
         "Effect": "Allow",
         "Principal": "*",
         "Action": "s3:GetObject",
         "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
       }
     ]
   }
   ```

5. **Properties** tab → **Static website hosting** → **Edit** → **Enable**,
   index document `index.html` → **Save**.
6. Copy the **Bucket website endpoint** to your notepad. It looks like
   `your-bucket.s3-website-us-east-1.amazonaws.com`.

---

## 8. CloudFront distribution

1. Open **CloudFront** → **Create distribution**. Name it
   `ticket-switchboard-distribution`.
2. **Origin**: paste the **S3 website endpoint** from step 7.

   > Paste the website endpoint — do **not** pick the bucket from the
   > *Browse S3* list. The bucket origin serves the object listing, not
   > `index.html`.

3. Under origin settings choose **Customize**, set protocol to **HTTP only**.

   > S3 website endpoints do not serve HTTPS. Choosing *Match viewer* or
   > *HTTPS only* produces a 504 from the origin.

4. Keep the recommended cache settings and defaults through the remaining
   screens → **Create distribution**.
5. On the **General** tab → **Settings** → **Edit** → set **Default root
   object** to `index.html` → **Save**.
6. Wait 5–10 minutes for deployment. Copy the **Distribution domain name**
   (e.g. `d1example8.cloudfront.net`) to your notepad.

---

## 9. Cognito user pool

### Create the pool

1. Open **Cognito** → **User pools** → **Create user pool**.

   | Setting | Value |
   |---|---|
   | Application type | **Traditional web application** |
   | Name your application | `ticket-switchboard-app` |
   | Sign-in identifiers | **Email** and **Username** |
   | Self-registration | enabled |
   | Required attributes | `email` |

2. For **Add a return URL** enter `https://<your-cloudfront-domain>` — with
   `https://` and **no trailing slash**.
3. **Create user directory**.
4. Open **Overview** and copy the **User pool ID** to your notepad.

### Create the groups

5. **User management** → **Groups** → **Create group** → name `employees`.
6. **Create group** again → name `it-staff`.

> Spelling matters. The handler checks for the exact string `it-staff`.

### Create the SPA app client

7. **Applications** → **App clients** → **Create app client**.

   | Setting | Value |
   |---|---|
   | Application type | **Single-page application (SPA)** |
   | Name | `ticket-switchboard-web` |
   | Return URL | `https://<your-cloudfront-domain>` |

8. **Create app client**, then copy its **Client ID** to your notepad. This
   is the one the browser uses — an SPA client has no secret.
9. Open the client's **Login pages** tab → **Edit**. Confirm the callback URL,
   add the same URL under **Allowed sign-out URLs**, and verify:
   - Identity providers: **Cognito user pool**
   - OAuth 2.0 grant types: **Authorization code grant**
   - OpenID Connect scopes: **email**, **openid**, **phone**

   Save.

### Managed login branding and domain

10. **Branding** → **Managed login** → **Create a style** → select the
    `ticket-switchboard-web` client → **Create**. Keep the defaults.

    > Without a style assigned, the hosted login pages do not render.

11. **Branding** → **Domain**. Copy the Cognito domain to your notepad
    (`https://<prefix>.auth.us-east-1.amazoncognito.com`).

### Create a test user

12. **User management** → **Users** → **Create user**.

    | Setting | Value |
    |---|---|
    | Invitation message | **Don't send an invitation** |
    | User name | `testemployee` |
    | Email address | your email |
    | Mark email as verified | ticked |
    | Temporary password | set one — 8+ chars, upper, lower, number, symbol |

13. Open the user → **Group memberships** → **Add user to group** →
    **`it-staff`** → **Add**.

> `it-staff` can both submit tickets and list all of them. `employees` can
> only submit.

---

## 10. Secure the API

1. Back in **API Gateway**, open `ticket-switchboard-api`.
2. **Authorizers** → **Create an authorizer**:

   | Setting | Value |
   |---|---|
   | Name | `ticket-switchboard-api-cognito` |
   | Type | **Cognito** |
   | Cognito user pool | your pool |
   | Token source | `Authorization` |

3. **Create authorizer**.
4. **Resources** → `/tickets` → **POST** → **Method request** → **Edit** →
   set **Authorization** to your authorizer → **Save**.
5. Repeat for **GET**. Leave **OPTIONS** on *None*.
6. **Deploy API** → select the existing **prod** stage → **Deploy**.

> **The redeploy is required.** Authorization changes do not take effect on a
> stage until it is deployed again. Skipping this is the usual cause of calls
> still succeeding without a token.

---

## 11. Notifier Lambda

1. **Lambda** → **Create function** → **Author from scratch**.

   | Setting | Value |
   |---|---|
   | Function name | `ticket-switchboard-notifier` |
   | Runtime | **Python 3.12** |

2. Replace `lambda_function.py` with the contents of
   `terraform/lambda/notifier/lambda_function.py`. **Deploy**.
3. **Configuration** → **Environment variables** → add:

   | Key | Value |
   |---|---|
   | `DEFAULT_TEAM` | `Support` |
   | `TEAM_TOPICS` | the JSON below, on one line, with your ARNs |

   ```json
   {"Support":"arn:aws:sns:us-east-1:<account-id>:ticket-switchboard-support-team","Dev":"arn:aws:sns:us-east-1:<account-id>:ticket-switchboard-dev-team","Prod":"arn:aws:sns:us-east-1:<account-id>:ticket-switchboard-prod-team","Ops":"arn:aws:sns:us-east-1:<account-id>:ticket-switchboard-ops-team","Security":"arn:aws:sns:us-east-1:<account-id>:ticket-switchboard-security-team"}
   ```

4. **Configuration** → **Permissions** → open the execution role → attach
   **`AmazonDynamoDBFullAccess`** and **`AmazonSNSFullAccess`**.

   > DynamoDB access is needed to *read the stream*, not the table.

5. Back on the function page → **Add trigger**:

   | Setting | Value |
   |---|---|
   | Source | **DynamoDB** |
   | Table | `ticket-switchboard-tickets` |
   | Batch size | `1` |
   | Starting position | **Latest** |
   | Activate trigger | ticked |

6. **Add**.

---

## 12. Upload the front end

1. Open your copy of `index.html` and fill in the `CONFIG` block near the top
   of the `<script>` section:

   ```js
   const CONFIG = {
     API_ENDPOINT:   'https://xxxx.execute-api.us-east-1.amazonaws.com/prod/tickets',
     USER_POOL_ID:   'us-east-1_XXXXXXXXX',
     CLIENT_ID:      '<ticket-switchboard-web client id>',
     COGNITO_DOMAIN: 'https://<prefix>.auth.us-east-1.amazoncognito.com',
     REDIRECT_URI:   'https://<your-cloudfront-domain>'
   };
   ```

   The file also contains `${app_name}` placeholders. Replace them with a
   title of your choice, e.g. `Ticket Switchboard` (`${app_name_lead}` =
   `Ticket`, `${app_name_tail}` = `Switchboard`), and
   `${handler_function_name}` with `ticket-switchboard-handler`.

   > `REDIRECT_URI` must match the Cognito callback URL **exactly** —
   > `https://`, no trailing slash. A mismatch gives `redirect_mismatch` at
   > login.

2. Go to **S3** → your bucket → **Upload** → add `index.html` → **Upload**.

---

## 13. Test it

1. Open `https://<your-cloudfront-domain>` in a browser.
2. Click **Login with Cognito**, sign in as `testemployee` with the temporary
   password, and set a permanent one when prompted.
3. Fill in the form and submit, e.g. *"VPN keeps disconnecting every 10
   minutes"*.
4. Within a few seconds the banner confirms the ticket, its category,
   priority and assigned team.
5. Check your inbox for the alert from the assigned team's topic.
6. Click **View All Tickets** — visible because the user is in `it-staff`.

Try a few more to see the routing: *"Production database CPU is at 100%"*
→ Prod, *"CI/CD build fails after merging my PR"* → Dev, *"I received a
phishing email and clicked the link"* → Security / Critical.

### If something fails

| Symptom | Likely cause |
|---|---|
| Ticket submit times out | Handler timeout still 3s — step 5.5 |
| `AccessDeniedException` | Bedrock policy missing, or model not in this region |
| CORS error in the console | CORS not enabled, or API not redeployed after step 10 |
| 401 Unauthorized | Stage not redeployed after adding the authorizer |
| `redirect_mismatch` at login | `REDIRECT_URI` ≠ Cognito callback URL |
| CloudFront 504 | Origin protocol is not **HTTP only** — step 8.3 |
| No email arrives | SNS subscriptions still *Pending confirmation* |

---

## 14. Clean up

Delete in this order to avoid dependency errors:

1. **CloudFront** → select the distribution → **Disable**, wait for it to
   finish, then **Delete**. This takes 10–15 minutes.
2. **S3** → empty the bucket, then delete it.
3. **API Gateway** → delete `ticket-switchboard-api`.
4. **Lambda** → delete both functions. Optionally delete their execution
   roles in IAM.
5. **DynamoDB** → delete `ticket-switchboard-tickets`.
6. **Cognito** → delete the user pool (tick the prerequisites to remove the
   domain and deactivate deletion protection).
7. **SNS** → delete all five topics. This removes their subscriptions.
8. **SES** → delete the email identity.

> Leaving a CloudFront distribution enabled accrues request charges over
> time. It is the one resource worth double-checking.
