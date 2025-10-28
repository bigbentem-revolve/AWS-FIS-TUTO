# Génère une paire de clés SSH localement dans Terraform (en mémoire, pas sur ton disque)
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Crée une key pair EC2 à partir de la clé publique générée
resource "aws_key_pair" "ec2_keypair" {
  key_name   = "${local.prefix}-keypair"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Stocke la clé privée dans AWS Secrets Manager
resource "aws_secretsmanager_secret" "ec2_private_key_secret" {
  name        = "${local.prefix}-ec2-private-key"
  description = "Clé privée EC2 utilisée pour les tests FIS"
}

# Enregistre la clé privée générée dans le secret
resource "aws_secretsmanager_secret_version" "ec2_private_key_secret_version" {
  secret_id     = aws_secretsmanager_secret.ec2_private_key_secret.id
  secret_string = tls_private_key.ec2_key.private_key_pem
}
