# Cloud Guardian VPS Security Agent

Automated VPS security hardening and Cloudflare management system.

## Features

- **SSH Hardening**: Secure SSH configuration with key-based authentication
- **Firewall Management**: UFW firewall configuration and management
- **Intrusion Prevention**: Fail2ban setup for brute-force protection
- **Docker Security**: Secure Docker daemon configuration
- **Cloudflare Integration**: Automated DNS and SSL/TLS management
- **Automated Enforcement**: Systemd timer for regular security checks

## Quick Deployment

### Prerequisites

- Ubuntu/Debian VPS with root access
- SSH key-based authentication configured
- Cloudflare account with API token (optional)

### 1. Deploy to VPS

```bash
# Make deployment script executable
chmod +x deploy.sh

# Deploy to VPS (update VPS_IP in deploy.sh first)
./deploy.sh
```

### 2. Configure on VPS

SSH to your VPS and configure:

```bash
# Edit main configuration
sudo nano /etc/cloud-guardian.yaml

# Add Cloudflare API token
sudo nano /etc/cloud-guardian/env
```

### 3. Test and Enable

```bash
# Test configuration
sudo cloud-guardian --test

# Run one-shot enforcement
sudo cloud-guardian

# Enable automated enforcement (every 15 minutes)
sudo systemctl enable --now cloud-guardian.timer

# Check status
sudo systemctl status cloud-guardian.timer
```

## Configuration

### Main Configuration (`/etc/cloud-guardian.yaml`)

```yaml
ssh:
  port: 22
  permit_root_login: "no"
  password_auth: "no"

firewall:
  allowed_ports:
    - "80/tcp"
    - "443/tcp"

cloudflare:
  zone_id: "your_zone_id_here"
  dns_records:
    - name: "example.com"
      type: "A"
```

### Environment Variables (`/etc/cloud-guardian/env`)

```bash
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token_here
```

## Manual Installation

If you prefer manual installation:

```bash
# Copy cloud-guardian directory to VPS
scp -r cloud-guardian/ root@your-vps-ip:/tmp/

# SSH to VPS and install
ssh root@your-vps-ip
cd /tmp/cloud-guardian
chmod +x install.sh
sudo ./install.sh
```

## Security Features

### SSH Hardening
- Disable root login
- Disable password authentication
- Configure connection timeouts
- Set maximum authentication attempts

### Firewall Configuration
- Default deny incoming policy
- Allow only specified ports
- UFW management

### Fail2ban Protection
- SSH brute-force protection
- Configurable ban times
- Custom jail configurations

### Docker Security
- Secure daemon configuration
- Logging limits
- Security best practices

### Cloudflare Management
- Automatic DNS record updates
- SSL/TLS configuration
- Security settings management

## Monitoring

### Logs
- Main log: `/var/log/cloud-guardian.log`
- Systemd journal: `journalctl -u cloud-guardian`

### Status Checks
```bash
# Check timer status
sudo systemctl status cloud-guardian.timer

# View recent logs
sudo tail -f /var/log/cloud-guardian.log

# Manual enforcement
sudo cloud-guardian
```

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   - Verify VPS IP address
   - Check SSH key permissions
   - Ensure VPS is accessible

2. **Cloudflare API Errors**
   - Verify API token permissions
   - Check zone ID configuration
   - Ensure token has DNS edit permissions

3. **Service Not Running**
   - Check systemd status: `systemctl status cloud-guardian.timer`
   - Review logs: `journalctl -u cloud-guardian`
   - Verify configuration: `cloud-guardian --test`

### Support

For issues or questions:
1. Check logs in `/var/log/cloud-guardian.log`
2. Verify configuration with `cloud-guardian --test`
3. Review systemd status and journal logs
