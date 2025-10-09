# Prerequisite Role

Configures system prerequisites and network requirements for K3s cluster deployment. Handles kernel parameters, firewall rules, package dependencies, and system hardening required for secure and reliable Kubernetes operation.

## Features

- **Ansible Version Enforcement** - Ensures minimum Ansible version requirements
- **Distribution Support** - Supports Ubuntu, RedHat, and Arch Linux distributions
- **Kernel Configuration** - Configures IPv4/IPv6 forwarding and bridge networking
- **Firewall Management** - Configures UFW and firewalld with K3s-specific rules
- **Network Security** - Sets up secure network parameters for cluster communication
- **Package Dependencies** - Installs required packages for K3s operation
- **AppArmor Support** - Configures AppArmor security profiles when available
- **Multi-Node Support** - Handles both single-node and HA cluster configurations
- **Custom K3s Directory** - Supports alternative K3s installation locations
- **Manifest Management** - Deploys extra manifests for cluster initialization
- **Registry Configuration** - Supports private container registry setup

## Requirements

- Ansible core 2.14 or higher
- Root or sudo access
- Network connectivity for package installation
- Supported OS: Ubuntu 20.04+, RHEL 8+, Arch Linux
- ansible.posix collection
- community.general collection

## Role Variables

### Cluster Configuration

```yaml
# API server port (default: 6443)
api_port: 6443

# Cluster node groups
server_group: server      # Server node group name
agent_group: agent        # Agent node group name

# Network CIDRs
cluster_cidr: "10.42.0.0/16"    # Pod network CIDR
service_cidr: "10.43.0.0/16"    # Service network CIDR
```

### K3s Installation

```yaml
# Custom K3s installation directory (optional)
k3s_server_location: /var/lib/rancher/k3s

# Extra Kubernetes manifests to deploy
extra_manifests:
  - /path/to/manifest1.yaml
  - /path/to/manifest2.yaml

# Private registry configuration (optional)
registries_config_yaml: |
  mirrors:
    docker.io:
      endpoint:
        - "https://registry.example.com"
  configs:
    "registry.example.com":
      auth:
        username: user
        password: password
```

## Usage

### Basic K3s Prerequisites

```yaml
- name: Configure K3s prerequisites
  hosts: k3s_cluster
  become: yes
  roles:
    - homelab.proxmox_lxc.prereq
```

### With Custom Configuration

```yaml
- name: Configure prerequisites with custom settings
  hosts: k3s_cluster
  become: yes
  vars:
    api_port: 6443
    cluster_cidr: "10.50.0.0/16"
    service_cidr: "10.51.0.0/16"
    k3s_server_location: /opt/k3s
  roles:
    - homelab.proxmox_lxc.prereq
```

### High Availability Cluster

```yaml
- name: Configure HA cluster prerequisites
  hosts: k3s_servers
  become: yes
  vars:
    server_group: k3s_servers
    agent_group: k3s_agents
  roles:
    - homelab.proxmox_lxc.prereq
```

### With Private Registry

```yaml
- name: Configure prerequisites with private registry
  hosts: k3s_cluster
  become: yes
  vars:
    registries_config_yaml: |
      mirrors:
        docker.io:
          endpoint:
            - "https://harbor.example.com"
      configs:
        "harbor.example.com":
          auth:
            username: "{{ vault_registry_user }}"
            password: "{{ vault_registry_password }}"
          tls:
            insecure_skip_verify: false
  roles:
    - homelab.proxmox_lxc.prereq
```

## System Configuration

### Kernel Parameters

The role configures the following sysctl parameters:

```yaml
# IPv4 forwarding (required for K3s)
net.ipv4.ip_forward: 1

# IPv6 forwarding (if IPv6 addresses present)
net.ipv6.conf.all.forwarding: 1

# Bridge netfilter (RHEL/Arch)
net.bridge.bridge-nf-call-iptables: 1
net.bridge.bridge-nf-call-ip6tables: 1
```

### Firewall Rules - UFW

For Ubuntu systems with UFW:

```yaml
# K3s API server
Port: 6443/tcp

# etcd (HA clusters only)
Ports: 2379-2381/tcp

# Cluster and Service CIDRs
Allow: cluster_cidr and service_cidr
```

### Firewall Rules - firewalld

For RHEL systems with firewalld:

```yaml
# K3s API server
Port: 6443/tcp (zone: internal)

# etcd (HA clusters)
Ports: 2379-2381/tcp (zone: internal)

# Inter-node communication
Ports:
  - 5001/tcp   # Spegel (embedded registry)
  - 8472/udp   # Flannel VXLAN
  - 10250/tcp  # Kubelet metrics
  - 51820/udp  # Flannel WireGuard (IPv4)
  - 51821/udp  # Flannel WireGuard (IPv6)

# Cluster CIDRs (zone: trusted)
Allow: cluster_cidr and service_cidr

# Node IPs (zone: internal)
Allow: All server and agent node IPs
```

## Package Dependencies

### Ubuntu

```yaml
packages:
  - policycoreutils  # SELinux context restoration
```

### RHEL 10

```yaml
packages:
  - kernel-modules-extra  # br_netfilter module
```

### AppArmor (if enabled)

```yaml
# Suse
packages:
  - apparmor-parser

# Debian 11
packages:
  - apparmor
```

## Tasks Overview

The role performs the following operations:

1. **Version Check** - Validates Ansible version meets minimum requirements
2. **Package Installation** - Installs distribution-specific dependencies
3. **Kernel Configuration** - Enables IP forwarding and bridge networking
4. **Service Discovery** - Identifies active firewall services
5. **UFW Configuration** - Configures UFW rules if active
6. **firewalld Configuration** - Configures firewalld rules if active
7. **Module Loading** - Loads required kernel modules (br_netfilter)
8. **AppArmor Setup** - Installs AppArmor parser if needed
9. **Package Validation** - Warns about incompatible iptables versions
10. **Sudo Configuration** - Adds /usr/local/bin to secure_path (RHEL)
11. **Directory Setup** - Creates K3s directories and symlinks
12. **Manifest Deployment** - Copies extra Kubernetes manifests
13. **Registry Configuration** - Sets up private registry authentication

## Dependencies

Required Ansible collections:

- ansible.posix (for sysctl, firewalld modules)
- community.general (for ufw, modprobe modules)

## Files and Directories

### K3s Directories

```bash
/var/lib/rancher/k3s              # Default K3s data directory
/var/lib/rancher/k3s/server/manifests  # Extra manifest location
/etc/rancher/k3s                  # Configuration directory
/etc/rancher/k3s/registries.yaml  # Registry configuration
```

### System Configuration

```bash
/etc/sysctl.d/99-k3s.conf        # Kernel parameters
/etc/modules-load.d/br_netfilter.conf  # Module auto-load
/etc/sudoers                      # Sudo secure_path (RHEL)
```

## Examples

### Complete Cluster Setup

```yaml
- name: Prepare K3s cluster infrastructure
  hosts: k3s_cluster
  become: yes
  vars:
    server_group: k3s_servers
    agent_group: k3s_agents
    api_port: 6443
    cluster_cidr: "10.42.0.0/16"
    service_cidr: "10.43.0.0/16"

    # Extra manifests for cluster initialization
    extra_manifests:
      - files/metallb-config.yaml
      - files/traefik-config.yaml

  roles:
    - homelab.proxmox_lxc.prereq

  post_tasks:
    - name: Verify kernel parameters
      command: sysctl net.ipv4.ip_forward
      register: ip_forward
      changed_when: false

    - name: Display IP forwarding status
      debug:
        msg: "IP forwarding is {{ 'enabled' if ip_forward.stdout.endswith('1') else 'disabled' }}"
```

### Alternative K3s Location

```yaml
- name: Configure prerequisites with custom K3s location
  hosts: k3s_cluster
  become: yes
  vars:
    k3s_server_location: /mnt/ssd/k3s
  roles:
    - homelab.proxmox_lxc.prereq

  post_tasks:
    - name: Verify symlink
      stat:
        path: /var/lib/rancher/k3s
      register: k3s_link

    - name: Show K3s location
      debug:
        msg: "K3s data directory: {{ k3s_link.stat.lnk_target | default('/var/lib/rancher/k3s') }}"
```

### Airgapped Environment

```yaml
- name: Configure prerequisites for airgapped deployment
  hosts: k3s_cluster
  become: yes
  vars:
    airgap_dir: /opt/k3s-airgap  # Skips package updates
    registries_config_yaml: |
      mirrors:
        "*":
          endpoint:
            - "https://internal-registry.example.com"
      configs:
        "internal-registry.example.com":
          auth:
            username: "k3s"
            password: "{{ vault_airgap_registry_password }}"
  roles:
    - homelab.proxmox_lxc.prereq
```

## Troubleshooting

### Firewall Issues

```bash
# Check UFW status
sudo ufw status verbose

# Verify K3s API port is open
sudo ufw status | grep 6443

# Check firewalld zones
sudo firewall-cmd --list-all-zones

# Verify internal zone
sudo firewall-cmd --zone=internal --list-all
```

### Kernel Parameter Problems

```bash
# Check IP forwarding
sysctl net.ipv4.ip_forward
sysctl net.ipv6.conf.all.forwarding

# Check bridge netfilter
sysctl net.bridge.bridge-nf-call-iptables

# Reload sysctl
sudo sysctl --system

# Verify persistence
cat /etc/sysctl.d/99-k3s.conf
```

### Module Loading Issues

```bash
# Check if br_netfilter is loaded
lsmod | grep br_netfilter

# Manually load module
sudo modprobe br_netfilter

# Verify auto-load configuration
cat /etc/modules-load.d/br_netfilter.conf
```

### AppArmor Issues

```bash
# Check AppArmor status
sudo aa-status

# Check if enabled
cat /sys/module/apparmor/parameters/enabled

# Install AppArmor parser
sudo apt install apparmor  # Debian/Ubuntu
sudo zypper install apparmor-parser  # SUSE
```

### iptables Version Warning

```bash
# Check iptables version
iptables --version

# If version 1.8.0-1.8.4, use bundled binary:
# Add to K3s installation:
extra_server_args: "--prefer-bundled-bin"
```

## Security Considerations

- **Firewall Configuration** - Only opens required ports for K3s operation
- **Network Segmentation** - Uses trusted/internal zones for cluster traffic
- **Minimal Permissions** - Only grants necessary capabilities
- **AppArmor Profiles** - Enables mandatory access control when available
- **Secure Defaults** - Uses restrictive default policies
- **Registry Authentication** - Supports secure private registry access

## Performance Tuning

- **Kernel Parameters** - Optimized for container networking
- **Firewall Rules** - Efficient rule ordering
- **Module Loading** - Loads modules at boot for faster startup
- **Network Performance** - Bridge netfilter for optimal packet processing

## Integration with K3s Roles

This role is typically used before K3s server/agent installation:

```yaml
- name: Complete K3s deployment
  hosts: k3s_cluster
  become: yes
  tasks:
    - name: Configure prerequisites
      include_role:
        name: homelab.proxmox_lxc.prereq

    - name: Install K3s server
      include_role:
        name: homelab.proxmox_lxc.k3s_server
      when: inventory_hostname in groups['k3s_servers']

    - name: Install K3s agent
      include_role:
        name: homelab.proxmox_lxc.k3s_agent
      when: inventory_hostname in groups['k3s_agents']
```

## Known Issues

### iptables 1.8.0-1.8.4 Bug

K3s has a known issue with iptables versions 1.8.0-1.8.4. The role will warn if this version is detected. Solution:

```yaml
# Use bundled iptables binary
extra_server_args: "--prefer-bundled-bin"
```

### IPv6 Disabled Systems

If IPv6 is disabled, the IPv6 forwarding configuration is skipped automatically.

## License

Apache License 2.0 - See collection LICENSE file for details.
