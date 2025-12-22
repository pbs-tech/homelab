# Grafana Role

Deploys and configures Grafana as a powerful visualization and analytics platform in an LXC container, providing comprehensive dashboards and insights for infrastructure monitoring.

## Features

- **Rich Visualizations** - Wide variety of panel types for data visualization
- **Dashboard Management** - Automated dashboard provisioning and organization
- **Multi-Datasource** - Support for Prometheus, Loki, and other data sources
- **Alerting System** - Unified alerting with multi-channel notifications
- **User Management** - Role-based access control and team management
- **Plugin Ecosystem** - Extensive plugin library for extended functionality
- **API Access** - RESTful API for automation and integration
- **Template Variables** - Dynamic dashboards with variable substitution
- **Annotations** - Event marking and correlation on graphs

## Requirements

- Proxmox VE with LXC support
- Ubuntu 22.04 LTS template
- Network access to data sources (Prometheus, Loki, etc.)
- Valid domain name for HTTPS access (optional)
- Sufficient storage for dashboard definitions and plugins

### Required Vault Variables

The following vault variables must be configured before deployment:

- `vault_grafana_admin_password` - Admin user password
- `vault_grafana_secret_key` - Secret key for signing cookies and session tokens
  (generate with: `openssl rand -base64 32`)

## Role Variables

### Version and Installation

```yaml
# Grafana version (managed by apt)
grafana_version: 10.2.0

# Service port
grafana_port: 3000

# User and group
grafana_user: grafana
grafana_group: grafana
```

### Directory Configuration

```yaml
# Installation paths
grafana_config_dir: /etc/grafana
grafana_data_dir: /var/lib/grafana
grafana_logs_dir: /var/log/grafana
grafana_plugins_dir: "{{ grafana_data_dir }}/plugins"
grafana_dashboards_dir: "{{ grafana_data_dir }}/dashboards"
grafana_provisioning_dir: "{{ grafana_config_dir }}/provisioning"
```

### Server Configuration

```yaml
# Server domain and URL
grafana_domain: "{{ ansible_default_ipv4.address }}"
grafana_root_url: "http://{{ grafana_domain }}:{{ grafana_port }}"

# For production with reverse proxy
grafana_domain: "grafana.homelab.local"
grafana_root_url: "https://{{ grafana_domain }}"
grafana_serve_from_sub_path: false
```

### Admin User

```yaml
# Admin credentials
grafana_admin_user: admin
grafana_admin_password: "{{ vault_grafana_admin_password }}"

# Change admin password on first login
grafana_admin_password_change_required: true
```

### Security Settings

```yaml
# User registration
grafana_allow_sign_up: false
grafana_allow_org_create: false

# Auto-assignment
grafana_auto_assign_org: true
grafana_auto_assign_org_role: Viewer

# Session settings
grafana_session_lifetime: 24h
grafana_token_rotation_interval: 10m
```

### Database Configuration

```yaml
# Database type (sqlite3, mysql, postgres)
grafana_database_type: sqlite3
grafana_database_path: "{{ grafana_data_dir }}/grafana.db"

# For PostgreSQL
grafana_database_type: postgres
grafana_database_host: localhost:5432
grafana_database_name: grafana
grafana_database_user: grafana
grafana_database_password: "{{ vault_grafana_db_password }}"
```

### Logging Configuration

```yaml
# Logging
grafana_log_mode: file
grafana_log_level: info

# Available levels: debug, info, warn, error, critical
```

### Datasource Provisioning

```yaml
# Datasources to provision automatically
grafana_datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://192.168.0.200:9090
    is_default: true
    basic_auth: false
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://192.168.0.210:3100
    is_default: false
    basic_auth: false
    editable: true
    json_data:
      maxLines: 1000
      derivedFields:
        - datasourceName: Prometheus
          matcherRegex: "traceID=(\\w+)"
          name: TraceID
          url: "$${__value.raw}"
```

### Plugin Configuration

```yaml
# Plugins to install
grafana_plugins:
  - grafana-piechart-panel
  - grafana-worldmap-panel
  - grafana-clock-panel
  - grafana-simple-json-datasource

# Plugin installation from custom URLs
grafana_plugins_url:
  - url: https://example.com/custom-plugin.zip
    name: custom-plugin
```

### Authentication

```yaml
# Anonymous access
grafana_anonymous_enabled: false
grafana_anonymous_org_name: Main Org.
grafana_anonymous_org_role: Viewer

# OAuth configuration
grafana_oauth_enabled: false
grafana_oauth_provider: google
grafana_oauth_client_id: "{{ vault_oauth_client_id }}"
grafana_oauth_client_secret: "{{ vault_oauth_client_secret }}"
grafana_oauth_allowed_domains: example.com

# LDAP configuration
grafana_ldap_enabled: false
grafana_ldap_config_file: /etc/grafana/ldap.toml
```

## Usage

### Basic Deployment

```yaml
- hosts: proxmox_hosts
  roles:
    - homelab.proxmox_lxc.grafana
```

### With Custom Datasources

```yaml
- hosts: proxmox_hosts
  vars:
    grafana_datasources:
      - name: Prometheus
        type: prometheus
        url: http://192.168.0.200:9090
        is_default: true

      - name: Loki
        type: loki
        url: http://192.168.0.210:3100

      - name: InfluxDB
        type: influxdb
        url: http://192.168.0.220:8086
        database: homelab
        user: grafana
        password: "{{ vault_influxdb_password }}"
  roles:
    - homelab.proxmox_lxc.grafana
```

### With Additional Plugins

```yaml
- hosts: proxmox_hosts
  vars:
    grafana_plugins:
      - grafana-piechart-panel
      - grafana-worldmap-panel
      - grafana-clock-panel
      - alexanderzobnin-zabbix-app
      - grafana-kubernetes-app
  roles:
    - homelab.proxmox_lxc.grafana
```

### Production Configuration with OAuth

```yaml
- hosts: proxmox_hosts
  vars:
    grafana_domain: grafana.example.com
    grafana_root_url: "https://{{ grafana_domain }}"

    grafana_allow_sign_up: false
    grafana_oauth_enabled: true
    grafana_oauth_provider: google
    grafana_oauth_client_id: "{{ vault_oauth_client_id }}"
    grafana_oauth_client_secret: "{{ vault_oauth_client_secret }}"
    grafana_oauth_allowed_domains: example.com

    grafana_database_type: postgres
    grafana_database_host: postgres.homelab.local:5432
    grafana_database_name: grafana
  roles:
    - homelab.proxmox_lxc.grafana
```

## Dashboard Provisioning

### Automatic Dashboard Loading

Create dashboard JSON files in the provisioning directory:

```yaml
# Configure dashboard provisioning path
grafana_dashboard_providers:
  - name: 'default'
    org_id: 1
    folder: 'Homelab'
    type: file
    options:
      path: "{{ grafana_dashboards_dir }}"
```

Place dashboard JSON files in `{{ grafana_dashboards_dir }}/`:

```bash
# Example: Copy dashboard to provisioning directory
pct exec 201 -- mkdir -p /var/lib/grafana/dashboards
pct push 201 node-exporter-full.json /var/lib/grafana/dashboards/
```

### Dashboard Templates

Common dashboard imports:

```yaml
# In playbook or tasks
- name: Import Node Exporter Full dashboard
  community.grafana.grafana_dashboard:
    grafana_url: "{{ grafana_root_url }}"
    grafana_user: "{{ grafana_admin_user }}"
    grafana_password: "{{ grafana_admin_password }}"
    dashboard_id: 1860
    state: present

- name: Import Kubernetes cluster monitoring
  community.grafana.grafana_dashboard:
    grafana_url: "{{ grafana_root_url }}"
    grafana_user: "{{ grafana_admin_user }}"
    grafana_password: "{{ grafana_admin_password }}"
    dashboard_id: 7249
    state: present
```

## Files and Templates

### Configuration Files

- **grafana.ini.j2** - Main Grafana configuration template
- **datasources.yml.j2** - Datasource provisioning configuration
- **dashboards.yml.j2** - Dashboard provisioning configuration

### Directory Structure

```
/etc/grafana/
├── grafana.ini              # Main configuration
├── provisioning/
│   ├── datasources/
│   │   └── datasources.yml  # Datasource definitions
│   ├── dashboards/
│   │   └── dashboards.yml   # Dashboard provider config
│   └── notifiers/           # Alert notification channels

/var/lib/grafana/
├── grafana.db              # SQLite database
├── dashboards/             # Provisioned dashboards
└── plugins/                # Installed plugins

/var/log/grafana/           # Log files
```

## Dependencies

- homelab.common.container_base (recommended)
- homelab.common.security_hardening (recommended)

## Handlers

- `restart grafana` - Restart Grafana service after configuration changes

## Examples

### Complete Monitoring Stack

```yaml
- name: Deploy Grafana with full observability stack
  hosts: proxmox_hosts
  vars:
    grafana_domain: grafana.homelab.local
    grafana_root_url: "https://{{ grafana_domain }}"

    grafana_datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://192.168.0.200:9090
        is_default: true
        json_data:
          timeInterval: 15s

      - name: Loki
        type: loki
        access: proxy
        url: http://192.168.0.210:3100
        json_data:
          maxLines: 1000

      - name: AlertManager
        type: alertmanager
        access: proxy
        url: http://192.168.0.206:9093

    grafana_plugins:
      - grafana-piechart-panel
      - grafana-worldmap-panel
      - grafana-clock-panel

    grafana_allow_sign_up: false
    grafana_auto_assign_org_role: Viewer

  roles:
    - homelab.proxmox_lxc.grafana

  post_tasks:
    - name: Import standard dashboards
      community.grafana.grafana_dashboard:
        grafana_url: "{{ grafana_root_url }}"
        grafana_user: "{{ grafana_admin_user }}"
        grafana_password: "{{ grafana_admin_password }}"
        dashboard_id: "{{ item }}"
        state: present
      loop:
        - 1860  # Node Exporter Full
        - 12019 # Loki Dashboard
        - 13639 # K3s Cluster Monitoring
```

## Troubleshooting

### Check Service Status

```bash
# Check if Grafana is running
pct exec 201 -- systemctl status grafana-server

# View logs
pct exec 201 -- journalctl -u grafana-server -f

# Check Grafana logs
pct exec 201 -- tail -f /var/log/grafana/grafana.log
```

### Configuration Validation

```bash
# Check configuration file syntax
pct exec 201 -- grafana-cli admin reset-admin-password --homepath /usr/share/grafana admin

# Verify datasource connectivity
curl -u admin:password http://192.168.0.201:3000/api/datasources
```

### Plugin Issues

```bash
# List installed plugins
pct exec 201 -- grafana-cli plugins ls

# Install plugin manually
pct exec 201 -- grafana-cli plugins install grafana-piechart-panel

# Update all plugins
pct exec 201 -- grafana-cli plugins update-all

# Check plugin directory
pct exec 201 -- ls -la /var/lib/grafana/plugins/
```

### Database Issues

```bash
# Check database connectivity
pct exec 201 -- sqlite3 /var/lib/grafana/grafana.db ".tables"

# Backup database
pct exec 201 -- sqlite3 /var/lib/grafana/grafana.db ".backup /tmp/grafana-backup.db"

# Check database size
pct exec 201 -- du -sh /var/lib/grafana/grafana.db
```

### API Testing

```bash
# Test API health
curl -s http://192.168.0.201:3000/api/health | jq .

# List datasources
curl -s -u admin:password http://192.168.0.201:3000/api/datasources | jq .

# List dashboards
curl -s -u admin:password http://192.168.0.201:3000/api/search | jq .

# Test datasource
curl -s -u admin:password http://192.168.0.201:3000/api/datasources/1/health | jq .
```

### Login Issues

```bash
# Reset admin password
pct exec 201 -- grafana-cli admin reset-admin-password newpassword

# Check users
pct exec 201 -- sqlite3 /var/lib/grafana/grafana.db "SELECT * FROM user;"
```

## Security Considerations

- **Authentication** - Always change default admin password
- **HTTPS** - Use Traefik or nginx for TLS termination
- **RBAC** - Configure appropriate roles for users and teams
- **API Keys** - Use service accounts with limited permissions
- **Data Access** - Restrict datasource access based on roles
- **Anonymous Access** - Disable unless specifically needed
- **Session Security** - Configure appropriate session timeouts
- **Plugin Security** - Only install trusted plugins from official sources

## Performance Tuning

### Resource Allocation

```yaml
# For small homelab (< 10 users, < 50 dashboards)
grafana_resources:
  memory: 1024  # 1GB RAM
  cores: 2
  disk_size: "10"

# For medium deployment (< 50 users, < 200 dashboards)
grafana_resources:
  memory: 2048  # 2GB RAM
  cores: 4
  disk_size: "20"
```

### Database Optimization

For production use with many users/dashboards:

```yaml
# Switch to PostgreSQL
grafana_database_type: postgres
grafana_database_host: postgres.homelab.local:5432
grafana_database_name: grafana
grafana_database_max_open_conn: 300
grafana_database_max_idle_conn: 100
```

### Query Performance

```ini
# In grafana.ini template
[dataproxy]
timeout = 30
keep_alive_seconds = 30

[database]
max_idle_conn = 100
max_open_conn = 300
conn_max_lifetime = 14400

[rendering]
concurrent_render_limit = 10
```

## Integration with Other Services

### Prometheus Integration

Grafana automatically queries Prometheus when configured:

```yaml
grafana_datasources:
  - name: Prometheus
    type: prometheus
    url: http://192.168.0.200:9090
    is_default: true
```

### Loki Integration

For log exploration and correlation:

```yaml
grafana_datasources:
  - name: Loki
    type: loki
    url: http://192.168.0.210:3100
    json_data:
      derivedFields:
        - datasourceName: Prometheus
          matcherRegex: "instance=\"([^\"]+)\""
          name: Instance
          url: "/explore?left=[\"now-1h\",\"now\",\"Prometheus\",{\"expr\":\"up{instance=\\\"$${__value.raw}\\\"}\"},{\"ui\":[true,true,true,\"none\"]}]"
```

### Traefik Reverse Proxy

Expose Grafana through Traefik:

```yaml
# Traefik labels for Grafana
traefik_labels:
  - "traefik.enable=true"
  - "traefik.http.routers.grafana.rule=Host(`grafana.homelab.local`)"
  - "traefik.http.routers.grafana.tls=true"
  - "traefik.http.services.grafana.loadbalancer.server.port=3000"
```

## Popular Dashboard IDs

Import these from grafana.com:

- **1860** - Node Exporter Full (Linux hosts)
- **12019** - Loki Dashboard Quick Search
- **13639** - Kubernetes Cluster Monitoring
- **7249** - Kubernetes Cluster (Prometheus)
- **3662** - Prometheus 2.0 Overview
- **11074** - Node Exporter for Prometheus
- **12633** - Proxmox via Prometheus

## License

MIT License - See collection LICENSE file for details.
