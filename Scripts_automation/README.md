# README - Déploiement d'Infrastructure Azure

Ce projet contient deux méthodes pour déployer une infrastructure Azure complète comprenant des réseaux virtuels avec peering, des machines virtuelles (BD MySQL et serveur Web), ainsi qu'un compte de stockage avec un partage Azure Files.

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Prérequis](#prérequis)
3. [Solution Bash (Azure CLI)](#solution-bash-azure-cli)
4. [Solution Terraform](#solution-terraform)
5. [Architecture déployée](#architecture-déployée)
6. [Sécurisation pour la production](#sécurisation-pour-la-production)
7. [Surveillance et maintenance](#surveillance-et-maintenance)
8. [Résolution des problèmes](#résolution-des-problèmes)

## Vue d'ensemble

L'infrastructure déployée comprend:

- **Réseaux virtuels**:
  - VNet-BD (10.10.0.0/16) avec sous-réseau SR-BD (10.10.1.0/24)
  - VNet-WEB (10.20.0.0/16) avec sous-réseau SR-WEB (10.20.1.0/24)
  - Peering bidirectionnel entre les deux VNets

- **Machines Virtuelles**:
  - VM BD (MySQL): Ubuntu 22.04 LTS dans le sous-réseau SR-BD
  - VM WEB (Apache/PHP): Ubuntu 22.04 LTS dans le sous-réseau SR-WEB

- **Stockage**:
  - Compte de stockage Azure Premium
  - Partage Azure Files monté sur la VM BD
  - Sauvegarde quotidienne de MySQL vers Azure Files

## Prérequis

### Commun aux deux méthodes

- Un abonnement Azure actif
- Droits de création de ressources dans l'abonnement

### Pour la solution Bash (Azure CLI)

- Azure CLI installé et configuré (`az login` effectué)
- Bash ou shell compatible (Linux, macOS, WSL sur Windows)

### Pour la solution Terraform

- Terraform v1.0.0 ou supérieur installé
- Azure CLI installé et configuré (`az login` effectué)

## Solution Bash (Azure CLI)

### Installation

1. Téléchargez le script `deploy_azure_infra.sh`
2. Rendez-le exécutable:
   ```bash
   chmod +x deploy_azure_infra.sh
   ```

### Utilisation

**Pour déployer l'infrastructure:**

```bash
./deploy_azure_infra.sh
```

Le script:
1. Crée les réseaux virtuels et configure le peering
2. Déploie les machines virtuelles
3. Crée le compte de stockage et le partage Azure Files
4. Génère des scripts de configuration pour:
   - Installation et configuration de MySQL
   - Installation d'Apache/PHP avec une page de test
   - Montage du partage Azure Files
   - Configuration des sauvegardes MySQL

Après le déploiement, le script affiche les informations importantes comme les adresses IP des VMs et des instructions pour finaliser la configuration.

**Pour nettoyer toutes les ressources créées:**

```bash
./deploy_azure_infra.sh --cleanup
```

### Configuration post-déploiement

Après le déploiement, vous devez transférer et exécuter les scripts générés sur les VMs:

1. **Sur la VM BD (MySQL)**:
   ```bash
   scp sql.sh hassan@<IP_VM_BD>:
   scp connect.sh hassan@<IP_VM_BD>:
   scp backup.sh hassan@<IP_VM_BD>:
   ssh hassan@<IP_VM_BD>
   chmod +x sql.sh && sudo ./sql.sh
   chmod +x connect.sh && sudo ./connect.sh
   chmod +x backup.sh && sudo ./backup.sh
   ```

2. **Sur la VM WEB (Apache/PHP)**:
   ```bash
   scp web.sh hassan@<IP_VM_WEB>:
   ssh hassan@<IP_VM_WEB>
   chmod +x web.sh && sudo ./web.sh
   ```

3. **Accès à l'application**:
   - Ouvrez un navigateur et accédez à `http://<IP_VM_WEB>/index.php`

4. **Sécurisation (optionnelle) - Suppression de l'IP publique de la VM BD**:
   ```bash
   az network public-ip delete -g <RESOURCE_GROUP> -n 'serveur-bd-*PublicIP'
   ```

## Solution Terraform

### Installation

1. Téléchargez les fichiers `main.tf` et `variables.tf` (optionnel)
2. Initialisez le projet Terraform:
   ```bash
   terraform init
   ```

### Utilisation

**Pour déployer l'infrastructure:**

1. Validez la configuration:
   ```bash
   terraform plan
   ```

2. Déployez l'infrastructure:
   ```bash
   terraform apply
   ```

3. Confirmez avec `yes` lorsque demandé

Terraform déploie automatiquement l'infrastructure complète, y compris la configuration des VMs et le montage du partage Azure Files, sans nécessiter de configuration manuelle post-déploiement.

**Pour détruire l'infrastructure:**

```bash
terraform destroy
```

### Configuration post-déploiement

Contrairement à la solution Bash, Terraform configure automatiquement les VMs via des extensions. Une fois le déploiement terminé:

1. **Accès à l'application**:
   - L'URL est affichée dans les outputs Terraform

2. **Connexion SSH aux VMs**:
   - Les commandes SSH sont affichées dans les outputs Terraform

## Architecture déployée

```
+------------------+       Peering        +------------------+
|                  |<------------------->|                  |
|  VNet-BD         |                     |  VNet-WEB        |
|  10.10.0.0/16    |                     |  10.20.0.0/16    |
|                  |                     |                  |
|  +------------+  |                     |  +------------+  |
|  |            |  |                     |  |            |  |
|  | VM-BD      |  |                     |  | VM-WEB     |  |
|  | (MySQL)    |  |                     |  | (Apache/PHP)|  |
|  |            |  |                     |  |            |  |
|  +-----+------+  |                     |  +------------+  |
|        |         |                     |                  |
+--------|----------                     +------------------+
         |
         v
+------------------+
|                  |
|  Azure Files     |
|  (Stockage +     |
|   Sauvegardes)   |
|                  |
+------------------+
```

## Sécurisation pour la production

Pour un environnement de production, considérez les améliorations suivantes:

### Réseau

1. **Supprimez les IPs publiques inutiles**:
   - La VM BD ne devrait pas avoir d'IP publique en production
   - Utilisez Azure Bastion pour l'accès SSH sécurisé

2. **Restreignez les règles NSG**:
   - Limitez l'accès SSH aux adresses IP administratives uniquement
   - Limitez l'accès HTTP à votre plage d'IPs d'entreprise si possible

3. **Utilisez un équilibreur de charge avec WAF**:
   - Déployez Azure Application Gateway avec WAF devant les serveurs web

### Authentification

1. **Utilisez des clés SSH au lieu de mots de passe**:
   - Modifiez les scripts pour utiliser l'authentification par clé SSH

2. **Gérez les secrets dans Azure Key Vault**:
   - Stockez les mots de passe, clés et certificats dans Key Vault
   - Mettez à jour les scripts pour récupérer les secrets depuis Key Vault

### Base de données

1. **Utilisez Azure Database for MySQL**:
   - Remplacez la VM MySQL par un service géré Azure Database for MySQL
   - Bénéficiez des sauvegardes automatiques, haute disponibilité et correctifs automatiques

### Stockage

1. **Configurez la réplication géographique**:
   - Utilisez la réplication GRS au lieu de LRS pour le compte de stockage
   - Configurez les sauvegardes Azure pour les VMs

### Surveillance

1. **Activez Azure Monitor et Log Analytics**:
   - Déployez l'agent Log Analytics sur les VMs
   - Configurez des alertes pour les métriques clés

## Surveillance et maintenance

### Installation des agents de surveillance

Pour la solution Bash, ajoutez:

```bash
# Installation de l'agent Log Analytics
az vm extension set \
  --resource-group $RESOURCE_GROUP \
  --vm-name $VM_NAME \
  --name OmsAgentForLinux \
  --publisher Microsoft.EnterpriseCloud.Monitoring \
  --version 1.13 \
  --settings '{"workspaceId":"<WORKSPACE_ID>"}'
```

Pour Terraform, ajoutez:

```hcl
resource "azurerm_virtual_machine_extension" "log_analytics" {
  name                 = "LogAnalyticsAgent"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm_web.id
  publisher            = "Microsoft.EnterpriseCloud.Monitoring"
  type                 = "OmsAgentForLinux"
  type_handler_version = "1.13"
  
  settings = <<SETTINGS
    {
      "workspaceId": "<WORKSPACE_ID>"
    }
  SETTINGS
  
  protected_settings = <<PROTECTED_SETTINGS
    {
      "workspaceKey": "<WORKSPACE_KEY>"
    }
  PROTECTED_SETTINGS
}
```

### Mise à jour du système

Configurez les mises à jour automatiques sur les VMs:

```bash
# Sur Ubuntu 22.04
apt install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

## Résolution des problèmes

### Problèmes de connectivité MySQL

Si la VM WEB ne peut pas se connecter à MySQL:

1. Vérifiez que MySQL écoute sur toutes les interfaces:
   ```bash
   sudo grep bind-address /etc/mysql/mysql.conf.d/mysqld.cnf
   ```

2. Vérifiez que l'utilisateur MySQL a les permissions:
   ```bash
   sudo mysql -e "SELECT User, Host FROM mysql.user WHERE User='hassan';"
   ```

3. Vérifiez les règles de pare-feu:
   ```bash
   sudo ufw status
   ```

### Problèmes de montage Azure Files

1. Vérifiez que cifs-utils est installé:
   ```bash
   sudo apt install cifs-utils
   ```

2. Vérifiez les erreurs de montage:
   ```bash
   sudo mount -t cifs -v //storageaccount.file.core.windows.net/myshare /mnt/azurefiles -o vers=3.0,username=storageaccount,password=key
   ```

3. Vérifiez les journaux:
   ```bash
   dmesg | tail
   ```

---

Pour toute question ou problème, veuillez consulter la documentation officielle d'Azure ou contacter votre administrateur Azure.