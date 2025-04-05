variable "function_name_sqs" {
  type        = string
  description = "The name of the Lambda function"
}

variable "handler_sqs" {
  type        = string
  description = "The handler function (e.g., file.lambda_handler)"
}

variable "runtime" {
  type        = string
  default     = "python3.12"
  description = "Lambda runtime"
}

variable "timeout" {
  type        = number
  description = "Timeout in seconds"
}

variable "source_file" {
  type        = string
  description = "Path to the Lambda source .py file"
}

variable "output_path" {
  type        = string
  description = "Path to output the zipped Lambda"
}

variable "role_name_sqs" {
  type        = string
  description = "IAM role name for the Lambda function"
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log group retention in days"
}