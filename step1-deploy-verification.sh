#!/bin/bash

# Step 1: Deploy Agent Files Verification
echo "=== Step 1: Deploy Agent Files to VPS ==="

# 1.1 Get VPS IPv6 address
echo "1.1 Getting VPS IPv6 address..."
VPS_IPV6=$(ip -6 addr show scope global | awk '/inet6/{print $2}' | head -n1)
echo "VPS IPv6: $VPS_IPV6"

# 1.2 Verify files were copied correctly
echo "1.2 Verifying file deployment..."
if [[ -d "/opt/cloud-guardian" ]]; then
    echo "✓ /opt/cloud-guardian directory exists"
    ls -la /opt/cloud-guardian/
else
    echo "✗ /opt/cloud-guardian directory not found"
    exit 1
fi

# 1.3 Check ownership
echo "1.3 Checking file ownership..."
OWNER=$(stat -c '%U:%G' /opt/cloud-guardian)
if [[ "$OWNER" == "root:root" ]]; then
    echo "✓ Correct ownership: $OWNER"
else
    echo "✗ Incorrect ownership: $OWNER (should be root:root)"
    exit 1
fi

# 1.4 Check required files
echo "1.4 Checking required files..."
REQUIRED_FILES=(
    "cloud_guardian.py"
    "requirements.txt"
    "config/cloud-guardian.yaml"
    "systemd/cloud-guardian.service"
    "systemd/cloud-guardian.timer"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "/opt/cloud-guardian/$file" ]]; then
        echo "✓ $file exists"
    else
        echo "✗ $file missing"
        exit 1
    fi
done

echo "✓ Step 1 completed successfully: Agent files deployed to VPS"
