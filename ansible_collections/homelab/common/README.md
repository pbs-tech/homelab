# Homelab Common Collection

This collection provides shared utilities, roles, and configuration for all homelab infrastructure
components. It serves as the foundation for both the K3s and Proxmox LXC collections, promoting
code reuse and consistency across the entire infrastructure.

## Features

- **Shared Configuration**: Centralized infrastructure topology and settings
- **Common Roles**: Reusable roles for system setup, security hardening, and container management
- **Unified Dependencies**: Consolidated collection requirements management
- **Standardized Patterns**: Consistent deployment patterns across all services

## Roles

### common_setup

Common system configuration and package installation for all infrastructure components.

**Features:**

- Package management for Debian/Ubuntu systems
- User account creation and SSH key management
- SSH daemon configuration with security hardening
- Timezone and logging configuration
- System service management

**Variables:**

- `common_packages`: OS-specific package lists
- `common_users`: List of users to create
- `ssh_config`: SSH daemon settings
- `security_settings`: Basic security configuration

### container_base

Base container management for Proxmox LXC deployments with intelligent node placement.

**Features:**

- Automatic Proxmox node selection based on service type
- LXC container creation and configuration
- Network configuration with static IP assignment
- Container startup ordering
- Resource allocation management

**Variables:**

- `container_resources`: CPU, memory, and disk allocation
- `container_network`: Network bridge and IP configuration
- `lxc_config`: LXC-specific settings
- `container_startup_order`: Service dependency ordering

### security_hardening

Security configuration and hardening for all infrastructure components.

**Features:**

- System security configuration
- Container security policies
- Audit logging setup
- Network security rules
- Compliance with security best practices

**Variables:**

- `security_hardening_enabled`: Enable/disable hardening (default: true)
- `security_audit_enabled`: Enable audit logging (default: true)
- `security_log_retention_days`: Log retention period (default: 30)
- `ssh_permit_root_login`: Root SSH access (default: "prohibit-password")
- `ssh_password_authentication`: Allow password auth (default: false)

### monitoring_agent

Monitoring agent deployment for metrics and log collection.

**Features:**

- Node exporter installation and configuration
- Promtail log shipping agent
- Service discovery registration
- Health check endpoints
- Integration with Prometheus and Loki

**Variables:**

- `monitoring_enabled`: Enable monitoring agents (default: true)
- `node_exporter_port`: Node exporter port (default: 9100)
- `promtail_config`: Promtail configuration settings
- `prometheus_endpoint`: Prometheus server URL
- `loki_endpoint`: Loki server URL for log shipping

## Shared Configuration

The collection includes centralized configuration in `inventory/group_vars/all.yml`:

### Infrastructure Topology

- Network layout and IP addressing
- Domain configuration
- Service endpoints

### Proxmox Configuration

- Multi-node Proxmox setup
- API connection settings
- Node-specific configurations

### K3s Integration

- Cluster configuration
- Service discovery
- Integration endpoints

### Security Settings

- Hardening policies
- Audit configuration
- SSH and authentication settings

### Container Defaults

- Resource allocation templates
- Network configuration
- Template selection

## Usage

### Installation

```bash
# Install the collection
ansible-galaxy collection install homelab.common

# Or install from source
ansible-galaxy collection install -p . /path/to/homelab/common
```

### Dependencies

```bash
# Install all dependencies
ansible-galaxy install -r requirements.yml
```

### Role Usage

```yaml
# Use in playbooks
- hosts: all
  roles:
    - homelab.common.common_setup
    - homelab.common.security_hardening

# Use for container deployment
- hosts: lxc_containers
  pre_tasks:
    - include_role:
        name: homelab.common.container_base
```

### Configuration Override

```yaml
# Override common settings in your inventory
homelab_domain: "mylab.local"
security_config:
  hardening_enabled: true
  log_retention_days: 14
```

## Integration with Other Collections

### homelab.k3s

The K3s collection inherits:

- Security hardening roles
- Common system setup
- Network configuration
- Monitoring integration points

### homelab.proxmox_lxc

The Proxmox LXC collection inherits:

- Container base management
- Security hardening
- Service configuration patterns
- Network topology

### Secure Enclave Integration

The `secure_enclave` role in proxmox_lxc uses common collection roles for:

- **Security hardening** - Applied to bastion host and enclave infrastructure
- **Container base** - Used for LXC-based enclave components
- **Common setup** - System configuration for enclave VMs

The enclave provides an isolated pentesting environment with:
- Network isolation (10.10.0.0/24 subnet)
- Credential management and documentation
- CTF challenge mode with scoring
- Web dashboard for monitoring
- Traffic capture capabilities
- VPN access for remote testing

## Best Practices

### Configuration Management

- Use centralized configuration in the common collection
- Override specific settings in service-specific collections
- Maintain consistent naming conventions
- Document configuration changes

### Role Design

- Keep roles focused and single-purpose
- Use role dependencies appropriately
- Include comprehensive defaults
- Provide clear documentation

### Security

- Enable security hardening by default
- Use least-privilege access patterns
- Implement audit logging
- Regular security updates

## Testing

### Molecule Testing

```bash
cd ansible_collections/homelab/common/

# Run default tests
molecule test

# Run common-roles scenario
molecule test -s common-roles

# Development workflow
molecule create              # Create test environment
molecule converge           # Run playbook
molecule verify             # Run verification
molecule destroy            # Clean up
```

### Test Coverage

The Molecule tests validate:

- **common_setup**: Package installation, user creation, SSH configuration
- **container_base**: LXC container lifecycle, network configuration
- **security_hardening**: Hardening controls, audit logging, SSH settings
- **monitoring_agent**: Exporter installation, service registration

### Smoke Tests

From the repository root:

```bash
# Quick validation of common roles
make test-molecule-smoke

# Full common collection tests
make test-molecule-common
```

## Development

### Adding New Shared Components

1. Create the role in `roles/`
2. Add default variables
3. Document the role's purpose and usage
4. Update collection dependencies if needed
5. Test integration with dependent collections

### Extending Configuration

1. Add new settings to `inventory/group_vars/all.yml`
2. Document the configuration in README
3. Update dependent collections to use new settings
4. Verify backward compatibility

## Contributing

When contributing to this collection:

1. Ensure changes benefit multiple collections
2. Maintain backward compatibility
3. Update documentation
4. Test with all dependent collections
5. Follow Ansible best practices

## Version Compatibility

- Ansible: >= 2.15.0
- Python: >= 3.8
- Collections: See requirements.yml

## License

Apache License 2.0
