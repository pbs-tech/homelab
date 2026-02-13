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
make test-enclave              # Secure enclave network isolation and security
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
# Secure enclave (requires explicit acknowledgement)
ansible-playbook playbooks/infrastructure.yml --tags "enclave,phase6" \
  -e enclave_security_acknowledged=true -e enclave_persistent_mode=true

# LEGACY APPROACH - Still supported for backwards compatibility
ansible-playbook site.yml                                    # Deploy entire infrastructure
ansible-playbook site.yml --tags "k3s,cluster"              # Deploy only K3s cluster
# Deploy only Proxmox LXC services
ansible-playbook site.yml --tags "proxmox,lxc,services"
# Deploy specific service stacks
ansible-playbook site.yml --tags "monitoring"
```

### System Maintenance Commands

```bash
# Update all systems (Raspberry Pis rolling one-at-a-time, LXC containers 3-at-a-time)
ansible-playbook playbooks/update-systems.yml

# Update only Raspberry Pis
ansible-playbook playbooks/update-systems.yml --tags pi

# Update only LXC containers
ansible-playbook playbooks/update-systems.yml --tags lxc

# Restart all K3s deployments (rolling restart)
ansible-playbook playbooks/restart-k3s-pods.yml

# Restart deployments in a specific namespace
ansible-playbook playbooks/restart-k3s-pods.yml -e target_namespace=monitoring

# Restart a specific deployment
ansible-playbook playbooks/restart-k3s-pods.yml -e target_deployment=nginx

# Dry run (show what would restart)
ansible-playbook playbooks/restart-k3s-pods.yml -e dry_run=true

# Makefile shortcuts
make update-systems              # Update all systems
make update-pi                   # Update Raspberry Pis only
make update-lxc                  # Update LXC containers only
make restart-k3s-pods            # Restart all K3s deployments
make restart-k3s-pods TARGET_NS=monitoring    # Restart in namespace
make restart-k3s-pods TARGET_DEPLOY=nginx     # Restart specific deployment
```

### Security-Focused Deployment

```bash
# Phase 1: Deploy bastion hosts and foundation infrastructure
ansible-playbook playbooks/infrastructure.yml --tags "foundation,phase1"

# Phase 2: Deploy DNS, VPN, and reverse proxy services
ansible-playbook playbooks/infrastructure.yml --tags "networking,phase2"

# Security hardening test playbook
ansible-playbook test-security-hardening.yml
```

> **Note:** The legacy `security-deploy.yml` and `phase2-security.yml` files still exist for
> backwards compatibility but the phased deployment via `playbooks/infrastructure.yml` is the
> recommended approach.

### Secure Enclave Deployment (Pentesting Environment)

**Security Acknowledgement Required:** Before deploying the secure enclave, you must acknowledge
the security risks by setting `enclave_security_acknowledged: true` in your inventory or via
extra vars (`-e enclave_security_acknowledged=true`).

The secure enclave can be deployed in two modes:

- **Temporary mode** (default): Auto-shutdown after 4h idle, components don't auto-start on boot
- **Persistent mode**: Runs continuously like other infrastructure, all components auto-start on boot

```bash
# Deploy enclave in TEMPORARY mode (auto-shutdown enabled)
ansible-playbook playbooks/enclave.yml -e enclave_security_acknowledged=true

# Deploy enclave in PERSISTENT mode (runs continuously, integrated with infrastructure)
ansible-playbook playbooks/enclave.yml \
  -e enclave_security_acknowledged=true \
  -e enclave_persistent_mode=true

# Deploy as Phase 6 of infrastructure (persistent mode)
ansible-playbook playbooks/infrastructure.yml --tags "enclave,phase6" \
  -e enclave_security_acknowledged=true \
  -e enclave_persistent_mode=true

# Makefile shortcuts
make deploy-enclave              # Temporary mode
make deploy-enclave-persistent   # Persistent mode
make deploy-phase6               # Same as deploy-enclave-persistent
make enclave-status              # Check enclave status
make enclave-shutdown            # Emergency shutdown all VMs

# Deploy specific enclave components
ansible-playbook playbooks/enclave.yml --tags network,firewall  # Network isolation only
ansible-playbook playbooks/enclave.yml --tags infrastructure    # Bastion and router
ansible-playbook playbooks/enclave.yml --tags attacker          # Kali attacker VM
ansible-playbook playbooks/enclave.yml --tags vulnerable        # Vulnerable targets

# Access enclave (from production bastion)
ssh pbs@192.168.0.250  # Enclave bastion
enclave-status         # Check status
enclave-connect        # Connect to attacker VM
enclave-monitor        # Real-time monitoring
enclave-shutdown       # Emergency shutdown all VMs

# Verify network isolation
# From attacker VM (10.10.0.10):
ping 192.168.0.200     # Should FAIL (blocked to production)
ping 8.8.8.8           # Should SUCCEED (internet allowed)
nmap -sn 10.10.0.0/24  # Scan enclave targets
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

### Vault Setup (Required for Proxmox Authentication)

The Proxmox dynamic inventory requires vault variables for API authentication.

```bash
# Create vault file from example
cp inventory/group_vars/all/vault.yml.example inventory/group_vars/all/vault.yml

# Encrypt the vault file
ansible-vault encrypt inventory/group_vars/all/vault.yml

# Edit encrypted vault to add your credentials
ansible-vault edit inventory/group_vars/all/vault.yml
```

Required vault variables:

**Proxmox API Authentication:**

- `vault_proxmox_api_tokens.pve_mac.token_id` - API token ID for pve-mac
- `vault_proxmox_api_tokens.pve_mac.token_secret` - API token secret for pve-mac
- `vault_proxmox_api_tokens.pve_nas.token_id` - API token ID for pve-nas
- `vault_proxmox_api_tokens.pve_nas.token_secret` - API token secret for pve-nas
- `vault_ssl_email` - Email for Let's Encrypt certificates

**Service Secrets (required for deployment):**

- `vault_grafana_admin_password` - Grafana admin password
- `vault_grafana_secret_key` - Grafana secret key for signing (generate with: `openssl rand -base64 32`)
- `vault_adguard_admin_password` - AdGuard Home admin password (minimum 12 characters)
- `vault_wireguard_server_private_key` - WireGuard server private key (generate with: `wg genkey`)

To create Proxmox API tokens:

1. Login to Proxmox web UI
2. Navigate to Datacenter > Permissions > API Tokens
3. Create token with privileges: `VM.Allocate, VM.Config.*, VM.Console, VM.PowerMgmt,
   Datastore.AllocateSpace, Sys.Audit`

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
yamllint .                  # Check YAML formatting (yamllint 1.35+)
ansible-lint                # Check Ansible best practices (ansible-lint 24.0+)
pymarkdown --config .markdownlint.yaml scan .  # Check Markdown formatting

# Security scanning
trufflehog git file://. --only-verified  # Scan for secrets
```

### Molecule Testing Commands

Molecule 6.0+ provides comprehensive testing for Ansible roles and collections. The project includes
both Makefile targets for convenient execution and direct molecule commands for advanced usage.

#### Quick Start - Makefile Targets

```bash
# RECOMMENDED: Fast smoke test for all roles across all collections (< 5 min)
make test-molecule-smoke

# Run all molecule tests across all collections (recommended for CI/pre-commit)
make test-molecule-all

# Test individual collections
make test-molecule-common        # Test common collection
make test-molecule-k3s          # Test K3s collection
make test-molecule-proxmox      # Test Proxmox LXC collection

# Run molecule tests with specific scenarios
make test-molecule              # Run default scenario in current directory
```

**When to use each target:**

- `make test-molecule-smoke` - **RECOMMENDED**: Fast validation of all roles across all collections (< 5 min)
- `make test-molecule-all` - Before committing changes, in CI/CD pipelines
- `make test-molecule-common` - When modifying common roles (security_hardening, container_base, etc.)
- `make test-molecule-k3s` - When modifying K3s cluster configuration or roles
- `make test-molecule-proxmox` - When modifying LXC service roles or deployment logic
- `make test-molecule` - Quick testing in the current collection directory during development

#### Direct Molecule Commands

```bash
# Install Molecule testing dependencies
pip install "molecule>=6.0" "molecule-plugins[docker]>=23.5.0"
pip install "ansible-core>=2.17" "yamllint>=1.35" "ansible-lint>=24.0"

# Fast smoke test for ALL roles (< 5 min, from repository root)
molecule test -s smoke

# Test individual collections with default scenario
cd ansible_collections/homelab/common && molecule test
cd ansible_collections/homelab/k3s && molecule test
cd ansible_collections/homelab/proxmox_lxc && molecule test

# Test specific scenarios
molecule test -s smoke                                             # Smoke test all roles
cd ansible_collections/homelab/common && molecule test -s common-roles
cd ansible_collections/homelab/k3s && molecule test -s raspberry-pi
cd ansible_collections/homelab/proxmox_lxc && molecule test -s proxmox-integration

# Molecule development workflow (iterative testing)
molecule create              # Create test environment
molecule converge           # Run playbook (repeatable)
molecule verify             # Run verification tests
molecule destroy            # Clean up test environment

# Smoke test development workflow
molecule create -s smoke     # Create smoke test instances
molecule converge -s smoke   # Run smoke test playbook
molecule verify -s smoke     # Run smoke test verification
molecule destroy -s smoke    # Clean up smoke test instances

# List available scenarios
molecule list               # Show all scenarios in current collection

# Debugging failed tests
molecule converge           # Re-run without destroying environment
molecule login              # SSH into test container/instance
molecule --debug test       # Run with verbose debug output
```

#### Collection-Specific Testing

**Common Collection** (`homelab.common`):

```bash
cd ansible_collections/homelab/common

# Test all common roles (default scenario)
molecule test

# Test specific role scenario
molecule test -s common-roles

# Available scenarios: default, common-roles
# Tests: security_hardening, container_base, common_setup roles
```

**K3s Collection** (`homelab.k3s`):

```bash
cd ansible_collections/homelab/k3s

# Test K3s deployment on real Raspberry Pi nodes (requires infrastructure)
molecule test -s raspberry-pi

# Note: K3s tests require actual Raspberry Pi hardware at 192.168.0.111-114
# Use 'driver: name: default' for real infrastructure testing
```

**Proxmox LXC Collection** (`homelab.proxmox_lxc`):

```bash
cd ansible_collections/homelab/proxmox_lxc

# Test basic LXC role structure (default scenario)
molecule test

# Test Proxmox integration (requires Proxmox access)
molecule test -s proxmox-integration

# Note: Integration tests require Proxmox hosts at 192.168.0.56-57
```

#### CI/CD Integration

Molecule tests are automatically executed in GitHub Actions CI pipeline via two workflows:

**1. Smoke Test Workflow** (`.github/workflows/molecule-smoke.yml`)
- **Purpose:** Fast validation of ALL roles across all collections
- **Trigger:** Pull requests, pushes to main/molecule branches, workflow_dispatch
- **Duration:** < 15 minutes total (typically 5-8 minutes)
- **Strategy:** Single job testing all collections in one comprehensive smoke test
- **Optimal for:** Quick feedback on role changes, pre-commit validation

**2. Standard Molecule Workflow** (`.github/workflows/ci.yml`)
- **Purpose:** Comprehensive collection-specific testing
- **Trigger:** Pull requests, pushes to main, manual workflow dispatch
- **Strategy:** Matrix testing across all three collections in parallel
- **Duration:** Typically 3-5 minutes per collection
- **Requirements:** Python 3.12, Ansible 2.17+, Docker for container-based tests

**CI Workflow highlights:**

- Smoke test runs first for fast feedback
- Standard tests run after successful linting checks
- Tests each collection independently with dependency resolution
- Uses Docker driver for fast, isolated testing
- Automatically installs collection dependencies (e.g., homelab.common for k3s/proxmox_lxc)
- Caches Ansible collections for faster execution

**View CI results:**

```bash
# Check CI status from command line
make ci-status

# Or view in GitHub
# Navigate to: Actions > Molecule Smoke Test or CI workflow > Latest run
```

#### Best Practices

1. **Before committing:** Run `make test-molecule-smoke` for fast validation (< 5 min) or `make test-molecule-all` for comprehensive testing
2. **During development:** Use `molecule converge` for rapid iteration without destroying the environment
3. **For debugging:** Use `molecule --debug converge` to see detailed output
4. **Real infrastructure:** Use `driver: name: default` for testing on actual hardware (K3s Pi nodes, Proxmox)
5. **Docker testing:** Use `driver: name: docker` with molecule-plugins for fast, isolated unit tests
6. **Scenario organization:** Keep scenarios focused - unit tests in default, integration in named scenarios

#### Troubleshooting

**Common issues:**

```bash
# Molecule not found
pip install "molecule>=6.0" "molecule-plugins[docker]>=23.5.0"

# Docker driver not available
pip install "molecule-plugins[docker]>=23.5.0"

# Stale test environment
molecule destroy && molecule test

# Permission issues with Docker
sudo usermod -aG docker $USER && newgrp docker

# Collection not found during test
# Ensure you've built and installed the collection first
ansible-galaxy collection build
ansible-galaxy collection install *.tar.gz --force
```

**Important Note - Molecule 6.0+ Changes:**

- Molecule 6.0+ uses the `default` driver name (not `delegated`) for non-managed infrastructure testing
- The `docker` driver requires separate installation via `molecule-plugins[docker]`
- Scenarios using real infrastructure (K3s Pi nodes, Proxmox) use `driver: name: default`
- Docker-based scenarios use `driver: name: docker` with the molecule-plugins package
- The proxmox_lxc collection has simplified molecule tests for faster CI execution
- Complex integration tests (service-stack, full-stack) have been removed in favor of focused unit tests

## Architecture and Structure

### Network Layout

- **Raspberry Pi K3s cluster**: 192.168.0.111-114
  - k3-01: 192.168.0.111 (server node)
  - k3-02, k3-03, k3-04: 192.168.0.112-114 (agent nodes)
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

#### Security Research & Pentesting (Secure Enclave)

- **Enclave Bastion** (192.168.0.250) - Isolated jump host for pentesting environment access
- **Enclave Router** (192.168.0.251) - Network isolation and firewall for enclave
- **Kali Attacker VM** (10.10.0.10) - Pentesting workstation with security tools
- **DVWA** (10.10.0.100) - Damn Vulnerable Web Application for practice
- **Metasploitable3** (10.10.0.101) - Intentionally vulnerable VM for training
- **Isolated Network** (10.10.0.0/24) - Completely isolated from production with firewall rules
  - All traffic to production infrastructure BLOCKED
  - Internet access allowed for updates/tools
  - Auto-shutdown after 4h idle for safety
  - Comprehensive audit logging

### Directory Structure

```text
/
├── site.yml                         # Legacy main orchestration (backwards compatibility)
├── requirements.yml                 # Consolidated collection and dependency requirements
├── security-deploy.yml              # Legacy security deployment (use infrastructure.yml instead)
├── phase2-security.yml              # Legacy phase 2 deployment (use infrastructure.yml instead)
├── test-security-hardening.yml      # Security validation playbook
├── playbooks/                       # Recommended orchestration structure
│   ├── infrastructure.yml           # Main phased deployment orchestrator
│   ├── foundation.yml               # Phase 1: Bastion and Proxmox setup
│   ├── provision-containers.yml     # LXC container provisioning
│   ├── networking.yml               # Phase 2: DNS, VPN, reverse proxy
│   ├── monitoring.yml               # Phase 3: Prometheus, Grafana, Loki
│   ├── applications.yml             # Phase 4: Home automation, NAS services
│   ├── enclave.yml                  # Phase 6: Secure enclave (persistent/temporary modes)
│   ├── secure-enclave.yml           # Legacy secure enclave deployment
│   ├── update-systems.yml           # Rolling system updates (Pi + LXC)
│   └── restart-k3s-pods.yml         # K3s deployment rolling restarts
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
    │   ├── molecule/                # Molecule test scenarios
    │   │   ├── default/             # Default test scenario
    │   │   └── common-roles/        # Common roles test scenario
    │   └── roles/                   # Shared roles (common_setup, container_base,
    │                                # security_hardening)
    ├── k3s/                         # K3s cluster management
    │   ├── playbooks/site.yml       # K3s deployment
    │   ├── inventory/hosts.yml      # Raspberry Pi inventory
    │   ├── molecule/                # Molecule test scenarios
    │   │   └── raspberry-pi/        # Real hardware test scenario
    │   └── roles/                   # K3s-specific roles (k3s_server, k3s_agent,
    │                                # airgap)
    └── proxmox_lxc/                 # LXC services management
        ├── site.yml                 # LXC services orchestration
        ├── inventory/               # Dynamic and static inventory
        │   ├── proxmox.yml          # Dynamic Proxmox inventory
        │   └── hosts.yml.static-backup  # Backup of static inventory
        ├── molecule/                # Molecule test scenarios
        │   ├── default/             # Default test scenario
        │   └── proxmox-integration/ # Proxmox integration test scenario
        └── roles/                   # Service roles (traefik, prometheus,
                                     # grafana, etc.)
```

## Key Integration Points

### K3s Cluster Integration

- Traefik acts as unified ingress controller for both LXC services and K3s workloads
- Service account and RBAC configured for Kubernetes API access
- Certificate authority and token management for secure K3s communication

### Configuration Management

- Global variables in `inventory/group_vars/all/` define network topology and service settings
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

**Security-First Approach** (via `playbooks/infrastructure.yml`):

1. **Phase 1 (foundation)**: Provision LXC containers, deploy bastion hosts, configure Proxmox
2. **Phase 2 (networking)**: Deploy DNS (Unbound/AdGuard), VPN (WireGuard), reverse proxy (Traefik)
3. **Phase 3 (monitoring)**: Deploy Prometheus, Grafana, Loki, AlertManager
4. **Phase 4 (applications)**: Deploy Home Assistant, NAS/media services
5. **Phase 5 (k3s)**: Deploy K3s cluster (requires phases 1-2)
6. **Phase 6 (enclave)**: Deploy secure enclave (opt-in, requires explicit acknowledgement)

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
- **Molecule testing** - Collection-level testing with Molecule 6.0+
  - Python 3.12, Ansible 2.17+
  - Docker-based unit tests and real infrastructure validation
  - **Smoke test scenario** (`molecule/smoke/`) - Fast validation of ALL roles across all collections (< 5 min)
  - Multiple scenarios per collection (default, integration, service-stack)
  - Makefile targets for convenient execution (`make test-molecule-smoke`)
  - Automated CI/CD integration via GitHub Actions
- **CI/CD integration** - Automated linting, Molecule smoke tests, and validation via GitHub Actions

**Documentation Coverage**:

- **Repository README** with comprehensive overview and quick start
- **Collection READMEs** with detailed feature descriptions
- **Role documentation** for major components (Traefik, Security Hardening, etc.)
- **API documentation** via galaxy.yml metadata
- **Security architecture** documentation with threat model
- **Testing procedures** (TESTING.md) with practical validation approaches
- **Troubleshooting guides** with common issues and solutions
