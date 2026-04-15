#!/bin/bash

# Cloud Guardian Verification Commands
# Run these on the VPS after deployment

echo "=== Cloud Guardian Verification ==="

# Check SSH hardening
echo "1. SSH Configuration Verification:"
echo "   Current SSH settings:"
sudo sshd -T | grep -E "(PermitRootLogin|PasswordAuthentication|Port|MaxAuthTries)"
echo ""

# Check UFW firewall
echo "2. UFW Firewall Verification:"
sudo ufw status verbose
echo ""

# Check Fail2ban
echo "3. Fail2ban Verification:"
sudo fail2ban-client status
echo "   SSH jail status:"
sudo fail2ban-client status sshd 2>/dev/null || echo "   SSH jail not active yet"
echo ""

# Check Docker security (if enabled)
echo "4. Docker Security Verification:"
if command -v docker &> /dev/null; then
    echo "   Docker security options:"
    sudo docker info 2>/dev/null | grep -A 5 "Security Options" || echo "   Docker not running or not configured"
else
    echo "   Docker not installed"
fi
echo ""

# Check systemd timer
echo "5. Systemd Timer Verification:"
sudo systemctl status cloud-guardian.timer --no-pager
echo ""
echo "   Timer schedule:"
sudo systemctl list-timers cloud-guardian.timer --no-pager
echo ""

# Check logs
echo "6. Recent Logs:"
if [[ -f /var/log/cloud-guardian.log ]]; then
    echo "   Last 10 log entries:"
    sudo tail -n 10 /var/log/cloud-guardian.log
else
    echo "   No log file found yet"
fi
echo ""

# Check network ports
echo "7. Network Port Verification:"
echo "   Listening ports:"
sudo netstat -tlnp 2>/dev/null | grep -E ":22|:80|:443" || ss -tlnp | grep -E ":22|:80|:443"
echo ""

# Check Cloudflare configuration
echo "8. Cloudflare Configuration Check:"
if [[ -f /etc/cloud-guardian.yaml ]]; then
    echo "   Zone ID configured:"
    grep -A 2 "zone_id" /etc/cloud-guardian.yaml | head -3
    echo "   DNS records configured:"
    grep -A 5 "dns_records" /etc/cloud-guardian.yaml | head -8
else
    echo "   Configuration file not found"
fi
echo ""

# Test DNS resolution
echo "9. DNS Resolution Test:"
echo "   Testing n8n.vps.bolk.dev resolution:"
nslookup n8n.vps.bolk.dev 2>/dev/null || dig n8n.vps.bolk.dev +short 2>/dev/null || echo "   DNS tools not available"
echo ""

# Check environment variables
echo "10. Environment Configuration:"
if [[ -f /etc/cloud-guardian/env ]]; then
    echo "   Environment file exists:"
    ls -la /etc/cloud-guardian/env
    echo "   Cloudflare token configured:"
    if grep -q "YOUR_CF_API_TOKEN" /etc/cloud-guardian/env; then
        echo "   ⚠ WARNING: Placeholder token still in use - update required"
    else
        echo "   ✓ Custom token configured"
    fi
else
    echo "   Environment file not found"
fi
echo ""

echo "=== Verification Complete ==="
echo ""
echo "Expected Results:"
echo "✓ SSH: PermitRootLogin no, PasswordAuthentication no"
echo "✓ UFW: Status active, ports 22,80,443 allowed"
echo "✓ Fail2ban: Active with sshd jail"
echo "✓ Timer: Active and scheduled every 15 minutes"
echo "✓ DNS: n8n.vps.bolk.dev resolves to 31.97.47.51"
echo ""
echo "If any checks fail, review the configuration and run:"
echo "sudo cloud-guardian --test"
echo "sudo cloud-guardian"
