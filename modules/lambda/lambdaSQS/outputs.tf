output "lambda_sqs_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.lambda_sqs.function_name
}

output "lambda_sqs_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.lambda_sqs.arn
}
