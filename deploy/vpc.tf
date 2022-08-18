
############################################################################################
# VPC and Networks 
############################################################################################
resource "aws_vpc" "sharepass-vpc" {
  cidr_block           = "10.0.0.0/20"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true 

  tags = "${merge(tomap({Name="${var.application}-vpc"}), var.tags)}"
}

resource "aws_default_route_table" "sharepass-route-table" {
  #vpc_id = aws_vpc.sharepass-vpc.id
  default_route_table_id = aws_vpc.sharepass-vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sharepass-inet-gw.id
  }
  tags = "${merge(tomap({Name="${var.application}-route-table"}), var.tags)}"
}

// from ...17.0 to ...17.15 
resource "aws_subnet" "sharepass-subnet-public" {
  vpc_id            = aws_vpc.sharepass-vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"

  tags = "${merge(tomap({Name="${var.application}-public-subnet"}), var.tags)}"
}

// from ...17.16 to ...17.31
resource "aws_subnet" "sharepass-subnet-1a" {
  vpc_id            = aws_vpc.sharepass-vpc.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1a"

  tags = "${merge(tomap({Name="${var.application}-subnet-1b"}), var.tags)}"
}
resource "aws_subnet" "sharepass-subnet-1b" {
  vpc_id            = aws_vpc.sharepass-vpc.id
  cidr_block        = "10.0.13.0/24"
  availability_zone = "us-east-1b"

  tags = "${merge(tomap({Name="${var.application}-subnet-1a"}), var.tags)}"
}


############################################################################################
# Security Groups 
############################################################################################
resource "aws_security_group" "sharepass-vpn-access"  {
   name = "${var.application}-vpn-access"
   vpc_id = aws_vpc.sharepass-vpc.id
   ingress {
     from_port = 0
     protocol = "-1"
     to_port = 0
     cidr_blocks = ["0.0.0.0/0"]
   }
   egress {
     from_port = 0
     protocol = "-1"
     to_port = 0
     cidr_blocks = ["0.0.0.0/0"]
   }
 }

resource "aws_security_group" "sharepass-allow-tls" {
  name        = "${var.application}-sg-allow-tls-from-vpc"
  description = "Allow TLS inbound traffic from within the vpc"
  vpc_id      = aws_vpc.sharepass-vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.sharepass-vpc.cidr_block]       // in real world vpn scenario: add cidr blocks for on prem here too?
    //ipv6_cidr_blocks = [aws_vpc.sharepass-vpc.ipv6_cidr_block]
  }
  tags = "${merge(tomap({Name= "${var.application}-sg-allow-tls-from-vpc"}), var.tags)}"
}

resource "aws_security_group" "sharepass-allow-ssh" {
  name        = "${var.application}-sg-allow-ssh-from-public"
  description = "Allow SSH inbound traffic from public internet"
  vpc_id      = aws_vpc.sharepass-vpc.id

  ingress {
    description      = "ssh from public internet"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]  
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = "${merge(tomap({Name= "${var.application}-sg-allow-ssh-from-public"}), var.tags)}"
}

 resource "aws_security_group" "sharepass-vpn-dns" {
   name = "${var.application}-vpn-dns"
   vpc_id = aws_vpc.sharepass-vpc.id
   ingress {
     from_port = 0
     protocol = "-1"
     to_port = 0
     security_groups = [aws_security_group.sharepass-vpn-access.id]
   }
   egress {
     from_port = 0
     protocol = "-1"
     to_port = 0
     cidr_blocks = ["0.0.0.0/0"]
   }
  tags = "${merge(tomap({Name= "${var.application}-sg-vpn-public"}), var.tags)}"
 }


############################################################################################
# Endpoints & Gateways  
############################################################################################

resource "aws_internet_gateway" "sharepass-inet-gw" {
  vpc_id = aws_vpc.sharepass-vpc.id

  tags = "${merge(tomap({Name="${var.application}-internet-gw"}), var.tags)}"
}

resource "aws_vpc_endpoint" "apigw-endpoint" {
  vpc_id            = aws_vpc.sharepass-vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.execute-api"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [
    aws_subnet.sharepass-subnet-1a.id,
    aws_subnet.sharepass-subnet-1b.id,
    ]

  security_group_ids = [
    aws_security_group.sharepass-allow-tls.id,
  ]

  private_dns_enabled = true

  tags = "${merge(tomap({Name="${var.application}-apigw-vpc-endpoint"}), var.tags)}"
}

resource "aws_vpc_endpoint" "dyndb-endpoint" {
  vpc_id            = aws_vpc.sharepass-vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  tags = "${merge(tomap({Name="${var.application}-dyndb-vpc-endpoint"}), var.tags)}"
}

resource "aws_ec2_client_vpn_endpoint" "sharepass-vpn" {
  client_cidr_block      = "10.0.16.0/20"
  split_tunnel           = false
  server_certificate_arn = "arn:aws:acm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:certificate/eab830e3-81a6-498d-9211-b47a876ce0bb"

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = "arn:aws:acm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:certificate/b4abdb9c-d545-49db-8d1b-a442972d8330"
  }
  # dns_servers = [
  #   aws_route53_resolver_endpoint.sharepass-vpn-dns.ip_address.*.ip[0], 
  #   aws_route53_resolver_endpoint.sharepass-vpn-dns.ip_address.*.ip[1]
  # ]
  connection_log_options {
    enabled = false
  }
}

# resource aws_route53_resolver_endpoint sharepass-vpn-dns {
#   name = "${var.application}-vpn-dns-access"
#   direction = "INBOUND"
#   security_group_ids = [aws_security_group.sharepass-vpn-dns.id]
#   ip_address {
#     subnet_id = aws_subnet.sharepass-subnet-1a.id
#   }
#   ip_address {
#     subnet_id = aws_subnet.sharepass-subnet-1b.id
#   }
# }

resource "aws_ec2_client_vpn_network_association" "sharepass-private" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.sharepass-vpn.id
  subnet_id              = aws_subnet.sharepass-subnet-1a.id
}

resource "aws_vpc_endpoint_route_table_association" "private-dynamodb" {
  vpc_endpoint_id = "${aws_vpc_endpoint.dyndb-endpoint.id}"
  route_table_id  = "${aws_vpc.sharepass-vpc.main_route_table_id}"
}