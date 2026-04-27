# Airgap Role

Enables offline K3s installation by distributing pre-downloaded K3s artifacts to cluster nodes. Supports fully air-gapped environments where nodes have no internet connectivity.

## Features

- **Offline Installation** - Deploy K3s without internet access
- **Artifact Distribution** - Copies install script, binaries, and images to nodes
- **Multi-Architecture Support** - Automatically detects and uses correct architecture binaries
- **SELinux Support** - Distributes and installs SELinux policy RPMs for RHEL/CentOS
- **Image Management** - Handles container image archives (tar.gz, tar.zst, tar)
- **Version Control** - Supports specific K3s versions in airgap mode
- **Validation** - Ensures all required artifacts are present before distribution
- **Idempotent** - Safe to run multiple times

## Requirements

- Ansible 2.12 or higher (enforced by role)
- Pre-downloaded K3s artifacts in local directory
- Root or sudo access on target nodes
- Local control node with artifacts
- homelab.common collection installed

## Role Variables

### Required Variables

```yaml
# Directory containing airgap artifacts (must be defined to enable airgap)
airgap_dir: /opt/k3s-airgap

# Artifacts required in airgap_dir:
# - k3s-install.sh (or will be downloaded)
# - k3s (or k3s-arm64, k3s-arm, k3s-amd64)
# - k3s-airgap-images-*.tar.gz (or .tar.zst, .tar)
# - k3s-selinux-*.rpm (optional, for RHEL/CentOS)
```

### Automatic Variables (Set by Role)

```yaml
# Architecture detection (set automatically)
k3s_arch: "{{ 'arm64' if ansible_architecture == 'aarch64' else 'arm' if ansible_architecture == 'armv7l' else 'amd64' }}"

# Inventory groups (should be defined in inventory)
server_group: server
agent_group: agent
```

## Usage

### Basic Airgap Installation

```yaml
- hosts: k3s_cluster
  become: yes
  vars:
    airgap_dir: /opt/k3s-airgap
    k3s_version: v1.28.3+k3s1
  roles:
    - homelab.k3s.airgap
    - homelab.k3s.prereq
    - homelab.k3s.k3s_server  # or k3s_agent
```

### Airgap with Custom Artifact Location

```yaml
- hosts: k3s_cluster
  become: yes
  vars:
    airgap_dir: /home/admin/k3s-offline
  roles:
    - homelab.k3s.airgap
    - homelab.k3s.prereq
```

### Airgap for Specific Architecture

```yaml
# Role automatically detects architecture
- hosts: pi_cluster
  become: yes
  vars:
    airgap_dir: /opt/k3s-airgap
  roles:
    - homelab.k3s.raspberrypi
    - homelab.k3s.airgap  # Will use arm64 artifacts
    - homelab.k3s.prereq
```

## Preparing Airgap Artifacts

### Download Required Files

```bash
# Set K3s version
K3S_VERSION=v1.28.3+k3s1

# Create airgap directory
mkdir -p /opt/k3s-airgap
cd /opt/k3s-airgap

# Download install script
curl -sfL https://get.k3s.io/ -o k3s-install.sh
chmod +x k3s-install.sh

# Download K3s binary (choose architecture)
# For ARM64 (Raspberry Pi 3/4/5)
curl -sfL https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-arm64 -o k3s-arm64

# For AMD64 (x86_64)
curl -sfL https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s -o k3s-amd64

# For ARMv7 (Raspberry Pi 2)
curl -sfL https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-armhf -o k3s-arm

# Download airgap images (choose architecture)
# For ARM64
curl -sfL https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-airgap-images-arm64.tar.gz -o k3s-airgap-images-arm64.tar.gz

# For AMD64
curl -sfL https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-airgap-images-amd64.tar.gz -o k3s-airgap-images-amd64.tar.gz

# For ARMv7
curl -sfL https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-airgap-images-arm.tar.gz -o k3s-airgap-images-arm.tar.gz

# Download SELinux RPM (for RHEL/CentOS)
curl -sfL https://github.com/k3s-io/k3s-selinux/releases/download/v1.4.stable.1/k3s-selinux-1.4-1.el8.noarch.rpm -o k3s-selinux-1.4-1.el8.noarch.rpm
```

### Verify Artifacts

```bash
# List airgap directory
ls -lh /opt/k3s-airgap/

# Expected files (example for ARM64):
# k3s-install.sh
# k3s-arm64 (or k3s-amd64, k3s-arm)
# k3s-airgap-images-arm64.tar.gz
# k3s-selinux-*.rpm (optional)
```

## Distribution Process

### Artifact Distribution Flow

1. **Check Install Script** - Verifies k3s-install.sh exists locally
2. **Download if Missing** - Downloads install script if not present
3. **Distribute Script** - Copies install script to /usr/local/bin/ on nodes
4. **Detect Architecture** - Determines target node architecture
5. **Distribute Binary** - Copies appropriate k3s binary to /usr/local/bin/k3s
6. **Distribute SELinux RPM** - Copies SELinux RPM to /tmp/ (RHEL/CentOS only)
7. **Install SELinux Policy** - Installs RPM on RHEL/CentOS systems
8. **Create Images Directory** - Creates /var/lib/rancher/k3s/agent/images/
9. **Distribute Images** - Copies all .tar, .tar.gz, and .tar.zst files
10. **Run Install** - Executes k3s-install.sh with airgap settings

## Tasks Overview

### Validation Tasks

- **Ansible Version Check** - Enforces minimum Ansible 2.12
- **Airgap Check** - Only runs when airgap_dir is defined

### Control Node Tasks

- **Check Install Script** - Verifies k3s-install.sh exists locally
- **Download Script** - Downloads install script if missing (requires internet)

### Distribution Tasks

- **Distribute Install Script** - Copies to /usr/local/bin/k3s-install.sh
- **Detect Architecture** - Sets k3s_arch fact
- **Distribute Binary** - Copies architecture-specific binary
- **Distribute SELinux RPM** - Copies RPM files (RHEL/CentOS)
- **Install SELinux Policy** - Installs RPM package

### Image Distribution

- **Create Images Directory** - Creates /var/lib/rancher/k3s/agent/images/
- **Distribute Images** - Copies all container image archives

### Installation

- **Run Install (Server)** - Executes install for server nodes
- **Run Install (Agent)** - Executes install for agent nodes

## Files and Directories

### Local Control Node

- **{{ airgap_dir }}/k3s-install.sh** - K3s installation script
- **{{ airgap_dir }}/k3s-{{ arch }}** - K3s binary for each architecture
- **{{ airgap_dir }}/k3s-airgap-images-*.tar.gz** - Container image archives
- **{{ airgap_dir }}/k3s-selinux-*.rpm** - SELinux policy RPMs (optional)

### Target Nodes

- **/usr/local/bin/k3s-install.sh** - Installation script
- **/usr/local/bin/k3s** - K3s binary (755 permissions)
- **/var/lib/rancher/k3s/agent/images/*.tar.gz** - Container images
- **/tmp/k3s-selinux-*.rpm** - SELinux RPM (temporary)

## Handlers

This role does not define handlers. Installation is triggered directly by tasks.

## Dependencies

None. This role is designed to run before other K3s roles in airgap environments.

## Environment Variables

### Installation Environment

```yaml
# Server nodes
INSTALL_K3S_SKIP_ENABLE: "true"    # Don't enable service (done by k3s_server role)
INSTALL_K3S_SKIP_DOWNLOAD: "true"  # Use local artifacts

# Agent nodes
INSTALL_K3S_SKIP_ENABLE: "true"    # Don't enable service (done by k3s_agent role)
INSTALL_K3S_SKIP_DOWNLOAD: "true"  # Use local artifacts
INSTALL_K3S_EXEC: agent            # Install as agent
```

## Architecture Detection

### Supported Architectures

- **aarch64** → arm64 (Raspberry Pi 3/4/5, ARM64 servers)
- **armv7l** → arm (Raspberry Pi 2, ARMv7 boards)
- **x86_64** → amd64 (Standard x86_64 servers)

### Binary Selection

```yaml
# Role searches for binaries in this order:
with_first_found:
  - "{{ airgap_dir }}/k3s-{{ k3s_arch }}"  # Architecture-specific
  - "{{ airgap_dir }}/k3s"                 # Generic binary
```

## Troubleshooting

### Missing Artifacts

```bash
# Verify all required files exist
ls -lh /opt/k3s-airgap/

# Check for architecture-specific binary
ls -lh /opt/k3s-airgap/k3s-arm64

# Verify image archives
ls -lh /opt/k3s-airgap/*.tar.gz
```

### Ansible Version Error

```bash
# Check Ansible version
ansible --version

# Upgrade if needed
pip install --upgrade ansible-core
```

### Binary Not Found

```bash
# Role looks for:
# 1. /opt/k3s-airgap/k3s-arm64 (for ARM64)
# 2. /opt/k3s-airgap/k3s (fallback)

# Ensure correct binary is present
curl -sfL https://github.com/k3s-io/k3s/releases/download/v1.28.3+k3s1/k3s-arm64 \
  -o /opt/k3s-airgap/k3s-arm64
```

### Images Not Loading

```bash
# Verify images were copied
ls -lh /var/lib/rancher/k3s/agent/images/

# Check K3s can load images
k3s ctr images list

# Manually import if needed
k3s ctr images import /var/lib/rancher/k3s/agent/images/k3s-airgap-images-arm64.tar.gz
```

### SELinux Issues (RHEL/CentOS)

```bash
# Check if SELinux RPM was installed
rpm -qa | grep k3s-selinux

# Install manually if needed
dnf install /tmp/k3s-selinux-*.rpm

# Verify SELinux policy
semodule -l | grep k3s
```

## Security Considerations

- **Artifact Integrity** - Verify checksums of downloaded artifacts
- **Script Validation** - Review k3s-install.sh before distribution
- **Binary Verification** - Use official K3s releases only
- **Access Control** - Restrict access to airgap_dir on control node
- **Image Security** - Scan container images for vulnerabilities before distribution

## Performance Considerations

- **Distribution Time** - Depends on artifact size and network speed
- **Image Size** - Airgap images can be 500MB-1GB per architecture
- **Storage Requirements** - Nodes need space for images in /var/lib/rancher/k3s/
- **Parallel Distribution** - Ansible distributes to nodes in parallel by default
- **Local Caching** - Control node should have fast storage for airgap_dir

## Best Practices

### Artifact Management

- **Version Control** - Maintain separate directories for each K3s version
- **Checksums** - Verify artifact checksums after download
- **Documentation** - Document which version and architecture each artifact is for
- **Backup** - Keep backup of artifacts on separate media

### Distribution Strategy

```yaml
# Recommended playbook structure
- hosts: k3s_cluster
  become: yes
  serial: "{{ batch_size | default(5) }}"  # Control distribution speed
  vars:
    airgap_dir: /opt/k3s-airgap
  roles:
    - homelab.k3s.raspberrypi  # Detect architecture
    - homelab.k3s.airgap       # Distribute artifacts
    - homelab.k3s.prereq       # Configure prerequisites
```

### Testing

```bash
# Test artifact download on control node
ansible-playbook test-download.yml --tags download

# Test distribution to one node
ansible-playbook airgap-deploy.yml --limit k3-01

# Verify before full deployment
ansible k3s_cluster -m shell -a "ls -lh /var/lib/rancher/k3s/agent/images/"
```

## Common Scenarios

### Single Architecture Deployment

```yaml
# All ARM64 nodes (Raspberry Pi cluster)
- hosts: pi_cluster
  become: yes
  vars:
    airgap_dir: /opt/k3s-airgap-arm64
  roles:
    - homelab.k3s.airgap
```

### Multi-Architecture Deployment

```yaml
# Mixed architecture cluster
- hosts: k3s_cluster
  become: yes
  vars:
    airgap_dir: /opt/k3s-airgap  # Contains binaries for all architectures
  roles:
    - homelab.k3s.raspberrypi
    - homelab.k3s.airgap  # Automatically selects correct binary
```

### Version Upgrade in Airgap

```yaml
# Prepare new version artifacts, then:
- hosts: k3s_cluster
  become: yes
  serial: 1
  vars:
    airgap_dir: /opt/k3s-airgap-v1.28.4
    k3s_version: v1.28.4+k3s1
  roles:
    - homelab.k3s.airgap
    - homelab.k3s.k3s_upgrade
```

## Integration with Other Roles

### Before prereq Role

```yaml
- homelab.k3s.airgap       # 1. Distribute artifacts
- homelab.k3s.prereq       # 2. Configure system
- homelab.k3s.k3s_server   # 3. Install K3s
```

### With Security Hardening

```yaml
- homelab.k3s.airgap
- homelab.k3s.prereq
- homelab.k3s.security_hardening
- homelab.k3s.k3s_server
```

## License

Apache License 2.0 - See collection LICENSE file for details.
