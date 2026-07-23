"""Validate, filter, deduplicate, and process Jira webhooks."""

import hashlib
import hmac
import json
import logging
import os

from http_utils import response
from idempotency import forget_webhook, register_webhook
from jira_client import (
    INCIDENT_TYPE_ID,
    BUG_TYPE_ID,
    create_incident,
    get_issue_url,
)


logger = logging.getLogger()
logger.setLevel(logging.INFO)


def verify_signature(raw_body, headers):
    """Verify that the webhook request was signed with the Jira secret."""
    secret = os.environ["JIRA_WEBHOOK_SECRET"]
    received_signature = headers.get("x-hub-signature", "")
    expected_signature = "sha256=" + hmac.new(
        secret.encode("utf-8"),
        raw_body,
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(
        expected_signature,
        received_signature,
    )


def parse_payload(raw_body):
    """Convert the webhook request body from JSON to a dictionary."""
    return json.loads(raw_body.decode("utf-8"))


def get_issue_data(payload):
    """Extract the relevant issue, project, and issue type IDs."""
    issue = payload.get("issue", {})
    fields = issue.get("fields", {})
    return {
        "id": issue.get("id"),
        "key": issue.get("key"),
        "project_id": fields.get("project", {}).get("id"),
        "type_id": fields.get("issuetype", {}).get("id"),
        "summary": fields.get("summary") or "",
    }


def log_webhook(payload, issue_data):
    """Write the issue data and complete webhook payload to CloudWatch."""
    logger.info(
        "Received webhook: event=%s issue_id=%s issue_key=%s "
        "project_id=%s type_id=%s summary=%s",
        payload.get("webhookEvent"),
        issue_data["id"],
        issue_data["key"],
        issue_data["project_id"],
        issue_data["type_id"],
        issue_data["summary"],
    )
    logger.info(
        "Webhook payload: %s",
        json.dumps(payload, ensure_ascii=False),
    )


def should_create_incident(payload, issue_data):
    """Check whether the received Jira issue should produce an Incident."""
    return (
        payload.get("webhookEvent") == "jira:issue_created"
        and issue_data["type_id"] == BUG_TYPE_ID
        and issue_data["summary"].upper().startswith("URGENT")
    )


def process_webhook(payload, headers):
    """Filter, deduplicate, and process a verified Jira webhook."""
    issue_data = get_issue_data(payload)
    log_webhook(payload, issue_data)
    if not should_create_incident(payload, issue_data):
        return response(
            200,
            "Webhook ignored",
            issueKey=issue_data["key"],
        )
    webhook_id = headers.get(
        "x-atlassian-webhook-identifier"
    )
    if not webhook_id:
        logger.warning(
            "Webhook identifier is missing for issue %s",
            issue_data["key"],
        )
        return response(
            400,
            "Webhook identifier is missing",
        )
    if not register_webhook(webhook_id):
        logger.info(
            "Duplicate webhook ignored: %s",
            webhook_id,
        )
        return response(
            200,
            "Duplicate webhook ignored",
            issueKey=issue_data["key"],
        )
    try:
        created_incident = create_incident(issue_data)
    except Exception:
        forget_webhook(webhook_id)
        logger.exception(
            "Webhook processing failed: %s",
            webhook_id,
        )
        return response(
            500,
            "Incident creation failed",
            sourceIssueKey=issue_data["key"],
        )
    return response(
        200,
        "Incident created",
        sourceIssueId=issue_data["id"],
        sourceIssueKey=issue_data["key"],
        incidentId=created_incident["id"],
        incidentKey=created_incident["key"],
        incidentUrl=get_issue_url(created_incident["key"]),
    )