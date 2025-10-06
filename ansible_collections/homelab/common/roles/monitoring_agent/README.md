# Monitoring Agent Role

Comprehensive monitoring and observability agent role for homelab infrastructure, providing metrics collection, log aggregation, health monitoring, and performance analysis for both K3s nodes and LXC containers.

## Features

- **Node Exporter** - Prometheus-compatible system metrics export
- **Promtail Integration** - Log collection and forwarding to Loki
- **Custom Health Checks** - Infrastructure health monitoring scripts
- **Service Discovery** - Automatic service detection and registration
- **Performance Metrics** - System resource and performance monitoring
- **Log Analysis** - Automated log parsing and pattern detection
- **Alert Integration** - Alert rule configuration for critical events
- **Firewall Configuration** - Automatic firewall rules for metrics endpoints
- **Cron Automation** - Scheduled monitoring tasks and health checks
- **Security** - Isolated monitoring user with minimal privileges

## Requirements

- Ubuntu 22.04 LTS or Debian 11+ (recommended)
- Root or sudo access for systemd service management
- Network connectivity for downloading exporters
- Python 3.8+ with pip
- homelab.common collection installed
- Prometheus server for metrics collection (optional)
- Loki server for log aggregation (optional)

## Role Variables

### Version Management

```yaml
# Component versions
node_exporter_version: 1.7.0
promtail_version: 2.9.0
monitoring_agent_version: 1.0.0
```

### User and Directory Configuration

```yaml
# Service user and paths
monitoring_user: monitoring
monitoring_group: monitoring
monitoring_home: /opt/monitoring
monitoring_config_dir: /etc/monitoring
monitoring_data_dir: /var/lib/monitoring
monitoring_log_dir: /var/log/monitoring
monitoring_scripts_dir: "{{ monitoring_home }}/scripts"
```

### Service Ports

```yaml
# Exposed service ports
node_exporter_port: 9100
promtail_port: 9080
monitoring_agent_port: 9090
```

### Prometheus Configuration

```yaml
# Metrics collection settings
prometheus_config:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: "{{ homelab_cluster_name | default('homelab') }}"
    environment: "{{ homelab_environment | default('production') }}"

# Monitoring targets
monitoring_targets:
  - name: node-metrics
    port: "{{ node_exporter_port }}"
    path: /metrics
    interval: 15s
  - name: infrastructure-health
    port: "{{ monitoring_agent_port }}"
    path: /health
    interval: 30s
```

### Log Collection Configuration

```yaml
# Promtail log collection
log_collection:
  enabled: true
  paths:
    - /var/log/syslog
    - /var/log/auth.log
    - /var/log/monitoring/*.log
    - /var/log/ansible/*.log
  labels:
    job: system-logs
    host: "{{ inventory_hostname }}"
    environment: "{{ homelab_environment | default('production') }}"
```

### Alert Rules Configuration

```yaml
# Alert definitions
alert_rules:
  - name: high_cpu_usage
    condition: cpu_usage > 80
    duration: 5m
    severity: warning
    description: CPU usage is above 80% for 5 minutes

  - name: high_memory_usage
    condition: memory_usage > 85
    duration: 5m
    severity: warning
    description: Memory usage is above 85% for 5 minutes

  - name: disk_space_low
    condition: disk_free < 10
    duration: 1m
    severity: critical
    description: Disk space is below 10%

  - name: service_down
    condition: service_up == 0
    duration: 1m
    severity: critical
    description: Critical service is down
```

### Health Check Configuration

```yaml
# Infrastructure health monitoring
health_checks:
  enabled: true
  checks:
    - name: system_resources
      type: resource
      thresholds:
        cpu: 90
        memory: 90
        disk: 95

    - name: network_connectivity
      type: network
      targets:
        - 8.8.8.8
        - "{{ homelab_gateway_ip | default('192.168.0.1') }}"

    - name: service_dependencies
      type: service
      services:
        - ssh
        - systemd-resolved
```

### Performance Metrics Configuration

```yaml
# Performance data collection
performance_metrics:
  collection_interval: 60  # seconds
  retention_days: 30
  metrics:
    - cpu_usage
    - memory_usage
    - disk_io
    - network_io
    - load_average
    - process_count
```

### Log Analysis Configuration

```yaml
# Automated log analysis
log_analysis:
  enabled: true
  patterns:
    - name: error_patterns
      regex: ERROR|FATAL|CRITICAL
      action: alert

    - name: auth_failures
      regex: authentication failure|Failed password
      action: count

    - name: security_events
      regex: sudo|su|ssh|login
      action: track
```

### Notification Configuration

```yaml
# Alert notification channels
notifications:
  enabled: false  # Disable by default
  channels:
    slack:
      webhook_url: "{{ vault_slack_webhook_url | default('') }}"
      channel: "#infrastructure"
    email:
      smtp_server: "{{ vault_smtp_server | default('') }}"
      recipients: "{{ vault_alert_recipients | default([]) }}"
```

### Firewall Configuration

```yaml
# Firewall rules for monitoring
firewall_enabled: true
firewall_rules:
  - port: "{{ node_exporter_port }}"
    source: "{{ monitoring_allowed_ips | default(['192.168.0.0/24']) }}"
  - port: "{{ promtail_port }}"
    source: "{{ monitoring_allowed_ips | default(['192.168.0.0/24']) }}"
```

### Security Configuration

```yaml
# Security settings
security_config:
  enable_ssl: false  # SSL handled by reverse proxy
  auth_required: false
  allowed_ips: "{{ monitoring_allowed_ips | default(['192.168.0.0/24']) }}"
  log_security_events: true
```

### Backup Configuration

```yaml
# Monitoring data backup
backup_config:
  enabled: true
  retention_days: 7
  backup_path: /opt/backups/monitoring
  schedule: 0 2 * * *  # Daily at 2 AM
  compress: true
```

## Usage

### Basic Monitoring Setup

```yaml
- hosts: all
  become: yes
  roles:
    - homelab.common.monitoring_agent
```

### K3s Cluster Monitoring

```yaml
- hosts: k3s_cluster
  become: yes
  vars:
    prometheus_config:
      external_labels:
        cluster: k3s-homelab
        role: "{{ 'server' if 'k3s_server' in group_names else 'agent' }}"
  roles:
    - homelab.common.monitoring_agent
```

### LXC Container Monitoring

```yaml
- hosts: lxc_containers
  become: yes
  vars:
    log_collection:
      enabled: true
      paths:
        - /var/log/syslog
        - /var/log/auth.log
        - /var/log/{{ service_name }}/*.log
  roles:
    - homelab.common.monitoring_agent
```

### Custom Alert Configuration

```yaml
- hosts: production_servers
  become: yes
  vars:
    alert_rules:
      - name: critical_cpu
        condition: cpu_usage > 95
        duration: 1m
        severity: critical
      - name: memory_leak
        condition: memory_growth_rate > 10
        duration: 30m
        severity: warning
  roles:
    - homelab.common.monitoring_agent
```

### Advanced Health Monitoring

```yaml
- hosts: database_servers
  become: yes
  vars:
    health_checks:
      enabled: true
      checks:
        - name: database_connectivity
          type: service
          services:
            - postgresql
            - redis
        - name: replication_lag
          type: custom
          script: /opt/monitoring/scripts/check_replication.sh
  roles:
    - homelab.common.monitoring_agent
```

## Tasks Overview

### Installation Tasks

1. **Install Monitoring Dependencies** - curl, wget, jq, python3-pip
2. **Install Python Libraries** - psutil, requests, prometheus_client
3. **Create Monitoring User** - System user with limited privileges
4. **Create Directory Structure** - Config, data, log, and script directories
5. **Install Node Exporter** - Download and install Prometheus node exporter
6. **Install Promtail** - Download and install Grafana Promtail

### Configuration Tasks

1. **Create Systemd Services** - Node exporter and Promtail service files
2. **Configure Monitoring** - Main monitoring configuration file
3. **Configure Promtail** - Log collection configuration
4. **Configure Log Rotation** - Logrotate for monitoring logs
5. **Deploy Custom Scripts** - Health check and monitoring scripts
6. **Configure Alert Rules** - Alert rule definitions

### Automation Tasks

1. **Create Cron Jobs** - Scheduled monitoring tasks
2. **Configure Firewall** - UFW rules for metrics endpoints
3. **Enable Services** - Start and enable systemd services
4. **Verify Deployment** - Health check validation

## Files and Templates

### Service Templates

- **node_exporter.service.j2** - Systemd service for Node Exporter
- **promtail.service.j2** - Systemd service for Promtail
- **monitoring_agent.service.j2** - Custom monitoring agent service

### Configuration Templates

- **monitoring_config.yml.j2** - Main monitoring configuration
- **promtail.yml.j2** - Promtail log collection configuration
- **alert_rules.yml.j2** - Alert rule definitions

### Script Templates

- **infrastructure_health_check.py.j2** - System health monitoring
- **service_discovery.py.j2** - Service discovery and registration
- **performance_metrics.py.j2** - Performance data collection
- **log_analyzer.py.j2** - Log analysis and pattern matching

### Utility Templates

- **monitoring_logrotate.j2** - Log rotation configuration

## Handlers

- `reload systemd` - Reload systemd daemon after service changes
- `restart node_exporter` - Restart Node Exporter service
- `restart promtail` - Restart Promtail service
- `restart monitoring_agent` - Restart custom monitoring agent

## Dependencies

- community.general (>=7.0.0) - For UFW firewall module
- Python packages: psutil, requests, prometheus_client

## Monitoring Integration

### Prometheus Integration

```yaml
# Prometheus scrape configuration
scrape_configs:
  - job_name: 'homelab-nodes'
    static_configs:
      - targets:
        - '192.168.0.111:9100'  # k3s-01
        - '192.168.0.112:9100'  # k3s-02
        - '192.168.0.200:9100'  # prometheus-lxc
```

### Loki Integration

```yaml
# Loki configuration for log ingestion
log_collection:
  enabled: true
  loki_url: "http://192.168.0.210:3100"
  paths:
    - /var/log/syslog
    - /var/log/auth.log
```

### Grafana Dashboards

Pre-configured dashboard imports:

- Node Exporter Full (ID: 1860)
- System Logs (Loki)
- Infrastructure Health Overview
- Performance Metrics Dashboard

## Scheduled Tasks

### Cron Job Schedule

```yaml
# Infrastructure health check - Every 5 minutes
*/5 * * * * /opt/monitoring/scripts/infrastructure_health_check.py

# Service discovery update - Every 10 minutes
*/10 * * * * /opt/monitoring/scripts/service_discovery.py

# Performance metrics collection - Every minute
*/1 * * * * /opt/monitoring/scripts/performance_metrics.py

# Log analysis - Every 4 hours
0 */4 * * * /opt/monitoring/scripts/log_analyzer.py
```

## Metrics Exported

### Node Exporter Metrics

- **CPU Metrics** - Usage, load average, context switches
- **Memory Metrics** - Total, used, free, cached, buffers
- **Disk Metrics** - I/O operations, latency, utilization
- **Network Metrics** - Bytes sent/received, packets, errors
- **Filesystem Metrics** - Disk usage, inodes, mount points
- **System Metrics** - Uptime, boot time, processes

### Custom Metrics

- **Health Status** - Infrastructure health score
- **Service Discovery** - Active services count
- **Performance Score** - Calculated performance index
- **Log Events** - Error count, warning count, security events

## Testing and Validation

### Verify Node Exporter

```bash
# Check Node Exporter status
sudo systemctl status node_exporter

# Test metrics endpoint
curl http://localhost:9100/metrics

# Verify specific metrics
curl http://localhost:9100/metrics | grep node_cpu
```

### Verify Promtail

```bash
# Check Promtail status
sudo systemctl status promtail

# Test Promtail endpoint
curl http://localhost:9080/ready

# View Promtail logs
sudo journalctl -u promtail -f
```

### Verify Custom Scripts

```bash
# Run health check manually
sudo -u monitoring /opt/monitoring/scripts/infrastructure_health_check.py

# Test service discovery
sudo -u monitoring /opt/monitoring/scripts/service_discovery.py

# Check performance metrics
sudo -u monitoring /opt/monitoring/scripts/performance_metrics.py
```

### Verify Firewall Rules

```bash
# Check UFW status
sudo ufw status numbered

# Verify monitoring ports
sudo ss -tlnp | grep -E "9100|9080"
```

## Troubleshooting

### Node Exporter Issues

```bash
# Check service status
sudo systemctl status node_exporter

# View logs
sudo journalctl -u node_exporter -f

# Test manually
/usr/local/bin/node_exporter --web.listen-address=:9100

# Verify binary
ls -la /usr/local/bin/node_exporter
```

### Promtail Issues

```bash
# Check Promtail status
sudo systemctl status promtail

# View configuration
cat /etc/monitoring/promtail.yml

# Test configuration
promtail -config.file=/etc/monitoring/promtail.yml -dry-run

# Check log permissions
ls -la /var/log/syslog
```

### Firewall Blocking Metrics

```bash
# Check firewall status
sudo ufw status verbose

# Allow specific IP
sudo ufw allow from 192.168.0.200 to any port 9100

# Disable firewall temporarily (testing only)
sudo ufw disable
```

### Script Execution Errors

```bash
# Check script permissions
ls -la /opt/monitoring/scripts/

# Run script with debug
sudo -u monitoring python3 -v /opt/monitoring/scripts/infrastructure_health_check.py

# Check Python dependencies
pip3 list | grep -E "psutil|requests|prometheus"
```

### Cron Job Not Running

```bash
# Check cron service
sudo systemctl status cron

# View cron logs
sudo journalctl -u cron -f

# List user crontab
sudo crontab -u monitoring -l

# Test cron job manually
sudo -u monitoring /opt/monitoring/scripts/infrastructure_health_check.py
```

## Security Considerations

- **Isolated User** - Monitoring runs as dedicated system user
- **Limited Privileges** - No sudo access for monitoring user
- **Firewall Protection** - Metrics endpoints restricted to monitoring network
- **No Authentication** - Designed for internal network use with reverse proxy for external access
- **Log Security** - Security events logged and monitored
- **File Permissions** - Strict permissions on configuration and scripts

## Performance Impact

- **Node Exporter** - Minimal CPU and memory overhead (<1% CPU, ~10MB RAM)
- **Promtail** - Light resource usage (~2% CPU, ~50MB RAM)
- **Custom Scripts** - Scheduled to avoid overlapping execution
- **Log Collection** - Buffered to prevent I/O spikes
- **Network Traffic** - ~50KB/s metrics + logs traffic

## Best Practices

1. **Version Management** - Pin exporter versions for stability
2. **Resource Limits** - Set systemd resource limits for monitoring services
3. **Log Retention** - Configure appropriate retention based on storage
4. **Alert Tuning** - Adjust thresholds to reduce false positives
5. **Regular Updates** - Keep exporters and scripts updated
6. **Backup Monitoring Data** - Regular backups of monitoring configuration
7. **Test Alerts** - Regularly test alert delivery
8. **Documentation** - Document custom metrics and scripts

## Advanced Configuration

### Custom Metrics Collection

```yaml
# Add custom metric collectors
monitoring_scripts:
  - name: custom_app_metrics.py
    schedule: "*/2 * * * *"
    port: 9091
```

### Multi-Environment Setup

```yaml
# Development environment
- hosts: dev_servers
  vars:
    prometheus_config:
      external_labels:
        environment: development
        datacenter: home
    alert_rules:
      - name: dev_cpu_high
        condition: cpu_usage > 95
        severity: info

# Production environment
- hosts: prod_servers
  vars:
    prometheus_config:
      external_labels:
        environment: production
        datacenter: home
    alert_rules:
      - name: prod_cpu_high
        condition: cpu_usage > 80
        severity: critical
```

### High-Availability Setup

```yaml
# HA monitoring with multiple agents
health_checks:
  enabled: true
  ha_mode: true
  peers:
    - 192.168.0.111
    - 192.168.0.112
    - 192.168.0.113
```

## Migration Guide

### From Manual Installation

1. Stop existing services: `systemctl stop node_exporter promtail`
2. Backup configurations: `/etc/node_exporter/`, `/etc/promtail/`
3. Run role with `monitoring_preserve_data: true`
4. Verify metrics continuity

### Upgrading Versions

```yaml
# Override version variables
node_exporter_version: 1.8.0  # New version
promtail_version: 3.0.0        # New version
monitoring_force_reinstall: true
```

## License

Apache License 2.0 - See collection LICENSE file for details.
