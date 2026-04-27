# LXC Template Role

Downloads and manages LXC container templates in Proxmox VE storage, with support for concurrent downloads, verification, and automatic caching. Focuses on Ubuntu templates for consistent, well-supported container deployments.

## Features

- **Automatic Template Download** - Downloads LXC templates from official Proxmox repositories
- **Ubuntu Focus** - Prioritizes Ubuntu LTS templates for easier management
- **Concurrent Downloads** - Supports parallel template downloads for faster provisioning
- **Intelligent Caching** - Only downloads templates that don't already exist
- **Force Refresh** - Optional force download to update existing templates
- **Verification** - Validates downloaded templates exist and are accessible
- **Async Operations** - Non-blocking downloads with progress monitoring
- **Storage Management** - Automatic storage directory creation and permissions
- **Template Discovery** - Lists existing templates before downloading
- **Cache Refresh** - Updates Proxmox template cache after downloads

## Requirements

- Proxmox VE 7.0 or higher
- Internet connectivity for template downloads
- Sufficient storage space in template directory (typically /var/lib/vz/template/cache)
- Root or sudo access on Proxmox host
- homelab.common collection installed

## Role Variables

### Template Configuration

```yaml
# Default Ubuntu LXC templates
lxc_templates:
  - name: ubuntu-22.04-standard
    url: http://download.proxmox.com/images/system/ubuntu-22.04-standard_22.04-1_amd64.tar.zst
    filename: ubuntu-22.04-standard_22.04-1_amd64.tar.zst
    storage: local
    force_download: false

  - name: ubuntu-20.04-standard
    url: http://download.proxmox.com/images/system/ubuntu-20.04-standard_20.04-1_amd64.tar.zst
    filename: ubuntu-20.04-standard_20.04-1_amd64.tar.zst
    storage: local
    force_download: false

  - name: ubuntu-24.04-standard
    url: http://download.proxmox.com/images/system/ubuntu-24.04-standard_24.04-2_amd64.tar.zst
    filename: ubuntu-24.04-standard_24.04-2_amd64.tar.zst
    storage: local
    force_download: false
```

### Storage Configuration

```yaml
# Template storage location
lxc_template_storage_path: /var/lib/vz/template/cache

# Default template for containers
default_lxc_template: ubuntu-22.04-standard
```

### Download Configuration

```yaml
# Maximum number of concurrent downloads
max_concurrent_downloads: 3

# Download timeout in seconds (30 minutes)
download_timeout: 1800
```

## Usage

### Basic Template Download

```yaml
- name: Download LXC templates
  hosts: proxmox_hosts
  roles:
    - homelab.proxmox_lxc.lxc_template
```

### Download Specific Templates

```yaml
- name: Download only Ubuntu 22.04 template
  hosts: proxmox_hosts
  vars:
    lxc_templates:
      - name: ubuntu-22.04-standard
        url: http://download.proxmox.com/images/system/ubuntu-22.04-standard_22.04-1_amd64.tar.zst
        filename: ubuntu-22.04-standard_22.04-1_amd64.tar.zst
        storage: local
        force_download: false
  roles:
    - homelab.proxmox_lxc.lxc_template
```

### Force Template Refresh

```yaml
- name: Force re-download of all templates
  hosts: proxmox_hosts
  vars:
    lxc_templates:
      - name: ubuntu-22.04-standard
        url: http://download.proxmox.com/images/system/ubuntu-22.04-standard_22.04-1_amd64.tar.zst
        filename: ubuntu-22.04-standard_22.04-1_amd64.tar.zst
        storage: local
        force_download: true
  roles:
    - homelab.proxmox_lxc.lxc_template
```

### Custom Template Repository

```yaml
- name: Download from custom repository
  hosts: proxmox_hosts
  vars:
    lxc_templates:
      - name: custom-ubuntu
        url: https://internal-repo.example.com/templates/ubuntu-custom.tar.zst
        filename: ubuntu-custom.tar.zst
        storage: local
        force_download: false
    download_timeout: 3600  # 1 hour for large templates
  roles:
    - homelab.proxmox_lxc.lxc_template
```

## Template Types

### Ubuntu LTS Templates

**Ubuntu 22.04 LTS (Jammy Jellyfish)** - Recommended
- Long-term support until 2027
- Python 3.10 pre-installed
- Modern kernel and systemd
- Best compatibility with Ansible

**Ubuntu 20.04 LTS (Focal Fossa)**
- Long-term support until 2025
- Python 3.8 pre-installed
- Stable and well-tested
- Good for legacy applications

**Ubuntu 24.04 LTS (Noble Numbat)**
- Long-term support until 2029
- Latest features and improvements
- Python 3.12 pre-installed
- Recommended for new deployments

### Why Ubuntu?

This collection focuses on Ubuntu templates because:

1. **Pre-installed Python** - Ansible requires Python, Ubuntu includes it by default
2. **Package Availability** - Extensive APT repositories
3. **LTS Support** - 5+ years of security updates
4. **Documentation** - Extensive community support
5. **Consistency** - Unified package management and configuration

## Tasks Overview

The role performs the following operations:

1. **Storage Verification** - Checks if template storage directory exists
2. **Directory Creation** - Creates storage directory if needed
3. **Template Discovery** - Lists existing templates in storage
4. **Download Planning** - Determines which templates need downloading
5. **Async Download** - Downloads templates concurrently (non-blocking)
6. **Download Monitoring** - Waits for and monitors download progress
7. **Verification** - Validates downloaded templates
8. **Cache Refresh** - Updates Proxmox template cache

## Dependencies

This role requires:

- ansible.builtin modules (get_url, stat, file, shell)
- Proxmox VE 7.0+ with pveam command

## Files and Templates

### Storage Locations

- **/var/lib/vz/template/cache/** - Default template storage
- Templates are named according to: `distribution-version-type_version_architecture.tar.{zst,xz,gz}`

### Template Formats

Supported compression formats:

- **.tar.zst** - Zstandard compression (fastest, recommended)
- **.tar.xz** - XZ compression (smaller size)
- **.tar.gz** - Gzip compression (compatibility)

## Examples

### Complete Infrastructure Setup

```yaml
- name: Prepare Proxmox infrastructure
  hosts: proxmox_hosts
  tasks:
    - name: Download all required templates
      include_role:
        name: homelab.proxmox_lxc.lxc_template

    - name: Verify templates are available
      command: pveam list local
      register: template_list
      changed_when: false

    - name: Display available templates
      debug:
        var: template_list.stdout_lines
```

### Multi-Node Template Deployment

```yaml
- name: Deploy templates to all Proxmox nodes
  hosts: proxmox_cluster
  serial: 1  # One node at a time to avoid download contention
  vars:
    lxc_templates:
      - name: ubuntu-22.04-standard
        url: http://download.proxmox.com/images/system/ubuntu-22.04-standard_22.04-1_amd64.tar.zst
        filename: ubuntu-22.04-standard_22.04-1_amd64.tar.zst
        storage: local
        force_download: false
  roles:
    - homelab.proxmox_lxc.lxc_template
```

### Template Update Workflow

```yaml
- name: Update LXC templates quarterly
  hosts: proxmox_hosts
  vars:
    lxc_templates:
      - name: ubuntu-22.04-standard
        url: http://download.proxmox.com/images/system/ubuntu-22.04-standard_22.04-1_amd64.tar.zst
        filename: ubuntu-22.04-standard_22.04-1_amd64.tar.zst
        storage: local
        force_download: true  # Force update to get latest version
  roles:
    - homelab.proxmox_lxc.lxc_template

  post_tasks:
    - name: Clean up old template versions
      shell: |
        cd /var/lib/vz/template/cache
        ls -t ubuntu-22.04-standard*.tar.zst | tail -n +2 | xargs -r rm
      args:
        executable: /bin/bash
```

## Troubleshooting

### Download Failures

```bash
# Check internet connectivity
ping download.proxmox.com

# Test manual download
wget http://download.proxmox.com/images/system/ubuntu-22.04-standard_22.04-1_amd64.tar.zst

# Check available disk space
df -h /var/lib/vz/template/cache

# Verify storage permissions
ls -la /var/lib/vz/template/cache
```

### Template Not Appearing

```bash
# List templates via pveam
pveam list local

# Manually refresh template cache
pveam update

# Check file exists
ls -lh /var/lib/vz/template/cache/ubuntu-22.04-standard*.tar.zst

# Verify file integrity
file /var/lib/vz/template/cache/ubuntu-22.04-standard*.tar.zst
```

### Slow Downloads

```bash
# Check network bandwidth
iftop -i vmbr0

# Test download speed
wget --output-document=/dev/null http://download.proxmox.com/images/system/ubuntu-22.04-standard_22.04-1_amd64.tar.zst

# Consider using a mirror or caching proxy
# Add to vars:
lxc_templates:
  - url: http://mirror.example.com/proxmox/ubuntu-22.04.tar.zst
```

### Timeout Issues

```bash
# Increase timeout for large templates or slow connections
# In playbook:
vars:
  download_timeout: 3600  # 1 hour

# Check for network issues
traceroute download.proxmox.com

# Monitor download progress
tail -f /var/log/syslog | grep wget
```

## Security Considerations

- **HTTPS Downloads** - Use HTTPS URLs when available for template downloads
- **Checksum Verification** - Consider adding SHA256 checksum verification
- **Source Validation** - Only download from trusted repositories
- **Storage Permissions** - Ensure template directory has appropriate permissions (0755)
- **Template Updates** - Regularly update templates to get security fixes
- **Network Isolation** - Consider using internal mirror for airgapped environments

## Performance Optimization

- **Concurrent Downloads** - Adjust max_concurrent_downloads based on bandwidth
- **Storage Backend** - Use fast storage (SSD) for template cache
- **Mirror Selection** - Use geographically close mirrors
- **Compression Format** - Prefer .tar.zst for faster decompression
- **Caching Strategy** - Keep commonly used templates, remove old versions

## Integration with Container Creation

This role is typically used before container creation:

```yaml
- name: Complete container deployment
  hosts: proxmox_hosts
  tasks:
    - name: Ensure templates are available
      include_role:
        name: homelab.proxmox_lxc.lxc_template

    - name: Create containers
      include_role:
        name: homelab.proxmox_lxc.lxc_container
      vars:
        container_template: "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
```

## Advanced Usage

### Airgapped Environments

```yaml
- name: Prepare templates for airgapped deployment
  hosts: internet_connected_host
  tasks:
    - name: Download templates
      include_role:
        name: homelab.proxmox_lxc.lxc_template

    - name: Archive templates
      archive:
        path: /var/lib/vz/template/cache/*.tar.zst
        dest: /tmp/lxc-templates.tar.gz

    - name: Transfer to airgapped environment
      # Manual transfer process
```

### Custom Template Creation

```yaml
- name: Create custom template from existing container
  hosts: proxmox_hosts
  tasks:
    - name: Stop container
      command: pct stop 999

    - name: Create template
      command: vzdump 999 --compress zstd --dumpdir /var/lib/vz/template/cache

    - name: Rename to standard format
      shell: |
        cd /var/lib/vz/template/cache
        mv vzdump-lxc-999*.tar.zst custom-ubuntu-22.04_1.0_amd64.tar.zst
```

## License

Apache License 2.0 - See collection LICENSE file for details.
