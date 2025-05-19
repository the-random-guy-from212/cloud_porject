# Infrastructure Azure avec Terraform

## Qu'est-ce que Terraform ?

Terraform est un outil d'Infrastructure as Code (IaC) open-source développé par HashiCorp qui permet de créer, modifier et gérer des infrastructures cloud de manière déclarative. Au lieu de configurer manuellement des ressources via des interfaces web ou des commandes CLI, Terraform permet de définir l'infrastructure souhaitée dans des fichiers de configuration et de l'appliquer automatiquement.

## Avantages de Terraform

- **Déclaratif** : Définissez l'état souhaité au lieu de décrire les étapes pour y parvenir
- **Multi-Cloud** : Compatible avec de nombreux fournisseurs (AWS, Azure, Google Cloud, etc.)
- **Versionnable** : Les fichiers de configuration peuvent être versionnés avec Git
- **Plan d'exécution** : Visualisez les changements avant de les appliquer
- **État de l'infrastructure** : Terraform suit l'état actuel de votre infrastructure

## Présentation du script

Ce script Terraform automatise la création d'une infrastructure Azure complète pour une architecture à deux niveaux (web et base de données) avec les éléments suivants :

### Ressources déployées

1. **Réseaux virtuels et Peering**
   - Vnet-BD avec sous-réseau SR-BD (10.10.0.0/16, 10.10.1.0/24)
   - Vnet-WEB avec sous-réseau SR-WEB (10.20.0.0/16, 10.20.1.0/24)
   - Configuration de peering bidirectionnel

2. **Machines virtuelles**
   - Serveur de base de données (serveur-bd-idosr00) avec MySQL
   - Serveur web (serveur-web-idosr00) avec Apache et PHP
   - Groupes de sécurité réseau avec les ports requis

3. **Compte de stockage et partage de fichiers**
   - Compte de stockage premium pour Azure Files
   - Partage de fichiers de 100 Go

4. **Configuration avancée**
   - Scripts d'initialisation personnalisés pour les deux VMs
   - Installation et configuration de MySQL avec création de base de données
   - Installation de PHP avec connexion à MySQL
   - Montage du partage Azure Files
   - Script de sauvegarde MySQL automatisé quotidien

## Prérequis

Pour utiliser ce script Terraform, vous aurez besoin de :

1. **Terraform** : [Télécharger et installer Terraform](https://www.terraform.io/downloads.html)
2. **Azure CLI** : [Installer Azure CLI](https://docs.microsoft.com/fr-fr/cli/azure/install-azure-cli)
3. **Un compte Azure** avec les autorisations nécessaires pour créer des ressources

## Comment utiliser ce script

### 1. Préparation de l'environnement

```bash
# Installer Terraform (exemple pour Linux)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Authentification Azure
az login
```

### 2. Initialisation du projet

```bash
# Créer un dossier pour votre projet
mkdir mon-projet-azure && cd mon-projet-azure

# Copier le fichier main.tf dans ce dossier

# Initialiser Terraform
terraform init
```

### 3. Planifier et appliquer les changements

```bash
# Visualiser les changements à appliquer
terraform plan

# Appliquer les changements (créer l'infrastructure)
terraform apply
```

Lors de l'exécution de `terraform apply`, vous serez invité à confirmer la création des ressources. Tapez `yes` pour continuer.

### 4. Accéder aux ressources

Une fois le déploiement terminé, Terraform affichera les sorties configurées :
- L'adresse IP publique du serveur web
- L'adresse IP publique du serveur de base de données
- La clé d'accès du compte de stockage

Vous pouvez vous connecter aux machines virtuelles via SSH :

```bash
ssh hassan@<adresse_IP_publique>
```

Le mot de passe est : `P@ssw0rd123456`

### 5. Détruire l'infrastructure

Pour supprimer toutes les ressources créées :

```bash
terraform destroy
```

## Détails techniques de l'implémentation

### Structure du réseau

Le script crée deux réseaux virtuels distincts :
- **Vnet-BD** : Réseau pour la base de données avec espace d'adressage 10.10.0.0/16
- **Vnet-WEB** : Réseau pour le serveur web avec espace d'adressage 10.20.0.0/16

Ces réseaux sont connectés par peering pour permettre la communication inter-réseau.

### Configuration du serveur de base de données

Le serveur de base de données est configuré avec :
- Ubuntu 22.04 LTS
- MySQL Server configuré pour accepter les connexions externes
- Une base de données `db_web` et un utilisateur `hassan` avec privilèges
- Ouverture du port SSH (22)

### Configuration du serveur web

Le serveur web est configuré avec :
- Ubuntu 22.04 LTS
- Apache2 et PHP avec le module MySQL
- Une page PHP qui se connecte à la base de données distante
- Ouverture des ports SSH (22) et HTTP (80)

### Stockage et sauvegardes

Le script configure :
- Un compte de stockage premium pour Azure Files
- Un partage de fichiers monté sur la VM du serveur de base de données
- Un script de sauvegarde automatique qui :
  - Sauvegarde toutes les bases de données MySQL quotidiennement
  - Stocke les sauvegardes dans le partage Azure Files
  - Supprime les sauvegardes de plus de 7 jours

## Personnalisation

Vous pouvez facilement personnaliser ce script en modifiant :
- Les noms des ressources
- Les tailles des machines virtuelles
- Les plages d'adresses IP
- Les configurations de sécurité
- Les scripts d'initialisation

Pour modifier le script, ouvrez le fichier `main.tf` dans un éditeur de texte et apportez les modifications souhaitées.

## Bonnes pratiques

1. **Ne stockez jamais de mots de passe ou de clés sensibles directement dans les fichiers Terraform**
   - Utilisez plutôt des variables d'environnement ou un coffre-fort sécurisé

2. **Utilisez des modules pour les composants réutilisables**
   - Ce script pourrait être réorganisé en modules pour une meilleure structuration

3. **Testez toujours avec `terraform plan` avant d'appliquer**
   - Cela vous permet de vérifier les modifications avant de les appliquer

4. **Utilisez un backend distant pour stocker l'état**
   - Pour le travail en équipe, stockez l'état dans un backend distant comme Azure Storage

## Dépannage

### Problèmes courants

1. **Erreur d'authentification Azure**
   ```
   Solution : Exécutez `az login` pour vous authentifier
   ```

2. **Conflits de noms de ressources**
   ```
   Solution : Modifiez les noms de ressources qui doivent être uniques (comme le compte de stockage)
   ```

3. **Quotas Azure dépassés**
   ```
   Solution : Vérifiez vos quotas dans le portail Azure et demandez une augmentation si nécessaire
   ```

4. **Problèmes de connexion au serveur web**
   ```
   Solution : Vérifiez que les règles de groupe de sécurité réseau permettent le trafic sur le port 80
   ```

### Vérification du déploiement

Pour vérifier que le déploiement fonctionne correctement :

1. Accédez à `http://<IP_publique_serveur_web>/index.php`
   - Vous devriez voir un message confirmant la connexion à la base de données

2. Connectez-vous au serveur de base de données et vérifiez le montage du partage Azure Files :
   ```bash
   ssh hassan@<IP_publique_serveur_bd>
   ls /mnt/azurefiles/mysql_backups
   ```

## Conclusion

Ce script Terraform offre une solution complète pour déployer une infrastructure à deux niveaux sur Azure avec une configuration automatisée. Il illustre comment l'Infrastructure as Code peut simplifier et accélérer le déploiement d'environnements complexes tout en maintenant la cohérence et la reproductibilité.

---

*Ce README a été créé pour accompagner le script Terraform fourni. N'hésitez pas à le personnaliser selon vos besoins spécifiques.*