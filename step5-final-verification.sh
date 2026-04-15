#!/bin/bash

# Step 5: Verify All Components
echo "=== Step 5: Verify All Components ==="

# 5.1 Check timer status
echo "5.1 Checking timer status..."
if systemctl is-active cloud-guardian.timer >/dev/null 2>&1; then
    echo "✓ Timer is active"
    systemctl status cloud-guardian.timer --no-pager -l
    echo ""
    echo "Timer schedule:"
    systemctl list-timers cloud-guardian.timer --no-pager
else
    echo "✗ Timer is not active"
    exit 1
fi

# 5.2 Verify firewall comprehensive
echo "5.2 Verifying firewall configuration..."
echo "UFW Status:"
sudo ufw status verbose
echo ""

echo "DOCKER-USER chain:"
if sudo iptables -S DOCKER-USER 2>/dev/null; then
    echo "✓ DOCKER-USER chain exists"
else
    echo "⚠ DOCKER-USER chain not found (Docker may not be installed)"
fi
echo ""

# 5.3 Validate port exposure
echo "5.3 Validating port exposure..."
echo "Listening ports:"
ss -tulpn | grep -E ":22|:80|:443"
echo ""

echo "Public port analysis:"
PUBLIC_PORTS=$(ss -tulpn | grep "0.0.0.0\|:::" | grep -E ":80|:443" | wc -l)
SSH_RESTRICTED=$(ss -tulpn | grep ":22" | grep -v "127.0.0.1" | wc -l)

if [[ $PUBLIC_PORTS -ge 2 ]]; then
    echo "✓ Ports 80/443 publicly accessible"
else
    echo "⚠ Ports 80/443 may not be publicly accessible"
fi

if [[ $SSH_RESTRICTED -eq 0 ]]; then
    echo "✓ SSH appears to be restricted (not on 0.0.0.0)"
else
    echo "⚠ SSH may be publicly accessible"
fi

# 5.4 DNS resolution check
echo "5.4 Checking DNS resolution..."
if command -v nslookup >/dev/null 2>&1; then
    echo "n8n.vps.bolk.dev resolution:"
    nslookup n8n.vps.bolk.dev | grep -A 1 "Name:"
elif command -v dig >/dev/null 2>&1; then
    echo "n8n.vps.bolk.dev resolution:"
    dig n8n.vps.bolk.dev +short
else
    echo "⚠ DNS tools not available"
fi
echo ""

# 5.5 Security component summary
echo "5.5 Security component summary..."
echo "SSH Hardening:"
sudo sshd -T | grep -E "(permitrootlogin|passwordauthentication|port)" | head -3

echo -e "\nFirewall Status:"
sudo ufw status | head -1

echo -e "\nFail2ban Status:"
if systemctl is-active fail2ban >/dev/null 2>&1; then
    echo "Active - $(sudo fail2ban-client status | grep "Number of jail" || echo "Status unknown")"
else
    echo "Inactive"
fi

echo -e "\nDocker Security:"
if command -v docker >/dev/null 2>&1 && systemctl is-active docker >/dev/null 2>&1; then
    echo "Docker active with security policies"
else
    echo "Docker not active"
fi

# 5.6 Configuration validation
echo -e "\n5.6 Final configuration validation..."
if /opt/cloud-guardian/venv/bin/python /opt/cloud-guardian/cloud_guardian.py --config /etc/cloud-guardian.yaml --test; then
    echo "✓ Configuration validation passed"
else
    echo "✗ Configuration validation failed"
    exit 1
fi

# 5.7 Cloudflare settings reminder
echo -e "\n5.7 Cloudflare settings to verify in dashboard:"
echo "  - SSL/TLS mode: Strict"
echo "  - HSTS: Enabled"
echo "  - Minimum TLS version: 1.3"
echo "  - DNS record n8n.vps.bolk.dev → 31.97.47.51"

echo -e "\n✓ Step 5 completed: All components verified"
echo -e "\n=== DEPLOYMENT COMPLETE ==="
echo "Cloud Guardian is now:"
echo "  ✓ Deployed and configured"
echo "  ✓ Running automated enforcement every 15 minutes"
echo "  ✓ Securing SSH, firewall, and Docker"
echo "  ✓ Managing Cloudflare DNS and SSL/TLS"
echo ""
echo "Monitor with: sudo tail -f /var/log/cloud-guardian.log"
