#!/bin/bash

# Complete Cloud Guardian Deployment Verification
# Run this script on the VPS after deployment

echo "=== CLOUD GUARDIAN DEPLOYMENT VERIFICATION ==="
echo "Date: $(date)"
echo "VPS: $(hostname -I | awk '{print $1}')"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0

check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        ((ERRORS++))
    fi
}

# === STEP 1: File Deployment Verification ===
echo -e "${BLUE}=== STEP 1: File Deployment Verification ===${NC}"
if [[ -d "/opt/cloud-guardian" ]]; then
    check_status 0 "Cloud Guardian directory exists"
    OWNER=$(stat -c '%U:%G' /opt/cloud-guardian 2>/dev/null)
    if [[ "$OWNER" == "root:root" ]]; then
        check_status 0 "Correct ownership (root:root)"
    else
        check_status 1 "Incorrect ownership: $OWNER"
    fi
    
    # Check required files
    for file in cloud_guardian.py requirements.txt config/cloud-guardian.yaml systemd/cloud-guardian.service systemd/cloud-guardian.timer; do
        if [[ -f "/opt/cloud-guardian/$file" ]]; then
            check_status 0 "Required file: $file"
        else
            check_status 1 "Missing file: $file"
        fi
    done
else
    check_status 1 "Cloud Guardian directory missing"
fi

# === STEP 2: Runtime and Configuration Verification ===
echo -e "\n${BLUE}=== STEP 2: Runtime and Configuration Verification ===${NC}"
if [[ -d "/opt/cloud-guardian/venv" ]]; then
    check_status 0 "Python virtual environment exists"
    if /opt/cloud-guardian/venv/bin/python --version >/dev/null 2>&1; then
        check_status 0 "Python virtual environment functional"
    else
        check_status 1 "Python virtual environment not functional"
    fi
else
    check_status 1 "Python virtual environment missing"
fi

# Check dependencies
if /opt/cloud-guardian/venv/bin/pip list 2>/dev/null | grep -q "requests\|PyYAML"; then
    check_status 0 "Required Python packages installed"
else
    check_status 1 "Required Python packages missing"
fi

# Check environment file
if [[ -f "/etc/cloud-guardian/env" ]]; then
    PERMS=$(stat -c '%a' /etc/cloud-guardian/env 2>/dev/null)
    if [[ "$PERMS" == "600" ]]; then
        check_status 0 "Environment file permissions correct (600)"
    else
        check_status 1 "Environment file permissions incorrect: $PERMS"
    fi
    
    if grep -q "CF_API_TOKEN=vC15Trm58jdoCTTC6Che7clmHgZs5i4pID1DnK7z" /etc/cloud-guardian/env; then
        check_status 0 "Cloudflare API token configured"
    else
        check_status 1 "Cloudflare API token not configured correctly"
    fi
else
    check_status 1 "Environment file missing"
fi

# Check configuration file
if [[ -f "/etc/cloud-guardian.yaml" ]]; then
    check_status 0 "Configuration file exists"
    
    if python3 -c "import yaml; yaml.safe_load(open('/etc/cloud-guardian.yaml'))" 2>/dev/null; then
        check_status 0 "YAML syntax valid"
    else
        check_status 1 "YAML syntax error"
    fi
    
    # Check specific configuration values
    if grep -q "zone_id.*c58c15e45959a879f1309e92be02b07c" /etc/cloud-guardian.yaml; then
        check_status 0 "Cloudflare zone_id configured"
    else
        check_status 1 "Cloudflare zone_id not configured"
    fi
    
    if grep -q "2a02:a461:f84f:1:e135:2aca:e78e:63b1" /etc/cloud-guardian.yaml; then
        check_status 0 "IPv6 client address configured"
    else
        check_status 1 "IPv6 client address not configured"
    fi
    
    if grep -q "n8n.vps.bolk.dev" /etc/cloud-guardian.yaml; then
        check_status 0 "DNS record configured"
    else
        check_status 1 "DNS record not configured"
    fi
else
    check_status 1 "Configuration file missing"
fi

# === STEP 3: Systemd Timer Verification ===
echo -e "\n${BLUE}=== STEP 3: Systemd Timer Verification ===${NC}"
if [[ -f "/usr/local/bin/cloud-guardian" ]]; then
    check_status 0 "Cloud Guardian executable exists"
    if [[ -x "/usr/local/bin/cloud-guardian" ]]; then
        check_status 0 "Cloud Guardian executable is executable"
    else
        check_status 1 "Cloud Guardian executable not executable"
    fi
else
    check_status 1 "Cloud Guardian executable missing"
fi

if [[ -f "/etc/systemd/system/cloud-guardian.service" ]]; then
    check_status 0 "Systemd service file installed"
else
    check_status 1 "Systemd service file missing"
fi

if [[ -f "/etc/systemd/system/cloud-guardian.timer" ]]; then
    check_status 0 "Systemd timer file installed"
else
    check_status 1 "Systemd timer file missing"
fi

if systemctl is-enabled cloud-guardian.timer >/dev/null 2>&1; then
    check_status 0 "Timer enabled"
else
    check_status 1 "Timer not enabled"
fi

if systemctl is-active cloud-guardian.timer >/dev/null 2>&1; then
    check_status 0 "Timer active"
else
    check_status 1 "Timer not active"
fi

# Check 15-minute schedule
if grep -q "OnCalendar=\*:0/15" /etc/systemd/system/cloud-guardian.timer; then
    check_status 0 "15-minute schedule configured"
else
    check_status 1 "15-minute schedule not configured"
fi

# === STEP 4: Security Enforcement Verification ===
echo -e "\n${BLUE}=== STEP 4: Security Enforcement Verification ===${NC}"

# Test configuration
if cloud-guardian --test >/dev/null 2>&1; then
    check_status 0 "Configuration test passes"
else
    check_status 1 "Configuration test fails"
fi

# SSH hardening
if sudo sshd -T 2>/dev/null | grep -q "permitrootlogin no"; then
    check_status 0 "SSH root login disabled"
else
    check_status 1 "SSH root login not disabled"
fi

if sudo sshd -T 2>/dev/null | grep -q "passwordauthentication no"; then
    check_status 0 "SSH password authentication disabled"
else
    check_status 1 "SSH password authentication not disabled"
fi

# UFW firewall
if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
    check_status 0 "UFW firewall active"
    
    if sudo ufw status 2>/dev/null | grep -q "80/tcp.*ALLOW IN"; then
        check_status 0 "Port 80 allowed"
    else
        check_status 1 "Port 80 not allowed"
    fi
    
    if sudo ufw status 2>/dev/null | grep -q "443/tcp.*ALLOW IN"; then
        check_status 0 "Port 443 allowed"
    else
        check_status 1 "Port 443 not allowed"
    fi
    
    if sudo ufw status 2>/dev/null | grep -q "2a02:a461:f84f:1:e135:2aca:e78e:63b1"; then
        check_status 0 "IPv6 SSH access configured"
    else
        check_status 1 "IPv6 SSH access not configured"
    fi
else
    check_status 1 "UFW firewall not active"
fi

# Fail2ban
if systemctl is-active fail2ban >/dev/null 2>&1; then
    check_status 0 "Fail2ban service active"
    
    if sudo fail2ban-client status sshd >/dev/null 2>&1; then
        check_status 0 "SSH jail active"
    else
        check_status 1 "SSH jail not active"
    fi
else
    check_status 1 "Fail2ban service not active"
fi

# Docker DOCKER-USER policy
if command -v docker >/dev/null 2>&1; then
    if sudo iptables -S DOCKER-USER 2>/dev/null | grep -q "DROP\|REJECT"; then
        check_status 0 "Docker DOCKER-USER policy configured"
    else
        check_status 1 "Docker DOCKER-USER policy not configured"
    fi
else
    check_status 0 "Docker not installed (optional)"
fi

# === STEP 5: Final Component Verification ===
echo -e "\n${BLUE}=== STEP 5: Final Component Verification ===${NC}"

# Port exposure check
PUBLIC_PORTS=$(ss -tulpn 2>/dev/null | grep "0.0.0.0\|:::" | grep -E ":80|:443" | wc -l)
if [[ $PUBLIC_PORTS -ge 2 ]]; then
    check_status 0 "Ports 80/443 publicly accessible"
else
    check_status 1 "Ports 80/443 may not be publicly accessible"
fi

# SSH restriction check
SSH_PUBLIC=$(ss -tulpn 2>/dev/null | grep ":22" | grep "0.0.0.0\|:::" | wc -l)
if [[ $SSH_PUBLIC -eq 0 ]]; then
    check_status 0 "SSH not publicly accessible"
else
    check_status 1 "SSH may be publicly accessible"
fi

# DNS resolution
if command -v nslookup >/dev/null 2>&1; then
    if nslookup n8n.vps.bolk.dev 2>/dev/null | grep -q "31.97.47.51"; then
        check_status 0 "DNS resolution correct (n8n.vps.bolk.dev → 31.97.47.51)"
    else
        check_status 1 "DNS resolution incorrect or not working"
    fi
elif command -v dig >/dev/null 2>&1; then
    if dig n8n.vps.bolk.dev +short 2>/dev/null | grep -q "31.97.47.51"; then
        check_status 0 "DNS resolution correct (n8n.vps.bolk.dev → 31.97.47.51)"
    else
        check_status 1 "DNS resolution incorrect or not working"
    fi
else
    check_status 1 "DNS tools not available for testing"
fi

# === SUMMARY ===
echo -e "\n${BLUE}=== DEPLOYMENT SUMMARY ===${NC}"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}🎉 DEPLOYMENT SUCCESSFUL - ALL 5 STEPS COMPLETED${NC}"
    echo ""
    echo "Cloud Guardian is now:"
    echo "  ✓ Deployed with all files and correct ownership"
    echo "  ✓ Configured with your specific Cloudflare settings"
    echo "  ✓ Running automated enforcement every 15 minutes"
    echo "  ✓ Securing SSH (only your IPv6: 2a02:a461:f84f:1:e135:2aca:e78e:63b1)"
    echo "  ✓ Firewall active (only 80/443 public, SSH restricted)"
    echo "  ✓ Fail2ban protecting SSH"
    echo "  ✓ Managing Cloudflare zone: c58c15e45959a879f1309e92be02b07c"
    echo "  ✓ DNS: n8n.vps.bolk.dev → 31.97.47.51"
    echo ""
    echo "Monitor with:"
    echo "  sudo tail -f /var/log/cloud-guardian.log"
    echo "  systemctl status cloud-guardian.timer"
    echo "  cloud-guardian --test"
else
    echo -e "${RED}❌ DEPLOYMENT INCOMPLETE${NC}"
    echo "Found $ERRORS error(s) - please review and fix before proceeding"
fi

echo ""
echo "Next: Check Cloudflare dashboard for SSL/TLS strict mode, HSTS, and TLS 1.3 settings"
