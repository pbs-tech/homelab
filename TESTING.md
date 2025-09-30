# Homelab Testing Strategy

This document outlines the practical testing approach for the homelab infrastructure, focused on fast validation and continuous integration.

## Testing Philosophy

The testing strategy prioritizes speed and practicality:

1. **Fast Smoke Tests** - 30-second validation of critical components
2. **Infrastructure Validation** - Health checks for all deployed services
3. **Security Validation** - Security hardening verification
4. **Service Validation** - Functional testing of all services

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

## CI/CD Integration

The GitHub Actions workflow (`.github/workflows/ci.yml`) provides automated validation:

**Workflow Jobs:**
- **yamllint** - YAML syntax validation
- **ansible-lint** - Ansible best practices with security profile
- **markdownlint** - Documentation quality
- **secrets-scan** - TruffleHog secret detection
- **galaxy-validation** - Collection build and validation

**Trigger Conditions:**
- Push to main, develop, or update-actions branches
- Pull requests to main or develop
- Manual workflow dispatch

**Optimization:**
- Path filtering to skip unnecessary jobs
- Caching for Ansible collections and pip packages
- Parallel execution where possible
- Fast failure for critical issues

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

4. **Run full validation** before committing:
   ```bash
   make test
   ```

5. **Commit changes** once all tests pass

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

# Install development dependencies
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
ansible-playbook test-proxmox-api-tokens.yml
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
| **Total** | **< 5 min** | **Full infrastructure validation** |

## Best Practices

### Test Development

- **Keep tests fast** - Use health endpoints over full functional tests
- **Test real infrastructure** - No mocks, validate actual deployments
- **Ignore non-critical errors** - Gather complete status before failing
- **Provide clear output** - Status summaries for quick assessment

### Test Maintenance

- **Update tests with infrastructure changes** - Keep service lists current
- **Document expected results** - Clear success/failure criteria
- **Version control test data** - Track inventory and configuration
- **Review test output regularly** - Identify patterns and improvements

### CI/CD Best Practices

- **Run linting before tests** - Catch syntax issues early
- **Use path filtering** - Skip unnecessary job runs
- **Cache dependencies** - Speed up workflow execution
- **Fail fast on critical issues** - Don't waste resources

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

## Contributing

When adding new services or infrastructure:

1. **Update relevant test files** with new services
2. **Add health check endpoints** to service definitions
3. **Document expected test behavior** in comments
4. **Verify tests run successfully** before committing
5. **Update this documentation** with significant changes

## Reference

### Test File Locations

```text
tests/
├── quick-smoke-test.yml          # Fast validation (< 2 min)
├── validate-infrastructure.yml   # Infrastructure health (< 3 min)
├── validate-security.yml         # Security validation (< 3 min)
└── validate-services.yml         # Service functionality (< 4 min)
```

### Related Documentation

- **README.md** - Project overview and quick start
- **CLAUDE.md** - Development guidelines and commands
- **.github/workflows/ci.yml** - CI/CD pipeline configuration
- **Makefile** - Development and testing commands
