# Common Setup Role

Foundation role for all homelab infrastructure components, providing standardized system configuration, user management, SSH hardening, and logging setup for both K3s nodes and LXC containers.

## Features

- **Package Management** - Automated installation of essential system packages
- **User Management** - Secure user account creation with SSH key deployment
- **SSH Hardening** - SSH daemon configuration with security best practices
- **Timezone Configuration** - Centralized timezone management across infrastructure
- **Logging Setup** - rsyslog and logrotate configuration for centralized logging
- **Service Management** - Automatic service enablement and startup
- **Cross-Platform Support** - Compatible with Ubuntu and Debian distributions
- **Idempotent Operations** - Safe to run repeatedly without side effects

## Requirements

- Ubuntu 22.04 LTS or Debian 11+ (recommended)
- Root or sudo access
- Network connectivity for package installation
- homelab.common collection installed

## Role Variables

### Package Management

```yaml
# Distribution-specific package lists
common_packages:
  ubuntu:
    - curl
    - wget
    - htop
    - vim
    - git
    - unzip
    - ca-certificates
    - python3
    - python3-pip
  debian:
    - curl
    - wget
    - htop
    - vim
    - git
    - unzip
    - ca-certificates
    - python3
    - python3-pip
```

### User Configuration

```yaml
# List of users to create
common_users: []

# Example user configuration:
common_users:
  - name: serviceuser
    shell: /bin/bash
    groups: ["sudo"]
  - name: ansible
    shell: /bin/bash
    groups: ["sudo", "docker"]
```

### SSH Configuration

```yaml
# SSH daemon security settings
ssh_config:
  port: 22
  permit_root_login: false
  password_authentication: false
  pubkey_authentication: true
  authorized_keys_file: /home/%u/.ssh/authorized_keys
```

### Timezone Configuration

```yaml
# System timezone (inherits from global homelab_timezone if available)
timezone: "{{ homelab_timezone | default('UTC') }}"
```

### Logging Configuration

```yaml
# rsyslog settings
rsyslog_config:
  max_message_size: 64k
  preserve_fqdn: true
  remote_logging: false

# Log retention (requires security_config.log_retention_days)
security_config:
  log_retention_days: 30
```

### Security Settings

```yaml
# Basic security configuration
security_settings:
  disable_ipv6: false
  enable_fail2ban: true
  ufw_default_policy: deny

# SSH key path for authorized_key deployment
security_config:
  ssh_key_path: ~/.ssh/id_rsa
```

## Usage

### Basic Infrastructure Setup

```yaml
- hosts: all
  become: yes
  roles:
    - homelab.common.common_setup
```

### With Custom Users

```yaml
- hosts: all
  become: yes
  vars:
    common_users:
      - name: deploy
        shell: /bin/bash
        groups: ["sudo"]
      - name: monitoring
        shell: /bin/false
        groups: []
  roles:
    - homelab.common.common_setup
```

### K3s Cluster Setup

```yaml
- hosts: k3s_cluster
  become: yes
  vars:
    timezone: "America/New_York"
    common_users:
      - name: k3s-admin
        shell: /bin/bash
        groups: ["sudo"]
  roles:
    - homelab.common.common_setup
```

### LXC Container Setup

```yaml
- hosts: lxc_containers
  become: yes
  vars:
    ssh_config:
      port: 22
      permit_root_login: false
      password_authentication: false
    rsyslog_config:
      remote_logging: true
      remote_host: "192.168.0.210"
  roles:
    - homelab.common.common_setup
```

### Custom Package Installation

```yaml
- hosts: all
  become: yes
  vars:
    common_packages:
      ubuntu:
        - curl
        - wget
        - htop
        - vim
        - git
        - unzip
        - ca-certificates
        - python3
        - python3-pip
        - tmux          # Additional packages
        - ncdu
        - net-tools
  roles:
    - homelab.common.common_setup
```

## Tasks Overview

### System Configuration Tasks

1. **Update Package Cache** - Refresh apt cache for package installation
2. **Install Common Packages** - Install distribution-specific essential packages
3. **Set Timezone** - Configure system timezone consistently
4. **Create Common Users** - Set up user accounts with proper shells and groups
5. **Configure SSH Keys** - Deploy authorized keys for SSH access

### Security Configuration Tasks

1. **SSH Daemon Hardening** - Configure secure SSH daemon settings
2. **SSH Service Management** - Enable and start SSH service
3. **Configuration Validation** - Validate SSH configuration before applying

### Logging Configuration Tasks

1. **Configure rsyslog** - Set up centralized logging infrastructure
2. **Log Rotation Setup** - Configure logrotate for log management
3. **Service Restart** - Restart rsyslog to apply configuration

## Files and Templates

### Configuration Templates

- **sshd_config.j2** - SSH daemon configuration template
- **rsyslog.conf.j2** - rsyslog configuration for centralized logging
- **logrotate.conf.j2** - Log rotation configuration for system logs

### Template Variables

All templates use role variables and support Jinja2 templating for dynamic configuration based on inventory and group variables.

## Handlers

- `restart ssh` - Restart SSH daemon after configuration changes
- `restart rsyslog` - Restart rsyslog service after configuration updates

## Dependencies

- ansible.posix (for authorized_key module)
- community.general (for timezone module)

## Platform Support

### Tested Platforms

- Ubuntu 22.04 LTS
- Ubuntu 20.04 LTS
- Debian 11 (Bullseye)

### Distribution Detection

The role automatically detects the distribution and applies appropriate package lists using `ansible_distribution` fact.

## Configuration Examples

### Development Environment

```yaml
- hosts: dev_servers
  become: yes
  vars:
    timezone: "America/Los_Angeles"
    ssh_config:
      port: 22
      permit_root_login: false
      password_authentication: false
    common_users:
      - name: developer
        shell: /bin/bash
        groups: ["sudo", "docker"]
  roles:
    - homelab.common.common_setup
```

### Production Environment

```yaml
- hosts: production
  become: yes
  vars:
    timezone: "UTC"
    ssh_config:
      port: 22
      permit_root_login: false
      password_authentication: false
    rsyslog_config:
      remote_logging: true
      remote_host: "syslog.homelab.local"
    security_config:
      log_retention_days: 90
    common_users:
      - name: ansible
        shell: /bin/bash
        groups: ["sudo"]
  roles:
    - homelab.common.common_setup
```

### Bastion Host Configuration

```yaml
- hosts: bastion
  become: yes
  vars:
    timezone: "UTC"
    ssh_config:
      port: 22
      permit_root_login: false
      password_authentication: false
    common_users:
      - name: jumpuser
        shell: /bin/bash
        groups: ["sudo"]
      - name: audit
        shell: /bin/bash
        groups: []
    rsyslog_config:
      preserve_fqdn: true
      remote_logging: false
    security_config:
      log_retention_days: 180
  roles:
    - homelab.common.common_setup
```

## Integration with Other Roles

### Combined with Security Hardening

```yaml
- hosts: all
  become: yes
  roles:
    - homelab.common.common_setup
    - homelab.common.security_hardening
```

### Combined with Monitoring Agent

```yaml
- hosts: all
  become: yes
  roles:
    - homelab.common.common_setup
    - homelab.common.monitoring_agent
```

### Full Infrastructure Stack

```yaml
- hosts: all
  become: yes
  roles:
    - homelab.common.common_setup
    - homelab.common.security_hardening
    - homelab.common.monitoring_agent
```

## Testing and Validation

### Verify SSH Configuration

```bash
# Test SSH configuration syntax
sudo sshd -t

# Check SSH service status
sudo systemctl status ssh

# Verify SSH can be reloaded
sudo systemctl reload ssh
```

### Verify User Creation

```bash
# Check user accounts
getent passwd | grep -E "serviceuser|ansible"

# Verify user groups
groups serviceuser
groups ansible
```

### Verify Logging

```bash
# Check rsyslog status
sudo systemctl status rsyslog

# Test logging
logger -t test "Test message"
tail -f /var/log/syslog

# Verify logrotate configuration
sudo logrotate -d /etc/logrotate.d/*
```

### Verify Timezone

```bash
# Check system timezone
timedatectl status

# Verify time is synchronized
systemctl status systemd-timesyncd
```

## Troubleshooting

### SSH Access Issues

```bash
# Check SSH configuration syntax
sudo sshd -t

# View SSH logs
sudo journalctl -u ssh -f

# Test SSH connection locally
ssh localhost

# Verify SSH keys are deployed
ls -la ~/.ssh/authorized_keys
```

### Package Installation Failures

```bash
# Update package cache manually
sudo apt update

# Check for held packages
apt-mark showhold

# View package manager logs
cat /var/log/apt/term.log
```

### User Creation Problems

```bash
# Check if user exists
id username

# View user creation logs
sudo journalctl -t ansible

# Verify home directory
ls -la /home/username
```

### Logging Issues

```bash
# Check rsyslog status
sudo systemctl status rsyslog

# Test rsyslog configuration
sudo rsyslogd -N1

# View rsyslog logs
sudo journalctl -u rsyslog -f

# Check log file permissions
ls -la /var/log/
```

## Security Considerations

- **SSH Key Management** - Ensure SSH private keys are properly secured and not committed to version control
- **User Passwords** - Users created without passwords; SSH key authentication required
- **Root Access** - Root login disabled by default; use sudo for administrative tasks
- **Configuration Backups** - Original configurations backed up before modification
- **Log Security** - Log files contain sensitive information; restrict access appropriately

## Performance Impact

- **Minimal Overhead** - Package installation is one-time operation
- **SSH Performance** - Optimized SSH configuration maintains connection speed
- **Logging Impact** - Local logging has negligible performance impact
- **Remote Logging** - Network logging may increase bandwidth usage

## Best Practices

1. **Always Test First** - Test role in development before production deployment
2. **Use Version Control** - Track changes to common_users and ssh_config
3. **Document Custom Packages** - Maintain documentation for additional packages
4. **Regular Updates** - Keep common packages list current with security updates
5. **SSH Key Rotation** - Periodically rotate SSH keys for security
6. **Monitor Logs** - Regularly review logs for anomalies
7. **Backup Configurations** - Keep backups of critical configuration files

## Change Management

### Adding New Packages

```yaml
# Extend default package list
common_packages:
  ubuntu: "{{ common_packages.ubuntu + ['newpackage1', 'newpackage2'] }}"
```

### Changing SSH Port

```yaml
ssh_config:
  port: 2222  # Custom SSH port
  # Remember to update firewall rules!
```

### Remote Logging Setup

```yaml
rsyslog_config:
  remote_logging: true
  remote_host: "192.168.0.210"  # Loki server
  remote_port: 514
  protocol: tcp
```

## License

Apache License 2.0 - See collection LICENSE file for details.
