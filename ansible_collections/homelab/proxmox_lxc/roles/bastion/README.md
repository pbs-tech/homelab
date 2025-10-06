# Bastion Role

Deploys and configures a hardened bastion host (jump server) in an LXC container for secure infrastructure access. Provides a security-first gateway for managing K3s clusters and Proxmox infrastructure with comprehensive security controls, fail2ban protection, and automated Ansible deployment capabilities.

## Features

- **Hardened Security** - Comprehensive security hardening with fail2ban, UFW, and SSH restrictions
- **Ansible Ready** - Pre-configured with Ansible, collections, and Python dependencies
- **Jump Server** - Secure gateway for infrastructure access from external networks
- **Automated Deployment** - Self-contained Ansible deployment environment
- **Collection Sync** - Automated synchronization of Ansible collections and playbooks
- **User Management** - Automated user creation with sudo access and SSH keys
- **Firewall Protection** - UFW firewall with restrictive default-deny policy
- **Intrusion Prevention** - fail2ban for SSH and service protection
- **Resource Optimized** - Configured with appropriate resources for management workloads
- **High Availability Ready** - Can be deployed on multiple Proxmox nodes

## Requirements

- Proxmox VE 7.0 or higher
- Ubuntu 22.04 LTS template available
- Valid Proxmox API token with container creation permissions
- Network connectivity to Proxmox host
- SSH public key for automated access
- homelab.common collection installed

## Role Variables

### Bastion Container Configuration

```yaml
# Container specification
bastion_container:
  vmid: 999
  hostname: k3s-bastion
  ip: 192.168.0.110/24
  gateway: 192.168.0.1
  nameservers: 192.168.0.202
  template: local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst
  cores: 2
  memory: 2048
  disk_size: 20G
  features:
    - nesting=1        # Required for container management
    - keyctl=1         # Required for key management
  unprivileged: true   # Security best practice
```

### Security Configuration

```yaml
# Security settings
bastion_security:
  ssh_port: 22
  fail2ban_enabled: true
  firewall_enabled: true
  allowed_ports:
    - 22  # SSH
    - 53  # DNS (for local resolution)
  fail2ban_bantime: 3600      # 1 hour ban
  fail2ban_maxretry: 3        # 3 attempts before ban
```

### Package Installation

```yaml
# Core packages for bastion functionality
bastion_packages:
  - ansible              # Ansible automation
  - ansible-core         # Core Ansible engine
  - python3-pip          # Python package manager
  - git                  # Version control
  - curl                 # HTTP client
  - wget                 # File downloader
  - unzip                # Archive extraction
  - jq                   # JSON processor
  - fail2ban             # Intrusion prevention
  - ufw                  # Firewall
  - htop                 # Process monitor
  - net-tools            # Network utilities
  - openssh-client       # SSH client
  - sshpass              # Non-interactive SSH password provider

# Python packages for Ansible functionality
bastion_pip_packages:
  - kubernetes           # K8s API client
  - proxmoxer            # Proxmox API client
  - requests             # HTTP library
```

## Usage

### Basic Bastion Deployment

```yaml
- name: Deploy bastion host
  hosts: proxmox_hosts
  vars:
    proxmox_node: "pve-mac"
    ansible_ssh_public_key_content: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
  roles:
    - homelab.proxmox_lxc.bastion
```

### Custom Bastion Configuration

```yaml
- name: Deploy hardened bastion with custom settings
  hosts: proxmox_hosts
  vars:
    proxmox_node: "pve-mac"
    bastion_container:
      vmid: 110
      hostname: secure-bastion
      ip: 192.168.0.110/24
      gateway: 192.168.0.1
      cores: 4
      memory: 4096
      disk_size: 50G
    bastion_security:
      fail2ban_bantime: 7200  # 2 hour ban
      fail2ban_maxretry: 2    # More restrictive
    ansible_ssh_public_key_content: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
  roles:
    - homelab.proxmox_lxc.bastion
```

### Multiple Bastion Hosts

```yaml
- name: Deploy bastion hosts for HA
  hosts: proxmox_hosts
  tasks:
    - name: Create primary bastion
      include_role:
        name: homelab.proxmox_lxc.bastion
      vars:
        bastion_container:
          vmid: 110
          hostname: k3s-bastion
          ip: 192.168.0.110/24

    - name: Create secondary bastion
      include_role:
        name: homelab.proxmox_lxc.bastion
      vars:
        bastion_container:
          vmid: 109
          hostname: nas-bastion
          ip: 192.168.0.109/24
```

## Bastion Architecture

### Security Layers

1. **Network Layer** - Dedicated VLAN/subnet for management traffic
2. **Firewall Layer** - UFW with default-deny policy
3. **Access Layer** - SSH with key-based authentication only
4. **Intrusion Prevention** - fail2ban monitoring and blocking
5. **Audit Layer** - Comprehensive logging of all access

### Access Flow

```
External User → VPN → Bastion Host → Infrastructure
                         ↓
                   [Security Checks]
                   - SSH key auth
                   - fail2ban
                   - UFW filtering
                   - Audit logging
```

### Deployment Workflow

1. **Bastion Creation** - Deploy bastion container on Proxmox
2. **Security Hardening** - Apply security configurations
3. **Tool Installation** - Install Ansible and dependencies
4. **Collection Sync** - Copy Ansible collections and playbooks
5. **Key Deployment** - Set up SSH keys for infrastructure access
6. **Validation** - Verify connectivity and access

## Tasks Overview

The role performs the following operations:

1. **Container Creation** - Creates bastion LXC container with secure API authentication
2. **Container Start** - Starts container and waits for availability
3. **Package Update** - Updates package cache
4. **Package Installation** - Installs core packages and Python dependencies
5. **SSH Hardening** - Configures secure SSH daemon settings
6. **fail2ban Setup** - Configures intrusion prevention
7. **Firewall Configuration** - Sets up UFW with restrictive rules
8. **User Creation** - Creates Ansible user with sudo access
9. **SSH Key Deployment** - Deploys SSH public keys
10. **Collection Sync** - Synchronizes Ansible collections and playbooks

## Dependencies

This role requires:

- community.general collection (for proxmox, ufw modules)
- ansible.posix collection (for authorized_key, synchronize modules)
- homelab.common collection (for shared configurations)

## Files and Templates

### Configuration Templates

- **sshd_config.j2** - Hardened SSH daemon configuration
- **jail.local.j2** - fail2ban jail configuration

### SSH Configuration

Key security settings in sshd_config:

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
```

### fail2ban Configuration

Default jail settings:

```
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
```

## Handlers

- `restart ssh` - Restart SSH daemon after configuration changes
- `restart fail2ban` - Restart fail2ban after configuration changes

## Examples

### Complete Security Deployment

```yaml
- name: Deploy security-focused bastion infrastructure
  hosts: proxmox_hosts
  vars:
    proxmox_node: "pve-mac"
    bastion_container:
      vmid: 110
      hostname: security-bastion
      ip: 192.168.0.110/24
      cores: 2
      memory: 2048
    bastion_security:
      fail2ban_enabled: true
      firewall_enabled: true
      fail2ban_bantime: 10800  # 3 hours
      fail2ban_maxretry: 2
      allowed_ports:
        - 22  # SSH only
    ansible_ssh_public_key_content: "{{ lookup('file', '~/.ssh/bastion_id_rsa.pub') }}"

  roles:
    - homelab.proxmox_lxc.bastion

  post_tasks:
    - name: Verify bastion accessibility
      wait_for:
        host: 192.168.0.110
        port: 22
        timeout: 60

    - name: Test SSH connection
      command: ssh -o StrictHostKeyChecking=no pbs@192.168.0.110 'echo Bastion accessible'
      delegate_to: localhost
```

### Development Bastion

```yaml
- name: Deploy development bastion
  hosts: proxmox_hosts
  vars:
    bastion_container:
      vmid: 999
      hostname: dev-bastion
      ip: 192.168.0.250/24
    bastion_security:
      fail2ban_bantime: 600   # 10 minutes (more lenient)
      fail2ban_maxretry: 5
  roles:
    - homelab.proxmox_lxc.bastion
```

## Troubleshooting

### Cannot Access Bastion

```bash
# Verify container is running
pct status 110

# Check network connectivity
ping 192.168.0.110

# Test SSH port
nc -zv 192.168.0.110 22

# Access via Proxmox console
pct console 110
```

### fail2ban Issues

```bash
# Check fail2ban status
pct exec 110 -- fail2ban-client status

# View SSH jail status
pct exec 110 -- fail2ban-client status sshd

# Unban an IP address
pct exec 110 -- fail2ban-client set sshd unbanip 192.168.0.50

# Check fail2ban logs
pct exec 110 -- tail -f /var/log/fail2ban.log
```

### UFW Configuration Problems

```bash
# Check UFW status
pct exec 110 -- ufw status verbose

# Temporarily disable UFW for debugging
pct exec 110 -- ufw disable

# Re-enable with proper rules
pct exec 110 -- ufw --force enable

# Check UFW logs
pct exec 110 -- tail -f /var/log/ufw.log
```

### Ansible Collection Issues

```bash
# Verify collections are present
pct exec 110 -- ls -la /home/pbs/ansible_collections/homelab/

# Test Ansible installation
pct exec 110 -- ansible --version

# Verify Python dependencies
pct exec 110 -- pip list | grep -E 'kubernetes|proxmoxer'
```

## Security Considerations

- **SSH Keys Only** - Disable password authentication completely
- **fail2ban Monitoring** - Monitor and tune fail2ban rules for your environment
- **Firewall Rules** - Keep allowed_ports to absolute minimum
- **Audit Logging** - Enable comprehensive audit logging
- **Network Segmentation** - Isolate bastion on dedicated management network
- **Regular Updates** - Keep bastion packages updated for security patches
- **User Access Control** - Limit user accounts to only necessary administrators
- **Two-Factor Auth** - Consider adding 2FA for SSH access (optional)

## Performance Considerations

- **Resource Allocation** - 2 CPU cores and 2GB RAM is sufficient for most environments
- **Disk Space** - 20GB provides adequate space for collections and logs
- **Network Bandwidth** - Minimal requirements as it's primarily SSH traffic
- **Concurrent Sessions** - Monitor if many users access simultaneously

## Integration with Infrastructure

### K3s Cluster Management

```bash
# SSH to bastion
ssh pbs@192.168.0.110

# Run K3s deployment from bastion
cd ~/ansible_collections/homelab/k3s/
ansible-playbook playbooks/site.yml
```

### Proxmox Management

```bash
# Manage Proxmox infrastructure from bastion
ansible-playbook site.yml --tags "proxmox,lxc"
```

### Network Diagram

```
Internet → VPN Gateway → Bastion (192.168.0.110) → Internal Infrastructure
                            ↓
                    K3s Cluster (192.168.0.111-114)
                    Proxmox Hosts (192.168.0.56-57)
                    LXC Services (192.168.0.200-240)
```

## Advanced Usage

### VPN Integration

```yaml
# Deploy bastion with WireGuard VPN
- name: Bastion with VPN
  hosts: proxmox_hosts
  roles:
    - homelab.proxmox_lxc.bastion
  post_tasks:
    - name: Install WireGuard
      apt:
        name: wireguard
        state: present
      delegate_to: 192.168.0.110
```

### Monitoring Integration

```yaml
# Add bastion to monitoring
- name: Configure bastion monitoring
  hosts: bastion
  tasks:
    - name: Install node_exporter
      include_role:
        name: homelab.common.node_exporter
```

## License

Apache License 2.0 - See collection LICENSE file for details.
