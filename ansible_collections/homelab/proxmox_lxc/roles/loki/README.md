# Loki Role

Deploys and configures Grafana Loki as a horizontally scalable, highly available log aggregation system in an LXC container, providing efficient log storage and querying for the homelab environment.

## Features

- **Cost-Effective Storage** - Only indexes metadata, not full log content
- **LogQL Query Language** - Powerful query language similar to PromQL
- **Label-Based Indexing** - Efficient log organization using labels
- **Multi-Tenancy** - Support for multiple isolated tenants
- **Grafana Integration** - Native integration with Grafana for log exploration
- **Horizontal Scalability** - Designed for distributed deployment (single-node for homelab)
- **Retention Management** - Configurable retention policies and compaction
- **Stream Processing** - Real-time log ingestion and querying
- **Low Resource Usage** - Optimized for resource-constrained environments

## Requirements

- Proxmox VE with LXC support
- Ubuntu 22.04 LTS template
- Network access for log shipping (Promtail agents)
- Sufficient storage for log retention
- Time synchronization across log sources

## Role Variables

### Version and Installation

```yaml
# Loki version to install
loki_version: 2.9.2

# Service port
loki_port: 3100

# User and group
loki_user: loki
loki_group: loki
```

### Directory Configuration

```yaml
# Installation paths
loki_bin_dir: /usr/local/bin
loki_config_dir: /etc/loki
loki_data_dir: /var/lib/loki
loki_log_dir: /var/log/loki
```

### Network Configuration

```yaml
# Network binding
loki_listen_address: 0.0.0.0
loki_listen_port: "{{ loki_port }}"

# HTTP server configuration
loki_http_server_idle_timeout: 120s
loki_http_server_read_timeout: 30s
loki_http_server_write_timeout: 30s
```

### Storage Configuration

```yaml
# Storage type (filesystem, s3, gcs, etc.)
loki_storage_type: filesystem
loki_storage_filesystem_directory: "{{ loki_data_dir }}/chunks"

# For production S3 storage
loki_storage_type: s3
loki_storage_s3_bucket: homelab-loki-logs
loki_storage_s3_region: us-east-1
loki_storage_s3_access_key: "{{ vault_s3_access_key }}"
loki_storage_s3_secret_key: "{{ vault_s3_secret_key }}"
```

### Retention Configuration

```yaml
# Enable retention
loki_retention_enabled: true

# Retention period (720h = 30 days)
loki_retention_period: "720h"

# Enable compaction
loki_compaction_enabled: true
loki_compaction_working_directory: "{{ loki_data_dir }}/boltdb-compactor"
loki_compaction_shared_store_type: filesystem
```

### Performance Settings

```yaml
# Query parallelism
loki_max_query_parallelism: 32

# Ingestion rate limits (in MB)
loki_ingestion_rate_limit_mb: 4
loki_ingestion_burst_size_mb: 6

# Stream limits
loki_max_streams_per_user: 10000
loki_max_line_size: 256000
```

### Query Limits

```yaml
# Query timeout
loki_query_timeout: 1m

# Maximum number of series
loki_max_query_series: 500

# Maximum query lookback period
loki_max_query_lookback: 0s  # 0 = unlimited
```

### Table Manager

```yaml
# Table manager for retention
loki_table_manager_retention_deletes_enabled: "{{ loki_retention_enabled }}"
loki_table_manager_retention_period: "{{ loki_retention_period }}"
```

## Usage

### Basic Deployment

```yaml
- hosts: proxmox_hosts
  roles:
    - homelab.proxmox_lxc.loki
```

### With Custom Retention

```yaml
- hosts: proxmox_hosts
  vars:
    loki_retention_enabled: true
    loki_retention_period: "2160h"  # 90 days
    loki_compaction_enabled: true
  roles:
    - homelab.proxmox_lxc.loki
```

### High Volume Configuration

```yaml
- hosts: proxmox_hosts
  vars:
    loki_ingestion_rate_limit_mb: 16
    loki_ingestion_burst_size_mb: 32
    loki_max_streams_per_user: 50000
    loki_max_query_parallelism: 64
  roles:
    - homelab.proxmox_lxc.loki
```

### With S3 Storage Backend

```yaml
- hosts: proxmox_hosts
  vars:
    loki_storage_type: s3
    loki_storage_s3_bucket: homelab-loki-logs
    loki_storage_s3_region: us-east-1
    loki_storage_s3_endpoint: s3.amazonaws.com
    loki_storage_s3_access_key: "{{ vault_s3_access_key }}"
    loki_storage_s3_secret_key: "{{ vault_s3_secret_key }}"
  roles:
    - homelab.proxmox_lxc.loki
```

## Configuration

### Loki Configuration File

The role creates `/etc/loki/loki.yml` with:

```yaml
auth_enabled: false

server:
  http_listen_address: {{ loki_listen_address }}
  http_listen_port: {{ loki_listen_port }}
  grpc_listen_port: 9096

common:
  path_prefix: {{ loki_data_dir }}
  storage:
    filesystem:
      chunks_directory: {{ loki_storage_filesystem_directory }}
      rules_directory: {{ loki_data_dir }}/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: {{ loki_data_dir }}/boltdb-shipper-active
    cache_location: {{ loki_data_dir }}/boltdb-shipper-cache
    shared_store: filesystem
  filesystem:
    directory: {{ loki_storage_filesystem_directory }}

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: {{ loki_ingestion_rate_limit_mb }}
  ingestion_burst_size_mb: {{ loki_ingestion_burst_size_mb }}
  max_streams_per_user: {{ loki_max_streams_per_user }}
  max_line_size: {{ loki_max_line_size }}

compactor:
  working_directory: {{ loki_compaction_working_directory }}
  shared_store: {{ loki_compaction_shared_store_type }}
  compaction_interval: 10m
  retention_enabled: {{ loki_retention_enabled }}
  retention_delete_delay: 2h
  retention_delete_worker_count: 150

table_manager:
  retention_deletes_enabled: {{ loki_table_manager_retention_deletes_enabled }}
  retention_period: {{ loki_table_manager_retention_period }}

analytics:
  reporting_enabled: false
```

### Promtail Integration

Loki receives logs from Promtail agents. Configure Promtail to ship logs:

```yaml
# In Promtail configuration
loki_endpoint: http://192.168.0.210:3100
```

## Files and Templates

### Configuration Files

- **loki.yml.j2** - Main Loki configuration template
- **loki.service.j2** - Systemd service unit file

### Directory Structure

```
/etc/loki/
└── loki.yml                # Main configuration

/var/lib/loki/
├── chunks/                 # Log chunk storage
├── boltdb-shipper-active/  # Active index
├── boltdb-shipper-cache/   # Index cache
├── boltdb-compactor/       # Compaction working dir
└── rules/                  # Alert rules

/usr/local/bin/
└── loki                    # Loki binary

/var/log/loki/             # Log files
```

## Dependencies

- homelab.common.container_base (recommended)
- homelab.common.security_hardening (recommended)

## Handlers

- `reload systemd` - Reload systemd daemon after service file changes
- `restart loki` - Restart Loki service after configuration changes

## Examples

### Complete Log Aggregation Stack

```yaml
- name: Deploy Loki with optimized settings
  hosts: proxmox_hosts
  vars:
    loki_retention_enabled: true
    loki_retention_period: "1440h"  # 60 days
    loki_compaction_enabled: true

    loki_ingestion_rate_limit_mb: 8
    loki_ingestion_burst_size_mb: 12
    loki_max_streams_per_user: 20000

    loki_max_query_parallelism: 32
    loki_query_timeout: 2m

    # Optimize for homelab
    loki_max_line_size: 512000
    loki_max_query_series: 1000

  roles:
    - homelab.proxmox_lxc.loki
```

### Development Configuration

```yaml
- name: Deploy Loki for testing
  hosts: proxmox_hosts
  vars:
    loki_retention_period: "168h"  # 7 days
    loki_ingestion_rate_limit_mb: 2
    loki_max_streams_per_user: 5000
  roles:
    - homelab.proxmox_lxc.loki
```

## Troubleshooting

### Check Service Status

```bash
# Check if Loki is running
pct exec 210 -- systemctl status loki

# View logs
pct exec 210 -- journalctl -u loki -f

# Check Loki process
pct exec 210 -- ps aux | grep loki
```

### Validate Configuration

```bash
# Test configuration file
pct exec 210 -- /usr/local/bin/loki -config.file=/etc/loki/loki.yml -verify-config

# Check configuration syntax
pct exec 210 -- cat /etc/loki/loki.yml | grep -v "^#" | grep -v "^$"
```

### Query Loki

```bash
# Check Loki readiness
curl -s http://192.168.0.210:3100/ready

# Check Loki metrics
curl -s http://192.168.0.210:3100/metrics | grep loki_

# Query labels
curl -s 'http://192.168.0.210:3100/loki/api/v1/labels' | jq .

# Query label values
curl -s 'http://192.168.0.210:3100/loki/api/v1/label/job/values' | jq .

# Query logs (LogQL)
curl -G -s 'http://192.168.0.210:3100/loki/api/v1/query' \
  --data-urlencode 'query={job="syslog"}' | jq .

# Query logs with range
curl -G -s 'http://192.168.0.210:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={job="syslog"}' \
  --data-urlencode 'start=1609459200' \
  --data-urlencode 'end=1609545600' | jq .
```

### Storage Issues

```bash
# Check disk usage
pct exec 210 -- df -h /var/lib/loki

# Check chunk storage size
pct exec 210 -- du -sh /var/lib/loki/chunks/*

# Check index size
pct exec 210 -- du -sh /var/lib/loki/boltdb-shipper-active/*

# List retention status
curl -s http://192.168.0.210:3100/loki/api/v1/status/buildinfo | jq .
```

### Ingestion Issues

```bash
# Check if Loki is receiving logs
curl -s http://192.168.0.210:3100/metrics | grep loki_distributor_bytes_received_total

# Check for errors
pct exec 210 -- journalctl -u loki | grep -i error

# Test log ingestion
curl -v -H "Content-Type: application/json" \
  -XPOST -s "http://192.168.0.210:3100/loki/api/v1/push" \
  --data-raw '{"streams": [{ "stream": { "job": "test" }, "values": [ [ "'$(date +%s)000000000'", "test log line" ] ] }]}'
```

### Performance Issues

```bash
# Monitor resource usage
pct exec 210 -- htop

# Check Loki metrics
curl -s http://192.168.0.210:3100/metrics | grep -E "loki_(ingester|querier)_"

# Check query performance
curl -s http://192.168.0.210:3100/metrics | grep loki_query_duration_seconds

# View active streams
curl -s http://192.168.0.210:3100/metrics | grep loki_ingester_streams
```

### Compaction Issues

```bash
# Check compaction status
curl -s http://192.168.0.210:3100/metrics | grep loki_compactor_

# Check retention application
pct exec 210 -- ls -la /var/lib/loki/boltdb-compactor/

# View compaction logs
pct exec 210 -- journalctl -u loki | grep compactor
```

## Security Considerations

- **Network Access** - Restrict Loki port (3100) to trusted networks
- **Authentication** - Enable auth for multi-tenant deployments
- **TLS Encryption** - Use reverse proxy (Traefik) for HTTPS
- **Data Protection** - Secure log data directory permissions (700)
- **Rate Limiting** - Configure appropriate ingestion limits
- **Query Limits** - Prevent resource exhaustion with query limits

## Performance Tuning

### Resource Allocation

```yaml
# For small homelab (< 10 log sources)
loki_resources:
  memory: 1024  # 1GB RAM
  cores: 2
  disk_size: "20"

# For medium homelab (10-30 log sources)
loki_resources:
  memory: 2048  # 2GB RAM
  cores: 4
  disk_size: "50"

# For large homelab (30+ log sources)
loki_resources:
  memory: 4096  # 4GB RAM
  cores: 8
  disk_size: "100"
```

### Storage Optimization

- Enable compaction to reduce storage footprint
- Configure appropriate retention periods
- Monitor chunk size and adjust if needed
- Consider S3 for long-term storage

### Query Optimization

- Use specific label selectors to reduce query scope
- Limit query time ranges when possible
- Configure appropriate query timeouts
- Use line filters early in queries

### Ingestion Optimization

```yaml
# For high-volume logging
loki_ingestion_rate_limit_mb: 16
loki_ingestion_burst_size_mb: 32
loki_max_streams_per_user: 50000
```

## Integration with Other Services

### Grafana Integration

Loki automatically integrates with Grafana as a datasource:

```yaml
# In Grafana configuration
grafana_datasources:
  - name: Loki
    type: loki
    url: http://192.168.0.210:3100
    json_data:
      maxLines: 1000
```

### Promtail Log Shipping

Configure Promtail to ship logs to Loki:

```yaml
# In Promtail configuration
loki_endpoint: http://192.168.0.210:3100
```

### Prometheus Integration

Use Loki with Prometheus for correlated metrics and logs:

```yaml
# In Grafana, configure derived fields
grafana_datasources:
  - name: Loki
    type: loki
    url: http://192.168.0.210:3100
    json_data:
      derivedFields:
        - datasourceName: Prometheus
          matcherRegex: "instance=\"([^\"]+)\""
          name: Instance
          url: "/explore"
```

### Traefik Reverse Proxy

Expose Loki through Traefik for external access:

```yaml
# Traefik labels for Loki
traefik_labels:
  - "traefik.enable=true"
  - "traefik.http.routers.loki.rule=Host(`loki.homelab.local`)"
  - "traefik.http.routers.loki.tls=true"
  - "traefik.http.services.loki.loadbalancer.server.port=3100"
```

## Useful LogQL Queries

```logql
# Show all logs from a job
{job="syslog"}

# Filter logs containing "error"
{job="syslog"} |= "error"

# Exclude logs containing "debug"
{job="syslog"} != "debug"

# Regular expression filter
{job="syslog"} |~ "error|critical"

# JSON parsing
{job="syslog"} | json | level="error"

# Rate of log lines
rate({job="syslog"}[5m])

# Count errors per service
sum by (service) (count_over_time({job="syslog"} |= "error" [5m]))

# Top 10 error messages
topk(10, sum by (msg) (count_over_time({job="syslog"} |= "error" [1h])))
```

## License

MIT License - See collection LICENSE file for details.
