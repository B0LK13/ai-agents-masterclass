#!/bin/bash

# FINAL CLOUD GUARDIAN PRODUCTION DEPLOYMENT
# With your confirmed exact values

set -e

echo "🚀 CLOUD GUARDIAN PRODUCTION DEPLOYMENT"
echo "========================================"
echo "IPv6 Allowed: 2a02:a461:f84f:1:e135:2aca:e78e:63b1/128"
echo "CF_API_TOKEN: vC15Trm58jdoCTTC6Che7clmHgZs5i4pID1DnK7z"
echo "Zone ID: c58c15e45959a879f1309e92be02b07c"
echo "DNS: n8n.vps.bolk.dev → 31.97.47.51"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# === STEP 1: Deploy Agent Files to VPS ===
echo -e "${BLUE}=== STEP 1: Deploy Agent Files to VPS ===${NC}"
echo "1.1 Get VPS IPv6 address:"
echo "ip -6 addr show scope global | awk '/inet6/{print \$2}' | head -n1"
echo ""

echo "1.2 Test connectivity and deploy files:"
echo "# Test IPv6 first"
echo "ssh -6 -o ConnectTimeout=10 gebruiker@2a02:4780:41:f89c::1 exit"
echo ""
echo "# Deploy with corrected SCP command (no /48 suffix)"
echo "scp -6 -r /home/gebruiker/templates/cloud-guardian gebruiker@2a02:4780:41:f89c::1:~/cloud-guardian"
echo ""
echo "# If IPv6 fails, use IPv4"
echo "scp -4 -r /home/gebruiker/templates/cloud-guardian gebruiker@31.97.47.51:~/cloud-guardian"
echo ""

echo "1.3 Move files and set ownership:"
echo "sudo mv ~/cloud-guardian /opt/ && sudo chown -R root:root /opt/cloud-guardian"
echo ""

# === STEP 2: Install Runtime and Configure ===
echo -e "${BLUE}=== STEP 2: Install Runtime and Configure ===${NC}"
cat << 'EOF'
# Install system packages
sudo apt-get update
sudo apt-get install -y python3 python3-venv python3-pip ufw fail2ban

# Create Python virtual environment
python3 -m venv /opt/cloud-guardian/venv

# Install dependencies
/opt/cloud-guardian/venv/bin/pip install -r /opt/cloud-guardian/requirements.txt

# Create secure environment file with YOUR EXACT API TOKEN
sudo install -d -m 700 /etc/cloud-guardian
echo 'CF_API_TOKEN=vC15Trm58jdoCTTC6Che7clmHgZs5i4pID1DnK7z' | sudo tee /etc/cloud-guardian/env >/dev/null
sudo chmod 600 /etc/cloud-guardian/env

# Create configuration file with YOUR EXACT VALUES
sudo tee /etc/cloud-guardian.yaml > /dev/null << 'YAMLEOF'
# Cloud Guardian Production Configuration
ssh:
  port: 22
  permit_root_login: "no"
  password_auth: "no"
  max_auth_tries: 3
  client_alive_interval: 300
  client_alive_count_max: 2
  ipv6_allow: "2a02:a461:f84f:1:e135:2aca:e78e:63b1/128"

firewall:
  allowed_ports:
    - "80/tcp"
    - "443/tcp"

fail2ban:
  ban_time: 3600
  find_time: 600
  max_retry: 3
  ssh_max_retry: 3

docker:
  enabled: true
  secure_daemon: true

cloudflare:
  zone_id: "c58c15e45959a879f1309e92be02b07c"
  dns_records:
    - name: "n8n.vps.bolk.dev"
      type: "A"
      ttl: 300
      content: "31.97.47.51"
  ssl:
    mode: "strict"
    always_use_https: true
    min_tls_version: "1.3"
    hsts_enabled: true
    hsts_max_age: 31536000

monitoring:
  log_retention_days: 30
  alert_email: "admin@bolk.dev"

updates:
  auto_security_updates: true
  reboot_if_required: false
YAMLEOF
EOF

echo ""

# === STEP 3: Enable Systemd Timer ===
echo -e "${BLUE}=== STEP 3: Enable Systemd Timer ===${NC}"
cat << 'EOF'
# Create executable wrapper
sudo tee /usr/local/bin/cloud-guardian > /dev/null << 'WRAPEOF'
#!/bin/bash
source /opt/cloud-guardian/venv/bin/activate
exec python3 /opt/cloud-guardian/cloud_guardian.py "$@"
WRAPEOF
sudo chmod +x /usr/local/bin/cloud-guardian

# Install systemd files
sudo install -Dm644 /opt/cloud-guardian/systemd/cloud-guardian.service /etc/systemd/system/
sudo install -Dm644 /opt/cloud-guardian/systemd/cloud-guardian.timer /etc/systemd/system/

# Enable 15-minute automation
sudo systemctl daemon-reload
sudo systemctl enable cloud-guardian.service
sudo systemctl enable cloud-guardian.timer
sudo systemctl start cloud-guardian.timer
EOF

echo ""

# === STEP 4: Execute One-Shot Enforcement ===
echo -e "${BLUE}=== STEP 4: Execute One-Shot Enforcement ===${NC}"
echo "# Test configuration first"
echo "cloud-guardian --test"
echo ""
echo "# Run immediate enforcement (CORRECTED COMMAND)"
echo "/opt/cloud-guardian/venv/bin/python /opt/cloud-guardian/cloud_guardian.py --config /etc/cloud-guardian.yaml --once --verbose"
echo ""

# === STEP 5: Verify All Components ===
echo -e "${BLUE}=== STEP 5: Verify All Components ===${NC}"
cat << 'EOF'
# Check timer status
systemctl status cloud-guardian.timer
systemctl list-timers cloud-guardian.timer

# Verify SSH hardening
sudo sshd -T | grep -E "(permitrootlogin|passwordauthentication)"
# Expected: permitrootlogin no, passwordauthentication no

# Verify UFW firewall
sudo ufw status verbose
# Expected: 80/443 public, SSH restricted to 2a02:a461:f84f:1:e135:2aca:e78e:63b1

# Verify Fail2ban
sudo fail2ban-client status
sudo fail2ban-client status sshd

# Check Docker DOCKER-USER policy
sudo iptables -S DOCKER-USER
# Expected: DROP policy

# Validate port exposure (should show only 80/443 public)
ss -tulpn | grep -E ":22|:80|:443"

# Test DNS resolution
nslookup n8n.vps.bolk.dev
# Expected: 31.97.47.51

# Final configuration test
cloud-guardian --test
# Expected: All checks pass with your token configured
EOF

echo ""
echo -e "${GREEN}=== DEPLOYMENT READY ===${NC}"
echo "🎯 All commands configured with your exact values:"
echo "   IPv6: 2a02:a461:f84f:1:e135:2aca:e78e:63b1/128"
echo "   Token: vC15Trm58jdoCTTC6Che7clmHgZs5i4pID1DnK7z"
echo "   Zone: c58c15e45959a879f1309e92be02b07c"
echo ""
echo "🚀 Execute these commands on your VPS to complete deployment!"
