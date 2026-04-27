# Promtail Role

Deploys and configures Promtail as a log shipping agent that collects, labels, and forwards logs to Grafana Loki, providing comprehensive log collection from system logs, application logs, and journal entries.

## Features

- **Multi-Source Collection** - Collects logs from files, systemd journal, and syslog
- **Automatic Labeling** - Enriches logs with metadata and custom labels
- **Pipeline Processing** - Transform and filter logs before shipping
- **Service Discovery** - Automatic discovery of log sources
- **Position Tracking** - Remembers log position to avoid duplicates
- **Low Resource Usage** - Optimized for minimal CPU and memory footprint
- **Reliable Delivery** - Buffering and retry mechanisms for log delivery
- **Multiple Outputs** - Ship logs to multiple Loki instances
- **Metrics Exposure** - Prometheus metrics for monitoring

## Requirements

- Proxmox VE with LXC support or bare metal/VM
- Ubuntu 22.04 LTS (or compatible Linux distribution)
- Network access to Loki instance
- Read access to log files (adm and systemd-journal groups)
- Sufficient disk space for position tracking

## Role Variables

### Version and Installation

```yaml
# Promtail version to install
promtail_version: 2.9.2

# User and group
promtail_user: promtail
promtail_group: promtail
```

### Directory Configuration

```yaml
# Installation paths
promtail_bin_dir: /usr/local/bin
promtail_config_dir: /etc/promtail
promtail_data_dir: /var/lib/promtail
promtail_log_dir: /var/log/promtail
```

### Server Configuration

```yaml
# Server ports
promtail_listen_address: 0.0.0.0
promtail_listen_port: 9080
promtail_grpc_listen_port: 9081
```

### Loki Endpoint

```yaml
# Loki server to send logs to
loki_endpoint: http://192.168.0.210:3100

# Multiple Loki endpoints for HA
loki_endpoints:
  - url: http://192.168.0.210:3100
  - url: http://192.168.0.211:3100
```

### Position Tracking

```yaml
# Position file for tracking log positions
promtail_positions_file: "{{ promtail_data_dir }}/positions.yaml"

# Position sync period
promtail_positions_sync_period: 10s
```

### Service Identification

```yaml
# Labels applied to all logs
promtail_service_name: "{{ inventory_hostname }}"
promtail_environment: homelab
promtail_instance: "{{ ansible_default_ipv4.address }}"
```

### Scrape Configuration

```yaml
# Log scraping configuration
promtail_scrape_configs:
  # System logs
  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          service: "{{ promtail_service_name }}"
          environment: "{{ promtail_environment }}"
          __path__: /var/log/syslog

  # Authentication logs
  - job_name: auth
    static_configs:
      - targets:
          - localhost
        labels:
          job: auth
          service: "{{ promtail_service_name }}"
          environment: "{{ promtail_environment }}"
          __path__: /var/log/auth.log

  # Daemon logs
  - job_name: daemon
    static_configs:
      - targets:
          - localhost
        labels:
          job: daemon
          service: "{{ promtail_service_name }}"
          environment: "{{ promtail_environment }}"
          __path__: /var/log/daemon.log

  # Systemd journal
  - job_name: journal
    journal:
      max_age: 12h
      labels:
        job: systemd-journal
        service: "{{ promtail_service_name }}"
        environment: "{{ promtail_environment }}"
```

## Usage

### Basic Deployment

```yaml
- hosts: all_servers
  roles:
    - homelab.proxmox_lxc.promtail
```

### With Custom Loki Endpoint

```yaml
- hosts: all_servers
  vars:
    loki_endpoint: http://loki.homelab.lan:3100
  roles:
    - homelab.proxmox_lxc.promtail
```

### With Additional Log Sources

```yaml
- hosts: web_servers
  vars:
    promtail_scrape_configs:
      - job_name: syslog
        static_configs:
          - targets: [localhost]
            labels:
              job: syslog
              service: "{{ inventory_hostname }}"
              __path__: /var/log/syslog

      - job_name: nginx
        static_configs:
          - targets: [localhost]
            labels:
              job: nginx
              service: nginx
              __path__: /var/log/nginx/*.log

      - job_name: application
        static_configs:
          - targets: [localhost]
            labels:
              job: app
              app: webapp
              __path__: /var/log/webapp/*.log
  roles:
    - homelab.proxmox_lxc.promtail
```

### With Pipeline Processing

```yaml
- hosts: application_servers
  vars:
    promtail_scrape_configs:
      - job_name: json-logs
        static_configs:
          - targets: [localhost]
            labels:
              job: app
              __path__: /var/log/app/*.json
        pipeline_stages:
          - json:
              expressions:
                level: level
                message: message
                timestamp: timestamp
          - labels:
              level:
          - timestamp:
              source: timestamp
              format: RFC3339
  roles:
    - homelab.proxmox_lxc.promtail
```

## Configuration

### Promtail Configuration File

The role creates `/etc/promtail/promtail.yml` with:

```yaml
server:
  http_listen_address: {{ promtail_listen_address }}
  http_listen_port: {{ promtail_listen_port }}
  grpc_listen_port: {{ promtail_grpc_listen_port }}

positions:
  filename: {{ promtail_positions_file }}
  sync_period: {{ promtail_positions_sync_period }}

clients:
  - url: {{ loki_endpoint }}/loki/api/v1/push

scrape_configs:
  {{ promtail_scrape_configs | to_yaml | indent(2) }}
```

### Pipeline Stages

Common pipeline transformations:

```yaml
# JSON parsing
pipeline_stages:
  - json:
      expressions:
        level: level
        message: msg
        timestamp: ts

# Regular expression extraction
pipeline_stages:
  - regex:
      expression: '^(?P<timestamp>\S+) (?P<level>\S+) (?P<message>.*)$'
  - labels:
      level:
  - timestamp:
      source: timestamp
      format: "2006-01-02 15:04:05"

# Drop logs matching pattern
pipeline_stages:
  - match:
      selector: '{job="syslog"}'
      stages:
        - drop:
            expression: ".*debug.*"

# Add static labels
pipeline_stages:
  - static_labels:
      cluster: homelab
      region: us-east
```

## Files and Templates

### Configuration Files

- **promtail.yml.j2** - Main Promtail configuration template
- **promtail.service.j2** - Systemd service unit file

### Directory Structure

```
/etc/promtail/
└── promtail.yml            # Main configuration

/var/lib/promtail/
└── positions.yaml          # Log position tracking

/usr/local/bin/
└── promtail                # Promtail binary

/var/log/promtail/         # Log files (if file logging enabled)
```

## Dependencies

- homelab.common.container_base (recommended)
- homelab.common.security_hardening (recommended)

## Handlers

- `reload systemd` - Reload systemd daemon after service file changes
- `restart promtail` - Restart Promtail service after configuration changes

## Examples

### Complete Log Collection Setup

```yaml
- name: Deploy Promtail on all hosts
  hosts: all
  vars:
    loki_endpoint: http://192.168.0.210:3100

    promtail_scrape_configs:
      # System logs
      - job_name: syslog
        static_configs:
          - targets: [localhost]
            labels:
              job: syslog
              host: "{{ inventory_hostname }}"
              environment: production
              __path__: /var/log/syslog

      # Auth logs
      - job_name: auth
        static_configs:
          - targets: [localhost]
            labels:
              job: auth
              host: "{{ inventory_hostname }}"
              __path__: /var/log/auth.log

      # Systemd journal
      - job_name: journal
        journal:
          max_age: 12h
          labels:
            job: systemd-journal
            host: "{{ inventory_hostname }}"

      # Kernel logs
      - job_name: kernel
        static_configs:
          - targets: [localhost]
            labels:
              job: kernel
              host: "{{ inventory_hostname }}"
              __path__: /var/log/kern.log

  roles:
    - homelab.proxmox_lxc.promtail
```

### Application-Specific Configuration

```yaml
- name: Deploy Promtail for web servers
  hosts: web_servers
  vars:
    promtail_scrape_configs:
      # Nginx access logs
      - job_name: nginx-access
        static_configs:
          - targets: [localhost]
            labels:
              job: nginx
              log_type: access
              __path__: /var/log/nginx/access.log

      # Nginx error logs
      - job_name: nginx-error
        static_configs:
          - targets: [localhost]
            labels:
              job: nginx
              log_type: error
              __path__: /var/log/nginx/error.log

      # Application logs with JSON parsing
      - job_name: webapp
        static_configs:
          - targets: [localhost]
            labels:
              job: webapp
              __path__: /var/log/webapp/*.log
        pipeline_stages:
          - json:
              expressions:
                level: level
                message: message
                request_id: request_id
          - labels:
              level:
              request_id:

  roles:
    - homelab.proxmox_lxc.promtail
```

### Kubernetes Node Configuration

```yaml
- name: Deploy Promtail on K3s nodes
  hosts: k3s_nodes
  vars:
    promtail_scrape_configs:
      # Kubelet logs
      - job_name: kubelet
        journal:
          max_age: 12h
          labels:
            job: kubelet
            node: "{{ inventory_hostname }}"
        relabel_configs:
          - source_labels: ['__journal__systemd_unit']
            target_label: 'unit'

      # Container logs
      - job_name: kubernetes-pods
        static_configs:
          - targets: [localhost]
            labels:
              job: kubernetes-pods
              node: "{{ inventory_hostname }}"
              __path__: /var/log/pods/**/*.log

  roles:
    - homelab.proxmox_lxc.promtail
```

## Troubleshooting

### Check Service Status

```bash
# Check if Promtail is running
systemctl status promtail

# View logs
journalctl -u promtail -f

# Check Promtail process
ps aux | grep promtail
```

### Validate Configuration

```bash
# Test configuration file
/usr/local/bin/promtail -config.file=/etc/promtail/promtail.yml -dry-run

# Check configuration syntax
cat /etc/promtail/promtail.yml | grep -v "^#" | grep -v "^$"
```

### Check Position Tracking

```bash
# View position file
cat /var/lib/promtail/positions.yaml

# Check if logs are being read
tail -f /var/lib/promtail/positions.yaml
```

### Test Loki Connectivity

```bash
# Test connection to Loki
curl -s http://192.168.0.210:3100/ready

# Check if Promtail can push logs
curl -v -H "Content-Type: application/json" \
  -XPOST "http://192.168.0.210:3100/loki/api/v1/push" \
  --data-raw '{"streams": [{"stream": {"job": "test"}, "values": [["'$(date +%s)000000000'", "test"]]}]}'
```

### Check Promtail Metrics

```bash
# Check Promtail metrics
curl -s http://localhost:9080/metrics | grep promtail_

# Check bytes sent
curl -s http://localhost:9080/metrics | grep promtail_sent_bytes_total

# Check read lines
curl -s http://localhost:9080/metrics | grep promtail_read_lines_total

# Check dropped entries
curl -s http://localhost:9080/metrics | grep promtail_dropped_entries_total
```

### File Permission Issues

```bash
# Check if promtail user can read logs
sudo -u promtail cat /var/log/syslog

# Check group membership
groups promtail

# Fix permissions if needed
usermod -a -G adm promtail
usermod -a -G systemd-journal promtail
```

### Debugging Log Shipping

```bash
# Enable debug logging
# Edit /etc/promtail/promtail.yml
# Add under server section:
# log_level: debug

# Restart Promtail
systemctl restart promtail

# View debug logs
journalctl -u promtail -f
```

## Security Considerations

- **File Permissions** - Promtail user needs read access to log files
- **Group Membership** - Add promtail user to adm and systemd-journal groups
- **Network Security** - Encrypt traffic to Loki in production
- **Sensitive Data** - Filter sensitive information before shipping
- **Resource Limits** - Configure systemd resource limits if needed
- **Position File** - Protect position file from unauthorized access

## Performance Tuning

### Resource Allocation

Promtail is lightweight and typically requires minimal resources:

```yaml
# Typical homelab configuration
promtail_resources:
  memory: 256   # MB
  cpu_shares: 512
```

### Optimize Log Collection

```yaml
# Batch size for sending logs
promtail_batch_size: 1048576  # 1MB

# Batch wait time
promtail_batch_wait: 1s

# Maximum backoff time for retries
promtail_max_backoff: 300s

# Timeout for sending batches
promtail_timeout: 10s
```

### Reduce Cardinality

```yaml
# Limit labels to reduce cardinality
pipeline_stages:
  - labeldrop:
      - request_id
      - trace_id

# Use relabeling to normalize labels
pipeline_stages:
  - relabel_configs:
      - source_labels: [pod_name]
        regex: '(.+)-[a-z0-9]{5}'
        target_label: app
```

## Integration with Other Services

### Loki Integration

Promtail ships logs directly to Loki:

```yaml
loki_endpoint: http://192.168.0.210:3100
```

### Prometheus Metrics

Promtail exposes metrics for Prometheus scraping:

```yaml
# In Prometheus scrape config
- job_name: 'promtail'
  static_configs:
    - targets:
        - '192.168.0.111:9080'
        - '192.168.0.112:9080'
        - '192.168.0.113:9080'
```

### Grafana Dashboards

Use Grafana to visualize Promtail metrics:
- Dashboard ID **15141** - Promtail Metrics

## Advanced Pipeline Examples

### Parse Nginx Logs

```yaml
pipeline_stages:
  - regex:
      expression: '^(?P<remote_addr>\S+) - (?P<remote_user>\S+) \[(?P<time_local>[^\]]+)\] "(?P<method>\S+) (?P<path>\S+)[^"]*" (?P<status>\d+) (?P<body_bytes_sent>\d+)'
  - labels:
      method:
      status:
      path:
  - timestamp:
      source: time_local
      format: "02/Jan/2006:15:04:05 -0700"
```

### Filter and Drop Logs

```yaml
pipeline_stages:
  # Drop debug logs
  - match:
      selector: '{job="app"}'
      stages:
        - drop:
            expression: ".*DEBUG.*"

  # Keep only errors and warnings
  - match:
      selector: '{job="app"}'
      stages:
        - drop:
            expression: ".*"
            older_than: 24h
        - match:
            selector: '{level!~"ERROR|WARN"}'
            action: drop
```

### Extract Kubernetes Metadata

```yaml
pipeline_stages:
  - cri: {}
  - regex:
      expression: '^/var/log/pods/(?P<namespace>[^_]+)_(?P<pod>[^_]+)_(?P<uid>[^/]+)/(?P<container>[^/]+)'
      source: filename
  - labels:
      namespace:
      pod:
      container:
```

## License

MIT License - See collection LICENSE file for details.
