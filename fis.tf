##########################
# FIS Experiment Template
##########################
resource "aws_fis_experiment_template" "web_instance_failure" {
  description = "FIS experiment - terminate one EC2 instance in ASG to validate ALB/ASG/RDS resilience"

  role_arn = aws_iam_role.fis_experiment_role.arn

  target {
    name           = "WebInstances"
    resource_type  = "aws:ec2:instance"
    selection_mode = "COUNT(1)"

    resource_tag {
      key   = "Service"
      value = "web"
    }
  }

  target {
    name           = "Volumes-Target-azA"
    resource_type  = "aws:ec2:ebs-volume"
    selection_mode = "ALL"

    resource_tag {
      key   = "Service"
      value = "web"
    }

    parameters = {
      availabilityZoneIdentifier = aws_subnet.public_a.availability_zone_id
    }
  }

  target {
    name           = "Volumes-Target-azB"
    resource_type  = "aws:ec2:ebs-volume"
    selection_mode = "ALL"

    resource_tag {
      key   = "Service"
      value = "web"
    }

    parameters = {
      availabilityZoneIdentifier = aws_subnet.public_b.availability_zone_id
    }
  }


  action {
    name      = "TerminateInstance"
    action_id = "aws:ec2:terminate-instances"

    target {
      key   = "Instances"
      value = "WebInstances"
    }

    description = "Terminate one EC2 instance from the web ASG"

    start_after = [
      "Volume_IO_Latency_azA",
      "Volume_IO_Latency_azB"
    ]
  }

  action {
    name        = "Volume_IO_Latency_azA"
    action_id   = "aws:ebs:volume-io-latency"
    description = "Add Latency on instance EBS AZA"
    parameter {
      key   = "duration"
      value = "PT2M"
    }
    parameter {
      key   = "readIOLatencyMilliseconds"
      value = "200"
    }
    parameter {
      key   = "readIOPercentage"
      value = "50"
    }
    parameter {
      key   = "writeIOLatencyMilliseconds"
      value = "200"
    }
    parameter {
      key   = "writeIOPercentage"
      value = "50"
    }

    target {
      key   = "Volumes"
      value = "Volumes-Target-azA"
    }
  }

  action {
    name        = "Volume_IO_Latency_azB"
    action_id   = "aws:ebs:volume-io-latency"
    description = "Add Latency on instance EBS AZB"
    parameter {
      key   = "duration"
      value = "PT2M"
    }
    parameter {
      key   = "readIOLatencyMilliseconds"
      value = "200"
    }
    parameter {
      key   = "readIOPercentage"
      value = "50"
    }
    parameter {
      key   = "writeIOLatencyMilliseconds"
      value = "200"
    }
    parameter {
      key   = "writeIOPercentage"
      value = "50"
    }

    target {
      key   = "Volumes"
      value = "Volumes-Target-azB"
    }
  }

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = aws_cloudwatch_metric_alarm.alb_5xx_alarm.arn
  }


  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = aws_cloudwatch_metric_alarm.alb_latency_alarm.arn
  }

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = aws_cloudwatch_metric_alarm.rds_connections_alarm.arn
  }


  /*
  dynamic "stop_condition" {
    for_each = aws_cloudwatch_metric_alarm.ebs_read_latency_alarm
    iterator = metric
    content {
      source = "aws:cloudwatch:alarm"
      value  = metric.value.arn
    }
  }

  dynamic "stop_condition" {
    for_each = aws_cloudwatch_metric_alarm.ebs_write_latency_alarm
    iterator = metric
    content {
      source = "aws:cloudwatch:alarm"
      value  = metric.value.arn
    }
  }
*/

  tags = {
    Name    = "${local.prefix}-fis-experiment-template"
    project = "fis-poc"
    owner   = "team-sre"
    purpose = "pra-to-fis-demo"
  }

  log_configuration {
    log_schema_version = 2
    cloudwatch_logs_configuration {
      log_group_arn = "${aws_cloudwatch_log_group.fis_experiment_logs.arn}:*"
    }
  }
  experiment_report_configuration {
    data_sources {
      cloudwatch_dashboard {
        dashboard_arn = aws_cloudwatch_dashboard.fis_dashboard.dashboard_arn
      }
    }

    outputs {
      s3_configuration {
        bucket_name = aws_s3_bucket.fis_experiment_reports.bucket
        prefix      = "fis-example-reports"
      }
    }

    post_experiment_duration = "PT2M"
    pre_experiment_duration  = "PT2M"

  }
}

resource "aws_s3_bucket" "fis_experiment_reports" {
  bucket = "${local.prefix}-fis-experiment-reports"

  tags = {
    Name = "${local.prefix}-fis-experiment-reports"
  }

  force_destroy = true
}