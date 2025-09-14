#!/bin/bash

# Cloud Guardian Deployment Verification Script
# Run this on the VPS after completing all deployment steps

echo "🛡️ CLOUD GUARDIAN DEPLOYMENT VERIFICATION"
echo "=========================================="
echo "Date: $(date)"
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

echo -e "${BLUE}=== STEP 1: File Deployment Verification ===${NC}"
if [[ -d "/opt/cloud-guardian" ]] && [[ "$(stat -c '%U:%G' /opt/cloud-guardian)" == "root:root" ]]; then
    check_status 0 "Files deployed with correct ownership"
else
    check_status 1 "File deployment failed"
fi

echo -e "\n${BLUE}=== STEP 2: Configuration Verification ===${NC}"
if [[ -f "/etc/cloud-guardian/env" ]] && [[ "$(stat -c '%a' /etc/cloud-guardian/env)" == "600" ]]; then
    check_status 0 "Environment file secure (600 permissions)"
else
    check_status 1 "Environment file not secure"
fi

if grep -q "CF_API_TOKEN=vC15Trm58jdoCTTC6Che7clmHgZs5i4pID1DnK7z" /etc/cloud-guardian/env 2>/dev/null; then
    check_status 0 "Cloudflare API token configured"
else
    check_status 1 "Cloudflare API token not configured"
fi

if [[ -f "/etc/cloud-guardian.yaml" ]] && python3 -c "import yaml; yaml.safe_load(open('/etc/cloud-guardian.yaml'))" 2>/dev/null; then
    check_status 0 "Configuration file valid"
else
    check_status 1 "Configuration file invalid"
fi

if grep -q "zone_id.*c58c15e45959a879f1309e92be02b07c" /etc/cloud-guardian.yaml 2>/dev/null; then
    check_status 0 "Cloudflare zone ID configured"
else
    check_status 1 "Cloudflare zone ID not configured"
fi

if grep -q "2a02:a461:f84f:1:e135:2aca:e78e:63b1" /etc/cloud-guardian.yaml 2>/dev/null; then
    check_status 0 "IPv6 client address configured"
else
    check_status 1 "IPv6 client address not configured"
fi

echo -e "\n${BLUE}=== STEP 3: Systemd Timer Verification ===${NC}"
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

echo -e "\n${BLUE}=== STEP 4: Security Enforcement Verification ===${NC}"
if cloud-guardian --test >/dev/null 2>&1; then
    check_status 0 "Configuration test passes"
else
    check_status 1 "Configuration test fails"
fi

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

if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
    check_status 0 "UFW firewall active"
else
    check_status 1 "UFW firewall not active"
fi

if sudo ufw status 2>/dev/null | grep -q "2a02:a461:f84f:1:e135:2aca:e78e:63b1"; then
    check_status 0 "SSH restricted to your IPv6"
else
    check_status 1 "SSH not properly restricted"
fi

if systemctl is-active fail2ban >/dev/null 2>&1; then
    check_status 0 "Fail2ban active"
else
    check_status 1 "Fail2ban not active"
fi

# Check port exposure
PUBLIC_PORTS=$(ss -tulpn 2>/dev/null | grep "0.0.0.0\|:::" | grep -E ":80|:443" | wc -l)
if [[ $PUBLIC_PORTS -ge 2 ]]; then
    check_status 0 "Ports 80/443 publicly accessible"
else
    check_status 1 "Ports 80/443 may not be publicly accessible"
fi

SSH_PUBLIC=$(ss -tulpn 2>/dev/null | grep ":22" | grep "0.0.0.0\|:::" | wc -l)
if [[ $SSH_PUBLIC -eq 0 ]]; then
    check_status 0 "SSH not publicly accessible"
else
    check_status 1 "SSH may be publicly accessible"
fi

# DNS resolution test
if nslookup n8n.vps.bolk.dev 2>/dev/null | grep -q "31.97.47.51"; then
    check_status 0 "DNS resolution correct (n8n.vps.bolk.dev → 31.97.47.51)"
else
    check_status 1 "DNS resolution incorrect"
fi

echo -e "\n${BLUE}=== DEPLOYMENT SUMMARY ===${NC}"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}🎉 DEPLOYMENT SUCCESSFUL - ALL STEPS COMPLETED${NC}"
    echo ""
    echo "Your Cloud Guardian is now:"
    echo "  ✓ Securing SSH (only your IPv6: 2a02:a461:f84f:1:e135:2aca:e78e:63b1/128)"
    echo "  ✓ Firewall active (only 80/443 public)"
    echo "  ✓ Fail2ban protecting SSH"
    echo "  ✓ Managing Cloudflare zone: c58c15e45959a879f1309e92be02b07c"
    echo "  ✓ Running automated enforcement every 15 minutes"
    echo ""
    echo "Monitor with:"
    echo "  sudo tail -f /var/log/cloud-guardian.log"
    echo "  systemctl status cloud-guardian.timer"
else
    echo -e "${RED}❌ DEPLOYMENT INCOMPLETE${NC}"
    echo "Found $ERRORS error(s) - please review and fix"
fi

echo ""
echo "Next: Verify Cloudflare dashboard shows SSL/TLS strict mode, HSTS, and TLS 1.3"
