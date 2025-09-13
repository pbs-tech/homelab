# Homelab Proxmox LXC Collection

This Ansible collection automates the deployment of LXC containers in Proxmox for various homelab services, with Traefik providing HTTPS connectivity to both LXC services and existing K3s cluster services.

## Services Deployed

- **Prometheus** (192.168.0.200:9090) - Metrics collection and monitoring
- **Grafana** (192.168.0.201:3000) - Metrics visualization and dashboards
- **Unbound** (192.168.0.202:53) - Recursive DNS resolver
- **WireGuard** (192.168.0.203:51820) - VPN server
- **AdGuard Home** (192.168.0.204:80) - DNS filtering and ad blocking
- **Traefik** (192.168.0.205:80/443) - Reverse proxy and load balancer
- **AlertManager** (192.168.0.206:9093) - Alert routing and management
- **Proxmox VE Exporter** (192.168.0.207:9221) - Proxmox metrics for Prometheus
- **Home Assistant** (192.168.0.208:8123) - Home automation platform

## Prerequisites

1. **Proxmox VE** host with LXC template available
2. **K3s cluster** managed by [k3s-ansible](https://github.com/k3s-io/k3s-ansible)
3. **Bastion host** (192.168.0.110) with Ansible and kubectl installed
4. **SSH key pair** for container access
5. **DNS resolution** for your homelab domain

## Network Architecture

```
Internet
    ↓
Traefik LXC (192.168.0.205)
    ↓
┌─────────────────┬─────────────────┐
│   LXC Services  │   K3s Cluster   │
│                 │                 │
│ • Prometheus    │ • Node 1 (.111) │
│ • Grafana       │ • Node 2 (.112) │
│ • Home Assistant│ • Node 3 (.113) │
│ • etc.          │ • Node 4 (.114) │
└─────────────────┴─────────────────┘
```

## Installation

1. **Install the collection:**
   ```bash
   ansible-galaxy collection install homelab.proxmox_lxc
   ```

2. **Update inventory variables:**
   Edit `inventory/group_vars/all.yml` with your specific settings:
   - Proxmox host IP
   - SSH keys
   - Domain settings

3. **Configure Proxmox authentication:**
   Set up SSH key authentication or API tokens for secure access.

## Usage

### Deploy all services:
```bash
ansible-playbook site.yml
```

### Deploy specific services:
```bash
# Deploy containers only
ansible-playbook site.yml --tags "deploy"

# Configure monitoring stack only
ansible-playbook site.yml --tags "monitoring"

# Configure Traefik only
ansible-playbook site.yml --tags "traefik"
```

### Individual service deployment:
```bash
# Deploy and configure Prometheus
ansible-playbook site.yml --tags "prometheus"

# Deploy and configure Home Assistant
ansible-playbook site.yml --tags "homeassistant"
```

## K3s Integration

The collection integrates with your existing K3s cluster by:

1. **Service Discovery**: Traefik automatically discovers K3s services via Kubernetes API
2. **Load Balancing**: Distributes traffic across K3s nodes
3. **SSL Termination**: Provides HTTPS for both LXC and K3s services
4. **Ingress Controller**: Acts as ingress controller for K3s workloads

### Accessing Services

After deployment, services will be available at:

- `https://prometheus.homelab.local` - Prometheus monitoring
- `https://grafana.homelab.local` - Grafana dashboards
- `https://ha.homelab.local` - Home Assistant
- `https://adguard.homelab.local` - AdGuard Home
- `https://k3s.homelab.local` - K3s cluster services

## Configuration

### Customizing IP addresses:
Override default IPs in your inventory or group vars:
```yaml
prometheus_ip: "192.168.0.220"
grafana_ip: "192.168.0.221"
```

### SSL certificates:
Configure Let's Encrypt in `roles/traefik/defaults/main.yml`:
```yaml
ssl_email: "your-email@domain.com"
homelab_domain: "your-domain.com"
```

### Container resources:
Adjust container specs in `playbooks/deploy_services.yml`:
```yaml
container_memory: 2048
container_cores: 2
container_disk_size: "32"
```

## Monitoring Integration

The collection sets up comprehensive monitoring:

- **Prometheus** scrapes metrics from:
  - K3s nodes (node-exporter on port 9100)
  - K3s API server and workloads
  - LXC services
  - Proxmox host
  
- **Grafana** provides pre-configured dashboards for:
  - K3s cluster overview
  - Node resource utilization
  - Service health and performance
  - Proxmox infrastructure

## Security

- All containers run unprivileged by default
- SSH key-based authentication
- Traefik handles SSL/TLS termination
- Network segmentation via LXC containers
- Service-specific firewall rules

## Troubleshooting

### Container creation fails:
- Verify Proxmox API connectivity
- Check LXC template availability
- Ensure sufficient Proxmox resources

### Services not accessible:
- Verify DNS resolution for homelab domain
- Check Traefik logs: `systemctl status traefik` or `journalctl -u traefik -f`
- Confirm firewall rules allow traffic

### K3s integration issues:
- Verify kubeconfig accessibility from Traefik container
- Check K3s service account permissions
- Ensure network connectivity between Traefik and K3s nodes

## Contributing

1. Fork the repository
2. Create feature branch
3. Test changes thoroughly
4. Submit pull request

## License

MIT