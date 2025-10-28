data "aws_ami" "amazon_linux_2023" {
  most_recent = true

  owners = ["137112412989"] # Compte officiel Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"] # Pour architecture x86_64
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Catch all EBS volumes tagged Service=web
data "aws_ebs_volumes" "web" {
  filter {
    name   = "tag:Service"
    values = ["web"]
  }
}
