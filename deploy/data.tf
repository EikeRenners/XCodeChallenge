data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${data.aws_region.current.name}.s3"
}

#### lambda function for upload 
data "archive_file" "lmb-sharepass" {
  type = "zip"

  source_dir  = "${path.module}/../src/lambdas/bin/lmb-${var.application}"
  output_path = "${path.module}/../src/lambdas/archive/lmb-${var.application}.zip"  

}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}