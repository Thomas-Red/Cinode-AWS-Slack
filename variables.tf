variable "region" {
  description = "The region to deploy to"
  type        = string
  default     = "eu-north-1"
}

variable "profile" {
  description = "The SSO profile to use"
  type        = string
  default = "thomas-admin"
}

variable "function_name_auth" {
  description = "Name of the Lambda function"
  type        = string
  default     = "lambda_auth_test1"
}

variable "function_name_sqs" {
  description = "Name of the Lambda function"
  type        = string
  default     = "lambda_sqs_test1"
}

variable "function_name_slack" {
  description = "Name of the Lambda function"
  type        = string
  default     = "lambda_slack_test1"
}

variable "handler_auth" {
  description = "Lambda handler (e.g. file.function)"
  type        = string
  default     = "lambdaAuth.lambda_handler"
}

variable "handler_sqs" {
  description = "Lambda handler (e.g. file.function)"
  type        = string
  default     = "lambdaSQS.lambda_handler"
}

variable "handler_slack" {
  description = "Lambda handler (e.g. file.function)"
  type        = string
  default     = "lambdaSlack.lambda_handler"
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.12"
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 15
}

variable "role_name_auth" {
  description = "IAM Role name for Lambda"
  type        = string
  default     = "lambda_auth_role1"
}

variable "log_retention_days" {
  description = "CloudWatch Log retention in days"
  type        = number
  default     = 30
}

variable "role_name_slack" {
  description = "IAM Role name for Lambda"
  type        = string
  default     = "lambda_slack_role1"

}

variable "role_name_sqs" {
  description = "IAM Role name for Lambda"
  type        = string
  default     = "lambda_sqs_role1"

}

variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
  default     = "webhook-api"

}

variable "name_prefix" {
  description = "Prefix for the SQS queue name"
  type        = string
  default     = "DealBot"

}

variable "stage_name" {
  description = "Deployment stage name"
  type        = string
  default     = "dev"
}

variable "visibility_timeout" {
  type        = number
  default     = 30
  description = "Visibility timeout for the main queue (in seconds)"
}

variable "max_receive_count" {
  type        = number
  default     = 5
  description = "Max number of times a message can be received before going to DLQ"
}
