# Package the Lambda function source code into a ZIP file
data "archive_file" "lambda_slack_zip" {
  type        = "zip"
  source_file = var.source_file
  output_path = var.output_path
}

# Create an IAM role for the Slack Lambda to assume
resource "aws_iam_role" "lambda_slack_role" {
  name = var.role_name_slack

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach basic execution permissions (logging, metrics)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_slack_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow Lambda to process messages from SQS
resource "aws_iam_role_policy_attachment" "Lambda_SQS_Queue_Execution_Role" {
  role       = aws_iam_role.lambda_slack_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

# Grant access to SSM features (e.g., EC2 instance metadata)
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.lambda_slack_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allow read-only access to SSM Parameter Store (for fetching secrets/configs)
resource "aws_iam_role_policy_attachment" "ssm_read_only" {
  role       = aws_iam_role.lambda_slack_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# Create the Lambda function that sends Slack messages
resource "aws_lambda_function" "lambda_slack" {
  function_name    = var.function_name_slack
  filename         = data.archive_file.lambda_slack_zip.output_path
  source_code_hash = data.archive_file.lambda_slack_zip.output_base64sha256
  role             = aws_iam_role.lambda_slack_role.arn
  handler          = var.handler_slack
  runtime          = var.runtime
  timeout          = var.timeout
  layers           = [aws_lambda_layer_version.request_module.arn] # Attach custom requests layer
}

# Create a CloudWatch log group for the Slack Lambda
resource "aws_cloudwatch_log_group" "lambda_slack" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_slack.function_name}"
  retention_in_days = var.log_retention_days
}

# Define a Lambda layer that includes the 'requests' Python library
resource "aws_lambda_layer_version" "request_module" {
  layer_name          = "request_module"
  filename            = "${path.module}/request_module.zip"
  source_code_hash    = filebase64sha256("${path.module}/request_module.zip")
  compatible_runtimes = ["python3.12"]
  description         = "Requests lib for my Lambdas"
}