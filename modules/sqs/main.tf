# Create a Dead Letter Queue (DLQ) to store messages that can't be processed
resource "aws_sqs_queue" "dlq" {
  name = "${var.name_prefix}-dlq"

  message_retention_seconds = 1209600 # Keep messages for 14 days (max allowed)
}

# Create the main SQS queue and link it to the DLQ
resource "aws_sqs_queue" "main" {
  name = "${var.name_prefix}-queue"

  # Set redrive policy to send failed messages to the DLQ after maxReceiveCount
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  visibility_timeout_seconds = var.visibility_timeout # Time message stays invisible after being picked up
}