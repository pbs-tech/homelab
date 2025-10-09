# Prerequisites Role

Configures system prerequisites and environment settings required for K3s cluster deployment. Handles network configuration, firewall rules, kernel modules, and system packages needed by K3s on all node types.

## Features

- **Ansible Version Enforcement** - Ensures minimum Ansible version requirements
- **Network Configuration** - Enables IPv4/IPv6 forwarding for Kubernetes networking
- **Firewall Management** - Configures UFW and firewalld rules for K3s services
- **Kernel Module Loading** - Loads required kernel modules (br_netfilter)
- **Package Installation** - Installs distribution-specific dependencies
- **AppArmor Support** - Configures AppArmor for container security
- **Iptables Compatibility** - Detects and warns about incompatible iptables versions
- **Custom Manifest Support** - Deploys additional Kubernetes manifests
- **Registry Configuration** - Configures private container registries
- **Alternative Storage** - Supports custom K3s data directory locations

## Requirements

- Root or sudo access
- Ansible 2.14 or higher
- Supported Linux distribution (Ubuntu, Debian, RHEL, Arch Linux)
- Network connectivity (unless using airgap mode)
- homelab.common collection installed

## Role Variables

### Basic Configuration

```yaml
# K3s API server port
api_port: 6443

# Inventory groups
server_group: server
agent_group: agent

# Cluster network CIDRs
cluster_cidr: "10.42.0.0/16"
service_cidr: "10.43.0.0/16"
```

### Storage Configuration

```yaml
# Custom K3s data directory (optional)
# k3s_server_location: /mnt/k3s-data

# Alternative location creates symlink from /var/lib/rancher/k3s
```

### Registry Configuration

```yaml
# Private registry configuration (optional)
registries_config_yaml: |
  mirrors:
    docker.io:
      endpoint:
        - "https://registry.homelab.local:5000"
  configs:
    "registry.homelab.local:5000":
      auth:
        username: admin
        password: secret
      tls:
        cert_file: /etc/rancher/k3s/certs/registry.crt
        key_file: /etc/rancher/k3s/certs/registry.key
        ca_file: /etc/rancher/k3s/certs/registry-ca.crt
```

### Manifest Deployment

```yaml
# Additional Kubernetes manifests to deploy
extra_manifests:
  - /path/to/custom-resource.yaml
  - /path/to/namespace.yaml
  - /path/to/network-policy.yaml
```

### Airgap Configuration

```yaml
# Airgap directory (if using offline installation)
# airgap_dir: /opt/k3s-airgap
```

## Usage

### Basic Prerequisites Setup

```yaml
- hosts: k3s_cluster
  become: yes
  roles:
    - homelab.k3s.prereq
```

### With Custom Network CIDRs

```yaml
- hosts: k3s_cluster
  become: yes
  vars:
    cluster_cidr: "10.50.0.0/16"
    service_cidr: "10.51.0.0/16"
  roles:
    - homelab.k3s.prereq
```

### With Private Registry

```yaml
- hosts: k3s_cluster
  become: yes
  vars:
    registries_config_yaml: |
      mirrors:
        docker.io:
          endpoint:
            - "https://registry.homelab.local"
      configs:
        "registry.homelab.local":
          auth:
            username: "{{ vault_registry_user }}"
            password: "{{ vault_registry_pass }}"
  roles:
    - homelab.k3s.prereq
```

### With Custom Manifests

```yaml
- hosts: server
  become: yes
  vars:
    extra_manifests:
      - files/manifests/metallb-config.yaml
      - files/manifests/ingress-nginx.yaml
  roles:
    - homelab.k3s.prereq
```

### Alternative Data Location

```yaml
- hosts: k3s_cluster
  become: yes
  vars:
    k3s_server_location: /mnt/nvme/k3s
  roles:
    - homelab.k3s.prereq
```

## Tasks Overview

### Version and Package Management

1. **Ansible Version Check** - Enforces minimum Ansible 2.14
2. **Ubuntu Packages** - Installs policycoreutils for SELinux
3. **RHEL 10 Packages** - Installs kernel-modules-extra for br_netfilter
4. **Package Cache Update** - Updates cache unless in airgap mode

### Network Configuration

1. **IPv4 Forwarding** - Enables net.ipv4.ip_forward
2. **IPv6 Forwarding** - Enables net.ipv6.conf.all.forwarding (if IPv6 present)
3. **Service Facts** - Gathers information about running services

### UFW Firewall Configuration

1. **Detect UFW Status** - Checks if UFW is running
2. **API Port** - Opens port 6443 for Kubernetes API
3. **Etcd Ports** - Opens 2379-2381 for etcd (HA clusters only)
4. **Cluster CIDRs** - Allows traffic from cluster and service networks

### Firewalld Configuration

1. **Detect Firewalld** - Checks if firewalld is running
2. **API Port** - Opens port 6443/tcp in internal zone
3. **Etcd Ports** - Opens 2379-2381/tcp (HA clusters only)
4. **Inter-Node Ports** - Opens required ports for K3s services:
   - 5001/tcp - Spegel (embedded registry)
   - 8472/udp - Flannel VXLAN
   - 10250/tcp - Kubelet metrics
   - 51820/udp - Flannel Wireguard IPv4
   - 51821/udp - Flannel Wireguard IPv6
5. **Node CIDRs** - Allows traffic from all cluster nodes
6. **Cluster CIDRs** - Adds cluster and service networks to trusted zone

### Kernel Module Configuration

1. **Module Configuration** - Adds br_netfilter to /etc/modules-load.d/
2. **Module Loading** - Loads br_netfilter kernel module
3. **Sysctl Settings** - Configures bridge-nf-call-iptables settings

### AppArmor Configuration

1. **Detect AppArmor** - Checks for AppArmor presence
2. **AppArmor Status** - Verifies if AppArmor is enabled
3. **Install Parser (SUSE)** - Installs apparmor-parser on SUSE systems
4. **Install Parser (Debian 11)** - Installs apparmor package on Debian 11

### Iptables Compatibility

1. **Package Facts** - Gathers installed package information
2. **Version Check** - Detects iptables v1.8.0-1.8.4 (incompatible versions)
3. **Warning** - Recommends using --prefer-bundled-bin if incompatible

### System Configuration

1. **Sudo Path (RHEL)** - Adds /usr/local/bin to sudo secure_path
2. **Alternative Storage** - Creates symlink if custom data location specified
3. **Manifest Directory** - Creates /var/lib/rancher/k3s/server/manifests
4. **Deploy Manifests** - Copies extra manifests if provided
5. **Registry Config** - Deploys private registry configuration

## Files and Directories

### Configuration Files

- **/etc/modules-load.d/br_netfilter.conf** - Kernel module autoload
- **/etc/rancher/k3s/registries.yaml** - Private registry configuration
- **/etc/sudoers** - Updated sudo secure_path (RHEL only)

### Data Directories

- **/var/lib/rancher/k3s/** - Default K3s data directory
- **/var/lib/rancher/k3s/server/manifests/** - Auto-deployed manifests
- **Custom location** - If k3s_server_location specified

### Network Configuration

- **/etc/sysctl.conf** or **/etc/sysctl.d/** - Kernel network parameters

## Handlers

This role does not define handlers. Configuration changes are applied immediately via sysctl and systemctl.

## Dependencies

- ansible.posix (for sysctl, firewalld modules)
- community.general (for ufw, modprobe modules)

## Network Requirements

### Required Ports (UFW/Firewalld)

#### All Nodes

- **6443/tcp** - Kubernetes API server
- **10250/tcp** - Kubelet metrics

#### Server Nodes (HA only)

- **2379/tcp** - etcd client requests
- **2380/tcp** - etcd peer communication
- **2381/tcp** - etcd metrics

#### Inter-Node Communication

- **5001/tcp** - Spegel distributed registry
- **8472/udp** - Flannel VXLAN overlay
- **51820/udp** - Flannel Wireguard (IPv4)
- **51821/udp** - Flannel Wireguard (IPv6)

### Network CIDRs

- **Cluster CIDR** - Pod network range (default 10.42.0.0/16)
- **Service CIDR** - Service network range (default 10.43.0.0/16)

## System Requirements

### Kernel Modules

- **br_netfilter** - Bridge netfilter for iptables (RHEL/Arch)
- **overlay** - Overlay filesystem (loaded by containerd)
- **ip_tables** - iptables support

### Kernel Parameters

```yaml
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
```

### Package Requirements

#### Ubuntu/Debian

- policycoreutils - SELinux context management

#### RHEL/CentOS 10

- kernel-modules-extra - Additional kernel modules

#### SUSE

- apparmor-parser - AppArmor profile parser

## Troubleshooting

### Ansible Version Error

```bash
# Check Ansible version
ansible --version

# Upgrade Ansible
pip install --upgrade ansible-core
```

### Network Forwarding Issues

```bash
# Check IPv4 forwarding
sysctl net.ipv4.ip_forward

# Check IPv6 forwarding
sysctl net.ipv6.conf.all.forwarding

# Apply settings manually
sysctl -w net.ipv4.ip_forward=1
sysctl -p
```

### Firewall Problems

```bash
# UFW status
ufw status verbose
ufw show listening

# Firewalld status
firewall-cmd --list-all
firewall-cmd --list-all --zone=internal
firewall-cmd --list-all --zone=trusted
```

### Kernel Module Issues

```bash
# Check if br_netfilter is loaded
lsmod | grep br_netfilter

# Load manually
modprobe br_netfilter

# Verify module configuration
cat /etc/modules-load.d/br_netfilter.conf
```

### Iptables Compatibility

```bash
# Check iptables version
iptables --version

# If v1.8.0-1.8.4, use bundled binary
# Add to extra_server_args: --prefer-bundled-bin
```

### AppArmor Issues

```bash
# Check AppArmor status
cat /sys/module/apparmor/parameters/enabled

# View AppArmor profiles
aa-status

# Install parser if missing (Debian)
apt-get install apparmor
```

## Security Considerations

- **Firewall Rules** - Only opens necessary ports for K3s
- **Network Isolation** - Uses zones/rules to separate cluster traffic
- **AppArmor** - Enables container security policies
- **SELinux** - Installs tools for SELinux context management
- **Bridge Filtering** - Enables iptables filtering on bridged traffic
- **Secure Defaults** - Minimal port exposure by default

## Performance Considerations

- **Network Forwarding** - Essential for pod-to-pod communication
- **Bridge Netfilter** - May have slight performance impact
- **Firewall Rules** - Minimal overhead with properly configured rules
- **AppArmor** - Negligible performance impact
- **Storage Location** - Use fast storage for K3s data directory

## Best Practices

### Pre-Deployment

- **Version Check** - Ensure Ansible 2.14+ before deployment
- **Network Planning** - Plan cluster and service CIDR ranges
- **Firewall Review** - Review existing firewall rules for conflicts
- **Storage Planning** - Choose appropriate location for K3s data

### Configuration

- **Consistent Settings** - Use same network CIDRs across all nodes
- **Registry Configuration** - Configure private registries before deployment
- **Manifest Organization** - Organize manifests by function/namespace
- **Documentation** - Document custom configurations and CIDRs

### Validation

- **Network Tests** - Verify network forwarding after configuration
- **Firewall Tests** - Test port accessibility from other nodes
- **Module Loading** - Confirm kernel modules loaded correctly
- **Package Verification** - Verify all required packages installed

## Common Configurations

### Minimal Setup

```yaml
# Uses all defaults
- hosts: k3s_cluster
  become: yes
  roles:
    - homelab.k3s.prereq
```

### High Security

```yaml
- hosts: k3s_cluster
  become: yes
  vars:
    cluster_cidr: "10.244.0.0/16"
    service_cidr: "10.245.0.0/16"
    extra_manifests:
      - network-policies/default-deny.yaml
      - pod-security-policies/restricted.yaml
  roles:
    - homelab.k3s.prereq
```

### Private Registry

```yaml
- hosts: k3s_cluster
  become: yes
  vars:
    registries_config_yaml: |
      mirrors:
        docker.io:
          endpoint:
            - "https://harbor.homelab.local"
  roles:
    - homelab.k3s.prereq
```

### Alternative Storage

```yaml
- hosts: k3s_cluster
  become: yes
  vars:
    k3s_server_location: /mnt/ssd/k3s
  roles:
    - homelab.k3s.prereq
```

## License

Apache License 2.0 - See collection LICENSE file for details.
