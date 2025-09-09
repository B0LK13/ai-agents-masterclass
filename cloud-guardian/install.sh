#!/bin/bash

# Cloud Guardian Installation Script
# Run with: sudo bash install.sh

set -e

echo "Installing Cloud Guardian VPS Security Agent..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Create directories
echo "Creating directories..."
mkdir -p /etc/cloud-guardian
mkdir -p /var/log
mkdir -p /usr/local/bin

# Install Python dependencies
echo "Installing Python dependencies..."
apt-get update
apt-get install -y python3 python3-pip python3-venv

# Create virtual environment
echo "Creating Python virtual environment..."
python3 -m venv /opt/cloud-guardian-venv
source /opt/cloud-guardian-venv/bin/activate

# Install Python packages
pip install -r requirements.txt

# Copy files
echo "Installing Cloud Guardian files..."
cp cloud_guardian.py /opt/cloud-guardian-venv/bin/
chmod +x /opt/cloud-guardian-venv/bin/cloud_guardian.py

# Create wrapper script
cat > /usr/local/bin/cloud-guardian << 'EOF'
#!/bin/bash
source /opt/cloud-guardian-venv/bin/activate
exec python3 /opt/cloud-guardian-venv/bin/cloud_guardian.py "$@"
EOF
chmod +x /usr/local/bin/cloud-guardian

# Copy configuration
cp config/cloud-guardian.yaml /etc/cloud-guardian.yaml

# Create environment file template
cat > /etc/cloud-guardian/env << 'EOF'
# Cloud Guardian Environment Variables
# Add your Cloudflare API token here:
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token_here
EOF

# Install systemd files
echo "Installing systemd service and timer..."
cp systemd/cloud-guardian.service /etc/systemd/system/
cp systemd/cloud-guardian.timer /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

echo ""
echo "Cloud Guardian installation completed!"
echo ""
echo "Next steps:"
echo "1. Edit /etc/cloud-guardian.yaml with your configuration"
echo "2. Add your Cloudflare API token to /etc/cloud-guardian/env"
echo "3. Test the installation: sudo cloud-guardian --test"
echo "4. Run one-shot enforcement: sudo cloud-guardian"
echo "5. Enable automated enforcement: sudo systemctl enable --now cloud-guardian.timer"
echo ""
echo "Configuration files:"
echo "  - Main config: /etc/cloud-guardian.yaml"
echo "  - Environment: /etc/cloud-guardian/env"
echo "  - Logs: /var/log/cloud-guardian.log"
echo ""
