# Homelab Installation Guide

Complete installation guide for setting up the homelab infrastructure from scratch, including prerequisites, step-by-step deployment, and post-installation configuration.

## Overview

This guide covers the complete setup of a homelab infrastructure using Ansible collections to deploy:

- **K3s Kubernetes cluster** on Raspberry Pi nodes
- **LXC containers** in Proxmox for various services
- **Monitoring stack** with Prometheus, Grafana, and Loki
- **Security layer** with VPN, DNS filtering, and hardening
- **Media management** with automated download and streaming services

## Prerequisites

### Hardware Requirements

#### Minimum Setup

- **1x Proxmox VE host** (8GB RAM, 100GB storage)
- **2x Raspberry Pi 4** (4GB RAM each) for K3s cluster
- **Network switch** with VLAN support (optional)
- **Domain name** or internal DNS setup

#### Recommended Setup

- **2x Proxmox VE hosts** (16GB RAM, 500GB SSD each)
- **4x Raspberry Pi 4** (8GB RAM each) for K3s cluster
- **Managed switch** with VLAN and monitoring support
- **External domain** with DNS API access for certificates
- **UPS** for power protection

### Network Requirements

```text
Network Layout:
┌─────────────────────────────────────────────┐
│ Router/Gateway: 192.168.0.1                 │
├─────────────────────────────────────────────┤
│ Proxmox Hosts:                              │
│   pve-mac: 192.168.0.56                     │
│   pve-nas: 192.168.0.57                     │
├─────────────────────────────────────────────┤
│ Management:                                 │
│   nas-bastion: 192.168.0.109                │
│   k3s-bastion: 192.168.0.110                │
├─────────────────────────────────────────────┤
│ K3s Cluster:                                │
│   k3-01 (server): 192.168.0.111             │
│   k3-02 (agent): 192.168.0.112              │
│   k3-03 (agent): 192.168.0.113              │
│   k3-04 (agent): 192.168.0.114              │
├─────────────────────────────────────────────┤
│ Core Services: 192.168.0.200-210            │
│ NAS Services: 192.168.0.230-235             │
│ Monitoring: 192.168.0.240+                  │
└─────────────────────────────────────────────┘
```

### Software Requirements

#### Control Machine (Ansible Host)

- **Ubuntu 22.04 LTS** or similar Linux distribution
- **Python 3.12+** with pip (aligned with CI/CD pipeline)
- **Git** for repository management
- **SSH client** configured with keys

#### Proxmox VE Hosts

- **Proxmox VE 8.0+** installed and configured
- **API access** enabled with root@pam user
- **SSH keys** configured for root access
- **Storage** configured (local, local-lvm, or shared storage)

#### Raspberry Pi Nodes

- **Ubuntu Server 22.04 LTS** (64-bit)
- **SSH enabled** with public key authentication
- **Static IP addresses** configured
- **Internet connectivity** for package downloads

## Phase 1: Environment Preparation

### 1.1 Control Machine Setup

Install required software on your Ansible control machine:

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Python and development tools
sudo apt install -y python3 python3-pip python3-venv git curl wget

# Create Python virtual environment
python3 -m venv ~/.venv/homelab
source ~/.venv/homelab/bin/activate

# Install Ansible and required Python packages
pip install -r requirements.txt

# Or install manually:
# pip install ansible-core>=2.17.0
# pip install ansible-lint>=24.0.0 yamllint>=1.35.0

# Install additional tools
sudo apt install -y sshpass rsync jq
```

### 1.2 SSH Key Setup

Configure SSH keys for secure authentication:

```bash
# Generate SSH key pair (if not already present)
ssh-keygen -t ed25519 -f ~/.ssh/homelab_ed25519 -C "homelab-ansible"

# Add to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/homelab_ed25519

# Configure SSH client
cat >> ~/.ssh/config << EOF
Host pve-*
    User root
    IdentityFile ~/.ssh/homelab_ed25519
    StrictHostKeyChecking accept-new

Host 192.168.0.*
    User pbs
    IdentityFile ~/.ssh/homelab_ed25519
    StrictHostKeyChecking accept-new

Host k3s-*
    User pbs
    IdentityFile ~/.ssh/homelab_ed25519
    StrictHostKeyChecking accept-new
EOF

chmod 600 ~/.ssh/config
```

> **Key migration:** If you rebuild or migrate the control machine and lose access to existing
> hosts, see the [SSH Key Recovery](TROUBLESHOOTING.md#ssh-key-recovery) section in the
> troubleshooting guide. A recovery script for K3s Pi nodes is available at
> `scripts/recovery.sh`.

### 1.3 Repository Setup

Clone and configure the homelab repository:

```bash
# Clone repository
git clone https://github.com/pbs-tech/homelab.git
cd homelab

# Install Ansible collections and dependencies
ansible-galaxy install -r requirements.yml

# Verify collections are available
ansible-galaxy collection list homelab
```

## Phase 2: Proxmox VE Preparation

### 2.1 Proxmox Host Configuration

Configure each Proxmox VE host:

```bash
# Update Proxmox hosts
ssh root@pve-mac "apt update && apt upgrade -y"
ssh root@pve-nas "apt update && apt upgrade -y"

# Install additional packages
ssh root@pve-mac "apt install -y qemu-guest-agent"
ssh root@pve-nas "apt install -y qemu-guest-agent"

# Configure storage (if needed)
ssh root@pve-mac "pvesm add dir backup --path /var/lib/vz/backup --content backup"
```

### 2.2 LXC Template Setup

Download required LXC templates:

```bash
# Download Ubuntu 22.04 template on both hosts
ssh root@pve-mac "pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
ssh root@pve-nas "pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst"

# Verify templates are available
ssh root@pve-mac "pveam list local | grep ubuntu-22.04"
ssh root@pve-nas "pveam list local | grep ubuntu-22.04"
```

### 2.3 Network Configuration

Ensure proper network configuration:

```bash
# Check network bridges
ssh root@pve-mac "brctl show"

# Verify network connectivity
ssh root@pve-mac "ping -c 3 8.8.8.8"
ssh root@pve-nas "ping -c 3 8.8.8.8"
```

## Phase 3: Raspberry Pi Preparation

### 3.1 Pi Operating System Setup

Install Ubuntu Server on each Raspberry Pi:

1. Download Ubuntu Server 22.04 LTS (64-bit) for Raspberry Pi
2. Flash to SD cards using Raspberry Pi Imager or similar tool
3. Enable SSH and configure user accounts during imaging
4. Boot each Pi and complete initial setup

### 3.2 Pi Network Configuration

Configure static IP addresses:

```bash
# On each Raspberry Pi, edit netplan configuration
sudo nano /etc/netplan/50-cloud-init.yaml

# Example configuration:
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 192.168.0.111/24  # Adjust for each Pi
      gateway4: 192.168.0.1
      nameservers:
        addresses:
          - 192.168.0.1
          - 8.8.8.8

# Apply configuration
sudo netplan apply
```

### 3.3 Pi SSH Key Distribution

Install SSH keys on all Raspberry Pi nodes:

```bash
# Copy SSH keys to each Pi
for i in {111..114}; do
  ssh-copy-id -i ~/.ssh/homelab_ed25519.pub pbs@192.168.0.$i
done

# Test connectivity
for i in {111..114}; do
  echo -n "192.168.0.$i: "
  ssh pbs@192.168.0.$i "hostname" 2>/dev/null && echo "OK" || echo "FAILED"
done
```

## Phase 4: Inventory Configuration

### 4.1 Create Inventory Files

Set up Ansible inventory:

```bash
# The repository includes a pre-configured inventory file
# Edit it to match your environment
nano inventory/hosts.yml

# Create vault file from example
cp inventory/group_vars/vault.yml.example inventory/group_vars/vault.yml

# Review and customize as needed
nano inventory/group_vars/vault.yml
```

Example `hosts.yml`:

```yaml
all:
  children:
    proxmox_hosts:
      hosts:
        pve-mac:
          ansible_host: 192.168.0.56
          ansible_user: root
        pve-nas:
          ansible_host: 192.168.0.57
          ansible_user: root

    k3s_cluster:
      children:
        server:
          hosts:
            k3-01:
              ansible_host: 192.168.0.111
              ansible_user: pbs
        agent:
          hosts:
            k3-02:
              ansible_host: 192.168.0.112
              ansible_user: pbs
            k3-03:
              ansible_host: 192.168.0.113
              ansible_user: pbs
            k3-04:
              ansible_host: 192.168.0.114
              ansible_user: pbs
```

### 4.2 Configure Variables

The repository includes a pre-configured `inventory/hosts.yml` with default settings.
Key variables are defined in collection-specific inventories:

- **Common settings**: `ansible_collections/homelab/common/inventory/group_vars/`
- **K3s settings**: `ansible_collections/homelab/k3s/inventory/`
- **Proxmox LXC settings**: `ansible_collections/homelab/proxmox_lxc/inventory/`

Review and customize these files as needed for your environment:

```bash
# Review root inventory
cat inventory/hosts.yml

# Review collection inventories
cat ansible_collections/homelab/k3s/inventory/hosts.yml
cat ansible_collections/homelab/proxmox_lxc/inventory/proxmox.yml
```

### 4.3 Create Vault File

Store sensitive data securely:

```bash
# Create vault file from example
cp inventory/group_vars/vault.yml.example inventory/group_vars/vault.yml

# Edit the vault file to add your credentials
nano inventory/group_vars/vault.yml

# Encrypt the vault file
ansible-vault encrypt inventory/group_vars/vault.yml

# Or edit an already encrypted vault:
ansible-vault edit inventory/group_vars/vault.yml
```

Required vault variables (see `vault.yml.example` for template):

```yaml
---
# Proxmox API Token Authentication (preferred method)
vault_proxmox_api_tokens:
  pve_mac:
    token_id: "root@pam!ansible"
    token_secret: "your-token-secret"
  pve_nas:
    token_id: "root@pam!ansible"
    token_secret: "your-token-secret"

# SSL/TLS Configuration
vault_ssl_email: "admin@yourdomain.com"
```

**Vault Password Management:**

```bash
# Save vault password for convenience
echo "your_vault_password" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible_vault_pass
```

## Phase 5: Infrastructure Deployment

### 5.1 Pre-deployment Validation

Validate configuration before deployment:

```bash
# Test inventory connectivity
ansible all -m ping -i inventory/hosts.yml

# Validate playbook syntax
ansible-playbook --syntax-check playbooks/infrastructure.yml

# Run in check mode to see what would change
ansible-playbook --check --diff playbooks/infrastructure.yml
```

### 5.2 Foundation Deployment (Phase 1)

Deploy bastion hosts and core infrastructure:

```bash
# Deploy foundation services
ansible-playbook playbooks/infrastructure.yml --tags "foundation,phase1"

# Verify bastion hosts are accessible
ansible bastion_hosts -m ping -i inventory/hosts.yml

# Check service status
for host in 109 110; do
  echo "Checking bastion 192.168.0.$host:"
  ssh pbs@192.168.0.$host "sudo systemctl status sshd fail2ban ufw"
done
```

### 5.3 Networking Deployment (Phase 2)

Deploy DNS, VPN, and reverse proxy services:

```bash
# Deploy networking services
ansible-playbook playbooks/infrastructure.yml --tags "networking,phase2"

# Test DNS resolution
nslookup google.com 192.168.0.204  # AdGuard
nslookup google.com 192.168.0.202  # Unbound

# Test Traefik
curl -I http://192.168.0.205
```

### 5.4 Monitoring Deployment (Phase 3)

Deploy monitoring and observability stack:

```bash
# Deploy monitoring services
ansible-playbook playbooks/infrastructure.yml --tags "monitoring,phase3"

# Verify monitoring stack
curl -s http://192.168.0.200:9090/api/v1/targets | jq '.data.activeTargets[].health'
curl -s http://192.168.0.201:3000/api/health | jq '.'
```

### 5.5 Application Deployment (Phase 4)

Deploy application and media services:

```bash
# Deploy application services
ansible-playbook playbooks/infrastructure.yml --tags "applications,phase4"

# Test Home Assistant
curl -s http://192.168.0.208:8123/api/ | jq '.'

# Test media services
curl -s http://192.168.0.230:8989/api/v3/system/status | jq '.version'
```

### 5.6 K3s Cluster Deployment (Phase 5)

Deploy Kubernetes cluster:

```bash
# Deploy K3s cluster
ansible-playbook playbooks/infrastructure.yml --tags "k3s,phase5"

# Verify cluster status
kubectl --kubeconfig /tmp/k3s.yaml get nodes
kubectl --kubeconfig /tmp/k3s.yaml get pods --all-namespaces
```

## Phase 6: Post-Installation Configuration

### 6.1 SSL Certificate Setup

Configure SSL certificates for all services:

```bash
# Wait for certificate generation (may take a few minutes)
sleep 300

# Check certificate status
curl -s https://traefik.homelab.lan:8080/api/http/routers | jq '.[] | select(.tls != null)'

# Test HTTPS access
curl -I https://prometheus.homelab.lan
curl -I https://grafana.homelab.lan
```

### 6.2 Service Configuration

Configure individual services:

```bash
# Configure Grafana data sources and dashboards
curl -X POST "https://admin:${vault_grafana_admin_password}@grafana.homelab.lan/api/datasources" \
  -H "Content-Type: application/json" \
  -d '{"name":"Prometheus","type":"prometheus","url":"http://192.168.0.200:9090","access":"proxy"}'

# Import pre-built dashboards
for dashboard in node-exporter k3s-cluster traefik; do
  curl -X POST "https://admin:${vault_grafana_admin_password}@grafana.homelab.lan/api/dashboards/import" \
    -H "Content-Type: application/json" \
    -d @"dashboards/${dashboard}.json"
done
```

### 6.3 DNS Configuration

Update local DNS to use AdGuard Home:

```bash
# Update router DNS settings to point to AdGuard (192.168.0.204)
# OR update individual device DNS settings

# Test DNS filtering
nslookup doubleclick.net 192.168.0.204  # Should be blocked
nslookup google.com 192.168.0.204       # Should resolve
```

### 6.4 VPN Client Setup

Configure VPN clients for remote access:

```bash
# Generate client configurations
ansible-playbook playbooks/networking.yml --tags "wireguard" -e "client_name=laptop"
ansible-playbook playbooks/networking.yml --tags "wireguard" -e "client_name=phone"

# Copy client configs
scp pbs@192.168.0.203:/opt/wireguard/clients/laptop.conf ./
scp pbs@192.168.0.203:/opt/wireguard/clients/phone.conf ./

# Import configs into WireGuard clients
```

## Phase 7: Testing and Validation

### 7.1 Connectivity Testing

Test all service endpoints:

```bash
#!/bin/bash
# test-services.sh

services=(
  "traefik.homelab.lan:8080"
  "prometheus.homelab.lan"
  "grafana.homelab.lan"
  "adguard.homelab.lan"
  "ha.homelab.lan"
  "sonarr.homelab.lan"
  "radarr.homelab.lan"
  "jellyfin.homelab.lan"
)

for service in "${services[@]}"; do
  echo -n "Testing $service: "
  if curl -s -I "https://$service" | grep -q "HTTP/[12]\\.[01] [23]"; then
    echo "OK"
  else
    echo "FAILED"
  fi
done
```

### 7.2 Security Validation

Verify security configuration:

```bash
# Check SSH hardening
ansible all -m shell -a "sshd -T | grep -E 'passwordauthentication|permitrootlogin|protocol'"

# Verify firewall status
ansible all -m shell -a "ufw status"

# Check for running security services
ansible all -m shell -a "systemctl is-active fail2ban auditd"
```

### 7.3 Performance Testing

Basic performance validation:

```bash
# Check resource usage
ansible all -m shell -a "free -h && df -h"

# Test network performance between services
ansible prometheus -m shell -a "curl -w '%{time_total}' -s -o /dev/null http://192.168.0.201:3000"
```

## Phase 8: Backup and Documentation

### 8.1 Create Backups

Set up initial backups:

```bash
# Create LXC snapshots
for i in {200..210}; do
  pct snapshot $i "initial-install-$(date +%Y%m%d)"
done

# Backup configurations
mkdir -p ~/homelab-backups/$(date +%Y%m%d)
cp -r inventory/ ~/homelab-backups/$(date +%Y%m%d)/
tar -czf ~/homelab-backups/$(date +%Y%m%d)/configs.tar.gz /etc/
```

### 8.2 Document Configuration

Create configuration documentation:

```bash
# Generate service inventory
ansible-inventory --list -i inventory/hosts.yml > service-inventory.json

# Document network configuration
ip route show > network-routes.txt
cat /etc/resolv.conf > dns-config.txt

# Export service configurations
curl -s https://traefik.homelab.lan:8080/api/rawdata | jq '.' > traefik-config.json
```

## Troubleshooting Installation Issues

### Common Problems and Solutions

#### 1. SSH Connection Failures

```bash
# Check SSH key permissions
chmod 600 ~/.ssh/homelab_ed25519
chmod 644 ~/.ssh/homelab_ed25519.pub

# Verify SSH agent has key loaded
ssh-add -l

# Test direct SSH connection
ssh -vvv pbs@192.168.0.111
```

#### 2. Proxmox API Connection Issues

```bash
# Test API connectivity
curl -k -u "root@pam:password" "https://192.168.0.56:8006/api2/json/version"

# Check firewall settings on Proxmox host
iptables -L | grep 8006
```

#### 3. Container Creation Failures

```bash
# Check available templates
pveam list local | grep ubuntu

# Verify storage space
df -h /var/lib/vz
pvesh get /nodes/pve-mac/storage/local/status
```

#### 4. Service Access Issues

```bash
# Check service status
pct exec 205 -- systemctl status traefik
pct exec 200 -- systemctl status prometheus

# Verify network connectivity
ping 192.168.0.205
telnet 192.168.0.205 80
```

### Getting Help

If you encounter issues during installation:

1. **Check logs**: Use `journalctl -f` on affected systems
2. **Run with debug**: Add `-vvv` to ansible-playbook commands
3. **Verify prerequisites**: Ensure all requirements are met
4. **Consult documentation**: Review service-specific documentation
5. **Seek support**: Use GitHub issues or community forums

## Next Steps

After successful installation:

1. **Configure monitoring alerts** in AlertManager
2. **Set up automated backups** for critical data
3. **Customize service configurations** for your needs
4. **Add additional services** as required
5. **Review security settings** and harden further if needed
6. **Document customizations** for future reference

## Maintenance Schedule

Establish regular maintenance routines:

- **Daily**: Monitor service health via Grafana
- **Weekly**: Review logs and update packages
- **Monthly**: Review security configurations and backup retention
- **Quarterly**: Update service versions and review capacity

This completes the homelab installation. Your infrastructure should now be fully operational with monitoring, security, and automation in place.
