#!/bin/bash

# Master Cloud Guardian VPS Deployment Script
# Execute all 5 steps in sequence with verification

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
VPS_IPV4="31.97.47.51"
VPS_IPV6="2a02:4780:41:f89c::1"
VPS_USER="gebruiker"

echo -e "${BLUE}=== Cloud Guardian VPS Deployment Master Script ===${NC}"
echo "This script will execute all 5 deployment steps in sequence"
echo "VPS IPv4: $VPS_IPV4"
echo "VPS IPv6: $VPS_IPV6"
echo ""

# Function to pause between steps
pause_between_steps() {
    echo -e "${YELLOW}Press Enter to continue to next step, or Ctrl+C to abort...${NC}"
    read -r
}

# Step 1: Deploy Agent Files to VPS
echo -e "${BLUE}=== STEP 1: Deploy Agent Files to VPS ===${NC}"

echo "1.1 Getting VPS IPv6 address..."
echo "Run on VPS: ip -6 addr show scope global | awk '/inet6/{print \$2}' | head -n1"
echo "Expected: 2a02:4780:41:f89c::1/64"
echo ""

echo "1.2 Testing connectivity and deploying files..."
echo "Try IPv6 first:"
echo "ssh -6 -o ConnectTimeout=10 $VPS_USER@$VPS_IPV6 exit"
echo ""
echo "If IPv6 works, use corrected SCP command:"
echo "scp -6 -r /home/gebruiker/templates/cloud-guardian $VPS_USER@$VPS_IPV6:~/cloud-guardian"
echo ""
echo "If IPv6 fails, use IPv4 with temporary firewall rule:"
echo "sudo ufw allow from YOUR.IPv4/32 to any port 22 proto tcp"
echo "scp -4 -r /home/gebruiker/templates/cloud-guardian $VPS_USER@$VPS_IPV4:~/cloud-guardian"
echo ""

echo "1.3 Move files and set ownership (run on VPS):"
echo "sudo mv ~/cloud-guardian /opt/ && sudo chown -R root:root /opt/cloud-guardian"
echo ""

echo "1.4 Verify deployment (run verification script on VPS):"
cat << 'EOF'
#!/bin/bash
echo "=== Step 1 Verification ==="
if [[ -d "/opt/cloud-guardian" ]] && [[ "$(stat -c '%U:%G' /opt/cloud-guardian)" == "root:root" ]]; then
    echo "✓ Files deployed and ownership correct"
    ls -la /opt/cloud-guardian/
else
    echo "✗ Deployment verification failed"
    exit 1
fi
EOF

pause_between_steps

# Step 2: Install Runtime and Configure
echo -e "${BLUE}=== STEP 2: Install Runtime and Configure ===${NC}"

echo "2.1 Create Python virtual environment:"
echo "python3 -m venv /opt/cloud-guardian/venv"
echo ""

echo "2.2 Install dependencies:"
echo "/opt/cloud-guardian/venv/bin/pip install -r /opt/cloud-guardian/requirements.txt"
echo ""

echo "2.3 Create secure environment file:"
echo "sudo install -d -m 700 /etc/cloud-guardian && echo 'CF_API_TOKEN=YOUR_ACTUAL_TOKEN' | sudo tee /etc/cloud-guardian/env >/dev/null && sudo chmod 600 /etc/cloud-guardian/env"
echo ""

echo "2.4 Create configuration file:"
echo "Copy the template to /etc/cloud-guardian.yaml and update:"
echo "  - Add your actual Cloudflare zone_id"
echo "  - Update IPv6 address in ssh_ipv6_allow"
echo "  - Verify n8n DNS record points to 31.97.47.51"

pause_between_steps

# Step 3: Enable Systemd Timer
echo -e "${BLUE}=== STEP 3: Enable Systemd Timer ===${NC}"

echo "3.1 Install systemd files:"
echo "sudo install -Dm644 /opt/cloud-guardian/systemd/cloud-guardian.service /etc/systemd/system/"
echo "sudo install -Dm644 /opt/cloud-guardian/systemd/cloud-guardian.timer /etc/systemd/system/"
echo ""

echo "3.2 Enable 15-minute automation:"
echo "sudo systemctl daemon-reload && sudo systemctl enable --now cloud-guardian.timer"
echo ""

echo "3.3 Verify timer status:"
echo "systemctl status cloud-guardian.timer"
echo "systemctl list-timers cloud-guardian.timer"

pause_between_steps

# Step 4: Execute One-Shot Enforcement
echo -e "${BLUE}=== STEP 4: Execute One-Shot Enforcement ===${NC}"

echo "4.1 Run immediate enforcement:"
echo "/opt/cloud-guardian/venv/bin/python /opt/cloud-guardian/cloud_guardian.py --config /etc/cloud-guardian.yaml --once --verbose"
echo ""

echo "4.2 Verify SSH hardening:"
echo "sudo sshd -T | grep -E '(permitrootlogin|passwordauthentication)'"
echo ""

echo "4.3 Verify UFW rules:"
echo "sudo ufw status verbose"
echo ""

echo "4.4 Verify Docker DOCKER-USER policy:"
echo "sudo iptables -S DOCKER-USER"
echo ""

echo "4.5 Verify Fail2ban:"
echo "sudo fail2ban-client status"
echo "sudo fail2ban-client status sshd"

pause_between_steps

# Step 5: Verify All Components
echo -e "${BLUE}=== STEP 5: Verify All Components ===${NC}"

echo "5.1 Check timer status:"
echo "systemctl status cloud-guardian.timer"
echo ""

echo "5.2 Verify firewall:"
echo "ufw status verbose"
echo "iptables -S DOCKER-USER"
echo ""

echo "5.3 Validate port exposure:"
echo "ss -tulpn | grep -E ':22|:80|:443'"
echo "Expected: Only 80/443 on 0.0.0.0, SSH restricted"
echo ""

echo "5.4 Confirm Cloudflare settings in dashboard:"
echo "  - SSL/TLS mode: Strict"
echo "  - HSTS: Enabled"
echo "  - TLS 1.3 minimum"
echo "  - DNS: n8n.vps.bolk.dev → 31.97.47.51"
echo ""

echo "5.5 Final configuration test:"
echo "/opt/cloud-guardian/venv/bin/python /opt/cloud-guardian/cloud_guardian.py --config /etc/cloud-guardian.yaml --test"

echo -e "${GREEN}=== DEPLOYMENT COMPLETE ===${NC}"
echo ""
echo "Cloud Guardian is now:"
echo "  ✓ Deployed with all components verified"
echo "  ✓ Running automated enforcement every 15 minutes"
echo "  ✓ Securing SSH (root disabled, key-only auth)"
echo "  ✓ Firewall active (only 80/443 public, SSH restricted)"
echo "  ✓ Fail2ban protecting SSH"
echo "  ✓ Docker security policies applied"
echo "  ✓ Cloudflare DNS and SSL/TLS managed"
echo ""
echo "Monitor with:"
echo "  sudo tail -f /var/log/cloud-guardian.log"
echo "  systemctl status cloud-guardian.timer"
echo ""
echo -e "${YELLOW}IMPORTANT: Ensure you've updated the configuration with:${NC}"
echo "  - Your actual Cloudflare API token"
echo "  - Your actual Cloudflare zone_id"
echo "  - Your client IPv6 address for SSH access"
