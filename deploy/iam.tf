
# Lambda function policy
resource "aws_iam_policy" "lambda_policy" {
    name        = "${var.environment}-${var.application}-lambda-policy"
    description = "${var.environment}-${var.application}-lambda-policy"
 
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:Get*",
        "dynamodb:Query",
        "dynamodb:Delete*",
        "dynamodb:PutItem"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:dynamodb:*:*:table/${aws_dynamodb_table.sharepass-secrets-table.name}"
    }
  ]
}
EOF
} # IMPORTANT: Define base / env / para-name as env variables in TF - allow access to only defined parameter 


resource "aws_iam_role" "lambda_exec" {
  name = "${var.environment}-${var.application}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}