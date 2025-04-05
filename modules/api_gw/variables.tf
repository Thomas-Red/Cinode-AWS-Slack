variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "lambda_authorizer_arn" {
  description = "ARN of the Lambda Authorizer function"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "lambda_sqs_function_arn" {
  description = "ARN of the Lambda SQS function"
  type        = string
}

variable "stage_name" {
  description = "Deployment stage name"
  type        = string
}