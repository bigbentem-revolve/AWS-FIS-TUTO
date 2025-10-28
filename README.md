# AWS Fault Injection Service

## Du Plan de Reprise d’Activité à l’expérimentation du Chaos

Implémenter AWS FIS pour valider la résilience dans le Cloud. Ce dépôt fournit un exemple de template FIS, un dashboard CloudWatch et des alarmes pour arrêter l'expérience si des seuils critiques sont atteints.

### But

- Exemple de template AWS FIS pour tester la résilience : terminer une instance EC2 d'un ASG et injecter de la latence I/O sur les volumes EBS.
- Fournit également un dashboard CloudWatch et des alarmes (certaines alarmes EBS sont commentées par défaut).

### Prérequis

- Terraform (>= 1.0)
- AWS CLI configuré (credentials / profile) ou variables d'environnement AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
- Compte AWS avec droits suffisants pour créer IAM, EC2, CloudWatch, FIS, S3, RDS, ALB, CloudWatch Logs

### Ce qui est déployé (fichiers principaux)

Voici une vue synthétique des fichiers et des ressources qu'ils définissent dans ce projet :

- `fis.tf`
  - `aws_fis_experiment_template.web_instance_failure` : template FIS principal
    - targets : `WebInstances` (instances taggées `Service=web`), `Volumes-Target-azA` et `Volumes-Target-azB` (volumes EBS filtrés par zone/tags)
    - actions : `TerminateInstance` (terminer une instance) et `Volume_IO_Latency_*` (injecter latence I/O sur volumes EBS)
    - stop_conditions : références vers alarmes CloudWatch (ALB, RDS, et possibilité d'alarmes EBS)
    - configuration de rapport d'expérience (S3) et logs CloudWatch

- `cloudwatch.tf`
  - `aws_cloudwatch_dashboard.fis_dashboard` : dashboard CloudWatch pour monitoring FIS
  - alarmes : `aws_cloudwatch_metric_alarm.alb_5xx_alarm`, `alb_latency_alarm`, `rds_connections_alarm`
  - (optionnel/commenté) alarmes EBS pour latence read/write (créées par `for_each` sur les volumes)

- `main.tf`
  - VPC, subnets, security groups, ALB (`aws_lb.web_alb`), target group (`aws_lb_target_group.web_tg`), launch template (`aws_launch_template.web_lt`) et autoscaling group (`aws_autoscaling_group.web_asg`)

- `iam.tf`
  - rôle IAM pour FIS (`aws_iam_role.fis_experiment_role`) et policies requises

- `keypair.tf`, `provider.tf`, `local.tf`, `data.tf`, `output.tf` : configuration AWS, données (AMIs, volumes...), outputs et variables locales

- `userdata.sh` : script d'init pour les instances

- `fis_subnet.tf`, `fis_ecs.tf.exemple` : exemples et snippets supplémentaires pour cibler des sous-réseaux ou ECS (exemple)

- `errored.tfstate`, `log/`, `results/` : fichiers d'état et données de sortie (logs, résultats)

Remarque : certaines ressources (par ex. volumes EBS recherchés via `data.aws_ebs_volumes`) sont attendues par les alarmes EBS/commentaires — adaptez ou fournissez les data sources si nécessaire.

## Arborescence du dépôt

Arbre simplifié des fichiers à la racine du projet :

```text
.git/
.gitignore
.terraform/
.terraform.lock.hcl
README.md
cloudwatch.tf
data.tf
errored.tfstate
fis.tf
fis_ecs.tf.exemple
fis_subnet.tf
iam.tf
keypair.tf
local.tf
log/
main.tf
output.tf
provider.tf
results/
userdata.sh
```

Si tu veux que je génère un arbre plus détaillé (avec fichiers dans `log/` ou `results/`), je peux lister et l'ajouter.

### Points d'attention / actions manuelles possibles

- Alarmes EBS
  - Les alarmes EBS sont commentées dans `cloudwatch.tf`. Si vous souhaitez que les `stop_conditions` dynamiques dans `fis.tf` soient valides, décommentez les ressources `aws_cloudwatch_metric_alarm` (ebs_read_latency_alarm / ebs_write_latency_alarm) et exécutez `terraform apply`.
  - Alternative : si vous ne voulez pas créer ces alarmes, supprimez les blocs `dynamic "stop_condition"` dans `fis.tf` pour éviter des références vides.

- Permissions pour le rôle FIS
  - L'action `aws:ebs:volume-io-latency` nécessite des permissions SSM/EC2. Assurez-vous que `aws_iam_role.fis_experiment_role` a les permissions nécessaires (ex. `ec2:Describe*`, `ec2:AttachVolume`, `ec2:DetachVolume`, `ssm:SendCommand`, `iam:PassRole`). Pour test rapide, attachez les policies managées `AmazonEC2FullAccess` et `AmazonSSMFullAccess` (à restreindre ensuite).

## Exemples de commandes

```bash
# Initialiser et planifier
terraform init
terraform plan -var="region=eu-west-1"

# Appliquer
terraform apply -var="region=eu-west-1"

# Pour déployer uniquement le dashboard et les alarmes (si modifications ciblées)
terraform apply -target=aws_cloudwatch_dashboard.fis_dashboard -target=aws_cloudwatch_metric_alarm.alb_5xx_alarm
```

## Dépannage rapide

- Erreur "Missing resource instance key" : signifie qu'on tente d'accéder à une ressource créée avec `for_each` sans index ; utiliser `aws_cloudwatch_metric_alarm.name[key]` ou générer dynamiquement les `stop_condition` (cf. `fis.tf`).
- Erreur FIS `AuthorizationFailure` pendant une action (ex. `volume-io-latency`) : attacher aux IAM role les permissions SSM/EC2 nécessaires.

### Commandes utiles (attention : opérations destructrices)

```bash
# Pour forcer suppression d'un volume EBS (danger : perte de données)
aws ec2 detach-volume --volume-id vol-0f67b384aa1bd9ee7 --force --region eu-west-1
aws ec2 wait volume-available --volume-ids vol-0f67b384aa1bd9ee7 --region eu-west-1
aws ec2 delete-volume --volume-id vol-0f67b384aa1bd9ee7 --region eu-west-1

# Pour supprimer un secret immédiatement (Secrets Manager)
aws secretsmanager delete-secret --secret-id <nom-ou-arn> --force-delete-without-recovery --region eu-west-1
```

## Bonnes pratiques

- Restreindre les permissions IAM du rôle FIS à un policy minimal pour production.
- Tester d'abord sur un compte ou environnement non critique.
- Vérifier que les tags `Service=web` existent bien sur vos volumes/instances attendus.

## Auteurs

- Benjamin TOULOT-VERDIER — Devoteam A Cloud

  - Société : Devoteam A Cloud
  - Site : [https://www.devoteam.com](https://www.devoteam.com)
  - Pour toute question ou contribution : ouvrez une issue dans ce dépôt ou contactez l'auteur via les canaux internes de votre organisation.

## Liens utiles

- Terraform resource (AWS FIS experiment template) : [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/fis_experiment_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/fis_experiment_template)
- AWS Fault Injection Service (FIS) — documentation utilisateur : [https://docs.aws.amazon.com/fis/latest/userguide/what-is-fis.html](https://docs.aws.amazon.com/fis/latest/userguide/what-is-fis.html)
- CloudWatch Metric Alarm (docs) : [https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
# AWS Fault Injection Service

## Du Plan de Reprise d’Activité à l’expérimentation du Chaos - Implémenter AWS FIS pour valider la résilience dans le Cloud


### But

- Exemple de template AWS FIS pour tester la résilience : terminer une instance EC2 d'un ASG et injecter de la latence I/O sur les volumes EBS.
- Fournit également un dashboard CloudWatch et des alarmes (certaines alarmes EBS sont commentées par défaut).

### Prérequis

- Terraform (>= 1.0)
- AWS CLI configuré (credentials / profile) ou variables d'environnement AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
- Compte AWS avec droits suffisants pour créer IAM, EC2, CloudWatch, FIS, S3, RDS, ALB, CloudWatch Logs

### Ce qui est déployé (fichiers principaux)

Voici une vue synthétique des fichiers et des ressources qu'ils définissent dans ce projet :

- `fis.tf`
  - `aws_fis_experiment_template.web_instance_failure` : template FIS principal
    - targets : `WebInstances` (instances taggées `Service=web`), `Volumes-Target-azA` et `Volumes-Target-azB` (volumes EBS filtrés par zone/tags)
    - actions : `TerminateInstance` (terminer une instance) et `Volume_IO_Latency_*` (injecter latence I/O sur volumes EBS)
    - stop_conditions : références vers alarmes CloudWatch (ALB, RDS, et possibilité d'alarmes EBS)
    - configuration de rapport d'expérience (S3) et logs CloudWatch

- `cloudwatch.tf`
  - `aws_cloudwatch_dashboard.fis_dashboard` : dashboard CloudWatch pour monitoring FIS
  - alarmes : `aws_cloudwatch_metric_alarm.alb_5xx_alarm`, `alb_latency_alarm`, `rds_connections_alarm`
  - (optionnel/commenté) alarmes EBS pour latence read/write (créées par `for_each` sur les volumes)

- `main.tf`
  - VPC, subnets, security groups, ALB (`aws_lb.web_alb`), target group (`aws_lb_target_group.web_tg`), launch template (`aws_launch_template.web_lt`) et autoscaling group (`aws_autoscaling_group.web_asg`)

- `iam.tf`
  - rôle IAM pour FIS (`aws_iam_role.fis_experiment_role`) et policies requises

- `keypair.tf`, `provider.tf`, `local.tf`, `data.tf`, `output.tf` : configuration AWS, données (AMIs, volumes...), outputs et variables locales

- `userdata.sh` : script d'init pour les instances

- `fis_subnet.tf`, `fis_ecs.tf.exemple` : exemples et snippets supplémentaires pour cibler des sous-réseaux ou ECS (exemple)

- `errored.tfstate`, `log/`, `results/` : fichiers d'état et données de sortie (logs, résultats)

Remarque : certaines ressources (par ex. volumes EBS recherchés via `data.aws_ebs_volumes`) sont attendues par les alarmes EBS/commentaires — adaptez ou fournissez les data sources si nécessaire.
# AWS Fault Injection Service

## Du Plan de Reprise d’Activité à l’expérimentation du Chaos

Implémenter AWS FIS pour valider la résilience dans le Cloud. Ce dépôt fournit un exemple de template FIS, un dashboard CloudWatch et des alarmes pour arrêter l'expérience si des seuils critiques sont atteints.

### But

- Exemple de template AWS FIS pour tester la résilience : terminer une instance EC2 d'un ASG et injecter de la latence I/O sur les volumes EBS.
- Fournit également un dashboard CloudWatch et des alarmes (certaines alarmes EBS sont commentées par défaut).

### Prérequis

- Terraform (>= 1.0)
- AWS CLI configuré (credentials / profile) ou variables d'environnement AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
- Compte AWS avec droits suffisants pour créer IAM, EC2, CloudWatch, FIS, S3, RDS, ALB, CloudWatch Logs

### Ce qui est déployé (fichiers principaux)

Voici une vue synthétique des fichiers et des ressources qu'ils définissent dans ce projet :

- `fis.tf`
  - `aws_fis_experiment_template.web_instance_failure` : template FIS principal
    - targets : `WebInstances` (instances taggées `Service=web`), `Volumes-Target-azA` et `Volumes-Target-azB` (volumes EBS filtrés par zone/tags)
    - actions : `TerminateInstance` (terminer une instance) et `Volume_IO_Latency_*` (injecter latence I/O sur volumes EBS)
    - stop_conditions : références vers alarmes CloudWatch (ALB, RDS, et possibilité d'alarmes EBS)
    - configuration de rapport d'expérience (S3) et logs CloudWatch

- `cloudwatch.tf`
  - `aws_cloudwatch_dashboard.fis_dashboard` : dashboard CloudWatch pour monitoring FIS
  - alarmes : `aws_cloudwatch_metric_alarm.alb_5xx_alarm`, `alb_latency_alarm`, `rds_connections_alarm`
  - (optionnel/commenté) alarmes EBS pour latence read/write (créées par `for_each` sur les volumes)

- `main.tf`
  - VPC, subnets, security groups, ALB (`aws_lb.web_alb`), target group (`aws_lb_target_group.web_tg`), launch template (`aws_launch_template.web_lt`) et autoscaling group (`aws_autoscaling_group.web_asg`)

- `iam.tf`
  - rôle IAM pour FIS (`aws_iam_role.fis_experiment_role`) et policies requises

- `keypair.tf`, `provider.tf`, `local.tf`, `data.tf`, `output.tf` : configuration AWS, données (AMIs, volumes...), outputs et variables locales

- `userdata.sh` : script d'init pour les instances

- `fis_subnet.tf`, `fis_ecs.tf.exemple` : exemples et snippets supplémentaires pour cibler des sous-réseaux ou ECS (exemple)

- `errored.tfstate`, `log/`, `results/` : fichiers d'état et données de sortie (logs, résultats)

Remarque : certaines ressources (par ex. volumes EBS recherchés via `data.aws_ebs_volumes`) sont attendues par les alarmes EBS/commentaires — adaptez ou fournissez les data sources si nécessaire.

## Arborescence du dépôt

Arbre simplifié des fichiers à la racine du projet :

```text
.git/
.gitignore
.terraform/
.terraform.lock.hcl
README.md
cloudwatch.tf
data.tf
errored.tfstate
fis.tf
fis_ecs.tf.exemple
fis_subnet.tf
iam.tf
keypair.tf
local.tf
log/
main.tf
output.tf
provider.tf
results/
userdata.sh
```

Si tu veux que je génère un arbre plus détaillé (avec fichiers dans `log/` ou `results/`), je peux lister et l'ajouter.

### Points d'attention / actions manuelles possibles

- Alarmes EBS
  - Les alarmes EBS sont commentées dans `cloudwatch.tf`. Si vous souhaitez que les `stop_conditions` dynamiques dans `fis.tf` soient valides, décommentez les ressources `aws_cloudwatch_metric_alarm` (ebs_read_latency_alarm / ebs_write_latency_alarm) et exécutez `terraform apply`.
  - Alternative : si vous ne voulez pas créer ces alarmes, supprimez les blocs `dynamic "stop_condition"` dans `fis.tf` pour éviter des références vides.

- Permissions pour le rôle FIS
  - L'action `aws:ebs:volume-io-latency` nécessite des permissions SSM/EC2. Assurez-vous que `aws_iam_role.fis_experiment_role` a les permissions nécessaires (ex. `ec2:Describe*`, `ec2:AttachVolume`, `ec2:DetachVolume`, `ssm:SendCommand`, `iam:PassRole`). Pour test rapide, attachez les policies managées `AmazonEC2FullAccess` et `AmazonSSMFullAccess` (à restreindre ensuite).

## Exemples de commandes

```bash
# Initialiser et planifier
terraform init
terraform plan -var="region=eu-west-1"

# Appliquer
terraform apply -var="region=eu-west-1"

# Pour déployer uniquement le dashboard et les alarmes (si modifications ciblées)
terraform apply -target=aws_cloudwatch_dashboard.fis_dashboard -target=aws_cloudwatch_metric_alarm.alb_5xx_alarm
```

## Dépannage rapide

- Erreur "Missing resource instance key" : signifie qu'on tente d'accéder à une ressource créée avec `for_each` sans index ; utiliser `aws_cloudwatch_metric_alarm.name[key]` ou générer dynamiquement les `stop_condition` (cf. `fis.tf`).
- Erreur FIS `AuthorizationFailure` pendant une action (ex. `volume-io-latency`) : attacher aux IAM role les permissions SSM/EC2 nécessaires.

### Commandes utiles (attention : opérations destructrices)

```bash
# Pour forcer suppression d'un volume EBS (danger : perte de données)
aws ec2 detach-volume --volume-id vol-0f67b384aa1bd9ee7 --force --region eu-west-1
aws ec2 wait volume-available --volume-ids vol-0f67b384aa1bd9ee7 --region eu-west-1
aws ec2 delete-volume --volume-id vol-0f67b384aa1bd9ee7 --region eu-west-1

# Pour supprimer un secret immédiatement (Secrets Manager)
aws secretsmanager delete-secret --secret-id <nom-ou-arn> --force-delete-without-recovery --region eu-west-1
```

## Bonnes pratiques

- Restreindre les permissions IAM du rôle FIS à un policy minimal pour production.
- Tester d'abord sur un compte ou environnement non critique.
- Vérifier que les tags `Service=web` existent bien sur vos volumes/instances attendus.

## Auteurs

- Benjamin TOULOT-VERDIER — Devoteam A Cloud

  - Société : Devoteam A Cloud
  - Site : [https://www.devoteam.com](https://www.devoteam.com)
  - Pour toute question ou contribution : ouvrez une issue dans ce dépôt ou contactez l'auteur via les canaux internes de votre organisation.

## Liens utiles

- Terraform resource (AWS FIS experiment template) : [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/fis_experiment_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/fis_experiment_template)
- AWS Fault Injection Service (FIS) — documentation utilisateur : [https://docs.aws.amazon.com/fis/latest/userguide/what-is-fis.html](https://docs.aws.amazon.com/fis/latest/userguide/what-is-fis.html)
- CloudWatch Metric Alarm (docs) : [https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
