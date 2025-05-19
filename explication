# Explication détaillée de l'infrastructure Azure

## Introduction
Ce document explique en détail comment configurer une infrastructure cloud Azure pour héberger une application web connectée à une base de données, avec stockage partagé. Cette architecture est conçue pour les environnements de production qui nécessitent une séparation entre la couche web et la couche de données, tout en assurant une sauvegarde régulière des données.

## Composants principaux

### 1. Réseaux virtuels (VNet)
Un réseau virtuel Azure est une représentation de votre propre réseau dans le cloud. Il s'agit d'un isolement logique du cloud Azure dédié à votre abonnement. Les VNets permettent :
- Un isolement sécurisé
- L'organisation des ressources par fonction
- Une communication privée entre les ressources

#### Vnet-BD (10.10.0.0/16)
- **Fonction** : Héberge le serveur de base de données
- **Sous-réseau** : SR-BD (10.10.1.0/24)
- **Sécurité** : Isolé avec accès contrôlé

#### Vnet-WEB (10.20.0.0/16)
- **Fonction** : Héberge le serveur web
- **Sous-réseau** : SR-WEB (10.20.1.0/24)
- **Sécurité** : Exposition contrôlée à Internet

### 2. Peering de réseau virtuel
Le peering de réseau virtuel permet la connexion transparente entre deux VNets. Cette configuration :
- Permet la communication entre ressources de différents VNets
- Maintient une connexion privée (trafic sur le réseau Microsoft)
- Élimine la nécessité de passerelles ou connexions publiques
- Améliore la sécurité en limitant l'exposition des ressources

### 3. Machines virtuelles

#### VM-BD (serveur-bd-idosr00)
- **Système d'exploitation** : Ubuntu 22.04 LTS
- **Configuration** : Serveur MySQL
- **Réseau** : Vnet-BD, sous-réseau SR-BD
- **Accès** : IP privée uniquement (après configuration finale)
- **Sécurité** : Port 22 (SSH) ouvert pendant la configuration

#### VM-WEB (serveur-web-idosr00)
- **Système d'exploitation** : Ubuntu 22.04 LTS
- **Configuration** : Apache, PHP
- **Réseau** : Vnet-WEB, sous-réseau SR-WEB
- **Accès** : IP publique
- **Sécurité** : Ports 80 (HTTP) et 22 (SSH) ouverts

### 4. Stockage Azure

#### Compte de stockage (storageaccountidosr00)
- **Type** : Premium
- **Redondance** : LRS (stockage localement redondant)
- **Services** : Azure Files

#### Partage de fichiers (myshare00)
- **Quota** : 100 Go
- **Niveau** : Premium
- **Fonction** : Stockage des sauvegardes de base de données

## Flux d'opérations

### 1. Communication entre serveurs
1. Le serveur web se connecte au serveur de base de données via le peering VNet
2. La connexion utilise l'adresse IP privée du serveur BD (10.10.1.4)
3. Le trafic reste sécurisé sur le réseau Azure, sans exposition à Internet

### 2. Processus de sauvegarde
1. Le script backup.sh sur le serveur BD effectue une sauvegarde complète de MySQL
2. Les fichiers sont compressés (.sql.gz) et horodatés
3. Les sauvegardes sont stockées sur le partage Azure Files
4. Une tâche cron exécute cette sauvegarde quotidiennement à minuit
5. Les sauvegardes de plus de 7 jours sont automatiquement supprimées

### 3. Accès aux ressources
1. Le serveur web est accessible depuis Internet via son IP publique
2. Le serveur BD est accessible uniquement depuis le serveur web via IP privée
3. Les deux serveurs peuvent accéder au partage de fichiers Azure

## Avantages de cette architecture

### Sécurité
- Isolation des réseaux par fonction
- Serveur de base de données sans exposition Internet
- Communication sécurisée via peering VNet
- Authentification basée sur mots de passe pour les services

### Haute disponibilité
- Stockage premium pour performances optimales
- Sauvegarde automatique quotidienne
- Rétention des sauvegardes pendant 7 jours

### Évolutivité
- Architecture modulaire permettant l'ajout de services
- VNets configurés avec espace d'adressage important pour croissance future
- Partage de fichiers avec quota extensible

### Maintenance simplifiée
- Montage automatique du partage de fichiers
- Rotation automatique des sauvegardes
- Scripts d'initialisation pour déploiement rapide

## Considérations pour l'amélioration

1. **Sécurité renforcée**
   - Remplacer l'authentification par mot de passe par des clés SSH
   - Implémenter des groupes de sécurité réseau (NSG) plus stricts
   - Utiliser Azure Key Vault pour la gestion des secrets

2. **Haute disponibilité**
   - Ajouter des serveurs web redondants avec équilibrage de charge
   - Configurer MySQL en mode réplication
   - Augmenter le niveau de redondance du stockage (ZRS ou GRS)

3. **Surveillance**
   - Implémenter Azure Monitor pour la surveillance des ressources
   - Configurer des alertes pour les métriques critiques
   - Mettre en place Log Analytics pour l'analyse centralisée des journaux