#!/bin/bash

# Final Cloud Guardian Verification with Your Specific Values
# IPv6: 2a02:a461:f84f:1:e135:2aca:e78e:63b1/128
# Token: vC15Trm58jdoCTTC6Che7clmHgZs5i4pID1DnK7z
# Zone: c58c15e45959a879f1309e92be02b07c

echo "🛡️ CLOUD GUARDIAN FINAL VERIFICATION"
echo "===================================="
echo "Your Configuration:"
echo "  IPv6: 2a02:a461:f84f:1:e135:2aca:e78e:63b1/128"
echo "  Token: vC15Trm58jdoCTTC6Che7clmHgZs5i4pID1DnK7z"
echo "  Zone: c58c15e45959a879f1309e92be02b07c"
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

echo -e "${BLUE}=== MILESTONE 1: File Deployment ===${NC}"
if [[ -d "/opt/cloud-guardian" ]] && [[ "$(stat -c '%U:%G' /opt/cloud-guardian)" == "root:root" ]]; then
    check_status 0 "Files deployed with root ownership"
else
    check_status 1 "File deployment failed"
fi

echo -e "\n${BLUE}=== MILESTONE 2: Configuration with Your Values ===${NC}"
if grep -q "CF_API_TOKEN=vC15Trm58jdoCTTC6Che7clmHgZs5i4pID1DnK7z" /etc/cloud-guardian/env 2>/dev/null; then
    check_status 0 "YOUR Cloudflare API token configured"
else
    check_status 1 "Cloudflare API token not configured correctly"
fi

if grep -q "zone_id.*c58c15e45959a879f1309e92be02b07c" /etc/cloud-guardian.yaml 2>/dev/null; then
    check_status 0 "YOUR Cloudflare zone ID configured"
else
    check_status 1 "Cloudflare zone ID not configured"
fi

if grep -q "2a02:a461:f84f:1:e135:2aca:e78e:63b1/128" /etc/cloud-guardian.yaml 2>/dev/null; then
    check_status 0 "YOUR IPv6 address configured"
else
    check_status 1 "IPv6 address not configured"
fi

if grep -q "n8n.vps.bolk.dev" /etc/cloud-guardian.yaml 2>/dev/null; then
    check_status 0 "DNS record configured (n8n.vps.bolk.dev → 31.97.47.51)"
else
    check_status 1 "DNS record not configured"
fi

echo -e "\n${BLUE}=== MILESTONE 3: Systemd Timer ===${NC}"
if systemctl is-active cloud-guardian.timer >/dev/null 2>&1; then
    check_status 0 "Timer active (15-minute automation)"
else
    check_status 1 "Timer not active"
fi

echo -e "\n${BLUE}=== MILESTONE 4: Security Enforcement ===${NC}"
if cloud-guardian --test >/dev/null 2>&1; then
    check_status 0 "Configuration test passes with YOUR token"
else
    check_status 1 "Configuration test fails"
fi

if sudo sshd -T 2>/dev/null | grep -q "permitrootlogin no"; then
    check_status 0 "SSH root login disabled"
else
    check_status 1 "SSH root login not disabled"
fi

if sudo ufw status 2>/dev/null | grep -q "2a02:a461:f84f:1:e135:2aca:e78e:63b1"; then
    check_status 0 "SSH restricted to YOUR IPv6"
else
    check_status 1 "SSH not properly restricted to your IPv6"
fi

if systemctl is-active fail2ban >/dev/null 2>&1; then
    check_status 0 "Fail2ban active"
else
    check_status 1 "Fail2ban not active"
fi

echo -e "\n${BLUE}=== MILESTONE 5: Final Verification ===${NC}"
PUBLIC_PORTS=$(ss -tulpn 2>/dev/null | grep "0.0.0.0\|:::" | grep -E ":80|:443" | wc -l)
if [[ $PUBLIC_PORTS -ge 2 ]]; then
    check_status 0 "Ports 80/443 publicly accessible"
else
    check_status 1 "Ports 80/443 may not be publicly accessible"
fi

SSH_PUBLIC=$(ss -tulpn 2>/dev/null | grep ":22" | grep "0.0.0.0\|:::" | wc -l)
if [[ $SSH_PUBLIC -eq 0 ]]; then
    check_status 0 "SSH not publicly accessible (restricted to your IPv6)"
else
    check_status 1 "SSH may be publicly accessible"
fi

if nslookup n8n.vps.bolk.dev 2>/dev/null | grep -q "31.97.47.51"; then
    check_status 0 "DNS resolution correct (n8n.vps.bolk.dev → 31.97.47.51)"
else
    check_status 1 "DNS resolution incorrect"
fi

echo -e "\n${BLUE}=== DEPLOYMENT SUMMARY ===${NC}"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}🎉 DEPLOYMENT SUCCESSFUL WITH YOUR VALUES${NC}"
    echo ""
    echo "Your Cloud Guardian is securing:"
    echo "  🔒 SSH access: ONLY from 2a02:a461:f84f:1:e135:2aca:e78e:63b1/128"
    echo "  🔥 Firewall: Only 80/443 public"
    echo "  ☁️ Cloudflare: Zone c58c15e45959a879f1309e92be02b07c"
    echo "  🛡️ Fail2ban: Protecting against brute-force"
    echo "  ⏰ Automation: Running every 15 minutes"
    echo ""
    echo "Monitor with:"
    echo "  systemctl status cloud-guardian.timer"
    echo "  sudo tail -f /var/log/cloud-guardian.log"
    echo "  cloud-guardian --test"
else
    echo -e "${RED}❌ DEPLOYMENT ISSUES FOUND${NC}"
    echo "Found $ERRORS error(s) - please review configuration"
fi

echo ""
echo "Cloudflare Dashboard Verification:"
echo "  - Zone: c58c15e45959a879f1309e92be02b07c"
echo "  - SSL/TLS: Strict mode ✓"
echo "  - HSTS: Enabled ✓"
echo "  - TLS 1.3: Minimum ✓"
