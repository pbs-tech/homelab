# Molecule Smoke Test

## Overview

The smoke test scenario provides fast, comprehensive validation of all roles across all three homelab collections:

- **homelab.common** - Shared utilities and security hardening
- **homelab.k3s** - Kubernetes cluster management
- **homelab.proxmox_lxc** - LXC container services

## Purpose

- **Fast validation** - Completes in under 5 minutes
- **Syntax checking** - Validates Ansible syntax and role structure
- **Variable validation** - Ensures configuration variables are properly defined
- **Basic functionality** - Tests core role functionality without full infrastructure
- **CI/CD friendly** - Designed for automated testing in CI pipelines

## What Gets Tested

### Common Collection Roles

- `common_setup` - System configuration and package installation
- `security_hardening` - Security hardening configuration
- `container_base` - Container resource management (syntax validation)
- `monitoring_agent` - Monitoring agent setup (if present)

### K3s Collection Roles

- `prereq` - K3s prerequisites and system preparation
- `security_hardening` - K3s-specific security configuration
- `raspberrypi` - Raspberry Pi specific configuration (syntax validation)
- `airgap` - Airgap installation support (syntax validation)
- `k3s_server` - Verified to exist (full deployment skipped)
- `k3s_agent` - Verified to exist (full deployment skipped)

### Proxmox LXC Collection Roles

- `bastion` - Bastion host configuration (syntax validation)
- `lxc_container` - Container management (syntax validation)
- Service roles verified:
  - `prometheus` - Metrics collection
  - `grafana` - Visualization
  - `traefik` - Reverse proxy
  - `loki` - Log aggregation
  - `alertmanager` - Alert management
  - `unbound` - DNS resolver
  - `adguard` - DNS filtering
  - `wireguard` - VPN server
  - `homeassistant` - Home automation

## Usage

### Quick Start

```bash
# Run complete smoke test
make test-molecule-smoke

# Or use molecule directly
molecule test -s smoke
```

### Development Workflow

```bash
# Create test instances
molecule create -s smoke

# Run playbook (repeatable)
molecule converge -s smoke

# Run verification tests
molecule verify -s smoke

# Destroy test instances
molecule destroy -s smoke
```

### Debugging

```bash
# Run with verbose output
molecule --debug converge -s smoke

# Login to test instance
molecule login -s smoke -h smoke-common   # Common collection tests
molecule login -s smoke -h smoke-k3s      # K3s collection tests
molecule login -s smoke -h smoke-proxmox  # Proxmox LXC collection tests
```

## Test Infrastructure

The smoke test uses Docker containers with these characteristics:

- **Image**: `geerlingguy/docker-ubuntu2204-ansible:latest`
- **Privileged mode**: Enabled for systemd support
- **Instance count**: 3 (one per collection)
- **Network**: Docker bridge network
- **Duration**: < 5 minutes total

### Test Instances

1. **smoke-common** - Tests common collection roles
   - Groups: `common_test`, `monitoring`
   - Primary focus: Shared utilities and security

2. **smoke-k3s** - Tests K3s collection roles
   - Groups: `k3s_test`, `k3s_server`
   - Primary focus: K3s prerequisites and configuration

3. **smoke-proxmox** - Tests Proxmox LXC collection roles
   - Groups: `proxmox_test`, `monitoring`, `networking`
   - Primary focus: Service role verification

## Limitations

The smoke test is designed for fast validation and has these limitations:

1. **No real infrastructure** - Proxmox API calls and K3s installations are skipped
2. **Syntax validation only** - Service deployments that require actual infrastructure are validated for syntax but not fully deployed
3. **Mock data** - Uses mock SSH keys, configurations, and directories
4. **Docker limitations** - Not all features work in Docker containers (e.g., actual K3s cluster)

## When to Use

### ✅ Use Smoke Test For

- Pre-commit validation
- CI/CD pipelines
- Quick syntax checking
- Role refactoring verification
- Documentation updates
- Variable changes

### ❌ Don't Use Smoke Test For

- Full integration testing (use collection-specific scenarios)
- Real infrastructure validation (use `raspberry-pi` or `proxmox-integration` scenarios)
- Performance testing
- Service-to-service communication testing

## CI/CD Integration

The smoke test is ideal for CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run Molecule smoke test
  run: make test-molecule-smoke
```

Benefits:
- Fast feedback (< 5 minutes)
- No infrastructure dependencies
- Docker-only requirements
- Comprehensive coverage

## Troubleshooting

### Common Issues

**Docker not available:**

```bash
# Ensure Docker is running
docker info

# Start Docker daemon
sudo systemctl start docker
```

**Collection not found:**

```bash
# Install collections
ansible-galaxy install -r requirements.yml
```

**Stale test instances:**

```bash
# Clean up and retry
make molecule-destroy
make test-molecule-smoke
```

**Syntax errors:**

```bash
# Run with verbose output to see details
molecule --debug converge -s smoke
```

## Related Documentation

- [Main README](../../README.md) - Project overview
- [CLAUDE.md](../../CLAUDE.md) - Development guidelines
- [TESTING.md](../../TESTING.md) - Comprehensive testing guide
- [Molecule documentation](https://molecule.readthedocs.io/) - Official Molecule docs

## Contributing

When adding new roles:

1. Add role inclusion to `converge.yml`
2. Add verification tasks to `verify.yml`
3. Update this README with role details
4. Test locally before committing
5. Ensure CI pipeline passes
