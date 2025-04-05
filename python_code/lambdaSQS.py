import json
import logging
import boto3
import re

# Enable logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
ssm_client = boto3.client("ssm")
sqs_client = boto3.client("sqs")

def get_parameter(name, with_decryption=True):
    """
    Fetches a parameter from AWS Systems Manager Parameter Store.
    """
    try:
        response = ssm_client.get_parameter(Name=name, WithDecryption=with_decryption)
        return response["Parameter"]["Value"]
    except Exception as e:
        logger.error(f"Error fetching parameter {name}: {str(e)}")
        raise

# Fetch SQS URL from AWS Parameter Store
SQS_QUEUE_URL = get_parameter("/sqs/queue_url_2")

def sanitize_event(event):
    """
    Sanitizes the event log by masking sensitive information before logging.
    """
    sanitized_event = json.loads(json.dumps(event))  # Create a deep copy

    # Mask Authorization header
    if "headers" in sanitized_event and "Authorization" in sanitized_event["headers"]:
        sanitized_event["headers"]["Authorization"] = "Basic ***MASKED***"

    if "multiValueHeaders" in sanitized_event and "Authorization" in sanitized_event["multiValueHeaders"]:
        sanitized_event["multiValueHeaders"]["Authorization"] = ["Basic ***MASKED***"]

    # Mask Webhook ID in request body
    if "body" in sanitized_event and sanitized_event["body"]:
        try:
            body_data = json.loads(sanitized_event["body"])
            if "WebhookId" in body_data:
                body_data["WebhookId"] = "***MASKED***"
            sanitized_event["body"] = json.dumps(body_data)
        except json.JSONDecodeError:
            pass  # If the body is not JSON, we skip masking

    return sanitized_event

def _build_response(status_code, message):
    """
    Helper to return standardized API responses.
    """
    return {
        "statusCode": status_code,
        "body": json.dumps({"message": message})
    }

def lambda_handler(event, context):
    """
    Receives webhook data from Cinode, filters for 'Won' deals, 
    removes sensitive data (Webhook URL), and forwards to SQS.
    """
    try:
        # Log sanitized event
        logger.info("Received event (sanitized): %s", json.dumps(sanitize_event(event), indent=2))

        # Extract the body from the event
        body_str = event.get("body", "")
        if not body_str:
            logger.warning("No body found in the event.")
            return _build_response(400, "No request body provided.")

        data = json.loads(body_str)

        # Remove WebhookId (extra security measure)
        if "WebhookId" in data:
            del data["WebhookId"]

        # Extract payload and state information
        payload = data.get("Payload", {})
        current_state = payload.get("CurrentState", {})

        # Check if the deal is "Won"
        if current_state.get("StateTitle") != "Won":
            logger.info("Ignoring deal - not WON status.")
            return _build_response(200, "Deal ignored. Not a 'Won' deal.")

        # Send only "Won" deals (without webhook info) to SQS
        response = sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(data)
        )

        logger.info(f"Message sent to SQS: {response['MessageId']} (Webhook ID removed)")

        return _build_response(200, "Won deal forwarded to SQS.")

    except Exception as e:
        logger.error(f"Error processing webhook: {str(e)}")
        return _build_response(500, "Internal Server Error")