# LXC Container Role

Creates and manages LXC containers in Proxmox VE with secure API token authentication, comprehensive resource allocation, and automated networking configuration.

## Features

- **Secure API Authentication** - Uses Proxmox API tokens for secure container management
- **Automatic Container Creation** - Idempotent container provisioning with retry logic
- **Resource Management** - Configurable CPU cores, memory, swap, and disk allocation
- **Network Configuration** - Flexible network setup with static or DHCP addressing
- **SSH Key Injection** - Automated SSH public key deployment for secure access
- **Container Auto-start** - Configurable automatic startup on Proxmox host boot
- **Unprivileged Containers** - Security-first approach with unprivileged containers by default
- **Inventory Integration** - Automatic addition to Ansible inventory after creation
- **Health Verification** - Wait for SSH availability before proceeding

## Requirements

- Proxmox VE 7.0 or higher
- LXC template available in Proxmox storage
- Valid Proxmox API token with appropriate permissions
- Network connectivity to Proxmox host
- homelab.common collection installed

## Role Variables

### Required Variables

```yaml
# Container identification
container_id: 100                    # Proxmox VMID
container_hostname: "myapp"          # Container hostname
container_ip: "192.168.0.100"        # Container IP address

# Proxmox node configuration
proxmox_node: "pve-mac"             # Proxmox node name
```

### Container Resource Allocation

```yaml
# Resource settings (defaults shown)
container_disk_size: 8               # Disk size in GB
container_cores: 1                   # CPU cores
container_memory: 512                # Memory in MB
container_swap: 0                    # Swap in MB
container_onboot: true               # Start on boot
container_unprivileged: true         # Use unprivileged container
```

### Container Template Configuration

```yaml
# Template configuration
container_template_name: "ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
container_template: "local:vztmpl/{{ container_template_name }}"
```

### Network Configuration

```yaml
# Default network configuration (DHCP)
container_network_config:
  net0: "name=eth0,bridge=vmbr0,ip=dhcp"

# Static IP configuration example
container_network_config:
  net0: "name=eth0,bridge=vmbr0,ip=192.168.0.100/24,gw=192.168.0.1,type=veth"
```

### SSH and Authentication

```yaml
# SSH public key for container access
container_ssh_key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
container_ssh_private_key: "~/.ssh/id_rsa"
```

### Inventory Configuration

```yaml
# Ansible inventory groups
container_groups:
  - lxc_containers
  - monitoring  # Optional additional groups
```

### Proxmox API Configuration

```yaml
# API authentication (from proxmox_config)
proxmox_config:
  pve-mac:
    host: "192.168.0.56"
    api_token_id: "ansible@pam!ansible"
    api_token_secret: "{{ vault_proxmox_api_token }}"
    validate_certs: false

# API retry settings
proxmox_api_defaults:
  timeout: 300
  retry_count: 3
  retry_delay: 5
```

## Usage

### Basic Container Creation

```yaml
- name: Create basic LXC container
  hosts: proxmox_hosts
  vars:
    container_id: 100
    container_hostname: "test-container"
    container_ip: "192.168.0.100"
    proxmox_node: "pve-mac"
  roles:
    - homelab.proxmox_lxc.lxc_container
```

### Container with Custom Resources

```yaml
- name: Create high-resource container
  hosts: proxmox_hosts
  vars:
    container_id: 200
    container_hostname: "database"
    container_ip: "192.168.0.200"
    proxmox_node: "pve-nas"
    container_cores: 4
    container_memory: 4096
    container_disk_size: 50
    container_swap: 2048
  roles:
    - homelab.proxmox_lxc.lxc_container
```

### Container with Static Network

```yaml
- name: Create container with static networking
  hosts: proxmox_hosts
  vars:
    container_id: 150
    container_hostname: "webserver"
    container_ip: "192.168.0.150"
    proxmox_node: "pve-mac"
    container_network_config:
      net0: "name=eth0,bridge=vmbr0,ip=192.168.0.150/24,gw=192.168.0.1,type=veth"
  roles:
    - homelab.proxmox_lxc.lxc_container
```

### Multiple Containers in Parallel

```yaml
- name: Create multiple containers
  hosts: proxmox_hosts
  tasks:
    - name: Create monitoring stack containers
      include_role:
        name: homelab.proxmox_lxc.lxc_container
      vars:
        container_id: "{{ item.id }}"
        container_hostname: "{{ item.hostname }}"
        container_ip: "{{ item.ip }}"
        proxmox_node: "pve-mac"
        container_cores: "{{ item.cores | default(2) }}"
        container_memory: "{{ item.memory | default(1024) }}"
      loop:
        - { id: 200, hostname: "prometheus", ip: "192.168.0.200", cores: 2, memory: 2048 }
        - { id: 201, hostname: "grafana", ip: "192.168.0.201" }
        - { id: 202, hostname: "unbound", ip: "192.168.0.202" }
```

## Container Templates

Supported Ubuntu LXC templates:

- **ubuntu-22.04-standard** - Ubuntu 22.04 LTS (recommended)
- **ubuntu-20.04-standard** - Ubuntu 20.04 LTS
- **ubuntu-24.04-standard** - Ubuntu 24.04 LTS

Use the `homelab.proxmox_lxc.lxc_template` role to download templates before creating containers.

## Dependencies

This role requires:

- community.general collection (for proxmox module)
- homelab.common collection (for Proxmox API validation)

## Tasks Overview

The role performs the following operations:

1. **API Validation** - Validates Proxmox API connectivity and authentication
2. **Container Creation** - Creates LXC container with specified configuration
3. **Container Start** - Starts the container if newly created
4. **SSH Wait** - Waits for SSH service to become available
5. **Inventory Registration** - Adds container to Ansible inventory

## Handlers

This role does not define handlers. Container state changes are handled inline.

## Examples

### Complete Service Deployment

```yaml
- name: Deploy Prometheus monitoring service
  hosts: proxmox_hosts
  vars:
    # Container settings
    container_id: 200
    container_hostname: "prometheus"
    container_ip: "192.168.0.200"
    proxmox_node: "pve-mac"

    # Resource allocation
    container_cores: 2
    container_memory: 2048
    container_disk_size: 20

    # Network configuration
    container_network_config:
      net0: "name=eth0,bridge=vmbr0,ip=192.168.0.200/24,gw=192.168.0.1,type=veth"

    # Inventory groups
    container_groups:
      - lxc_containers
      - monitoring
      - prometheus_servers

  roles:
    - homelab.proxmox_lxc.lxc_container

  post_tasks:
    - name: Configure Prometheus
      include_role:
        name: homelab.proxmox_lxc.prometheus
```

### Development Container

```yaml
- name: Create development container
  hosts: proxmox_hosts
  vars:
    container_id: 999
    container_hostname: "dev-sandbox"
    container_ip: "192.168.0.250"
    proxmox_node: "pve-mac"
    container_onboot: false
    container_template_name: "ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  roles:
    - homelab.proxmox_lxc.lxc_container
```

## Troubleshooting

### Container Creation Fails

```bash
# Check Proxmox API connectivity
curl -k "https://192.168.0.56:8006/api2/json/version" \
  -H "Authorization: PVEAPIToken=ansible@pam!ansible=secret-token"

# Verify template exists
pvesm list local | grep vztmpl

# Check available resources
pvesh get /nodes/pve-mac/status
```

### Container Won't Start

```bash
# Check container status
pct status 100

# View container logs
pct console 100

# Check Proxmox logs
journalctl -u pve-container@100 -f
```

### SSH Connection Issues

```bash
# Test SSH connectivity
ssh -v root@192.168.0.100

# Check container network configuration
pct config 100 | grep net

# Verify firewall rules
pct exec 100 -- ufw status
```

### Resource Allocation Problems

```bash
# Check Proxmox node resources
pvesh get /nodes/pve-mac/status

# View container resource usage
pct exec 100 -- top

# Check disk usage
pct exec 100 -- df -h
```

## Security Considerations

- **Unprivileged Containers** - Always use unprivileged containers unless specifically required
- **API Token Security** - Store API tokens in Ansible Vault, never in plain text
- **SSH Key Management** - Use unique SSH keys per environment
- **Network Isolation** - Configure appropriate network segmentation
- **Resource Limits** - Set reasonable resource limits to prevent resource exhaustion
- **Certificate Validation** - Enable validate_certs in production environments

## Performance Tuning

- **CPU Allocation** - Allocate cores based on workload requirements
- **Memory Sizing** - Monitor and adjust based on actual usage
- **Swap Configuration** - Generally keep swap at 0 for containers
- **Disk Performance** - Use appropriate storage backend (SSD vs HDD)
- **Network Bandwidth** - Consider network rate limiting for high-traffic containers

## Integration with Other Roles

This role is typically used in combination with:

- **lxc_template** - Download container templates before creation
- **container_base** - Apply base container configuration
- **security_hardening** - Harden container security
- **Service roles** - Deploy specific applications (Prometheus, Grafana, etc.)

## License

Apache License 2.0 - See collection LICENSE file for details.
