# K3s Collection - Molecule Test Strategy

This document outlines the comprehensive testing strategy for the `homelab.k3s` Ansible collection using Molecule 6.0+.

## Testing Philosophy

The K3s collection implements a **dual-scenario testing approach**:

1. **Default Scenario**: Fast, CI-compatible containerized tests
2. **Raspberry Pi Scenario**: Real hardware integration tests

This approach balances:

- **Speed**: Container tests complete in < 10 minutes
- **Confidence**: Real hardware tests validate production readiness
- **Cost**: Container tests run free in CI, hardware tests run on-demand
- **Coverage**: Both unit-style and integration-style testing

## Test Scenarios

### Default Scenario (CI-Compatible)

**Purpose**: Fast validation of K3s roles in containerized environment

**When to use**:

- Pull request validation
- Pre-commit testing
- Rapid development iteration
- CI/CD pipelines

**Coverage**:

- ✅ K3s server role installation
- ✅ K3s agent role installation
- ✅ Cluster formation (1 server + 2 agents)
- ✅ Basic kubectl functionality
- ✅ Service management (systemd)
- ✅ Node registration and readiness
- ✅ Test workload deployment

**Limitations**:

- ❌ Physical networking
- ❌ Real storage devices
- ❌ Traefik ingress integration
- ❌ Hardware-specific optimizations
- ❌ Performance characteristics

**Execution time**: ~8-10 minutes

### Raspberry Pi Scenario (Real Hardware)

**Purpose**: End-to-end validation on production hardware

**When to use**:

- Pre-release testing
- Hardware compatibility verification
- Performance testing
- Full stack validation

**Coverage**:

- ✅ All default scenario coverage
- ✅ Physical network configuration
- ✅ Raspberry Pi optimizations
- ✅ Real storage and I/O
- ✅ Security hardening integration
- ✅ Common collection integration
- ✅ Multi-node cluster networking
- ✅ Production-like environment

**Requirements**:

- 4x Raspberry Pi 4 nodes (192.168.0.111-114)
- Physical network connectivity
- SSH access configured

**Execution time**: ~15-30 minutes

## Test Matrix

| Test Type | Scenario | Environment | Frequency | Duration | CI |
|-----------|----------|-------------|-----------|----------|-----|
| Unit | default | Docker/Podman | Every commit | 8-10 min | ✅ |
| Integration | raspberry-pi | Real Hardware | Pre-release | 15-30 min | ❌ |

## Test Coverage Goals

### Role Coverage

- **prereq role**: ✅ Tested in both scenarios
  - System package installation
  - Network configuration (IPv4 forwarding)
  - Firewall rules (UFW, firewalld)
  - Kernel modules (br_netfilter)
  - AppArmor setup

- **k3s_server role**: ✅ Tested in both scenarios
  - K3s binary download and installation
  - Service configuration (single/HA modes)
  - Token management
  - API server startup
  - Kubeconfig generation
  - Kubectl setup

- **k3s_agent role**: ✅ Tested in both scenarios
  - K3s binary installation
  - Agent service configuration
  - Token-based cluster joining
  - Node registration

### Functional Coverage

| Functionality | Default | Raspberry Pi | Notes |
|--------------|---------|--------------|-------|
| Single server cluster | ✅ | ✅ | Basic deployment |
| Multi-server HA | ⚠️ | ✅ | Container limited |
| Agent nodes | ✅ | ✅ | Multiple agents |
| Network policies | ⚠️ | ✅ | Simplified in container |
| Storage classes | ❌ | ✅ | Requires real storage |
| Ingress (Traefik) | ❌ | ✅ | Advanced networking |
| Security hardening | ⚠️ | ✅ | Limited in container |
| Monitoring integration | ⚠️ | ✅ | External dependencies |

**Legend**: ✅ Full support | ⚠️ Partial support | ❌ Not supported

## Test Execution Strategy

### Development Workflow

```bash
# 1. Make changes to roles
vim roles/k3s_server/tasks/main.yml

# 2. Quick validation with linting
make lint-ansible

# 3. Fast container test (default scenario)
make test-molecule-k3s

# 4. Iterative debugging (if needed)
cd ansible_collections/homelab/k3s/
molecule converge -s default
molecule login -s default -h k3s-server-01
molecule verify -s default

# 5. Pre-commit: Real hardware test
make test-molecule-k3s-pi
```

### CI/CD Pipeline

```yaml
# GitHub Actions Workflow
jobs:
  molecule:
    strategy:
      matrix:
        include:
          - collection: k3s
            scenario: default  # Only default in CI
    steps:
      - name: Run Molecule tests
        run: molecule test -s default
```

**Rationale**: CI runs only container tests for speed and cost

### Pre-Release Validation

```bash
# Comprehensive test suite before release
make test-molecule-all

# This runs:
# 1. common collection - default scenario
# 2. common collection - common-roles scenario
# 3. k3s collection - default scenario
# 4. k3s collection - raspberry-pi scenario ← Real hardware
# 5. proxmox_lxc collection - default scenario
# 6. proxmox_lxc collection - proxmox-integration scenario
```

## Verification Strategy

### Multi-Level Verification

#### Level 1: Installation Verification

```yaml
- name: Check K3s binary exists
  stat:
    path: /usr/local/bin/k3s
  register: k3s_binary

- name: Assert K3s binary is executable
  assert:
    that:
      - k3s_binary.stat.exists
      - k3s_binary.stat.executable
```

#### Level 2: Service Verification

```yaml
- name: Check K3s service is running
  systemd:
    name: k3s
  register: k3s_service

- name: Assert service is active
  assert:
    that:
      - k3s_service.status.ActiveState == "active"
```

#### Level 3: Cluster Functionality

```yaml
- name: Get cluster nodes
  command: k3s kubectl get nodes -o json
  register: cluster_nodes

- name: Assert all nodes ready
  assert:
    that:
      - nodes_info.items | length >= 3
      - all nodes have Ready condition
```

#### Level 4: Workload Deployment

```yaml
- name: Deploy test pod
  command: k3s kubectl run test-pod --image=busybox

- name: Wait for pod running
  command: k3s kubectl wait --for=condition=Ready pod/test-pod

- name: Assert pod is running
  # Verify pod deployed successfully
```

### Idempotence Testing

Molecule automatically tests idempotence:

```bash
# First run makes changes
molecule converge -s default

# Second run should make no changes
molecule converge -s default
# Exit code 0 = idempotent
```

**Target**: Zero changes on second run

## Container vs Real Hardware Trade-offs

### Container Advantages

- ✅ **Speed**: 8-10 minutes vs 15-30 minutes
- ✅ **Cost**: Free CI execution
- ✅ **Repeatability**: Clean state every run
- ✅ **Parallelization**: Run multiple tests simultaneously
- ✅ **No dependencies**: No physical infrastructure needed

### Container Limitations

- ❌ **Kernel**: Shared host kernel, limited module loading
- ❌ **Networking**: Container networking != physical networking
- ❌ **Performance**: Not representative of production
- ❌ **Security**: Privileged containers required
- ❌ **Storage**: Emulated, not real block devices

### When to Use Each

| Use Case | Default | Raspberry Pi |
|----------|---------|--------------|
| Development iteration | ✅ | ❌ |
| Pull request validation | ✅ | ❌ |
| Pre-commit hook | ✅ | ❌ |
| CI/CD pipeline | ✅ | ❌ |
| Pre-release testing | ✅ | ✅ |
| Performance testing | ❌ | ✅ |
| Production validation | ❌ | ✅ |
| Hardware compatibility | ❌ | ✅ |

## Test Maintenance

### Regular Maintenance Tasks

**Weekly**:

- Run full test suite: `make test-molecule-all`
- Review test execution times
- Check for flaky tests

**Monthly**:

- Update K3s version in tests to match production
- Review container image versions
- Update dependencies (`requirements.yml`)

**Per Release**:

- Execute raspberry-pi scenario
- Validate all test assertions still relevant
- Update test documentation
- Review coverage gaps

### Handling Test Failures

#### Container Test Failures

```bash
# 1. Reproduce locally
cd ansible_collections/homelab/k3s/
molecule test -s default

# 2. Debug with converge
molecule converge -s default

# 3. Inspect container
molecule login -s default -h k3s-server-01
systemctl status k3s
journalctl -u k3s -n 100

# 4. Check logs
k3s kubectl logs -n kube-system --selector=k3s-app=k3s

# 5. Manual cleanup if stuck
molecule destroy -s default
docker ps -a | grep k3s | awk '{print $1}' | xargs docker rm -f
```

#### Real Hardware Test Failures

```bash
# 1. Check node connectivity
ansible raspberry_pi_test -m ping

# 2. Verify SSH access
ssh pbs@192.168.0.111

# 3. Check K3s status on nodes
ansible k3s_servers -m command -a "systemctl status k3s"

# 4. Review logs
ansible k3s_servers -m shell -a "journalctl -u k3s -n 100"

# 5. Reset if needed
cd ansible_collections/homelab/k3s/
molecule destroy -s raspberry-pi
```

## Future Enhancements

### Short-term (Next Release)

- [ ] Add network policy tests
- [ ] Test K3s upgrades
- [ ] Add multi-server HA testing in containers
- [ ] Implement test result reporting

### Medium-term (Next Quarter)

- [ ] Performance benchmarking tests
- [ ] Security scanning integration
- [ ] Chaos engineering tests
- [ ] Load testing scenarios

### Long-term (Next Year)

- [ ] Multi-architecture testing (ARM64, AMD64)
- [ ] Air-gapped deployment testing
- [ ] Disaster recovery scenarios
- [ ] Compliance validation

## Success Metrics

### Test Reliability

- **Target**: > 99% success rate
- **Current**: Track via CI/CD metrics
- **Action**: Investigate any test with > 1% failure rate

### Test Speed

- **Target**: Default scenario < 10 minutes
- **Current**: ~8-10 minutes
- **Action**: Optimize if exceeds 15 minutes

### Coverage

- **Target**: > 80% role coverage
- **Current**: ~85% (estimated)
- **Action**: Add tests for uncovered edge cases

### Maintenance Cost

- **Target**: < 2 hours/month
- **Current**: ~1 hour/month
- **Action**: Automate more maintenance tasks

## Related Documentation

- [Default Scenario README](default/README.md) - Container test details
- [Raspberry Pi Scenario](raspberry-pi/) - Real hardware test details
- [K3s Collection README](../README.md) - Collection overview
- [CLAUDE.md](../../../CLAUDE.md) - Project-wide testing strategy

## Contact and Support

For test-related questions:

1. Check this documentation
2. Review test logs and error messages
3. Inspect molecule configuration files
4. Consult K3s and Molecule documentation
5. Open an issue in the repository

---

**Last Updated**: 2025-10-11
**Molecule Version**: 6.0+
**Maintainer**: Homelab Team
