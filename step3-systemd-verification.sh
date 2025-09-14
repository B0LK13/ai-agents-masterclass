#!/bin/bash

# Step 3: Enable Systemd Timer Verification
echo "=== Step 3: Enable Systemd Timer ==="

# 3.1 Verify systemd files installed
echo "3.1 Verifying systemd files..."
if [[ -f "/etc/systemd/system/cloud-guardian.service" ]]; then
    echo "✓ Service file installed"
    PERMS=$(stat -c '%a' /etc/systemd/system/cloud-guardian.service)
    echo "  Permissions: $PERMS"
else
    echo "✗ Service file not found"
    exit 1
fi

if [[ -f "/etc/systemd/system/cloud-guardian.timer" ]]; then
    echo "✓ Timer file installed"
    PERMS=$(stat -c '%a' /etc/systemd/system/cloud-guardian.timer)
    echo "  Permissions: $PERMS"
else
    echo "✗ Timer file not found"
    exit 1
fi

# 3.2 Verify systemd daemon reloaded
echo "3.2 Checking systemd daemon status..."
if systemctl daemon-reload; then
    echo "✓ Systemd daemon reloaded successfully"
else
    echo "✗ Failed to reload systemd daemon"
    exit 1
fi

# 3.3 Verify service enabled
echo "3.3 Verifying service enabled..."
if systemctl is-enabled cloud-guardian.service >/dev/null 2>&1; then
    echo "✓ Service enabled"
else
    echo "✗ Service not enabled"
    exit 1
fi

# 3.4 Verify timer enabled and active
echo "3.4 Verifying timer status..."
if systemctl is-enabled cloud-guardian.timer >/dev/null 2>&1; then
    echo "✓ Timer enabled"
else
    echo "✗ Timer not enabled"
    exit 1
fi

if systemctl is-active cloud-guardian.timer >/dev/null 2>&1; then
    echo "✓ Timer active"
else
    echo "✗ Timer not active"
    exit 1
fi

# 3.5 Check timer schedule
echo "3.5 Checking timer schedule..."
systemctl list-timers cloud-guardian.timer --no-pager
echo ""

# 3.6 Verify 15-minute interval
echo "3.6 Verifying 15-minute interval..."
if grep -q "OnCalendar=\*:0/15" /etc/systemd/system/cloud-guardian.timer; then
    echo "✓ 15-minute interval configured"
else
    echo "⚠ Timer interval may not be 15 minutes"
fi

echo "✓ Step 3 completed: Systemd timer enabled for 15-minute automation"
