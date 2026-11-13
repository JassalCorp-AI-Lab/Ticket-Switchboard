"""
Ticket Switchboard - stream notifier.

Triggered by the DynamoDB stream on the tickets table. For every INSERT it
looks up the SNS topic of the team the model assigned and publishes an alert.

The team -> topic ARN map is injected by Terraform as the TEAM_TOPICS
environment variable (a JSON object), so no account ID is hard-coded here.
"""

import json
import os

import boto3

sns = boto3.client("sns")

TEAM_TOPICS = json.loads(os.environ["TEAM_TOPICS"])
DEFAULT_TEAM = os.environ.get("DEFAULT_TEAM", "Support")

MESSAGE_TEMPLATE = """New Support Ticket Alert

Ticket ID: {ticket_id}
Submitter: {name}
Priority: {priority}
Category: {category}
Assigned Team: {assigned_team}

Description:
{description}

Log in to the dashboard to view suggested resolutions."""


def attr(image, key, default=""):
    return image.get(key, {}).get("S", default)


def lambda_handler(event, context):
    sent = 0
    for record in event.get("Records", []):
        if record.get("eventName") != "INSERT":
            continue

        data = record["dynamodb"]
        image = data.get("NewImage", {})

        ticket_id = data["Keys"]["ticket_id"]["S"]
        assigned_team = attr(image, "assigned_team", DEFAULT_TEAM)
        topic_arn = TEAM_TOPICS.get(assigned_team, TEAM_TOPICS[DEFAULT_TEAM])

        priority = attr(image, "priority", "Low")
        category = attr(image, "category", "Unknown")

        sns.publish(
            TopicArn=topic_arn,
            Subject=f"[{priority}] New {category} Ticket: {ticket_id}"[:100],
            Message=MESSAGE_TEMPLATE.format(
                ticket_id=ticket_id,
                name=attr(image, "name", "Unknown"),
                priority=priority,
                category=category,
                assigned_team=assigned_team,
                description=attr(image, "description"),
            ),
        )
        sent += 1
        print(f"Notification sent to {assigned_team} team for ticket {ticket_id}")

    return {"statusCode": 200, "body": json.dumps({"notifications_sent": sent})}
