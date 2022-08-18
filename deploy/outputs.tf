output "sharepass_base_url" {
  value = aws_api_gateway_deployment.sharepass.invoke_url
}
