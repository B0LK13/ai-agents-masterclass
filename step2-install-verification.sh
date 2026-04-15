#!/bin/bash

# Step 2: Install Runtime and Configure Verification
echo "=== Step 2: Install Runtime and Configure ==="

# 2.1 Verify Python virtual environment
echo "2.1 Verifying Python virtual environment..."
if [[ -d "/opt/cloud-guardian/venv" ]]; then
    echo "✓ Virtual environment exists"
    /opt/cloud-guardian/venv/bin/python --version
else
    echo "✗ Virtual environment not found"
    exit 1
fi

# 2.2 Verify dependencies installed
echo "2.2 Verifying dependencies..."
if /opt/cloud-guardian/venv/bin/pip list | grep -q "requests\|PyYAML"; then
    echo "✓ Dependencies installed:"
    /opt/cloud-guardian/venv/bin/pip list | grep -E "requests|PyYAML"
else
    echo "✗ Dependencies not installed"
    exit 1
fi

# 2.3 Verify secure environment file
echo "2.3 Verifying environment file..."
if [[ -f "/etc/cloud-guardian/env" ]]; then
    PERMS=$(stat -c '%a' /etc/cloud-guardian/env)
    if [[ "$PERMS" == "600" ]]; then
        echo "✓ Environment file exists with correct permissions (600)"
        if grep -q "CF_API_TOKEN=" /etc/cloud-guardian/env; then
            if grep -q "YOUR_ACTUAL_TOKEN" /etc/cloud-guardian/env; then
                echo "⚠ WARNING: Placeholder token detected - update required"
            else
                echo "✓ Custom API token configured"
            fi
        else
            echo "✗ CF_API_TOKEN not found in environment file"
        fi
    else
        echo "✗ Incorrect permissions: $PERMS (should be 600)"
    fi
else
    echo "✗ Environment file not found"
    exit 1
fi

# 2.4 Verify configuration file
echo "2.4 Verifying configuration file..."
if [[ -f "/etc/cloud-guardian.yaml" ]]; then
    echo "✓ Configuration file exists"
    
    # Check for zone_id
    if grep -q 'zone_id: ""' /etc/cloud-guardian.yaml; then
        echo "⚠ WARNING: Empty zone_id - update required"
    elif grep -q 'zone_id:' /etc/cloud-guardian.yaml; then
        echo "✓ Zone ID configured"
    fi
    
    # Check for IPv6 client allow
    if grep -q "YOUR_CLIENT_IPV6" /etc/cloud-guardian.yaml; then
        echo "⚠ WARNING: Placeholder IPv6 address - update required"
    elif grep -q "ipv6_allow:" /etc/cloud-guardian.yaml; then
        echo "✓ IPv6 client allow configured"
    fi
    
    # Check DNS record
    if grep -q "n8n.vps.bolk.dev" /etc/cloud-guardian.yaml; then
        echo "✓ n8n DNS record configured"
    fi
    
    # Validate YAML syntax
    if /opt/cloud-guardian/venv/bin/python -c "import yaml; yaml.safe_load(open('/etc/cloud-guardian.yaml'))" 2>/dev/null; then
        echo "✓ YAML syntax valid"
    else
        echo "✗ YAML syntax error"
        exit 1
    fi
else
    echo "✗ Configuration file not found"
    exit 1
fi

echo "✓ Step 2 completed: Runtime installed and configured"
