# Explication détaillée de l'Architecture Azure

## Vue d'ensemble

Ce diagramme illustre une architecture Azure à trois niveaux (three-tier) qui sépare clairement les couches applicative, données et stockage. Cette approche architecturale répond aux meilleures pratiques pour les applications d'entreprise en matière de sécurité, de performance et de maintenance.

## Composants principaux et leur fonction

### 1. Réseaux Virtuels (VNets)

**Définition**: Un réseau virtuel Azure (VNet) est un réseau privé isolé dans le cloud Azure, semblable à un réseau physique dans un datacenter traditionnel.

**Architecture mise en place**:
- **Vnet-WEB (10.20.0.0/16)**:
  - Réseau dédié pour les serveurs d'applications
  - Sous-réseau SR-WEB (10.20.1.0/24) pour segmenter davantage le réseau
  - Règles de sécurité permettant les ports 22 (SSH) et 80 (HTTP)

- **Vnet-BD (10.10.0.0/16)**:
  - Réseau isolé pour les serveurs de base de données
  - Sous-réseau SR-BD (10.10.1.0/24) pour une meilleure organisation
  - Règles de sécurité limitant l'accès uniquement au port 3306 (MySQL) depuis le réseau interne

**Avantage**: Cette séparation respecte le principe de défense en profondeur en isolant les ressources critiques (bases de données) des ressources exposées à Internet (serveurs web).

### 2. Peering de Réseaux Virtuels

**Définition**: Le peering VNet permet d'interconnecter des réseaux virtuels distincts pour qu'ils communiquent entre eux de manière privée et sécurisée.

**Configuration**:
- Connexion bidirectionnelle entre Vnet-WEB et Vnet-BD
- Permet au serveur web d'accéder à la base de données via une adresse IP privée (10.10.1.4)
- Le trafic reste dans le backbone réseau d'Azure sans jamais transiter par Internet

**Avantage**: Communication à faible latence et hautement sécurisée entre les différentes couches de l'application.

### 3. Machines Virtuelles

**VM Web (serveur-web-idosr00)**:
- Serveur Ubuntu 22.04 LTS
- Apache et PHP installés pour servir l'application web
- IP publique pour permettre l'accès depuis Internet
- Exposée uniquement sur les ports nécessaires (22 pour administration, 80 pour le trafic web)

**VM BD (serveur-bd-idosr00)**:
- Serveur Ubuntu 22.04 LTS
- MySQL Server pour le stockage des données
- IP privée uniquement (pas d'accès direct depuis Internet)
- Base de données "db_web" avec utilisateur "hassan" configuré

**Avantage**: Cette séparation permet d'appliquer différents niveaux de sécurité selon l'exposition requise pour chaque service.

### 4. Stockage Azure

**Définition**: Le stockage Azure offre des services de persistance hautement disponibles et sécurisés dans le cloud.

**Configuration**:
- Compte de stockage premium pour des performances optimales
- Partage de fichiers accessible via le protocole SMB (Server Message Block)
- Utilisé principalement pour stocker les sauvegardes de bases de données

**Avantage**: Solution de stockage gérée par Microsoft qui assure durabilité et disponibilité des données sans maintenance d'infrastructure.

## Flux de données principaux

1. **Accès à l'application**:
   - Les utilisateurs se connectent au serveur web via son adresse IP publique sur le port 80 (HTTP)
   - Le trafic traverse les règles de sécurité du réseau web qui autorisent ce type de connexion

2. **Traitement des requêtes**:
   - L'application PHP sur le serveur Apache traite les requêtes utilisateur
   - Lorsque des données sont nécessaires, l'application établit une connexion MySQL vers le serveur BD
   - Cette connexion utilise l'adresse IP privée (10.10.1.4) via le peering VNet

3. **Sauvegarde des données**:
   - Un script cron s'exécute quotidiennement à minuit sur le serveur BD
   - Il réalise une sauvegarde complète de la base de données MySQL
   - La sauvegarde est compressée et transférée vers le partage de fichiers Azure
   - Une politique de rétention de 7 jours est appliquée pour gérer l'espace de stockage

## Aspects de sécurité

1. **Isolation réseau**: Séparation claire entre les réseaux web et base de données
2. **Principe du moindre privilège**: 
   - La VM BD n'est pas exposée à Internet
   - Seuls les ports strictement nécessaires sont autorisés
3. **Communication sécurisée**: Tout le trafic entre composants reste dans le réseau Azure
4. **Protection des données**: Sauvegardes régulières vers un stockage Azure sécurisé

## Avantages de cette architecture

1. **Sécurité renforcée** par la séparation des couches applicatives
2. **Maintenance simplifiée** car chaque composant peut être géré séparément
3. **Évolutivité** permettant d'augmenter les ressources par couche selon les besoins
4. **Résilience** grâce aux sauvegardes automatisées des données critiques
5. **Performance optimisée** par le placement approprié des ressources dans des réseaux dédiés

Cette architecture constitue une base solide pour les applications d'entreprise nécessitant une séparation claire entre la présentation, la logique métier et les données.