resource "aws_fis_experiment_template" "az_failure_subnet" {
  description = "Perturbe le trafic sur le subnet public_a"
  role_arn    = aws_iam_role.fis_experiment_role.arn
  # Condition d'arrêt : stopper si l'alarme CloudWatch se déclenche
  stop_condition {
    source = "none"
  }
  # Cible : instances EC2 taggées pra_latency=true (10% des instances)
  target {
    name           = "subnet-target"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"
    resource_arns  = [aws_subnet.public_a.arn]
    # resource_tag {
    # key = "AzImpairmentPower"
    # value = "DisruptSubnet"
    # }
    # filter {
    # path = "AvailabilityZone"
    # values = ["eu-west-1b"]
    # }
  }
  # Action : disruption réseau (clonage d'ACL réseau) pour 1 minutes
  action {
    action_id   = "aws:network:disrupt-connectivity"
    name        = "disrupt-connectivity"
    description = "Bloquer le trafic sortant HTTPS (port 443) via NACL"
    parameter {
      key   = "duration"
      value = "PT1M" #1 minute
    }
    parameter {
      key   = "scope"
      value = "all"
    }
    # parameter {
    # key = "scope"
    # value = "prefix-list"
    # }
    # parameter {
    # key = "prefixListIdentifier"
    # value = "<prefix-list-identifier>"
    # }
    target {
      key   = "Subnets"
      value = "subnet-target"
    }
  }
  tags = {
    Name = "fis-network-disrupt-connectivity"
  }
}