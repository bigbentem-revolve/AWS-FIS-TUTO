###############################
# CloudWatch Dashboard for FIS Monitoring
resource "aws_cloudwatch_dashboard" "fis_dashboard" {
  dashboard_name = "${local.prefix}-fis-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.web_alb.arn_suffix]
          ]
          period = 60
          stat   = "Sum"
          region = "eu-west-1"
          title  = "ALB 5XX Errors"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.web_rds.id]
          ]
          period = 60
          stat   = "Average"
          region = "eu-west-1"
          title  = "RDS Database Connections"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.web_alb.arn_suffix, "TargetGroup", aws_lb_target_group.web_tg.arn_suffix]
          ]
          period = 60
          stat   = "Average"
          region = "eu-west-1"
          title  = "ALB Target Response Time"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EBS", "VolumeReadOps", "resourceTag/Service", "web"],
            [".", "VolumeWriteOps", ".", ".", { "stat" : "Sum" }]
          ]
          period = 60
          stat   = "Average"
          region = "eu-west-1"
          title  = "EBS Volume Read/Write Ops (web)"
        }
      }
    ] }
  )
}

###############################
# CloudWatch Alarms for FIS Stop Conditions

################################
# ALB 5XX Errors, Latency
resource "aws_cloudwatch_metric_alarm" "alb_5xx_alarm" {
  alarm_name          = "ALB-High-5XX-Errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 60
  threshold           = 5
  statistic           = "Sum"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"

  dimensions = {
    LoadBalancer = aws_lb.web_alb.arn_suffix
  }

  alarm_description  = "Stop FIS if too many 5XX responses detected on ALB"
  treat_missing_data = "notBreaching"

  alarm_actions = [] # pas d'action directe, utilisée comme stop condition FIS

  tags = {
    project = "fis-poc"
    type    = "stop-condition"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_latency_alarm" {
  alarm_name          = "ALB-High-Latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 60
  threshold           = 0.5 # 500 ms
  statistic           = "Average"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"

  dimensions = {
    TargetGroup  = aws_lb_target_group.web_tg.arn_suffix
    LoadBalancer = aws_lb.web_alb.arn_suffix
  }

  alarm_description  = "Stop FIS if latency exceeds 500ms average"
  treat_missing_data = "notBreaching"
  alarm_actions      = []

  tags = {
    project = "fis-poc"
    type    = "stop-condition"
  }
}

################################
# RDS Database Connections
resource "aws_cloudwatch_metric_alarm" "rds_connections_alarm" {
  alarm_name          = "RDS-High-Connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 60
  threshold           = 20
  statistic           = "Average"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.web_rds.id
  }

  alarm_description  = "Stop FIS if RDS connection count becomes too high"
  treat_missing_data = "notBreaching"
  alarm_actions      = []

  tags = {
    project = "fis-poc"
    type    = "stop-condition"
  }
}

###############################
# CloudWatch Log Group for FIS Experiment Logs
resource "aws_cloudwatch_log_group" "fis_experiment_logs" {
  name              = "/aws/fis/experiments/${local.prefix}-fis-experiments"
  retention_in_days = 30

  tags = {
    project = "fis-poc"
    type    = "experiment-logs"
  }
}


###############################
# EBS Disk Latency Alarms (Read / Write)
###############################
/*

resource "aws_cloudwatch_metric_alarm" "ebs_read_latency_alarm" {
  for_each           = toset(data.aws_ebs_volumes.web.ids)
  alarm_name          = "EBS-${each.key}-High-Read-Latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 60
  threshold           = 3 # 3000ms
  statistic           = "Average"
  metric_name         = "VolumeTotalReadTime"
  namespace           = "AWS/EBS"
  alarm_description   = "Stop FIS if read latency exceeds 3000ms"
  treat_missing_data  = "notBreaching"
  alarm_actions       = []

  dimensions = {
    VolumeId = each.key
  }

  tags = {
    project = "fis-poc"
    type    = "stop-condition"
  }
}

resource "aws_cloudwatch_metric_alarm" "ebs_write_latency_alarm" {
  for_each           = toset(data.aws_ebs_volumes.web.ids)
  alarm_name          = "EBS-${each.key}-High-Write-Latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 60
  threshold           = 3 # 3000ms
  statistic           = "Average"
  metric_name         = "VolumeTotalWriteTime"
  namespace           = "AWS/EBS"
  alarm_description   = "Stop FIS if write latency exceeds 3000ms"
  treat_missing_data  = "notBreaching"
  alarm_actions       = []

  dimensions = {
    VolumeId = each.key
  }

  tags = {
    project = "fis-poc"
    type    = "stop-condition"
  }
}
*/