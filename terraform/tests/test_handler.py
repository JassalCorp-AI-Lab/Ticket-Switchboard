"""Offline tests for the ticket handler.

Stubs boto3, so nothing touches AWS and no credentials are needed. Covers the
Bedrock Converse request/response shape, the classification fallbacks, the
cognito:groups claim parsing and the HTTP routing.

    python tests/test_handler.py

Exits non-zero if anything fails.
"""
import sys

# Importing the handler must not drop __pycache__ into the Lambda source dir -
# archive_file zips that directory as the deployment package.
sys.dont_write_bytecode = True

import json  # noqa: E402
import os  # noqa: E402
import types  # noqa: E402
from unittest import mock  # noqa: E402

HANDLER_DIR = (
    sys.argv[1]
    if len(sys.argv) > 1
    else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lambda", "handler")
)

# --- stub boto3 before importing the handler -------------------------------
fake_table = mock.MagicMock()
fake_bedrock = mock.MagicMock()

boto3 = types.ModuleType("boto3")
boto3.resource = lambda *a, **k: mock.MagicMock(Table=lambda n: fake_table)
boto3.client = lambda *a, **k: fake_bedrock
sys.modules["boto3"] = boto3

os.environ["TABLE_NAME"] = "ticket-switchboard-tickets"
sys.path.insert(0, HANDLER_DIR)
import lambda_function as h  # noqa: E402

failures = []


def check(name, cond, detail=""):
    print(("PASS  " if cond else "FAIL  ") + name + (" :: " + detail if detail and not cond else ""))
    if not cond:
        failures.append(name)


def converse_reply(text):
    return {"output": {"message": {"content": [{"text": text}]}}}


# 1. Converse response shape is parsed, values pass through
fake_bedrock.converse.return_value = converse_reply(
    '{"category":"Network","priority":"High","assigned_team":"Ops",'
    '"suggestions":["Restart VPN client","Check DNS"]}'
)
r = h.classify("VPN keeps disconnecting")
check("parses Converse output shape", r["assigned_team"] == "Ops", repr(r))
check("category passed through", r["category"] == "Network", repr(r))
check("suggestions list kept", r["suggestions"] == ["Restart VPN client", "Check DNS"], repr(r))

# 2. Converse was called with the right request shape
kwargs = fake_bedrock.converse.call_args.kwargs
check("sends messages array", kwargs["messages"][0]["role"] == "user", repr(kwargs.get("messages")))
check("content is a text block", "text" in kwargs["messages"][0]["content"][0], repr(kwargs.get("messages")))
check("sends inferenceConfig", "maxTokens" in kwargs["inferenceConfig"], repr(kwargs.get("inferenceConfig")))
check("no legacy 'body' kwarg", "body" not in kwargs, repr(list(kwargs)))

# 3. Markdown fences and chatter around the JSON are tolerated
fake_bedrock.converse.return_value = converse_reply(
    'Sure, here you go:\n```json\n{"category":"Security","priority":"Critical",'
    '"assigned_team":"Security","suggestions":["Reset credentials"]}\n```\nHope that helps!'
)
r = h.classify("I clicked a phishing link")
check("tolerates fences + prose", r["priority"] == "Critical", repr(r))

# 4. Values outside the allowed sets fall back safely
fake_bedrock.converse.return_value = converse_reply(
    '{"category":"Banana","priority":"URGENT!!","assigned_team":"Legal","suggestions":"just one"}'
)
r = h.classify("something odd")
check("invalid category -> Other", r["category"] == "Other", repr(r))
check("invalid priority -> Low", r["priority"] == "Low", repr(r))
check("invalid team -> Support", r["assigned_team"] == "Support", repr(r))
check("scalar suggestions coerced to list", r["suggestions"] == ["just one"], repr(r))

# 5. cognito:groups parsing across the shapes a REST authorizer can produce
def ev(groups, method="GET"):
    return {"httpMethod": method, "requestContext": {"authorizer": {"claims": {"cognito:groups": groups}}}}


check("groups as list", h.user_groups(ev(["it-staff"])) == ["it-staff"])
check("groups as plain string", h.user_groups(ev("it-staff")) == ["it-staff"])
check("groups as bracketed string", h.user_groups(ev("[employees it-staff]")) == ["employees", "it-staff"])
check("groups comma separated", h.user_groups(ev("employees,it-staff")) == ["employees", "it-staff"])
check("no groups claim", h.user_groups({"httpMethod": "GET"}) == [])

# 6. GET authorization
fake_table.scan.return_value = {"Items": []}
res = h.lambda_handler(ev(["employees"]), None)
check("GET without it-staff -> 403", res["statusCode"] == 403, repr(res))
res = h.lambda_handler(ev(["it-staff"]), None)
check("GET with it-staff -> 200", res["statusCode"] == 200, repr(res))
check("GET returns tickets key", "tickets" in json.loads(res["body"]), res["body"])

# 7. POST validation
res = h.lambda_handler({"httpMethod": "POST", "body": json.dumps({"name": "A"})}, None)
check("POST missing fields -> 400", res["statusCode"] == 400, repr(res))
res = h.lambda_handler({"httpMethod": "POST", "body": "not json"}, None)
check("POST bad JSON -> 400", res["statusCode"] == 400, repr(res))

# 8. OPTIONS + CORS headers
res = h.lambda_handler({"httpMethod": "OPTIONS"}, None)
check("OPTIONS -> 200", res["statusCode"] == 200, repr(res))
check("CORS header present", "Access-Control-Allow-Origin" in res["headers"], repr(res["headers"]))

# 9. Decimal encoding (DynamoDB numbers)
from decimal import Decimal  # noqa: E402

check("Decimal serialises", json.dumps({"n": Decimal("3")}, cls=h.DecimalEncoder) == '{"n": 3}')

print()
print(("ALL PASSED" if not failures else f"{len(failures)} FAILED: {failures}"))
sys.exit(1 if failures else 0)
