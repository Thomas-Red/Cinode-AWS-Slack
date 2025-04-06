# Create the API Gateway REST API
resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_name
  description = "API Gateway with Lambda Authorizer"
  endpoint_configuration {
    types = ["REGIONAL"] # Use a regional endpoint
  }
}

# Configure a Lambda authorizer for the API Gateway
resource "aws_api_gateway_authorizer" "this" {
  name                   = "${var.api_name}-authorizer"
  rest_api_id            = aws_api_gateway_rest_api.this.id
  authorizer_uri         = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_authorizer_arn}/invocations"
  authorizer_credentials = aws_iam_role.apigateway_lambda_role.arn
  identity_source        = "method.request.header.Authorization" # Read token from Authorization header
  type                   = "TOKEN"
}

# IAM role for API Gateway to invoke the Lambda authorizer
resource "aws_iam_role" "apigateway_lambda_role" {
  name = "apigateway_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
}

# Grant permission for API Gateway to invoke the Lambda authorizer
resource "aws_lambda_permission" "apigateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_authorizer_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/dev/POST/post"
}

# Create the /post resource under the API Gateway
resource "aws_api_gateway_resource" "post_resource" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "post"
}

# Define the POST method with custom Lambda authorizer
resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.post_resource.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.this.id
}

# Integrate POST method with Lambda using AWS_PROXY integration
resource "aws_api_gateway_integration" "post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.post_resource.id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_sqs_function_arn}/invocations"
}

# Grant permission for API Gateway to invoke the SQS handler Lambda
resource "aws_lambda_permission" "post_invoke_permission" {
  statement_id  = "AllowAPIGatewayInvokePost"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_sqs_function_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/POST/post"
}

# Create CloudWatch log group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "/aws/api-gateway/${var.api_name}"
  retention_in_days = 14
}

# IAM role that allows API Gateway to write logs to CloudWatch
resource "aws_iam_role" "api_gateway_logging" {
  name = "${var.api_name}-api-gateway-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
}

# IAM policy for the API Gateway logging role with CloudWatch permissions
resource "aws_iam_role_policy" "api_gateway_logging_policy" {
  name = "${var.api_name}-api-gateway-logging-policy"
  role = aws_iam_role.api_gateway_logging.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents",
        "logs:FilterLogEvents",
        "logs:PutLogEvents"
      ],
      Resource = "*"
    }]
  })
}

# Tell API Gateway to use the CloudWatch logging role
resource "aws_api_gateway_account" "logging" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_logging.arn
}

# Deploy the API Gateway and trigger redeployments when things change
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  triggers = {
    redeployment = sha1(join("", [
      jsonencode(aws_api_gateway_rest_api.this),
      aws_api_gateway_integration.post_integration.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Define the deployment stage with access logging and X-Ray tracing enabled
resource "aws_api_gateway_stage" "this" {
  stage_name           = var.stage_name
  rest_api_id          = aws_api_gateway_rest_api.this.id
  deployment_id        = aws_api_gateway_deployment.this.id
  description          = "Enables API Gateway logging to CloudWatch"
  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId",
      ip             = "$context.identity.sourceIp",
      caller         = "$context.identity.caller",
      user           = "$context.identity.user",
      requestTime    = "$context.requestTime",
      httpMethod     = "$context.httpMethod",
      resourcePath   = "$context.resourcePath",
      status         = "$context.status",
      protocol       = "$context.protocol",
      responseLength = "$context.responseLength"
    })
  }
}

# Enable detailed method-level logging and metrics for all methods
resource "aws_api_gateway_method_settings" "s" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*" # Apply to all methods in all resources

  settings {
    metrics_enabled    = true
    logging_level      = "INFO"
    data_trace_enabled = true
  }
}