# Molecule Testing Guide for Homelab Collections

This guide covers comprehensive testing of your homelab infrastructure using Molecule across both collections.

## Overview

The testing setup includes:
- **Docker-based testing**: Fast feedback for role logic and basic functionality
- **Real infrastructure testing**: Validation on actual Proxmox LXC containers and Raspberry Pi nodes
- **Service integration testing**: Multi-service stack validation

## Prerequisites

### Required Software
```bash
# Install Molecule and dependencies
pip install molecule molecule-plugins[docker] molecule-plugins[vagrant]
pip install docker ansible-lint yamllint

# Install required collections
ansible-galaxy collection install community.general community.docker ansible.posix
```

### Environment Variables
For real infrastructure testing, set these environment variables:
```bash
export PROXMOX_PASSWORD="your-proxmox-password"
export CONTAINER_PASSWORD="your-container-root-password"
export SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"
```

## Testing Collections

### 1. Proxmox LXC Collection Testing

#### Quick Docker Testing (Recommended for Development)
```bash
cd ansible_collections/homelab/proxmox_lxc/
molecule test  # Runs default Docker scenario
```

#### Real LXC Container Testing
```bash
# Test on actual Proxmox infrastructure
molecule test -s proxmox-integration
```

#### Service Stack Integration Testing
```bash
# Test monitoring + networking stack integration
molecule test -s service-stack
```

### 2. K3s Collection Testing

#### Raspberry Pi Cluster Testing
```bash
cd ansible_collections/homelab/k3s/
molecule test -s raspberry-pi
```

## Testing Scenarios Explained

### Docker Scenarios (`default`)
**Purpose**: Fast feedback during development
- Tests role logic and templating
- Validates service startup and basic functionality
- No external dependencies required
- Runs in isolated containers

**What it tests**:
- ✅ Role syntax and logic
- ✅ Service installation and startup
- ✅ Configuration templating
- ✅ Basic health checks

**What it doesn't test**:
- ❌ Real network connectivity
- ❌ Hardware-specific issues
- ❌ Cross-service integration on real infrastructure

### Real Infrastructure Scenarios

#### Proxmox Integration (`proxmox-integration`)
**Purpose**: Validate on actual LXC containers
- Creates real containers on your Proxmox host (pve-mac)
- Tests actual service deployment
- Validates networking and connectivity
- Cleans up automatically

**What it tests**:
- ✅ LXC container lifecycle
- ✅ Service deployment on real containers
- ✅ Network connectivity within your homelab
- ✅ Resource usage and performance
- ✅ Integration with existing infrastructure

#### Raspberry Pi Testing (`raspberry-pi`)
**Purpose**: K3s cluster validation on actual hardware
- Uses your real Pi nodes (k3s-1, k3s-4)
- Tests cluster formation and functionality
- Validates hardware-specific configurations

**What it tests**:
- ✅ K3s cluster bootstrapping
- ✅ Node joining and cluster formation
- ✅ Hardware compatibility (ARM64)
- ✅ Network policies and connectivity
- ✅ Workload scheduling and execution

#### Service Stack Integration (`service-stack`)
**Purpose**: Multi-service integration validation
- Tests monitoring stack (Prometheus + Grafana + Loki)
- Tests networking stack (Traefik + DNS)
- Validates cross-service communication

## Test Commands Reference

### Collection-Level Testing
```bash
# Test all scenarios for a collection
molecule test --all

# Test specific scenario
molecule test -s scenario-name

# Run only converge (skip destroy)
molecule converge -s scenario-name

# Run only verify tests
molecule verify -s scenario-name

# Clean up without destroying
molecule cleanup -s scenario-name
```

### Role-Level Testing
```bash
# Test individual role (if molecule config exists)
cd roles/prometheus/
molecule test
```

### Debugging Tests
```bash
# Create and converge but don't destroy (for debugging)
molecule create -s scenario-name
molecule converge -s scenario-name
# Debug your issues...
molecule destroy -s scenario-name

# Login to test instance
molecule login -s scenario-name -h instance-name
```

## Test Matrix Coverage

### Proxmox LXC Services
| Service | Docker Test | LXC Test | Integration Test |
|---------|-------------|----------|------------------|
| Prometheus | ✅ | ✅ | ✅ |
| Grafana | ✅ | ✅ | ✅ |
| Loki | ✅ | ✅ | ✅ |
| Promtail | ✅ | ✅ | ✅ |
| Traefik | ✅ | ✅ | ✅ |
| Unbound | ✅ | ✅ | ✅ |
| OpenWrt | ✅ | ⚠️ | ⚠️ |

Legend: ✅ Implemented, ⚠️ Requires manual setup, ❌ Not implemented

### K3s Components
| Component | Docker Test | Pi Test |
|-----------|-------------|---------|
| Prerequisites | ✅ | ✅ |
| K3s Server | ⚠️ | ✅ |
| K3s Agent | ⚠️ | ✅ |
| Security Hardening | ✅ | ✅ |
| Cluster Integration | ❌ | ✅ |

## Troubleshooting

### Common Issues

#### Docker Permission Errors
```bash
sudo usermod -aG docker $USER
newgrp docker
```

#### Proxmox API Connection Issues
- Verify `PROXMOX_PASSWORD` environment variable
- Check network connectivity to Proxmox host
- Ensure API user has necessary permissions

#### Raspberry Pi SSH Issues
- Verify SSH key authentication is set up
- Check that Pi nodes are accessible from bastion host
- Ensure sufficient resources (memory/disk) on Pi nodes

#### Container IP Conflicts
- Default test container uses IP 192.168.0.250
- Ensure this IP is not in use in your network
- Modify IPs in molecule.yml if needed

### Test Logs and Debugging
```bash
# Increase verbosity
molecule test -s scenario-name -vvv

# Check Docker container logs
docker logs molecule-instance-name

# Check systemd service logs in test containers
molecule login -s scenario-name
journalctl -u service-name -f
```

## Best Practices

### Development Workflow
1. **Start with Docker tests** - Fast feedback loop
2. **Fix issues quickly** - No infrastructure cleanup required
3. **Test on real infrastructure** - Validate actual deployment
4. **Run integration tests** - Ensure services work together

### Test Maintenance
- Update test data retention periods to keep tests fast
- Clean up test resources promptly
- Monitor resource usage during real infrastructure tests
- Keep test scenarios focused and atomic

### Safety Guidelines
- **Never run destructive tests on production infrastructure**
- **Use dedicated test IP ranges** (192.168.0.250+)
- **Always verify cleanup** after real infrastructure tests
- **Monitor resource usage** during tests

## Next Steps

1. **Add more role-specific tests** as you develop new services
2. **Extend integration scenarios** for complex service interactions  
3. **Consider performance testing** for high-load scenarios
4. **Add security testing** with tools like Ansible Vault validation

The testing framework is extensible - add new scenarios as your infrastructure grows!