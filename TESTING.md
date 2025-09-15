# Homelab Testing Strategy

This document outlines the comprehensive testing approach for the homelab infrastructure, combining
rapid local development with production workflow validation.

## Testing Philosophy

The testing strategy employs two complementary approaches:

1. **Molecule Tests** - Fast, reproducible local development using containers
2. **Production Tests** - Validation against actual hardware and infrastructure

This dual approach ensures both rapid iteration during development and confidence in production deployments.

## Test Categories

### Molecule Tests (Development & CI)

#### Molecule Purpose

- Rapid local testing during development
- Reproducible test environments
- Automated CI/CD validation
- Role and collection functionality verification

#### Molecule Types

**Collection-Specific Tests:**

- `homelab.common/molecule/default/` - Basic common role functionality
- `homelab.common/molecule/common-roles/` - Advanced container and configuration logic
- `homelab.k3s/molecule/raspberry-pi/` - K3s deployment patterns
- `homelab.proxmox_lxc/molecule/service-stack/` - Service deployment stacks
- `homelab.proxmox_lxc/molecule/proxmox-integration/` - Proxmox API integration

**Full-Stack Integration Test:**

- `molecule/full-stack/` - Complete infrastructure orchestration using new playbook architecture

#### Running Molecule Tests

```bash
# Individual collection tests
cd ansible_collections/homelab/common/
molecule test

cd ansible_collections/homelab/k3s/
molecule test -s raspberry-pi

cd ansible_collections/homelab/proxmox_lxc/
molecule test -s service-stack

# Full-stack integration test
cd molecule/full-stack/
molecule test

# Specific scenario testing
molecule converge -s default    # Deploy only
molecule verify -s default     # Test only
molecule destroy -s default    # Cleanup only
```

### Production Tests (Hardware Validation)

#### Production Purpose

- Validate actual production workflows
- Test against real hardware (Raspberry Pi, Proxmox)
- End-to-end infrastructure deployment verification
- Production readiness confirmation

#### Production Types

**Unit Tests (`tests/unit/`):**

- Role loading and variable validation
- Configuration logic verification
- Safe to run anywhere (check mode)

**Integration Tests (`tests/integration/`):**

- Service stack deployment using containers
- Inter-service communication testing
- Configuration validation across services

**System Tests (`tests/system/`):**

- K3s cluster deployment on actual Raspberry Pi hardware
- Proxmox LXC container lifecycle management
- Real infrastructure integration testing

#### Running Production Tests

```bash
cd tests/

# All test types
ansible-playbook test_suite.yml

# Specific test types
ansible-playbook test_suite.yml -e "test_types=['unit']" --tags quick
ansible-playbook test_suite.yml -e "test_types=['integration']"
ansible-playbook test_suite.yml -e "test_types=['system']" -e proxmox_password=your_password

# Individual test files
ansible-playbook unit/test_common_roles.yml
ansible-playbook system/test_k3s_cluster.yml -e proxmox_password=your_password
```

## Development Workflow

### Local Development Cycle

1. **Make changes** to roles, playbooks, or configuration
2. **Run molecule tests** for rapid feedback:

   ```bash
   cd ansible_collections/homelab/common/
   molecule test
   ```

3. **Test specific scenarios** as needed:

   ```bash
   molecule converge -s common-roles
   molecule verify -s common-roles
   ```

4. **Run full-stack test** for integration validation:

   ```bash
   cd ../../molecule/full-stack/
   molecule test
   ```

5. **Commit changes** once molecule tests pass

### Pre-Production Validation

1. **Run production unit tests** (safe, no hardware required):

   ```bash
   cd tests/
   ansible-playbook test_suite.yml -e "test_types=['unit']" --tags quick
   ```

2. **Run integration tests** (uses containers, no hardware required):

   ```bash
   ansible-playbook test_suite.yml -e "test_types=['integration']"
   ```

3. **Run system tests** against test hardware:

   ```bash
   ansible-playbook test_suite.yml -e "test_types=['system']" -e proxmox_password=your_password
   ```

### CI/CD Pipeline

The GitHub Actions workflow (`/.github/workflows/molecule.yml`) automatically:

1. Runs all molecule tests across collections and scenarios
2. Executes full-stack integration test
3. Validates production unit tests
4. Provides comprehensive test reporting

## Test Configuration

### Molecule Configuration

Each molecule scenario includes:

- **molecule.yml** - Test infrastructure definition
- **converge.yml** - Deployment test playbook
- **verify.yml** - Validation test playbook
- **prepare.yml** - Test environment setup (optional)

### Production Test Configuration

Production tests use:

- **tests/inventory/test_hosts.yml** - Test target configuration
- **tests/ansible.cfg** - Test-specific Ansible settings
- **Common collection variables** - Shared configuration

### Environment Setup

#### For Molecule Tests

```bash
# Install molecule and dependencies
pip install molecule[docker] molecule-plugins[docker] containers.podman

# Install collections
ansible-galaxy install -r requirements.yml
```

#### For Production Tests

```bash
# Configure test inventory
cp tests/inventory/test_hosts.yml.example tests/inventory/test_hosts.yml
# Edit with your test environment details

# Set up authentication
echo "your_vault_password" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass

# For Proxmox tests
export PROXMOX_PASSWORD="your_proxmox_password"
# Or use vault: ansible-vault encrypt_string 'password' --name proxmox_password
```

## Best Practices

### Molecule Test Development

- **Keep tests fast** - Use check mode where possible
- **Mock external dependencies** - Avoid real API calls in molecule
- **Test role logic** - Focus on variable computation and task flow
- **Use realistic scenarios** - Mirror production inventory patterns

### Production Test Development

- **Ensure idempotency** - Tests should be runnable multiple times
- **Clean up resources** - Always clean up test containers/VMs
- **Include comprehensive assertions** - Verify expected outcomes
- **Document prerequisites** - Clear setup requirements

### Test Data Management

- **Use consistent test data** - Standardize mock configurations
- **Avoid hardcoded values** - Use variables for test configuration
- **Mock secrets safely** - Never commit real credentials
- **Version test configurations** - Track test inventory changes

## Troubleshooting

### Common Issues

### Molecule Tests

```bash
# Podman connection issues
podman system reset  # Reset podman state
molecule destroy    # Clean up containers

# Collection import errors
ansible-galaxy install -r requirements.yml --force

# Platform compatibility
molecule test --scenario-name default  # Specify scenario explicitly
```

### Production Tests

```bash
# SSH connectivity
ansible all -m ping -i tests/inventory/test_hosts.yml

# Proxmox API issues
curl -k https://your-proxmox-host:8006/api2/json/version

# Vault password issues
ansible-vault decrypt tests/inventory/test_hosts.yml --vault-password-file ~/.ansible_vault_pass
```

### Debug Mode

```bash
# Verbose molecule output
molecule test -s default -vvv

# Production test debugging
cd tests/
ansible-playbook test_suite.yml -vvv -e "test_types=['unit']"

# Check mode for safe testing
ansible-playbook test_suite.yml --check -e "test_types=['unit']"
```

## Future Enhancements

- **Performance testing** - Load testing for services
- **Security scanning** - Automated security validation
- **Chaos engineering** - Failure scenario testing
- **Multi-environment testing** - Development, staging, production variants
- **Test coverage reporting** - Comprehensive test coverage metrics

## Contributing

When adding new tests:

1. **Follow existing patterns** - Use established test structures
2. **Update documentation** - Document new test scenarios
3. **Verify CI compatibility** - Ensure tests work in GitHub Actions
4. **Test both approaches** - Add both molecule and production tests where applicable
5. **Include cleanup logic** - Always clean up test resources
