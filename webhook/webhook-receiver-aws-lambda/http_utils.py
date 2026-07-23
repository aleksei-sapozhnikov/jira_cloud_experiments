"""Handle HTTP requests and responses for the Lambda Function URL."""

import base64
import json


def response(status_code, message, **data):
    """Build a JSON response for the Lambda Function URL."""
    return {
        "statusCode": status_code,
        "headers": {
            "content-type": "application/json",
        },
        "body": json.dumps({
            "message": message,
            **data,
        }),
    }


def handle_http_method(event):
    """Return a default response for GET and unsupported HTTP methods."""
    method = (
        event.get("requestContext", {})
        .get("http", {})
        .get("method", "")
    )
    if method == "GET":
        return response(
            200,
            "Jira webhook receiver is running",
        )
    if method != "POST":
        return response(
            405,
            "Method not allowed",
        )
    return None


def get_request_data(event):
    """Extract normalized headers and the original request body."""
    headers = {
        key.lower(): value
        for key, value in (event.get("headers") or {}).items()
    }
    body = event.get("body") or ""
    if event.get("isBase64Encoded"):
        raw_body = base64.b64decode(body)
    else:
        raw_body = body.encode("utf-8")
    return headers, raw_body
