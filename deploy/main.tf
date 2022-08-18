provider "aws" {
  region = "us-east-1"
  profile = "${var.profile}"

  # Make it faster by skipping something
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
}


resource "aws_key_pair" "eike" {
  key_name   = "eike-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGZe9UMHchkqjsCgmqhMgE4nHgSY21E6xn/F0OP5nsqH eike@renners.net"
}

resource "aws_instance" "sharepass-jumphost" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  root_block_device {
    delete_on_termination = true
    volume_size = 8
    volume_type = "gp2"
  }

  key_name = aws_key_pair.eike.key_name

  vpc_security_group_ids = [ aws_security_group.sharepass-allow-ssh.id ]
  subnet_id = aws_subnet.sharepass-subnet-public.id
  associate_public_ip_address = true

  tags = "${merge(tomap({Name="${var.application}-ec2-jumphost"}), var.tags)}"
}