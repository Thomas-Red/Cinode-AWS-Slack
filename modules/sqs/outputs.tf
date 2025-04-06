output "queue_name" {
  description = "The name of the main SQS queue"
  value       = aws_sqs_queue.main.name
}

output "queue_url" {
  description = "The URL of the main SQS queue"
  value       = aws_sqs_queue.main.id
}

output "queue_arn" {
  description = "The ARN of the main SQS queue"
  value       = aws_sqs_queue.main.arn
}

output "dlq_arn" {
  description = "The ARN of the Dead Letter Queue (DLQ)"
  value       = aws_sqs_queue.dlq.arn
}