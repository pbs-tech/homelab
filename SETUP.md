# Homelab Quick Setup Guide

This guide provides a streamlined path to get your homelab infrastructure up and running quickly. For detailed installation instructions, see [INSTALLATION.md](docs/INSTALLATION.md).

## Prerequisites Checklist

Before you begin, ensure you have:

- [ ] **Hardware**:
  - At least 1 Proxmox VE host (8GB RAM, 100GB storage minimum)
  - 2-4 Raspberry Pi 4 boards (4GB+ RAM) for K3s cluster
  - Network switch and cables
  - Domain name (optional, for external access)

- [ ] **Software on Control Machine**:
  - Ubuntu 22.04 LTS (or similar Linux distribution)
  - Python 3.12+
  - Git
  - SSH keys generated and configured

- [ ] **Network Configuration**:
  - Static IP addresses assigned for all nodes
  - SSH access to all Proxmox hosts and Raspberry Pi nodes
  - Internet connectivity for package downloads

## Quick Start (30 Minutes)

### Step 1: Prepare Your Control Machine (5 minutes)

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y python3 python3-pip python3-venv git

# Create and activate virtual environment
python3 -m venv ~/.venv/homelab
source ~/.venv/homelab/bin/activate

# Make activation persistent (add to .bashrc or .zshrc)
echo "source ~/.venv/homelab/bin/activate" >> ~/.bashrc
```

### Step 2: Clone Repository and Install Dependencies (5 minutes)

```bash
# Clone the repository
git clone https://github.com/pbs-tech/homelab.git
cd homelab

# Install Python dependencies
pip install -r requirements.txt

# Install Ansible collections
ansible-galaxy install -r requirements.yml
```

### Step 3: Configure SSH Access (5 minutes)

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -f ~/.ssh/homelab_ed25519 -C "homelab-ansible"

# Copy SSH keys to all nodes
# For Raspberry Pi nodes (adjust IPs as needed)
for i in {111..114}; do
  ssh-copy-id -i ~/.ssh/homelab_ed25519.pub pbs@192.168.0.$i
done

# For Proxmox hosts
ssh-copy-id -i ~/.ssh/homelab_ed25519.pub root@192.168.0.56  # pve-mac
ssh-copy-id -i ~/.ssh/homelab_ed25519.pub root@192.168.0.57  # pve-nas

# Test connectivity
ansible all -m ping -i inventory/hosts.yml
```

### Step 4: Configure Vault (5 minutes)

```bash
# Create vault file from example
cp inventory/group_vars/vault.yml.example inventory/group_vars/vault.yml

# Edit vault with your credentials
nano inventory/group_vars/vault.yml
```

**Required changes in vault.yml:**
- Replace `vault_proxmox_api_tokens` with your Proxmox API tokens
- Update `vault_ssl_email` with your email address

**How to create Proxmox API tokens:**
1. Login to Proxmox web UI (https://your-proxmox-ip:8006)
2. Navigate to: Datacenter → Permissions → API Tokens
3. Click "Add" and create token for `root@pam` user
4. Name it "ansible" and note the token ID and secret
5. Copy these values to your vault.yml file

```bash
# Encrypt the vault file
ansible-vault encrypt inventory/group_vars/vault.yml

# Save vault password for convenience
echo "your_vault_password" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass

# Configure Ansible to use the vault password file
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible_vault_pass

# Add to shell profile for persistence (add to .bashrc or .zshrc)
echo 'export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible_vault_pass' >> ~/.bashrc
```

### Step 5: Review and Customize Inventory (5 minutes)

```bash
# Review the main inventory file
cat inventory/hosts.yml

# Customize if your IPs differ from defaults
nano inventory/hosts.yml
```

**Key sections to review:**
- `proxmox_hosts`: Update Proxmox host IPs if different
- `k3s_cluster`: Update Raspberry Pi IPs if different
- Domain names and network settings

### Step 6: Deploy Infrastructure (Variable - can be hours for full deployment)

#### Option A: Phased Deployment (Recommended)

Deploy in phases with validation at each step:

```bash
# Phase 1: Foundation (Bastion hosts and Proxmox setup)
ansible-playbook playbooks/infrastructure.yml --tags "foundation,phase1"

# Phase 2: Networking (DNS, VPN, Reverse proxy)
ansible-playbook playbooks/infrastructure.yml --tags "networking,phase2"

# Phase 3: Monitoring (Prometheus, Grafana, Loki)
ansible-playbook playbooks/infrastructure.yml --tags "monitoring,phase3"

# Phase 4: Applications (Home automation, Media services)
ansible-playbook playbooks/infrastructure.yml --tags "applications,phase4"

# Phase 5: K3s Cluster
ansible-playbook playbooks/infrastructure.yml --tags "k3s,phase5"
```

#### Option B: Full Deployment

Deploy everything at once:

```bash
# Deploy all infrastructure
ansible-playbook playbooks/infrastructure.yml

# This will take 1-2 hours depending on your hardware
```

#### Option C: Minimal Deployment

Deploy just the essentials for testing:

```bash
# Deploy monitoring stack only
ansible-playbook playbooks/monitoring.yml

# Deploy networking services only
ansible-playbook playbooks/networking.yml
```

### Step 7: Validation and Testing (5 minutes)

```bash
# Run quick smoke test
make test-quick

# Verify infrastructure health
make test-infrastructure

# Check security configuration
make test-security

# Test service functionality
make test-services
```

## Post-Installation Steps

### Access Your Services

Once deployed, access your services at:

- **Grafana**: https://grafana.homelab.local (or http://192.168.0.201:3000)
- **Prometheus**: http://192.168.0.200:9090
- **Traefik Dashboard**: http://192.168.0.205:8080
- **Home Assistant**: http://192.168.0.208:8123

**Default credentials:**
- Check your vault file for passwords
- Many services will require initial setup on first access

### Configure DNS

Update your local DNS or router settings to use:
- **Primary DNS**: 192.168.0.204 (AdGuard Home)
- **Secondary DNS**: 192.168.0.202 (Unbound)

Or add entries to your `/etc/hosts` file:

```bash
192.168.0.200  prometheus.homelab.local
192.168.0.201  grafana.homelab.local
192.168.0.205  traefik.homelab.local
```

### Set Up VPN Access (Optional)

For remote access to your homelab:

```bash
# Generate VPN client configuration
ansible-playbook playbooks/networking.yml --tags "wireguard" -e "client_name=laptop"

# Copy configuration from WireGuard server
scp pbs@192.168.0.203:/opt/wireguard/clients/laptop.conf ./

# Import into your WireGuard client
```

## Common Issues and Solutions

### Issue: "SSH connection refused"

**Solution:**

```bash
# Verify SSH service is running on target
ssh user@target-ip "sudo systemctl status sshd"

# Check firewall rules
ssh user@target-ip "sudo ufw status"
```

### Issue: "Proxmox API connection failed"

**Solution:**

```bash
# Test API token manually
curl -k -H "Authorization: PVEAPIToken=root@pam!ansible=your-secret" \
  https://192.168.0.56:8006/api2/json/version

# Verify token has correct permissions in Proxmox UI
```

### Issue: "Container creation failed"

**Solution:**

```bash
# Check available storage on Proxmox
ssh root@pve-mac "df -h /var/lib/vz"

# Verify LXC templates are downloaded
ssh root@pve-mac "pveam list local | grep ubuntu-22.04"

# Download template if missing
ssh root@pve-mac "pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
```

### Issue: "Service not responding"

**Solution:**

```bash
# Check service status
ansible prometheus -m shell -a "systemctl status prometheus"

# Check service logs
ansible prometheus -m shell -a "journalctl -u prometheus -n 50"

# Verify network connectivity
ping 192.168.0.200
telnet 192.168.0.200 9090
```

## Next Steps

### Essential Tasks

1. **Configure Grafana Dashboards**
   - Import pre-built dashboards for Node Exporter, K3s, and Traefik
   - Set up alerting rules in AlertManager

2. **Set Up Backups**
   - Configure automated snapshots for LXC containers
   - Set up backup retention policies

3. **Customize Services**
   - Configure Home Assistant for your smart home devices
   - Set up media management with Sonarr/Radarr

4. **Security Hardening Review**
   - Review firewall rules: `make test-security`
   - Update SSH keys and passwords
   - Enable two-factor authentication where available

### Optional Enhancements

- **Secure Enclave**: Deploy isolated pentesting environment

  ```bash
  ansible-playbook playbooks/secure-enclave.yml
  ```

- **Additional Monitoring**: Add custom exporters and metrics
- **Custom Services**: Add your own services using existing role patterns
- **High Availability**: Configure clustering for critical services

## Useful Commands Reference

### Testing and Validation

```bash
make test-quick          # Quick smoke test (< 2 min)
make test               # Full test suite (< 5 min)
make lint               # Run all linting checks
```

### Deployment

```bash
make deploy             # Full deployment with linting
make deploy-phase1      # Foundation only
make deploy-phase2      # Networking only
```

### Maintenance

```bash
make status             # Show infrastructure status
make monitor            # Display monitoring URLs
make clean              # Clean temporary files
```

### Molecule Testing (Development)

```bash
make test-molecule-smoke    # Fast smoke test for all roles
make test-molecule-all      # Run all Molecule scenarios
```

## Getting Help

If you encounter issues:

1. **Check logs**: Use `journalctl -f` on affected systems
2. **Run with debug**: Add `-vvv` to ansible-playbook commands
3. **Review documentation**:
   - [INSTALLATION.md](docs/INSTALLATION.md) - Detailed installation guide
   - [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues and solutions
   - [TESTING.md](TESTING.md) - Testing strategy and validation
4. **Consult specific guides**:
   - [CLAUDE.md](CLAUDE.md) - Complete command reference
   - [API.md](API.md) - API documentation
   - Collection-specific READMEs in `ansible_collections/homelab/*/`

## What's Next?

You now have a fully functional homelab infrastructure! Here are some suggested learning paths:

1. **Learn the Stack**
   - Explore Grafana dashboards to understand your infrastructure
   - Review Traefik routes and SSL certificates
   - Examine Prometheus metrics and alerts

2. **Customize and Extend**
   - Add your own services following existing role patterns
   - Customize monitoring dashboards
   - Tune resource allocations based on usage

3. **Advanced Topics**
   - Set up GitOps with ArgoCD on K3s
   - Implement automated backups and disaster recovery
   - Deploy production workloads on K3s cluster

4. **Contribute Back**
   - Share your improvements via pull requests
   - Report issues and suggest enhancements
   - Help others in the community

---

**Happy Homelabbing!** 🚀

For detailed information, see the [complete documentation](README.md).
