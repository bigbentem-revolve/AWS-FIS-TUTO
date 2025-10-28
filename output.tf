# Export de l'ID du Template d'expérimentation FIS
output "fis_experiment_template_id" {
  value = aws_fis_experiment_template.web_instance_failure.id
}

# Export du nom du bucket s3 pour le rapport FIS
output "fis_experiment_report_bucket" {
  value = aws_s3_bucket.fis_experiment_reports.arn
}

# Export de l'URI de l'ALB public
output "alb_uri" {
  value = aws_lb.web_alb.dns_name
}

# Exporte la clé publique pour d’autres modules
output "ec2_public_key" {
  value = tls_private_key.ec2_key.public_key_openssh
}

# Exporte l’ARN du secret contenant la clé privée
output "private_key_secret_arn" {
  value = aws_secretsmanager_secret.ec2_private_key_secret.arn
}
