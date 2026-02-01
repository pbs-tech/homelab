# Homelab Infrastructure API Documentation

Comprehensive API reference for all services in the homelab infrastructure. This document provides base URLs, authentication methods, common endpoints, and usage examples for programmatic access to homelab services.

## Table of Contents

- [1. Proxmox API](#1-proxmox-api)
- [2. Kubernetes (K3s) API](#2-kubernetes-k3s-api)
- [3. Traefik API](#3-traefik-api)
- [4. Prometheus API](#4-prometheus-api)
- [5. Grafana API](#5-grafana-api)
- [6. Home Assistant API](#6-home-assistant-api)
- [7. AdGuard Home API](#7-adguard-home-api)
- [8. AlertManager API](#8-alertmanager-api)
- [9. Loki API](#9-loki-api)
- [10. Media Services APIs](#10-media-services-apis)

---

## 1. Proxmox API

The Proxmox Virtual Environment API provides programmatic access to VM and LXC container management.

### Base Information

- **Host Nodes**: pve-mac (192.168.0.56), pve-nas (192.168.0.57)
- **Base URL**: `https://192.168.0.56:8006/api2/json` or `https://192.168.0.57:8006/api2/json`
- **Web UI**: `https://192.168.0.56:8006` or `https://192.168.0.57:8006`
- **Default Port**: 8006 (HTTPS)

### Authentication

Proxmox supports multiple authentication methods. This homelab uses **API tokens** for automation.

#### API Token Authentication

1. **Creating API Tokens** (via Web UI):
   - Navigate to Datacenter → Permissions → API Tokens
   - Click "Add" and create a token with required privileges
   - Required privileges: `VM.Allocate, VM.Config.*, VM.Console, VM.PowerMgmt, Datastore.AllocateSpace, Sys.Audit`

2. **Token Format**:
   ```
   TOKEN_ID: user@realm!tokenname
   TOKEN_SECRET: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```

3. **Vault Variables** (configured in `inventory/group_vars/all/vault.yml`):
   ```yaml
   vault_proxmox_api_tokens:
     pve_mac:
       token_id: "ansible@pam!automation"
       token_secret: "your-secret-here"
     pve_nas:
       token_id: "ansible@pam!automation"
       token_secret: "your-secret-here"
   ```

#### Using API Tokens

**HTTP Header Method**:
```bash
curl -k -H "Authorization: PVEAPIToken=ansible@pam!automation=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
  https://192.168.0.56:8006/api2/json/version
```

**Python Example**:
```python
import requests

headers = {
    'Authorization': 'PVEAPIToken=ansible@pam!automation=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
}

response = requests.get(
    'https://192.168.0.56:8006/api2/json/version',
    headers=headers,
    verify=False
)
print(response.json())
```

### Common Endpoints

#### Cluster and Node Information

```bash
# Get cluster status
curl -k -H "Authorization: PVEAPIToken=USER!TOKEN=SECRET" \
  https://192.168.0.56:8006/api2/json/cluster/status

# Get node information
curl -k -H "Authorization: PVEAPIToken=USER!TOKEN=SECRET" \
  https://192.168.0.56:8006/api2/json/nodes/pve-mac/status

# List all VMs and containers
curl -k -H "Authorization: PVEAPIToken=USER!TOKEN=SECRET" \
  https://192.168.0.56:8006/api2/json/cluster/resources
```

#### LXC Container Management

```bash
# List containers on a node
curl -k -H "Authorization: PVEAPIToken=USER!TOKEN=SECRET" \
  https://192.168.0.56:8006/api2/json/nodes/pve-mac/lxc

# Get container status
curl -k -H "Authorization: PVEAPIToken=USER!TOKEN=SECRET" \
  https://192.168.0.56:8006/api2/json/nodes/pve-mac/lxc/200/status/current

# Start a container
curl -k -X POST -H "Authorization: PVEAPIToken=USER!TOKEN=SECRET" \
  https://192.168.0.56:8006/api2/json/nodes/pve-mac/lxc/200/status/start

# Stop a container
curl -k -X POST -H "Authorization: PVEAPIToken=USER!TOKEN=SECRET" \
  https://192.168.0.56:8006/api2/json/nodes/pve-mac/lxc/200/status/stop

# Get container configuration
curl -k -H "Authorization: PVEAPIToken=USER!TOKEN=SECRET" \
  https://192.168.0.56:8006/api2/json/nodes/pve-mac/lxc/200/config
```

#### Storage and Templates

```bash
# List storage
curl -k -H "Authorization: PVEAPIToken=USER!TOKEN=SECRET" \
  https://192.168.0.56:8006/api2/json/storage

# List LXC templates
curl -k -H "Authorization: PVEAPIToken=USER!TOKEN=SECRET" \
  https://192.168.0.56:8006/api2/json/nodes/pve-mac/storage/local/content?content=vztmpl
```

### Troubleshooting

**Common Issues**:

1. **SSL Certificate Errors**: Use `-k` or `verify=False` for self-signed certificates
2. **Permission Denied**: Ensure API token has required privileges
3. **Invalid Token**: Verify token format and expiration

**Test Authentication**:
```bash
# Test token validity
curl -k -H "Authorization: PVEAPIToken=USER!TOKEN=SECRET" \
  https://192.168.0.56:8006/api2/json/version

# Expected output: {"data":{"release":"8.1","version":"8.1.3","repoid":"..."}}
```

**Debugging**:
```bash
# Enable verbose output
curl -v -k -H "Authorization: PVEAPIToken=USER!TOKEN=SECRET" \
  https://192.168.0.56:8006/api2/json/version 2>&1 | grep -E "^>|^<"
```

---

## 2. Kubernetes (K3s) API

The K3s Kubernetes API provides cluster management and workload orchestration capabilities.

### Base Information

- **Server Node**: k3-01 (192.168.0.111)
- **Agent Nodes**: k3-02 (192.168.0.112), k3-03 (192.168.0.113), k3-04 (192.168.0.114)
- **API Server URL**: `https://192.168.0.111:6443`
- **Default Port**: 6443 (HTTPS)

### Authentication

K3s uses kubeconfig files with client certificates for authentication.

#### Kubeconfig File

Located on server node at `/etc/rancher/k3s/k3s.yaml`:

```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTi...
    server: https://192.168.0.111:6443
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
users:
- name: default
  user:
    client-certificate-data: LS0tLS1CRUdJTi...
    client-key-data: LS0tLS1CRUdJTi...
```

#### Accessing the API

**From Control Node** (after kubeconfig distribution):
```bash
# Set KUBECONFIG environment variable
export KUBECONFIG=~/.kube/config

# Test connection
kubectl cluster-info

# Get cluster version
kubectl version
```

**From Server Node**:
```bash
# Use k3s wrapper (no kubeconfig needed)
k3s kubectl get nodes

# Or export kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

#### Service Account Tokens

For application access, use service account tokens:

```bash
# Create service account
kubectl create serviceaccount my-app

# Create role binding
kubectl create clusterrolebinding my-app \
  --clusterrole=cluster-admin \
  --serviceaccount=default:my-app

# Get service account token
kubectl get secret $(kubectl get serviceaccount my-app -o jsonpath='{.secrets[0].name}') \
  -o jsonpath='{.data.token}' | base64 -d
```

### Common Endpoints

#### Cluster Information

```bash
# Get API version
curl -k https://192.168.0.111:6443/version

# Get API resources (requires authentication)
kubectl api-resources

# Get cluster info
kubectl cluster-info
```

#### Node Management

```bash
# List all nodes
kubectl get nodes

# Get detailed node info
kubectl get nodes -o wide

# Describe node
kubectl describe node k3-01

# Get node metrics (requires metrics-server)
kubectl top nodes
```

#### Pod and Workload Management

```bash
# List pods in all namespaces
kubectl get pods -A

# Get pods in specific namespace
kubectl get pods -n kube-system

# Get pod logs
kubectl logs <pod-name> -n <namespace>

# Execute command in pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Get deployments
kubectl get deployments -A

# Get services
kubectl get services -A
```

#### REST API Access (with Bearer Token)

```bash
# Set token variable
TOKEN=$(kubectl get secret $(kubectl get serviceaccount default -o jsonpath='{.secrets[0].name}') \
  -o jsonpath='{.data.token}' | base64 -d)

# List namespaces
curl -k -H "Authorization: Bearer $TOKEN" \
  https://192.168.0.111:6443/api/v1/namespaces

# List pods
curl -k -H "Authorization: Bearer $TOKEN" \
  https://192.168.0.111:6443/api/v1/namespaces/default/pods

# Get specific pod
curl -k -H "Authorization: Bearer $TOKEN" \
  https://192.168.0.111:6443/api/v1/namespaces/default/pods/<pod-name>
```

### Troubleshooting

**Connection Issues**:
```bash
# Test API server connectivity
telnet 192.168.0.111 6443

# Check server certificate
openssl s_client -connect 192.168.0.111:6443 -showcerts

# Verify kubeconfig
kubectl config view

# Check current context
kubectl config current-context
```

**Authentication Problems**:
```bash
# Verify certificate validity
kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}' | base64 -d | openssl x509 -text

# Check cluster access
kubectl auth can-i get pods

# Test with verbose output
kubectl get nodes -v=8
```

**Common Errors**:

1. **"The connection to the server was refused"**: API server not running or firewall blocking
2. **"x509: certificate signed by unknown authority"**: Kubeconfig certificate mismatch
3. **"Unauthorized"**: Invalid or expired credentials

---

## 3. Traefik API

Traefik reverse proxy provides a dashboard and API for monitoring and configuration management.

### Base Information

- **Container ID**: 205
- **IP Address**: 192.168.0.205
- **Dashboard URL**: `http://192.168.0.205:8080` or `https://traefik.homelab.local`
- **API Port**: 8080
- **HTTP Port**: 80
- **HTTPS Port**: 443

### Authentication

The Traefik API and dashboard can be secured with basic authentication or OAuth.

#### Basic Authentication (Optional)

If enabled in configuration:
```yaml
# In Traefik dynamic configuration
http:
  middlewares:
    api-auth:
      basicAuth:
        users:
          - "admin:$2y$10$encrypted_password_hash"
```

#### Accessing Without Authentication

For internal homelab use, dashboard is typically accessible without authentication:
```bash
# Dashboard
http://192.168.0.205:8080/dashboard/

# API
http://192.168.0.205:8080/api/
```

### Common Endpoints

#### Overview and Health

```bash
# API health check
curl -s http://192.168.0.205:8080/ping
# Expected: OK

# Get Traefik version
curl -s http://192.168.0.205:8080/api/version | jq .

# Get overview
curl -s http://192.168.0.205:8080/api/overview | jq .
```

#### Routers

```bash
# List all HTTP routers
curl -s http://192.168.0.205:8080/api/http/routers | jq .

# Get specific router
curl -s http://192.168.0.205:8080/api/http/routers/prometheus@docker | jq .

# List TCP routers
curl -s http://192.168.0.205:8080/api/tcp/routers | jq .
```

#### Services

```bash
# List all HTTP services
curl -s http://192.168.0.205:8080/api/http/services | jq .

# Get service details
curl -s http://192.168.0.205:8080/api/http/services/prometheus@docker | jq .

# Check service load balancer servers
curl -s http://192.168.0.205:8080/api/http/services/prometheus@docker/loadBalancer/servers | jq .
```

#### Middlewares

```bash
# List all middlewares
curl -s http://192.168.0.205:8080/api/http/middlewares | jq .

# Get middleware details
curl -s http://192.168.0.205:8080/api/http/middlewares/compress@file | jq .
```

#### Certificates

```bash
# List TLS certificates
curl -s http://192.168.0.205:8080/api/http/routers | jq '[.[] | select(.tls)] | .[].tls'

# Get certificate details (via raw configuration)
curl -s http://192.168.0.205:8080/api/rawdata | jq .tlsStores
```

#### Entry Points

```bash
# Get entry points configuration
curl -s http://192.168.0.205:8080/api/rawdata | jq .entryPoints
```

### Usage Examples

#### Monitor Active Routes

```bash
# Get all active HTTP routers with status
curl -s http://192.168.0.205:8080/api/http/routers | \
  jq '.[] | {name: .name, rule: .rule, service: .service, status: .status}'

# Count active routers
curl -s http://192.168.0.205:8080/api/http/routers | jq 'length'
```

#### Check Service Health

```bash
# Get service status and backend servers
curl -s http://192.168.0.205:8080/api/http/services | \
  jq '.[] | {name: .name, status: .status, servers: .loadBalancer.servers}'
```

#### List All Domains

```bash
# Extract all routed domains
curl -s http://192.168.0.205:8080/api/http/routers | \
  jq -r '.[] | .rule' | grep -oP '(?<=Host\(`).*?(?=`\))'
```

### Troubleshooting

**Dashboard Access Issues**:
```bash
# Check if Traefik is listening on port 8080
pct exec 205 -- ss -tlnp | grep 8080

# Check service status
pct exec 205 -- systemctl status traefik

# View Traefik logs
pct exec 205 -- journalctl -u traefik -f
```

**Service Discovery Problems**:
```bash
# Check provider configuration
curl -s http://192.168.0.205:8080/api/rawdata | jq .providers

# Verify Docker socket access (if using Docker provider)
pct exec 205 -- docker ps

# Check file provider for static routes
pct exec 205 -- cat /etc/traefik/dynamic.yml
```

**Certificate Issues**:
```bash
# Check Let's Encrypt account
pct exec 205 -- cat /etc/traefik/acme.json | jq .

# View certificate domains
pct exec 205 -- cat /etc/traefik/acme.json | jq '.letsencrypt.Certificates[].domain'

# Force certificate renewal (restart Traefik)
pct exec 205 -- systemctl restart traefik
```

---

## 4. Prometheus API

Prometheus provides a powerful HTTP API for querying metrics and managing the monitoring system.

### Base Information

- **Container ID**: 200
- **IP Address**: 192.168.0.200
- **Base URL**: `http://192.168.0.200:9090`
- **Web UI**: `http://192.168.0.200:9090` or `https://prometheus.homelab.local`
- **Default Port**: 9090

### Authentication

Prometheus by default has no authentication. For production use, access through Traefik with basic auth middleware.

#### Accessing via Traefik (with authentication)

```bash
# If basic auth is enabled on Traefik
curl -u admin:password https://prometheus.homelab.local/api/v1/query?query=up
```

### Common Endpoints

#### Health and Status

```bash
# Check Prometheus health
curl -s http://192.168.0.200:9090/api/v1/status/config | jq .

# Get runtime information
curl -s http://192.168.0.200:9090/api/v1/status/runtimeinfo | jq .

# Get build information
curl -s http://192.168.0.200:9090/api/v1/status/buildinfo | jq .

# Get TSDB status
curl -s http://192.168.0.200:9090/api/v1/status/tsdb | jq .

# Check flags
curl -s http://192.168.0.200:9090/api/v1/status/flags | jq .
```

#### Query API

```bash
# Instant query
curl -s 'http://192.168.0.200:9090/api/v1/query?query=up' | jq .

# Query with time parameter
curl -s 'http://192.168.0.200:9090/api/v1/query?query=up&time=2024-01-01T00:00:00Z' | jq .

# Range query
curl -s 'http://192.168.0.200:9090/api/v1/query_range?query=node_memory_MemAvailable_bytes&start=2024-01-01T00:00:00Z&end=2024-01-01T01:00:00Z&step=15s' | jq .

# Query with URL encoding
curl -s --data-urlencode 'query=sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)' \
  'http://192.168.0.200:9090/api/v1/query' | jq .
```

#### Metadata

```bash
# List all metric names
curl -s http://192.168.0.200:9090/api/v1/label/__name__/values | jq .

# Get label names
curl -s http://192.168.0.200:9090/api/v1/labels | jq .

# Get label values for specific label
curl -s http://192.168.0.200:9090/api/v1/label/job/values | jq .

# Get metric metadata
curl -s http://192.168.0.200:9090/api/v1/metadata | jq .

# Get series matching label selectors
curl -s 'http://192.168.0.200:9090/api/v1/series?match[]=up&match[]=node_cpu_seconds_total' | jq .
```

#### Targets and Service Discovery

```bash
# Get all targets
curl -s http://192.168.0.200:9090/api/v1/targets | jq .

# Get only active targets
curl -s http://192.168.0.200:9090/api/v1/targets | \
  jq '.data.activeTargets[] | {job: .labels.job, health: .health, lastScrape: .lastScrape}'

# Get dropped targets
curl -s http://192.168.0.200:9090/api/v1/targets | jq '.data.droppedTargets'

# Get service discovery info
curl -s http://192.168.0.200:9090/api/v1/targets/metadata | jq .
```

#### Alerts and Rules

```bash
# Get active alerts
curl -s http://192.168.0.200:9090/api/v1/alerts | jq .

# Get alert rules
curl -s http://192.168.0.200:9090/api/v1/rules | jq .

# Get specific rule group
curl -s 'http://192.168.0.200:9090/api/v1/rules?type=alert' | jq .
```

### Usage Examples

#### Common PromQL Queries

```bash
# CPU usage per node
curl -s --data-urlencode 'query=100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)' \
  'http://192.168.0.200:9090/api/v1/query' | jq .

# Memory usage percentage
curl -s --data-urlencode 'query=100 - ((node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100)' \
  'http://192.168.0.200:9090/api/v1/query' | jq .

# Disk usage
curl -s --data-urlencode 'query=100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)' \
  'http://192.168.0.200:9090/api/v1/query' | jq .

# Service uptime in hours
curl -s --data-urlencode 'query=(time() - process_start_time_seconds) / 3600' \
  'http://192.168.0.200:9090/api/v1/query' | jq .
```

#### Python Example

```python
import requests
from datetime import datetime, timedelta

PROMETHEUS_URL = "http://192.168.0.200:9090"

def query_prometheus(query):
    response = requests.get(
        f"{PROMETHEUS_URL}/api/v1/query",
        params={'query': query}
    )
    return response.json()

def query_range(query, start, end, step='15s'):
    response = requests.get(
        f"{PROMETHEUS_URL}/api/v1/query_range",
        params={
            'query': query,
            'start': start.isoformat(),
            'end': end.isoformat(),
            'step': step
        }
    )
    return response.json()

# Example: Get current CPU usage
result = query_prometheus('100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)')
print(result)

# Example: Get memory usage over last hour
end = datetime.now()
start = end - timedelta(hours=1)
result = query_range('node_memory_MemAvailable_bytes', start, end)
print(result)
```

### Troubleshooting

**Query Performance**:
```bash
# Check query statistics
curl -s http://192.168.0.200:9090/api/v1/status/runtimeinfo | jq .

# Monitor slow queries in logs
pct exec 200 -- journalctl -u prometheus | grep -i "slow"
```

**Scraping Issues**:
```bash
# Check scrape errors
curl -s http://192.168.0.200:9090/api/v1/targets | \
  jq '.data.activeTargets[] | select(.health != "up") | {job: .labels.job, error: .lastError}'

# Test scrape endpoint manually
curl -s http://192.168.0.111:9100/metrics | head -20
```

**Storage Issues**:
```bash
# Check TSDB stats
curl -s http://192.168.0.200:9090/api/v1/status/tsdb | jq .

# Check disk usage
pct exec 200 -- df -h /var/lib/prometheus

# View data directory size
pct exec 200 -- du -sh /var/lib/prometheus/*
```

---

## 5. Grafana API

Grafana provides a comprehensive REST API for managing dashboards, datasources, users, and organizations.

### Base Information

- **Container ID**: 201
- **IP Address**: 192.168.0.201
- **Base URL**: `http://192.168.0.201:3000/api`
- **Web UI**: `http://192.168.0.201:3000` or `https://grafana.homelab.local`
- **Default Port**: 3000

### Authentication

Grafana supports multiple authentication methods for API access.

#### Basic Authentication

```bash
# Using admin credentials
curl -u admin:${GRAFANA_PASSWORD} http://192.168.0.201:3000/api/org
```

#### API Key Authentication

1. **Create API Key** (via Web UI):
   - Settings → API Keys → Add API Key
   - Set role (Viewer, Editor, or Admin)
   - Copy generated key

2. **Using API Key**:
```bash
# Bearer token method
curl -H "Authorization: Bearer eyJrIjoiT0tTcG1pUlY2RnVKZTFVaDFsNFZXdE9ZWmNrMkZYbk" \
  http://192.168.0.201:3000/api/dashboards/home

# Header method
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://192.168.0.201:3000/api/org
```

#### Service Account Tokens (Grafana 9+)

More secure alternative to API keys:
```bash
# Create service account via API
curl -X POST -H "Content-Type: application/json" \
  -d '{"name":"automation","role":"Admin"}' \
  -u admin:password http://192.168.0.201:3000/api/serviceaccounts

# Create token for service account
curl -X POST -H "Content-Type: application/json" \
  -d '{"name":"token1"}' \
  -u admin:password http://192.168.0.201:3000/api/serviceaccounts/1/tokens
```

### Common Endpoints

#### Health and Status

```bash
# Health check
curl -s http://192.168.0.201:3000/api/health | jq .

# Get Grafana version and settings
curl -s http://192.168.0.201:3000/api/frontend/settings | jq .

# Get current org
curl -s -u admin:password http://192.168.0.201:3000/api/org | jq .

# Get user info
curl -s -u admin:password http://192.168.0.201:3000/api/user | jq .
```

#### Datasources

```bash
# List all datasources
curl -s -u admin:password http://192.168.0.201:3000/api/datasources | jq .

# Get datasource by ID
curl -s -u admin:password http://192.168.0.201:3000/api/datasources/1 | jq .

# Get datasource by name
curl -s -u admin:password http://192.168.0.201:3000/api/datasources/name/Prometheus | jq .

# Test datasource
curl -s -u admin:password http://192.168.0.201:3000/api/datasources/1/health | jq .

# Create datasource
curl -X POST -H "Content-Type: application/json" \
  -u admin:password \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://192.168.0.200:9090",
    "access": "proxy",
    "isDefault": true
  }' \
  http://192.168.0.201:3000/api/datasources

# Update datasource
curl -X PUT -H "Content-Type: application/json" \
  -u admin:password \
  -d '{"name":"Prometheus","type":"prometheus","url":"http://192.168.0.200:9090","access":"proxy"}' \
  http://192.168.0.201:3000/api/datasources/1

# Delete datasource
curl -X DELETE -u admin:password http://192.168.0.201:3000/api/datasources/1
```

#### Dashboards

```bash
# Search dashboards
curl -s -u admin:password http://192.168.0.201:3000/api/search | jq .

# Search with query
curl -s -u admin:password 'http://192.168.0.201:3000/api/search?query=node' | jq .

# Get dashboard by UID
curl -s -u admin:password http://192.168.0.201:3000/api/dashboards/uid/prometheus-overview | jq .

# Get dashboard by slug
curl -s -u admin:password http://192.168.0.201:3000/api/dashboards/db/prometheus-overview | jq .

# Get home dashboard
curl -s -u admin:password http://192.168.0.201:3000/api/dashboards/home | jq .

# Create or update dashboard
curl -X POST -H "Content-Type: application/json" \
  -u admin:password \
  -d @dashboard.json \
  http://192.168.0.201:3000/api/dashboards/db

# Delete dashboard by UID
curl -X DELETE -u admin:password http://192.168.0.201:3000/api/dashboards/uid/prometheus-overview

# Get dashboard tags
curl -s -u admin:password http://192.168.0.201:3000/api/dashboards/tags | jq .
```

#### Folders

```bash
# List all folders
curl -s -u admin:password http://192.168.0.201:3000/api/folders | jq .

# Get folder by UID
curl -s -u admin:password http://192.168.0.201:3000/api/folders/homelab | jq .

# Create folder
curl -X POST -H "Content-Type: application/json" \
  -u admin:password \
  -d '{"title":"Homelab","uid":"homelab"}' \
  http://192.168.0.201:3000/api/folders
```

#### Users and Organizations

```bash
# List all users (admin only)
curl -s -u admin:password http://192.168.0.201:3000/api/users | jq .

# Get user by ID
curl -s -u admin:password http://192.168.0.201:3000/api/users/1 | jq .

# Create user
curl -X POST -H "Content-Type: application/json" \
  -u admin:password \
  -d '{"name":"User","email":"user@example.com","login":"user","password":"password"}' \
  http://192.168.0.201:3000/api/admin/users

# List organizations
curl -s -u admin:password http://192.168.0.201:3000/api/orgs | jq .
```

#### Snapshots

```bash
# Create snapshot
curl -X POST -H "Content-Type: application/json" \
  -u admin:password \
  -d @dashboard.json \
  http://192.168.0.201:3000/api/snapshots

# Get snapshot
curl -s http://192.168.0.201:3000/api/snapshots/SNAPSHOT_KEY | jq .

# Delete snapshot
curl -X DELETE -u admin:password http://192.168.0.201:3000/api/snapshots/SNAPSHOT_KEY
```

#### Annotations

```bash
# Get annotations
curl -s -u admin:password 'http://192.168.0.201:3000/api/annotations?from=1609459200000&to=1609545600000' | jq .

# Create annotation
curl -X POST -H "Content-Type: application/json" \
  -u admin:password \
  -d '{
    "time": 1609459200000,
    "text": "Deployment started",
    "tags": ["deployment"]
  }' \
  http://192.168.0.201:3000/api/annotations
```

### Usage Examples

#### Import Dashboard from Grafana.com

```bash
# Import dashboard 1860 (Node Exporter Full)
curl -X POST -H "Content-Type: application/json" \
  -u admin:password \
  -d '{
    "dashboard": {
      "id": null,
      "uid": null,
      "title": "Node Exporter Full",
      "tags": ["prometheus"],
      "timezone": "browser",
      "schemaVersion": 16
    },
    "folderId": 0,
    "overwrite": true,
    "inputs": [
      {
        "name": "DS_PROMETHEUS",
        "type": "datasource",
        "pluginId": "prometheus",
        "value": "Prometheus"
      }
    ]
  }' \
  http://192.168.0.201:3000/api/dashboards/import
```

#### Python Example

```python
import requests
import json

GRAFANA_URL = "http://192.168.0.201:3000"
GRAFANA_API_KEY = "your-api-key-here"

headers = {
    'Authorization': f'Bearer {GRAFANA_API_KEY}',
    'Content-Type': 'application/json'
}

def get_dashboards():
    response = requests.get(
        f"{GRAFANA_URL}/api/search",
        headers=headers
    )
    return response.json()

def create_datasource(name, url):
    data = {
        "name": name,
        "type": "prometheus",
        "url": url,
        "access": "proxy",
        "isDefault": True
    }
    response = requests.post(
        f"{GRAFANA_URL}/api/datasources",
        headers=headers,
        json=data
    )
    return response.json()

# Example usage
dashboards = get_dashboards()
print(f"Found {len(dashboards)} dashboards")

# Create Prometheus datasource
result = create_datasource("Prometheus", "http://192.168.0.200:9090")
print(result)
```

### Troubleshooting

**Authentication Issues**:
```bash
# Test credentials
curl -v -u admin:password http://192.168.0.201:3000/api/org 2>&1 | grep -E "HTTP|401|200"

# Reset admin password
pct exec 201 -- grafana-cli admin reset-admin-password newpassword

# Check API key validity
curl -H "Authorization: Bearer YOUR_API_KEY" http://192.168.0.201:3000/api/user
```

**Datasource Connection**:
```bash
# Test datasource connectivity from Grafana container
pct exec 201 -- curl -s http://192.168.0.200:9090/api/v1/query?query=up | head

# Check datasource health via API
curl -s -u admin:password http://192.168.0.201:3000/api/datasources/1/health | jq .
```

**Database Issues**:
```bash
# Check Grafana database
pct exec 201 -- sqlite3 /var/lib/grafana/grafana.db ".tables"

# List users
pct exec 201 -- sqlite3 /var/lib/grafana/grafana.db "SELECT * FROM user;"
```

---

## 6. Home Assistant API

Home Assistant provides a comprehensive REST API and WebSocket API for home automation control and monitoring.

### Base Information

- **Container ID**: 208
- **IP Address**: 192.168.0.208
- **Base URL**: `http://192.168.0.208:8123/api`
- **Web UI**: `http://192.168.0.208:8123` or `https://homeassistant.homelab.local`
- **WebSocket**: `ws://192.168.0.208:8123/api/websocket`
- **Default Port**: 8123

### Authentication

Home Assistant uses Long-Lived Access Tokens for API authentication.

#### Creating Access Token

1. **Via Web UI**:
   - Navigate to Profile → Long-Lived Access Tokens
   - Click "Create Token"
   - Name the token and copy the generated token

2. **Token Format**:
   ```
   eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJ...
   ```

#### Using Access Token

```bash
# Bearer token method
curl -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  http://192.168.0.208:8123/api/

# Header format
curl -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  http://192.168.0.208:8123/api/states
```

### Common Endpoints

#### Health and Status

```bash
# API health check
curl -H "Authorization: Bearer TOKEN" \
  http://192.168.0.208:8123/api/ | jq .

# Get configuration
curl -H "Authorization: Bearer TOKEN" \
  http://192.168.0.208:8123/api/config | jq .

# Discovery info
curl -H "Authorization: Bearer TOKEN" \
  http://192.168.0.208:8123/api/discovery_info | jq .

# Check if config is valid
curl -X POST -H "Authorization: Bearer TOKEN" \
  http://192.168.0.208:8123/api/config/core/check_config | jq .
```

#### States

```bash
# Get all entity states
curl -H "Authorization: Bearer TOKEN" \
  http://192.168.0.208:8123/api/states | jq .

# Get specific entity state
curl -H "Authorization: Bearer TOKEN" \
  http://192.168.0.208:8123/api/states/light.living_room | jq .

# Update entity state
curl -X POST -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"state": "on", "attributes": {"brightness": 255}}' \
  http://192.168.0.208:8123/api/states/light.living_room
```

#### Services

```bash
# List all services
curl -H "Authorization: Bearer TOKEN" \
  http://192.168.0.208:8123/api/services | jq .

# Call a service (turn on light)
curl -X POST -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "light.living_room"}' \
  http://192.168.0.208:8123/api/services/light/turn_on

# Call service with parameters
curl -X POST -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "entity_id": "light.living_room",
    "brightness": 200,
    "rgb_color": [255, 0, 0]
  }' \
  http://192.168.0.208:8123/api/services/light/turn_on

# Turn off light
curl -X POST -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "light.living_room"}' \
  http://192.168.0.208:8123/api/services/light/turn_off
```

#### Events

```bash
# Get event types
curl -H "Authorization: Bearer TOKEN" \
  http://192.168.0.208:8123/api/events | jq .

# Fire custom event
curl -X POST -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "Custom event triggered"}' \
  http://192.168.0.208:8123/api/events/my_custom_event
```

#### History

```bash
# Get history for all entities (last 24 hours)
curl -H "Authorization: Bearer TOKEN" \
  http://192.168.0.208:8123/api/history/period | jq .

# Get history for specific entity
curl -H "Authorization: Bearer TOKEN" \
  'http://192.168.0.208:8123/api/history/period?filter_entity_id=sensor.temperature' | jq .

# Get history with time range
curl -H "Authorization: Bearer TOKEN" \
  'http://192.168.0.208:8123/api/history/period/2024-01-01T00:00:00?end_time=2024-01-02T00:00:00' | jq .
```

#### Logbook

```bash
# Get logbook entries
curl -H "Authorization: Bearer TOKEN" \
  http://192.168.0.208:8123/api/logbook | jq .

# Get logbook for specific entity
curl -H "Authorization: Bearer TOKEN" \
  'http://192.168.0.208:8123/api/logbook?entity=light.living_room' | jq .
```

#### Error Log

```bash
# Get error log
curl -H "Authorization: Bearer TOKEN" \
  http://192.168.0.208:8123/api/error_log
```

### WebSocket API

For real-time updates and more efficient communication:

```python
import asyncio
import websockets
import json

async def connect_home_assistant():
    uri = "ws://192.168.0.208:8123/api/websocket"
    async with websockets.connect(uri) as websocket:
        # Receive auth required message
        auth_required = await websocket.recv()
        print(f"< {auth_required}")

        # Send auth message
        await websocket.send(json.dumps({
            "type": "auth",
            "access_token": "YOUR_ACCESS_TOKEN"
        }))

        # Receive auth result
        auth_result = await websocket.recv()
        print(f"< {auth_result}")

        # Subscribe to state changes
        await websocket.send(json.dumps({
            "id": 1,
            "type": "subscribe_events",
            "event_type": "state_changed"
        }))

        # Listen for events
        while True:
            message = await websocket.recv()
            print(f"< {message}")

asyncio.get_event_loop().run_until_complete(connect_home_assistant())
```

### Usage Examples

#### Python REST API Example

```python
import requests

HA_URL = "http://192.168.0.208:8123/api"
HA_TOKEN = "your-access-token"

headers = {
    "Authorization": f"Bearer {HA_TOKEN}",
    "Content-Type": "application/json"
}

def get_states():
    response = requests.get(f"{HA_URL}/states", headers=headers)
    return response.json()

def turn_on_light(entity_id, brightness=255):
    data = {
        "entity_id": entity_id,
        "brightness": brightness
    }
    response = requests.post(
        f"{HA_URL}/services/light/turn_on",
        headers=headers,
        json=data
    )
    return response.json()

def get_entity_history(entity_id, hours=24):
    response = requests.get(
        f"{HA_URL}/history/period",
        headers=headers,
        params={"filter_entity_id": entity_id}
    )
    return response.json()

# Example usage
states = get_states()
print(f"Total entities: {len(states)}")

# Turn on light
result = turn_on_light("light.living_room", brightness=200)
print(result)
```

### Troubleshooting

**Connection Issues**:
```bash
# Check if Home Assistant is accessible
curl -I http://192.168.0.208:8123

# Check service status
pct exec 208 -- systemctl status homeassistant

# View logs
pct exec 208 -- journalctl -u homeassistant -f
```

**Authentication Problems**:
```bash
# Test token validity
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://192.168.0.208:8123/api/ | jq .

# Expected response: {"message": "API running."}
# If 401: Token invalid or expired
```

**Integration Issues**:
```bash
# Check configuration
pct exec 208 -- docker exec homeassistant hass --script check_config

# View integration errors
curl -H "Authorization: Bearer TOKEN" \
  http://192.168.0.208:8123/api/error_log | grep -i integration
```

---

## 7. AdGuard Home API

AdGuard Home provides a REST API for DNS filtering management, statistics, and configuration.

### Base Information

- **Container ID**: 204
- **IP Address**: 192.168.0.204
- **Base URL**: `http://192.168.0.204/control`
- **Web UI**: `http://192.168.0.204` or `https://adguard.homelab.local`
- **DNS Port**: 53
- **Web Port**: 80/443
- **Initial Setup Port**: 3000

### Authentication

AdGuard Home uses Basic HTTP authentication.

#### Credentials

- **Username**: admin (default)
- **Password**: Set during initial setup or via `vault_adguard_admin_password`

#### Using Authentication

```bash
# Basic auth method
curl -u admin:password http://192.168.0.204/control/status

# With credentials in URL (not recommended for production)
curl http://admin:password@192.168.0.204/control/status
```

### Common Endpoints

#### Status and Health

```bash
# Get AdGuard status
curl -u admin:password http://192.168.0.204/control/status | jq .

# Get DNS status
curl -u admin:password http://192.168.0.204/control/dns_info | jq .

# Get version info
curl -u admin:password http://192.168.0.204/control/status | jq '.version'
```

#### Statistics

```bash
# Get query statistics
curl -u admin:password http://192.168.0.204/control/stats | jq .

# Get statistics for specific time period
curl -u admin:password 'http://192.168.0.204/control/stats?time_unit=hours&time_period=24' | jq .

# Reset statistics
curl -X POST -u admin:password http://192.168.0.204/control/stats_reset

# Get top blocked domains
curl -u admin:password http://192.168.0.204/control/stats | jq '.top_blocked_domains'

# Get top queried domains
curl -u admin:password http://192.168.0.204/control/stats | jq '.top_queried_domains'

# Get top clients
curl -u admin:password http://192.168.0.204/control/stats | jq '.top_clients'
```

#### Query Log

```bash
# Get query log
curl -u admin:password http://192.168.0.204/control/querylog | jq .

# Get query log with parameters
curl -u admin:password 'http://192.168.0.204/control/querylog?older_than=2024-01-01T00:00:00Z' | jq .

# Clear query log
curl -X POST -u admin:password http://192.168.0.204/control/querylog_clear

# Get query log config
curl -u admin:password http://192.168.0.204/control/querylog_info | jq .
```

#### Filtering

```bash
# Get filtering status
curl -u admin:password http://192.168.0.204/control/filtering/status | jq .

# Enable filtering
curl -X POST -u admin:password \
  -H "Content-Type: application/json" \
  -d '{"enabled": true}' \
  http://192.168.0.204/control/filtering/config

# Disable filtering
curl -X POST -u admin:password \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}' \
  http://192.168.0.204/control/filtering/config

# Get filter lists
curl -u admin:password http://192.168.0.204/control/filtering/status | jq '.filters'

# Add filter list
curl -X POST -u admin:password \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com/blocklist.txt",
    "name": "Custom Blocklist",
    "enabled": true
  }' \
  http://192.168.0.204/control/filtering/add_url

# Refresh filters
curl -X POST -u admin:password \
  -H "Content-Type: application/json" \
  -d '{"whitelist": false}' \
  http://192.168.0.204/control/filtering/refresh
```

#### Blocklist and Allowlist

```bash
# Add custom rule to blocklist
curl -X POST -u admin:password \
  -H "Content-Type: application/json" \
  -d '{"text": "||example.com^"}' \
  http://192.168.0.204/control/filtering/add_url

# Get custom rules
curl -u admin:password http://192.168.0.204/control/filtering/status | jq '.user_rules'

# Add to allowlist
curl -X POST -u admin:password \
  -H "Content-Type: application/json" \
  -d '{"text": "@@||trusted-site.com^"}' \
  http://192.168.0.204/control/filtering/add_url
```

#### DNS Rewrites

```bash
# Get DNS rewrites
curl -u admin:password http://192.168.0.204/control/rewrite/list | jq .

# Add DNS rewrite
curl -X POST -u admin:password \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "*.homelab.local",
    "answer": "192.168.0.205"
  }' \
  http://192.168.0.204/control/rewrite/add

# Delete DNS rewrite
curl -X POST -u admin:password \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "*.homelab.local",
    "answer": "192.168.0.205"
  }' \
  http://192.168.0.204/control/rewrite/delete
```

#### Clients

```bash
# Get clients
curl -u admin:password http://192.168.0.204/control/clients | jq .

# Add client with custom settings
curl -X POST -u admin:password \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Device Name",
    "ids": ["192.168.0.100"],
    "use_global_settings": false,
    "filtering_enabled": true,
    "blocked_services": ["youtube", "facebook"]
  }' \
  http://192.168.0.204/control/clients/add

# Update client
curl -X POST -u admin:password \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Device Name",
    "data": {
      "ids": ["192.168.0.100"],
      "use_global_settings": true
    }
  }' \
  http://192.168.0.204/control/clients/update

# Delete client
curl -X POST -u admin:password \
  -H "Content-Type: application/json" \
  -d '{"name": "Device Name"}' \
  http://192.168.0.204/control/clients/delete
```

### Usage Examples

#### Python Example

```python
import requests
from requests.auth import HTTPBasicAuth

ADGUARD_URL = "http://192.168.0.204/control"
USERNAME = "admin"
PASSWORD = "your-password"

auth = HTTPBasicAuth(USERNAME, PASSWORD)

def get_statistics():
    response = requests.get(f"{ADGUARD_URL}/stats", auth=auth)
    return response.json()

def get_query_log(limit=100):
    response = requests.get(
        f"{ADGUARD_URL}/querylog",
        auth=auth,
        params={"limit": limit}
    )
    return response.json()

def add_blocklist_rule(domain):
    data = {"text": f"||{domain}^"}
    response = requests.post(
        f"{ADGUARD_URL}/filtering/add_url",
        auth=auth,
        json=data
    )
    return response.json()

def get_top_blocked_domains(count=10):
    stats = get_statistics()
    top_blocked = stats.get('top_blocked_domains', [])
    return top_blocked[:count]

# Example usage
stats = get_statistics()
print(f"Total queries: {stats['num_dns_queries']}")
print(f"Blocked queries: {stats['num_blocked_filtering']}")

# Get recent queries
log = get_query_log(limit=10)
for entry in log.get('data', []):
    print(f"{entry['time']}: {entry['question']['name']} - {entry['reason']}")
```

### Troubleshooting

**Connection Issues**:
```bash
# Check if AdGuard is running
pct exec 204 -- systemctl status AdGuardHome

# Test web interface
curl -I http://192.168.0.204

# Test DNS functionality
dig @192.168.0.204 google.com
```

**Authentication Problems**:
```bash
# Test credentials
curl -v -u admin:password http://192.168.0.204/control/status 2>&1 | grep -E "HTTP|401|200"

# Reset admin password
pct exec 204 -- /opt/AdGuardHome/AdGuardHome -s stop
pct exec 204 -- /opt/AdGuardHome/AdGuardHome --reset-password
```

**DNS Resolution Issues**:
```bash
# Check DNS info
curl -u admin:password http://192.168.0.204/control/dns_info | jq .

# View upstream DNS servers
curl -u admin:password http://192.168.0.204/control/dns_info | jq '.upstream_dns'

# Test upstream connectivity
pct exec 204 -- dig @192.168.0.202 google.com
```

---

## 8. AlertManager API

Prometheus AlertManager provides an API for managing alerts, silences, and notification routing.

### Base Information

- **Container ID**: 206
- **IP Address**: 192.168.0.206
- **Base URL**: `http://192.168.0.206:9093/api`
- **API Version**: v2
- **Web UI**: `http://192.168.0.206:9093` or `https://alertmanager.homelab.local`
- **Default Port**: 9093

### Authentication

AlertManager by default has no authentication. For production, access through Traefik with authentication middleware.

### Common Endpoints

#### Health and Status

```bash
# Check health
curl -s http://192.168.0.206:9093/-/healthy

# Check readiness
curl -s http://192.168.0.206:9093/-/ready

# Get status
curl -s http://192.168.0.206:9093/api/v2/status | jq .

# Get configuration
curl -s http://192.168.0.206:9093/api/v2/status | jq '.config'

# Get cluster status
curl -s http://192.168.0.206:9093/api/v2/status | jq '.cluster'
```

#### Alerts

```bash
# Get all alerts
curl -s http://192.168.0.206:9093/api/v2/alerts | jq .

# Get alerts with filters
curl -s 'http://192.168.0.206:9093/api/v2/alerts?filter=severity=critical' | jq .

# Get specific alert by fingerprint
curl -s 'http://192.168.0.206:9093/api/v2/alerts?filter=fingerprint=abc123' | jq .

# Post new alerts
curl -X POST -H "Content-Type: application/json" \
  -d '[
    {
      "labels": {
        "alertname": "TestAlert",
        "severity": "warning",
        "instance": "192.168.0.111"
      },
      "annotations": {
        "summary": "Test alert",
        "description": "This is a test alert"
      },
      "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%S.000Z)'",
      "endsAt": "'$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%S.000Z)'"
    }
  ]' \
  http://192.168.0.206:9093/api/v1/alerts
```

#### Silences

```bash
# Get all silences
curl -s http://192.168.0.206:9093/api/v2/silences | jq .

# Get active silences
curl -s 'http://192.168.0.206:9093/api/v2/silences?filter=active=true' | jq .

# Get specific silence by ID
curl -s http://192.168.0.206:9093/api/v2/silence/SILENCE_ID | jq .

# Create silence
curl -X POST -H "Content-Type: application/json" \
  -d '{
    "matchers": [
      {
        "name": "alertname",
        "value": "HighMemoryUsage",
        "isRegex": false,
        "isEqual": true
      }
    ],
    "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%S.000Z)'",
    "endsAt": "'$(date -u -d '+2 hours' +%Y-%m-%dT%H:%M:%S.000Z)'",
    "comment": "Maintenance window",
    "createdBy": "admin"
  }' \
  http://192.168.0.206:9093/api/v2/silences

# Update silence
curl -X PUT -H "Content-Type: application/json" \
  -d '{
    "id": "SILENCE_ID",
    "matchers": [...],
    "startsAt": "...",
    "endsAt": "...",
    "comment": "Updated silence",
    "createdBy": "admin"
  }' \
  http://192.168.0.206:9093/api/v2/silences

# Delete silence
curl -X DELETE http://192.168.0.206:9093/api/v2/silence/SILENCE_ID
```

#### Alert Groups

```bash
# Get alert groups
curl -s http://192.168.0.206:9093/api/v2/alerts/groups | jq .

# Get groups with filters
curl -s 'http://192.168.0.206:9093/api/v2/alerts/groups?filter=severity=critical' | jq .

# Get active alerts grouped
curl -s 'http://192.168.0.206:9093/api/v2/alerts/groups?filter=active=true' | jq .
```

#### Receivers

```bash
# Get receivers (from configuration)
curl -s http://192.168.0.206:9093/api/v2/status | jq '.config.receivers'

# Test receiver (requires amtool)
pct exec 206 -- amtool config routes test \
  --config.file=/etc/alertmanager/alertmanager.yml \
  severity=critical alertname=TestAlert
```

### Usage Examples

#### Create Silence for Maintenance

```bash
# 2-hour maintenance window
curl -X POST -H "Content-Type: application/json" \
  -d '{
    "matchers": [
      {
        "name": "instance",
        "value": "192.168.0.111",
        "isRegex": false,
        "isEqual": true
      }
    ],
    "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%S.000Z)'",
    "endsAt": "'$(date -u -d '+2 hours' +%Y-%m-%dT%H:%M:%S.000Z)'",
    "comment": "Scheduled maintenance on k3-01",
    "createdBy": "automation"
  }' \
  http://192.168.0.206:9093/api/v2/silences | jq .
```

#### Send Test Alert

```bash
# Critical test alert
curl -X POST -H "Content-Type: application/json" \
  -d '[
    {
      "labels": {
        "alertname": "SystemTest",
        "severity": "critical",
        "instance": "test-instance",
        "service": "test"
      },
      "annotations": {
        "summary": "System test alert",
        "description": "This is a critical test alert for notification testing"
      },
      "generatorURL": "http://prometheus.homelab.local"
    }
  ]' \
  http://192.168.0.206:9093/api/v1/alerts
```

#### Python Example

```python
import requests
from datetime import datetime, timedelta

ALERTMANAGER_URL = "http://192.168.0.206:9093/api"

def get_active_alerts():
    response = requests.get(f"{ALERTMANAGER_URL}/v2/alerts")
    return response.json()

def create_silence(alertname, duration_hours=2, comment="Scheduled maintenance"):
    start_time = datetime.utcnow()
    end_time = start_time + timedelta(hours=duration_hours)

    data = {
        "matchers": [
            {
                "name": "alertname",
                "value": alertname,
                "isRegex": False,
                "isEqual": True
            }
        ],
        "startsAt": start_time.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
        "endsAt": end_time.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
        "comment": comment,
        "createdBy": "python-script"
    }

    response = requests.post(
        f"{ALERTMANAGER_URL}/v2/silences",
        json=data
    )
    return response.json()

def get_alert_groups():
    response = requests.get(f"{ALERTMANAGER_URL}/v2/alerts/groups")
    return response.json()

# Example usage
alerts = get_active_alerts()
print(f"Active alerts: {len(alerts)}")

# Create silence
silence_id = create_silence("HighMemoryUsage", duration_hours=4)
print(f"Created silence: {silence_id}")

# Get grouped alerts
groups = get_alert_groups()
for group in groups:
    print(f"Group: {group['labels']} - Alerts: {len(group['alerts'])}")
```

### Troubleshooting

**Service Status**:
```bash
# Check AlertManager status
pct exec 206 -- systemctl status alertmanager

# View logs
pct exec 206 -- journalctl -u alertmanager -f

# Check process
pct exec 206 -- ps aux | grep alertmanager
```

**Configuration Validation**:
```bash
# Validate configuration
pct exec 206 -- amtool check-config /etc/alertmanager/alertmanager.yml

# Test routing
pct exec 206 -- amtool config routes test \
  --config.file=/etc/alertmanager/alertmanager.yml \
  severity=critical alertname=TestAlert
```

**Notification Issues**:
```bash
# Check SMTP connectivity (if using email)
pct exec 206 -- telnet smtp.gmail.com 587

# View notification logs
pct exec 206 -- journalctl -u alertmanager | grep -i "notify"

# Test webhook receiver
curl -X POST http://webhook-receiver/test
```

---

## 9. Loki API

Grafana Loki provides an HTTP API for log ingestion and querying using LogQL.

### Base Information

- **Container ID**: 210
- **IP Address**: 192.168.0.210
- **Base URL**: `http://192.168.0.210:3100`
- **Default Port**: 3100
- **gRPC Port**: 9096

### Authentication

Loki by default has no authentication. For production, access through Traefik with authentication middleware.

### Common Endpoints

#### Health and Status

```bash
# Check readiness
curl -s http://192.168.0.210:3100/ready

# Get metrics
curl -s http://192.168.0.210:3100/metrics | grep loki_

# Get build info
curl -s http://192.168.0.210:3100/loki/api/v1/status/buildinfo | jq .

# Get runtime configuration
curl -s http://192.168.0.210:3100/loki/api/v1/status/runtime_config | jq .
```

#### Labels

```bash
# Get all label names
curl -s http://192.168.0.210:3100/loki/api/v1/labels | jq .

# Get label values for specific label
curl -s http://192.168.0.210:3100/loki/api/v1/label/job/values | jq .

# Get labels with time range
curl -s 'http://192.168.0.210:3100/loki/api/v1/labels?start=1609459200&end=1609545600' | jq .
```

#### Query API

```bash
# Instant query (LogQL)
curl -s --data-urlencode 'query={job="syslog"}' \
  http://192.168.0.210:3100/loki/api/v1/query | jq .

# Query with limit
curl -s --data-urlencode 'query={job="syslog"} |= "error"' \
  --data-urlencode 'limit=100' \
  http://192.168.0.210:3100/loki/api/v1/query | jq .

# Range query
curl -G -s http://192.168.0.210:3100/loki/api/v1/query_range \
  --data-urlencode 'query={job="syslog"}' \
  --data-urlencode 'start=1609459200' \
  --data-urlencode 'end=1609545600' \
  --data-urlencode 'limit=1000' | jq .

# Query with direction (forward/backward)
curl -G -s http://192.168.0.210:3100/loki/api/v1/query_range \
  --data-urlencode 'query={job="syslog"}' \
  --data-urlencode 'direction=backward' \
  --data-urlencode 'limit=100' | jq .
```

#### Series

```bash
# Get series matching label matchers
curl -s --data-urlencode 'match={job="syslog"}' \
  http://192.168.0.210:3100/loki/api/v1/series | jq .

# Get series with time range
curl -s --data-urlencode 'match={job="syslog"}' \
  --data-urlencode 'start=1609459200' \
  --data-urlencode 'end=1609545600' \
  http://192.168.0.210:3100/loki/api/v1/series | jq .
```

#### Push API (Log Ingestion)

```bash
# Push logs to Loki
curl -X POST -H "Content-Type: application/json" \
  -d '{
    "streams": [
      {
        "stream": {
          "job": "test",
          "level": "info"
        },
        "values": [
          ["'$(date +%s)000000000'", "Test log line 1"],
          ["'$(date +%s)000000001'", "Test log line 2"]
        ]
      }
    ]
  }' \
  http://192.168.0.210:3100/loki/api/v1/push
```

#### Tail (Live Log Streaming)

WebSocket endpoint for real-time log tailing:
```bash
# Using websocat
websocat 'ws://192.168.0.210:3100/loki/api/v1/tail?query={job="syslog"}'
```

### LogQL Query Examples

```bash
# Simple label matcher
curl -s --data-urlencode 'query={job="syslog"}' \
  http://192.168.0.210:3100/loki/api/v1/query | jq .

# Filter logs containing "error"
curl -s --data-urlencode 'query={job="syslog"} |= "error"' \
  http://192.168.0.210:3100/loki/api/v1/query | jq .

# Exclude logs containing "debug"
curl -s --data-urlencode 'query={job="syslog"} != "debug"' \
  http://192.168.0.210:3100/loki/api/v1/query | jq .

# Regular expression filter
curl -s --data-urlencode 'query={job="syslog"} |~ "error|critical"' \
  http://192.168.0.210:3100/loki/api/v1/query | jq .

# JSON parsing
curl -s --data-urlencode 'query={job="syslog"} | json | level="error"' \
  http://192.168.0.210:3100/loki/api/v1/query | jq .

# Rate query (log lines per second)
curl -s --data-urlencode 'query=rate({job="syslog"}[5m])' \
  http://192.168.0.210:3100/loki/api/v1/query | jq .

# Count errors per service
curl -s --data-urlencode 'query=sum by (service) (count_over_time({job="syslog"} |= "error" [5m]))' \
  http://192.168.0.210:3100/loki/api/v1/query | jq .
```

### Usage Examples

#### Python Example

```python
import requests
from datetime import datetime, timedelta
import time

LOKI_URL = "http://192.168.0.210:3100"

def query_logs(logql, limit=100):
    response = requests.get(
        f"{LOKI_URL}/loki/api/v1/query",
        params={
            'query': logql,
            'limit': limit
        }
    )
    return response.json()

def query_range(logql, start, end, limit=1000):
    response = requests.get(
        f"{LOKI_URL}/loki/api/v1/query_range",
        params={
            'query': logql,
            'start': int(start.timestamp()),
            'end': int(end.timestamp()),
            'limit': limit
        }
    )
    return response.json()

def push_logs(job, level, messages):
    timestamp_ns = str(int(time.time() * 1000000000))

    values = [[timestamp_ns, msg] for msg in messages]

    data = {
        "streams": [
            {
                "stream": {
                    "job": job,
                    "level": level
                },
                "values": values
            }
        ]
    }

    response = requests.post(
        f"{LOKI_URL}/loki/api/v1/push",
        json=data
    )
    return response.status_code

def get_labels():
    response = requests.get(f"{LOKI_URL}/loki/api/v1/labels")
    return response.json()

# Example usage
# Query recent error logs
errors = query_logs('{job="syslog"} |= "error"', limit=50)
print(f"Found {len(errors['data']['result'])} error log streams")

# Query logs from last hour
end = datetime.now()
start = end - timedelta(hours=1)
logs = query_range('{job="syslog"}', start, end)

# Push test logs
push_logs("test", "info", ["Test message 1", "Test message 2"])

# Get all labels
labels = get_labels()
print(f"Available labels: {labels['data']}")
```

### Troubleshooting

**Service Status**:
```bash
# Check Loki status
pct exec 210 -- systemctl status loki

# View logs
pct exec 210 -- journalctl -u loki -f

# Check if listening
pct exec 210 -- ss -tlnp | grep 3100
```

**Query Issues**:
```bash
# Test simple query
curl -s --data-urlencode 'query={job="syslog"}' \
  http://192.168.0.210:3100/loki/api/v1/query | jq .

# Check for errors in response
curl -s --data-urlencode 'query={invalid}' \
  http://192.168.0.210:3100/loki/api/v1/query | jq .status

# Verify labels exist
curl -s http://192.168.0.210:3100/loki/api/v1/labels | jq .
```

**Ingestion Issues**:
```bash
# Check if Loki is receiving logs
curl -s http://192.168.0.210:3100/metrics | grep loki_distributor_bytes_received_total

# Test manual log push
curl -X POST -H "Content-Type: application/json" \
  -d '{"streams":[{"stream":{"job":"test"},"values":[["'$(date +%s)000000000'","test"]]}]}' \
  http://192.168.0.210:3100/loki/api/v1/push -v

# Check for ingestion errors
pct exec 210 -- journalctl -u loki | grep -i error
```

**Storage Issues**:
```bash
# Check disk usage
pct exec 210 -- df -h /var/lib/loki

# Check chunk storage
pct exec 210 -- du -sh /var/lib/loki/chunks/*

# Check index size
pct exec 210 -- du -sh /var/lib/loki/boltdb-shipper-active/*
```

---

## 10. Media Services APIs

Brief overview of media management service APIs (Sonarr, Radarr, Prowlarr, qBittorrent, Jellyfin).

### Sonarr API

- **IP**: 192.168.0.230
- **Port**: 8989
- **Base URL**: `http://192.168.0.230:8989/api/v3`
- **Authentication**: API Key (in request header `X-Api-Key`)

```bash
# Get system status
curl -H "X-Api-Key: YOUR_API_KEY" http://192.168.0.230:8989/api/v3/system/status

# Get all series
curl -H "X-Api-Key: YOUR_API_KEY" http://192.168.0.230:8989/api/v3/series

# Get calendar
curl -H "X-Api-Key: YOUR_API_KEY" http://192.168.0.230:8989/api/v3/calendar
```

### Radarr API

- **IP**: 192.168.0.231
- **Port**: 7878
- **Base URL**: `http://192.168.0.231:7878/api/v3`
- **Authentication**: API Key (in request header `X-Api-Key`)

```bash
# Get system status
curl -H "X-Api-Key: YOUR_API_KEY" http://192.168.0.231:7878/api/v3/system/status

# Get all movies
curl -H "X-Api-Key: YOUR_API_KEY" http://192.168.0.231:7878/api/v3/movie

# Get calendar
curl -H "X-Api-Key: YOUR_API_KEY" http://192.168.0.231:7878/api/v3/calendar
```

### Prowlarr API

- **IP**: 192.168.0.233
- **Port**: 9696
- **Base URL**: `http://192.168.0.233:9696/api/v1`
- **Authentication**: API Key (in request header `X-Api-Key`)

```bash
# Get indexers
curl -H "X-Api-Key: YOUR_API_KEY" http://192.168.0.233:9696/api/v1/indexer

# Search
curl -H "X-Api-Key: YOUR_API_KEY" http://192.168.0.233:9696/api/v1/search?query=ubuntu
```

### qBittorrent API

- **IP**: 192.168.0.234
- **Port**: 8080
- **Base URL**: `http://192.168.0.234:8080/api/v2`
- **Authentication**: Cookie-based (login first)

```bash
# Login
curl -X POST -d 'username=admin&password=adminpass' \
  http://192.168.0.234:8080/api/v2/auth/login -c cookies.txt

# Get torrent list
curl -b cookies.txt http://192.168.0.234:8080/api/v2/torrents/info

# Get application version
curl -b cookies.txt http://192.168.0.234:8080/api/v2/app/version
```

### Jellyfin API

- **IP**: 192.168.0.235
- **Port**: 8096
- **Base URL**: `http://192.168.0.235:8096`
- **Authentication**: API Key or User Token

```bash
# Get system info (requires API key)
curl -H "X-Emby-Token: YOUR_API_KEY" http://192.168.0.235:8096/System/Info

# Get users
curl -H "X-Emby-Token: YOUR_API_KEY" http://192.168.0.235:8096/Users

# Get libraries
curl -H "X-Emby-Token: YOUR_API_KEY" http://192.168.0.235:8096/Library/MediaFolders
```

---

## General Troubleshooting Tips

### Network Connectivity

```bash
# Test basic connectivity
ping 192.168.0.200

# Test specific port
telnet 192.168.0.200 9090
# or
nc -zv 192.168.0.200 9090

# Check DNS resolution
nslookup prometheus.homelab.local

# Trace route
traceroute 192.168.0.200
```

### Service Health Checks

```bash
# Quick health check script
for service in prometheus:9090 grafana:3000 loki:3100 alertmanager:9093; do
  host=$(echo $service | cut -d: -f1)
  port=$(echo $service | cut -d: -f2)
  echo -n "Testing $host ($port): "
  curl -s -o /dev/null -w "%{http_code}" "http://192.168.0.20${port#*0}:$port" | \
    grep -q "200\|401\|302" && echo "OK" || echo "FAILED"
done
```

### API Response Debugging

```bash
# Verbose output with headers
curl -v http://192.168.0.200:9090/api/v1/query?query=up 2>&1 | less

# Pretty print JSON
curl -s http://192.168.0.200:9090/api/v1/targets | jq .

# Save response for analysis
curl -s http://192.168.0.200:9090/api/v1/targets > response.json

# Check response time
curl -w "@curl-format.txt" -o /dev/null -s http://192.168.0.200:9090/api/v1/query?query=up
```

### Container/LXC Troubleshooting

```bash
# Check container status
pct status 200

# Execute command in container
pct exec 200 -- systemctl status prometheus

# View container logs
pct exec 200 -- journalctl -u prometheus -f

# Check resource usage
pct exec 200 -- htop

# Network connectivity from container
pct exec 200 -- curl -s http://192.168.0.111:9100/metrics | head
```

---

## Appendix: Service Port Reference

| Service | Container ID | IP Address | Port(s) | Protocol |
|---------|-------------|------------|---------|----------|
| Prometheus | 200 | 192.168.0.200 | 9090 | HTTP |
| Grafana | 201 | 192.168.0.201 | 3000 | HTTP |
| Unbound | 202 | 192.168.0.202 | 53 | DNS/UDP |
| WireGuard | 203 | 192.168.0.203 | 51820 | UDP |
| AdGuard Home | 204 | 192.168.0.204 | 53, 80, 443, 3000 | DNS/HTTP |
| Traefik | 205 | 192.168.0.205 | 80, 443, 8080 | HTTP/HTTPS |
| AlertManager | 206 | 192.168.0.206 | 9093 | HTTP |
| PVE Exporter | 207 | 192.168.0.207 | 9221 | HTTP |
| Home Assistant | 208 | 192.168.0.208 | 8123 | HTTP |
| Loki | 210 | 192.168.0.210 | 3100, 9096 | HTTP/gRPC |
| Sonarr | 230 | 192.168.0.230 | 8989 | HTTP |
| Radarr | 231 | 192.168.0.231 | 7878 | HTTP |
| Bazarr | 232 | 192.168.0.232 | 6767 | HTTP |
| Prowlarr | 233 | 192.168.0.233 | 9696 | HTTP |
| qBittorrent | 234 | 192.168.0.234 | 8080 | HTTP |
| Jellyfin | 235 | 192.168.0.235 | 8096 | HTTP |
| PVE Exporter (NAS) | 240 | 192.168.0.240 | 9221 | HTTP |
| K3s API | - | 192.168.0.111 | 6443 | HTTPS |
| Kubelet | - | 192.168.0.111-114 | 10250 | HTTPS |
| Node Exporter | - | 192.168.0.111-114 | 9100 | HTTP |

---

## Additional Resources

- **Prometheus API Documentation**: https://prometheus.io/docs/prometheus/latest/querying/api/
- **Grafana API Documentation**: https://grafana.com/docs/grafana/latest/developers/http_api/
- **Kubernetes API Reference**: https://kubernetes.io/docs/reference/kubernetes-api/
- **Home Assistant API**: https://developers.home-assistant.io/docs/api/rest/
- **Loki API Documentation**: https://grafana.com/docs/loki/latest/api/
- **Traefik API Documentation**: https://doc.traefik.io/traefik/operations/api/

---

**Document Version**: 1.0
**Last Updated**: 2026-02-01
**Maintained By**: Homelab Infrastructure Team
