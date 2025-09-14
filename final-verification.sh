#!/bin/bash

# Final Cloud Guardian Deployment Verification
echo "=== CLOUD GUARDIAN DEPLOYMENT VERIFICATION ==="
echo "Date: $(date)"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

# Function to check and report
check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        ((ERRORS++))
    fi
}

# Step 1: File Deployment
echo "=== STEP 1: File Deployment ==="
if [[ -d "/opt/cloud-guardian" ]]; then
    check_status 0 "Cloud Guardian directory exists"
    OWNER=$(stat -c '%U:%G' /opt/cloud-guardian 2>/dev/null)
    if [[ "$OWNER" == "root:root" ]]; then
        check_status 0 "Correct ownership (root:root)"
    else
        check_status 1 "Incorrect ownership: $OWNER"
    fi
else
    check_status 1 "Cloud Guardian directory missing"
fi

# Step 2: Runtime and Configuration
echo -e "\n=== STEP 2: Runtime and Configuration ==="
if [[ -d "/opt/cloud-guardian/venv" ]]; then
    check_status 0 "Python virtual environment exists"
else
    check_status 1 "Python virtual environment missing"
fi

if [[ -f "/etc/cloud-guardian/env" ]]; then
    PERMS=$(stat -c '%a' /etc/cloud-guardian/env 2>/dev/null)
    if [[ "$PERMS" == "600" ]]; then
        check_status 0 "Environment file permissions correct (600)"
    else
        check_status 1 "Environment file permissions incorrect: $PERMS"
    fi
else
    check_status 1 "Environment file missing"
fi

if [[ -f "/etc/cloud-guardian.yaml" ]]; then
    check_status 0 "Configuration file exists"
    if python3 -c "import yaml; yaml.safe_load(open('/etc/cloud-guardian.yaml'))" 2>/dev/null; then
        check_status 0 "YAML syntax valid"
    else
        check_status 1 "YAML syntax error"
    fi
else
    check_status 1 "Configuration file missing"
fi

# Step 3: Systemd Timer
echo -e "\n=== STEP 3: Systemd Timer ==="
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

# Step 4: Security Enforcement
echo -e "\n=== STEP 4: Security Enforcement ==="
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

if systemctl is-active fail2ban >/dev/null 2>&1; then
    check_status 0 "Fail2ban service active"
else
    check_status 1 "Fail2ban service not active"
fi

# Step 5: Final Verification
echo -e "\n=== STEP 5: Final Verification ==="
if [[ -f "/usr/local/bin/cloud-guardian" ]]; then
    check_status 0 "Cloud Guardian executable exists"
else
    check_status 1 "Cloud Guardian executable missing"
fi

if /opt/cloud-guardian/venv/bin/python /opt/cloud-guardian/cloud_guardian.py --test --config /etc/cloud-guardian.yaml >/dev/null 2>&1; then
    check_status 0 "Configuration test passes"
else
    check_status 1 "Configuration test fails"
fi

# Summary
echo -e "\n=== DEPLOYMENT SUMMARY ==="
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ DEPLOYMENT SUCCESSFUL${NC}"
    echo "All 5 steps completed successfully"
    echo ""
    echo "Cloud Guardian is now:"
    echo "  ✓ Deployed and configured"
    echo "  ✓ Running automated enforcement every 15 minutes"
    echo "  ✓ Securing SSH, firewall, and system"
    echo "  ✓ Ready for Cloudflare management (add API token)"
    echo ""
    echo "Next steps:"
    echo "1. Add your Cloudflare API token to /etc/cloud-guardian/env"
    echo "2. Update zone_id in /etc/cloud-guardian.yaml"
    echo "3. Monitor logs: sudo tail -f /var/log/cloud-guardian.log"
else
    echo -e "${RED}✗ DEPLOYMENT INCOMPLETE${NC}"
    echo "Found $ERRORS error(s) - please review and fix"
fi

echo ""
echo "Monitor with:"
echo "  systemctl status cloud-guardian.timer"
echo "  sudo tail -f /var/log/cloud-guardian.log"
echo "  sudo cloud-guardian --test"
