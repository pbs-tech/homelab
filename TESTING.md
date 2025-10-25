# Homelab Testing Strategy

This document outlines the practical testing approach for the homelab infrastructure, focused on fast validation and continuous integration.

## Testing Philosophy

The testing strategy prioritizes speed and practicality:

1. **Fast Smoke Tests** - 30-second validation of critical components
2. **Infrastructure Validation** - Health checks for all deployed services
3. **Security Validation** - Security hardening verification
4. **Service Validation** - Functional testing of all services
5. **Molecule Testing** - Collection-level automated testing

All tests complete in under 5 minutes total, making them practical for frequent validation.

## Test Suite Overview

### Quick Smoke Test (`tests/quick-smoke-test.yml`)

**Runtime:** < 2 minutes
**Purpose:** Fast validation of critical infrastructure

**What it checks:**
- Ansible syntax validation
- K3s cluster node connectivity
- Proxmox host connectivity
- Critical service health (Traefik, Prometheus, K3s API)

**Usage:**

```bash
make test-quick
# OR
ansible-playbook tests/quick-smoke-test.yml
```

### Infrastructure Validation (`tests/validate-infrastructure.yml`)

**Runtime:** < 3 minutes
**Purpose:** Verify all infrastructure components are deployed and running

**What it checks:**
- LXC container status on pve-mac (11 containers)
- LXC container status on pve-nas (7 containers)
- Service port availability
- K3s cluster node status
- K3s service health
- K3s pod count and status

**Usage:**

```bash
make test-infrastructure
# OR
ansible-playbook tests/validate-infrastructure.yml
```

### Security Validation (`tests/validate-security.yml`)

**Runtime:** < 3 minutes
**Purpose:** Validate security hardening across all infrastructure

**What it checks:**
- UFW firewall status on all nodes
- SSH hardening (PasswordAuthentication, PermitRootLogin)
- fail2ban service and SSH jail status
- Unattended-upgrades configuration
- Bastion host security configurations
- SSL certificate accessibility

**Usage:**

```bash
make test-security
# OR
ansible-playbook tests/validate-security.yml
```

### Service Validation (`tests/validate-services.yml`)

**Runtime:** < 4 minutes
**Purpose:** Validate all services are functioning correctly

**What it checks:**
- **Monitoring Stack**: Prometheus metrics, Grafana health, Loki readiness, AlertManager
- **Networking**: Traefik dashboard/API, DNS resolution (Unbound/AdGuard)
- **Media Services**: Sonarr, Radarr, Jellyfin, qBittorrent
- **Home Automation**: Home Assistant API
- **K3s Services**: Pod status, service count

**Usage:**

```bash
make test-services
# OR
ansible-playbook tests/validate-services.yml
```

## Running Tests

### Using Makefile (Recommended)

```bash
# Quick validation (30 seconds)
make test-quick

# Full validation suite (< 5 minutes)
make test

# Individual test categories
make test-infrastructure
make test-security
make test-services

# Specific validations
make test-api                 # Proxmox API authentication

# Molecule tests (collection-level automated testing)
make test-molecule-all        # Run all Molecule scenarios
make test-molecule-common     # Test common collection
make test-molecule-k3s        # Test K3s collection
make test-molecule-proxmox    # Test Proxmox LXC collection
```

### Direct Ansible Commands

```bash
# Run all tests
ansible-playbook tests/quick-smoke-test.yml
ansible-playbook tests/validate-infrastructure.yml
ansible-playbook tests/validate-security.yml
ansible-playbook tests/validate-services.yml

# With verbose output
ansible-playbook tests/validate-services.yml -vv
```

## Molecule Testing

The project uses Molecule 6.0+ for collection-level testing and validation. Molecule provides automated testing with multiple scenarios per collection.

### Quick Start

**Using Makefile (Recommended):**

```bash
# Run all molecule tests (recommended before commits)
make test-molecule-all

# Test individual collections
make test-molecule-common        # Test common collection
make test-molecule-k3s          # Test K3s collection
make test-molecule-proxmox      # Test Proxmox LXC collection

# Test specific scenarios
make test-molecule-common-roles      # Common roles scenario
make test-molecule-k3s-pi           # K3s on Raspberry Pi
make test-molecule-proxmox-integration  # Proxmox integration
```

**Direct Molecule Commands:**

```bash
# Install Molecule and dependencies
pip install "molecule>=6.0" "molecule-plugins[docker]>=23.5.0"
pip install "ansible-core>=2.17" "yamllint>=1.35" "ansible-lint>=24.0"

# Test individual collections with default scenario
cd ansible_collections/homelab/common && molecule test
cd ansible_collections/homelab/k3s && molecule test
cd ansible_collections/homelab/proxmox_lxc && molecule test

# Test specific scenarios
cd ansible_collections/homelab/common && molecule test -s common-roles
cd ansible_collections/homelab/k3s && molecule test -s raspberry-pi
cd ansible_collections/homelab/proxmox_lxc && molecule test -s proxmox-integration
```

### Molecule Test Scenarios

**Common Collection (`homelab.common`):**
- `default` - Tests common roles and setup (Docker driver)
- `common-roles` - Tests container base and security hardening roles (Docker driver)

**K3s Collection (`homelab.k3s`):**
- `default` - Basic K3s role validation (Docker driver)
- `raspberry-pi` - Tests K3s deployment on real Raspberry Pi hardware (default driver)

**Proxmox LXC Collection (`homelab.proxmox_lxc`):**
- `default` - Docker-based unit tests for LXC roles (Docker driver)
- `proxmox-integration` - Real Proxmox infrastructure testing (default driver)

### Development Workflow with Molecule

**Iterative Testing (Fast Development Cycle):**

```bash
# Navigate to collection directory
cd ansible_collections/homelab/common

# Create test environment (once)
molecule create

# Run playbook (repeatable without destroying environment)
molecule converge

# Run verification tests
molecule verify

# Destroy test environment when done
molecule destroy
```

**Makefile Helpers for Development:**

```bash
# Run converge on all collections (no destroy)
make molecule-converge

# Run converge on specific collection
make molecule-converge-common
make molecule-converge-k3s
make molecule-converge-proxmox

# Run verify on all collections
make molecule-verify

# Destroy all test instances
make molecule-destroy

# Reset all instances (destroy + create fresh)
make molecule-reset
```

### Debugging Molecule Tests

```bash
# Run with debug output
cd ansible_collections/homelab/common
molecule --debug test

# Keep environment after failure (for inspection)
molecule converge  # Re-run without destroying

# Login to test container/instance
molecule login

# List all scenarios and their status
molecule list
```

### Molecule 6.0+ Driver Notes

**Important Changes in Molecule 6.0+:**

- **Default Driver**: Scenarios testing real infrastructure (Raspberry Pi nodes, Proxmox LXC) use `driver: name: default` (formerly `delegated`)
- **Docker Driver**: Requires separate installation via `molecule-plugins[docker]` package
- **Driver Compatibility**: The `delegated` driver name is no longer recognized; use `default` instead

**Driver Selection:**

- `docker` - For fast unit tests in containers (requires Docker daemon)
- `default` - For testing on pre-existing infrastructure (SSH-based)

**Local Testing Requirements:**

- Docker daemon running for Docker-based scenarios
- SSH access to target nodes for default driver scenarios
- Proper authentication configured (SSH keys, API tokens)

### Molecule CI/CD Integration

Molecule tests are automatically executed in the GitHub Actions CI pipeline (`.github/workflows/ci.yml`):

**CI Configuration:**
- **Trigger:** Pull requests, pushes to main, manual workflow dispatch
- **Strategy:** Matrix testing across collections in parallel
- **Duration:** 3-5 minutes per collection
- **Environment:** Python 3.12, Ansible 2.17+, Docker

**Test Matrix:**
- `common` collection with `default` scenario
- `proxmox_lxc` collection with `default` scenario
- K3s collection tested separately (requires real hardware)

**CI Workflow highlights:**
- Runs after successful linting checks
- Tests each collection independently with dependency resolution
- Uses Docker driver for fast, isolated testing
- Automatically installs collection dependencies
- Caches Ansible collections for faster execution

**View CI Results:**

```bash
# Check CI status from command line
make ci-status

# View detailed logs
# Navigate to: GitHub > Actions > CI workflow > Latest run
```

## CI/CD Integration

The GitHub Actions workflow (`.github/workflows/ci.yml`) provides automated validation:

**Workflow Jobs:**
- **lint** - YAML, Ansible, and Markdown linting
- **collections** - Galaxy collection build and validation
- **molecule** - Collection-level automated testing
- **secrets-scan** - TruffleHog secret detection (PRs only)

**Environment:**
- Python 3.12
- Ansible 2.17+
- yamllint 1.35+
- ansible-lint 24.0+
- Molecule 6.0+

**Trigger Conditions:**
- Push to main branch
- Pull requests to main or develop
- Manual workflow dispatch

**Optimization:**
- Dependency caching (pip, Ansible collections)
- Parallel job execution
- Fast failure for critical issues
- Matrix testing for collections

## Development Workflow

### Local Development Cycle

1. **Make changes** to roles, playbooks, or configuration

2. **Run linting** before testing:

   ```bash
   make lint
   # OR specific linters
   make lint-yaml
   make lint-ansible
   make lint-markdown
   ```

3. **Run quick smoke test** for rapid feedback:

   ```bash
   make test-quick
   ```

4. **Run molecule tests** for changed collections:

   ```bash
   # If you modified common collection
   make test-molecule-common

   # Or test all collections
   make test-molecule-all
   ```

5. **Run full validation** before committing:

   ```bash
   make test
   ```

6. **Commit changes** once all tests pass

### Pre-Commit Testing Checklist

```bash
# 1. Lint all code
make lint

# 2. Run Molecule tests for affected collections
make test-molecule-all

# 3. Run infrastructure validation
make test-infrastructure

# 4. Run security validation
make test-security

# 5. Run service validation
make test-services
```

### Pre-Production Validation

1. **Lint all code**:

   ```bash
   make lint
   ```

2. **Run infrastructure validation**:

   ```bash
   make test-infrastructure
   ```

3. **Run security validation**:

   ```bash
   make test-security
   ```

4. **Run service validation**:

   ```bash
   make test-services
   ```

5. **Deploy with confidence**:

   ```bash
   make deploy
   ```

## Test Configuration

### Inventory Requirements

Tests use the standard homelab inventory:
- `ansible_collections/homelab/common/inventory/hosts.yml` - Main inventory
- `ansible_collections/homelab/k3s/inventory/hosts.yml` - K3s cluster
- `ansible_collections/homelab/proxmox_lxc/inventory/proxmox.yml` - Dynamic Proxmox inventory

### Environment Setup

#### For Local Testing

```bash
# Install all dependencies
make install

# Install development dependencies (includes Molecule)
make install-dev

# Configure vault password (if needed)
echo "your_vault_password" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass
```

#### For Proxmox API Tests

```bash
# Test Proxmox API authentication
make test-api
# OR
ansible-playbook tests/test-proxmox-api-tokens.yml
```

#### For Molecule Testing

```bash
# Install Molecule and dependencies (included in make install-dev)
pip install "molecule>=6.0" "molecule-plugins[docker]>=23.5.0"

# Ensure Docker is running (for Docker-based scenarios)
docker ps

# Verify installation
molecule --version
```

## Understanding Test Results

### Successful Test Output

```text
TASK [Display validation summary] ********************************
ok: [localhost] => {
    "msg": "
        ====================================
        Service Validation Complete
        ====================================

        All services validated successfully
        Status: HEALTHY
    "
}
```

### Failed Test Output

Tests use `ignore_errors: true` for most checks to gather complete status information. Review the output for:

- **FAIL** indicators in status displays
- **DEGRADED** service states
- Assertion failures with specific error messages
- Connection timeout errors

### Reading Status Reports

Each test generates a comprehensive status report:

```text
Monitoring Stack Status:
- Prometheus: HEALTHY
- Grafana: HEALTHY
- Loki: HEALTHY
- AlertManager: HEALTHY
```

### Molecule Test Output

Molecule provides detailed test execution output:

```text
PLAY RECAP *********************************************************************
instance                   : ok=10   changed=5    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0

INFO     Running default > verify
INFO     Running Ansible Verifier

PLAY [Verify] ******************************************************************

TASK [Verify role deployment] **************************************************
ok: [instance]

PLAY RECAP *********************************************************************
instance                   : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

INFO     Verifier completed successfully.
```

## Troubleshooting

### Common Issues

#### Connectivity Issues

```bash
# Test basic connectivity
ansible all -m ping

# Test specific host group
ansible k3s_cluster -m ping
ansible proxmox_hosts -m ping
```

#### Service Not Responding

```bash
# Check service status directly
ssh user@192.168.0.200 'systemctl status prometheus'

# Test service port
telnet 192.168.0.200 9090
```

#### Proxmox API Issues

```bash
# Validate API tokens
make test-api

# Test API manually
curl -k -H "Authorization: PVEAPIToken=USER@REALM!TOKENID=SECRET" \
  https://proxmox-host:8006/api2/json/version
```

#### Molecule Docker Issues

```bash
# Check Docker daemon is running
docker ps

# Pull required images manually
docker pull geerlingguy/docker-ubuntu2204-ansible

# Clean up stale containers
docker system prune -f

# Ensure user is in docker group
sudo usermod -aG docker $USER
newgrp docker
```

#### Molecule Test Failures

```bash
# Destroy and retry
cd ansible_collections/homelab/common
molecule destroy
molecule test

# Run with debug output
molecule --debug test

# Keep environment after failure
molecule converge
molecule login  # Inspect the test instance
```

### Debug Mode

```bash
# Run tests with verbose output
ansible-playbook tests/validate-services.yml -vvv

# Run with debug output
ansible-playbook tests/validate-services.yml -vvv --step

# Run specific plays
ansible-playbook tests/validate-services.yml --tags monitoring
```

### Test-Specific Issues

#### Infrastructure Validation Failures

```bash
# Check LXC container status
pvesh get /nodes/pve-mac/lxc

# Check service ports
nmap 192.168.0.200-210
```

#### Security Validation Failures

```bash
# Check UFW status
ansible k3s_cluster -b -m command -a "ufw status verbose"

# Check fail2ban jails
ansible k3s_cluster -b -m command -a "fail2ban-client status"
```

#### Service Validation Failures

```bash
# Check service logs
ssh user@192.168.0.200 'journalctl -u prometheus -n 50'

# Check service health endpoints
curl http://192.168.0.200:9090/-/healthy
```

## Performance Expectations

| Test Suite | Expected Runtime | Components Checked |
|------------|------------------|-------------------|
| Quick Smoke Test | < 2 min | Syntax, connectivity, critical services |
| Infrastructure | < 3 min | 18 containers, 4 K3s nodes, service ports |
| Security | < 3 min | Firewall, SSH, fail2ban, SSL certificates |
| Services | < 4 min | 15+ services, APIs, K3s workloads |
| Molecule (per collection) | 3-5 min | Role validation, integration tests |
| **Total** | **< 15 min** | **Full infrastructure + collection validation** |

## Best Practices

### Test Development

- **Keep tests fast** - Use health endpoints over full functional tests
- **Test real infrastructure** - No mocks, validate actual deployments
- **Ignore non-critical errors** - Gather complete status before failing
- **Provide clear output** - Status summaries for quick assessment

### Molecule Testing

- **Use Docker for unit tests** - Fast, isolated, repeatable
- **Use default driver for integration** - Test on real infrastructure
- **Iterative development** - Use `converge` for rapid testing
- **Keep scenarios focused** - Unit tests in default, integration in named scenarios
- **Test dependencies** - Ensure collection dependencies are installed

### Test Maintenance

- **Update tests with infrastructure changes** - Keep service lists current
- **Document expected results** - Clear success/failure criteria
- **Version control test data** - Track inventory and configuration
- **Review test output regularly** - Identify patterns and improvements

### CI/CD Best Practices

- **Run linting before tests** - Catch syntax issues early
- **Use caching** - Speed up workflow execution with dependency caching
- **Matrix testing** - Test collections in parallel
- **Fail fast on critical issues** - Don't waste resources
- **Test locally first** - Run `make test-molecule-all` before pushing

## Continuous Improvement

### Monitoring Test Results

- Track test execution times
- Identify flaky tests
- Monitor failure patterns
- Update test coverage as infrastructure grows

### Future Enhancements

Potential improvements (implement as needed):

- Backup/restore validation tests
- Disaster recovery scenario tests
- Load testing for critical services
- Certificate expiration monitoring
- Resource utilization validation
- Extended Molecule scenarios (full-stack integration)
- Performance benchmarking tests

## Contributing

When adding new services or infrastructure:

1. **Update relevant test files** with new services
2. **Add health check endpoints** to service definitions
3. **Add Molecule scenarios** for new roles/collections
4. **Document expected test behavior** in comments
5. **Verify tests run successfully** before committing
6. **Update this documentation** with significant changes

## Reference

### Test File Locations

```text
tests/
├── quick-smoke-test.yml          # Fast validation (< 2 min)
├── validate-infrastructure.yml   # Infrastructure health (< 3 min)
├── validate-security.yml         # Security validation (< 3 min)
└── validate-services.yml         # Service functionality (< 4 min)

ansible_collections/homelab/*/molecule/
├── common/
│   ├── default/                  # Common roles unit tests
│   └── common-roles/             # Security and container tests
├── k3s/
│   ├── default/                  # K3s role validation
│   └── raspberry-pi/             # Real hardware tests
└── proxmox_lxc/
    ├── default/                  # LXC roles unit tests
    └── proxmox-integration/      # Real Proxmox tests
```

### Makefile Test Targets

```bash
# Infrastructure validation
make test                    # Full test suite
make test-quick             # Quick smoke tests
make test-infrastructure    # Infrastructure health
make test-security          # Security validation
make test-services          # Service functionality
make test-api              # Proxmox API tests

# Molecule testing
make test-molecule-all              # All Molecule scenarios
make test-molecule-common           # Common collection
make test-molecule-k3s             # K3s collection
make test-molecule-proxmox         # Proxmox LXC collection
make molecule-converge             # Converge all collections
make molecule-verify               # Verify all collections
make molecule-destroy              # Destroy all instances
make molecule-reset                # Reset all instances
```

### Related Documentation

- **README.md** - Project overview and quick start
- **CLAUDE.md** - Development guidelines and complete command reference
- **.github/workflows/ci.yml** - CI/CD pipeline configuration
- **Makefile** - Development and testing commands
- **ansible_collections/homelab/*/molecule/** - Molecule test scenarios
