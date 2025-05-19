from diagrams import Diagram
from diagrams.azure.compute import VM
from diagrams.azure.network import LoadBalancers
from diagrams.azure.database import SQLDatabases

# Set the graph attributes to increase the resolution (4K ~ 3840x2160)
graph_attr = {
    "dpi": "300",         # Higher dpi for better quality
    "size": "16,9!"       # Size ratio in inches (approx 3840x2160 at 300dpi)
}

with Diagram("Azure Grouped Workers", show=False, direction="TB", graph_attr=graph_attr):
    lb = LoadBalancers("azure-lb")
    workers = [VM(f"worker{i}") for i in range(1, 6)]
    db = SQLDatabases("azure-sql-db")

    lb >> workers >> db
