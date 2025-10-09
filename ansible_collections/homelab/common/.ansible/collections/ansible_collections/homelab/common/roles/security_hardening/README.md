# Security Hardening Role

Comprehensive security hardening role for both K3s nodes and LXC containers, implementing security best practices, compliance standards, and automated security configuration.

## Features

- **CIS Benchmark Compliance** - Implements CIS security benchmarks
- **System Hardening** - Kernel parameters, file permissions, and service configuration
- **SSH Security** - SSH daemon hardening and key management
- **Firewall Configuration** - UFW/iptables rules with service-specific policies
- **Audit Logging** - auditd configuration for security monitoring
- **Fail2ban Protection** - Intrusion detection and prevention
- **Container Security** - LXC and Docker security policies
- **User Management** - Secure user creation and privilege management
- **Log Monitoring** - Centralized logging and security event detection

## Requirements

- Ubuntu 22.04 LTS (recommended)
- Root or sudo access
- Network connectivity for package updates
- homelab.common collection installed

## Role Variables

### General Security Settings

```yaml
# Enable/disable security features
security_hardening_enabled: true
security_audit_enabled: true
security_compliance_mode: "cis"  # cis, stig, custom

# Security profiles
security_profile: "high"  # low, medium, high, maximum
```

### System Hardening

```yaml
# Kernel security parameters
kernel_security_params:
  net.ipv4.conf.all.send_redirects: 0
  net.ipv4.conf.default.send_redirects: 0
  net.ipv4.conf.all.accept_redirects: 0
  net.ipv4.conf.default.accept_redirects: 0
  net.ipv4.conf.all.secure_redirects: 0
  net.ipv4.conf.default.secure_redirects: 0
  net.ipv4.ip_forward: 0
  net.ipv6.conf.all.accept_redirects: 0
  kernel.dmesg_restrict: 1
  kernel.kptr_restrict: 2

# File system security
filesystem_security:
  nodev_partitions:
    - /tmp
    - /var/tmp
    - /dev/shm
  nosuid_partitions:
    - /tmp
    - /var/tmp
  noexec_partitions:
    - /tmp
    - /var/tmp
```

### SSH Hardening

```yaml
# SSH daemon configuration
ssh_hardening:
  port: 22
  protocol: 2
  permit_root_login: "no"
  password_authentication: "no"
  pubkey_authentication: "yes"
  challenge_response_authentication: "no"
  use_pam: "yes"
  x11_forwarding: "no"
  max_auth_tries: 3
  max_sessions: 2
  client_alive_interval: 300
  client_alive_count_max: 0
  allow_users: ["pbs", "ansible"]
  deny_users: ["root", "nobody"]
  allowed_ciphers:
    - "aes256-gcm@openssh.com"
    - "chacha20-poly1305@openssh.com"
  allowed_kex:
    - "curve25519-sha256@libssh.org"
    - "diffie-hellman-group16-sha512"
  allowed_macs:
    - "hmac-sha2-256-etm@openssh.com"
    - "hmac-sha2-512-etm@openssh.com"
```

### Firewall Configuration

```yaml
# UFW firewall rules
ufw_config:
  enabled: true
  default_policy:
    incoming: "deny"
    outgoing: "allow"
    routed: "deny"

  # Service-specific rules
  service_rules:
    ssh:
      port: 22
      protocol: tcp
      source: "192.168.0.0/24"
      comment: "SSH access from local network"

    k3s_api:
      port: 6443
      protocol: tcp
      source: "192.168.0.0/24"
      comment: "K3s API server"
      apply_to: "k3s"

    prometheus:
      port: 9090
      protocol: tcp
      source: "192.168.0.205"  # Traefik only
      comment: "Prometheus metrics"
      apply_to: "monitoring"
```

### Audit Configuration

```yaml
# auditd configuration
audit_config:
  enabled: true
  rules_file: "/etc/audit/rules.d/audit.rules"
  max_log_file: 8
  num_logs: 5
  max_log_file_action: "rotate"

  # Audit rules
  rules:
    - "-w /etc/passwd -p wa -k identity"
    - "-w /etc/group -p wa -k identity"
    - "-w /etc/shadow -p wa -k identity"
    - "-w /etc/sudoers -p wa -k identity"
    - "-w /var/log/auth.log -p wa -k auth"
    - "-w /var/log/secure -p wa -k auth"
    - "-w /etc/ssh/sshd_config -p wa -k sshd"
    - "-a always,exit -F arch=b64 -S execve -k exec"
```

### Fail2ban Configuration

```yaml
# Fail2ban intrusion prevention
fail2ban_config:
  enabled: true
  backend: "systemd"
  ban_time: 600
  find_time: 600
  max_retry: 3

  # Service-specific jails
  jails:
    sshd:
      enabled: true
      port: 22
      filter: "sshd"
      logpath: "/var/log/auth.log"
      max_retry: 3
      ban_time: 3600

    traefik:
      enabled: true
      port: "http,https"
      filter: "traefik-auth"
      logpath: "/var/log/traefik/access.log"
      max_retry: 5
      ban_time: 1800
```

### Container Security (LXC)

```yaml
# LXC security configuration
lxc_security:
  unprivileged: true
  apparmor: true
  seccomp: true
  capabilities_drop:
    - "SYS_MODULE"
    - "SYS_RAWIO"
    - "SYS_PACCT"
    - "SYS_ADMIN"
    - "SYS_NICE"
    - "SYS_RESOURCE"
    - "SYS_TIME"
    - "SYS_TTY_CONFIG"
    - "AUDIT_WRITE"
    - "AUDIT_CONTROL"
    - "MAC_OVERRIDE"
    - "MAC_ADMIN"

  # Resource limits
  resource_limits:
    memory_limit: "2G"
    cpu_shares: 1024
    pids_limit: 1000
```

### K3s Security Configuration

```yaml
# K3s-specific hardening
k3s_security:
  pod_security_standards: "restricted"
  admission_controllers:
    - "NodeRestriction"
    - "ResourceQuota"
    - "LimitRanger"
    - "PodSecurityPolicy"

  kubelet_config:
    authentication:
      anonymous:
        enabled: false
      webhook:
        enabled: true
    authorization:
      mode: "Webhook"
    readOnlyPort: 0
    protectKernelDefaults: true
    makeIPTablesUtilChains: true
    eventRecordQPS: 0
    rotateCertificates: true
    serverTLSBootstrap: true
```

## Usage

### Basic Hardening

```yaml
- hosts: all
  become: yes
  roles:
    - homelab.common.security_hardening
```

### High Security Profile

```yaml
- hosts: all
  become: yes
  vars:
    security_profile: "maximum"
    security_compliance_mode: "cis"
  roles:
    - homelab.common.security_hardening
```

### K3s Cluster Hardening

```yaml
- hosts: k3s_cluster
  become: yes
  vars:
    k3s_security:
      pod_security_standards: "restricted"
      audit_log_enabled: true
  roles:
    - homelab.common.security_hardening
```

### LXC Container Hardening

```yaml
- hosts: lxc_containers
  become: yes
  vars:
    lxc_security:
      unprivileged: true
      apparmor: true
      seccomp: true
  roles:
    - homelab.common.security_hardening
```

## Security Profiles

### Low Profile

- Basic SSH hardening
- Standard firewall rules
- Basic logging
- Suitable for development environments

### Medium Profile (Default)

- SSH hardening with key-based auth
- UFW firewall with service rules
- auditd logging
- Fail2ban protection
- Basic system hardening

### High Profile

- Comprehensive SSH hardening
- Strict firewall rules
- Enhanced audit logging
- Aggressive fail2ban settings
- Container security policies
- Kernel hardening

### Maximum Profile

- CIS benchmark compliance
- Minimal attack surface
- Comprehensive monitoring
- Strict access controls
- Advanced container security
- Full audit trail

## Tasks Overview

### System Hardening Tasks

1. **Package Security** - Remove unnecessary packages, update system
2. **Kernel Hardening** - Configure security parameters
3. **File System Security** - Set proper permissions and mount options
4. **Service Configuration** - Disable unnecessary services
5. **User Management** - Configure secure user accounts

### Network Security Tasks

1. **SSH Hardening** - Configure secure SSH daemon
2. **Firewall Setup** - Configure UFW/iptables rules
3. **Network Parameters** - Secure kernel network settings
4. **Service Binding** - Restrict service network access

### Monitoring and Logging Tasks

1. **Audit Configuration** - Set up auditd logging
2. **Log Rotation** - Configure log management
3. **Intrusion Detection** - Configure fail2ban
4. **Monitoring Integration** - Set up metrics collection

### Container Security Tasks

1. **LXC Hardening** - Configure container security
2. **AppArmor Profiles** - Set up mandatory access controls
3. **Resource Limits** - Configure container constraints
4. **Capability Dropping** - Remove unnecessary privileges

## Files and Templates

### Configuration Templates

- **sshd_config.j2** - Hardened SSH daemon configuration
- **audit.rules.j2** - Audit rules template
- **jail.local.j2** - Fail2ban jail configuration
- **99-security.conf.j2** - Kernel security parameters

### Security Scripts

- **security-check.sh** - Security compliance checker
- **hardening-report.sh** - Generate hardening report
- **backup-configs.sh** - Backup original configurations

## Handlers

- `restart ssh` - Restart SSH daemon
- `restart ufw` - Restart firewall
- `restart auditd` - Restart audit daemon
- `restart fail2ban` - Restart fail2ban service
- `reload sysctl` - Reload kernel parameters

## Dependencies

- ansible.posix (for mount, sysctl modules)
- community.general (for ufw, fail2ban modules)

## Compliance Standards

### CIS Benchmark

Implements controls from:

- CIS Ubuntu Linux 22.04 LTS Benchmark
- CIS Kubernetes Benchmark
- CIS Container Runtime Benchmark

### Security Frameworks

- NIST Cybersecurity Framework
- OWASP Security Guidelines
- Docker Security Best Practices
- Kubernetes Security Best Practices

## Monitoring Integration

### Prometheus Metrics

Exports security-related metrics:

- Failed login attempts
- Firewall blocked connections
- Audit events count
- Service status

### Grafana Dashboards

Pre-configured dashboards for:

- Security events overview
- Authentication failures
- Network security status
- Compliance monitoring

### Alert Rules

Security-focused alerts:

- Multiple failed login attempts
- Privilege escalation attempts
- Suspicious network activity
- Service configuration changes

## Testing and Validation

### Security Tests

```bash
# Run security validation
ansible-playbook security-test.yml --check

# Generate compliance report
ansible-playbook hardening-report.yml
```

### Compliance Checking

```bash
# CIS benchmark scan
ansible-playbook cis-check.yml

# Custom security audit
ansible-playbook security-audit.yml
```

## Troubleshooting

### SSH Access Issues

```bash
# Check SSH configuration
sudo sshd -t
sudo systemctl status ssh

# Review authentication logs
sudo journalctl -u ssh -f
```

### Firewall Problems

```bash
# Check UFW status
sudo ufw status verbose
sudo ufw show listening

# Debug firewall rules
sudo iptables -L -v -n
```

### Audit System Issues

```bash
# Check auditd status
sudo systemctl status auditd
sudo auditctl -s

# Review audit logs
sudo ausearch -k identity
```

## Security Considerations

- **Backup Configurations** - Always backup original configs before hardening
- **Test Changes** - Test in development environment first
- **Monitor Impact** - Watch for service disruptions after hardening
- **Keep Updated** - Regularly update security configurations
- **Document Changes** - Maintain security change log

## Performance Impact

- **Minimal Impact** - Most hardening has negligible performance cost
- **Audit Logging** - May increase I/O load on busy systems
- **Firewall Rules** - Complex rules may affect network performance
- **Resource Limits** - Container limits may affect application performance

## License

Apache License 2.0 - See collection LICENSE file for details.
