# AlertManager Role

Deploys and configures Prometheus AlertManager as a centralized alert handling system in an LXC container, providing alert routing, grouping, silencing, and multi-channel notification delivery for the homelab monitoring stack.

## Features

- **Alert Routing** - Route alerts to different receivers based on labels
- **Alert Grouping** - Group related alerts to reduce notification noise
- **Alert Deduplication** - Prevent duplicate alert notifications
- **Silencing** - Temporary mute alerts during maintenance windows
- **Inhibition** - Suppress alerts based on other active alerts
- **Multi-Channel Notifications** - Email, Slack, PagerDuty, webhook, and more
- **High Availability** - Clustering support for redundancy (single-node for homelab)
- **Web UI** - Built-in web interface for alert management
- **API Access** - RESTful API for programmatic alert handling
- **Template Support** - Customizable notification templates

## Requirements

- Proxmox VE with LXC support
- Ubuntu 22.04 LTS template
- Network access to Prometheus instance
- SMTP server or notification service credentials (for alerts)
- Valid email addresses or notification endpoints

## Role Variables

### Version and Installation

```yaml
# AlertManager version to install
alertmanager_version: "0.27.0"

# Service port
alertmanager_port: 9093

# User and group
alertmanager_user: alertmanager
alertmanager_group: alertmanager
```

### Directory Configuration

```yaml
# Installation paths
alertmanager_config_dir: /etc/alertmanager
alertmanager_data_dir: /var/lib/alertmanager
alertmanager_templates_dir: /etc/alertmanager/templates
```

### Server Configuration

```yaml
# Network binding
alertmanager_listen_address: "0.0.0.0:{{ alertmanager_port }}"

# External URL (for links in notifications)
alertmanager_external_url: "http://{{ ansible_default_ipv4.address }}:{{ alertmanager_port }}"

# Cluster listen address (for HA)
alertmanager_cluster_listen_address: "0.0.0.0:9094"
```

### Alert Routing

```yaml
# Default receiver
alertmanager_default_receiver: "default"

# Group alerts by these labels
alertmanager_group_by:
  - alertname
  - cluster
  - service

# Time to wait before sending notification
alertmanager_group_wait: 30s

# Time to wait before sending notification about new alerts
alertmanager_group_interval: 5m

# Time to wait before re-sending notification
alertmanager_repeat_interval: 4h
```

### Email Configuration

```yaml
# SMTP settings
alertmanager_smtp_smarthost: "smtp.gmail.com:587"
alertmanager_smtp_from: "alertmanager@homelab.lan"
alertmanager_smtp_auth_username: "{{ vault_smtp_username }}"
alertmanager_smtp_auth_password: "{{ vault_smtp_password }}"
alertmanager_smtp_require_tls: true

# Email receiver
alertmanager_email_configs:
  - to: "admin@homelab.lan"
    send_resolved: true
    headers:
      Subject: "[ALERT] {{ .GroupLabels.alertname }}"
```

### Slack Configuration

```yaml
# Slack webhook
alertmanager_slack_api_url: "{{ vault_slack_webhook_url }}"

# Slack channel
alertmanager_slack_configs:
  - channel: "#alerts"
    send_resolved: true
    title: "{{ .GroupLabels.alertname }}"
    text: "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
```

### Webhook Configuration

```yaml
# Generic webhook receivers
alertmanager_webhook_configs:
  - url: "http://webhook.homelab.lan/alerts"
    send_resolved: true
    max_alerts: 10
```

### PagerDuty Configuration

```yaml
# PagerDuty integration
alertmanager_pagerduty_configs:
  - service_key: "{{ vault_pagerduty_service_key }}"
    send_resolved: true
    severity: "{{ .Labels.severity }}"
    description: "{{ .Annotations.summary }}"
```

## Usage

### Basic Deployment

```yaml
- hosts: proxmox_hosts
  roles:
    - homelab.proxmox_lxc.alertmanager
```

### With Email Notifications

```yaml
- hosts: proxmox_hosts
  vars:
    alertmanager_smtp_smarthost: "smtp.gmail.com:587"
    alertmanager_smtp_from: "alerts@example.com"
    alertmanager_smtp_auth_username: "{{ vault_smtp_username }}"
    alertmanager_smtp_auth_password: "{{ vault_smtp_password }}"

    alertmanager_email_configs:
      - to: "admin@example.com"
        send_resolved: true
  roles:
    - homelab.proxmox_lxc.alertmanager
```

### With Slack Integration

```yaml
- hosts: proxmox_hosts
  vars:
    alertmanager_slack_api_url: "{{ vault_slack_webhook_url }}"
    alertmanager_slack_configs:
      - channel: "#homelab-alerts"
        send_resolved: true
        title: "{{ .GroupLabels.alertname }}"
        text: |
          {{ range .Alerts }}
          *Alert:* {{ .Labels.alertname }}
          *Severity:* {{ .Labels.severity }}
          *Summary:* {{ .Annotations.summary }}
          *Description:* {{ .Annotations.description }}
          {{ end }}
  roles:
    - homelab.proxmox_lxc.alertmanager
```

### With Multiple Receivers

```yaml
- hosts: proxmox_hosts
  vars:
    alertmanager_receivers:
      - name: "default"
        email_configs:
          - to: "admin@example.com"

      - name: "critical"
        email_configs:
          - to: "oncall@example.com"
        slack_configs:
          - channel: "#critical-alerts"
            send_resolved: true

      - name: "warning"
        slack_configs:
          - channel: "#warnings"

    alertmanager_routes:
      - match:
          severity: critical
        receiver: "critical"
        repeat_interval: 1h

      - match:
          severity: warning
        receiver: "warning"
        repeat_interval: 12h
  roles:
    - homelab.proxmox_lxc.alertmanager
```

## Configuration

### AlertManager Configuration File

The role creates `/etc/alertmanager/alertmanager.yml`:

```yaml
global:
  smtp_smarthost: {{ alertmanager_smtp_smarthost }}
  smtp_from: {{ alertmanager_smtp_from }}
  smtp_auth_username: {{ alertmanager_smtp_auth_username }}
  smtp_auth_password: {{ alertmanager_smtp_auth_password }}
  smtp_require_tls: {{ alertmanager_smtp_require_tls }}
  slack_api_url: {{ alertmanager_slack_api_url }}

route:
  receiver: {{ alertmanager_default_receiver }}
  group_by: {{ alertmanager_group_by }}
  group_wait: {{ alertmanager_group_wait }}
  group_interval: {{ alertmanager_group_interval }}
  repeat_interval: {{ alertmanager_repeat_interval }}

  routes:
    {{ alertmanager_routes | to_yaml | indent(4) }}

receivers:
  {{ alertmanager_receivers | to_yaml | indent(2) }}

inhibit_rules:
  {{ alertmanager_inhibit_rules | to_yaml | indent(2) }}
```

### Notification Templates

Create custom templates in `/etc/alertmanager/templates/`:

```yaml
# /etc/alertmanager/templates/email.tmpl
{{ define "email.default.subject" }}
[{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .GroupLabels.SortedPairs.Values | join " " }}
{{ end }}

{{ define "email.default.html" }}
<h2>Summary</h2>
<p>{{ .Alerts | len }} alert(s) in {{ .GroupLabels.SortedPairs.Values | join " " }}</p>

<h2>Alerts</h2>
{{ range .Alerts }}
<h3>{{ .Labels.alertname }}</h3>
<p><strong>Severity:</strong> {{ .Labels.severity }}</p>
<p><strong>Summary:</strong> {{ .Annotations.summary }}</p>
<p><strong>Description:</strong> {{ .Annotations.description }}</p>
<p><strong>Started:</strong> {{ .StartsAt }}</p>
{{ end }}
{{ end }}
```

## Files and Templates

### Configuration Files

- **alertmanager.yml.j2** - Main AlertManager configuration template
- **alertmanager.service.j2** - Systemd service unit file

### Directory Structure

```
/etc/alertmanager/
├── alertmanager.yml        # Main configuration
└── templates/              # Notification templates
    ├── email.tmpl
    └── slack.tmpl

/var/lib/alertmanager/      # Data directory (silences, notifications)

/usr/local/bin/
├── alertmanager            # Main binary
└── amtool                  # CLI tool for AlertManager
```

## Dependencies

- homelab.common.container_base (recommended)
- homelab.common.security_hardening (recommended)

## Handlers

- `restart alertmanager` - Restart AlertManager service after configuration changes
- `reload alertmanager` - Reload configuration without restart

## Examples

### Complete Alert Routing Configuration

```yaml
- name: Deploy AlertManager with comprehensive routing
  hosts: proxmox_hosts
  vars:
    alertmanager_smtp_smarthost: "smtp.gmail.com:587"
    alertmanager_smtp_from: "alerts@homelab.lan"
    alertmanager_smtp_auth_username: "{{ vault_smtp_username }}"
    alertmanager_smtp_auth_password: "{{ vault_smtp_password }}"

    alertmanager_slack_api_url: "{{ vault_slack_webhook_url }}"

    alertmanager_receivers:
      - name: "default"
        email_configs:
          - to: "admin@homelab.lan"
            send_resolved: true

      - name: "critical"
        email_configs:
          - to: "oncall@homelab.lan"
            send_resolved: true
        slack_configs:
          - channel: "#critical"
            send_resolved: true
            title: "CRITICAL: {{ .GroupLabels.alertname }}"

      - name: "database"
        email_configs:
          - to: "dba@homelab.lan"
        slack_configs:
          - channel: "#database-alerts"

    alertmanager_routes:
      - match:
          severity: critical
        receiver: "critical"
        repeat_interval: 30m
        continue: true

      - match_re:
          service: "^(postgres|mysql|mongodb)$"
        receiver: "database"
        repeat_interval: 2h

    alertmanager_inhibit_rules:
      - source_match:
          severity: critical
        target_match:
          severity: warning
        equal:
          - alertname
          - instance

  roles:
    - homelab.proxmox_lxc.alertmanager
```

### Prometheus Integration

```yaml
# In Prometheus configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - '192.168.0.206:9093'
      timeout: 10s

# Alert rules in Prometheus
groups:
  - name: homelab
    interval: 30s
    rules:
      - alert: HighMemoryUsage
        expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1
        for: 5m
        labels:
          severity: warning
          service: node
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory available is {{ $value | humanizePercentage }}"

      - alert: ServiceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
          service: "{{ $labels.job }}"
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "{{ $labels.instance }} has been down for more than 2 minutes"
```

## Troubleshooting

### Check Service Status

```bash
# Check if AlertManager is running
pct exec 206 -- systemctl status alertmanager

# View logs
pct exec 206 -- journalctl -u alertmanager -f

# Check process
pct exec 206 -- ps aux | grep alertmanager
```

### Validate Configuration

```bash
# Validate configuration file
pct exec 206 -- amtool check-config /etc/alertmanager/alertmanager.yml

# Test routing
pct exec 206 -- amtool config routes test \
  --config.file=/etc/alertmanager/alertmanager.yml \
  severity=critical alertname=TestAlert
```

### Check Alerts

```bash
# List active alerts via API
curl -s http://192.168.0.206:9093/api/v2/alerts | jq .

# List silences
curl -s http://192.168.0.206:9093/api/v2/silences | jq .

# Get alert status
curl -s http://192.168.0.206:9093/api/v2/status | jq .
```

### Create Silence

```bash
# Create silence using amtool
pct exec 206 -- amtool silence add \
  alertname=HighMemoryUsage \
  --duration=2h \
  --comment="Maintenance window"

# Create silence via API
curl -X POST http://192.168.0.206:9093/api/v2/silences \
  -H 'Content-Type: application/json' \
  -d '{
    "matchers": [
      {"name": "alertname", "value": "HighMemoryUsage", "isRegex": false}
    ],
    "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%S.000Z)'",
    "endsAt": "'$(date -u -d '+2 hours' +%Y-%m-%dT%H:%M:%S.000Z)'",
    "comment": "Maintenance window",
    "createdBy": "admin"
  }'
```

### Test Notifications

```bash
# Send test alert via amtool
pct exec 206 -- amtool alert add \
  alertname=TestAlert \
  severity=warning \
  instance=localhost \
  summary="This is a test alert"

# Send test via API
curl -X POST http://192.168.0.206:9093/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[
    {
      "labels": {
        "alertname": "TestAlert",
        "severity": "warning"
      },
      "annotations": {
        "summary": "Test alert",
        "description": "This is a test alert"
      }
    }
  ]'
```

### Debug Email Delivery

```bash
# Check SMTP connectivity
pct exec 206 -- telnet smtp.gmail.com 587

# Test email sending
pct exec 206 -- swaks \
  --to admin@homelab.lan \
  --from alerts@homelab.lan \
  --server smtp.gmail.com:587 \
  --auth-user username \
  --auth-password password \
  --tls

# Check logs for email errors
pct exec 206 -- journalctl -u alertmanager | grep -i email
```

## Security Considerations

- **Credentials Protection** - Store SMTP and API credentials in Ansible Vault
- **Network Access** - Restrict AlertManager port (9093) to trusted networks
- **HTTPS** - Use Traefik for TLS termination
- **Authentication** - Enable basic auth for web UI in production
- **API Security** - Limit API access to authorized clients
- **Template Safety** - Validate templates to prevent injection attacks

## Performance Tuning

### Resource Allocation

```yaml
# For small homelab (< 100 alerts/day)
alertmanager_resources:
  memory: 512   # MB
  cores: 1
  disk_size: "5"

# For medium deployment (100-1000 alerts/day)
alertmanager_resources:
  memory: 1024  # MB
  cores: 2
  disk_size: "10"
```

### Alert Batching

```yaml
# Reduce notification frequency
alertmanager_group_wait: 60s
alertmanager_group_interval: 10m
alertmanager_repeat_interval: 12h
```

## Integration with Other Services

### Prometheus Integration

AlertManager receives alerts from Prometheus:

```yaml
# In Prometheus configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['192.168.0.206:9093']
```

### Grafana Integration

Configure Grafana to display AlertManager alerts:

```yaml
# In Grafana datasources
- name: AlertManager
  type: alertmanager
  url: http://192.168.0.206:9093
```

### Traefik Reverse Proxy

Expose AlertManager UI through Traefik:

```yaml
# Traefik labels for AlertManager
traefik_labels:
  - "traefik.enable=true"
  - "traefik.http.routers.alertmanager.rule=Host(`alertmanager.homelab.lan`)"
  - "traefik.http.routers.alertmanager.tls=true"
  - "traefik.http.services.alertmanager.loadbalancer.server.port=9093"
```

## Common Alert Rules

```yaml
# Prometheus alert rules for homelab
groups:
  - name: infrastructure
    rules:
      - alert: NodeDown
        expr: up{job="node"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.instance }} is down"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Disk space below 10% on {{ $labels.instance }}"

      - alert: HighCPU
        expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
```

## License

MIT License - See collection LICENSE file for details.
