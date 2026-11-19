# --- AFRINIC SUPERNET ALLOCATIONS ---
# Define all company-owned supernets assigned by AFRINIC
MY_SUPERNETS = [
    "196.207.0.0/20", 
    "196.220.0.0/19",
    "41.67.128.0/18", 
    "41.219.128.0/18"
]

# --- ROUTER DEPLOYMENT INVENTORY ---
# Key-value maps defining 'Hostname': 'Environment Variable Name'
ROUTER_INVENTORY = {
    "SAPETRO-CORE": "SAPETRO_CORE_NODE",
    "MEDALLION-CORE": "MEDALLION_CORE_NODE"
}

