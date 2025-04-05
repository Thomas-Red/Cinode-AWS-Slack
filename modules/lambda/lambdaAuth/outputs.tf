output "lambda_auth_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.lambda_auth.function_name
}

output "lambda_auth_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.lambda_auth.arn
}
