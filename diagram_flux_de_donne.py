from diagrams import Diagram, Cluster, Edge, Node
from diagrams.azure.compute import VM
from diagrams.azure.network import VirtualNetworks, RouteFilters
from diagrams.azure.storage import StorageAccounts
from diagrams.onprem.network import Apache
from diagrams.onprem.database import MySQL
from diagrams.onprem.client import Client
from diagrams.azure.general import Subscriptions

# Configuration avancée pour une meilleure qualité et présentation
graph_attr = {
    "dpi": "300",
    "fontsize": "14",
    "bgcolor": "white",
    "pad": "0.75",
    "nodesep": "0.60",
    "ranksep": "0.75",
    "splines": "ortho",  # Lignes droites à angles droits
    "fontname": "Arial",
    "concentrate": "true"  # Regrouper les lignes parallèles
}

node_attr = {
    "fontsize": "12",
    "fontname": "Arial",
    "margin": "0.3,0.2"
}

edge_attr = {
    "fontsize": "10",
    "fontname": "Arial"
}

# Création du diagramme principal avec orientation de haut en bas
with Diagram(
    "Architecture Cloud et Flux de Données IDOSR",
    show=True,
    direction="TB",
    graph_attr=graph_attr,
    node_attr=node_attr,
    edge_attr=edge_attr,
    filename="architecture_cloud_idosr"
):
    # Zone utilisateur
    with Cluster("Utilisateurs", graph_attr={"bgcolor": "#E8F5E9", "fontcolor": "#2E7D32", "style": "rounded", "pencolor": "#2E7D32"}):
        client = Client("Navigateur Web\nClient Final")

    # Abonnement Azure
    with Cluster("Microsoft Azure", graph_attr={"bgcolor": "#E3F2FD", "fontcolor": "#1565C0", "style": "rounded", "pencolor": "#1565C0"}):
        subscription = Subscriptions("Abonnement IDOSR")
        
        # Réseau Azure
        with Cluster("Réseau Virtuel (VNet)", graph_attr={"bgcolor": "#E0F7FA", "fontcolor": "#00838F", "style": "rounded", "pencolor": "#00838F"}):
            peering = RouteFilters("VNet Peering\nCommunication Inter-Services")
            
            # Tier Web
            with Cluster("Tier Web - DMZ", graph_attr={"bgcolor": "#FFF3E0", "fontcolor": "#E65100", "style": "rounded", "pencolor": "#E65100"}):
                vm_web = VM("VM-WEB\nserveur-web-idosr00\nUbuntu 20.04 LTS")
                apache_php = Apache("Apache 2.4\nPHP 8.0\nServeur Web")
            
            # Tier Base de données
            with Cluster("Tier Base de Données", graph_attr={"bgcolor": "#F3E5F5", "fontcolor": "#6A1B9A", "style": "rounded", "pencolor": "#6A1B9A"}):
                vm_bd = VM("VM-BD\nserveur-bd-idosr00\nUbuntu 20.04 LTS")
                mysql_db = MySQL("MySQL 8.0\ndb_web\nServeur de données")
            
            # Tier Stockage
            with Cluster("Tier Stockage", graph_attr={"bgcolor": "#E8EAF6", "fontcolor": "#283593", "style": "rounded", "pencolor": "#283593"}):
                storage = StorageAccounts("storageaccountidosr00\nBlob et File Storage")

    # Connexions et flux de données
    # Flux utilisateur vers web
    client >> Edge(
        label="Requête HTTP/HTTPS (80/443)",
        color="#1976D2",
        style="bold",
        penwidth="2.0"
    ) >> vm_web
    
    # Flux interne web - Traitement
    vm_web >> Edge(
        label="Héberge",
        color="#FFA000",
        style="solid"
    ) >> apache_php
    
    # Flux requête SQL
    apache_php >> Edge(
        label="Requêtes SQL\nvia VNet Peering",
        color="#43A047",
        style="solid"
    ) >> peering
    
    peering >> Edge(
        color="#43A047",
        style="solid"
    ) >> mysql_db
    
    # Flux réponse SQL
    mysql_db >> Edge(
        label="Réponses SQL",
        color="#43A047",
        style="dashed"
    ) >> peering
    
    peering >> Edge(
        color="#43A047", 
        style="dashed"
    ) >> apache_php
    
    # Réponse au client
    apache_php >> Edge(
        label="Réponse HTTP",
        color="#1976D2",
        style="dashed"
    ) >> client
    
    # Processus de sauvegarde
    mysql_db >> Edge(
        label="Sauvegarde quotidienne\n(cron 02:00 UTC)",
        color="#D32F2F",
        style="bold"
    ) >> storage
    
    # Connexion SMB
    vm_bd >> Edge(
        label="Montage SMB\nStockage persistant",
        color="#7B1FA2",
        style="dotted",
        penwidth="1.5"
    ) >> storage