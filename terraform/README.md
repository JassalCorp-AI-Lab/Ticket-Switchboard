# Ticket Switchboard — Terraform deployment

Deploys the whole **AI-Powered IT Help Desk Ticketing System** from the lab
guide with `terraform plan` / `terraform apply`. Everything the lab asks you to
click through in the console is defined here instead: DynamoDB, two Lambda
functions, API Gateway, S3 + CloudFront, Cognito, SNS and SES.

---

## 1. Prerequisites

| | |
|---|---|
| Terraform | >= 1.6 |
| AWS CLI | configured with credentials (`aws configure`) |
| AWS permissions | administrator-level, or enough to create the services below |
| Region | `us-east-1` by default |
| An inbox you can open | for SES verification, 5 SNS confirmations and the test user |

Nothing to do in the Bedrock console — serverless models are enabled on first
invocation. See [§9](#9-choosing-a-model) to use a different model.

---

## 2. Deploy

```bash
cd project/terraform

cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: notification_email + test_user_password

terraform init
terraform plan
terraform apply
```

Roughly 5–8 minutes, most of it CloudFront.

Prefer not to keep the password in a file:

```bash
export TF_VAR_notification_email="you@example.com"
export TF_VAR_test_user_password='ChangeMe#2026'
terraform apply
```

### After apply

`terraform output next_steps` prints the checklist. In short:

1. **Confirm the emails.** AWS sends five *"AWS Notification — Subscription
   Confirmation"* messages (one per team topic) plus an SES verification mail.
   Click every link, spam folder included. Until you do, tickets are classified
   and stored but no notification email arrives.
2. **Open the app.** `terraform output app_url` → click *Login with Cognito* →
   sign in as `testemployee` with the temporary password you set. Cognito asks
   for a permanent password at first sign-in.
3. **Submit a ticket**, e.g. *"VPN keeps disconnecting every 10 minutes"*.

If the page 404s immediately after apply, CloudFront is still propagating —
wait a few minutes and reload.

---

## 3. Layout

```
project/terraform/
├── main.tf                  module wiring
├── web_app.tf               renders index.html and uploads it to S3
├── variables.tf             inputs
├── outputs.tf               URLs, IDs, post-apply checklist
├── providers.tf             provider + default_tags
├── versions.tf              version pins
├── terraform.tfvars.example copy to terraform.tfvars
├── frontend/
│   └── index.html.tftpl     the lab's index.html, config values templated
├── lambda/
│   ├── handler/             POST/GET /tickets — Bedrock + DynamoDB
│   └── notifier/            DynamoDB stream → SNS
├── tests/
│   └── test_handler.py      offline handler tests — `python tests/test_handler.py`
└── modules/
    ├── dynamodb/            tickets table + NEW_IMAGE stream
    ├── lambda/              reusable Python Lambda (role, policy, logs, zip)
    ├── api_gateway/         REST API, Cognito authorizer, CORS, prod stage
    ├── cognito/             user pool, managed login, 2 clients, groups, user
    ├── notifications/       5 SNS team topics + SES identity
    └── frontend/            S3 website bucket + CloudFront distribution
```

The Lambda zips are built at plan time by `archive_file` — no build step, and
editing a `.py` file is enough for the next `apply` to redeploy it.

### Why the page upload lives in the root module

Cognito needs the CloudFront URL as its OAuth callback, and `index.html` needs
the Cognito *and* API Gateway values. Putting the upload inside
`modules/frontend` would make `frontend` and `cognito` depend on each other,
which Terraform rejects as a cycle. So `web_app.tf` renders and uploads the
page from the root module, after all three modules exist.

---

## 4. Inputs

| Variable | Default | Notes |
|---|---|---|
| `notification_email` | *(required)* | SES identity, SNS subscriptions, test user |
| `test_user_password` | *(required)* | 8+ chars, upper + lower + digit + symbol |
| `aws_region` | `us-east-1` | |
| `project_name` | `ticket-switchboard` | lowercase DNS-safe prefix for every resource, max 24 chars |
| `app_display_name` | `Ticket Switchboard` | title in the web UI and sender name on notification emails |
| `bedrock_model_id` | `mistral.ministral-3-8b-instruct` | any Converse-capable model — see §9 |
| `bedrock_max_tokens` | `500` | cap on the classifier's output |
| `bedrock_temperature` | `0.1` | low keeps the JSON classification stable |
| `api_stage_name` | `prod` | |
| `bucket_name` | *(generated)* | `ticket-switchboard-lab-<account>-<region>-<suffix>` |
| `cognito_domain_prefix` | *(generated)* | `ticket-switchboard-<suffix>` |
| `test_user_name` | `testemployee` | |
| `test_user_group` | `it-staff` | `it-staff` may also list all tickets |
| `create_test_user` | `true` | |
| `verify_ses_identity` | `true` | |
| `log_retention_days` | `7` | |
| `cloudfront_price_class` | `PriceClass_100` | cheapest |
| `tags` | project/lab/managed-by | applied through `default_tags` |

Useful outputs: `app_url`, `api_tickets_endpoint`, `cognito_user_pool_id`,
`cognito_spa_client_id`, `cognito_domain`, `hosted_ui_login_url`,
`team_topic_arns`, `next_steps`.

---

## 5. Where this differs from the lab guide

All deliberate; the behaviour the lab describes is unchanged.

| Lab | Here | Why |
|---|---|---|
| `invoke_model` with a provider-specific body, parsing `outputs[0].text` | The **Converse API** with `mistral.ministral-3-8b-instruct` | The guide's model is Legacy and unusable in new accounts; Converse uses one shape for every provider, so the model ID becomes swappable without a code change (§9) |
| `AmazonBedrockFullAccess`, `AmazonDynamoDBFullAccess`, `AmazonSNSFullAccess` on the roles | Inline policies scoped to this table, stream, topics and model | Same operations, least privilege |
| Account IDs and table names hard-coded in the Lambda source | Passed as environment variables | No editing the code per account |
| Handler's `GET /tickets` validates the POST body first, then returns 403/nothing | `GET` scans the table and returns `{"tickets": [...]}` for `it-staff` | As written, the lab's GET always fails on the body check and never returns tickets — the front end's *View all tickets* button needs a real list |
| `cognito:groups` checked with `'it-staff' not in user_groups` | Claim parsed whether it arrives as a list, `it-staff`, or `[employees it-staff]` | REST API authorizers flatten the claim to a string |
| CloudFront **Free plan** via the console wizard | Standard distribution, `PriceClass_100` | The flat-rate plan is a console-only flow; cost is still ~$0 at lab volume |
| CORS headers on 2xx only | Also on gateway 4XX/5XX responses | A 401 from the authorizer otherwise reaches the browser as an opaque CORS error |
| Index document only | `index.html` also set as the error document | Returns the SPA instead of S3's XML error page |

The S3 bucket is public-read behind CloudFront, exactly as the lab specifies,
because the origin is the S3 *website* endpoint. For anything beyond a lab,
switch to a REST origin with Origin Access Control and drop the public policy.

---

## 6. Clean up

```bash
terraform destroy
```

Replaces the lab's entire manual teardown section. A few notes:

- The S3 bucket is created with `force_destroy = true`, so `destroy` empties it
  first. Set `force_destroy_bucket = false` in `modules/frontend` if you would
  rather it refuse to delete a non-empty bucket.
- Cognito `deletion_protection` is `INACTIVE` so the pool deletes without a
  console step.
- CloudFront is disabled and then deleted, which AWS can take 10–15 minutes to
  complete. That is normal — let it finish.
- `destroy` does not delete CloudWatch log data beyond the two log groups it
  owns. There is no Bedrock model access to revoke — nothing is billed for a
  model you are not invoking.

---

## 7. Troubleshooting

**`AccessDeniedException` / `ValidationException` from Bedrock**
Since October 2025 this is almost never a missing access request — serverless
models are enabled on first invocation. The likely causes, in order:

1. **You set `bedrock_model_id` to a Legacy model** — new accounts cannot
   invoke those at all. Check its lifecycle status (§9).
2. The model is not offered in `aws_region`, or needs a cross-region inference
   profile (`us.`-prefixed) rather than a bare model ID.
3. You are within the ~2 minutes AWS allows for the first-invocation
   subscription to complete. Retry.
4. The role lacks `bedrock:InvokeModel` for that ARN — if you changed
   `bedrock_model_id`, the scoped policy in `main.tf` follows the variable, so
   re-run `apply` rather than editing the model ID only in the console.

**No notification email**
The SNS subscriptions are still *Pending confirmation*. Check the inbox and
spam folder for the five confirmation mails. `terraform output team_topic_arns`
tells you which topics exist.

**401 Unauthorized from the API**
The ID token expired — sign out and back in. If it happens immediately after
changing the authorizer, re-run `apply`; the deployment's `triggers` block
normally handles the redeploy for you.

**`redirect_mismatch` on the Cognito login page**
`REDIRECT_URI` in the served `index.html` must match the callback URL on the
app client exactly, including `https://` and no trailing slash. Both come from
the same Terraform output, so this usually means a stale cached page — the
apply issues a CloudFront invalidation, but you can force one with
`aws cloudfront create-invalidation --distribution-id $(terraform output -raw cloudfront_distribution_id) --paths "/*"`.

**Bucket or Cognito domain name already taken**
Both are globally unique. Set `bucket_name` and/or `cognito_domain_prefix`
explicitly, or `terraform taint random_string.suffix` for a new suffix.

---

## 8. Cost

Same as the lab: roughly **$0.00 – $0.50** for a 2–3 hour session, almost all
of it Bedrock inference at a fraction of a cent per ticket. Everything else sits
inside the free tier. Run `terraform destroy` when you are done — a CloudFront
distribution left enabled accrues request charges over time.

---

## 9. Choosing a model

The handler calls Bedrock through the **Converse API**, which uses one request
and response shape for every provider. So switching models is a one-line change
plus an `apply` — no code edit:

```hcl
# terraform.tfvars
bedrock_model_id = "<model-id>"
```

The IAM policy is scoped to whatever `bedrock_model_id` is set to, so always
change it here rather than in the Lambda console.

### Avoid Legacy models

Check the lifecycle status before you pick anything. AWS's
[model lifecycle page](https://docs.aws.amazon.com/bedrock/latest/userguide/model-lifecycle-legacy.html)
states:

> New customers can't use Legacy models and existing customers may lose access
> to Legacy models after 15 days of inactivity.

So a Legacy model will simply fail to invoke in a fresh account, whatever your
IAM policy says. Legacy Mistral IDs at the time of writing include
`mistral.mixtral-8x7b-instruct-v0:1`, `mistral.devstral-2-123b`,
`mistral.voxtral-mini-3b-2507` and `mistral.voxtral-small-24b-2507` — the AWS
page above is the authoritative, current list.

### The default

`mistral.ministral-3-8b-instruct` — **Ministral 3 8B**. A small, fast, cheap
instruct model, which is all a classifier prompt needs. Per its
[model card](https://docs.aws.amazon.com/bedrock/latest/userguide/model-card-mistral-ai-ministral-3-8b.html)
it is lifecycle **Active**, launched 2 December 2025 with "EOL no sooner than"
2 December 2026, supports Converse, and is available in `us-east-1` for direct
in-region access — so a plain model ID works, with no `us.` inference profile.

### Alternatives

All verified Active, Converse-capable and available in `us-east-1` on a plain
model ID:

| Model | ID | When to use |
|---|---|---|
| Ministral 3 8B | `mistral.ministral-3-8b-instruct` | **Default.** Cheapest and fastest; ample for classification |
| Mistral Small | `mistral.mistral-small-2402-v1:0` | Slightly stronger reasoning, 32K context |
| Mistral Large 3 | `mistral.mistral-large-3-675b-instruct` | 256K context; far more than this workload needs, and much pricier |

You are not limited to Mistral — because of Converse, any Bedrock model that
supports it will work, including the Amazon Nova and Anthropic Claude families.
Two things to check first: that the model is offered in your `aws_region`, and
whether it needs a cross-region inference profile ID (prefixed `us.`) rather
than a bare model ID. Anthropic models before Claude Opus 4.7 also need a
one-time First Time Use form.

Confirm what your account can actually see:

```bash
aws bedrock list-foundation-models --region us-east-1 \
  --query "modelSummaries[?contains(modelId,'mistral')].[modelId,modelLifecycle.status]" \
  --output table
```

### Tuning

`bedrock_max_tokens` (default 500) and `bedrock_temperature` (default 0.1) are
exposed as variables. Temperature is deliberately low: the prompt asks for a
strict JSON object, and sampling randomness mostly produces malformed output
rather than better triage.

Whichever model you pick, the prompt and its JSON contract (`category`,
`priority`, `assigned_team`, `suggestions`) are model-agnostic —
`extract_json()` tolerates markdown fences and surrounding prose, and the
handler validates every returned value against the allowed sets before writing
to DynamoDB.
