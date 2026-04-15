#!/bin/bash

# Cloud VPS Connection Script
# Connects current host to your Cloud Guardian VPS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# VPS Configuration
VPS_IPv4="31.97.47.51"
VPS_IPv6="2a02:4780:41:f89c::1"
VPS_USER="gebruiker"
VPS_SSH_PORT="22"

# Current host IPv4
CURRENT_HOST_IPv4="34.29.83.0"
ALLOWED_IPv6="2a02:a461:f84f:1:e135:2aca:e78e:63b1/128"

echo -e "${BLUE}🔗 Cloud VPS Connection Script${NC}"
echo -e "${BLUE}==============================${NC}"
echo -e "VPS IPv4: ${GREEN}$VPS_IPv4${NC}"
echo -e "VPS IPv6: ${GREEN}$VPS_IPv6${NC}"
echo -e "SSH User: ${GREEN}$VPS_USER${NC}"
echo -e "Current Host: ${YELLOW}$CURRENT_HOST_IPv4${NC}"
echo ""

# Function to test SSH connection
test_ssh_connection() {
    local host=$1
    local user=$2
    local port=$3
    
    echo -e "${BLUE}Testing SSH connection to $host...${NC}"
    
    # Test if we can connect (with timeout)
    if timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "$user@$host" -p "$port" exit 2>/dev/null; then
        echo -e "${GREEN}✅ SSH connection successful!${NC}"
        return 0
    else
        echo -e "${RED}❌ SSH connection failed${NC}"
        return 1
    fi
}

# Function to connect via SSH
connect_ssh() {
    local host=$1
    local user=$2
    local port=$3
    
    echo -e "${BLUE}Connecting to $host...${NC}"
    ssh "$user@$host" -p "$port"
}

# Main connection logic
echo -e "${YELLOW}⚠️  Connection Status Check:${NC}"
echo -e "Current host IPv4: ${YELLOW}$CURRENT_HOST_IPv4${NC}"
echo -e "VPS allows SSH from: ${GREEN}$ALLOWED_IPv6${NC}"
echo ""

echo -e "${YELLOW}Since the current host is not in the allowed IPv6 range,${NC}"
echo -e "${YELLOW}you'll need to temporarily allow this host on the VPS.${NC}"
echo ""

echo -e "${BLUE}Connection Options:${NC}"
echo -e "${GREEN}1.${NC} Try direct IPv4 connection (may fail due to firewall)"
echo -e "${GREEN}2.${NC} Try IPv6 connection (if available)"
echo -e "${GREEN}3.${NC} Show commands to temporarily allow current host"
echo -e "${GREEN}4.${NC} Show VPS management commands"
echo -e "${GREEN}5.${NC} Exit"
echo ""

read -p "Select option (1-5): " choice

case $choice in
    1)
        echo -e "${BLUE}Attempting direct IPv4 connection...${NC}"
        if test_ssh_connection "$VPS_IPv4" "$VPS_USER" "$VPS_SSH_PORT"; then
            connect_ssh "$VPS_IPv4" "$VPS_USER" "$VPS_SSH_PORT"
        else
            echo -e "${RED}Direct connection failed. Try option 3 to allow current host.${NC}"
        fi
        ;;
    2)
        echo -e "${BLUE}Attempting IPv6 connection...${NC}"
        if test_ssh_connection "$VPS_IPv6" "$VPS_USER" "$VPS_SSH_PORT"; then
            connect_ssh "$VPS_IPv6" "$VPS_USER" "$VPS_SSH_PORT"
        else
            echo -e "${RED}IPv6 connection failed. IPv6 may not be available.${NC}"
        fi
        ;;
    3)
        echo -e "${BLUE}Commands to temporarily allow current host:${NC}"
        echo ""
        echo -e "${YELLOW}Execute these commands on your VPS:${NC}"
        echo -e "${GREEN}# Allow current host temporarily${NC}"
        echo "sudo ufw allow from $CURRENT_HOST_IPv4/32 to any port 22 proto tcp"
        echo ""
        echo -e "${GREEN}# Then connect from this host:${NC}"
        echo "ssh $VPS_USER@$VPS_IPv4"
        echo ""
        echo -e "${GREEN}# After connection, remove temporary rule:${NC}"
        echo "sudo ufw delete allow from $CURRENT_HOST_IPv4/32 to any port 22 proto tcp"
        echo ""
        echo -e "${YELLOW}Would you like to try connecting now? (y/n)${NC}"
        read -p "> " try_connect
        if [[ $try_connect =~ ^[Yy]$ ]]; then
            connect_ssh "$VPS_IPv4" "$VPS_USER" "$VPS_SSH_PORT"
        fi
        ;;
    4)
        echo -e "${BLUE}VPS Management Commands:${NC}"
        echo ""
        echo -e "${GREEN}# Check Cloud Guardian status${NC}"
        echo "systemctl status cloud-guardian.timer"
        echo ""
        echo -e "${GREEN}# View Cloud Guardian logs${NC}"
        echo "sudo tail -f /var/log/cloud-guardian.log"
        echo ""
        echo -e "${GREEN}# Test Cloud Guardian configuration${NC}"
        echo "cloud-guardian --test"
        echo ""
        echo -e "${GREEN}# Manual Cloud Guardian enforcement${NC}"
        echo "cloud-guardian --once --verbose"
        echo ""
        echo -e "${GREEN}# Check firewall status${NC}"
        echo "sudo ufw status verbose"
        echo ""
        echo -e "${GREEN}# Check Fail2ban status${NC}"
        echo "sudo fail2ban-client status sshd"
        echo ""
        echo -e "${GREEN}# Check port exposure${NC}"
        echo "ss -tulpn | grep -E ':22|:80|:443'"
        ;;
    5)
        echo -e "${BLUE}Exiting...${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option. Please select 1-5.${NC}"
        ;;
esac
