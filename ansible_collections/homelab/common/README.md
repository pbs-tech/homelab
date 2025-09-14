# Homelab Common Collection

This collection provides shared utilities, roles, and configuration for all homelab infrastructure components. It serves as the foundation for both the K3s and Proxmox LXC collections, promoting code reuse and consistency across the entire infrastructure.

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
