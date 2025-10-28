##########################
# IAM Role pour FIS
##########################
resource "aws_iam_role" "fis_experiment_role" {
  name = "${local.prefix}-FISExperimentRole"


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "fis.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "fis_experiment_policy" {
  name = "${local.prefix}-FISExperimentPolicy"
  role = aws_iam_role.fis_experiment_role.id


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # FIS actions
      {
        Effect = "Allow"
        Action = [
          "fis:CreateExperiment",
          "fis:StartExperiment",
          "fis:StopExperiment",
          "fis:GetExperiment",
          "fis:GetExperimentTemplate",
          "fis:ListExperiments",
          "fis:ListExperimentTemplates"
        ]
        Resource = "*"
      },
      # EC2 stop/terminate/Latency
      {
        Effect = "Allow"
        Action = [
          "ec2:StopInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:desribeTags",
          "ec2:ModifiyVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:DescribeVolumes",
          "ec2:InjectVolumeIOLatency",
          "ec2:PauseVolumeIO",
          "tag:GetResources"
        ]
        Resource = "*"
      },
      # AutoScaling
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
      },
      # CloudWatch read
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      # Report write
      {
        Effect = "Allow"
        Action = [
          "s3:putObject",
          "S3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.fis_experiment_reports.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.fis_experiment_reports.bucket}/*"
        ]
      },
      # CloudWatch read
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricWidgetImage"
        ]
        Resource = "*"
      },
      # Dashboard access
      {
        Effect = "Allow"
        Action = [
          "CloudWatch:GetDashboard"
        ]
        Resource = ["${aws_cloudwatch_dashboard.fis_dashboard.dashboard_arn}"]
      },
      # CloudWatch access
      {
        Effect = "Allow"
        Action = [
          "CloudWatch:PutLogEvents",
          "CloudWatch:CreateLogStream"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.fis_experiment_logs.arn}",
          "${aws_cloudwatch_log_group.fis_experiment_logs.arn}:*"
        ]
      },
      # CreateLogDelivery
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}