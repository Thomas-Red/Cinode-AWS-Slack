# Deploy the Lambda function for authentication logic
module "lambdaAuth" {
  source             = "./modules/lambda/lambdaAuth"
  function_name_auth = var.function_name_auth
  handler_auth       = var.handler_auth
  runtime            = var.runtime
  timeout            = var.timeout
  role_name_auth     = var.role_name_auth
  log_retention_days = var.log_retention_days

  source_file = "${path.module}/python_code/lambdaAuth.py"
  output_path = "${path.module}/python_code/lambdaAuth.zip"
}

# Deploy the Lambda function that sends messages to Slack
module "lambdaSlack" {
  source              = "./modules/lambda/lambdaSlack"
  function_name_slack = var.function_name_slack
  handler_slack       = var.handler_slack
  runtime             = var.runtime
  timeout             = var.timeout
  role_name_slack     = var.role_name_slack
  log_retention_days  = var.log_retention_days

  source_file = "${path.module}/python_code/lambdaSlack.py"
  output_path = "${path.module}/python_code/lambdaSlack.zip"
}

# Deploy the Lambda function that processes SQS messages
module "lambdaSQS" {
  source             = "./modules/lambda/lambdaSQS"
  function_name_sqs  = var.function_name_sqs
  handler_sqs        = var.handler_sqs
  runtime            = var.runtime
  timeout            = var.timeout
  role_name_sqs      = var.role_name_sqs
  log_retention_days = var.log_retention_days

  source_file = "${path.module}/python_code/lambdaSQS.py"
  output_path = "${path.module}/python_code/lambdaSQS.zip"
}

# Deploy the API Gateway and connect it to Lambda and the authorizer
module "api_gw" {
  source                  = "./modules/api_gw"
  api_name                = var.api_name
  lambda_authorizer_arn   = module.lambdaAuth.lambda_auth_function_arn
  region                  = var.region
  lambda_sqs_function_arn = module.lambdaSQS.lambda_sqs_function_arn
  stage_name              = var.stage_name
}

# Create the SQS queue and dead letter queue
module "sqs" {
  source             = "./modules/sqs"
  name_prefix        = var.name_prefix
  visibility_timeout = var.visibility_timeout
  max_receive_count  = var.max_receive_count
}

# Connect the SQS queue to the Slack Lambda as an event trigger
resource "aws_lambda_event_source_mapping" "trigger_sqs_to_slack_lambda" {
  event_source_arn = module.sqs.queue_arn
  function_name    = module.lambdaSlack.lambda_slack_function_arn
  batch_size       = 10
  enabled          = true
}

# Store the SQS queue URL in SSM Parameter Store for use in Lambda
resource "aws_ssm_parameter" "sqs_queue_url" {
  name        = "/sqs/queue_url_2"
  description = "URL for the Slack-triggered SQS queue"
  type        = "String"
  value       = module.sqs.queue_url
}