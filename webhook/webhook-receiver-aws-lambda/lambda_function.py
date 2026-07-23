"""Provide the AWS Lambda entry point for Jira webhook processing."""

import json
import logging

from http_utils import get_request_data, handle_http_method, response
from webhook import parse_payload, process_webhook, verify_signature


logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, _context):
    """Receive, validate, and process a Jira webhook request."""
    method_response = handle_http_method(event)
    if method_response:
        return method_response
    headers, raw_body = get_request_data(event)
    if not verify_signature(raw_body, headers):
        logger.warning("Webhook signature validation failed")
        return response(401, "Invalid signature")
    try:
        payload = parse_payload(raw_body)
    except (json.JSONDecodeError, UnicodeDecodeError):
        logger.warning("Webhook contains invalid JSON")
        return response(400, "Invalid JSON")
    return process_webhook(payload, headers)
