# Package the Lambda function code into a ZIP file
data "archive_file" "lambda_auth_zip" {
  type        = "zip"
  source_file = var.source_file
  output_path = var.output_path
}

# IAM role for the Lambda function to assume
resource "aws_iam_role" "lambda_auth_role" {
  name = var.role_name_auth

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

# Attach the basic execution policy (includes permissions for logging)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_auth_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach policy for accessing SSM parameters and instance info
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.lambda_auth_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach read-only access to SSM parameters
resource "aws_iam_role_policy_attachment" "ssm_read_only" {
  role       = aws_iam_role.lambda_auth_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# Create the Lambda function using the packaged ZIP
resource "aws_lambda_function" "lambda_auth" {
  function_name    = var.function_name_auth
  filename         = data.archive_file.lambda_auth_zip.output_path
  source_code_hash = data.archive_file.lambda_auth_zip.output_base64sha256
  role             = aws_iam_role.lambda_auth_role.arn
  handler          = var.handler_auth
  runtime          = var.runtime
  timeout          = var.timeout
}

# Create a CloudWatch Log Group for the Lambda function
resource "aws_cloudwatch_log_group" "lambda_auth" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_auth.function_name}"
  retention_in_days = var.log_retention_days
}