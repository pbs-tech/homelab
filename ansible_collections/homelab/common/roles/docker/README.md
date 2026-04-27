# Docker Role

Installs and configures Docker CE on Ubuntu/Debian systems, including the Docker Compose plugin, GPG key management, and user group configuration.

## Features

- **Idempotent Installation** - Skips installation if Docker binary already exists
- **GPG Key Management** - Downloads and configures Docker's official GPG key
- **Architecture Detection** - Automatically detects amd64, arm64, and armhf architectures
- **Docker Compose** - Installs the docker-compose-plugin alongside Docker CE
- **User Group Management** - Configures docker group membership for specified users

## Requirements

- Ubuntu 22.04+ or Debian 11+ (Bookworm/Bullseye)
- Root or sudo access
- Network connectivity for package installation and Docker repository access

## Role Variables

```yaml
# Ensure the docker group exists (default: true)
docker_ensure_group: true

# List of users to add to the docker group (default: [])
docker_group_users: []
```

## Usage

### Basic Installation

```yaml
- hosts: docker_hosts
  become: yes
  roles:
    - homelab.common.docker
```

### With User Group Configuration

```yaml
- hosts: docker_hosts
  become: yes
  vars:
    docker_group_users:
      - ansible
      - deploy
  roles:
    - homelab.common.docker
```

## Handlers

- `Restart docker` - Restarts the Docker daemon after installation

## Dependencies

None.

## License

Apache License 2.0 - See collection LICENSE file for details.
