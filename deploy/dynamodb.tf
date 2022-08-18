resource "aws_dynamodb_table" "sharepass-secrets-table" {
  name           = "${var.application}-dyndb-table"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "SecretId"
  # range_key      = "RangeKey"

  attribute {
    name = "SecretId"
    type = "S"
  }

  tags = "${merge(tomap({Name="${var.application}-dyndb-table"}), var.tags)}"
}