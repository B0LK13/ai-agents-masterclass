#!/bin/bash

# Cloud Guardian VPS Deployment Commands
# Run these commands from your local machine with VPS access

set -e

echo "=== Cloud Guardian VPS Deployment ==="
echo "VPS IPv4: 31.97.47.51"
echo "VPS IPv6: 2a02:4780:41:f89c::1"
echo ""

# Step 1: Deploy Agent to VPS
echo "Step 1: Testing connectivity and deploying agent..."

# Test IPv6 connectivity first
echo "Testing IPv6 connectivity..."
if ssh -6 -o ConnectTimeout=10 -o BatchMode=yes gebruiker@2a02:4780:41:f89c::1 exit 2>/dev/null; then
    echo "✓ IPv6 connectivity available"
    USE_IPV6=true
    VPS_ADDRESS="2a02:4780:41:f89c::1"
else
    echo "✗ IPv6 connectivity failed, trying IPv4..."
    if ssh -4 -o ConnectTimeout=10 -o BatchMode=yes gebruiker@31.97.47.51 exit 2>/dev/null; then
        echo "✓ IPv4 connectivity available"
        USE_IPV6=false
        VPS_ADDRESS="31.97.47.51"
    else
        echo "✗ Both IPv6 and IPv4 connectivity failed"
        echo "Please check VPS accessibility and SSH configuration"
        exit 1
    fi
fi

# Deploy files based on connectivity
if [ "$USE_IPV6" = true ]; then
    echo "Deploying via IPv6..."
    # Corrected IPv6 SCP command (note the proper bracket escaping)
    scp -6 -r /home/gebruiker/templates/cloud-guardian gebruiker@[2a02:4780:41:f89c::1]:~/cloud-guardian
else
    echo "Deploying via IPv4..."
    # Note: You may need to temporarily allow your client IPv4 for SSH
    echo "If connection fails, temporarily allow your client IP in VPS firewall"
    scp -4 -r /home/gebruiker/templates/cloud-guardian gebruiker@31.97.47.51:~/cloud-guardian
fi

# Move files to proper location and set ownership
if [ "$USE_IPV6" = true ]; then
    ssh -6 gebruiker@2a02:4780:41:f89c::1 << 'ENDSSH'
sudo mkdir -p /opt/cloud-guardian
sudo mv ~/cloud-guardian/* /opt/cloud-guardian/
sudo chown -R root:root /opt/cloud-guardian
sudo chmod +x /opt/cloud-guardian/*.sh
ENDSSH
else
    ssh -4 gebruiker@31.97.47.51 << 'ENDSSH'
sudo mkdir -p /opt/cloud-guardian
sudo mv ~/cloud-guardian/* /opt/cloud-guardian/
sudo chown -R root:root /opt/cloud-guardian
sudo chmod +x /opt/cloud-guardian/*.sh
ENDSSH
fi

echo "✓ Step 1 completed: Agent deployed to VPS"
echo ""

# Step 2: Install and Configure on VPS
echo "Step 2: Installing and configuring on VPS..."

# Connect to VPS and perform installation
if [ "$USE_IPV6" = true ]; then
    ssh -6 gebruiker@2a02:4780:41:f89c::1 << 'ENDSSH'
# Create Python virtual environment
sudo python3 -m venv /opt/cloud-guardian/venv
sudo /opt/cloud-guardian/venv/bin/pip install --upgrade pip

# Install dependencies
sudo /opt/cloud-guardian/venv/bin/pip install -r /opt/cloud-guardian/requirements.txt

# Create configuration directories
sudo mkdir -p /etc/cloud-guardian
sudo mkdir -p /var/log

# Create environment file with Cloudflare API token
sudo tee /etc/cloud-guardian/env > /dev/null << 'EOF'
# Cloud Guardian Environment Variables
CLOUDFLARE_API_TOKEN=YOUR_CF_API_TOKEN
EOF

echo "✓ Python environment and dependencies installed"
ENDSSH
else
    ssh -4 gebruiker@31.97.47.51 << 'ENDSSH'
# Create Python virtual environment
sudo python3 -m venv /opt/cloud-guardian/venv
sudo /opt/cloud-guardian/venv/bin/pip install --upgrade pip

# Install dependencies
sudo /opt/cloud-guardian/venv/bin/pip install -r /opt/cloud-guardian/requirements.txt

# Create configuration directories
sudo mkdir -p /etc/cloud-guardian
sudo mkdir -p /var/log

# Create environment file with Cloudflare API token
sudo tee /etc/cloud-guardian/env > /dev/null << 'EOF'
# Cloud Guardian Environment Variables
CLOUDFLARE_API_TOKEN=YOUR_CF_API_TOKEN
EOF

echo "✓ Python environment and dependencies installed"
ENDSSH
fi

echo "✓ Step 2 completed: Installation and basic configuration done"
echo ""

echo "=== MANUAL CONFIGURATION REQUIRED ==="
echo "1. SSH to your VPS and edit /etc/cloud-guardian/env"
echo "2. Replace YOUR_CF_API_TOKEN with your actual Cloudflare API token"
echo "3. Edit /etc/cloud-guardian.yaml with your zone_id and domain settings"
echo "4. Run the remaining steps after configuration"
echo ""
echo "Continue with: bash deployment-commands.sh --continue"
