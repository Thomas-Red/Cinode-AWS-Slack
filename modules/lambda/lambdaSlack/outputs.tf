output "lambda_slack_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.lambda_slack.function_name
}

output "lambda_slack_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.lambda_slack.arn
}