# Homelab API Documentation

This document provides comprehensive API documentation for all services deployed in the homelab infrastructure, including access methods, authentication, and integration points.

## Service APIs Overview

### Core Infrastructure APIs

| Service | API Endpoint | Port | Authentication | Documentation |
|---------|-------------|------|----------------|---------------|
| **Traefik** | `https://traefik.homelab.local/api` | 8080 | Basic Auth | [Traefik API Docs](https://doc.traefik.io/traefik/operations/api/) |
| **Prometheus** | `https://prometheus.homelab.local/api/v1` | 9090 | Basic Auth | [Prometheus API](https://prometheus.io/docs/prometheus/latest/querying/api/) |
| **Grafana** | `https://grafana.homelab.local/api` | 3000 | API Key | [Grafana API](https://grafana.com/docs/grafana/latest/http_api/) |
| **AlertManager** | `https://alertmanager.homelab.local/api/v2` | 9093 | Basic Auth | [AlertManager API](https://petstore.swagger.io/?url=https://raw.githubusercontent.com/prometheus/alertmanager/main/api/v2/openapi.yaml) |
| **Loki** | `https://loki.homelab.local/loki/api/v1` | 3100 | None | [Loki API](https://grafana.com/docs/loki/latest/api/) |

### Home Automation APIs

| Service | API Endpoint | Port | Authentication | Documentation |
|---------|-------------|------|----------------|---------------|
| **Home Assistant** | `https://ha.homelab.local/api` | 8123 | Bearer Token | [HA API](https://developers.home-assistant.io/docs/api/rest/) |

### Media Management APIs

| Service | API Endpoint | Port | Authentication | Documentation |
|---------|-------------|------|----------------|---------------|
| **Sonarr** | `https://sonarr.homelab.local/api/v3` | 8989 | API Key | [Sonarr API](https://sonarr.tv/docs/api/) |
| **Radarr** | `https://radarr.homelab.local/api/v3` | 7878 | API Key | [Radarr API](https://radarr.video/docs/api/) |
| **Prowlarr** | `https://prowlarr.homelab.local/api/v1` | 9696 | API Key | [Prowlarr API](https://prowlarr.com/docs/api/) |
| **Jellyfin** | `https://jellyfin.homelab.local/api` | 8096 | API Key | [Jellyfin API](https://api.jellyfin.org/) |
| **qBittorrent** | `https://qbt.homelab.local/api/v2` | 8080 | Cookie Auth | [qBittorrent API](https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1)) |

### Network Services APIs

| Service | API Endpoint | Port | Authentication | Documentation |
|---------|-------------|------|----------------|---------------|
| **AdGuard Home** | `https://adguard.homelab.local/control` | 80 | Basic Auth | [AdGuard API](https://github.com/AdguardTeam/AdGuardHome/tree/master/openapi) |
| **Unbound** | N/A (DNS only) | 53 | N/A | DNS Protocol |

### Infrastructure Management APIs

| Service | API Endpoint | Port | Authentication | Documentation |
|---------|-------------|------|----------------|---------------|
| **Proxmox VE** | `https://pve-mac:8006/api2` | 8006 | API Token | [Proxmox API](https://pve.proxmox.com/pve-docs/api-viewer/) |
| **K3s API Server** | `https://k3s-01:6443` | 6443 | Bearer Token | [Kubernetes API](https://kubernetes.io/docs/reference/kubernetes-api/) |

## Authentication Methods

### API Key Authentication

Services using API key authentication require the key to be included in headers:

```bash
# Example: Sonarr API call
curl -X GET "https://sonarr.homelab.local/api/v3/system/status" \
  -H "X-Api-Key: your_api_key_here"
```

### Bearer Token Authentication

Services using bearer tokens:

```bash
# Example: Home Assistant API call
curl -X GET "https://ha.homelab.local/api/states" \
  -H "Authorization: Bearer your_long_lived_access_token"
```

### Basic Authentication

Services using basic auth:

```bash
# Example: Prometheus API call
curl -X GET "https://prometheus.homelab.local/api/v1/query?query=up" \
  -u "username:password"
```

### Cookie Authentication

Services using cookie-based auth:

```bash
# Example: qBittorrent login and API call
# First login to get session cookie
curl -X POST "https://qbt.homelab.local/api/v2/auth/login" \
  -d "username=admin&password=password" \
  -c cookies.txt

# Then use cookie for API calls
curl -X GET "https://qbt.homelab.local/api/v2/torrents/info" \
  -b cookies.txt
```

## Common API Operations

### Monitoring and Metrics

#### Prometheus Queries

```bash
# Get all active targets
curl -s "https://prometheus.homelab.local/api/v1/targets" | jq '.data.activeTargets'

# Query metrics
curl -s "https://prometheus.homelab.local/api/v1/query?query=up" | jq '.data.result'

# Range queries
curl -s "https://prometheus.homelab.local/api/v1/query_range?query=up&start=$(date -d '1 hour ago' +%s)&end=$(date +%s)&step=60s"
```

#### Grafana Dashboard Management

```bash
# Get all dashboards
curl -s "https://grafana.homelab.local/api/search" \
  -H "Authorization: Bearer your_api_key"

# Create dashboard
curl -X POST "https://grafana.homelab.local/api/dashboards/db" \
  -H "Authorization: Bearer your_api_key" \
  -H "Content-Type: application/json" \
  -d @dashboard.json
```

### Service Health Checks

#### Traefik Service Discovery

```bash
# Get all routers
curl -s "https://traefik.homelab.local/api/http/routers" | jq '.'

# Get service status
curl -s "https://traefik.homelab.local/api/http/services" | jq '.'

# Check middleware
curl -s "https://traefik.homelab.local/api/http/middlewares" | jq '.'
```

#### Container and Service Status

```bash
# Check all services health
for service in prometheus grafana traefik; do
  echo "Checking $service..."
  curl -s -o /dev/null -w "%{http_code}" "https://$service.homelab.local/health" || echo " - $service health check"
done
```

### Home Automation Integration

#### Home Assistant API Examples

```bash
# Get all entities
curl -X GET "https://ha.homelab.local/api/states" \
  -H "Authorization: Bearer $HA_TOKEN"

# Call service
curl -X POST "https://ha.homelab.local/api/services/light/turn_on" \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "light.living_room"}'

# Get configuration
curl -X GET "https://ha.homelab.local/api/config" \
  -H "Authorization: Bearer $HA_TOKEN"
```

### Media Management APIs

#### Sonarr/Radarr Operations

```bash
# Get system status
curl -X GET "https://sonarr.homelab.local/api/v3/system/status" \
  -H "X-Api-Key: $SONARR_API_KEY"

# Get series list
curl -X GET "https://sonarr.homelab.local/api/v3/series" \
  -H "X-Api-Key: $SONARR_API_KEY"

# Add new series
curl -X POST "https://sonarr.homelab.local/api/v3/series" \
  -H "X-Api-Key: $SONARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d @new_series.json
```

## API Integration Patterns

### Service Discovery Integration

Traefik automatically discovers services via:

#### Docker Labels (LXC Services)

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.service.rule=Host(`service.homelab.local`)"
  - "traefik.http.services.service.loadbalancer.server.port=8080"
```

#### Kubernetes Ingress (K3s Services)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: service-ingress
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  rules:
    - host: service.homelab.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: service
                port:
                  number: 80
```

### Monitoring Integration

#### Prometheus Service Discovery

```yaml
# Kubernetes service discovery
- job_name: 'kubernetes-services'
  kubernetes_sd_configs:
    - role: service

# Static configuration for LXC services
- job_name: 'lxc-services'
  static_configs:
    - targets:
        - '192.168.0.200:9090'  # Prometheus
        - '192.168.0.201:3000'  # Grafana
```

### Log Aggregation

#### Loki Integration

```bash
# Query logs
curl -G "https://loki.homelab.local/loki/api/v1/query_range" \
  --data-urlencode 'query={job="traefik"}' \
  --data-urlencode "start=$(date -d '1 hour ago' --iso-8601)" \
  --data-urlencode "end=$(date --iso-8601)"

# Push logs (via Promtail)
curl -X POST "https://loki.homelab.local/loki/api/v1/push" \
  -H "Content-Type: application/json" \
  -d @log_entry.json
```

## Security Considerations

### API Security Best Practices

1. **Use HTTPS** - All API communications encrypted
2. **API Key Management** - Store keys in Ansible Vault
3. **Rate Limiting** - Traefik middleware for API protection
4. **Network Restrictions** - Firewall rules limit API access
5. **Token Rotation** - Regular rotation of API keys and tokens

### Authentication Token Management

```yaml
# Store in Ansible Vault
vault_grafana_api_key: "glsa_xxxxx"
vault_sonarr_api_key: "xxxxxxxx"
vault_ha_token: "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
```

### Network Access Control

API access is restricted via:

- **VPN requirement** for external access
- **Firewall rules** limiting source IPs
- **Traefik middleware** for additional protection
- **Service-specific authentication** for all APIs

## Troubleshooting API Issues

### Common Problems

#### SSL Certificate Issues

```bash
# Check certificate validity
curl -vI https://service.homelab.local 2>&1 | grep -E 'certificate|SSL'

# Force certificate refresh
pct exec 205 -- systemctl restart traefik
```

#### Authentication Failures

```bash
# Test API authentication
curl -v -X GET "https://prometheus.homelab.local/api/v1/targets" \
  -u "username:password"

# Check API key validity
curl -v -X GET "https://sonarr.homelab.local/api/v3/system/status" \
  -H "X-Api-Key: $API_KEY"
```

#### Service Discovery Issues

```bash
# Check Traefik service discovery
curl -s "https://traefik.homelab.local/api/http/routers" | jq '.[] | select(.service != null)'

# Verify Kubernetes API connectivity
kubectl --kubeconfig=/path/to/kubeconfig get ingress --all-namespaces
```

## API Testing and Validation

### Health Check Script

```bash
#!/bin/bash
# api-health-check.sh

services=(
  "traefik.homelab.local/api/http/routers"
  "prometheus.homelab.local/api/v1/targets"
  "grafana.homelab.local/api/health"
  "ha.homelab.local/api/"
)

for service in "${services[@]}"; do
  echo -n "Testing $service: "
  if curl -s -f "https://$service" >/dev/null; then
    echo "OK"
  else
    echo "FAILED"
  fi
done
```

### API Integration Testing

```yaml
# api-test.yml
- name: Test API endpoints
  uri:
    url: "https://{{ item.service }}.homelab.local{{ item.path }}"
    method: GET
    headers:
      Authorization: "Bearer {{ item.token | default(omit) }}"
    validate_certs: yes
    status_code: [200, 401]  # 401 expected for protected endpoints
  loop:
    - { service: "prometheus", path: "/api/v1/targets" }
    - { service: "grafana", path: "/api/health" }
    - { service: "traefik", path: "/api/http/routers" }
```

## Performance and Rate Limiting

### API Rate Limits

Most services have rate limiting configured:

- **Traefik**: 100 requests/second per IP
- **Prometheus**: No built-in limits (use Traefik middleware)
- **Grafana**: 100 requests/minute per user
- **Home Assistant**: 10 requests/second per IP

### Performance Optimization

```yaml
# Traefik middleware for API caching
http:
  middlewares:
    api-cache:
      plugin:
        cache:
          ttl: 300s
```

## Future API Enhancements

### Planned Integrations

- **GraphQL endpoints** for unified data access
- **Webhook integration** for event-driven automation
- **API gateway** with centralized authentication
- **Rate limiting** with Redis backend
- **API versioning** strategy

### Monitoring Enhancements

- **API usage metrics** in Prometheus
- **Response time monitoring** via Traefik
- **Error rate alerting** in AlertManager
- **API documentation** auto-generation

This API documentation provides a comprehensive reference for all service APIs in the homelab infrastructure. Regular updates ensure accuracy as services are added or modified.
