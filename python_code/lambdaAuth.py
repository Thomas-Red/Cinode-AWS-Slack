import base64
import json
import logging
import boto3
import re

# Enable logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS SSM client
ssm_client = boto3.client("ssm")

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

# Fetch credentials securely from AWS Parameter Store
VALID_USERNAME = get_parameter("/auth/username")
VALID_PASSWORD = get_parameter("/auth/password")

def extract_base_arn(method_arn):
    """Extracts the base ARN dynamically to prevent issues"""
    arn_parts = method_arn.split("/")
    base_arn = "/".join(arn_parts[:2])  # Keep only the base API ARN
    return f"{base_arn}/*/*"

def allow_policy(resource):
    safe_resource = extract_base_arn(resource)
    logger.info("Allowing access to: %s", safe_resource)  # No need to mask again
    return {
        "principalId": "user",
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {"Action": "execute-api:Invoke", "Effect": "Allow", "Resource": safe_resource}
            ],
        },
    }

def deny_policy(resource):
    safe_resource = extract_base_arn(resource)
    logger.warning("Denying access to: %s", safe_resource)  # No need to mask again
    return {
        "principalId": "user",
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {"Action": "execute-api:Invoke", "Effect": "Deny", "Resource": safe_resource}
            ],
        },
    }

def mask_sensitive_data(data):
    """
    Masks sensitive information in logs, including usernames.
    """
    if isinstance(data, str):
        # Mask username (we don't mask methodArn here to avoid redundancy)
        data = re.sub(r'Username=[^\s]+', "Username=***MASKED***", data)
    return data

def sanitize_event(event):
    """
    Sanitizes the event log by masking sensitive information, including methodArn.
    """
    sanitized_event = event.copy()
    if "authorizationToken" in sanitized_event:
        sanitized_event["authorizationToken"] = "Basic ***MASKED***"  # Mask credentials
    if "methodArn" in sanitized_event:
        sanitized_event["methodArn"] = "arn:aws:***MASKED***"  # Mask method ARN
    return sanitized_event

def lambda_handler(event, context):
    """
    Handles incoming authentication requests and validates credentials.
    """
    # Log sanitized event to remove sensitive data
    logger.info("Full received event (sanitized): %s", json.dumps(sanitize_event(event), indent=2))

    # Ensure methodArn exists
    method_arn = event.get("methodArn")
    if not method_arn:
        logger.error("methodArn is missing! Denying request.")
        return deny_policy("arn:aws:execute-api:*")  # Safer default

    # No need to mask methodArn again since it's already masked in sanitized logs
    logger.info("Received methodArn.")

    # Extract Authorization Token
    auth_header = event.get("authorizationToken", "")
    if not auth_header or not auth_header.startswith("Basic "):
        logger.warning("Invalid or missing Authorization token. Denying request.")
        return deny_policy(method_arn)

    # Decode the Base64-encoded credentials
    try:
        encoded_credentials = auth_header.split("Basic ")[1]
        decoded_bytes = base64.b64decode(encoded_credentials).decode("utf-8")

        if ":" not in decoded_bytes:
            logger.warning("Malformed credentials. Denying request.")
            return deny_policy(method_arn)

        received_username, received_password = decoded_bytes.split(":", 1)

        # Log username safely (mask password)
        logger.info(mask_sensitive_data(f"Decoded credentials: Username={received_username}"))

    except Exception as e:
        logger.error("Error decoding credentials: %s", str(e))
        return deny_policy(method_arn)

    # Validate credentials
    if received_username == VALID_USERNAME and received_password == VALID_PASSWORD:
        logger.info("Authentication successful! Allowing request.")
        return allow_policy(method_arn)

    logger.warning(mask_sensitive_data(f"Authentication failed! Username={received_username}"))
    return deny_policy(method_arn)