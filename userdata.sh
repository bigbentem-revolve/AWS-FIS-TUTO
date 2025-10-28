#!/bin/bash
# userdata minimal pour instances web
sudo yum update -y
sudo yum install -y httpd
sudo systemctl enable --now httpd
echo "<h1>Tutorile pour un démonstrateur AWS Fault Integration Simultor</h1><h2>Création d'une infrastructure de test pour la démonstration FIS<h2>" | sudo tee /var/www/html/index.html
