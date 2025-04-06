import json
import logging
import requests
import boto3
import os

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

# Fetch secrets from AWS Systems Manager Parameter Store
SQS_QUEUE_URL = get_parameter("/sqs/queue_url_2")
SLACK_BOT_TOKEN = get_parameter("/slack/bot_token")
SLACK_CHANNEL_ID = get_parameter("/slack/channel_id")
SLACK_URL = "https://slack.com/api/chat.postMessage"

def post_to_slack(message_payload):
    """
    Sends a JSON payload to Slack using the `chat.postMessage` API.
    """
    headers = {
        "Authorization": f"Bearer {SLACK_BOT_TOKEN}",
        "Content-Type": "application/json"
    }
    payload = {
        "channel": SLACK_CHANNEL_ID,
        "blocks": message_payload["blocks"],
        "attachments": message_payload["attachments"]
    }

    response = requests.post(SLACK_URL, headers=headers, json=payload, timeout=10)

    if response.status_code != 200 or not response.json().get("ok"):
        raise RuntimeError(f"Slack API call failed: {response.status_code} {response.text}")

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
    Reads messages from SQS and sends Slack notifications (No Filtering).
    """
    try:
        for record in event["Records"]:
            message_body = json.loads(record["body"])

            logger.info(f"Processing SQS message: {json.dumps(message_body, indent=2)}")

            # Extract payload from the message
            payload = message_body.get("Payload", {})

            # Extract relevant deal information
            deal_title = payload.get("Title", "No title")
            sales_manager = payload.get("SalesManagers", [{}])[0].get("Fullname", "N/A")
            customer_name = payload.get("Customer", {}).get("Name", "Unknown Customer")
            value_amount = payload.get("EstimatedValue", 0)
            currency = payload.get("Currency", {}).get("CurrencyCode", "SEK")
            state_title = payload.get("CurrentState", {}).get("StateTitle", "Unknown")

            # Build Slack message
            slack_message = {
                "blocks": [
                    {"type": "section", "text": {"type": "mrkdwn", "text": "*New Deal Update!* :bell:"}}
                ],
                "attachments": [
                    {
                        "color": "#2ECC71",
                        "blocks": [
                            {"type": "section", "text": {"type": "mrkdwn", "text": f"*{deal_title}*"}},
                            {"type": "section", "text": {"type": "mrkdwn", "text": f"📧 *Sales Manager:* {sales_manager}"}},
                            {"type": "section", "text": {"type": "mrkdwn", "text": f"🏢 *Customer:* {customer_name}"}},
                            {"type": "section", "text": {"type": "mrkdwn", "text": f"💰 *Value:* *{value_amount:,.0f} {currency}*"}},
                            {"type": "section", "text": {"type": "mrkdwn", "text": f"📌 *Current State:* {state_title}"}}
                        ]
                    }
                ]
            }

            # Send message to Slack
            post_to_slack(slack_message)
            logger.info("Slack message posted successfully.")

        return _build_response(200, "Slack notification sent successfully.")

    except Exception as e:
        logger.error(f"Error processing SQS message: {str(e)}")
        return _build_response(500, "Internal Server Error")