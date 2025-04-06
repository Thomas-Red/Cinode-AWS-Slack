output "api_gateway_id" {
  description = "ID for API Gateway"
  value       = aws_api_gateway_rest_api.this.id
}

output "api_gateway_invoke_url" {
  description = "Invocations-URL for API Gateway"
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "api_gateway_arn" {
  description = "ARN for API Gateway"
  value       = aws_api_gateway_rest_api.this.arn

}