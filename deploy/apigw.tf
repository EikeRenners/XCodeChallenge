resource "aws_api_gateway_rest_api" "sharepass" {
  name        = "${var.application}"
  description = "SharePass - Secure password sharing in the cloud"  
  endpoint_configuration {
    types            = ["PRIVATE"]
    vpc_endpoint_ids = [aws_vpc_endpoint.apigw-endpoint.id]
  }
}

resource "aws_api_gateway_rest_api_policy" "sharepass-apigw-resource-policy" {
  rest_api_id = aws_api_gateway_rest_api.sharepass.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": "*",
            "Action": "execute-api:Invoke",
            "Resource": [
                "execute-api:/*"
            ]
        },
        {
            "Effect": "Deny",
            "Principal": "*",
            "Action": "execute-api:Invoke",
            "Resource": [
               "execute-api:/*"
            ],
            "Condition" : {
                "IpAddress": {
                    "aws:SourceIp": ["10.0.17.0/24" ]
                }
            }
        }
    ]
}
EOF
}


############################################################################################
# API Gateway configuration for internal request handling  
############################################################################################
resource "aws_api_gateway_resource" "sharepass-proxy" {
  rest_api_id = aws_api_gateway_rest_api.sharepass.id
  parent_id   = aws_api_gateway_rest_api.sharepass.root_resource_id
  #path_part   = "sharepass"
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "sharepass-method" {
  rest_api_id   = aws_api_gateway_rest_api.sharepass.id
  resource_id   = aws_api_gateway_resource.sharepass-proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "sharepass" {
  rest_api_id = aws_api_gateway_rest_api.sharepass.id
  resource_id = aws_api_gateway_method.sharepass-method.resource_id
  http_method = aws_api_gateway_method.sharepass-method.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lmb-sharepass.invoke_arn
}



############################################################################################
# API Gateway deployment 
############################################################################################
resource "aws_api_gateway_deployment" "sharepass" {
  depends_on = [
    aws_api_gateway_integration.sharepass
  ]

  rest_api_id = aws_api_gateway_rest_api.sharepass.id
  stage_name  = "${var.environment}"
  
}

