# Airgap Role

Enables K3s deployment in air-gapped (offline) environments by distributing pre-downloaded K3s binaries, container images, and installation scripts to cluster nodes without requiring internet connectivity.

## Features

- **Offline Installation** - Deploy K3s without internet access
- **Binary Distribution** - Distributes K3s binaries to all nodes
- **Image Distribution** - Distributes container images for K3s components
- **Multi-Architecture** - Supports AMD64, ARM64, and ARM architectures
- **SELinux Support** - Distributes and installs SELinux policies for RHEL
- **Install Script** - Distributes official K3s installation script
- **Automated Detection** - Automatically detects architecture
- **Image Formats** - Supports tar, tar.gz, and tar.zst image formats
- **Version Control** - Manages specific K3s versions for airgap deployment

## Requirements

- Ansible core 2.12 or higher
- Pre-downloaded K3s artifacts in airgap directory:
  - k3s binary (or k3s-amd64, k3s-arm64, k3s-arm)
  - k3s-install.sh script
  - k3s-airgap-images (tar/tar.gz/tar.zst)
  - k3s-selinux RPM (for RHEL systems)
- Sufficient storage on target nodes
- Root or sudo access

## Role Variables

### Airgap Configuration

```yaml
# Airgap directory on control node
airgap_dir: /opt/k3s-airgap

# Architecture detection (automatic)
k3s_arch: "{{ 'arm64' if ansible_architecture == 'aarch64' else 'arm' if ansible_architecture == 'armv7l' else 'amd64' }}"
```

### File Naming Conventions

Expected files in airgap_dir:

```bash
k3s-install.sh                          # K3s installation script
k3s-amd64 or k3s-arm64 or k3s-arm      # Architecture-specific binary
k3s-airgap-images-amd64.tar.zst        # Container images (zstd)
k3s-airgap-images-amd64.tar.gz         # Container images (gzip)
k3s-airgap-images-amd64.tar            # Container images (uncompressed)
k3s-selinux-*.rpm                      # SELinux policy (RHEL only)
```

## Usage

### Basic Airgap Deployment

```yaml
- name: Deploy K3s in airgapped environment
  hosts: k3s_cluster
  become: yes
  vars:
    airgap_dir: /opt/k3s-airgap
  roles:
    - homelab.proxmox_lxc.prereq
    - homelab.proxmox_lxc.airgap
    - homelab.proxmox_lxc.k3s_server  # or k3s_agent
```

### Multi-Architecture Cluster

```yaml
- name: Deploy mixed architecture airgapped cluster
  hosts: k3s_cluster
  become: yes
  vars:
    airgap_dir: /opt/k3s-airgap
  roles:
    - homelab.proxmox_lxc.raspberrypi  # Detect Raspberry Pi
    - homelab.proxmox_lxc.airgap
  tasks:
    - name: Verify correct binary was distributed
      stat:
        path: /usr/local/bin/k3s
      register: k3s_binary

    - name: Display architecture
      debug:
        msg: "K3s binary distributed for {{ k3s_arch }} architecture"
```

### With SELinux (RHEL)

```yaml
- name: Deploy K3s airgapped on RHEL with SELinux
  hosts: rhel_k3s_cluster
  become: yes
  vars:
    airgap_dir: /opt/k3s-airgap
  roles:
    - homelab.proxmox_lxc.airgap

  post_tasks:
    - name: Verify SELinux policy installed
      command: rpm -q k3s-selinux
      register: selinux_rpm
      changed_when: false
      failed_when: false
      when: ansible_os_family == 'RedHat'
```

## Preparing Airgap Assets

### Download K3s Assets

On an internet-connected machine:

```bash
#!/bin/bash
# Script to download K3s airgap assets

K3S_VERSION="v1.28.5+k3s1"
AIRGAP_DIR="/opt/k3s-airgap"

mkdir -p "$AIRGAP_DIR"
cd "$AIRGAP_DIR"

# Download K3s install script
curl -sfL https://get.k3s.io -o k3s-install.sh
chmod +x k3s-install.sh

# Download K3s binaries
# AMD64
curl -sfL "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s" -o k3s-amd64
# ARM64
curl -sfL "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-arm64" -o k3s-arm64
# ARMv7
curl -sfL "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-armhf" -o k3s-arm

# Download airgap images
# AMD64
curl -sfL "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-airgap-images-amd64.tar.zst" -o k3s-airgap-images-amd64.tar.zst
# ARM64
curl -sfL "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-airgap-images-arm64.tar.zst" -o k3s-airgap-images-arm64.tar.zst

# Download SELinux RPM (for RHEL)
curl -sfL "https://github.com/k3s-io/k3s-selinux/releases/download/v1.4.stable.1/k3s-selinux-1.4-1.el8.noarch.rpm" -o k3s-selinux-1.4-1.el8.noarch.rpm

# Set permissions
chmod +x k3s-*
chmod 644 *.tar.zst *.rpm

echo "Airgap assets downloaded to $AIRGAP_DIR"
```

### Transfer to Airgapped Environment

```bash
# Create archive
tar -czf k3s-airgap-bundle.tar.gz -C /opt k3s-airgap

# Transfer via USB, secure file transfer, etc.
# Then extract on airgapped control node:
tar -xzf k3s-airgap-bundle.tar.gz -C /opt
```

## Tasks Overview

The role performs the following operations when airgap_dir is defined:

1. **Version Validation** - Ensures Ansible version is 2.12+
2. **Install Script Check** - Checks if install script already exists
3. **Install Script Download** - Downloads script on control node (if missing)
4. **Script Distribution** - Copies install script to target nodes
5. **Architecture Detection** - Determines target node architecture
6. **Binary Distribution** - Copies architecture-specific K3s binary
7. **SELinux Distribution** - Copies SELinux RPM to temp directory
8. **SELinux Installation** - Installs SELinux policy on RHEL systems
9. **Image Directory Creation** - Creates /var/lib/rancher/k3s/agent/images
10. **Image Distribution** - Copies container image tarballs
11. **K3s Installation** - Runs k3s-install.sh with airgap settings

## Dependencies

This role requires:

- ansible.builtin modules (copy, file, command, set_fact)

## Files and Directories

### Control Node

```bash
{{ airgap_dir }}/
├── k3s-install.sh               # Installation script
├── k3s-amd64                    # AMD64 binary
├── k3s-arm64                    # ARM64 binary
├── k3s-arm                      # ARMv7 binary
├── k3s-airgap-images-*.tar.zst  # Container images
└── k3s-selinux-*.rpm            # SELinux policy
```

### Target Nodes

```bash
/usr/local/bin/
└── k3s-install.sh               # Installation script
└── k3s                          # K3s binary

/var/lib/rancher/k3s/agent/images/
└── k3s-airgap-images-*.tar.zst  # Container images

/tmp/
└── k3s-selinux-*.rpm            # SELinux RPM (temporary)
```

## Environment Variables

The role sets these environment variables during installation:

```bash
INSTALL_K3S_SKIP_ENABLE=true      # Don't enable service yet
INSTALL_K3S_SKIP_DOWNLOAD=true    # Use local files
INSTALL_K3S_EXEC=agent            # For agent nodes
```

## Examples

### Complete Airgap Deployment

```yaml
- name: Prepare airgap assets
  hosts: localhost
  become: no
  tasks:
    - name: Ensure airgap directory exists
      file:
        path: /opt/k3s-airgap
        state: directory
        mode: '0755'

    - name: Download airgap assets
      script: download-k3s-airgap.sh v1.28.5+k3s1
      args:
        creates: /opt/k3s-airgap/k3s-install.sh

- name: Deploy airgapped K3s cluster
  hosts: k3s_cluster
  become: yes
  vars:
    airgap_dir: /opt/k3s-airgap
    k3s_version: "v1.28.5+k3s1"

  roles:
    - homelab.proxmox_lxc.prereq
    - homelab.proxmox_lxc.raspberrypi
    - homelab.proxmox_lxc.airgap

- name: Install K3s servers
  hosts: k3s_servers
  become: yes
  roles:
    - homelab.proxmox_lxc.k3s_server

- name: Install K3s agents
  hosts: k3s_agents
  become: yes
  roles:
    - homelab.proxmox_lxc.k3s_agent
```

### Version-Specific Airgap

```yaml
- name: Deploy specific K3s version airgapped
  hosts: k3s_cluster
  become: yes
  vars:
    k3s_version: "v1.27.10+k3s1"
    airgap_dir: "/opt/k3s-airgap-{{ k3s_version }}"
  roles:
    - homelab.proxmox_lxc.airgap
```

### Airgap with Custom Registry

```yaml
- name: Deploy with airgap and private registry
  hosts: k3s_cluster
  become: yes
  vars:
    airgap_dir: /opt/k3s-airgap
    registries_config_yaml: |
      mirrors:
        docker.io:
          endpoint:
            - "https://harbor.internal.local"
      configs:
        "harbor.internal.local":
          auth:
            username: "k3s"
            password: "{{ vault_harbor_password }}"
  roles:
    - homelab.proxmox_lxc.prereq
    - homelab.proxmox_lxc.airgap
```

## Troubleshooting

### Binary Not Found

```bash
# Check if binary exists on control node
ls -lh /opt/k3s-airgap/k3s-*

# Verify architecture detection
ansible k3s_cluster -m setup -a 'filter=ansible_architecture'

# Check distributed binary
ansible k3s_cluster -m stat -a 'path=/usr/local/bin/k3s' -b
```

### Image Loading Issues

```bash
# Check image directory
ls -lh /var/lib/rancher/k3s/agent/images/

# Verify image file integrity
file /var/lib/rancher/k3s/agent/images/*.tar.zst

# Check available disk space
df -h /var/lib/rancher/k3s/
```

### SELinux Installation Fails

```bash
# Check if SELinux is enabled
getenforce

# Verify RPM exists
ls -lh /opt/k3s-airgap/k3s-selinux*.rpm

# Manual installation
sudo rpm -ivh /tmp/k3s-selinux*.rpm

# Check SELinux policy
sudo semodule -l | grep k3s
```

### Install Script Issues

```bash
# Verify script is executable
ls -l /usr/local/bin/k3s-install.sh

# Test script manually
sudo INSTALL_K3S_SKIP_DOWNLOAD=true /usr/local/bin/k3s-install.sh

# Check environment variables
env | grep K3S
```

## Security Considerations

- **File Permissions** - Ensure airgap files have appropriate permissions (755 for binaries)
- **Checksum Verification** - Verify checksums of downloaded files
- **Secure Transfer** - Use secure methods to transfer airgap bundle
- **Access Control** - Restrict access to airgap directory
- **Version Control** - Maintain manifest of included versions
- **Image Scanning** - Scan container images for vulnerabilities before airgapping

## Performance Considerations

- **Local Distribution** - Files are copied from control node, ensure adequate bandwidth
- **Disk Space** - Container images can be several GB per architecture
- **Compression** - Use .tar.zst for smaller file sizes (vs .tar or .tar.gz)
- **Parallel Deployment** - Consider serial deployment to avoid control node bandwidth saturation

## Storage Requirements

Approximate storage needed:

```
k3s binary: ~100MB per architecture
airgap images: ~800MB-1.2GB per architecture (compressed)
SELinux RPM: ~25KB
Total per architecture: ~1GB
```

For multi-architecture cluster:
- Control node: ~3GB (all architectures)
- Target node: ~1GB (single architecture)

## Version Compatibility

This role is compatible with K3s versions:

- v1.24.x and newer (recommended: v1.27+)
- Requires matching versions between:
  - k3s binary
  - k3s-airgap-images
  - k3s-selinux (if using RHEL)

## Integration Example

```yaml
# Complete airgap deployment workflow
- name: Stage 1 - Prepare airgap assets (internet-connected)
  hosts: localhost
  tasks:
    - name: Download K3s airgap bundle
      script: scripts/download-k3s-airgap.sh
      args:
        creates: /opt/k3s-airgap/k3s-install.sh

- name: Stage 2 - Deploy to airgapped environment
  hosts: k3s_cluster
  become: yes
  vars:
    airgap_dir: /opt/k3s-airgap
  roles:
    - homelab.proxmox_lxc.prereq
    - homelab.proxmox_lxc.airgap

- name: Stage 3 - Install K3s servers
  hosts: k3s_servers
  become: yes
  serial: 1
  roles:
    - homelab.proxmox_lxc.k3s_server

- name: Stage 4 - Install K3s agents
  hosts: k3s_agents
  become: yes
  roles:
    - homelab.proxmox_lxc.k3s_agent
```

## License

Apache License 2.0 - See collection LICENSE file for details.
