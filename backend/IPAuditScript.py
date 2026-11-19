import os
import re
from dotenv import load_dotenv
from netmiko import ConnectHandler
import pandas as pd
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

# Load separate variables/modules
load_dotenv()
from backend.network_config import MY_SUPERNETS, ROUTER_INVENTORY

def fetch_routes_from_node(hostname, env_var_name):
    router_ip = os.getenv(env_var_name)
    username = os.getenv("ROUTER_USER")
    password = os.getenv("ROUTER_PASS")
    
    if not router_ip:
        print(f"[Error] No IP configured in .env for variable {env_var_name}. Skipping {hostname}.")
        return ""
        
    print(f"\n>>> Connecting to {hostname} ({router_ip})...")
    
    device_params = {
        "device_type": "cisco_xr",
        "host": router_ip,
        "username": username,
        "password": password,
    }
    
    node_output = ""
    try:
        with ConnectHandler(**device_params) as ssh:
            for supernet in MY_SUPERNETS:
                print(f"[{hostname}] Fetching paths for block: {supernet}...")
                command = f"show route ipv4 unicast longer-prefixes {supernet}"
                node_output += ssh.send_command(command) + "\n"
        return node_output
    except Exception as e:
        print(f"[Error] Failed to gather data from {hostname}: {e}")
        return ""

def process_and_generate_report(raw_data_map):
    prefix_regex = r"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/(\d{1,2})"
    records = []
    
    for hostname, output in raw_data_map.items():
        if not output:
            continue
        
        seen_prefixes = set()
        for line in output.splitlines():
            match = re.search(prefix_regex, line)
            if match:
                network = match.group(1)
                mask = int(match.group(2))
                prefix = f"{network}/{mask}"
                
                if prefix in seen_prefixes:
                    continue
                seen_prefixes.add(prefix)

                # Classification Logic rules
                if prefix in MY_SUPERNETS:
                    category = "AFRINIC Allocation"
                    comment = "Official Supernet assigned by AFRINIC"
                elif mask > 24:
                    category = "Customer Lease / Service"
                    comment = f"Leased or assigned to a customer or client (/{mask} prefix size)"
                else:
                    category = "Aggregated Route"
                    comment = "Aggregated routing space within the network (<= /24)"

                records.append({
                    "Router Hostname": hostname,
                    "IP Prefix": prefix,
                    "Prefix Size": f"/{mask}",
                    "Classification": category,
                    "Comments": comment
                })

    if not records:
        print("\n[Warning] No IP prefix data collected. Excel report skipped.")
        return

    # Formulate DataFrame
    df = pd.DataFrame(records)
    # Natural sort order: Hostname -> Class Type -> Mask Size
    df = df.sort_values(by=["Router Hostname", "Classification", "Prefix Size"])

    # Output file configuration
    filename = "Network_Prefix_MultiNode_Audit.xlsx"
    with pd.ExcelWriter(filename, engine='openpyxl') as writer:
        df.to_excel(writer, index=False, sheet_name="Routing Consolidated Summary")
        
        # Design & Layout Tuning via openpyxl
        ws = writer.sheets["Routing Consolidated Summary"]
        ws.views.sheetView[0].showGridLines = True
        
        # Formatting Styles Definition
        header_fill = PatternFill(start_color="1F4E78", end_color="1F4E78", fill_type="solid")
        header_font = Font(name="Segoe UI", size=11, bold=True, color="FFFFFF")
        
        supernet_fill = PatternFill(start_color="DDEBF7", end_color="DDEBF7", fill_type="solid")
        agg_fill = PatternFill(start_color="F2F2F2", end_color="F2F2F2", fill_type="solid")
        customer_fill = PatternFill(start_color="FFF2CC", end_color="FFF2CC", fill_type="solid")
        
        font_body = Font(name="Segoe UI", size=10, bold=False, color="000000")
        thin_border = Border(left=Side(style='thin', color='D9D9D9'), right=Side(style='thin', color='D9D9D9'),
                             top=Side(style='thin', color='D9D9D9'), bottom=Side(style='thin', color='D9D9D9'))

        # Standardize headers styling
        for col_idx in range(1, 6):
            cell = ws.cell(row=1, column=col_idx)
            cell.fill = header_fill
            cell.font = header_font
            cell.alignment = Alignment(horizontal="center", vertical="center")
        ws.row_dimensions[1].height = 26

        # Apply conditional structural fills row-by-row
        for row_idx in range(2, len(records) + 2):
            ws.row_dimensions[row_idx].height = 20
            class_val = ws.cell(row=row_idx, column=4).value
            
            row_fill = agg_fill
            if class_val == "AFRINIC Allocation":
                row_fill = supernet_fill
            elif class_val == "Customer Lease / Service":
                row_fill = customer_fill

            for col_idx in range(1, 6):
                cell = ws.cell(row=row_idx, column=col_idx)
                cell.font = font_body
                cell.fill = row_fill
                cell.border = thin_border
                if col_idx in [2, 3, 4]:
                    cell.alignment = Alignment(horizontal="center", vertical="center")
                else:
                    cell.alignment = Alignment(horizontal="left", vertical="center")

        # Autoadjust sizes
        for col in ws.columns:
            max_len = max(len(str(cell.value or '')) for cell in col)
            col_letter = get_column_letter(col[0].column)
            ws.column_dimensions[col_letter].width = max(max_len + 4, 15)

    print(f"\n[Success] Integrated Network Audit completed! File saved: '{filename}'")

if __name__ == "__main__":
    raw_outputs = {}
    for hostname, env_var in ROUTER_INVENTORY.items():
        raw_outputs[hostname] = fetch_routes_from_node(hostname, env_var)
        
    process_and_generate_report(raw_outputs)