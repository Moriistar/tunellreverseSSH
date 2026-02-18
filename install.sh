#!/bin/bash

# ==================================================
# Project: Advanced Reverse SSH Tunnel Manager
# Developer: Moriistar
# GitHub: https://github.com/Moriistar
# ==================================================

# --- Colors & Styles ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Check Root ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[Error] Please run this script as root (sudo).${NC}"
  exit 1
fi

# --- Helper Functions ---
pause() {
    read -n 1 -s -r -p "Press any key to continue..."
    echo ""
}

show_header() {
    clear
    echo -e "${PURPLE}======================================================${NC}"
    echo -e "${CYAN}    __  ___           _ _      __               ${NC}"
    echo -e "${CYAN}   /  |/  /___  _____(_)_)____/ /_____ ______   ${NC}"
    echo -e "${CYAN}  / /|_/ / __ \/ ___/ / / ___/ __/ __ \`/ ___/   ${NC}"
    echo -e "${CYAN} / /  / / /_/ / /  / / (__  ) /_/ /_/ / /       ${NC}"
    echo -e "${CYAN}/_/  /_/\____/_/  /_/_/____/\__/\__,_/_/        ${NC}"
    echo -e "${PURPLE}======================================================${NC}"
    echo -e "${YELLOW}       Reverse SSH Tunnel Manager V3.0       ${NC}"
    echo -e "${PURPLE}======================================================${NC}"
    echo ""
}

restart_ssh() {
    echo -e "${BLUE}>>> Restarting SSH Service...${NC}"
    if systemctl list-units --full -all | grep -Fq "sshd.service"; then
        systemctl restart sshd
    else
        systemctl restart ssh
    fi
    echo -e "${GREEN}[OK] Service restarted.${NC}"
}

# --- 1. Destination Setup (Iran) ---
setup_destination() {
    show_header
    echo -e "${BLUE}>>> Configuring Destination Server (Iran)...${NC}"

    # Backup
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    # Configs
    local CONFIGS=("GatewayPorts yes" "TCPKeepAlive yes" "ClientAliveInterval 60" "ClientAliveCountMax 3")
    
    for cfg in "${CONFIGS[@]}"; do
        key=$(echo "$cfg" | awk '{print $1}')
        if grep -q "^$key" /etc/ssh/sshd_config; then
            echo -e "${YELLOW}[Skip] $key is already set.${NC}"
        else
            echo "$cfg" >> /etc/ssh/sshd_config
            echo -e "${GREEN}[Add] Added $key to sshd_config.${NC}"
        fi
    done

    restart_ssh
    echo -e "${GREEN}>>> Destination Setup Complete!${NC}"
    pause
}

# --- 2. Source Setup (Foreign) ---
setup_source() {
    show_header
    echo -e "${BLUE}>>> Configuring Source Server (Foreign)...${NC}"

    read -p "Enter Destination (Iran) IP: " DEST_IP
    if [[ -z "$DEST_IP" ]]; then echo -e "${RED}IP required!${NC}"; pause; return; fi

    read -p "Enter Service Name (default: morii): " SVC_NAME
    SVC_NAME=${SVC_NAME:-morii}

    # SSH Key Logic
    if [ ! -f ~/.ssh/id_rsa ]; then
        echo -e "${CYAN}Generating SSH Key...${NC}"
        ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
    fi

    echo -e "${YELLOW}>>> Copying SSH Key to Destination... (Enter Password if asked)${NC}"
    ssh-copy-id -o StrictHostKeyChecking=no "root@$DEST_IP"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}[Error] Connection failed.${NC}"; pause; return;
    fi

    # Service Creation
    SERVICE_FILE="/etc/systemd/system/${SVC_NAME}@.service"
    
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Reverse Tunnel %I - ${SVC_NAME}
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/ssh -N -R 0.0.0.0:%i:localhost:%i -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no root@${DEST_IP}
Restart=always
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    echo -e "${GREEN}>>> Service Template Created!${NC}"
    
    add_ports "$SVC_NAME"
}

# --- Helper: Add Ports ---
add_ports() {
    local SVC=$1
    echo ""
    echo -e "${YELLOW}Enter Ports to tunnel (space separated, e.g., 80 443):${NC}"
    read -a PORTS

    for PORT in "${PORTS[@]}"; do
        echo -e "Enabling Tunnel on Port ${GREEN}$PORT${NC}..."
        systemctl enable --now "${SVC}@${PORT}"
    done
    echo -e "${GREEN}>>> Ports Activated.${NC}"
    pause
}

# --- 3. Add Ports to Existing ---
add_more_ports() {
    show_header
    read -p "Enter your existing Service Name (e.g., morii): " SVC
    if [ ! -f "/etc/systemd/system/${SVC}@.service" ]; then
        echo -e "${RED}Service file not found!${NC}"; pause; return;
    fi
    add_ports "$SVC"
}

# --- 4. Tunnel Status ---
show_status() {
    show_header
    echo -e "${BLUE}>>> Active Tunnels List:${NC}"
    echo "-----------------------------------"
    systemctl list-units --type=service --state=running | grep "@" | grep ".service"
    echo "-----------------------------------"
    echo -e "${YELLOW}Tip: Use 'lsof -i -P -n | grep LISTEN' on Iran server to verify.${NC}"
    pause
}

# --- 5. Test Connection ---
test_connection() {
    show_header
    read -p "Enter Destination IP to Ping: " DEST_IP
    echo -e "${CYAN}>>> Pinging $DEST_IP (4 packets)...${NC}"
    ping -c 4 "$DEST_IP"
    pause
}

# --- 6. Uninstall / Delete ---
uninstall_menu() {
    show_header
    echo -e "${RED}>>> Uninstall Menu${NC}"
    echo "1) Delete Specific Port"
    echo "2) Delete Entire Service (All Ports)"
    echo "3) Back"
    read -p "Choice: " U_CHOICE

    case $U_CHOICE in
        1)
            read -p "Service Name (e.g., morii): " SVC
            read -p "Port to remove: " PORT
            systemctl stop "${SVC}@${PORT}"
            systemctl disable "${SVC}@${PORT}"
            echo -e "${GREEN}Port $PORT removed.${NC}"
            pause
            ;;
        2)
            read -p "Service Name to wipe (e.g., morii): " SVC
            echo -e "${RED}Stopping all tunnels for $SVC...${NC}"
            # Stop all instances
            systemctl list-units --all | grep "${SVC}@" | awk '{print $1}' | xargs -r systemctl stop
            systemctl list-units --all | grep "${SVC}@" | awk '{print $1}' | xargs -r systemctl disable
            
            rm -f "/etc/systemd/system/${SVC}@.service"
            systemctl daemon-reload
            echo -e "${GREEN}>>> Full Uninstall Complete.${NC}"
            pause
            ;;
        *) return ;;
    esac
}

# --- MAIN LOOP ---
while true; do
    show_header
    echo -e " ${GREEN}1)${NC} Setup Destination Server (Iran)"
    echo -e " ${GREEN}2)${NC} Setup Source Server (Foreign) & Create Tunnel"
    echo -e " ${CYAN}3)${NC} Add More Ports to Existing Tunnel"
    echo -e " ${CYAN}4)${NC} Check Tunnel Status"
    echo -e " ${CYAN}5)${NC} Test Connectivity (Ping)"
    echo -e " ${RED}6)${NC} Uninstall / Delete Tunnels"
    echo -e " ${BLUE}0)${NC} Exit"
    echo ""
    read -p " Select Option [0-6]: " OPTION

    case $OPTION in
        1) setup_destination ;;
        2) setup_source ;;
        3) add_more_ports ;;
        4) show_status ;;
        5) test_connection ;;
        6) uninstall_menu ;;
        0) echo -e "${GREEN}Good luck Moriistar!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid Option.${NC}"; sleep 1 ;;
    esac
done
