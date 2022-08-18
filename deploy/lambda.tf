
# Role to Policy attachment
resource "aws_iam_role_policy_attachment" "terraform_lambda_iam_policy_basic_execution" {
    role = aws_iam_role.lambda_exec.id
    policy_arn = aws_iam_policy.lambda_policy.arn
}


resource "aws_lambda_permission" "sharepass-apigw-lambda-exec-permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lmb-sharepass.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.sharepass.id}/*/*"
}


resource "aws_lambda_function" "lmb-sharepass" {
  function_name = "${var.application}-lambda-function"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.sharepass_lambda.key

  runtime       = "go1.x"
  handler       = "lmb-${var.application}"
  timeout       = 30
  memory_size   = 128

  source_code_hash = data.archive_file.lmb-sharepass.output_base64sha256
  role = aws_iam_role.lambda_exec.arn

  tags = "${merge(
    tomap({
      Name="${var.application}-lambda-function"
      }), 
    var.tags)}"
}

# CloudWatch Log Group for the Lambda function
resource "aws_cloudwatch_log_group" "lmb-sharepass-cwlog-group" {
  name              = "/aws/lambda/${aws_lambda_function.lmb-sharepass.function_name}"
  retention_in_days = var.lambda_logs_retention_in_days
  tags              = var.tags
}