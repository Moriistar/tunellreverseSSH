#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check root privileges
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run the script with root privileges (sudo).${NC}"
  exit
fi

# Header function
show_header() {
    clear
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${YELLOW}       Moriistar Reverse SSH Tunnel Installer      ${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo ""
}

# ------------------- Iran Server Setup -------------------
setup_iran() {
    echo -e "${GREEN}>>> Configuring Iran Server (Destination)...${NC}"
    
    # Enable GatewayPorts
    if grep -q "^GatewayPorts yes" /etc/ssh/sshd_config; then
        echo -e "${YELLOW}GatewayPorts is already enabled.${NC}"
    else
        echo "GatewayPorts yes" >> /etc/ssh/sshd_config
        echo -e "${GREEN}GatewayPorts added to sshd_config.${NC}"
    fi

    # Restart SSH Service (Fixed for Ubuntu/Debian/CentOS)
    echo -e "${GREEN}>>> Restarting SSH service...${NC}"
    if systemctl list-units --full -all | grep -Fq "sshd.service"; then
        systemctl restart sshd
    else
        systemctl restart ssh
    fi

    echo -e "${GREEN}>>> Iran server configuration completed.${NC}"
    echo -e "${RED}NOTE: According to instructions, a reboot is recommended.${NC}"
    read -p "Do you want to reboot the server right now? (y/n): " reboot_choice
    if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
        reboot
    fi
}

# ------------------- Foreign Server Setup -------------------
setup_kharej() {
    echo -e "${GREEN}>>> Configuring Foreign Server (Source)...${NC}"

    # Get necessary inputs
    read -p "Please enter Iran Server IP: " IRAN_IP
    read -p "Choose a custom name for the service (e.g., mytunnel): " SERVICE_NAME

    if [ -z "$IRAN_IP" ] || [ -z "$SERVICE_NAME" ]; then
        echo -e "${RED}Input missing. Operation cancelled.${NC}"
        return
    fi

    # SSH Key Generation
    echo -e "${GREEN}>>> Checking/Generating SSH Key...${NC}"
    if [ ! -f ~/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
        echo -e "${GREEN}SSH Key generated.${NC}"
    else
        echo -e "${YELLOW}SSH Key already exists.${NC}"
    fi

    # Copy Key to Iran Server
    echo -e "${YELLOW}>>> You will be asked for Iran server password to copy the key.${NC}"
    echo -e "Connecting to root@$IRAN_IP ..."
    ssh-copy-id -i ~/.ssh/id_rsa.pub root@$IRAN_IP

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error copying key! Please check network connection or password.${NC}"
        return
    fi

    # Create Systemd Service File
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}@.service"
    echo -e "${GREEN}>>> Creating service file at $SERVICE_FILE ...${NC}"

cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Reverse SSH Tunnel Port %I
After=network-online.target

[Service]
Type=simple
ExecStart=ssh -N -R 0.0.0.0:%i:localhost:%i root@${IRAN_IP}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Reload Daemon
    systemctl daemon-reload
    echo -e "${GREEN}Service created and Daemon reloaded.${NC}"

    # Get Ports
    echo ""
    echo -e "${YELLOW}Enter the ports you want to tunnel.${NC}"
    echo -e "Separate multiple ports with space (e.g., 8080 443 2082): "
    read -a PORTS

    for PORT in "${PORTS[@]}"; do
        echo -e ">>> Enabling and starting tunnel on port ${GREEN}$PORT${NC}..."
        systemctl enable "${SERVICE_NAME}@${PORT}"
        systemctl start "${SERVICE_NAME}@${PORT}"
    done

    echo ""
    echo -e "${GREEN}>>> Done! Service status:${NC}"
    for PORT in "${PORTS[@]}"; do
        systemctl status "${SERVICE_NAME}@${PORT}" --no-pager | grep "Active:"
    done
}

# ------------------- Main Menu -------------------
show_header
echo "Please select this server's location:"
echo "1) Iran Server (Destination)"
echo "2) Foreign Server (Source)"
echo "3) Exit"
echo ""
read -p "Enter your choice [1-3]: " CHOICE

case $CHOICE in
    1)
        setup_iran
        ;;
    2)
        setup_kharej
        ;;
    3)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option!${NC}"
        ;;
esac
