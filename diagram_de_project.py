from diagrams import Diagram, Cluster, Edge
from diagrams.azure.compute import VM
from diagrams.azure.network import VirtualNetworks, Subnets
from diagrams.azure.storage import StorageAccounts, BlobStorage
from diagrams.azure.database import SQLDatabases
from diagrams.onprem.network import Apache
from diagrams.onprem.database import MySQL
from diagrams.generic.network import Firewall

# Configuration du graphique pour une meilleure résolution et apparence professionnelle
graph_attr = {
    "dpi": "300",                    # Haute résolution
    "fontsize": "20",                # Taille de police plus grande pour lisibilité
    "fontname": "Arial",             # Police professionnelle
    "bgcolor": "white",              # Fond blanc pour clarté
    "pad": "0.75",                   # Plus d'espace entre les éléments
    "splines": "ortho",              # Lignes orthogonales pour aspect plus professionnel
    "nodesep": "0.60",               # Plus d'espace entre les nœuds
    "ranksep": "0.75",               # Plus d'espace entre les rangs
    "concentrate": "true",           # Regrouper les lignes parallèles
}

node_attr = {
    "fontname": "Arial",             # Police cohérente
    "fontsize": "14",                # Taille de police adaptée
}

# Créer le diagramme avec orientation gauche-droite
with Diagram("Architecture Azure - Application Web Trois Tiers", show=True, 
             direction="LR", graph_attr=graph_attr, node_attr=node_attr, 
             filename="architecture_azure_professionnelle"):
    
    # SECTION STOCKAGE
    with Cluster("Zone de Stockage Azure"):
        storage_account = StorageAccounts("Compte de Stockage\n(Premium)")
        file_share = BlobStorage("Partage de Fichiers\n(Sauvegardes MySQL)")
        storage_account - Edge(color="darkgreen") - file_share
    
    # SECTION RÉSEAUX ET SERVEURS
    with Cluster("Environnement Applicatif"):
        # Réseau VNet-WEB
        with Cluster("Vnet-WEB (10.20.0.0/16)"):
            fw_web = Firewall("Règles de Sécurité\nPorts: 22, 80")
            vnet_web = VirtualNetworks("Réseau Web")
            sr_web = Subnets("Sous-réseau Web\n10.20.1.0/24")
            
            # VM Web dans ce réseau
            with Cluster("Serveur d'application"):
                vm_web = VM("VM Web\nserveur-web-idosr00\nUbuntu 22.04 LTS")
                apache = Apache("Apache + PHP")
                
                # Connexions internes au serveur web
                vm_web >> apache
            
            # Hiérarchie réseau web
            vnet_web >> sr_web >> vm_web
            fw_web >> vnet_web
        
        # Réseau VNet-BD
        with Cluster("Vnet-BD (10.10.0.0/16)"):
            fw_bd = Firewall("Règles de Sécurité\nPort: 3306 (interne)")
            vnet_bd = VirtualNetworks("Réseau BD")
            sr_bd = Subnets("Sous-réseau BD\n10.10.1.0/24")
            
            # VM BD dans ce réseau
            with Cluster("Serveur de données"):
                vm_bd = VM("VM BD\nserveur-bd-idosr00\nUbuntu 22.04 LTS")
                mysql = MySQL("MySQL Server\nBase: db_web\nUtilisateur: hassan")
                
                # Connexions internes au serveur BD
                vm_bd >> mysql
            
            # Hiérarchie réseau BD
            vnet_bd >> sr_bd >> vm_bd
            fw_bd >> vnet_bd
    
    # CONNEXIONS ENTRE COMPOSANTS
    # Peering entre les VNets (connexion bidirectionnelle)
    vnet_web << Edge(label="  Peering VNet  ", color="blue", style="bold") >> vnet_bd
    
    # Connexion application à DB
    apache >> Edge(label="Requêtes SQL\n(IP privée 10.10.1.4)", color="darkgreen") >> mysql
    
    # Connexion de sauvegarde
    mysql >> Edge(label="Sauvegarde quotidienne\nScript cron à minuit", style="dashed", color="darkred") >> file_share
    
    # Connexion Internet (implicite pour VM Web avec IP publique)
    internet = Apache("Internet")
    internet >> Edge(label="HTTP (Port 80)", color="orange") >> fw_web