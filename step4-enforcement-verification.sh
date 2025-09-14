#!/bin/bash

# Step 4: Execute One-Shot Enforcement Verification
echo "=== Step 4: Execute One-Shot Enforcement ==="

# 4.1 Run immediate enforcement
echo "4.1 Running one-shot enforcement..."
if /opt/cloud-guardian/venv/bin/python /opt/cloud-guardian/cloud_guardian.py --config /etc/cloud-guardian.yaml --once --verbose; then
    echo "✓ Enforcement completed successfully"
else
    echo "✗ Enforcement failed"
    exit 1
fi

# 4.2 Verify SSH hardening
echo "4.2 Verifying SSH hardening..."
SSH_CONFIG=$(sudo sshd -T 2>/dev/null)
if echo "$SSH_CONFIG" | grep -q "permitrootlogin no"; then
    echo "✓ Root login disabled"
else
    echo "✗ Root login not disabled"
fi

if echo "$SSH_CONFIG" | grep -q "passwordauthentication no"; then
    echo "✓ Password authentication disabled"
else
    echo "✗ Password authentication not disabled"
fi

# 4.3 Verify UFW rules
echo "4.3 Verifying UFW firewall rules..."
UFW_STATUS=$(sudo ufw status verbose 2>/dev/null)
if echo "$UFW_STATUS" | grep -q "Status: active"; then
    echo "✓ UFW firewall active"
    
    if echo "$UFW_STATUS" | grep -q "80/tcp.*ALLOW IN"; then
        echo "✓ Port 80 allowed"
    else
        echo "✗ Port 80 not allowed"
    fi
    
    if echo "$UFW_STATUS" | grep -q "443/tcp.*ALLOW IN"; then
        echo "✓ Port 443 allowed"
    else
        echo "✗ Port 443 not allowed"
    fi
else
    echo "✗ UFW firewall not active"
fi

# 4.4 Verify Docker DOCKER-USER policy
echo "4.4 Verifying Docker DOCKER-USER policy..."
if command -v docker >/dev/null 2>&1; then
    if sudo iptables -S DOCKER-USER 2>/dev/null | grep -q "DROP\|REJECT"; then
        echo "✓ Docker DOCKER-USER policy configured"
    else
        echo "⚠ Docker DOCKER-USER policy may not be configured"
    fi
else
    echo "⚠ Docker not installed or not running"
fi

# 4.5 Verify Fail2ban
echo "4.5 Verifying Fail2ban..."
if systemctl is-active fail2ban >/dev/null 2>&1; then
    echo "✓ Fail2ban service active"
    
    if sudo fail2ban-client status sshd >/dev/null 2>&1; then
        echo "✓ SSH jail active"
        sudo fail2ban-client status sshd
    else
        echo "⚠ SSH jail not active yet"
    fi
else
    echo "✗ Fail2ban service not active"
fi

# 4.6 Check enforcement logs
echo "4.6 Checking enforcement logs..."
if [[ -f "/var/log/cloud-guardian.log" ]]; then
    echo "✓ Log file exists"
    echo "Recent log entries:"
    sudo tail -n 5 /var/log/cloud-guardian.log
else
    echo "⚠ Log file not found"
fi

echo "✓ Step 4 completed: One-shot enforcement executed and verified"
