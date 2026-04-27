# Security Hardening Role (K3s-Specific)

K3s-specific security hardening role that extends the base security hardening from homelab.common collection with Raspberry Pi and K3s-focused security configurations. Implements security best practices for K3s cluster nodes running on Raspberry Pi hardware.

## Features

- **Raspberry Pi Detection** - Automatically detects Pi hardware for Pi-specific hardening
- **K3s-Aware Firewall** - UFW configuration compatible with K3s networking
- **SSH Hardening** - Enhanced SSH security for K3s nodes
- **Fail2ban Protection** - Intrusion detection tuned for K3s environment
- **Automatic Updates** - Unattended upgrades configured for Raspberry Pi
- **System Hardening** - K3s-compatible kernel and system hardening
- **Log Management** - Centralized logging configuration for K3s nodes
- **Security Monitoring** - Automated security monitoring script for K3s clusters

## Features Overview

This role wraps and extends homelab.common.security_hardening with:

- Raspberry Pi hardware detection
- Pi-specific security packages (including rpi-update)
- K3s-compatible firewall rules
- K3s-specific SSH hardening
- K3s environment fail2ban configuration
- Pi-optimized automatic updates
- K3s node logging configuration
- K3s security monitoring scripts

## Requirements

- Ubuntu 22.04 LTS or Raspberry Pi OS (recommended)
- Root or sudo access
- homelab.common collection installed
- K3s cluster (for K3s-specific configurations)
- Network connectivity for package updates

## Role Variables

### Security Feature Toggles

```yaml
# UFW firewall enabled
pi_security_hardening:
  ufw_enabled: true

  # Fail2ban intrusion detection
  fail2ban:
    enabled: true

  # Unattended upgrades
  unattended_upgrades:
    enabled: true

  # Logging configuration
  logging:
    rsyslog_enabled: true
```

### Raspberry Pi Detection

```yaml
# Automatically set by role
raspberry_pi: false  # Set to true if Pi hardware detected
```

### Security Packages

Automatically installs based on Pi detection:

**For Raspberry Pi:**
- ufw
- fail2ban
- unattended-upgrades
- apt-listchanges
- logrotate
- rsyslog
- rpi-update (Pi-specific)

**For Non-Pi Systems:**
- ufw
- fail2ban
- unattended-upgrades
- apt-listchanges
- logrotate
- rsyslog

## Usage

### Basic K3s Node Hardening

```yaml
- hosts: k3s_cluster
  become: yes
  roles:
    - homelab.k3s.security_hardening
```

### With Custom Security Settings

```yaml
- hosts: k3s_cluster
  become: yes
  vars:
    pi_security_hardening:
      ufw_enabled: true
      fail2ban:
        enabled: true
        ban_time: 3600
      unattended_upgrades:
        enabled: true
        auto_reboot: false
      logging:
        rsyslog_enabled: true
  roles:
    - homelab.k3s.security_hardening
```

### Selective Security Features

```yaml
- hosts: k3s_cluster
  become: yes
  vars:
    pi_security_hardening:
      ufw_enabled: true
      fail2ban:
        enabled: false  # Disable fail2ban
      unattended_upgrades:
        enabled: true
      logging:
        rsyslog_enabled: true
  roles:
    - homelab.k3s.security_hardening
```

## Tasks Overview

### Detection and Preparation

1. **Detect Raspberry Pi** - Identifies Pi hardware
2. **Update Package Cache** - Updates apt cache
3. **Install Security Packages** - Installs based on Pi detection

### Security Configuration

1. **Configure UFW** - Sets up K3s-compatible firewall rules
2. **Configure SSH** - Hardens SSH for K3s nodes
3. **Configure Fail2ban** - Sets up intrusion detection
4. **Configure Unattended Upgrades** - Enables automatic updates
5. **Apply System Hardening** - K3s-compatible system hardening
6. **Configure Logging** - Sets up centralized logging

### Monitoring Setup

1. **Create Monitoring Script** - Deploys K3s security monitoring script
2. **Setup Cron Job** - Schedules monitoring (every 30 minutes)

## Included Task Files

### Detection Tasks

- **detect_pi.yml** - Raspberry Pi hardware detection

### Firewall Configuration

- **configure_ufw_k3s.yml** - K3s-compatible UFW configuration

### SSH Hardening

- **configure_ssh_k3s.yml** - SSH hardening for K3s nodes

### Intrusion Detection

- **configure_fail2ban_k3s.yml** - Fail2ban for K3s environment

### Update Management

- **configure_unattended_upgrades_pi.yml** - Automatic updates for Pi

### System Hardening

- **pi_system_hardening.yml** - Pi-specific system hardening
- **system_hardening_k3s.yml** - General K3s system hardening

### Logging

- **configure_logging_k3s.yml** - Logging configuration for K3s nodes

## Templates

### Monitoring Scripts

- **k3s_security_monitor.sh.j2** - Security monitoring script for K3s clusters

## Files and Directories

### Configuration Files

- **/etc/ufw/** - UFW firewall configuration
- **/etc/ssh/sshd_config** - SSH daemon configuration
- **/etc/fail2ban/** - Fail2ban configuration
- **/etc/apt/apt.conf.d/50unattended-upgrades** - Unattended upgrades config
- **/etc/rsyslog.conf** - Rsyslog configuration

### Monitoring Scripts

- **/usr/local/bin/k3s_security_monitor.sh** - Security monitoring script

### Cron Jobs

- K3s security monitoring - Runs every 30 minutes

## Handlers

This role relies on handlers from included task files for service restarts.

## Dependencies

- homelab.common.security_hardening (used as reference/base)
- ansible.posix (for sysctl, firewall modules)
- community.general (for ufw, fail2ban modules)

## Integration with Common Security Hardening

This role is K3s-specific and focuses on:

- Raspberry Pi hardware considerations
- K3s network compatibility
- K3s-specific monitoring
- Less frequent monitoring (30min vs 15min for LXC)

The homelab.common.security_hardening role provides:

- Base system hardening
- General security policies
- CIS benchmark compliance
- Container security (LXC/Docker)

## K3s-Specific Considerations

### Firewall Rules

UFW configuration must allow:
- K3s API server (port 6443)
- Kubelet metrics (port 10250)
- Flannel VXLAN (port 8472 UDP)
- Etcd (ports 2379-2381 for HA)

### SSH Configuration

Enhanced for K3s management:
- Allows kubectl command execution
- Permits K3s log access
- Supports cluster administration tasks

### Fail2ban Configuration

Tuned for K3s environment:
- Monitors K3s API authentication
- Tracks kubectl access attempts
- Integrates with kubelet logs

### System Hardening

Compatible with K3s requirements:
- Preserves IP forwarding
- Maintains bridge networking
- Allows iptables modifications
- Supports CNI networking

## Monitoring

### Security Monitoring Script

Monitors:
- Failed SSH attempts
- Firewall blocks
- K3s service status
- System resource usage
- Security package updates
- Log anomalies

### Cron Schedule

```bash
# K3s security monitoring (every 30 minutes)
*/30 * * * * /usr/local/bin/k3s_security_monitor.sh
```

Less frequent than LXC containers (15min) due to:
- Raspberry Pi resource constraints
- Lower attack surface on cluster nodes
- Longer-running workloads

## Troubleshooting

### UFW Blocks K3s Traffic

```bash
# Check UFW status
sudo ufw status verbose

# Check K3s-specific rules
sudo ufw show added | grep 6443

# Verify K3s networking
kubectl get nodes
kubectl get pods -A
```

### SSH Access Issues

```bash
# Check SSH configuration
sudo sshd -t

# View SSH logs
journalctl -u ssh -f

# Verify SSH is running
systemctl status ssh
```

### Fail2ban Too Aggressive

```bash
# Check ban status
sudo fail2ban-client status sshd

# Unban IP if needed
sudo fail2ban-client set sshd unbanip <ip-address>

# Adjust ban time in configuration
```

### Automatic Updates Causing Issues

```bash
# Check unattended upgrades log
cat /var/log/unattended-upgrades/unattended-upgrades.log

# Disable temporarily
sudo systemctl stop unattended-upgrades

# Adjust configuration
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

## Security Best Practices

### Pre-Hardening

- **Backup Configuration** - Backup current configs before hardening
- **Test in Development** - Test hardening in non-production first
- **Document Baseline** - Document current security state
- **Plan Access** - Ensure alternative access methods available

### During Hardening

- **Monitor Impact** - Watch for service disruptions
- **Validate Access** - Verify SSH access after each change
- **Check K3s** - Ensure K3s cluster remains operational
- **Log Review** - Monitor logs for errors

### Post-Hardening

- **Security Scan** - Run security audit after hardening
- **Performance Check** - Verify acceptable performance impact
- **Functionality Test** - Test all K3s features
- **Documentation** - Document all changes made

## Performance Impact

- **UFW** - Minimal impact on network performance
- **Fail2ban** - Low CPU/memory overhead
- **SSH Hardening** - No performance impact
- **Logging** - Minimal I/O impact on Raspberry Pi
- **Monitoring** - Low resource usage (30min interval)
- **Automatic Updates** - Runs during low-activity periods

## Raspberry Pi Considerations

### Resource Constraints

- Monitoring less frequent to reduce load
- Logging configured for SD card longevity
- Updates scheduled for low-activity periods
- Fail2ban tuned for Pi memory limits

### Hardware-Specific

- rpi-update package for firmware updates
- Pi-specific kernel hardening
- SD card wear reduction strategies
- Temperature monitoring integration

### Network Performance

- UFW optimized for Pi networking
- Minimal iptables rule overhead
- CNI compatibility maintained
- Flannel VXLAN performance preserved

## Compliance and Standards

This role contributes to:

- **CIS Kubernetes Benchmark** - Cluster node security
- **CIS Raspberry Pi Security** - Pi-specific hardening
- **NIST Cybersecurity Framework** - Defense in depth
- **Kubernetes Security Best Practices** - Node hardening

## Comparison with LXC Security Hardening

### Similarities

- UFW firewall configuration
- SSH hardening
- Fail2ban protection
- Automatic updates
- System hardening

### Differences

- **Monitoring Frequency** - 30min (K3s) vs 15min (LXC)
- **Hardware Focus** - Raspberry Pi (K3s) vs containers (LXC)
- **Network Rules** - K3s-specific (6443, 8472) vs service-specific
- **Package Selection** - rpi-update included for K3s
- **Hardening Scope** - Cluster nodes vs container hosts

## Testing and Validation

### Security Validation

```bash
# Run security audit
ansible-playbook test-security-hardening.yml

# Check UFW rules
ansible k3s_cluster -b -m shell -a "ufw status verbose"

# Verify fail2ban
ansible k3s_cluster -b -m shell -a "fail2ban-client status"

# Check monitoring script
ansible k3s_cluster -b -m shell -a "/usr/local/bin/k3s_security_monitor.sh"
```

### K3s Functionality

```bash
# Verify cluster health
kubectl get nodes
kubectl get pods -A

# Test networking
kubectl run test --image=busybox --restart=Never -- ping -c 3 google.com

# Check metrics
kubectl top nodes
```

## Common Use Cases

### Standard K3s Cluster Hardening

```yaml
- hosts: k3s_cluster
  become: yes
  roles:
    - homelab.k3s.security_hardening
```

### High Security K3s Cluster

```yaml
- hosts: k3s_cluster
  become: yes
  vars:
    pi_security_hardening:
      ufw_enabled: true
      fail2ban:
        enabled: true
        ban_time: 7200
        max_retry: 2
      unattended_upgrades:
        enabled: true
        auto_reboot: true
      logging:
        rsyslog_enabled: true
  roles:
    - homelab.k3s.security_hardening
```

### Development Cluster (Relaxed Security)

```yaml
- hosts: dev_cluster
  become: yes
  vars:
    pi_security_hardening:
      ufw_enabled: false
      fail2ban:
        enabled: false
      unattended_upgrades:
        enabled: true
      logging:
        rsyslog_enabled: true
  roles:
    - homelab.k3s.security_hardening
```

## License

Apache License 2.0 - See collection LICENSE file for details.
