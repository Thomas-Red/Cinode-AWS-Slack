
# 📘 README: Serverless Cinode Deal Notification Pipeline (Terraform + AWS)

## 📌 Overview

This project provisions a **serverless event-driven architecture** in AWS using **Terraform**. The system listens for **Cinode webhook events** (e.g., new “won deals”), validates incoming data, scrubs and queues it, and sends a formatted message to a **Slack channel** using a custom bot — all managed with secure and observable practices.

All infrastructure is defined as **infrastructure-as-code**, and secrets are securely stored in **AWS Systems Manager Parameter Store**.

## 🧱 Architecture Diagram

```
Cinode Webhook
     ↓
API Gateway — (lambdaAuth Authorizer)
     ↓
lambdaSQS (Payload Scrubber)
     ↓
Primary SQS Queue (DealBot-*)
     ↓
DLQ (DealBot-DLQ)
     ↓
lambdaSlack (Slack Formatter & Sender)
     ↓
Slack Channel
```

## ⚙️ AWS Services Provisioned

### ✅ API Gateway
- Custom Lambda Authorizer (`lambdaAuth`) validates inbound requests
- Routes valid POST requests to Lambda (`lambdaSQS`) via **AWS_PROXY**
- Integrated logging and X-Ray tracing

### ✅ Lambda Functions
- **`lambdaAuth`**: Validates `Authorization` header from Cinode
- **`lambdaSQS`**: Sanitizes payload and queues message to SQS
- **`lambdaSlack`**: Reads from SQS and posts formatted content to Slack

All Lambdas:
- Use Python 3.12
- 15-second timeout
- Structured logging to CloudWatch (30-day retention)
- Load secrets from **Parameter Store**

### ✅ SQS & DLQ
- **Primary SQS queue** receives scrubbed payloads
- Configured with:
  - `visibility_timeout = 30`
  - `max_receive_count = 5`
- **Dead Letter Queue (DLQ)** receives undeliverable messages
- DLQ setup is defined in Terraform using `redrive_policy`

> This ensures **resilience** and **fault isolation** in case of transient or permanent failures in message processing.

## 🔐 Secure Parameter Management

Secrets are stored and accessed from **AWS Systems Manager Parameter Store** (`SecureString`):

| Parameter Name               | Purpose                              |
|-----------------------------|--------------------------------------|
| `/dealbot/auth_token`       | Expected token in request header     |
| `/dealbot/slack_token`      | Slack bot OAuth token                |
| `/dealbot/slack_channel_id` | Target Slack channel ID              |

Make sure Lambda IAM roles have `ssm:GetParameter` access.

## 📂 Project Structure

```
.
├── README.md
├── main.tf
├── terraform.tf
├── variables.tf
├── python_code/
│   ├── lambdaAuth.py
│   ├── lambdaAuth.zip
│   ├── lambdaSQS.py
│   ├── lambdaSQS.zip
│   ├── lambdaSlack.py
│   └── lambdaSlack.zip
├── modules/
│   ├── api_gw/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── lambda/
│   │   ├── lambdaAuth/
│   │   │   ├── main.tf
│   │   │   ├── outputs.tf
│   │   │   └── variables.tf
│   │   ├── lambdaSQS/
│   │   │   ├── main.tf
│   │   │   ├── outputs.tf
│   │   │   └── variables.tf
│   │   └── lambdaSlack/
│   │       ├── main.tf
│   │       ├── outputs.tf
│   │       ├── variables.tf
│   │       └── request_module.zip
│   └── sqs/
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
```

## 🧬 Key Terraform Variables

| Variable              | Default             | Description                          |
|-----------------------|---------------------|--------------------------------------|
| `region`              | `eu-north-1`        | AWS region to deploy to              |
| `profile`             | _(user-defined)_    | AWS SSO CLI profile                  |
| `name_prefix`         | `DealBot`           | Used in naming SQS and DLQ queues    |
| `stage_name`          | `dev`               | API Gateway stage                    |
| `visibility_timeout`  | `30`                | SQS queue visibility timeout (sec)   |
| `max_receive_count`   | `5`                 | Failed receives before DLQ handoff   |

## 🚀 Deploying

### 🔧 Prerequisites

- Terraform CLI installed (`>=1.5`)
- AWS CLI & configured SSO profile
- Slack bot + target channel
- Parameter Store secrets created

### 🛠️ Deploy Infrastructure

```bash
terraform init
terraform apply -var="profile=your-aws-profile"
```

### 🧹 Teardown

```bash
terraform destroy -var="profile=your-aws-profile"
```

## 🧪 Testing the Flow

1. **Send Test Request**  
   Use `curl` or Postman:
   ```
   POST /post
   Headers: Authorization: <value in /dealbot/auth_token>
   Body: valid Cinode webhook JSON
   ```

2. **Check Outputs**
   - `lambdaAuth` logs auth status
   - `lambdaSQS` logs cleaned payload
   - `lambdaSlack` posts to Slack

3. **If Failures Happen**  
   - Messages land in DLQ after 5 retries
   - View DLQ messages in SQS console
   - Useful for debugging

## 📊 Observability

- **CloudWatch Logs**: for API Gateway and all Lambdas
- **DLQ Monitoring**: Check for failed messages in `DealBot-DLQ`
- **X-Ray Tracing**: Enabled at API Gateway stage
- Sensitive values are **redacted from logs**

## 🧠 Potential Enhancements

- Add DLQ -> SNS + email alerting
- Use Secrets Manager instead of Parameter Store
- Add LocalStack testing pipeline
- Harden Lambda auth with HMAC signature verification
