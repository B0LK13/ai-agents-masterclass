#!/usr/bin/env python3
"""
Cloud Guardian - VPS Security & Monitoring Agent
Automated security hardening and Cloudflare management
"""

import os
import sys
import yaml
import subprocess
import logging
import requests
import json
from datetime import datetime
from pathlib import Path

# Configure logging
import tempfile
import os

# Use temp log file if /var/log is not writable
log_file = '/var/log/cloud-guardian.log'
if not os.access('/var/log', os.W_OK):
    log_file = os.path.join(tempfile.gettempdir(), 'cloud-guardian.log')

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class CloudGuardian:
    def __init__(self, config_path='/etc/cloud-guardian.yaml'):
        self.config_path = config_path
        self.config = self.load_config()
        self.cloudflare_api_token = os.getenv('CLOUDFLARE_API_TOKEN') or os.getenv('CF_API_TOKEN')
        
    def load_config(self):
        """Load configuration from YAML file"""
        try:
            with open(self.config_path, 'r') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            logger.error(f"Configuration file not found: {self.config_path}")
            sys.exit(1)
        except yaml.YAMLError as e:
            logger.error(f"Error parsing configuration: {e}")
            sys.exit(1)
    
    def run_command(self, command, check=True):
        """Execute shell command and return result"""
        try:
            result = subprocess.run(
                command, 
                shell=True, 
                capture_output=True, 
                text=True, 
                check=check
            )
            logger.info(f"Command executed: {command}")
            if result.stdout:
                logger.debug(f"Output: {result.stdout}")
            return result
        except subprocess.CalledProcessError as e:
            logger.error(f"Command failed: {command}")
            logger.error(f"Error: {e.stderr}")
            return None
    
    def harden_ssh(self):
        """Harden SSH configuration"""
        logger.info("Hardening SSH configuration...")
        
        ssh_config = self.config.get('ssh', {})
        sshd_config_path = '/etc/ssh/sshd_config'
        
        # Backup original config
        self.run_command(f'cp {sshd_config_path} {sshd_config_path}.backup')
        
        # Apply SSH hardening settings
        ssh_settings = {
            'PermitRootLogin': ssh_config.get('permit_root_login', 'no'),
            'PasswordAuthentication': ssh_config.get('password_auth', 'no'),
            'PubkeyAuthentication': 'yes',
            'Port': ssh_config.get('port', 22),
            'MaxAuthTries': ssh_config.get('max_auth_tries', 3),
            'ClientAliveInterval': ssh_config.get('client_alive_interval', 300),
            'ClientAliveCountMax': ssh_config.get('client_alive_count_max', 2),
            'Protocol': 2
        }
        
        # Update SSH configuration
        for key, value in ssh_settings.items():
            self.run_command(f"sed -i 's/^#{key}.*/{key} {value}/' {sshd_config_path}")
            self.run_command(f"sed -i 's/^{key}.*/{key} {value}/' {sshd_config_path}")
        
        # Restart SSH service
        self.run_command('systemctl restart sshd')
        logger.info("SSH hardening completed")
    
    def configure_ufw(self):
        """Configure UFW firewall"""
        logger.info("Configuring UFW firewall...")
        
        firewall_config = self.config.get('firewall', {})
        
        # Reset UFW
        self.run_command('ufw --force reset')
        
        # Set default policies
        self.run_command('ufw default deny incoming')
        self.run_command('ufw default allow outgoing')
        
        # Allow SSH
        ssh_port = self.config.get('ssh', {}).get('port', 22)
        self.run_command(f'ufw allow {ssh_port}/tcp')
        
        # Allow configured ports
        allowed_ports = firewall_config.get('allowed_ports', [])
        for port in allowed_ports:
            self.run_command(f'ufw allow {port}')
        
        # Enable UFW
        self.run_command('ufw --force enable')
        logger.info("UFW firewall configured")
    
    def configure_fail2ban(self):
        """Configure Fail2ban"""
        logger.info("Configuring Fail2ban...")
        
        fail2ban_config = self.config.get('fail2ban', {})
        
        # Install fail2ban if not present
        self.run_command('apt-get update && apt-get install -y fail2ban')
        
        # Create jail.local configuration
        jail_config = f"""[DEFAULT]
bantime = {fail2ban_config.get('ban_time', 3600)}
findtime = {fail2ban_config.get('find_time', 600)}
maxretry = {fail2ban_config.get('max_retry', 3)}

[sshd]
enabled = true
port = {self.config.get('ssh', {}).get('port', 22)}
filter = sshd
logpath = /var/log/auth.log
maxretry = {fail2ban_config.get('ssh_max_retry', 3)}
"""
        
        with open('/etc/fail2ban/jail.local', 'w') as f:
            f.write(jail_config)
        
        # Restart fail2ban
        self.run_command('systemctl restart fail2ban')
        self.run_command('systemctl enable fail2ban')
        logger.info("Fail2ban configured")
    
    def secure_docker(self):
        """Secure Docker installation"""
        logger.info("Securing Docker...")
        
        docker_config = self.config.get('docker', {})
        
        if not docker_config.get('enabled', False):
            logger.info("Docker security skipped (not enabled)")
            return
        
        # Create docker daemon configuration
        daemon_config = {
            "log-driver": "json-file",
            "log-opts": {
                "max-size": "10m",
                "max-file": "3"
            },
            "userland-proxy": False,
            "experimental": False,
            "live-restore": True
        }
        
        os.makedirs('/etc/docker', exist_ok=True)
        with open('/etc/docker/daemon.json', 'w') as f:
            json.dump(daemon_config, f, indent=2)
        
        # Restart Docker
        self.run_command('systemctl restart docker')
        logger.info("Docker secured")
    
    def cloudflare_api_request(self, endpoint, method='GET', data=None):
        """Make Cloudflare API request"""
        base_url = 'https://api.cloudflare.com/client/v4'
        headers = {
            'Authorization': f'Bearer {self.cloudflare_api_token}',
            'Content-Type': 'application/json'
        }
        
        url = f"{base_url}/{endpoint}"
        
        try:
            if method == 'GET':
                response = requests.get(url, headers=headers)
            elif method == 'POST':
                response = requests.post(url, headers=headers, json=data)
            elif method == 'PUT':
                response = requests.put(url, headers=headers, json=data)
            elif method == 'PATCH':
                response = requests.patch(url, headers=headers, json=data)
            
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Cloudflare API request failed: {e}")
            return None
    
    def manage_cloudflare_dns(self):
        """Manage Cloudflare DNS records"""
        logger.info("Managing Cloudflare DNS records...")
        
        cloudflare_config = self.config.get('cloudflare', {})
        zone_id = cloudflare_config.get('zone_id')
        
        if not zone_id:
            logger.error("Cloudflare zone_id not configured")
            return
        
        # Get current public IP
        try:
            public_ip = requests.get('https://ipv4.icanhazip.com').text.strip()
            logger.info(f"Current public IP: {public_ip}")
        except:
            logger.error("Failed to get public IP")
            return
        
        # Update DNS records
        dns_records = cloudflare_config.get('dns_records', [])
        for record in dns_records:
            record_name = record.get('name')
            record_type = record.get('type', 'A')
            
            # Get existing record
            records = self.cloudflare_api_request(f"zones/{zone_id}/dns_records?name={record_name}&type={record_type}")
            
            if records and records.get('result'):
                # Update existing record
                record_id = records['result'][0]['id']
                update_data = {
                    'type': record_type,
                    'name': record_name,
                    'content': public_ip,
                    'ttl': record.get('ttl', 300)
                }
                result = self.cloudflare_api_request(f"zones/{zone_id}/dns_records/{record_id}", 'PUT', update_data)
                if result:
                    logger.info(f"Updated DNS record: {record_name}")
            else:
                # Create new record
                create_data = {
                    'type': record_type,
                    'name': record_name,
                    'content': public_ip,
                    'ttl': record.get('ttl', 300)
                }
                result = self.cloudflare_api_request(f"zones/{zone_id}/dns_records", 'POST', create_data)
                if result:
                    logger.info(f"Created DNS record: {record_name}")
    
    def configure_ssl_tls(self):
        """Configure Cloudflare SSL/TLS settings"""
        logger.info("Configuring Cloudflare SSL/TLS...")
        
        cloudflare_config = self.config.get('cloudflare', {})
        zone_id = cloudflare_config.get('zone_id')
        
        if not zone_id:
            logger.error("Cloudflare zone_id not configured")
            return
        
        ssl_config = cloudflare_config.get('ssl', {})
        
        # Set SSL mode
        ssl_mode = ssl_config.get('mode', 'full')
        ssl_data = {'value': ssl_mode}
        result = self.cloudflare_api_request(f"zones/{zone_id}/settings/ssl", 'PATCH', ssl_data)
        if result:
            logger.info(f"SSL mode set to: {ssl_mode}")
        
        # Enable Always Use HTTPS
        if ssl_config.get('always_use_https', True):
            https_data = {'value': 'on'}
            result = self.cloudflare_api_request(f"zones/{zone_id}/settings/always_use_https", 'PATCH', https_data)
            if result:
                logger.info("Always Use HTTPS enabled")
    
    def run_enforcement(self):
        """Run complete security enforcement"""
        logger.info("Starting Cloud Guardian enforcement...")
        
        try:
            # VPS Security Hardening
            self.harden_ssh()
            self.configure_ufw()
            self.configure_fail2ban()
            self.secure_docker()
            
            # Cloudflare Management
            if self.cloudflare_api_token:
                self.manage_cloudflare_dns()
                self.configure_ssl_tls()
            else:
                logger.warning("Cloudflare API token not found, skipping Cloudflare management")
            
            logger.info("Cloud Guardian enforcement completed successfully")
            
        except Exception as e:
            logger.error(f"Enforcement failed: {e}")
            sys.exit(1)

def main():
    import argparse

    parser = argparse.ArgumentParser(description='Cloud Guardian VPS Security Agent')
    parser.add_argument('--config', default='/etc/cloud-guardian.yaml',
                       help='Configuration file path')
    parser.add_argument('--test', action='store_true',
                       help='Test configuration only')
    parser.add_argument('--once', action='store_true',
                       help='Run enforcement once and exit')
    parser.add_argument('--verbose', action='store_true',
                       help='Enable verbose logging')

    args = parser.parse_args()

    # Set logging level
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    # Test mode
    if args.test:
        print("Cloud Guardian test mode - configuration validation")
        try:
            guardian = CloudGuardian(args.config)
            print("✓ Configuration loaded successfully")
            print(f"✓ Config file: {args.config}")
            print(f"✓ Cloudflare token: {'configured' if guardian.cloudflare_api_token else 'missing'}")
            return 0
        except Exception as e:
            print(f"✗ Configuration error: {e}")
            return 1

    # Normal enforcement
    try:
        guardian = CloudGuardian(args.config)
        guardian.run_enforcement()
        return 0
    except Exception as e:
        logger.error(f"Enforcement failed: {e}")
        return 1

if __name__ == '__main__':
    sys.exit(main())
