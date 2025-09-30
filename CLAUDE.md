# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a modular Ansible collection setup for homelab infrastructure management with three core collections:

1. **Common Collection** (`ansible_collections/homelab/common/`) - Shared utilities, roles, and configuration
   for all infrastructure components
2. **K3s Collection** (`ansible_collections/homelab/k3s/`) - Manages K3s Kubernetes cluster deployment
   on Raspberry Pi nodes
3. **Proxmox LXC Collection** (`ansible_collections/homelab/proxmox_lxc/`) - Manages LXC container services
   in Proxmox that integrate with the K3s cluster via Traefik reverse proxy

The infrastructure follows a layered architecture with shared components, independent but integrated
services, and unified orchestration through improved playbook structure.

## Key Commands

### Testing Commands

```bash
# Quick validation (< 2 minutes)
make test-quick

# Full validation suite (< 5 minutes)
make test

# Individual test categories
make test-infrastructure        # LXC containers, K3s nodes health
make test-security             # Security hardening validation
make test-services             # Service functionality checks
make test-api                  # Proxmox API authentication

# Direct playbook execution
ansible-playbook tests/quick-smoke-test.yml
ansible-playbook tests/validate-infrastructure.yml
ansible-playbook tests/validate-security.yml
ansible-playbook tests/validate-services.yml
```

### Security Validation Commands

```bash
# Run comprehensive security audit
./scripts/security-audit.sh

# Test Proxmox API token authentication
ansible-playbook test-proxmox-api-tokens.yml

# Validate Proxmox connectivity
ansible-playbook -i inventory/proxmox.yml playbooks/validate-proxmox.yml --tags validation

# Security hardening test playbook
ansible-playbook test-security-hardening.yml
```

### Main Deployment Commands

```bash
# RECOMMENDED: Security-First Phased Deployment
ansible-playbook playbooks/infrastructure.yml

# Phase-specific deployments
# Bastion hosts and Proxmox setup
ansible-playbook playbooks/infrastructure.yml --tags "foundation,phase1"
# DNS, VPN, reverse proxy
ansible-playbook playbooks/infrastructure.yml --tags "networking,phase2"
# Prometheus, Grafana, Loki
ansible-playbook playbooks/infrastructure.yml --tags "monitoring,phase3"
# Home automation, NAS services
ansible-playbook playbooks/infrastructure.yml --tags "applications,phase4"
# K3s cluster
ansible-playbook playbooks/infrastructure.yml --tags "k3s,phase5"

# LEGACY APPROACH - Still supported for backwards compatibility
ansible-playbook site.yml                                    # Deploy entire infrastructure
ansible-playbook site.yml --tags "k3s,cluster"              # Deploy only K3s cluster
# Deploy only Proxmox LXC services
ansible-playbook site.yml --tags "proxmox,lxc,services"
# Deploy specific service stacks
ansible-playbook site.yml --tags "monitoring"
```

### Security-Focused Deployment

```bash
# Phase 1: Create secured bastion host (run from control machine)
ansible-playbook security-deploy.yml --tags "phase1,bastion"

# Phase 2: Deploy DNS and core security services (run FROM bastion host)
ssh pbs@192.168.0.110
ansible-playbook phase2-security.yml --tags "dns,security"

# Security hardening test playbook
ansible-playbook test-security-hardening.yml
```

### LXC Template Management

```bash
# Download LXC templates only
# (Ubuntu-focused for easier management with pre-installed python)
ansible-playbook site.yml --tags "templates"

# Force re-download of templates
ansible-playbook site.yml --tags "templates" -e "force_download=true"
```

### Individual Collection Commands

```bash
# K3s cluster management
cd ansible_collections/homelab/k3s/
ansible-playbook playbooks/site.yml     # Deploy K3s cluster
ansible-playbook playbooks/reset.yml    # Reset K3s cluster
ansible-playbook playbooks/upgrade.yml  # Upgrade K3s cluster

# LXC services management
cd ansible_collections/homelab/proxmox_lxc/
ansible-playbook site.yml --tags "prometheus"
ansible-playbook site.yml --tags "homeassistant"
```

### Installation

```bash
# Install all required collections and dependencies
ansible-galaxy install -r requirements.yml

# Individual collection installation (if needed)
ansible-galaxy collection install homelab.common
ansible-galaxy collection install homelab.k3s
ansible-galaxy collection install homelab.proxmox_lxc
```

### Code Quality and Linting

```bash
# Quick linting commands
make lint                    # Run all linting checks
make lint-yaml              # Run YAML linting only
make lint-ansible           # Run Ansible linting only
make lint-markdown          # Run Markdown linting only

# Pre-commit hooks (recommended for development)
pre-commit install          # Install pre-commit hooks
pre-commit run --all-files  # Run hooks on all files

# Manual linting commands
yamllint .                  # Check YAML formatting
ansible-lint                # Check Ansible best practices with security profile
pymarkdown --config .markdownlint.yaml scan .  # Check Markdown formatting

# Security scanning
trufflehog git file://. --only-verified  # Scan for secrets
```

## Architecture and Structure

### Network Layout

- **Raspberry Pi K3s cluster**: 192.168.0.111-114
  - k3s-01: 192.168.0.111 (server node)
  - k3s-02, k3s-03, k3s-04: 192.168.0.112-114 (agent nodes)
- **Proxmox hosts**: 192.168.0.56-57 (pve-mac, pve-nas)
- **Bastion hosts**:
  - k3s-bastion: 192.168.0.110 (main bastion)
  - nas-bastion: 192.168.0.109 (NAS services bastion)
- **LXC container networks**:
  - Core services: 192.168.0.200-210
  - NAS services: 192.168.0.230-235
  - NAS monitoring: 192.168.0.240+
- **Domain**: homelab.local

### Core Services Deployed

#### Security & Networking

- **Bastion hosts** (192.168.0.109-110) - Secured jump hosts for infrastructure access
- **Traefik** (192.168.0.205) - Central reverse proxy for LXC and K3s services
- **Unbound/AdGuard** (192.168.0.202,204) - DNS filtering and resolution
- **WireGuard** (192.168.0.203) - VPN server for secure remote access
- **OpenWrt** (192.168.0.209) - Network management and routing

#### Monitoring & Observability

- **Prometheus** (192.168.0.200) - Metrics collection and storage
- **Grafana** (192.168.0.201) - Visualization and dashboards
- **AlertManager** (192.168.0.206) - Alert routing and management
- **Loki** (192.168.0.210) - Log aggregation and storage
- **PVE Exporters** (192.168.0.207, 240) - Proxmox metrics exporters

#### Home Automation & Media

- **Home Assistant** (192.168.0.208) - Home automation platform
- **Sonarr/Radarr/Bazarr** (192.168.0.230-232) - Media management suite
- **Prowlarr** (192.168.0.233) - Indexer management
- **qBittorrent** (192.168.0.234) - BitTorrent client
- **Jellyfin** (192.168.0.235) - Media streaming server

### Directory Structure

```text
/
├── site.yml                         # Legacy main orchestration (backwards compatibility)
├── requirements.yml                 # Consolidated collection and dependency requirements
├── security-deploy.yml              # Security-focused phased deployment
├── phase2-security.yml              # Phase 2 deployment (run from bastion)
├── test-security-hardening.yml      # Security validation playbook
├── playbooks/                       # NEW: Improved orchestration structure
│   ├── infrastructure.yml           # Main phased deployment orchestrator
│   ├── foundation.yml               # Phase 1: Bastion and Proxmox setup
│   ├── networking.yml               # Phase 2: DNS, VPN, reverse proxy
│   ├── monitoring.yml               # Phase 3: Prometheus, Grafana, Loki
│   └── applications.yml             # Phase 4: Home automation, NAS services
├── tests/                           # Fast validation tests (< 5 min total)
│   ├── quick-smoke-test.yml         # 30s validation of critical components
│   ├── validate-infrastructure.yml  # Infrastructure health checks
│   ├── validate-security.yml        # Security hardening verification
│   └── validate-services.yml        # Service functionality tests
└── ansible_collections/homelab/
    ├── common/                      # NEW: Shared utilities and configuration
    │   ├── galaxy.yml               # Common collection metadata
    │   ├── requirements.yml         # Common dependencies
    │   ├── inventory/group_vars/    # Shared infrastructure configuration
    │   └── roles/                   # Shared roles (common_setup, container_base,
    │                                # security_hardening)
    ├── k3s/                         # K3s cluster management
    │   ├── playbooks/site.yml       # K3s deployment
    │   ├── inventory/hosts.yml      # Raspberry Pi inventory
    │   └── roles/                   # K3s-specific roles (k3s_server, k3s_agent,
    │                                # airgap)
    └── proxmox_lxc/                 # LXC services management
        ├── site.yml                 # LXC services orchestration
        ├── inventory/               # Dynamic and static inventory
        │   ├── proxmox.yml          # Dynamic Proxmox inventory
        │   └── hosts.yml.static-backup  # Backup of static inventory
        └── roles/                   # Service roles (traefik, prometheus,
                                     # grafana, etc.)
```

## Key Integration Points

### K3s Cluster Integration

- Traefik acts as unified ingress controller for both LXC services and K3s workloads
- Service account and RBAC configured for Kubernetes API access
- Certificate authority and token management for secure K3s communication

### Configuration Management

- Global variables in `inventory/group_vars/all.yml` define network topology and service settings
- Role-specific defaults in `roles/*/defaults/main.yml` for service configurations
- Jinja2 templates generate service-specific configuration files

### Security Model

- **Defense in Depth**: Multi-layered security with bastion hosts, VPN access, and network segmentation
- **Bastion Architecture**: All infrastructure access routes through secured bastion hosts
- **Phased Deployment**: Security-first deployment approach with DNS security before service deployment
- **Container Security**: All LXC containers run unprivileged by default with security hardening
- **Authentication**: SSH key-based authentication across all services
- **SSL/TLS**: Certificate management handled centrally by Traefik with Let's Encrypt
- **Network Security**: Service-specific firewall rules and network segmentation
- **Security Hardening**: Automated security hardening roles for both K3s nodes and LXC containers

## Development Patterns

### Role Structure

Each role follows standard Ansible organization with comprehensive documentation:

```text
roles/{role_name}/
├── README.md              # Role documentation and usage
├── tasks/main.yml         # Main role tasks
├── defaults/main.yml      # Default variables
├── templates/             # Jinja2 configuration templates
└── handlers/main.yml      # Service restart/reload handlers
```

### Documentation Standards

- **README.md** files for all major roles and collections
- **Inline comments** for complex tasks and variables
- **Usage examples** with common configuration patterns
- **Troubleshooting guides** for common issues
- **Security considerations** for each component

### Deployment Strategy

The collection implements:

- **Idempotent operations** with proper change detection
- **Error handling** with rollback capabilities
- **Dependency management** between services
- **Tagged deployment** for selective service management
- **Resource validation** before deployment
- **Security-first approach** with hardening by default

**Security-First Approach**:

1. **Phase 1**: Deploy bastion hosts with hardened security configurations
2. **Phase 2**: Deploy DNS security infrastructure (Unbound/AdGuard) from bastion
3. **Phase 3**: Deploy VPN and reverse proxy services
4. **Standard Deployment**: Use traditional site.yml for normal operations after security foundation

**Service Organization**:

- **Core services** grouped by function (monitoring, networking, automation)
- **NAS services** isolated on separate network segments for security
- **Management services** on dedicated bastion hosts
- **Service stacks** deployed independently via tags with dependency management
- **Resource allocation** with intelligent node placement
- **Health checks** and validation for all services

**Testing Strategy**:

- **Fast smoke tests** - 30-second validation of critical components
- **Infrastructure validation** - Health checks for all deployed services (< 3 min)
- **Security validation** - Security hardening verification (< 3 min)
- **Service validation** - Functional testing of all services (< 4 min)
- **Total test time** - Complete validation in under 5 minutes
- **CI/CD integration** - Automated linting and validation via GitHub Actions

**Documentation Coverage**:

- **Repository README** with comprehensive overview and quick start
- **Collection READMEs** with detailed feature descriptions
- **Role documentation** for major components (Traefik, Security Hardening, etc.)
- **API documentation** via galaxy.yml metadata
- **Security architecture** documentation with threat model
- **Testing procedures** (TESTING.md) with practical validation approaches
- **Troubleshooting guides** with common issues and solutions
