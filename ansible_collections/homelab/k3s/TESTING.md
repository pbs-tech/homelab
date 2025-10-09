# K3s Collection Testing

This collection uses Molecule 6.0+ for automated testing on real Raspberry Pi hardware.

## Quick Start

### Prerequisites

```bash
# Install Molecule and dependencies
pip install "molecule>=6.0" "molecule-plugins[docker]>=23.5.0"
pip install "ansible-core>=2.17" "yamllint>=1.35" "ansible-lint>=24.0"

# Install required collections
ansible-galaxy install -r requirements.yml
```

### Raspberry Pi Cluster Testing

```bash
# Test K3s deployment on actual Pi hardware
molecule test -s raspberry-pi
```

## Available Test Scenarios

### `raspberry-pi` - Real Hardware Testing

- **Platform**: Raspberry Pi nodes (k3s-1, k3s-4)
- **Purpose**: Validate K3s cluster on ARM64 hardware
- **Nodes Tested**:
  - k3s-1 (192.168.0.111) - Server
  - k3s-4 (192.168.0.114) - Agent
- **Runtime**: ~15-20 minutes

## Test Coverage

| Role | Pi Hardware Test |
|------|------------------|
| prereq | ✅ |
| k3s_server | ✅ |
| k3s_agent | ✅ |
| security_hardening | ✅ |
| raspberrypi | ⚠️ |

## What Gets Tested

### Cluster Functionality

- ✅ K3s server initialization
- ✅ Agent joining to cluster
- ✅ Node readiness validation
- ✅ Pod scheduling and execution
- ✅ Network connectivity between nodes
- ✅ Basic workload deployment

### Security & Hardening

- ✅ Security hardening application
- ✅ Service account configuration
- ✅ Network policy validation

### Hardware Compatibility

- ✅ ARM64 binary compatibility
- ✅ Resource constraints validation
- ✅ Storage configuration
- ✅ Network interface setup

## Environment Setup

### SSH Access

Ensure you can SSH to your Pi nodes:

```bash
ssh pbs@192.168.0.111  # k3s-1
ssh pbs@192.168.0.114  # k3s-4
```

### Resource Requirements

- **Minimum RAM**: 1GB per Pi node
- **Minimum Storage**: 8GB available
- **Network**: All nodes must be on same subnet

## Test Workflow

### 1. Preparation Phase

- Validates resource availability
- Cleans up any existing K3s installation
- Prepares test environment

### 2. Deployment Phase

- Installs prerequisites on all nodes
- Bootstraps K3s server on k3s-1
- Joins k3s-4 as agent node
- Applies security hardening

### 3. Verification Phase

- Tests cluster readiness
- Deploys test workload
- Validates networking
- Confirms security settings

### 4. Cleanup Phase

- Removes test workloads
- Preserves cluster for continued use
- Logs completion status

## Troubleshooting

### Node Connectivity Issues

```bash
# Test SSH connectivity
ansible raspberry_pi_test -i molecule/raspberry-pi/molecule.yml -m ping

# Check node resources
ansible raspberry_pi_test -i molecule/raspberry-pi/molecule.yml \
  -m shell -a "free -h && df -h"
```

### K3s Service Issues

```bash
# Login to problematic node
molecule login -s raspberry-pi -h k3s-test-1

# Check K3s server logs
sudo journalctl -u k3s -f

# Check cluster status
sudo k3s kubectl get nodes -o wide
```

### Memory Issues

- K3s requires minimum 512MB available RAM
- Check for other services consuming memory
- Consider stopping unnecessary services during testing

### Network Issues

```bash
# Test inter-node connectivity
ping 192.168.0.111  # from k3s-4
ping 192.168.0.114  # from k3s-1

# Check firewall rules
sudo ufw status

# Verify K3s networking
sudo k3s kubectl get pods -n kube-system
```

## Safety Considerations

### Non-Destructive Testing

- Tests preserve existing cluster state when possible
- Cleanup phase removes only test resources
- Original configurations are backed up

### Resource Management

- Tests use minimal resource footprint
- Temporary workloads are cleaned up
- Storage usage is monitored

### Network Safety

- Uses test-specific namespaces
- No modification of production traffic
- Isolated test workloads

## Manual Testing Commands

```bash
# Test cluster after Molecule run
ssh pbs@192.168.0.111
sudo k3s kubectl get nodes
sudo k3s kubectl get pods --all-namespaces

# Deploy test workload manually
sudo k3s kubectl run nginx-test --image=nginx:alpine
sudo k3s kubectl expose pod nginx-test --port=80 --type=NodePort

# Cleanup manual tests
sudo k3s kubectl delete pod nginx-test
sudo k3s kubectl delete service nginx-test
```
