#!/bin/bash

# Cloud Guardian VPS Deployment Script
# Deploy Cloud Guardian to remote VPS

set -e

# Configuration
VPS_IP="31.97.47.51"
VPS_USER="root"
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
REMOTE_DIR="/tmp/cloud-guardian-deploy"

# Alternative IPv6 connection (uncomment if needed)
# VPS_IPV6="[2a01:4f8:c012:123::1]"  # Replace with actual IPv6

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Cloud Guardian VPS Deployment${NC}"
echo "=================================="

# Check if SSH key exists
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo -e "${RED}Error: SSH key not found at $SSH_KEY_PATH${NC}"
    echo "Please ensure you have SSH key access to the VPS"
    exit 1
fi

# Test SSH connection
echo -e "${YELLOW}Testing SSH connection to $VPS_IP...${NC}"
if ! ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=10 -o BatchMode=yes "$VPS_USER@$VPS_IP" exit 2>/dev/null; then
    echo -e "${RED}Error: Cannot connect to VPS via SSH${NC}"
    echo "Please check:"
    echo "  - VPS IP address: $VPS_IP"
    echo "  - SSH key path: $SSH_KEY_PATH"
    echo "  - VPS is accessible and SSH is running"
    exit 1
fi

echo -e "${GREEN}SSH connection successful!${NC}"

# Create deployment package
echo -e "${YELLOW}Creating deployment package...${NC}"
tar -czf cloud-guardian-deploy.tar.gz \
    cloud_guardian.py \
    requirements.txt \
    config/ \
    systemd/ \
    install.sh

# Copy files to VPS
echo -e "${YELLOW}Copying files to VPS...${NC}"
ssh -i "$SSH_KEY_PATH" "$VPS_USER@$VPS_IP" "mkdir -p $REMOTE_DIR"
scp -i "$SSH_KEY_PATH" cloud-guardian-deploy.tar.gz "$VPS_USER@$VPS_IP:$REMOTE_DIR/"

# Extract and install on VPS
echo -e "${YELLOW}Installing Cloud Guardian on VPS...${NC}"
ssh -i "$SSH_KEY_PATH" "$VPS_USER@$VPS_IP" << 'ENDSSH'
cd /tmp/cloud-guardian-deploy
tar -xzf cloud-guardian-deploy.tar.gz
chmod +x install.sh
./install.sh
ENDSSH

# Clean up local deployment package
rm -f cloud-guardian-deploy.tar.gz

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""
echo "Next steps on the VPS:"
echo "1. SSH to your VPS: ssh -i $SSH_KEY_PATH $VPS_USER@$VPS_IP"
echo "2. Edit configuration: nano /etc/cloud-guardian.yaml"
echo "3. Add Cloudflare API token: nano /etc/cloud-guardian/env"
echo "4. Test installation: cloud-guardian --test"
echo "5. Run one-shot enforcement: cloud-guardian"
echo "6. Enable automated enforcement: systemctl enable --now cloud-guardian.timer"
echo ""
echo -e "${YELLOW}Important: Remember to configure your Cloudflare API token and zone settings!${NC}"
