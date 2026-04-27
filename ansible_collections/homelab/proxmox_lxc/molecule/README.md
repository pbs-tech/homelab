# Molecule Tests for proxmox_lxc Collection

This directory contains Molecule test scenarios for the proxmox_lxc collection.

## Available Scenarios

### default
**Type:** Docker-based unit test
**Purpose:** Tests basic role functionality with a lightweight Prometheus deployment
**Runtime:** ~2-3 minutes
**CI:** ✅ Runs automatically in GitHub Actions

Tests:
- Role structure and dependencies
- Prometheus installation and configuration
- Service startup and health checks
- Basic API functionality

### proxmox-integration
**Type:** Real infrastructure test
**Purpose:** Tests actual LXC container deployment on Proxmox
**Runtime:** ~5-10 minutes
**CI:** ❌ Manual only (requires real Proxmox infrastructure)

Tests:
- LXC container creation
- Networking configuration
- Service deployment in real containers
- Full stack integration

## Running Tests

```bash
# Run default scenario (fast, CI-friendly)
cd ansible_collections/homelab/proxmox_lxc
molecule test

# Run proxmox integration (requires real Proxmox host)
molecule test -s proxmox-integration

# Individual test steps
molecule create      # Create test environment
molecule converge    # Run playbook
molecule verify      # Run verification
molecule destroy     # Clean up
```

## Design Philosophy

The molecule tests follow these principles:

1. **Fast feedback**: Default tests run in < 3 minutes
2. **Focused testing**: Each scenario tests specific functionality
3. **CI-friendly**: Docker-based tests require no infrastructure
4. **Manual integration**: Real infrastructure tests are opt-in

## Removed Scenarios

- **service-stack**: Too complex for CI, prone to timing issues
- **full-stack**: Redundant with individual collection tests

These were removed to improve CI reliability and test execution speed.
