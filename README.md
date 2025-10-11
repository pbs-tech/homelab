# Homelab Infrastructure Automation

A comprehensive Ansible-based infrastructure management solution for homelab environments, featuring modular collections for K3s clusters, Proxmox LXC services, and integrated security architecture.

## 🏗️ Architecture Overview

This repository implements a layered homelab infrastructure using three core Ansible collections:

- **[homelab.common](ansible_collections/homelab/common/)** - Shared utilities, roles, and configuration
- **[homelab.k3s](ansible_collections/homelab/k3s/)** - K3s Kubernetes cluster on Raspberry Pi nodes
- **[homelab.proxmox_lxc](ansible_collections/homelab/proxmox_lxc/)** - LXC container services in Proxmox

### Infrastructure Components

```text
┌─────────────────────────────────────────────────────────────────┐
│                        Internet                                 │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                ┌─────▼─────┐
                │ WireGuard │ VPN Access
                │ (203)     │ 192.168.0.203
                └─────┬─────┘
                      │
        ┌─────────────▼─────────────┐
        │      Bastion Hosts        │
        │ k3s-bastion (110)         │ Management Layer
        │ nas-bastion (109)         │ 192.168.0.109-110
        └─────────┬─────────────────┘
                  │
    ┌─────────────▼─────────────────────────┐
    │            Traefik                    │ Reverse Proxy
    │         192.168.0.205                 │ SSL Termination
    └─────┬─────────────────────────────┬───┘
          │                             │
    ┌─────▼─────┐               ┌───────▼────┐
    │LXC Services│               │K3s Cluster │
    │Core: 200-210│              │111-114     │
    │NAS: 230-235 │              │            │
    │Monitor: 240+│              │            │
    └───────────────┘              └────────────┘
```

### Service Architecture

#### Security & Networking (Phase 1-2)

- **Bastion Hosts** - Secured jump hosts for infrastructure access
- **DNS Security Stack** - Unbound + AdGuard for secure DNS resolution
- **WireGuard VPN** - Encrypted remote access tunnel
- **Traefik** - Central reverse proxy with Let's Encrypt SSL

#### Monitoring & Observability (Phase 3)

- **Prometheus** - Metrics collection and alerting
- **Grafana** - Visualization and dashboards
- **Loki + Promtail** - Log aggregation and analysis
- **AlertManager** - Alert routing and notification

#### Applications & Services (Phase 4-5)

- **Home Assistant** - Home automation platform
- **Media Stack** - Sonarr, Radarr, Jellyfin, qBittorrent
- **K3s Cluster** - Container orchestration on Raspberry Pi

## 🚀 Quick Start

### Prerequisites

- Ansible 2.17.0+
- Python 3.12+
- SSH access to target hosts
- Domain name for homelab services

### Installation

1. **Clone the repository:**

   ```bash
   git clone <repository-url>
   cd homelab
   ```

2. **Install dependencies:**

   ```bash
   ansible-galaxy install -r requirements.yml
   ```

3. **Configure inventory:**

   ```bash
   # Copy and customize inventory files
   cp inventory/hosts.yml.example inventory/hosts.yml
   cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml

   # Create vault file for sensitive data
   ansible-vault create inventory/group_vars/all/vault.yml
   ```

### Deployment Options

#### 🔒 Recommended: Security-First Deployment

Deploy with security hardening from the beginning:

```bash
# Phase 1: Foundation (Bastion + Proxmox setup)
ansible-playbook playbooks/infrastructure.yml --tags "foundation,phase1"

# Phase 2: Networking (DNS, VPN, Reverse proxy)
ansible-playbook playbooks/infrastructure.yml --tags "networking,phase2"

# Phase 3: Monitoring (Prometheus, Grafana, Loki)
ansible-playbook playbooks/infrastructure.yml --tags "monitoring,phase3"

# Phase 4: Applications (Home automation, Media)
ansible-playbook playbooks/infrastructure.yml --tags "applications,phase4"

# Phase 5: K3s Cluster
ansible-playbook playbooks/infrastructure.yml --tags "k3s,phase5"
```

#### ⚡ Alternative: Full Infrastructure Deployment

Deploy everything at once:

```bash
ansible-playbook playbooks/infrastructure.yml
```

#### 🎯 Selective Service Deployment

Deploy specific service stacks:

```bash
# Monitoring stack only
ansible-playbook playbooks/monitoring.yml

# Home automation services
ansible-playbook site.yml --tags "homeassistant"

# K3s cluster management
cd ansible_collections/homelab/k3s/
ansible-playbook playbooks/site.yml
```

## 📋 Service Inventory

| Service | IP Address | Purpose | Collection |
|---------|------------|---------|------------|
| **Security & Networking** | | |
| k3s-bastion | 192.168.0.110 | Management bastion | proxmox_lxc |
| nas-bastion | 192.168.0.109 | NAS services bastion | proxmox_lxc |
| WireGuard | 192.168.0.203 | VPN server | proxmox_lxc |
| Traefik | 192.168.0.205 | Reverse proxy | proxmox_lxc |
| Unbound | 192.168.0.202 | DNS resolver | proxmox_lxc |
| AdGuard Home | 192.168.0.204 | DNS filtering | proxmox_lxc |
| **Monitoring** | | |
| Prometheus | 192.168.0.200 | Metrics collection | proxmox_lxc |
| Grafana | 192.168.0.201 | Visualization | proxmox_lxc |
| AlertManager | 192.168.0.206 | Alert routing | proxmox_lxc |
| Loki | 192.168.0.210 | Log aggregation | proxmox_lxc |
| **Applications** | | |
| Home Assistant | 192.168.0.208 | Home automation | proxmox_lxc |
| Sonarr | 192.168.0.230 | TV management | proxmox_lxc |
| Radarr | 192.168.0.231 | Movie management | proxmox_lxc |
| Jellyfin | 192.168.0.235 | Media streaming | proxmox_lxc |
| **Cluster** | | |
| k3s-01 | 192.168.0.111 | K3s server node | k3s |
| k3s-02-04 | 192.168.0.112-114 | K3s agent nodes | k3s |

## 🔧 Configuration

### Network Configuration

Edit `inventory/group_vars/all.yml` to customize:

```yaml
# Domain configuration
homelab_domain: "homelab.local"
external_domain: "yourdomain.com"

# Network settings
network_cidr: "192.168.0.0/24"
gateway_ip: "192.168.0.1"

# Proxmox settings
proxmox_hosts:
  pve-mac: "192.168.0.56"
  pve-nas: "192.168.0.57"
```

### SSL Certificates

Configure Let's Encrypt in your vault:

```yaml
# inventory/group_vars/all/vault.yml
vault_ssl_email: "your-email@domain.com"
vault_cloudflare_api_token: "your_cloudflare_token"  # if using DNS challenge
```

### Service Customization

Override service defaults in inventory:

```yaml
# Custom resource allocation
prometheus_resources:
  memory: 4096
  cores: 4
  disk_size: "100"

# Custom service configuration
grafana_config:
  admin_password: "{{ vault_grafana_admin_password }}"
  plugins:
    - grafana-piechart-panel
    - grafana-worldmap-panel
```

## 🧪 Testing

The repository includes comprehensive testing using Molecule 6.0+ for collection development and fast validation tests for production infrastructure:

### Prerequisites

```bash
# Install testing dependencies
pip install "molecule>=6.0" "molecule-plugins[docker]>=23.5.0"
pip install "ansible-core>=2.17" "yamllint>=1.35" "ansible-lint>=24.0"
```

### Molecule Collection Testing

Test collections in isolated environments:

```bash
# Common collection - Docker-based unit tests
cd ansible_collections/homelab/common/
molecule test

# K3s collection - Real Raspberry Pi hardware tests (default driver)
cd ansible_collections/homelab/k3s/
molecule test -s raspberry-pi

# Proxmox LXC collection - Service integration tests (docker driver)
cd ansible_collections/homelab/proxmox_lxc/
molecule test -s service-stack

# Full stack integration test
cd molecule/full-stack/
molecule test
```

**Note:** Molecule 6.0+ uses the `default` driver for testing on real infrastructure (Raspberry Pi, Proxmox) and `docker` driver for containerized tests. The `delegated` driver from earlier versions is now named `default`.

### Production Validation

Fast validation tests for deployed infrastructure (< 5 minutes total):

```bash
# Quick smoke test (30 seconds)
make test-quick

# Full validation suite
make test

# Individual test suites
make test-infrastructure  # Container and K3s health
make test-security       # Security hardening validation
make test-services       # Service functionality checks
```

See [TESTING.md](TESTING.md) for detailed testing procedures and [collection TESTING.md files](ansible_collections/homelab/*/TESTING.md) for collection-specific testing.

## 🔒 Security

This infrastructure implements defense-in-depth security:

- **Bastion Architecture** - All access via secured jump hosts
- **Network Segmentation** - Services isolated in appropriate zones
- **Zero Trust Networking** - TLS everywhere with automatic certificate management
- **DNS Security** - Unbound + AdGuard filtering malicious domains
- **Container Security** - Unprivileged LXC containers with hardening
- **SSH Hardening** - Key-based authentication, fail2ban protection

See [SECURITY-ARCHITECTURE.md](SECURITY-ARCHITECTURE.md) and [.github/SECURITY.md](.github/SECURITY.md) for detailed security information.

## 📚 Documentation

### Getting Started

- [INSTALLATION.md](INSTALLATION.md) - Complete step-by-step installation guide
- [CLAUDE.md](CLAUDE.md) - Repository guidance and key commands
- [API.md](API.md) - Comprehensive API documentation for all services

### Core Documentation

- [TESTING.md](TESTING.md) - Comprehensive testing strategy with Molecule 6.0+ and production tests
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Detailed troubleshooting guide for common issues
- [SECURITY-ARCHITECTURE.md](SECURITY-ARCHITECTURE.md) - Security design and threat model

### Collection Documentation

- [homelab.common](ansible_collections/homelab/common/README.md) - Shared utilities and roles
- [homelab.k3s](ansible_collections/homelab/k3s/README.md) - K3s cluster management
- [homelab.proxmox_lxc](ansible_collections/homelab/proxmox_lxc/README.md) - LXC service deployment

### Role Documentation

- [Traefik Role](ansible_collections/homelab/proxmox_lxc/roles/traefik/README.md) - Reverse proxy and SSL termination
- [Security Hardening Role](ansible_collections/homelab/common/roles/security_hardening/README.md) - Comprehensive security hardening

### Specialized Guides

- [CLIENT-VPN-SETUP.md](CLIENT-VPN-SETUP.md) - VPN client configuration
- [Dynamic Inventory Setup](ansible_collections/homelab/proxmox_lxc/DYNAMIC_INVENTORY_SETUP.md) - Proxmox dynamic inventory
- [DEVOPS_ASSESSMENT.md](DEVOPS_ASSESSMENT.md) - DevOps practices assessment

## 🛠️ Development

### Code Quality

The repository includes comprehensive linting and quality checks:

```bash
# Run all quality checks
make lint

# Individual checks
make lint-yaml      # YAML formatting (yamllint 1.35+)
make lint-ansible   # Ansible best practices (ansible-lint 24.0+)
make lint-markdown  # Markdown formatting

# Pre-commit hooks
pre-commit install
pre-commit run --all-files
```

### CI/CD Pipeline

Automated testing and validation via GitHub Actions:

- **Linting**: YAML, Ansible, Markdown validation
- **Security**: TruffleHog secret scanning
- **Molecule Tests**: All collection scenarios (Python 3.12, Ansible 2.17+)
- **Collection Validation**: Galaxy import validation

See [.github/workflows/](/.github/workflows/) for pipeline configurations.

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following existing patterns
4. Run tests: `molecule test` and `make lint`
5. Update documentation as needed
6. Submit a pull request

### Collection Development

Each collection follows standard Ansible patterns:

```text
ansible_collections/homelab/{collection}/
├── galaxy.yml              # Collection metadata
├── README.md              # Collection documentation
├── requirements.yml       # Dependencies
├── roles/                 # Collection roles
│   └── {role}/
│       ├── tasks/         # Role tasks
│       ├── defaults/      # Default variables
│       ├── templates/     # Jinja2 templates
│       └── handlers/      # Event handlers
├── playbooks/            # Collection playbooks
├── inventory/            # Inventory configuration
└── molecule/             # Testing scenarios
```

## 🔍 Troubleshooting

For comprehensive troubleshooting guidance, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

### Quick Health Check

```bash
# Run system health check
for service in traefik prometheus grafana; do
  echo -n "Testing $service: "
  curl -s -o /dev/null -w "%{http_code}" "https://$service.homelab.local" |
    grep -q "200\|401\|302" && echo "OK" || echo "FAILED"
done
```

### Common Issues

#### Container Problems

```bash
# Check container status
for i in {200..210}; do
  pct status $i
done

# Review container logs
pct exec 205 -- journalctl -u traefik -f
```

#### Network Connectivity

```bash
# Test DNS resolution
nslookup prometheus.homelab.local 192.168.0.204
# Check service connectivity
telnet 192.168.0.200 9090
```

#### K3s Cluster Issues

```bash
# Check cluster health
kubectl --kubeconfig=/tmp/k3s.yaml get nodes
kubectl --kubeconfig=/tmp/k3s.yaml get pods --all-namespaces
```

### Getting Help

- **Comprehensive Guide**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Detailed troubleshooting for all services
- **API Issues**: [API.md](API.md) - API troubleshooting and testing
- **Installation Problems**: [INSTALLATION.md](INSTALLATION.md) - Installation troubleshooting
- **Testing Issues**: [TESTING.md](TESTING.md) - Test troubleshooting procedures
- **Community**: Check [Issues](../../issues) for known problems
- **Debug Mode**: Use `ansible-playbook -vvv` for verbose output

## 📄 License

This project is licensed under the Apache License 2.0 - see individual collection LICENSE files for details.

## 🙏 Acknowledgements

- [k3s-io/k3s-ansible](https://github.com/k3s-io/k3s-ansible) - Inspiration for K3s deployment patterns
- [geerlingguy/ansible-role-*](https://github.com/geerlingguy) - Ansible role development patterns
- [awesome-selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted) - Service selection guidance

---

Built with ❤️ for the homelab community
