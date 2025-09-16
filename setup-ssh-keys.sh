#!/bin/bash

# SSH Key Setup Script for Cloud VPS Connection
# Sets up SSH key authentication between current host and VPS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# VPS Configuration
VPS_IPv4="31.97.47.51"
VPS_IPv6="2a02:4780:41:f89c::1"
VPS_USER="gebruiker"
CURRENT_HOST_IPv4="34.29.83.0"

echo -e "${BLUE}🔑 SSH Key Setup for Cloud VPS${NC}"
echo -e "${BLUE}===============================${NC}"
echo -e "VPS: ${GREEN}$VPS_IPv4${NC}"
echo -e "User: ${GREEN}$VPS_USER${NC}"
echo -e "Current Host: ${YELLOW}$CURRENT_HOST_IPv4${NC}"
echo ""

# Check if SSH key exists
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
SSH_PUB_KEY_PATH="$HOME/.ssh/id_rsa.pub"

if [[ -f "$SSH_KEY_PATH" ]]; then
    echo -e "${GREEN}✅ SSH private key found: $SSH_KEY_PATH${NC}"
else
    echo -e "${YELLOW}⚠️  No SSH private key found${NC}"
    echo -e "${BLUE}Generating new SSH key pair...${NC}"
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    # Generate SSH key
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "$(whoami)@$(hostname)-$(date +%Y%m%d)"
    
    echo -e "${GREEN}✅ SSH key pair generated${NC}"
fi

if [[ -f "$SSH_PUB_KEY_PATH" ]]; then
    echo -e "${GREEN}✅ SSH public key found: $SSH_PUB_KEY_PATH${NC}"
    echo ""
    echo -e "${BLUE}Your public key:${NC}"
    cat "$SSH_PUB_KEY_PATH"
    echo ""
else
    echo -e "${RED}❌ SSH public key not found${NC}"
    exit 1
fi

echo -e "${BLUE}SSH Key Setup Instructions:${NC}"
echo -e "${YELLOW}Since the VPS restricts SSH access, you need to:${NC}"
echo ""

echo -e "${GREEN}1. Temporarily allow current host on VPS:${NC}"
echo "   Execute on VPS: sudo ufw allow from $CURRENT_HOST_IPv4/32 to any port 22 proto tcp"
echo ""

echo -e "${GREEN}2. Copy public key to VPS:${NC}"
echo "   ssh-copy-id $VPS_USER@$VPS_IPv4"
echo "   OR manually:"
echo "   ssh $VPS_USER@$VPS_IPv4 'mkdir -p ~/.ssh && echo \"$(cat $SSH_PUB_KEY_PATH)\" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh'"
echo ""

echo -e "${GREEN}3. Test SSH connection:${NC}"
echo "   ssh $VPS_USER@$VPS_IPv4"
echo ""

echo -e "${GREEN}4. Remove temporary firewall rule:${NC}"
echo "   Execute on VPS: sudo ufw delete allow from $CURRENT_HOST_IPv4/32 to any port 22 proto tcp"
echo ""

echo -e "${BLUE}Alternative: Manual Key Installation${NC}"
echo -e "${YELLOW}If you have console access to the VPS:${NC}"
echo ""
echo -e "${GREEN}1. Login to VPS console${NC}"
echo -e "${GREEN}2. Add this public key to ~/.ssh/authorized_keys:${NC}"
echo ""
cat "$SSH_PUB_KEY_PATH"
echo ""

# Function to attempt key copy
attempt_key_copy() {
    echo -e "${BLUE}Attempting to copy SSH key to VPS...${NC}"
    
    if command -v ssh-copy-id >/dev/null 2>&1; then
        echo -e "${BLUE}Using ssh-copy-id...${NC}"
        if ssh-copy-id -i "$SSH_PUB_KEY_PATH" "$VPS_USER@$VPS_IPv4" 2>/dev/null; then
            echo -e "${GREEN}✅ SSH key copied successfully!${NC}"
            return 0
        else
            echo -e "${RED}❌ ssh-copy-id failed${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}ssh-copy-id not available, trying manual method...${NC}"
        if ssh "$VPS_USER@$VPS_IPv4" "mkdir -p ~/.ssh && echo '$(cat $SSH_PUB_KEY_PATH)' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh" 2>/dev/null; then
            echo -e "${GREEN}✅ SSH key installed manually!${NC}"
            return 0
        else
            echo -e "${RED}❌ Manual key installation failed${NC}"
            return 1
        fi
    fi
}

# Ask if user wants to attempt key copy
echo -e "${YELLOW}Would you like to attempt copying the SSH key now? (y/n)${NC}"
echo -e "${YELLOW}Note: This requires the VPS firewall to allow this host first.${NC}"
read -p "> " copy_key

if [[ $copy_key =~ ^[Yy]$ ]]; then
    if attempt_key_copy; then
        echo -e "${GREEN}🎉 SSH key setup complete!${NC}"
        echo -e "${BLUE}Testing connection...${NC}"
        if ssh -o ConnectTimeout=5 "$VPS_USER@$VPS_IPv4" exit 2>/dev/null; then
            echo -e "${GREEN}✅ SSH connection test successful!${NC}"
        else
            echo -e "${YELLOW}⚠️  SSH connection test failed, but key may be installed${NC}"
        fi
    else
        echo -e "${RED}SSH key copy failed. Please use manual method above.${NC}"
    fi
fi

echo ""
echo -e "${BLUE}SSH Configuration Summary:${NC}"
echo -e "Private Key: ${GREEN}$SSH_KEY_PATH${NC}"
echo -e "Public Key: ${GREEN}$SSH_PUB_KEY_PATH${NC}"
echo -e "VPS Connection: ${GREEN}ssh $VPS_USER@$VPS_IPv4${NC}"
