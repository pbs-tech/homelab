# K3s Collection - Default Molecule Scenario

This is the default Molecule test scenario for the `homelab.k3s` collection, designed to run in CI/CD environments with Docker or Podman.

## Overview

The default scenario validates K3s cluster deployment in a containerized environment, testing both server and agent roles without requiring physical hardware.

## Test Architecture

### Platforms

- **k3s-server-01**: Single K3s server (control plane) node
- **k3s-agent-01**: First K3s agent (worker) node
- **k3s-agent-02**: Second K3s agent (worker) node

All nodes use Ubuntu 22.04 with systemd support via the `geerlingguy/docker-ubuntu2204-ansible` image.

### Container Configuration

Each container is configured with:

- **Privileged mode**: Required for K3s to manage containers and networking
- **Capabilities**: `SYS_ADMIN`, `NET_ADMIN`, `SYS_MODULE` for K3s operations
- **Volume mounts**:
  - `/sys/fs/cgroup:/sys/fs/cgroup:rw` - For systemd cgroup management
  - `/lib/modules:/lib/modules:ro` - For kernel module access
- **tmpfs mounts**: `/run`, `/tmp` for temporary files
- **No cgroupns_mode**: Removed for podman compatibility

### K3s Configuration

The test cluster uses:

- **Version**: v1.28.5+k3s1 (stable release)
- **Network**: Flannel with host-gw backend
- **Cluster CIDR**: 10.42.0.0/16
- **Service CIDR**: 10.43.0.0/16
- **Disabled components**: Traefik, ServiceLB, local-storage (not needed for testing)

## Test Sequence

### 1. Prepare Phase (`prepare.yml`)

Sets up the test environment:

- Install required system packages (curl, wget, iptables, etc.)
- Enable IPv4 forwarding for K3s networking
- Load `br_netfilter` kernel module
- Create K3s directories (`/etc/rancher/k3s`, `/var/lib/rancher/k3s`)
- Create systemd service environment files

### 2. Converge Phase (`converge.yml`)

Deploys K3s cluster:

1. **Prerequisites**: Apply `prereq` role to all nodes
2. **Server Installation**: Apply `k3s_server` role to server node
3. **Server Readiness**: Wait for K3s API server (port 6443) and token generation
4. **Agent Installation**: Apply `k3s_agent` role to agent nodes
5. **Cluster Formation**: Verify all nodes register with the cluster

### 3. Verify Phase (`verify.yml`)

Validates K3s installation and functionality:

#### Server Verification

- K3s binary exists and is executable
- K3s systemd service is loaded and active
- K3s API server responds to kubectl commands
- Kubernetes control plane is accessible
- Kubeconfig file exists at `/etc/rancher/k3s/k3s.yaml`

#### Agent Verification

- K3s binary installed on agents
- K3s agent service is loaded and active
- Agents are running and connected

#### Cluster Verification

- All expected nodes are registered
- Nodes are in Ready state
- System pods are running
- kube-system namespace exists
- Test workload can be deployed and scheduled

### 4. Cleanup Phase (`cleanup.yml`)

Ensures clean teardown:

- Stop K3s services (server and agent)
- Remove systemd service files
- Kill K3s processes
- Unmount K3s filesystems
- Remove K3s binaries and directories
- Clean up CNI configuration

## Running the Tests

### Quick Test (Recommended for Development)

```bash
# From the k3s collection directory
cd ansible_collections/homelab/k3s/
molecule test -s default
```

### Iterative Development Workflow

```bash
# Create test environment
molecule create -s default

# Apply changes (repeatable)
molecule converge -s default

# Run verification
molecule verify -s default

# Debug issues
molecule login -s default -h k3s-server-01

# Clean up
molecule destroy -s default
```

### From Repository Root

```bash
# Run k3s molecule tests via Makefile
make test-molecule-k3s

# Run all collection tests
make test-molecule

# Debug with converge only
make molecule-converge-k3s
```

### CI/CD Execution

The tests run automatically in GitHub Actions:

```yaml
- name: Run Molecule tests
  run: |
    cd ansible_collections/homelab/k3s
    molecule test -s default
```

## Container Limitations

### Expected Behaviors

Due to container constraints, some features may not work identically to real hardware:

1. **Kernel modules**: Limited to host kernel modules
2. **Networking**: Container networking vs real hardware networking
3. **Storage**: Emulated storage subsystems
4. **Performance**: May be slower than physical hardware
5. **Pod scheduling**: Limited to available container resources

### Workarounds Implemented

- **Disabled components**: Traefik and ServiceLB disabled as they require advanced networking
- **Retry logic**: Generous retry/delay settings for container environments
- **Ignore errors**: Some sysctl operations may fail in containers (safely ignored)
- **Simplified networking**: Using host-gw backend instead of VXLAN

## Key Differences from Real Hardware

| Aspect | Container Test | Real Hardware (raspberry-pi scenario) |
|--------|---------------|---------------------------------------|
| **Platform** | Docker/Podman containers | Raspberry Pi 4 nodes |
| **Networking** | Container networking | Physical network |
| **Storage** | tmpfs/overlay | Physical disks |
| **K3s Components** | Minimal (no Traefik) | Full stack |
| **Test Duration** | 5-10 minutes | 15-30 minutes |
| **Resource Requirements** | Low (laptop) | High (4x Pi nodes) |

## Troubleshooting

### Common Issues

#### 1. K3s Service Won't Start

```bash
# Check service status
molecule login -s default -h k3s-server-01
systemctl status k3s
journalctl -u k3s -n 100
```

**Solution**: Check for port conflicts or permission issues

#### 2. Agents Don't Join Cluster

```bash
# Verify token is shared
molecule login -s default -h k3s-agent-01
cat /etc/systemd/system/k3s-agent.service.env
```

**Solution**: Ensure server node fully initialized before agents start

#### 3. Pods Stuck in Pending

```bash
# Check node status
molecule login -s default -h k3s-server-01
k3s kubectl get nodes
k3s kubectl describe node <node-name>
```

**Solution**: Container resource constraints may limit pod scheduling

#### 4. Cleanup Failures

```bash
# Manual cleanup
molecule destroy -s default
docker ps -a | grep k3s | awk '{print $1}' | xargs docker rm -f
```

## Integration with Other Collections

This scenario depends on:

- **homelab.common**: Provides `prereq` role and shared utilities
- **community.general**: For system management modules
- **ansible.posix**: For sysctl and firewall management

Ensure all dependencies are installed:

```bash
ansible-galaxy collection install -r ../../requirements.yml
```

## CI/CD Integration

### GitHub Actions Matrix

The scenario is part of the CI/CD matrix:

```yaml
matrix:
  include:
    - collection: k3s
      scenario: default
```

### Expected Duration

- **Prepare**: ~1 minute
- **Converge**: ~3-5 minutes
- **Verify**: ~2 minutes
- **Total**: ~8-10 minutes

### Success Criteria

- All roles apply without errors
- K3s services start and remain active
- Cluster forms with all nodes
- Test workload deploys successfully
- Verification assertions pass

## Contributing

When modifying this scenario:

1. **Test locally first**: Run `molecule test -s default`
2. **Update documentation**: Keep this README in sync with changes
3. **Consider CI constraints**: Tests must complete in < 15 minutes
4. **Verify idempotence**: `molecule converge` should be idempotent
5. **Check cleanup**: Ensure `cleanup.yml` handles all resources

## References

- [Molecule Documentation](https://molecule.readthedocs.io/)
- [K3s Documentation](https://docs.k3s.io/)
- [Docker Systemd Images](https://github.com/geerlingguy/docker-ubuntu2204-ansible)
- [Podman Compatibility](https://podman.io/getting-started/installation)

## Scenario Metadata

- **Created**: 2025-10-11
- **Molecule Version**: 6.0+
- **Docker Driver**: molecule-plugins[docker] >= 23.5.0
- **Target Environment**: CI/CD (GitHub Actions, GitLab CI, etc.)
- **Maintenance**: Active
