# Container Base Role

Core role for Proxmox LXC container lifecycle management, providing standardized container creation, configuration, and API integration for homelab infrastructure deployments.

## Features

- **Proxmox API Integration** - Secure API token authentication for container management
- **Container Lifecycle Management** - Automated container creation, starting, and configuration
- **Resource Allocation** - Dynamic resource assignment (CPU, memory, disk)
- **Network Configuration** - Automated network setup with DHCP or static IP
- **Security by Default** - Unprivileged containers with firewall configuration
- **SSH Key Deployment** - Automatic SSH key injection for secure access
- **Startup Ordering** - Intelligent container boot sequence management
- **Node Selection** - Smart Proxmox node placement based on service type
- **Retry Logic** - Resilient API operations with automatic retry
- **Validation Integration** - Built-in API connectivity validation

## Requirements

- Proxmox VE 7.0+ with API access configured
- API tokens created with appropriate privileges
- LXC templates pre-downloaded on Proxmox nodes
- Network bridge (vmbr0) configured
- homelab.common collection installed
- community.general collection (>=7.0.0)

## Role Variables

### Container Resource Configuration

```yaml
# Container resources (inherited from container_defaults)
container_resources:
  disk_size: "8G"
  cores: 2
  memory: 2048
  swap: 512
```

### Network Configuration

```yaml
# Network settings
container_network:
  bridge: vmbr0
  ip_config: dhcp        # or 'static' with ansible_host
  firewall: true
```

### LXC Configuration

```yaml
# LXC-specific settings
lxc_config:
  onboot: true
  unprivileged: true
  template: "ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  storage: local-lvm
```

### Proxmox Node Selection

```yaml
# Automatic node selection based on service type
container_node: >-
  {% if inventory_hostname.endswith('-lxc') and (
    inventory_hostname.startswith('sonarr') or
    inventory_hostname.startswith('radarr') or
    inventory_hostname.startswith('bazarr') or
    inventory_hostname.startswith('prowlarr') or
    inventory_hostname.startswith('qbittorrent') or
    inventory_hostname.startswith('jellyfin') or
    inventory_hostname.startswith('pve-exporter-nas')
  ) -%}
  {{ proxmox_config.pve_nas.node }}
  {%- else -%}
  {{ proxmox_config.pve_mac.node }}
  {%- endif %}
```

### Proxmox API Configuration

```yaml
# API settings (from global configuration)
proxmox_config:
  pve_mac:
    node: "pve-mac"
    host: "192.168.0.56"
    api_token_id: "ansible@pve!homelab"
    api_token_secret: "{{ vault_pve_mac_token }}"
    validate_certs: false
  pve_nas:
    node: "pve-nas"
    host: "192.168.0.57"
    api_token_id: "ansible@pve!homelab"
    api_token_secret: "{{ vault_pve_nas_token }}"
    validate_certs: false

# API retry configuration
proxmox_api_defaults:
  timeout: 300
  retry_count: 3
  retry_delay: 5
```

### Container Startup Order

```yaml
# Service-based startup priorities
container_startup_order:
  networking: 1     # DNS, VPN, reverse proxy
  monitoring: 2     # Prometheus, Grafana, exporters
  automation: 3     # Home Assistant
  nas_services: 4   # Media services
  logging: 5        # Loki, log aggregation
```

### Container Defaults

```yaml
# Global container defaults (from all.yml)
container_defaults:
  cores: 2
  memory: 2048
  swap: 512
  disk_size: "8G"
  unprivileged: true
  onboot: true
  template: "ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  ssh_key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
```

## Usage

### Basic Container Creation

```yaml
- hosts: prometheus-lxc
  vars:
    container_id: 200
    proxmox_node: "pve-mac"
    container_resources:
      cores: 4
      memory: 4096
      swap: 512
      disk_size: "20G"
  roles:
    - homelab.common.container_base
```

### Multiple Containers Deployment

```yaml
- hosts: lxc_containers
  serial: 1  # Create one at a time to avoid conflicts
  vars:
    container_defaults:
      unprivileged: true
      onboot: true
  roles:
    - homelab.common.container_base
```

### Custom Network Configuration

```yaml
- hosts: traefik-lxc
  vars:
    container_id: 205
    proxmox_node: "pve-mac"
    container_network:
      bridge: vmbr0
      ip_config: static
      firewall: true
    # ansible_host provides the static IP
  roles:
    - homelab.common.container_base
```

### High-Resource Service Container

```yaml
- hosts: jellyfin-lxc
  vars:
    container_id: 235
    proxmox_node: "pve-nas"  # Media server on NAS node
    container_resources:
      cores: 6
      memory: 8192
      swap: 1024
      disk_size: "50G"
  roles:
    - homelab.common.container_base
```

### Monitoring Stack Containers

```yaml
- hosts: monitoring_stack
  vars:
    container_startup_order:
      monitoring: 2
    container_resources:
      cores: 4
      memory: 4096
  roles:
    - homelab.common.container_base
```

## Tasks Overview

### Validation Tasks

1. **Proxmox API Validation** - Verify API connectivity and authentication
2. **Template Availability Check** - Ensure LXC templates are downloaded
3. **Resource Validation** - Check sufficient resources on target node

### Container Configuration Tasks

1. **Set Container Variables** - Configure container parameters
2. **Build Network Configuration** - Create network interface settings
3. **Prepare Resource Allocation** - Set CPU, memory, and disk parameters
4. **Configure Security Settings** - Set unprivileged mode and capabilities

### Container Lifecycle Tasks

1. **Create LXC Container** - Deploy container via Proxmox API
2. **Start Container** - Boot container and verify startup
3. **Wait for SSH** - Ensure container is reachable
4. **Configure Startup Order** - Set boot priority based on service type

## Files and Templates

### Included Task Files

- **proxmox_api_validation.yml** - API connectivity and token validation
- Main task file implements all container lifecycle operations

### Dynamic Configuration

All configurations are generated dynamically based on role variables and inventory settings. No static templates required.

## Handlers

This role does not define handlers as it manages infrastructure state directly through the Proxmox API.

## Dependencies

- community.general (>=7.0.0) - For proxmox module
- homelab.common collection - For shared configuration and validation tasks

## Integration Points

### With Common Setup Role

```yaml
- hosts: lxc_containers
  serial: 1
  roles:
    - homelab.common.container_base
    # Container is now created and accessible
  tasks:
    - name: Run common setup inside container
      include_role:
        name: homelab.common.common_setup
```

### With Service Roles

```yaml
- hosts: prometheus-lxc
  roles:
    - homelab.common.container_base
    - homelab.proxmox_lxc.prometheus
```

### With Security Hardening

```yaml
- hosts: lxc_containers
  roles:
    - homelab.common.container_base
    - homelab.common.security_hardening
```

## Network Configuration

### DHCP Configuration (Default)

```yaml
container_network:
  bridge: vmbr0
  ip_config: dhcp
  firewall: true
```

### Static IP Configuration

```yaml
# In inventory:
prometheus-lxc:
  ansible_host: 192.168.0.200
  container_id: 200

# In playbook:
container_network:
  bridge: vmbr0
  ip_config: static
  firewall: true
```

### Multiple Network Interfaces

```yaml
container_netif:
  net0: "name=eth0,bridge=vmbr0,ip={{ ansible_host }}/24,gw={{ homelab_network.gateway_ip }}"
  net1: "name=eth1,bridge=vmbr1,ip=10.0.1.10/24"
```

## Node Placement Strategy

### Automatic Placement

The role automatically selects the appropriate Proxmox node based on service type:

- **Media Services** → pve-nas (Sonarr, Radarr, Bazarr, Prowlarr, qBittorrent, Jellyfin)
- **NAS Monitoring** → pve-nas (PVE exporters for NAS)
- **Core Services** → pve-mac (All other services)

### Manual Placement Override

```yaml
- hosts: custom-service-lxc
  vars:
    proxmox_node: "pve-nas"  # Force specific node
  roles:
    - homelab.common.container_base
```

## Security Configuration

### Unprivileged Containers (Default)

```yaml
lxc_config:
  unprivileged: true  # Enhanced security
```

### Privileged Containers (When Required)

```yaml
lxc_config:
  unprivileged: false  # Only for specific use cases
```

### Firewall Configuration

```yaml
container_network:
  firewall: true  # Enable Proxmox firewall
```

### SSH Key Injection

```yaml
container_defaults:
  ssh_key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
```

## Testing and Validation

### Verify Container Creation

```bash
# On Proxmox host
pct list | grep <vmid>
pct config <vmid>

# Check container status
pct status <vmid>
```

### Verify Network Configuration

```bash
# Inside container
ip addr show
ip route show

# Test connectivity
ping -c 3 8.8.8.8
```

### Verify SSH Access

```bash
# From Ansible controller
ssh root@<container_ip>

# Verify SSH key authentication
ssh -v root@<container_ip>
```

### Verify Startup Order

```bash
# On Proxmox host
pct config <vmid> | grep startup
```

## Troubleshooting

### Container Creation Fails

```bash
# Check Proxmox API connectivity
curl -k https://<proxmox_host>:8006/api2/json/version

# Verify API token permissions
pveum user token list ansible@pve

# Check template availability
pveam list local

# Review Proxmox logs
tail -f /var/log/pve/tasks/active
```

### Container Won't Start

```bash
# Check container configuration
pct config <vmid>

# Try manual start
pct start <vmid>

# View container logs
pct enter <vmid>
journalctl -xe
```

### Network Issues

```bash
# Verify bridge configuration
brctl show vmbr0

# Check container network inside container
pct enter <vmid>
ip addr show
ip route show

# Verify firewall rules
pct config <vmid> | grep firewall
```

### SSH Access Problems

```bash
# Check if SSH service is running
pct exec <vmid> -- systemctl status ssh

# Verify SSH port is open
pct exec <vmid> -- ss -tlnp | grep :22

# Check authorized keys
pct exec <vmid> -- cat /root/.ssh/authorized_keys
```

### API Authentication Errors

```bash
# Verify token configuration
cat /etc/pve/priv/token.cfg

# Check token permissions
pveum user token list ansible@pve

# Test API authentication
curl -k -H "Authorization: PVEAPIToken=ansible@pve!homelab=<token>" \
  https://<proxmox_host>:8006/api2/json/version
```

## Performance Considerations

- **Serial Execution** - Create containers serially to avoid storage lock conflicts
- **Resource Allocation** - Monitor Proxmox node resources before mass deployment
- **Storage Performance** - Use local-lvm for better I/O performance
- **Network Bandwidth** - Consider bandwidth when deploying multiple containers
- **API Timeouts** - Increase timeout for large container deployments

## Best Practices

1. **Template Management** - Pre-download all LXC templates before deployment
2. **Resource Planning** - Calculate total resources needed across all containers
3. **Backup Strategy** - Configure Proxmox backup jobs for containers
4. **Naming Convention** - Use consistent naming: `<service>-lxc`
5. **VMID Allocation** - Plan VMID ranges for different service types
6. **Network Segmentation** - Use different bridges for service isolation
7. **Startup Dependencies** - Set proper startup order for service dependencies
8. **Monitoring Integration** - Deploy monitoring agents immediately after creation

## Advanced Usage

### Container with Custom Storage

```yaml
- hosts: database-lxc
  vars:
    container_id: 250
    lxc_config:
      storage: nvme-pool  # Use faster storage
    container_resources:
      disk_size: "100G"
  roles:
    - homelab.common.container_base
```

### Container with Bind Mounts

```yaml
# Add bind mounts post-creation
- name: Add bind mount to container
  community.proxmox.proxmox:
    api_host: "{{ proxmox_config[proxmox_node].host }}"
    api_token_id: "{{ proxmox_config[proxmox_node].api_token_id }}"
    api_token_secret: "{{ proxmox_config[proxmox_node].api_token_secret }}"
    vmid: "{{ container_id }}"
    node: "{{ proxmox_node }}"
    mounts:
      mp0: "/mnt/nas,mp=/mnt/nas"
    state: present
    update: true
```

### Container with Resource Limits

```yaml
container_resources:
  cores: 4
  memory: 4096
  swap: 512
  disk_size: "20G"
  cpu_limit: 2        # CPU units
  cpu_shares: 1024    # CPU shares
  memory_shares: 1024 # Memory shares
```

## Migration Guide

### From Manual Container Creation

1. Document existing container settings: `pct config <vmid>`
2. Create inventory entries with matching settings
3. Use `state: present` for existing containers
4. Apply role to standardize configuration

### From Different Automation Tools

1. Export current container configurations
2. Map to role variables
3. Test in development environment
4. Deploy with proper validation

## License

Apache License 2.0 - See collection LICENSE file for details.
