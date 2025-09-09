# Cloud Guardian VPS Deployment Guide

## Overview

Cloud Guardian is an automated VPS security hardening and Cloudflare management system that provides:

- **SSH Hardening**: Secure SSH configuration with IPv6 restriction
- **Firewall Management**: UFW configuration with public ports 80/443 only
- **Intrusion Prevention**: Fail2ban setup for brute-force protection
- **Docker Security**: Secure Docker daemon configuration
- **Cloudflare Integration**: Automated DNS and SSL/TLS management
- **Automated Enforcement**: 15-minute systemd timer for continuous security

## Quick Deployment

### Prerequisites

- Ubuntu/Debian VPS with root access
- SSH key-based authentication configured
- Cloudflare account with API token
- IPv6 connectivity (preferred) or IPv4 access

### Configuration Values

Update these values in your deployment:

```bash
# Your specific configuration
IPv6_ALLOW="2a02:a461:f84f:1:e135:2aca:e78e:63b1/128"
CF_API_TOKEN="vC15Trm58jdoCTTC6Che7clmHgZs5i4pID1DnK7z"
ZONE_ID="c58c15e45959a879f1309e92be02b07c"
DNS_RECORD="n8n.vps.bolk.dev → 31.97.47.51"
```

### Deployment Steps

#### Step 1: Deploy Files to VPS

```bash
# Test connectivity
ssh -6 -o ConnectTimeout=10 gebruiker@2a02:4780:41:f89c::1 exit

# Deploy files (IPv6 preferred)
scp -6 -r cloud-guardian gebruiker@2a02:4780:41:f89c::1:~/cloud-guardian

# Or IPv4 fallback
scp -4 -r cloud-guardian gebruiker@31.97.47.51:~/cloud-guardian

# Move to system location
sudo mv ~/cloud-guardian /opt/ && sudo chown -R root:root /opt/cloud-guardian
```

#### Step 2: Install and Configure

```bash
# Install system packages
sudo apt-get update && sudo apt-get install -y python3 python3-venv python3-pip ufw fail2ban

# Create Python environment
python3 -m venv /opt/cloud-guardian/venv
/opt/cloud-guardian/venv/bin/pip install -r /opt/cloud-guardian/requirements.txt

# Configure environment and settings
sudo install -d -m 700 /etc/cloud-guardian
echo 'CF_API_TOKEN=vC15Trm58jdoCTTC6Che7clmHgZs5i4pID1DnK7z' | sudo tee /etc/cloud-guardian/env >/dev/null
sudo chmod 600 /etc/cloud-guardian/env
sudo cp /opt/cloud-guardian/config/cloud-guardian.yaml /etc/cloud-guardian.yaml
```

#### Step 3: Enable Automation

```bash
# Create executable wrapper
sudo tee /usr/local/bin/cloud-guardian > /dev/null << 'EOF'
#!/bin/bash
source /opt/cloud-guardian/venv/bin/activate
exec python3 /opt/cloud-guardian/cloud_guardian.py "$@"
EOF
sudo chmod +x /usr/local/bin/cloud-guardian

# Install systemd timer
sudo install -Dm644 /opt/cloud-guardian/systemd/cloud-guardian.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now cloud-guardian.timer
```

#### Step 4: Execute and Verify

```bash
# Test configuration
cloud-guardian --test

# Run one-shot enforcement
cloud-guardian --config /etc/cloud-guardian.yaml --once --verbose

# Verify components
systemctl status cloud-guardian.timer
sudo ufw status verbose
ss -tulpn | grep -E ":22|:80|:443"
```

## Security Features

### SSH Hardening
- Root login disabled
- Password authentication disabled
- Access restricted to specific IPv6: `2a02:a461:f84f:1:e135:2aca:e78e:63b1/128`

### Firewall Configuration
- UFW active with default deny incoming
- Public access: ports 80/443 only
- SSH restricted to authorized IPv6 only

### Cloudflare Management
- Zone: `c58c15e45959a879f1309e92be02b07c`
- SSL/TLS: Strict mode with TLS 1.3
- HSTS enabled with 1-year max age
- DNS: `n8n.vps.bolk.dev` → `31.97.47.51`

### Automation
- Runs every 15 minutes via systemd timer
- Continuous security enforcement
- Automated DNS and SSL/TLS management

## Monitoring

```bash
# Check timer status
systemctl status cloud-guardian.timer

# View logs
sudo tail -f /var/log/cloud-guardian.log

# Manual test
cloud-guardian --test

# Manual enforcement
cloud-guardian --once --verbose
```

## Files Structure

```
cloud-guardian/
├── cloud_guardian.py          # Main security agent
├── requirements.txt           # Python dependencies
├── config/
│   └── cloud-guardian.yaml   # Configuration template
├── systemd/
│   ├── cloud-guardian.service # Systemd service
│   └── cloud-guardian.timer   # 15-minute timer
├── README.md                  # Project documentation
└── DEPLOYMENT.md             # This deployment guide
```

## Expected Results

After successful deployment:

- ✅ SSH accessible only from `2a02:a461:f84f:1:e135:2aca:e78e:63b1/128`
- ✅ Ports 80/443 publicly accessible, SSH restricted
- ✅ Fail2ban protecting against brute-force attacks
- ✅ Cloudflare managing DNS and SSL/TLS automatically
- ✅ Security enforcement running every 15 minutes
- ✅ All security policies continuously maintained
