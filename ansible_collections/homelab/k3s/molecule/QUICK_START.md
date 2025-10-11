# K3s Molecule Tests - Quick Start Guide

Get started with K3s molecule tests in 60 seconds.

## Prerequisites

```bash
# Install molecule and dependencies
pip install "molecule>=6.0" "molecule-plugins[docker]>=23.5.0" docker

# Install collections
cd /home/pbs/ansible/homelab
ansible-galaxy collection install -r requirements.yml --force
ansible-galaxy collection install ansible_collections/homelab/common/ --force
ansible-galaxy collection install ansible_collections/homelab/k3s/ --force
```

## Quick Test

```bash
# From repository root
make test-molecule-k3s

# Or directly
cd ansible_collections/homelab/k3s/
molecule test -s default
```

**Expected duration**: 8-10 minutes

## Iterative Development

```bash
cd ansible_collections/homelab/k3s/

# 1. Create test environment (once)
molecule create -s default

# 2. Make code changes
vim roles/k3s_server/tasks/main.yml

# 3. Test changes (repeatable)
molecule converge -s default

# 4. Verify (optional)
molecule verify -s default

# 5. Debug if needed
molecule login -s default -h k3s-server-01

# 6. Cleanup when done
molecule destroy -s default
```

## Common Commands

```bash
# Run full test (destroy, create, converge, verify, destroy)
molecule test -s default

# Only create containers
molecule create -s default

# Only run playbook
molecule converge -s default

# Only run verification
molecule verify -s default

# Login to container
molecule login -s default -h k3s-server-01
molecule login -s default -h k3s-agent-01

# Destroy containers
molecule destroy -s default

# List running instances
molecule list -s default
```

## What Gets Tested

✅ K3s server installation and configuration
✅ K3s agent installation and joining cluster
✅ Cluster formation (1 server + 2 agents)
✅ Service management (systemd)
✅ API server functionality
✅ Node registration and readiness
✅ Basic workload deployment

## Quick Debugging

### Check K3s service status

```bash
molecule login -s default -h k3s-server-01
systemctl status k3s
journalctl -u k3s -n 50
```

### Verify cluster nodes

```bash
molecule login -s default -h k3s-server-01
k3s kubectl get nodes
k3s kubectl get pods --all-namespaces
```

### Check agent connection

```bash
molecule login -s default -h k3s-agent-01
systemctl status k3s-agent
cat /etc/systemd/system/k3s-agent.service.env
```

## Troubleshooting

### Problem: Molecule not found

```bash
pip install "molecule>=6.0" "molecule-plugins[docker]>=23.5.0"
```

### Problem: Collection not found

```bash
cd /home/pbs/ansible/homelab
ansible-galaxy collection install ansible_collections/homelab/common/ --force
```

### Problem: Test hangs or fails

```bash
# Clean up and retry
molecule destroy -s default
docker ps -a | grep k3s | awk '{print $1}' | xargs docker rm -f
molecule test -s default
```

### Problem: Permission denied

```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

## Test Scenarios

### Default (CI-Compatible) - 8-10 minutes

```bash
molecule test -s default
```

Fast containerized tests for development and CI.

### Raspberry Pi (Real Hardware) - 15-30 minutes

```bash
molecule test -s raspberry-pi
```

Full integration tests on production hardware.
Requires: 4x Raspberry Pi nodes at 192.168.0.111-114

## CI/CD Integration

Tests run automatically in GitHub Actions:

- On pull requests to main/develop
- On pushes to main branch
- On manual workflow dispatch

View results at: `.github/workflows/ci.yml`

## File Structure

```text
molecule/
├── default/              # CI-compatible tests
│   ├── molecule.yml      # Platform configuration
│   ├── prepare.yml       # Environment setup
│   ├── converge.yml      # K3s deployment
│   ├── verify.yml        # Verification tests
│   ├── cleanup.yml       # Resource cleanup
│   └── README.md         # Detailed docs
├── raspberry-pi/         # Real hardware tests
│   └── ...
├── TEST_STRATEGY.md      # Testing strategy
└── QUICK_START.md        # This file
```

## Next Steps

1. **Run your first test**: `make test-molecule-k3s`
2. **Read detailed docs**: `molecule/default/README.md`
3. **Review test strategy**: `molecule/TEST_STRATEGY.md`
4. **Check CI integration**: `.github/workflows/ci.yml`

## Quick Reference

| Command | Purpose | Duration |
|---------|---------|----------|
| `make test-molecule-k3s` | Full test from repo root | 8-10 min |
| `molecule test -s default` | Full test from collection dir | 8-10 min |
| `molecule converge -s default` | Quick test (no cleanup) | 5-7 min |
| `molecule verify -s default` | Verify only | 2 min |
| `molecule destroy -s default` | Cleanup | 30 sec |

## Getting Help

1. Check logs: `molecule --debug test -s default`
2. Review README: `molecule/default/README.md`
3. Check test strategy: `molecule/TEST_STRATEGY.md`
4. Inspect configuration: `molecule/default/molecule.yml`

---

**Ready to test?** Run: `make test-molecule-k3s`
