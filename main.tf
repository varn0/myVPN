provider "aws" {
  profile = "default"
  region  = "us-east-2"
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.public_key
}


# add default security group
resource "aws_default_security_group" "default" {
    revoke_rules_on_delete = true
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    ingress {
        from_port   = 65443
        to_port     = 65443
        protocol    = "udp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }     
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

resource "aws_instance" "wireguard" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  user_data     = file("${path.module}/scripts/install_wg.sh")
  key_name      = aws_key_pair.deployer.key_name

}
