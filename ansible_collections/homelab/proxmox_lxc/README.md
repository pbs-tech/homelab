# Homelab Proxmox LXC Collection

A comprehensive Ansible collection for deploying and managing LXC containers in Proxmox VE, providing essential homelab services with integrated security, monitoring, and automation capabilities.

## Features

- **Automated LXC deployment** with intelligent node placement
- **Comprehensive service stack** covering monitoring, networking, and applications
- **Security-first architecture** with bastion hosts and VPN access
- **Integrated monitoring** with Prometheus, Grafana, and Loki
- **DNS security stack** with Unbound and AdGuard Home
- **Reverse proxy** with Traefik and automatic SSL certificates
- **K3s integration** for unified ingress and service discovery
- **Resource management** with dynamic allocation and scaling

## Service Architecture

### Core Services (192.168.0.200-210)

| Service | IP | Port | Purpose |
|---------|-------|------|----------|
| **Prometheus** | 192.168.0.200 | 9090 | Metrics collection and alerting |
| **Grafana** | 192.168.0.201 | 3000 | Visualization and dashboards |
| **Unbound** | 192.168.0.202 | 53 | Recursive DNS resolver |
| **WireGuard** | 192.168.0.203 | 51820 | VPN server for secure access |
| **AdGuard Home** | 192.168.0.204 | 80 | DNS filtering and ad blocking |
| **Traefik** | 192.168.0.205 | 80/443 | Reverse proxy and SSL termination |
| **AlertManager** | 192.168.0.206 | 9093 | Alert routing and notification |
| **PVE Exporter** | 192.168.0.207 | 9221 | Proxmox metrics for monitoring |
| **Home Assistant** | 192.168.0.208 | 8123 | Home automation platform |
| **OpenWrt** | 192.168.0.209 | 80 | Network management |
| **Loki** | 192.168.0.210 | 3100 | Log aggregation and storage |

### NAS Services (192.168.0.230-235)

| Service | IP | Port | Purpose |
|---------|-------|------|----------|
| **Sonarr** | 192.168.0.230 | 8989 | TV series management |
| **Radarr** | 192.168.0.231 | 7878 | Movie management |
| **Bazarr** | 192.168.0.232 | 6767 | Subtitle management |
| **Prowlarr** | 192.168.0.233 | 9696 | Indexer management |
| **qBittorrent** | 192.168.0.234 | 8080 | BitTorrent client |
| **Jellyfin** | 192.168.0.235 | 8096 | Media streaming server |

### Management Services (192.168.0.109-110)

| Service | IP | Purpose |
|---------|-------|----------|
| **nas-bastion** | 192.168.0.109 | NAS services bastion host |
| **k3s-bastion** | 192.168.0.110 | Main infrastructure bastion |

## Prerequisites

1. **Proxmox VE** host with LXC template available
2. **K3s cluster** managed by [k3s-ansible](https://github.com/k3s-io/k3s-ansible)
3. **Bastion host** (192.168.0.110) with Ansible and kubectl installed
4. **SSH key pair** for container access
5. **DNS resolution** for your homelab domain

## Network Architecture

```text
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

### Deploy all services

```bash
ansible-playbook site.yml
```

### Deploy specific services

```bash
# Deploy containers only
ansible-playbook site.yml --tags "deploy"

# Configure monitoring stack only
ansible-playbook site.yml --tags "monitoring"

# Configure Traefik only
ansible-playbook site.yml --tags "traefik"
```

### Individual service deployment

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

- `https://prometheus.homelab.lan` - Prometheus monitoring
- `https://grafana.homelab.lan` - Grafana dashboards
- `https://ha.homelab.lan` - Home Assistant
- `https://adguard.homelab.lan` - AdGuard Home
- `https://k3s.homelab.lan` - K3s cluster services

## Configuration

### Customizing IP addresses

Override default IPs in your inventory or group vars:

```yaml
prometheus_ip: "192.168.0.220"
grafana_ip: "192.168.0.221"
```

### SSL certificates

Configure Let's Encrypt in `roles/traefik/defaults/main.yml`:

```yaml
ssl_email: "your-email@domain.com"
homelab_domain: "your-domain.com"
```

### Container resources

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

### Secure Enclave (192.168.0.248-252, 10.10.0.0/24)

Isolated pentesting environment for security training and testing.

| Service | Management IP | Isolated IP | Purpose |
|---------|---------------|-------------|---------|
| **Enclave Bastion** | 192.168.0.250 | - | Jump host for enclave access |
| **Enclave Router** | 192.168.0.251 | 10.10.0.1 | Network isolation firewall |
| **Kali Attacker** | 192.168.0.252 | 10.10.0.10 | Security testing workstation |
| **DVWA** | - | 10.10.0.100 | Vulnerable web application |
| **Metasploitable** | - | 10.10.0.101 | Vulnerable target system |

**Security:** Enclave is completely isolated from production (all traffic to 192.168.0.0/24 is blocked).

## Roles

The collection includes 29 roles organized by function:

### Security & Infrastructure

| Role | Description |
|------|-------------|
| `bastion` | Secured jump hosts for infrastructure access |
| `wireguard` | WireGuard VPN server for remote access |
| `traefik` | Reverse proxy with SSL/TLS termination |
| `lxc_container` | Base LXC container creation and configuration |
| `lxc_template` | LXC template management and downloads |
| `secure_enclave` | Isolated pentesting environment deployment |

### Monitoring & Observability

| Role | Description |
|------|-------------|
| `prometheus` | Metrics collection and storage |
| `grafana` | Dashboards and visualization |
| `alertmanager` | Alert routing and notifications |
| `loki` | Log aggregation and querying |
| `promtail` | Log shipping agent |
| `pve_exporter` | Proxmox metrics exporter |

### DNS & Networking

| Role | Description |
|------|-------------|
| `unbound` | Recursive DNS resolver with DNSSEC |
| `adguard` | DNS filtering and ad blocking |
| `openwrt` | Network management and routing |

### Applications

| Role | Description |
|------|-------------|
| `homeassistant` | Home automation platform |
| `sonarr` | TV series management |
| `radarr` | Movie management |
| `bazarr` | Subtitle management |
| `prowlarr` | Indexer management |
| `qbittorrent` | BitTorrent client |
| `jellyfin` | Media streaming server |

### Virtual Machines (KVM/QEMU)

| Role | Description |
|------|-------------|
| `truenas` | TrueNAS SCALE VM (ISO-based install via `vm_base`) |
| `ubuntu_vm` | Ubuntu cloud-init VM (template clone via `vm_base`) |

## Service Interactions

```text
┌──────────────────────────────────────────────────────────────────────────┐
│                        Service Interaction Diagram                        │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   Internet ──▶ WireGuard VPN (203) ──▶ Bastion (110) ──▶ All Services   │
│                       │                                                  │
│                       ▼                                                  │
│   Internet ──▶ Traefik (205) ──┬──▶ LXC Services                        │
│                                │                                         │
│                                └──▶ K3s Cluster (111-114)               │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│   DNS Flow:                                                              │
│   Client ──▶ AdGuard (204) ──▶ Unbound (202) ──▶ Internet               │
│                 │                                                        │
│                 └──▶ Filtering & Ad Blocking                            │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│   Monitoring Flow:                                                       │
│   All Services ──▶ Prometheus (200) ──▶ AlertManager (206)              │
│        │                  │                     │                        │
│        │                  ▼                     ▼                        │
│        │             Grafana (201)         Notifications                 │
│        │                                                                 │
│        └──────▶ Promtail ──▶ Loki (210) ──▶ Grafana (201)               │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│   Media Stack Flow:                                                      │
│   Prowlarr (233) ──▶ Sonarr (230) ──┬──▶ qBittorrent (234)              │
│         │                           │                                    │
│         └──────▶ Radarr (231) ──────┘         │                         │
│                                               ▼                          │
│                              Jellyfin (235) ◀── Media Files             │
│                                    │                                     │
│                        Bazarr (232) ──▶ Subtitles                       │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

## Dynamic Inventory

The collection supports Proxmox dynamic inventory for automatic container discovery:

```bash
# Use dynamic inventory
ansible-playbook -i inventory/proxmox.yml site.yml

# Combine with static inventory
ansible-playbook -i inventory/hosts.yml -i inventory/proxmox.yml site.yml
```

See [DYNAMIC_INVENTORY_SETUP.md](DYNAMIC_INVENTORY_SETUP.md) for detailed configuration.

## Testing

### Molecule Testing

```bash
cd ansible_collections/homelab/proxmox_lxc/

# Run default tests
molecule test

# Run Proxmox integration tests (requires Proxmox access)
molecule test -s proxmox-integration
```

### Production Validation

```bash
# Quick smoke test
ansible-playbook tests/quick-smoke-test.yml

# Full infrastructure validation
ansible-playbook tests/validate-infrastructure.yml

# Service-specific validation
ansible-playbook tests/validate-services.yml
```

## Troubleshooting

### Container creation fails

```bash
# Verify Proxmox API connectivity
curl -k https://192.168.0.56:8006/api2/json/version

# Check LXC template availability
pveam list local

# Verify API token permissions
pveum acl list
```

### Services not accessible

```bash
# Check container status
pct list | grep <container_id>
pct status <container_id>

# Check service inside container
pct exec <container_id> -- systemctl status <service>

# Verify Traefik routing
curl -s http://192.168.0.205:8080/api/http/routers | jq '.[].name'
```

### K3s integration issues

```bash
# Verify kubeconfig from Traefik container
pct exec 205 -- kubectl get nodes

# Check K3s service account
kubectl get serviceaccount traefik-ingress-controller -n traefik-system

# Test connectivity
pct exec 205 -- curl -k https://192.168.0.111:6443/version
```

### DNS resolution problems

```bash
# Test Unbound
dig @192.168.0.202 google.com

# Test AdGuard
dig @192.168.0.204 google.com

# Check DNS service status
pct exec 202 -- systemctl status unbound
pct exec 204 -- systemctl status AdGuardHome
```

## Secure Enclave Deployment

Deploy the isolated pentesting environment:

```bash
# Temporary mode (auto-shutdown after 4h idle)
ansible-playbook playbooks/enclave.yml -e enclave_security_acknowledged=true

# Persistent mode (runs continuously)
ansible-playbook playbooks/enclave.yml \
  -e enclave_security_acknowledged=true \
  -e enclave_persistent_mode=true

# Access enclave
ssh pbs@192.168.0.250  # Enclave bastion
enclave-connect         # Connect to Kali attacker VM
```

## Related Documentation

- [SERVICE-ACCESS-GUIDE.md](../../../docs/SERVICE-ACCESS-GUIDE.md) - How to access all services
- [API.md](../../../docs/API.md) - Service API documentation
- [SECURITY-ARCHITECTURE.md](../../../docs/SECURITY-ARCHITECTURE.md) - Security design
- [DYNAMIC_INVENTORY_SETUP.md](DYNAMIC_INVENTORY_SETUP.md) - Proxmox inventory setup

## Contributing

1. Fork the repository
2. Create feature branch
3. Test changes with Molecule
4. Update documentation
5. Submit pull request

## License

Apache License 2.0 - See LICENSE file for details.
