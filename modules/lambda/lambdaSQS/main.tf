# Package the Lambda function source code into a ZIP file
data "archive_file" "lambda_sqs_zip" {
  type        = "zip"
  source_file = var.source_file
  output_path = var.output_path
}

# Create an IAM role for the Lambda to assume
resource "aws_iam_role" "lambda_sqs_role" {
  name = var.role_name_sqs

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

# Attach basic execution policy (e.g., logging to CloudWatch)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_sqs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Grant full access to SQS so Lambda can receive and delete messages
resource "aws_iam_role_policy_attachment" "Lambda_SQS_Queue_Execution_Role" {
  role       = aws_iam_role.lambda_sqs_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

# Allow access to managed SSM core features (e.g., instance metadata)
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.lambda_sqs_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Provide read-only access to SSM parameters (e.g., for secret fetching)
resource "aws_iam_role_policy_attachment" "ssm_read_only" {
  role       = aws_iam_role.lambda_sqs_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# Create the Lambda function and deploy the packaged code
resource "aws_lambda_function" "lambda_sqs" {
  function_name    = var.function_name_sqs
  filename         = data.archive_file.lambda_sqs_zip.output_path
  source_code_hash = data.archive_file.lambda_sqs_zip.output_base64sha256
  role             = aws_iam_role.lambda_sqs_role.arn
  handler          = var.handler_sqs
  runtime          = var.runtime
  timeout          = var.timeout
}

# Create a CloudWatch log group for the Lambda function
resource "aws_cloudwatch_log_group" "lambda_sqs" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_sqs.function_name}"
  retention_in_days = var.log_retention_days
}