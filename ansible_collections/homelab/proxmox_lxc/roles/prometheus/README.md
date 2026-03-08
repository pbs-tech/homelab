# Prometheus Role

Deploys and configures Prometheus as a metrics collection and monitoring system in an LXC container, providing comprehensive infrastructure and service monitoring for the homelab environment.

## Features

- **Multi-Target Scraping** - Automatic discovery and monitoring of K3s nodes, LXC containers, and exporters
- **Long-term Storage** - Configurable data retention with efficient time-series database
- **Query Language** - Powerful PromQL for metrics analysis and alerting
- **Service Discovery** - Support for static and dynamic service discovery
- **Federation Support** - Multi-cluster metrics aggregation capability
- **Alerting Integration** - Native integration with AlertManager for alert routing
- **API Access** - RESTful API for programmatic access to metrics
- **High Performance** - Optimized for homelab scale with configurable resource allocation

## Requirements

- Proxmox VE with LXC support
- Ubuntu 22.04 LTS template
- Network access to monitored targets (K3s nodes, exporters, services)
- Sufficient storage for metrics retention
- Time synchronization across monitored hosts

## Role Variables

### Version and Installation

```yaml
# Prometheus version to install
prometheus_version: 2.48.0

# Installation paths
prometheus_bin_dir: /usr/local/bin
prometheus_config_dir: /etc/prometheus
prometheus_data_dir: /var/lib/prometheus
```

### Network Configuration

```yaml
# Service port
prometheus_port: 9090

# Network binding
prometheus_listen_address: "0.0.0.0:{{ prometheus_port }}"

# Firewall configuration (opens port via UFW)
prometheus_configure_firewall: true
```

### Data Retention

```yaml
# Data retention period
prometheus_data_retention: 15d

# Storage size (ensure adequate disk space)
prometheus_storage_retention_size: "10GB"
```

### Scrape Configuration

```yaml
# Global scrape interval
prometheus_scrape_interval: 15s

# Global evaluation interval for rules
prometheus_evaluation_interval: 15s

# Scrape timeout
prometheus_scrape_timeout: 10s
```

### Target Configuration

```yaml
# K3s cluster nodes for monitoring
k3s_nodes:
  - { name: "k3s-1", ip: "192.168.0.111" }
  - { name: "k3s-2", ip: "192.168.0.112" }
  - { name: "k3s-3", ip: "192.168.0.113" }
  - { name: "k3s-4", ip: "192.168.0.114" }

# Bastion host
k3s_bastion_ip: 192.168.0.110

# Additional scrape targets
prometheus_scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets:
          - '192.168.0.111:9100'
          - '192.168.0.112:9100'
          - '192.168.0.113:9100'
          - '192.168.0.114:9100'
```

### Dynamic LXC Container Scraping

The role includes a `lxc-containers` scrape job that is dynamically generated from the Ansible
`lxc_containers` inventory group at deploy time. Each LXC container is added as a target using
`{{ host }}.{{ homelab_domain }}:9100`. New containers are automatically included on the next
deploy — no manual target configuration is required.

### Proxmox NAS Exporter

A `proxmox-pve-nas` scrape job targets the PVE exporter for the NAS Proxmox host at
`pve-exporter-nas.{{ homelab_domain }}:9221`, enabling Proxmox NAS node metrics alongside the
existing `proxmox-pve-mac` job.

### AlertManager Integration

```yaml
# AlertManager endpoints
prometheus_alertmanager_urls:
  - "http://192.168.0.206:9093"

# Alert rule files
prometheus_rule_files:
  - "/etc/prometheus/rules/*.yml"
```

### Performance Tuning

```yaml
# Query concurrency
prometheus_query_max_concurrency: 20

# Maximum samples per query
prometheus_query_max_samples: 50000000

# Query timeout
prometheus_query_timeout: 2m
```

## Usage

### Basic Deployment

```yaml
- hosts: proxmox_hosts
  roles:
    - homelab.proxmox_lxc.prometheus
```

### With Custom Retention

```yaml
- hosts: proxmox_hosts
  vars:
    prometheus_data_retention: 30d
    prometheus_storage_retention_size: "20GB"
  roles:
    - homelab.proxmox_lxc.prometheus
```

### With Additional Scrape Targets

```yaml
- hosts: proxmox_hosts
  vars:
    prometheus_scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      - job_name: 'pve-exporter'
        static_configs:
          - targets:
              - '192.168.0.207:9221'
              - '192.168.0.240:9221'

      - job_name: 'grafana'
        static_configs:
          - targets: ['192.168.0.201:3000']
  roles:
    - homelab.proxmox_lxc.prometheus
```

### With Federation

```yaml
- hosts: proxmox_hosts
  vars:
    prometheus_scrape_configs:
      - job_name: 'federate'
        scrape_interval: 15s
        honor_labels: true
        metrics_path: '/federate'
        params:
          'match[]':
            - '{job="prometheus"}'
            - '{__name__=~"job:.*"}'
        static_configs:
          - targets:
              - 'prometheus-remote:9090'
  roles:
    - homelab.proxmox_lxc.prometheus
```

## Service Configuration

### Monitoring K3s Cluster

Prometheus automatically monitors K3s nodes when configured:

```yaml
k3s_nodes:
  - { name: "k3s-master", ip: "192.168.0.111" }
  - { name: "k3s-worker-1", ip: "192.168.0.112" }
  - { name: "k3s-worker-2", ip: "192.168.0.113" }
  - { name: "k3s-worker-3", ip: "192.168.0.114" }
```

Prometheus will scrape:
- Node Exporter metrics (9100)
- Kubelet metrics (10250)
- K3s API server metrics (6443)

### Bundled Alert Rules

The role ships a pre-configured rule file at `files/rules/node.rules.yml` with two alert groups:

**`node` group** — host-level alerts:

| Alert | Condition |
|---|---|
| HostDown | Target unreachable for 2 minutes |
| HighCPUUsage | CPU idle < 10% for 10 minutes |
| HighMemoryUsage | Available memory < 10% for 5 minutes |
| DiskSpaceLow | Filesystem free space < 15% for 5 minutes |
| HighDiskIOSaturation | Disk I/O saturation > 95% for 5 minutes |

**`proxmox` group** — Proxmox node alerts:

| Alert | Condition |
|---|---|
| ProxmoxNodeDown | Proxmox PVE exporter target unreachable for 2 minutes |

### Custom Alert Rules

Create additional rule files in `/etc/prometheus/rules/`:

```yaml
# /etc/prometheus/rules/homelab.yml
groups:
  - name: homelab
    interval: 30s
    rules:
      - alert: HighMemoryUsage
        expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 90% for 5 minutes"

      - alert: ServiceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "{{ $labels.instance }} has been down for more than 2 minutes"
```

### Prometheus Configuration Template

The role creates `/etc/prometheus/prometheus.yml` with:

```yaml
global:
  scrape_interval: {{ prometheus_scrape_interval }}
  evaluation_interval: {{ prometheus_evaluation_interval }}

alerting:
  alertmanagers:
    - static_configs:
        - targets: {{ prometheus_alertmanager_urls | to_json }}

rule_files:
  {{ prometheus_rule_files | to_yaml | indent(2) }}

scrape_configs:
  {{ prometheus_scrape_configs | to_yaml | indent(2) }}
```

## Files and Templates

### Configuration Files

- **prometheus.yml.j2** - Main Prometheus configuration template
- **prometheus.service.j2** - Systemd service unit file

### Directory Structure

```text
/etc/prometheus/          # Configuration directory
├── prometheus.yml        # Main configuration
└── rules/               # Alert rules directory

/var/lib/prometheus/     # Data directory (TSDB)

/usr/local/bin/          # Binary installation
├── prometheus           # Main binary
└── promtool            # Configuration validation tool
```

## Dependencies

- homelab.common.container_base (recommended)
- homelab.common.security_hardening (recommended)

## Handlers

- `restart prometheus` - Restart Prometheus service after configuration changes
- `reload systemd` - Reload systemd daemon after service file changes

## Examples

### Complete Monitoring Stack

```yaml
- name: Deploy comprehensive Prometheus monitoring
  hosts: proxmox_hosts
  vars:
    prometheus_data_retention: 30d
    prometheus_storage_retention_size: "25GB"

    prometheus_scrape_configs:
      # Self-monitoring
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      # K3s cluster nodes
      - job_name: 'k3s-nodes'
        static_configs:
          - targets:
              - '192.168.0.111:9100'
              - '192.168.0.112:9100'
              - '192.168.0.113:9100'
              - '192.168.0.114:9100'
            labels:
              cluster: 'homelab-k3s'

      # Proxmox exporters
      - job_name: 'proxmox'
        static_configs:
          - targets:
              - '192.168.0.207:9221'
              - '192.168.0.240:9221'

      # LXC services
      - job_name: 'grafana'
        static_configs:
          - targets: ['192.168.0.201:3000']

      - job_name: 'loki'
        static_configs:
          - targets: ['192.168.0.210:3100']

      - job_name: 'alertmanager'
        static_configs:
          - targets: ['192.168.0.206:9093']

    prometheus_alertmanager_urls:
      - "http://192.168.0.206:9093"

    prometheus_rule_files:
      - "/etc/prometheus/rules/*.yml"

  roles:
    - homelab.proxmox_lxc.prometheus
```

### Development/Testing Configuration

```yaml
- name: Deploy Prometheus for testing
  hosts: proxmox_hosts
  vars:
    prometheus_data_retention: 7d
    prometheus_scrape_interval: 30s
    prometheus_evaluation_interval: 30s

    prometheus_scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

  roles:
    - homelab.proxmox_lxc.prometheus
```

## Troubleshooting

### Check Service Status

```bash
# Check if Prometheus is running
pct exec 200 -- systemctl status prometheus

# View logs
pct exec 200 -- journalctl -u prometheus -f

# Check Prometheus process
pct exec 200 -- ps aux | grep prometheus
```

### Validate Configuration

```bash
# Validate prometheus.yml syntax
pct exec 200 -- /usr/local/bin/promtool check config /etc/prometheus/prometheus.yml

# Check alert rules
pct exec 200 -- /usr/local/bin/promtool check rules /etc/prometheus/rules/*.yml
```

### Query Metrics

```bash
# Check targets status via API
curl -s http://192.168.0.200:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health, lastScrape: .lastScrape}'

# Check specific metric
curl -s 'http://192.168.0.200:9090/api/v1/query?query=up' | jq .

# Query range
curl -s 'http://192.168.0.200:9090/api/v1/query_range?query=node_memory_MemAvailable_bytes&start=2024-01-01T00:00:00Z&end=2024-01-01T01:00:00Z&step=15s'
```

### Scraping Issues

```bash
# Check network connectivity to target
pct exec 200 -- curl -s http://192.168.0.111:9100/metrics | head

# Check DNS resolution
pct exec 200 -- nslookup k3s-1

# Verify firewall rules
pct exec 200 -- ss -tuln | grep 9090

# Check target configuration in UI
# Navigate to: http://192.168.0.200:9090/targets
```

### Storage Issues

```bash
# Check disk usage
pct exec 200 -- df -h /var/lib/prometheus

# Check TSDB status
curl -s http://192.168.0.200:9090/api/v1/status/tsdb | jq .

# View data directory size
pct exec 200 -- du -sh /var/lib/prometheus/*
```

### Performance Issues

```bash
# Monitor resource usage
pct exec 200 -- htop

# Check query performance
curl -s 'http://192.168.0.200:9090/api/v1/status/runtimeinfo' | jq .

# View metrics about Prometheus itself
curl -s http://192.168.0.200:9090/metrics | grep prometheus_
```

## Security Considerations

- **UFW Firewall** - Automatically opens port 9090 via UFW (controlled by `prometheus_configure_firewall`)
- **Authentication** - Use Traefik for external access with authentication
- **TLS Encryption** - Enable HTTPS through reverse proxy (Traefik)
- **Data Protection** - Secure metrics data directory permissions (700)
- **API Security** - Limit API access to trusted networks
- **Alert Confidentiality** - Secure AlertManager communication channels

## Performance Tuning

### Resource Allocation

```yaml
# For small homelab (< 20 targets)
prometheus_resources:
  memory: 2048  # 2GB RAM
  cores: 2
  disk_size: "20"

# For medium homelab (20-50 targets)
prometheus_resources:
  memory: 4096  # 4GB RAM
  cores: 4
  disk_size: "50"
```

### Query Optimization

- Use recording rules for frequently queried expressions
- Limit query range and resolution for dashboards
- Configure appropriate `scrape_interval` based on needs
- Use label filtering to reduce cardinality

### Storage Optimization

- Adjust retention period based on available disk space
- Enable compaction for older data blocks
- Monitor TSDB head chunks and compaction status
- Consider remote write for long-term storage

## Integration with Other Services

### Grafana

Prometheus automatically integrates with Grafana when configured as a datasource:

```yaml
# In Grafana configuration
grafana_datasources:
  - name: Prometheus
    type: prometheus
    url: http://192.168.0.200:9090
    is_default: true
```

### AlertManager

Route alerts to AlertManager for notification handling:

```yaml
prometheus_alertmanager_urls:
  - "http://192.168.0.206:9093"
```

### Traefik

Expose Prometheus UI through Traefik reverse proxy with authentication:

```yaml
# Traefik labels for Prometheus
traefik_labels:
  - "traefik.enable=true"
  - "traefik.http.routers.prometheus.rule=Host(`prometheus.homelab.local`)"
  - "traefik.http.routers.prometheus.tls=true"
  - "traefik.http.services.prometheus.loadbalancer.server.port=9090"
```

## Useful PromQL Queries

```promql
# CPU usage per node
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage percentage
100 - ((node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100)

# Disk usage
100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)

# Network traffic
rate(node_network_receive_bytes_total[5m])

# Service uptime
(time() - process_start_time_seconds) / 3600
```

## License

MIT License - See collection LICENSE file for details.
