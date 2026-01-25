# Proxmox VE Exporter Role

Deploys and configures Proxmox VE Exporter to expose Proxmox Virtual Environment metrics in Prometheus format, providing comprehensive monitoring of Proxmox hosts, virtual machines, LXC containers, and cluster resources.

## Features

- **Host Metrics** - CPU, memory, disk, and network statistics for Proxmox nodes
- **VM Monitoring** - Resource usage and status for all virtual machines
- **Container Tracking** - LXC container metrics and performance data
- **Cluster Information** - Cluster-wide resource allocation and health
- **Storage Metrics** - Storage pool usage and performance statistics
- **Node Status** - Node health, uptime, and cluster membership
- **Authentication Support** - API token and user/password authentication
- **Multi-Node Support** - Monitor multiple Proxmox nodes from single exporter
- **Prometheus Integration** - Native Prometheus scrape target format
- **Configurable Scraping** - Selective metric collection for performance

## Requirements

- Proxmox VE with LXC support (or dedicated monitoring VM)
- Ubuntu 22.04 LTS template
- Network access to Proxmox API (port 8006)
- Proxmox API token or user credentials with monitoring permissions
- Sufficient permissions to read cluster and node information

## Role Variables

### Version and Installation

```yaml
# PVE Exporter version
pve_exporter_version: "latest"

# Service port
pve_exporter_port: 9221

# User and group
pve_exporter_user: pve-exporter
pve_exporter_group: pve-exporter
```

### Directory Configuration

```yaml
# Installation paths
pve_exporter_config_dir: /etc/pve-exporter
pve_exporter_data_dir: /var/lib/pve-exporter
```

### Proxmox Connection

```yaml
# Proxmox API endpoints
pve_exporter_nodes:
  - name: pve-mac
    address: 192.168.0.56
    port: 8006

  - name: pve-nas
    address: 192.168.0.57
    port: 8006

# Authentication method (token or password)
pve_exporter_auth_method: token

# API Token authentication (recommended)
pve_exporter_api_user: "monitoring@pve"
pve_exporter_api_token_name: "prometheus"
pve_exporter_api_token: "{{ vault_pve_api_token }}"

# Password authentication (legacy)
pve_exporter_api_user: "monitoring@pve"
pve_exporter_api_password: "{{ vault_pve_api_password }}"
```

### SSL/TLS Configuration

```yaml
# Verify SSL certificates
pve_exporter_verify_ssl: false

# Custom CA certificate path
pve_exporter_ca_cert_file: "/etc/pve-exporter/ca.crt"
```

### Metric Collection

```yaml
# Collect VM metrics
pve_exporter_collect_vms: true

# Collect container metrics
pve_exporter_collect_containers: true

# Collect storage metrics
pve_exporter_collect_storage: true

# Collect cluster metrics
pve_exporter_collect_cluster: true

# Scrape interval (affects cache)
pve_exporter_scrape_interval: 15s
```

### Performance Settings

```yaml
# Maximum concurrent requests to Proxmox API
pve_exporter_max_concurrent_requests: 5

# Request timeout
pve_exporter_request_timeout: 10s

# Cache duration
pve_exporter_cache_duration: 15s
```

## Usage

### Basic Deployment

```yaml
- hosts: proxmox_hosts
  roles:
    - homelab.proxmox_lxc.pve_exporter
```

### With API Token Authentication

```yaml
- hosts: proxmox_hosts
  vars:
    pve_exporter_nodes:
      - name: pve-mac
        address: 192.168.0.56

    pve_exporter_auth_method: token
    pve_exporter_api_user: "monitoring@pve"
    pve_exporter_api_token_name: "prometheus"
    pve_exporter_api_token: "{{ vault_pve_api_token }}"
  roles:
    - homelab.proxmox_lxc.pve_exporter
```

### Multi-Node Monitoring

```yaml
- hosts: monitoring_servers
  vars:
    pve_exporter_nodes:
      - name: pve-mac
        address: 192.168.0.56
        port: 8006

      - name: pve-nas
        address: 192.168.0.57
        port: 8006

      - name: pve-prod
        address: 192.168.1.10
        port: 8006

    pve_exporter_verify_ssl: true
    pve_exporter_ca_cert_file: "/etc/pve-exporter/proxmox-ca.crt"
  roles:
    - homelab.proxmox_lxc.pve_exporter
```

### Selective Metric Collection

```yaml
- hosts: proxmox_hosts
  vars:
    # Only collect VM and container metrics
    pve_exporter_collect_vms: true
    pve_exporter_collect_containers: true
    pve_exporter_collect_storage: false
    pve_exporter_collect_cluster: false

    # Reduce scrape frequency
    pve_exporter_scrape_interval: 30s
  roles:
    - homelab.proxmox_lxc.pve_exporter
```

## Configuration

### PVE Exporter Configuration File

The role creates `/etc/pve-exporter/pve.yml`:

```yaml
default:
  user: {{ pve_exporter_api_user }}
  token_name: {{ pve_exporter_api_token_name }}
  token_value: {{ pve_exporter_api_token }}
  verify_ssl: {{ pve_exporter_verify_ssl }}

nodes:
  {% for node in pve_exporter_nodes %}
  - name: {{ node.name }}
    address: {{ node.address }}
    port: {{ node.port | default(8006) }}
  {% endfor %}
```

### Creating Proxmox API Token

```bash
# On Proxmox node, create monitoring user
pveum user add monitoring@pve --comment "Prometheus monitoring user"

# Create API token
pveum user token add monitoring@pve prometheus --privsep 0

# Grant permissions
pveum acl modify / -user monitoring@pve -role PVEAuditor

# Alternative: Grant specific permissions
pveum acl modify / -user monitoring@pve -role PVEAuditor
pveum acl modify /nodes -user monitoring@pve -role PVEAuditor
pveum acl modify /vms -user monitoring@pve -role PVEAuditor
pveum acl modify /storage -user monitoring@pve -role PVEAuditor
```

## Files and Templates

### Configuration Files

- **pve.yml.j2** - PVE Exporter configuration template
- **pve-exporter.service.j2** - Systemd service unit file

### Directory Structure

```
/etc/pve-exporter/
├── pve.yml                 # Main configuration
└── ca.crt                  # CA certificate (if SSL verification enabled)

/var/lib/pve-exporter/      # Data directory

/usr/local/bin/
└── pve-exporter            # Exporter binary (or Docker container)
```

## Dependencies

- homelab.common.container_base (recommended)
- homelab.common.security_hardening (recommended)

## Handlers

- `restart pve-exporter` - Restart PVE Exporter service after configuration changes

## Examples

### Complete Monitoring Setup

```yaml
- name: Deploy PVE Exporter for Proxmox monitoring
  hosts: monitoring_servers
  vars:
    pve_exporter_nodes:
      - name: pve-mac
        address: 192.168.0.56

      - name: pve-nas
        address: 192.168.0.57

    pve_exporter_auth_method: token
    pve_exporter_api_user: "monitoring@pve"
    pve_exporter_api_token_name: "prometheus"
    pve_exporter_api_token: "{{ vault_pve_api_token }}"

    pve_exporter_verify_ssl: false
    pve_exporter_collect_vms: true
    pve_exporter_collect_containers: true
    pve_exporter_collect_storage: true
    pve_exporter_collect_cluster: true

  roles:
    - homelab.proxmox_lxc.pve_exporter

  post_tasks:
    - name: Configure Prometheus scrape job
      ansible.builtin.blockinfile:
        path: /etc/prometheus/prometheus.yml
        block: |
          - job_name: 'proxmox'
            static_configs:
              - targets:
                  - '192.168.0.207:9221'
                  - '192.168.0.240:9221'
                labels:
                  cluster: homelab
        marker: "# {mark} ANSIBLE MANAGED - PVE Exporter"
      notify: restart prometheus
```

### Docker-Based Deployment

```yaml
- name: Deploy PVE Exporter using Docker
  hosts: monitoring_servers
  tasks:
    - name: Create pve-exporter configuration directory
      ansible.builtin.file:
        path: /etc/pve-exporter
        state: directory
        mode: "0755"

    - name: Create PVE Exporter configuration
      ansible.builtin.template:
        src: pve.yml.j2
        dest: /etc/pve-exporter/pve.yml
        mode: "0600"

    - name: Deploy PVE Exporter container
      community.docker.docker_container:
        name: pve-exporter
        image: prompve/prometheus-pve-exporter:latest
        state: started
        restart_policy: unless-stopped
        ports:
          - "9221:9221"
        volumes:
          - /etc/pve-exporter/pve.yml:/etc/pve.yml:ro
        env:
          PVE_VERIFY_SSL: "false"
```

## Troubleshooting

### Check Service Status

```bash
# Check if PVE Exporter is running
pct exec 207 -- systemctl status pve-exporter

# View logs
pct exec 207 -- journalctl -u pve-exporter -f

# Check process
pct exec 207 -- ps aux | grep pve-exporter
```

### Test Proxmox API Access

```bash
# Test API connectivity
curl -k https://192.168.0.56:8006/api2/json/version

# Test with API token
curl -k -H "Authorization: PVEAPIToken=monitoring@pve!prometheus=<token>" \
  https://192.168.0.56:8006/api2/json/cluster/resources

# Check permissions
curl -k -H "Authorization: PVEAPIToken=monitoring@pve!prometheus=<token>" \
  https://192.168.0.56:8006/api2/json/access/permissions
```

### Validate Metrics Export

```bash
# Check if exporter is responding
curl -s http://192.168.0.207:9221/metrics

# Check specific metrics
curl -s http://192.168.0.207:9221/metrics | grep pve_

# Count available metrics
curl -s http://192.168.0.207:9221/metrics | grep "^pve_" | wc -l

# Check node metrics
curl -s http://192.168.0.207:9221/metrics | grep pve_node_
```

### Common Metrics

```bash
# Node CPU usage
curl -s http://192.168.0.207:9221/metrics | grep pve_cpu_usage_ratio

# Node memory
curl -s http://192.168.0.207:9221/metrics | grep pve_memory_

# VM status
curl -s http://192.168.0.207:9221/metrics | grep pve_vm_status

# Container status
curl -s http://192.168.0.207:9221/metrics | grep pve_lxc_status

# Storage usage
curl -s http://192.168.0.207:9221/metrics | grep pve_storage_
```

### Authentication Issues

```bash
# Verify API token is valid
pveum user token list monitoring@pve

# Check user permissions
pveum user permissions monitoring@pve

# Test token from exporter host
pct exec 207 -- curl -k \
  -H "Authorization: PVEAPIToken=monitoring@pve!prometheus=<token>" \
  https://192.168.0.56:8006/api2/json/nodes
```

### Performance Issues

```bash
# Monitor exporter resource usage
pct exec 207 -- htop

# Check API request latency
curl -w "@-" -o /dev/null -s http://192.168.0.207:9221/metrics <<'EOF'
    time_namelookup:  %{time_namelookup}\n
       time_connect:  %{time_connect}\n
    time_appconnect:  %{time_appconnect}\n
      time_redirect:  %{time_redirect}\n
   time_pretransfer:  %{time_pretransfer}\n
 time_starttransfer:  %{time_starttransfer}\n
                    ----------\n
         time_total:  %{time_total}\n
EOF

# Check exporter metrics
curl -s http://192.168.0.207:9221/metrics | grep pve_exporter_
```

## Security Considerations

- **API Tokens** - Use API tokens instead of password authentication
- **Minimal Permissions** - Grant only PVEAuditor role (read-only)
- **SSL Verification** - Enable SSL verification in production
- **Network Access** - Restrict exporter port (9221) to Prometheus
- **Token Protection** - Store tokens in Ansible Vault
- **Dedicated User** - Create dedicated monitoring user in Proxmox
- **Firewall Rules** - Allow only necessary API access

## Performance Tuning

### Resource Allocation

```yaml
# For small homelab (2-3 Proxmox nodes)
pve_exporter_resources:
  memory: 256   # MB
  cores: 1
  disk_size: "5"

# For larger deployment (4+ nodes with many VMs)
pve_exporter_resources:
  memory: 512   # MB
  cores: 2
  disk_size: "10"
```

### Optimize Scraping

```yaml
# Reduce scrape frequency for large deployments
pve_exporter_scrape_interval: 30s
pve_exporter_cache_duration: 30s

# Limit concurrent requests
pve_exporter_max_concurrent_requests: 3

# Disable unused collectors
pve_exporter_collect_storage: false
```

## Integration with Other Services

### Prometheus Integration

Configure Prometheus to scrape PVE Exporter:

```yaml
# In Prometheus configuration
scrape_configs:
  - job_name: 'proxmox'
    static_configs:
      - targets:
          - '192.168.0.207:9221'
          - '192.168.0.240:9221'
        labels:
          cluster: homelab
          environment: production
    scrape_interval: 30s
    scrape_timeout: 10s
```

### Grafana Dashboards

Import Proxmox dashboards from grafana.com:
- **10347** - Proxmox VE Cluster
- **12633** - Proxmox via Prometheus
- **10048** - Proxmox Backup Server

### AlertManager Rules

```yaml
# Prometheus alert rules for Proxmox
groups:
  - name: proxmox
    rules:
      - alert: ProxmoxNodeDown
        expr: pve_node_status == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Proxmox node {{ $labels.node }} is down"

      - alert: ProxmoxHighMemory
        expr: pve_memory_usage_ratio > 0.9
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.node }}"

      - alert: ProxmoxVMDown
        expr: pve_vm_status == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "VM {{ $labels.name }} is down on {{ $labels.node }}"
```

## Available Metrics

### Node Metrics
- `pve_node_status` - Node online status (1=online, 0=offline)
- `pve_cpu_usage_ratio` - CPU usage ratio (0-1)
- `pve_memory_usage_bytes` - Memory usage in bytes
- `pve_memory_total_bytes` - Total memory in bytes
- `pve_memory_usage_ratio` - Memory usage ratio (0-1)
- `pve_disk_usage_bytes` - Disk usage in bytes
- `pve_disk_total_bytes` - Total disk in bytes
- `pve_uptime_seconds` - Node uptime in seconds

### VM Metrics
- `pve_vm_status` - VM status (1=running, 0=stopped)
- `pve_vm_cpu_usage` - VM CPU usage
- `pve_vm_memory_usage_bytes` - VM memory usage
- `pve_vm_disk_read_bytes_total` - VM disk read bytes
- `pve_vm_disk_write_bytes_total` - VM disk write bytes
- `pve_vm_network_receive_bytes_total` - VM network receive bytes
- `pve_vm_network_transmit_bytes_total` - VM network transmit bytes

### Container Metrics
- `pve_lxc_status` - Container status
- `pve_lxc_cpu_usage` - Container CPU usage
- `pve_lxc_memory_usage_bytes` - Container memory usage
- `pve_lxc_disk_usage_bytes` - Container disk usage

### Storage Metrics
- `pve_storage_size_bytes` - Storage total size
- `pve_storage_used_bytes` - Storage used space
- `pve_storage_available_bytes` - Storage available space

## Useful PromQL Queries

```promql
# Node CPU usage percentage
pve_cpu_usage_ratio * 100

# Node memory usage percentage
pve_memory_usage_ratio * 100

# Total VMs running
count(pve_vm_status == 1)

# Storage usage percentage
(pve_storage_used_bytes / pve_storage_size_bytes) * 100

# VMs grouped by node
count by (node) (pve_vm_status == 1)

# Network traffic rate
rate(pve_vm_network_receive_bytes_total[5m])
```

## License

MIT License - See collection LICENSE file for details.
