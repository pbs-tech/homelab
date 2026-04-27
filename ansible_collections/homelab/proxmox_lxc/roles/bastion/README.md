# Bastion Role

Configures a hardened bastion host (jump server) in an LXC container for secure infrastructure access. Provides a security-first gateway for managing K3s clusters and Proxmox infrastructure with comprehensive security controls, fail2ban protection, and iptables firewall.

**Note:** This role handles security configuration only. Container creation and initial provisioning is handled by the `homelab.common.container_base` role.

## Features

- **Hardened Security** - Comprehensive security hardening with fail2ban, iptables, and SSH restrictions
- **Ansible Ready** - Pre-configured with Ansible, collections, and Python dependencies
- **Jump Server** - Secure gateway for infrastructure access from external networks
- **User Management** - Automated user creation with sudo access and SSH keys
- **Firewall Protection** - iptables firewall with default-deny INPUT policy
- **Intrusion Prevention** - fail2ban for SSH brute-force protection
- **Collection Sync** - Optional synchronization of Ansible collections and playbooks
- **Self-Managed Firewall** - Proxmox-level firewall is disabled; the bastion manages its own iptables rules

## Requirements

- Proxmox VE 7.0 or higher
- Container already provisioned via `homelab.common.container_base`
- SSH connectivity to the container (as the `ansible` user created by `container_base`)
- SSH public key for automated access
- homelab.common collection installed

## Role Variables

### Security Configuration

```yaml
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
  - python3-pip          # Python package manager
  - git                  # Version control
  - curl                 # HTTP client
  - wget                 # File downloader
  - unzip                # Archive extraction
  - jq                   # JSON processor
  - fail2ban             # Intrusion prevention
  - ufw                  # Firewall utility (iptables used directly)
  - htop                 # Process monitor
  - net-tools            # Network utilities
  - openssh-client       # SSH client
  - sshpass              # Non-interactive SSH password provider
  - iptables             # Firewall

# Python packages for Ansible functionality
bastion_pip_packages:
  - kubernetes           # K8s API client
  - proxmoxer            # Proxmox API client
  - requests             # HTTP library
```

### Collection Sync

```yaml
# Whether to sync Ansible collections to bastion
bastion_sync_collections: false

# Source/destination paths for synchronization
bastion_sync_source_base: "{{ playbook_dir | dirname }}"
bastion_sync_dest_base: /home/pbs
```

## Usage

### Recommended: Phased Deployment via foundation.yml

The bastion is deployed as Phase 1 of `playbooks/infrastructure.yml`, which calls `playbooks/foundation.yml`. The deployment follows three sub-phases:

**Phase 1a** - Provision the bastion container using `container_base`:

```yaml
- name: Provision bastion containers
  hosts: bastion_hosts
  gather_facts: false
  become: false
  serial: 1
  vars:
    ansible_user: ansible
  tasks:
    - name: Create bastion LXC container
      ansible.builtin.include_role:
        name: homelab.common.container_base
      vars:
        container_resources:
          cores: "{{ lxc_cores | default(2) }}"
          memory: "{{ lxc_memory | default(2048) }}"
          swap: "{{ lxc_swap | default(256) }}"
          disk_size: "{{ lxc_disk_size | default(20) }}"
      when: container_id is defined
```

**Phase 1b** - Configure bastion security (this role):

```yaml
- name: Configure bastion host security
  hosts: bastion_hosts
  become: true
  gather_facts: false
  vars:
    ansible_user: ansible
  pre_tasks:
    - name: Wait for bastion SSH to be available
      ansible.builtin.wait_for_connection:
        delay: 5
        timeout: 120
    - name: Gather facts after bastion is available
      ansible.builtin.setup:
  roles:
    - role: homelab.proxmox_lxc.bastion
```

**Phase 1c** - Verify bastion accessibility as `pbs` user:

```yaml
- name: Verify bastion hosts are accessible
  hosts: bastion_hosts
  gather_facts: false
  become: false
  vars:
    ansible_user: pbs
  tasks:
    - name: Verify bastion SSH accessibility as pbs user
      ansible.builtin.wait_for_connection:
        delay: 5
        timeout: 60
```

### Quick Deployment Commands

```bash
# Deploy bastion hosts as part of Phase 1
ansible-playbook playbooks/infrastructure.yml --tags "foundation,phase1"

# Deploy only bastion configuration (assumes containers already exist)
ansible-playbook playbooks/foundation.yml --tags "bastion"
```

## Bastion Architecture

### Security Layers

1. **Network Layer** - Dedicated management network segment
2. **Firewall Layer** - iptables with default-deny INPUT policy
3. **Access Layer** - SSH with key-based authentication only
4. **Intrusion Prevention** - fail2ban monitoring and blocking
5. **Audit Layer** - Comprehensive logging of all access

### Access Flow

```
External User -> VPN -> Bastion Host -> Infrastructure
                          |
                    [Security Checks]
                    - SSH key auth
                    - fail2ban
                    - iptables filtering
                    - Audit logging
```

### Allowed SSH Users

- **pbs** - Primary operations user with sudo access
- **ansible** - Provisioning user for Ansible re-runs and configuration management

Both users are configured in `AllowUsers` in sshd_config.

## Tasks Overview

The role performs the following operations (container must already exist):

1. **Package Installation** - Installs core packages and Python dependencies
2. **SSH Hardening** - Deploys hardened sshd_config (key-only auth, AllowUsers, modern ciphers)
3. **fail2ban Setup** - Configures intrusion prevention with SSH jail
4. **iptables Firewall** - Sets up firewall rules:
   - Allow established/related connections
   - Allow loopback traffic
   - Allow configured ports (SSH, DNS)
   - Default INPUT policy: DROP
   - Persistent rules via iptables-restore systemd service
5. **User Creation** - Creates `pbs` user with passwordless sudo
6. **SSH Key Deployment** - Deploys SSH public keys for `pbs` user
7. **Collection Sync** - Optionally synchronizes Ansible collections and playbooks

## Dependencies

This role requires:

- ansible.posix collection (for authorized_key, synchronize modules)
- homelab.common collection (for container_base, shared configurations)

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
ClientAliveInterval 600
AllowUsers pbs ansible
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

## Troubleshooting

### Cannot Access Bastion

```bash
# Verify container is running
pct status 110

# Check network connectivity
ping 192.168.0.110

# Test SSH port
nc -zv 192.168.0.110 22

# Access via Proxmox console (bypasses SSH and iptables)
pct exec 110 -- bash
```

### fail2ban Banning Your IP

If fail2ban has banned your Ansible controller or workstation IP:

```bash
# Check if your IP is banned (run from Proxmox host)
pct exec 110 -- fail2ban-client status sshd

# Unban a specific IP address
pct exec 110 -- fail2ban-client set sshd unbanip 192.168.0.50

# View fail2ban logs
pct exec 110 -- tail -20 /var/log/fail2ban.log

# Temporarily stop fail2ban if needed during provisioning
pct exec 110 -- systemctl stop fail2ban
```

**Prevention:** If Ansible provisioning is triggering fail2ban bans, increase `fail2ban_maxretry` or whitelist your controller IP in the fail2ban jail configuration.

### iptables Lockout Recovery

If iptables rules lock you out of the bastion:

```bash
# Access the container directly from the Proxmox host (bypasses iptables)
pct exec 110 -- bash

# Flush all iptables rules to restore access
pct exec 110 -- iptables -F
pct exec 110 -- iptables -P INPUT ACCEPT

# Verify you can SSH in again, then re-run the bastion role
ansible-playbook playbooks/foundation.yml --tags "bastion"
```

### Proxmox Firewall vs Bastion iptables

The bastion manages its own iptables firewall. The Proxmox-level NIC firewall is intentionally **disabled** for bastion containers (set in `inventory/group_vars/bastion_hosts.yml`):

```yaml
container_network:
  firewall: false  # Bastion manages its own iptables
```

If you see unexpected connection drops, check that:

1. The Proxmox firewall is not enabled on the bastion NIC (Datacenter > Firewall > check container NIC)
2. The bastion iptables rules have ACCEPT rules before the DROP policy
3. The iptables-restore service is active: `pct exec 110 -- systemctl status iptables-restore`

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

- **SSH Keys Only** - Password authentication is completely disabled
- **AllowUsers** - Only `pbs` and `ansible` users can SSH in
- **Self-Managed Firewall** - Bastion uses iptables directly; Proxmox NIC firewall is disabled to avoid double-filtering and rule conflicts
- **fail2ban Monitoring** - Monitor and tune fail2ban rules for your environment
- **Firewall Rules** - Keep `allowed_ports` to the absolute minimum
- **Regular Updates** - Keep bastion packages updated for security patches
- **User Access Control** - Limit user accounts to only necessary administrators
- **iptables Rule Order** - ACCEPT rules are applied before the DROP policy to prevent lockout

## Network Diagram

```
Internet -> VPN Gateway -> Bastion (192.168.0.110) -> Internal Infrastructure
                              |
                      K3s Cluster (192.168.0.111-114)
                      Proxmox Hosts (192.168.0.56-57)
                      LXC Services (192.168.0.200-240)
```

### Bastion Hosts

| Host | IP | Container ID | Proxmox Node |
|------|-----|-------------|--------------|
| k3s-bastion | 192.168.0.110 | 110 | pve-mac |
| nas-bastion | 192.168.0.109 | 109 | pve-nas |

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

## License

Apache License 2.0 - See collection LICENSE file for details.
