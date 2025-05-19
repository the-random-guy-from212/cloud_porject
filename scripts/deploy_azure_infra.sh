#!/bin/bash

# Script de déploiement d'infrastructure Azure
# Ce script crée:
# - Deux réseaux virtuels avec peering
# - Une VM MySQL et une VM Web
# - Un compte de stockage avec partage Azure Files

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Variables de configuration
RESOURCE_GROUP=$(az group list --query "[0].name" -o tsv)
LOCATION="westus"
ADMIN_USERNAME="hassan"
ADMIN_PASSWORD="P@ssw0rd123456"
UNIQUE_SUFFIX="idosr$(date +%d%H%M)"
STORAGE_ACCOUNT_NAME="storageaccount${UNIQUE_SUFFIX}"
SHARE_NAME="myshare00"

# Fonction pour afficher les messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérification de la connexion Azure
print_message "Vérification de la connexion Azure..."
az account show &> /dev/null || { print_error "Vous n'êtes pas connecté à Azure. Exécutez 'az login'."; exit 1; }

# Partie I: Création des réseaux virtuels et peering
create_virtual_networks() {
    print_message "Création du réseau virtuel Vnet-BD..."
    az network vnet create \
        --resource-group $RESOURCE_GROUP \
        --name "Vnet-BD" \
        --address-prefixes "10.10.0.0/16" \
        --location $LOCATION \
        --output none

    print_message "Création du sous-réseau SR-BD..."
    az network vnet subnet create \
        --resource-group $RESOURCE_GROUP \
        --vnet-name "Vnet-BD" \
        --name "SR-BD" \
        --address-prefixes "10.10.1.0/24" \
        --output none

    print_message "Création du réseau virtuel Vnet-WEB..."
    az network vnet create \
        --resource-group $RESOURCE_GROUP \
        --name "Vnet-WEB" \
        --address-prefixes "10.20.0.0/16" \
        --location $LOCATION \
        --output none

    print_message "Création du sous-réseau SR-WEB..."
    az network vnet subnet create \
        --resource-group $RESOURCE_GROUP \
        --vnet-name "Vnet-WEB" \
        --name "SR-WEB" \
        --address-prefixes "10.20.1.0/24" \
        --output none

    print_message "Configuration du peering BD vers WEB..."
    az network vnet peering create \
        --resource-group $RESOURCE_GROUP \
        --name "Peering-BD-to-WEB" \
        --vnet-name "Vnet-BD" \
        --remote-vnet "Vnet-WEB" \
        --allow-vnet-access \
        --output none

    print_message "Configuration du peering WEB vers BD..."
    az network vnet peering create \
        --resource-group $RESOURCE_GROUP \
        --name "Peering-WEB-to-BD" \
        --vnet-name "Vnet-WEB" \
        --remote-vnet "Vnet-BD" \
        --allow-vnet-access \
        --output none
}

# Partie II: Création des machines virtuelles
create_virtual_machines() {
    print_message "Création de la VM BD (serveur MySQL)..."
    az vm create \
        --resource-group $RESOURCE_GROUP \
        --name "serveur-bd-${UNIQUE_SUFFIX}" \
        --image "UbuntuLTS" \
        --admin-username $ADMIN_USERNAME \
        --admin-password $ADMIN_PASSWORD \
        --vnet-name "Vnet-BD" \
        --subnet "SR-BD" \
        --size "Standard_B2s" \
        --nsg-rule SSH \
        --public-ip-address-allocation static \
        --output none

    print_message "Création de la VM WEB (serveur Apache)..."
    az vm create \
        --resource-group $RESOURCE_GROUP \
        --name "serveur-web-${UNIQUE_SUFFIX}" \
        --image "UbuntuLTS" \
        --admin-username $ADMIN_USERNAME \
        --admin-password $ADMIN_PASSWORD \
        --vnet-name "Vnet-WEB" \
        --subnet "SR-WEB" \
        --size "Standard_B2s" \
        --nsg-rule SSH \
        --public-ip-address-allocation static \
        --output none

    # Ouvrir le port 80 sur la VM WEB
    print_message "Ouverture du port 80 sur la VM WEB..."
    az vm open-port \
        --resource-group $RESOURCE_GROUP \
        --name "serveur-web-${UNIQUE_SUFFIX}" \
        --port 80 \
        --output none
}

# Partie III: Création du compte de stockage et du partage
create_storage_account() {
    print_message "Création du compte de stockage..."
    az storage account create \
        --resource-group $RESOURCE_GROUP \
        --name $STORAGE_ACCOUNT_NAME \
        --location $LOCATION \
        --sku "Premium_LRS" \
        --kind "FileStorage" \
        --https-only true \
        --output none

    # Récupérer la clé du compte de stockage
    STORAGE_KEY=$(az storage account keys list \
        --resource-group $RESOURCE_GROUP \
        --account-name $STORAGE_ACCOUNT_NAME \
        --query "[0].value" \
        --output tsv)

    print_message "Création du partage de fichiers..."
    az storage share create \
        --account-name $STORAGE_ACCOUNT_NAME \
        --account-key $STORAGE_KEY \
        --name $SHARE_NAME \
        --quota 100 \
        --output none
}

# Partie IV: Génération des scripts de configuration
generate_config_scripts() {
    # Récupérer les adresses IP
    BD_PUBLIC_IP=$(az vm show -d -g $RESOURCE_GROUP -n "serveur-bd-${UNIQUE_SUFFIX}" --query publicIps -o tsv)
    BD_PRIVATE_IP=$(az vm show -d -g $RESOURCE_GROUP -n "serveur-bd-${UNIQUE_SUFFIX}" --query privateIps -o tsv)
    WEB_PUBLIC_IP=$(az vm show -d -g $RESOURCE_GROUP -n "serveur-web-${UNIQUE_SUFFIX}" --query publicIps -o tsv)
    
    # Récupérer la clé de stockage
    STORAGE_KEY=$(az storage account keys list \
        --resource-group $RESOURCE_GROUP \
        --account-name $STORAGE_ACCOUNT_NAME \
        --query "[0].value" \
        --output tsv)

    print_message "Génération du script SQL pour la VM BD..."
    cat > sql.sh << EOF
#!/bin/bash
# Mettre à jour le système
sudo apt update && sudo apt upgrade -y
# Installer MySQL Server
sudo apt install -y mysql-server
# Activer et démarrer MySQL
sudo systemctl enable mysql
sudo systemctl start mysql
# Autoriser les connexions depuis l'extérieur
sudo sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
# Redémarrer MySQL pour appliquer la config
sudo systemctl restart mysql
# Créer un utilisateur admin 'hassan' et la base 'db_web'
sudo mysql <<EOT
CREATE DATABASE db_web;
CREATE USER 'hassan'@'%' IDENTIFIED BY 'P@ssw0rd123456';
GRANT ALL PRIVILEGES ON db_web.* TO 'hassan'@'%';
FLUSH PRIVILEGES;
EOT
# Ouvrir le port 3306 sur le pare-feu (si UFW est actif)
if sudo ufw status | grep -q active; then
    sudo ufw allow 3306/tcp
fi
echo "MySQL installé, configuré, et base de données 'db_web' prête !"
EOF

    print_message "Génération du script Web pour la VM WEB..."
    cat > web.sh << EOF
#!/bin/bash
# Mettre à jour le système
sudo apt update
# Installer Apache2, PHP et les extensions PHP pour MySQL
sudo apt install -y apache2 php libapache2-mod-php php-mysql
# Créer la page PHP de test
sudo bash -c "cat > /var/www/html/index.php" <<EOT
<?php
\\\$conn = new mysqli('${BD_PRIVATE_IP}', 'hassan', 'P@ssw0rd123456', 'db_web');
if (\\\$conn->connect_error) {
    die('Connexion échouée : ' . \\\$conn->connect_error);
}
echo 'Connexion réussie à la base de données MySQL distante ! <br>';
echo 'Je suis DRAOUI Hassan!';
\\\$conn->close();
?>
EOT
# Redémarrer Apache pour prendre en compte les changements
sudo systemctl restart apache2
echo "Installation terminée. Accédez à http://${WEB_PUBLIC_IP}/index.php pour tester."
EOF

    print_message "Génération du script de connexion au partage Azure Files..."
    cat > connect.sh << EOF
#!/bin/bash
# Variables à modifier par l'utilisateur
STORAGE_ACCOUNT="${STORAGE_ACCOUNT_NAME}"
SHARE_NAME="${SHARE_NAME}"
STORAGE_KEY="${STORAGE_KEY}"
MOUNT_POINT="/mnt/azurefiles"

# Installation des dépendances
echo "Installation de cifs-utils..."
sudo apt update -qq && sudo apt install -y cifs-utils

# Création du dossier de montage
echo "Création du point de montage \$MOUNT_POINT..."
sudo mkdir -p "\$MOUNT_POINT"

# Montage du partage SMB
echo "Montage du partage Azure Files..."
sudo mount -t cifs "//\$STORAGE_ACCOUNT.file.core.windows.net/\$SHARE_NAME" "\$MOUNT_POINT" -o "vers=3.0,username=\$STORAGE_ACCOUNT,password=\$STORAGE_KEY,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30"

# Ajout à /etc/fstab pour le montage automatique
echo "Ajout à /etc/fstab pour le montage au démarrage..."
FSTAB_ENTRY="//\$STORAGE_ACCOUNT.file.core.windows.net/\$SHARE_NAME \$MOUNT_POINT cifs vers=3.0,username=\$STORAGE_ACCOUNT,password=\$STORAGE_KEY,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30 0 0"
if grep -q "\$MOUNT_POINT" /etc/fstab; then
    echo "Une entrée existe déjà dans /etc/fstab pour \$MOUNT_POINT."
else
    echo "\$FSTAB_ENTRY" | sudo tee -a /etc/fstab > /dev/null
    echo "Entrée ajoutée à /etc/fstab."
fi

echo "Partage Azure Files monté avec succès"
EOF

    print_message "Génération du script de sauvegarde MySQL..."
    cat > backup.sh << EOF
#!/bin/bash
# Variables à configurer
MYSQL_USER="hassan"
MYSQL_PASSWORD="P@ssw0rd123456"
AZURE_MOUNT_POINT="/mnt/azurefiles"
BACKUP_DIR="\$AZURE_MOUNT_POINT/mysql_backups"
DAYS_TO_KEEP=7

# Vérification que le partage Azure est monté
if ! mountpoint -q "\$AZURE_MOUNT_POINT"; then
    echo "Erreur: Le partage Azure Files n'est pas monté sur \$AZURE_MOUNT_POINT"
    exit 1
fi

# Création du dossier de sauvegarde
sudo mkdir -p "\$BACKUP_DIR"
sudo chmod 777 "\$BACKUP_DIR"

# Fonction pour effectuer une sauvegarde
perform_backup() {
    local BACKUP_FILE="\$BACKUP_DIR/backup_\$(date +%Y%m%d_%H%M%S).sql.gz"
    echo "Début de la sauvegarde MySQL vers \$BACKUP_FILE..."
    
    # Commande de sauvegarde
    mysqldump -u "\$MYSQL_USER" -p"\$MYSQL_PASSWORD" --all-databases | gzip > "\$BACKUP_FILE"
    
    # Vérification de la sauvegarde
    if [ \$? -eq 0 ] && [ -s "\$BACKUP_FILE" ]; then
        echo "Sauvegarde réussie. Taille: \$(du -h "\$BACKUP_FILE" | cut -f1)"
    else
        echo "Échec de la sauvegarde!"
        rm -f "\$BACKUP_FILE"
        exit 1
    fi
    
    # Nettoyage des anciennes sauvegardes
    find "\$BACKUP_DIR" -name "backup_*.sql.gz" -type f -mtime +\$DAYS_TO_KEEP -delete
    echo "Nettoyage des sauvegardes de plus de \$DAYS_TO_KEEP jours effectué."
}

# Effectuer une sauvegarde immédiate
perform_backup

# Configurer la tâche cron pour minuit chaque jour
CRON_JOB="0 0 * * * \$(which bash) -c '\$(readlink -f "\$0")'"

# Vérifier si la tâche existe déjà
if ! crontab -l 2>/dev/null | grep -qF "\$(readlink -f "\$0")"; then
    (crontab -l 2>/dev/null; echo "\$CRON_JOB") | crontab -
    echo "Tâche cron configurée pour s'exécuter quotidiennement à minuit."
else
    echo "Une tâche cron existe déjà pour ce script."
fi

echo "Configuration terminée!"
echo " - Sauvegardes stockées dans: \$BACKUP_DIR"
EOF
}

# Exécution des fonctions principales
main() {
    print_message "Démarrage du déploiement de l'infrastructure Azure..."
    
    create_virtual_networks
    create_virtual_machines
    create_storage_account
    generate_config_scripts
    
    # Récupérer les adresses IP
    BD_PUBLIC_IP=$(az vm show -d -g $RESOURCE_GROUP -n "serveur-bd-${UNIQUE_SUFFIX}" --query publicIps -o tsv)
    BD_PRIVATE_IP=$(az vm show -d -g $RESOURCE_GROUP -n "serveur-bd-${UNIQUE_SUFFIX}" --query privateIps -o tsv)
    WEB_PUBLIC_IP=$(az vm show -d -g $RESOURCE_GROUP -n "serveur-web-${UNIQUE_SUFFIX}" --query publicIps -o tsv)
    
    print_message "Déploiement terminé avec succès!"
    echo ""
    echo "Informations sur l'infrastructure:"
    echo "--------------------------------"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Région: $LOCATION"
    echo ""
    echo "VM BD:"
    echo "  Nom: serveur-bd-${UNIQUE_SUFFIX}"
    echo "  IP Publique: $BD_PUBLIC_IP"
    echo "  IP Privée: $BD_PRIVATE_IP"
    echo ""
    echo "VM WEB:"
    echo "  Nom: serveur-web-${UNIQUE_SUFFIX}"
    echo "  IP Publique: $WEB_PUBLIC_IP"
    echo ""
    echo "Compte de stockage:"
    echo "  Nom: $STORAGE_ACCOUNT_NAME"
    echo "  Partage: $SHARE_NAME"
    echo ""
    echo "Scripts générés localement:"
    echo "  - sql.sh : Pour installer MySQL sur la VM BD"
    echo "  - web.sh : Pour installer Apache/PHP sur la VM WEB"
    echo "  - connect.sh : Pour monter le partage Azure Files"
    echo "  - backup.sh : Pour configurer les sauvegardes MySQL"
    echo ""
    echo "Instructions:"
    echo "1. Déployez sql.sh sur la VM BD: scp sql.sh ${ADMIN_USERNAME}@${BD_PUBLIC_IP}:"
    echo "2. Déployez web.sh sur la VM WEB: scp web.sh ${ADMIN_USERNAME}@${WEB_PUBLIC_IP}:"
    echo "3. Déployez connect.sh et backup.sh sur la VM BD"
    echo ""
    echo "Pour supprimer l'IP publique de la VM BD après configuration, exécutez:"
    echo "az network public-ip delete -g $RESOURCE_GROUP -n 'serveur-bd-${UNIQUE_SUFFIX}PublicIP'"
}

# Démarrage du script
main