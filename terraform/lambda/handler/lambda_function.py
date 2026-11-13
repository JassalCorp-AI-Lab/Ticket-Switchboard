"""
Ticket Switchboard - ticket handler.

Invoked by API Gateway (Lambda proxy integration) behind a Cognito authorizer.

  POST /tickets  -> classify the issue with Amazon Bedrock (Converse API)
                    and store the ticket in DynamoDB.
  GET  /tickets  -> list every ticket (members of the it-staff group only).

All configuration comes from environment variables set by Terraform, so no
account IDs, table names or model IDs are hard-coded here.
"""

import json
import os
import re
import uuid
from datetime import datetime, timezone
from decimal import Decimal

import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "mistral.ministral-3-8b-instruct")
MAX_TOKENS = int(os.environ.get("BEDROCK_MAX_TOKENS", "500"))
TEMPERATURE = float(os.environ.get("BEDROCK_TEMPERATURE", "0.1"))
IT_STAFF_GROUP = os.environ.get("IT_STAFF_GROUP", "it-staff")
ALLOWED_ORIGIN = os.environ.get("ALLOWED_ORIGIN", "*")

dynamodb = boto3.resource("dynamodb")
bedrock = boto3.client("bedrock-runtime")
table = dynamodb.Table(TABLE_NAME)

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
}

PROMPT_TEMPLATE = """You are an IT help desk classifier. Analyze this support ticket and provide:
1. Category (one of: Hardware, Software, Network, Security, Account, Other)
2. Priority (Critical, High, Medium, Low)
3. Assigned team (one of: Support, Dev, Prod, Ops, Security)
4. 2-3 suggested resolution steps

Team assignment logic:
- Hardware, printer, monitor, keyboard issues -> Support
- Database, performance, infrastructure, metrics -> Prod
- API, code, deployment, CI/CD, build -> Dev
- Security, breach, unauthorized, malware, credentials -> Security
- Network, WiFi, VPN, DNS, connectivity -> Ops
- Other or unclear -> Support (default)

Ticket Description: {description}

Respond ONLY in JSON format (no markdown, no extra text):
{{
"category": "...",
"priority": "...",
"assigned_team": "...",
"suggestions": ["step1", "step2", "step3"]
}}"""

VALID_CATEGORIES = {"Hardware", "Software", "Network", "Security", "Account", "Other"}
VALID_PRIORITIES = {"Critical", "High", "Medium", "Low"}
VALID_TEAMS = {"Support", "Dev", "Prod", "Ops", "Security"}


class DecimalEncoder(json.JSONEncoder):
    """DynamoDB returns numbers as Decimal, which json cannot serialise."""

    def default(self, o):
        if isinstance(o, Decimal):
            return int(o) if o % 1 == 0 else float(o)
        return super().default(o)


def respond(status_code, payload):
    return {
        "statusCode": status_code,
        "headers": CORS_HEADERS,
        "body": json.dumps(payload, cls=DecimalEncoder),
    }


def user_groups(event):
    """Read cognito:groups out of the authorizer claims.

    A REST API Cognito authorizer flattens claims, so the value arrives either
    as a list, as "it-staff", or as "[employees it-staff]".
    """
    claims = (
        event.get("requestContext", {}).get("authorizer", {}).get("claims", {}) or {}
    )
    raw = claims.get("cognito:groups", [])
    if isinstance(raw, list):
        return [str(g).strip() for g in raw if str(g).strip()]
    return [g for g in re.split(r"[\s,\[\]]+", str(raw)) if g]


def extract_json(text):
    """Pull the first JSON object out of the model output."""
    text = text.strip()
    text = re.sub(r"^```(?:json)?|```$", "", text, flags=re.MULTILINE).strip()
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end == -1 or end < start:
        raise ValueError(f"No JSON object in model output: {text[:300]}")
    return json.loads(text[start : end + 1])


def classify(description):
    """Ask the configured Bedrock model to triage the ticket.

    Uses the Converse API rather than invoke_model: Converse takes the same
    request shape and returns the same response shape for every provider, so
    BEDROCK_MODEL_ID can be changed without touching this code.
    """
    response = bedrock.converse(
        modelId=MODEL_ID,
        messages=[
            {
                "role": "user",
                "content": [{"text": PROMPT_TEMPLATE.format(description=description)}],
            }
        ],
        inferenceConfig={"maxTokens": MAX_TOKENS, "temperature": TEMPERATURE},
    )
    result = extract_json(response["output"]["message"]["content"][0]["text"])

    category = str(result.get("category", "Other")).strip()
    priority = str(result.get("priority", "Low")).strip()
    team = str(result.get("assigned_team", "Support")).strip()
    suggestions = result.get("suggestions", [])
    if not isinstance(suggestions, list):
        suggestions = [str(suggestions)]

    return {
        "category": category if category in VALID_CATEGORIES else "Other",
        "priority": priority if priority in VALID_PRIORITIES else "Low",
        "assigned_team": team if team in VALID_TEAMS else "Support",
        "suggestions": [str(s) for s in suggestions][:3],
    }


def list_tickets(event):
    if IT_STAFF_GROUP not in user_groups(event):
        return respond(403, {"error": "Only IT staff can view all tickets"})

    items, kwargs = [], {}
    while True:
        page = table.scan(**kwargs)
        items.extend(page.get("Items", []))
        if "LastEvaluatedKey" not in page:
            break
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]

    items.sort(key=lambda i: str(i.get("created_at", "")), reverse=True)
    return respond(200, {"tickets": items, "count": len(items)})


def create_ticket(event):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return respond(400, {"error": "Request body is not valid JSON"})

    name = str(body.get("name", "")).strip()
    email = str(body.get("email", "")).strip()
    description = str(body.get("description", "")).strip()

    if not all([name, email, description]):
        return respond(
            400, {"error": "Missing required fields: name, email, description"}
        )

    ticket_id = str(uuid.uuid4())[:8]
    ai = classify(description)

    table.put_item(
        Item={
            "ticket_id": ticket_id,
            "name": name,
            "email": email,
            "description": description,
            "category": ai["category"],
            "priority": ai["priority"],
            "assigned_team": ai["assigned_team"],
            "suggestions": ai["suggestions"],
            "status": "Open",
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
    )

    return respond(
        201,
        {
            "ticket_id": ticket_id,
            "message": "Ticket submitted successfully",
            "category": ai["category"],
            "priority": ai["priority"],
            "assigned_team": ai["assigned_team"],
            "suggestions": ai["suggestions"],
        },
    )


def lambda_handler(event, context):
    method = (event.get("httpMethod") or "").upper()
    try:
        if method == "OPTIONS":
            return respond(200, {})
        if method == "GET":
            return list_tickets(event)
        if method == "POST":
            return create_ticket(event)
        return respond(405, {"error": f"Method {method} not allowed"})
    except Exception as exc:  # noqa: BLE001 - surface the reason to the browser
        print(f"Error: {exc}")
        return respond(500, {"error": str(exc)})
