#!/bin/bash

# Complete Cloud Guardian VPS Deployment Script
# Execute this from your local machine with VPS access

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VPS_IPV4="31.97.47.51"
VPS_IPV6="2a02:4780:41:f89c::1"
VPS_USER="gebruiker"
SOURCE_DIR="/home/gebruiker/templates/cloud-guardian"

echo -e "${BLUE}=== Cloud Guardian VPS Deployment ===${NC}"
echo "VPS IPv4: $VPS_IPV4"
echo "VPS IPv6: $VPS_IPV6"
echo ""

# Function to test connectivity
test_connectivity() {
    echo -e "${YELLOW}Testing VPS connectivity...${NC}"
    
    # Test IPv6 first
    if ssh -6 -o ConnectTimeout=10 -o BatchMode=yes $VPS_USER@$VPS_IPV6 exit 2>/dev/null; then
        echo -e "${GREEN}✓ IPv6 connectivity available${NC}"
        export USE_IPV6=true
        export VPS_ADDRESS="$VPS_IPV6"
        export SSH_OPTS="-6"
        export SCP_OPTS="-6"
        return 0
    fi
    
    # Test IPv4 fallback
    if ssh -4 -o ConnectTimeout=10 -o BatchMode=yes $VPS_USER@$VPS_IPV4 exit 2>/dev/null; then
        echo -e "${GREEN}✓ IPv4 connectivity available${NC}"
        export USE_IPV6=false
        export VPS_ADDRESS="$VPS_IPV4"
        export SSH_OPTS="-4"
        export SCP_OPTS="-4"
        return 0
    fi
    
    echo -e "${RED}✗ No connectivity available to VPS${NC}"
    echo "Please check:"
    echo "  - VPS is running and accessible"
    echo "  - SSH service is running on port 22"
    echo "  - Your IP is allowed in VPS firewall"
    exit 1
}

# Step 1: Deploy Agent to VPS
deploy_agent() {
    echo -e "${BLUE}=== Step 1: Deploy Agent to VPS ===${NC}"
    
    # Check if source directory exists
    if [[ ! -d "$SOURCE_DIR" ]]; then
        echo -e "${RED}Error: Source directory not found: $SOURCE_DIR${NC}"
        echo "Please ensure the cloud-guardian template exists at the specified path"
        exit 1
    fi
    
    # Deploy files
    echo "Copying files to VPS..."
    if [[ "$USE_IPV6" == "true" ]]; then
        # Corrected IPv6 SCP command with proper bracket handling
        scp $SCP_OPTS -r "$SOURCE_DIR" $VPS_USER@[$VPS_IPV6]:~/cloud-guardian
    else
        scp $SCP_OPTS -r "$SOURCE_DIR" $VPS_USER@$VPS_ADDRESS:~/cloud-guardian
    fi
    
    # Move files to proper location and set ownership
    echo "Setting up directory structure..."
    ssh $SSH_OPTS $VPS_USER@$VPS_ADDRESS << 'ENDSSH'
sudo mkdir -p /opt/cloud-guardian
sudo mv ~/cloud-guardian/* /opt/cloud-guardian/ 2>/dev/null || true
sudo rmdir ~/cloud-guardian 2>/dev/null || true
sudo chown -R root:root /opt/cloud-guardian
sudo chmod +x /opt/cloud-guardian/*.sh
sudo chmod +x /opt/cloud-guardian/cloud_guardian.py
ENDSSH
    
    echo -e "${GREEN}✓ Step 1 completed: Agent deployed to VPS${NC}"
}

# Step 2: Install and Configure on VPS
install_configure() {
    echo -e "${BLUE}=== Step 2: Install and Configure on VPS ===${NC}"
    
    ssh $SSH_OPTS $VPS_USER@$VPS_ADDRESS << 'ENDSSH'
# Update system packages
sudo apt-get update

# Install required system packages
sudo apt-get install -y python3 python3-venv python3-pip ufw fail2ban

# Create Python virtual environment
echo "Creating Python virtual environment..."
sudo python3 -m venv /opt/cloud-guardian/venv
sudo /opt/cloud-guardian/venv/bin/pip install --upgrade pip

# Install Python dependencies
echo "Installing Python dependencies..."
sudo /opt/cloud-guardian/venv/bin/pip install -r /opt/cloud-guardian/requirements.txt

# Create configuration directories
sudo mkdir -p /etc/cloud-guardian
sudo mkdir -p /var/log

# Create executable wrapper
sudo tee /usr/local/bin/cloud-guardian > /dev/null << 'EOF'
#!/bin/bash
source /opt/cloud-guardian/venv/bin/activate
exec python3 /opt/cloud-guardian/cloud_guardian.py "$@"
EOF
sudo chmod +x /usr/local/bin/cloud-guardian

echo "✓ Python environment and dependencies installed"
ENDSSH
    
    echo -e "${GREEN}✓ Step 2 completed: Installation done${NC}"
    echo -e "${YELLOW}⚠ Manual configuration required:${NC}"
    echo "  1. Edit /etc/cloud-guardian/env with your Cloudflare API token"
    echo "  2. Edit /etc/cloud-guardian.yaml with your zone_id and settings"
}

# Step 3: Enable Systemd Automation
enable_automation() {
    echo -e "${BLUE}=== Step 3: Enable Systemd Automation ===${NC}"
    
    ssh $SSH_OPTS $VPS_USER@$VPS_ADDRESS << 'ENDSSH'
# Install systemd service and timer files
sudo cp /opt/cloud-guardian/systemd/cloud-guardian.service /etc/systemd/system/
sudo cp /opt/cloud-guardian/systemd/cloud-guardian.timer /etc/systemd/system/

# Reload systemd daemon
sudo systemctl daemon-reload

# Enable services
sudo systemctl enable cloud-guardian.service
sudo systemctl enable cloud-guardian.timer

# Start timer
sudo systemctl start cloud-guardian.timer

echo "✓ Systemd automation enabled"
ENDSSH
    
    echo -e "${GREEN}✓ Step 3 completed: Automation enabled${NC}"
}

# Step 4: Execute and Verify
execute_verify() {
    echo -e "${BLUE}=== Step 4: Execute and Verify ===${NC}"
    
    # Check if configuration files exist
    echo "Checking configuration..."
    ssh $SSH_OPTS $VPS_USER@$VPS_ADDRESS << 'ENDSSH'
if [[ ! -f /etc/cloud-guardian/env ]]; then
    echo "⚠ Warning: /etc/cloud-guardian/env not found"
    echo "Creating template..."
    sudo tee /etc/cloud-guardian/env > /dev/null << 'EOF'
# Cloud Guardian Environment Variables
CLOUDFLARE_API_TOKEN=YOUR_CF_API_TOKEN
EOF
fi

if [[ ! -f /etc/cloud-guardian.yaml ]]; then
    echo "⚠ Warning: /etc/cloud-guardian.yaml not found"
    echo "Copying template..."
    sudo cp /opt/cloud-guardian/config/cloud-guardian.yaml /etc/cloud-guardian.yaml
fi
ENDSSH
    
    # Test configuration
    echo "Testing configuration..."
    ssh $SSH_OPTS $VPS_USER@$VPS_ADDRESS << 'ENDSSH'
if sudo cloud-guardian --test; then
    echo "✓ Configuration test passed"
else
    echo "✗ Configuration test failed - please check settings"
    exit 1
fi
ENDSSH
    
    # Run one-shot enforcement
    echo "Running one-shot enforcement..."
    ssh $SSH_OPTS $VPS_USER@$VPS_ADDRESS << 'ENDSSH'
echo "Executing Cloud Guardian enforcement..."
sudo cloud-guardian
ENDSSH
    
    # Verify components
    echo "Verifying security components..."
    ssh $SSH_OPTS $VPS_USER@$VPS_ADDRESS << 'ENDSSH'
echo "=== Verification Results ==="

# Check SSH configuration
echo "SSH Configuration:"
sudo sshd -T | grep -E "(PermitRootLogin|PasswordAuthentication|Port)" || true

# Check UFW status
echo -e "\nUFW Firewall Status:"
sudo ufw status verbose || true

# Check Fail2ban status
echo -e "\nFail2ban Status:"
sudo fail2ban-client status || true
sudo fail2ban-client status sshd || true

# Check systemd timer
echo -e "\nSystemd Timer Status:"
sudo systemctl status cloud-guardian.timer --no-pager || true

# Check recent logs
echo -e "\nRecent Logs:"
sudo tail -n 10 /var/log/cloud-guardian.log || echo "No logs yet"

echo -e "\n=== Verification Complete ==="
ENDSSH
    
    echo -e "${GREEN}✓ Step 4 completed: Execution and verification done${NC}"
}

# Main execution
main() {
    case "${1:-all}" in
        "test")
            test_connectivity
            ;;
        "deploy")
            test_connectivity
            deploy_agent
            ;;
        "install")
            test_connectivity
            install_configure
            ;;
        "enable")
            test_connectivity
            enable_automation
            ;;
        "verify")
            test_connectivity
            execute_verify
            ;;
        "all")
            test_connectivity
            deploy_agent
            install_configure
            enable_automation
            execute_verify
            ;;
        *)
            echo "Usage: $0 [test|deploy|install|enable|verify|all]"
            echo "  test    - Test VPS connectivity"
            echo "  deploy  - Deploy agent files"
            echo "  install - Install and configure"
            echo "  enable  - Enable automation"
            echo "  verify  - Execute and verify"
            echo "  all     - Run all steps (default)"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"

echo -e "${GREEN}=== Cloud Guardian Deployment Complete ===${NC}"
echo ""
echo -e "${YELLOW}Important Next Steps:${NC}"
echo "1. SSH to your VPS: ssh $VPS_USER@$VPS_ADDRESS"
echo "2. Edit Cloudflare API token: sudo nano /etc/cloud-guardian/env"
echo "3. Update configuration: sudo nano /etc/cloud-guardian.yaml"
echo "   - Add your Cloudflare zone_id"
echo "   - Verify IPv6 address matches your client"
echo "   - Confirm DNS record for n8n.vps.bolk.dev"
echo "4. Test again: sudo cloud-guardian --test"
echo "5. Monitor logs: sudo tail -f /var/log/cloud-guardian.log"
