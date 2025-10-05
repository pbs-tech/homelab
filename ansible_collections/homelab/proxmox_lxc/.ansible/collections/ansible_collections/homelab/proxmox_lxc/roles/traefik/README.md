# Traefik Role

Deploys and configures Traefik as a reverse proxy and load balancer in an LXC container, providing unified ingress for both LXC services and K3s cluster workloads.

## Features

- **Automatic Service Discovery** - Discovers services via Docker labels and Kubernetes ingress
- **SSL Certificate Management** - Automated Let's Encrypt certificate provisioning and renewal
- **Security Headers** - Implements comprehensive security headers (HSTS, CSP, etc.)
- **Rate Limiting** - Configurable rate limiting to prevent abuse
- **Middleware Support** - Authentication, compression, and custom middleware
- **Dashboard** - Built-in dashboard for monitoring and configuration
- **High Availability** - Supports clustering for redundancy
- **Metrics** - Prometheus metrics integration for monitoring

## Requirements

- Proxmox VE with LXC support
- Ubuntu 22.04 LTS template
- Valid domain name for SSL certificates
- DNS configuration pointing to Traefik IP
- Network access to backend services

## Role Variables

### Container Configuration

```yaml
# Container resource allocation
traefik_resources:
  memory: 1024          # Memory in MB
  cores: 2              # CPU cores
  disk_size: "20"       # Disk size in GB

# Network configuration
traefik_ip: "192.168.0.205"
traefik_container_id: 205
traefik_node: "pve-mac"  # Proxmox node name
```

### SSL Certificate Configuration

```yaml
# Let's Encrypt configuration
ssl_config:
  email: "{{ vault_ssl_email }}"
  ca_server: "https://acme-v02.api.letsencrypt.org/directory"
  dns_challenge: true
  provider: "cloudflare"  # DNS provider for challenge

# Certificate domains
certificate_domains:
  - "{{ homelab_domain }}"
  - "*.{{ homelab_domain }}"
  - "{{ external_domain }}"
  - "*.{{ external_domain }}"
```

### Service Discovery

```yaml
# Docker provider (for LXC services)
docker_provider:
  enabled: true
  endpoint: "unix:///var/run/docker.sock"
  exposedByDefault: false
  watch: true

# Kubernetes provider (for K3s cluster)
kubernetes_provider:
  enabled: true
  endpoint: "https://192.168.0.111:6443"
  token: "{{ vault_k3s_token }}"
  namespaces:
    - "default"
    - "kube-system"
    - "monitoring"
```

### Security Configuration

```yaml
# Security headers
security_headers:
  frame_deny: true
  content_type_nosniff: true
  browser_xss_filter: true
  hsts_max_age: 31536000
  hsts_include_subdomains: true
  hsts_preload: true
  csp_policy: "default-src 'self'"

# Rate limiting
rate_limiting:
  enabled: true
  requests_per_second: 100
  burst_size: 200
```

### Middleware Configuration

```yaml
# Authentication middleware
auth_middleware:
  basic_auth:
    enabled: false
    users:
      - "admin:$2y$10$..."

  oauth:
    enabled: false
    provider: "google"
    client_id: "{{ vault_oauth_client_id }}"
    client_secret: "{{ vault_oauth_client_secret }}"

# Compression middleware
compression_middleware:
  enabled: true
  types:
    - "text/html"
    - "text/css"
    - "application/javascript"
    - "application/json"
```

## Usage

### Basic Deployment

```yaml
- hosts: proxmox_hosts
  roles:
    - homelab.proxmox_lxc.traefik
```

### With Custom Configuration

```yaml
- hosts: proxmox_hosts
  vars:
    traefik_resources:
      memory: 2048
      cores: 4
    ssl_config:
      dns_challenge: true
      provider: "route53"
  roles:
    - homelab.proxmox_lxc.traefik
```

### Enable Authentication

```yaml
- hosts: proxmox_hosts
  vars:
    auth_middleware:
      basic_auth:
        enabled: true
        users:
          - "admin:{{ vault_traefik_admin_password_hash }}"
  roles:
    - homelab.proxmox_lxc.traefik
```

## Service Configuration

### LXC Service Labels

Configure services with Docker labels for automatic discovery:

```yaml
# In service role (e.g., prometheus)
docker_labels:
  - "traefik.enable=true"
  - "traefik.http.routers.prometheus.rule=Host(`prometheus.{{ homelab_domain }}`)"
  - "traefik.http.routers.prometheus.tls=true"
  - "traefik.http.routers.prometheus.tls.certresolver=letsencrypt"
  - "traefik.http.services.prometheus.loadbalancer.server.port=9090"
  - "traefik.http.middlewares.prometheus-auth.basicAuth.users=admin:$$2y$$10$$..."
  - "traefik.http.routers.prometheus.middlewares=prometheus-auth"
```

### Kubernetes Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-service
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: default-compress@kubernetescrd
spec:
  tls:
    - hosts:
        - app.homelab.local
      secretName: homelab-tls
  rules:
    - host: app.homelab.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: example-service
                port:
                  number: 80
```

## Files and Templates

### Configuration Files

- **traefik.yml** - Main Traefik configuration
- **dynamic.yml** - Dynamic configuration for middlewares and services
- **acme.json** - Let's Encrypt certificate storage

### Systemd Service

- **traefik.service** - Systemd service unit file

### Docker Compose

- **docker-compose.yml** - Container orchestration (if using Docker)

## Dependencies

- homelab.common.container_base
- homelab.common.security_hardening

## Handlers

- `restart traefik` - Restart Traefik service
- `reload traefik` - Reload configuration without restart
- `renew certificates` - Force certificate renewal

## Examples

### Complete Configuration

```yaml
- name: Deploy Traefik with full configuration
  hosts: proxmox_hosts
  vars:
    traefik_resources:
      memory: 2048
      cores: 2
      disk_size: "30"

    ssl_config:
      email: "admin@example.com"
      dns_challenge: true
      provider: "cloudflare"

    security_headers:
      hsts_max_age: 31536000
      csp_policy: "default-src 'self'; script-src 'self' 'unsafe-inline'"

    rate_limiting:
      enabled: true
      requests_per_second: 50
      burst_size: 100

    auth_middleware:
      basic_auth:
        enabled: true
        users:
          - "admin:$2y$10$encrypted_password"

  roles:
    - homelab.proxmox_lxc.traefik
```

### Development Configuration

```yaml
- name: Deploy Traefik for development
  hosts: proxmox_hosts
  vars:
    ssl_config:
      ca_server: "https://acme-staging-v02.api.letsencrypt.org/directory"
      dns_challenge: false

    traefik_debug: true
    traefik_log_level: "DEBUG"

  roles:
    - homelab.proxmox_lxc.traefik
```

## Troubleshooting

### Certificate Issues

```bash
# Check certificate status
pct exec 205 -- cat /etc/traefik/acme.json | jq '.letsencrypt.Certificates[].domain'

# Force certificate renewal
pct exec 205 -- systemctl restart traefik

# Check logs
pct exec 205 -- journalctl -u traefik -f
```

### Service Discovery Issues

```bash
# Check API connectivity to K3s
pct exec 205 -- curl -k https://192.168.0.111:6443/version

# Verify service labels
docker inspect service_container | jq '.[0].Config.Labels'

# Check Traefik dashboard
curl -s http://192.168.0.205:8080/api/http/routers | jq '.'
```

### Performance Issues

```bash
# Monitor resource usage
pct exec 205 -- htop
pct exec 205 -- iotop

# Check connection limits
pct exec 205 -- ss -tuln | grep -E ':(80|443|8080)'

# Review access logs
pct exec 205 -- tail -f /var/log/traefik/access.log
```

## Security Considerations

- **Certificate Storage** - acme.json should have 600 permissions
- **API Security** - Dashboard should not be exposed externally
- **Rate Limiting** - Configure appropriate limits for your environment
- **Headers** - Enable security headers for all routes
- **Authentication** - Use strong passwords or OAuth for protected services

## Performance Tuning

- **Resource Allocation** - Adjust CPU/memory based on traffic
- **Connection Limits** - Configure appropriate limits
- **Caching** - Enable response caching for static content
- **Compression** - Enable gzip compression for text content

## License

MIT License - See collection LICENSE file for details.
