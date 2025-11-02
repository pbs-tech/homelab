# Secure Enclave Role

An Ansible role for deploying an isolated pentesting and security research environment in Proxmox. This role creates a network-isolated enclave with vulnerable VMs for authorized security testing, training, and experimentation.

## Overview

The Secure Enclave provides a safe, isolated environment for:
- Penetration testing practice
- Security research and experimentation
- Vulnerability assessment training
- Security tool testing
- CTF (Capture The Flag) competitions

## Features

### Network Isolation
- **Dedicated network segment** (10.10.0.0/24) isolated from production infrastructure
- **Firewall rules** blocking all traffic to production services (K3s cluster, monitoring, NAS)
- **NAT gateway** for internet access (updates, tool downloads)
- **DNS access** allowed only to internal Unbound server
- **Dual-homed bastion** for secure access from production network

### Security Features
- **Audit logging** - All access and activity logged
- **Network monitoring** - Traffic analysis and intrusion detection
- **Auto-shutdown** - Vulnerable VMs automatically shutdown when idle (default: 4 hours)
- **Scheduled shutdown** - Daily shutdown schedule (default: 2 AM)
- **Access control** - SSH key-based authentication only
- **Bastion architecture** - All access through secured jump host

### Components Deployed

1. **Enclave Bastion** (192.168.0.250)
   - Secured jump host for accessing the enclave
   - Security hardening applied
   - Monitoring and audit logging
   - Helper scripts for enclave management

2. **Enclave Router** (192.168.0.251)
   - Network isolation and firewall
   - NAT gateway for internet access
   - Traffic routing between networks
   - Connection tracking

3. **Attacker VM** (10.10.0.10)
   - Kali Linux-based pentesting workstation
   - Pre-installed security tools (nmap, metasploit, burp, sqlmap, etc.)
   - Useful wordlists and scripts (SecLists, PEASS, PayloadsAllTheThings)
   - Dual-homed: management + isolated network

4. **Vulnerable Targets**
   - DVWA (10.10.0.100) - Damn Vulnerable Web Application
   - Metasploitable3 (10.10.0.101) - Intentionally vulnerable VM
   - Easily extensible for additional targets

## Network Architecture

```
Production Network (192.168.0.0/24)
    |
    | (SSH only from 192.168.0.110)
    |
    v
Enclave Bastion (192.168.0.250) <-- Access Point
    |
    |
    v
Enclave Router (192.168.0.251)
    |
    | Firewall + NAT
    |
    v
Isolated Network (10.10.0.0/24)
    |
    +-- Attacker VM (10.10.0.10) - Kali Linux
    +-- DVWA (10.10.0.100)
    +-- Metasploitable3 (10.10.0.101)
    +-- [Additional targets...]

Firewall Rules:
  ✓ Allow: Isolated -> Internet (for updates)
  ✓ Allow: Isolated -> DNS (192.168.0.202)
  ✗ Block: Isolated -> Production Services
  ✗ Block: Isolated -> K3s Cluster
  ✗ Block: Isolated -> NAS Services
```

## Requirements

- Proxmox VE 7.0+
- Ansible 2.17+
- `community.general` collection
- `ansible.posix` collection
- Proxmox API token with appropriate permissions
- Available IP addresses in 192.168.0.250-254 range
- Storage for LXC containers and VMs

## Installation

This role is part of the `homelab.proxmox_lxc` collection:

```bash
ansible-galaxy collection install homelab.proxmox_lxc
```

## Usage

### Basic Deployment

Deploy the entire secure enclave:

```bash
ansible-playbook playbooks/secure-enclave.yml
```

### Selective Deployment

Deploy specific components using tags:

```bash
# Network isolation only
ansible-playbook playbooks/secure-enclave.yml --tags network,firewall

# Bastion and infrastructure
ansible-playbook playbooks/secure-enclave.yml --tags infrastructure

# Attacker VM only
ansible-playbook playbooks/secure-enclave.yml --tags attacker

# Vulnerable targets only
ansible-playbook playbooks/secure-enclave.yml --tags vulnerable
```

### Accessing the Enclave

1. **SSH to bastion from production bastion:**
   ```bash
   ssh pbs@192.168.0.250
   ```

2. **Check enclave status:**
   ```bash
   enclave-status
   ```

3. **Connect to attacker VM:**
   ```bash
   enclave-connect 10.10.0.10
   ```

4. **Scan vulnerable targets:**
   ```bash
   nmap -sV -sC 10.10.0.0/24
   ```

### Management Commands

Available on the enclave bastion:

- `enclave-status` - Display enclave network and VM status
- `enclave-connect [IP]` - SSH to enclave VMs (default: attacker VM)
- `enclave-shutdown` - Emergency shutdown of all enclave VMs
- `enclave-monitor` - Real-time monitoring dashboard
- `router-status` - Display router and firewall status (on router VM)

## Configuration

### Default Variables

Key variables that can be customized (see `defaults/main.yml`):

```yaml
# Network configuration
enclave_network:
  isolated_subnet: 10.10.0.0/24
  management_subnet: 192.168.0.250/29

# Auto-shutdown configuration
enclave_auto_shutdown:
  enabled: true
  idle_timeout_hours: 4
  shutdown_schedule: "0 2 * * *"  # 2 AM daily

# Monitoring
enclave_monitoring:
  enabled: true
  audit_logging: true
  metrics_enabled: true
```

### Adding Vulnerable VMs

Add entries to `enclave_vulnerable_vms` list:

```yaml
enclave_vulnerable_vms:
  - name: my-target
    vm_id: 255
    hostname: my-vulnerable-app
    ip_address: 10.10.0.102
    description: "My custom vulnerable application"
    cores: 2
    memory: 2048
    disk_size: 20
    deployment_type: docker
    docker_image: myorg/vulnerable-app
```

### Custom Pentesting Tools

Add tools to `enclave_pentesting_tools` list:

```yaml
enclave_pentesting_tools:
  - nmap
  - metasploit-framework
  - your-custom-tool
```

## Security Considerations

### Authorization
- **Only use for authorized security testing** - Never attack systems without permission
- **Educational use only** - For learning and improving security skills
- **Compliance** - Ensure compliance with organizational policies and legal requirements

### Network Isolation
- All traffic from enclave to production is **BLOCKED** by firewall
- Internet access is allowed for tool updates and downloads
- DNS queries allowed only to internal DNS server
- No lateral movement to production infrastructure possible

### Monitoring and Auditing
- All SSH access is logged via auditd
- Network connections are monitored and logged
- System commands are audited
- Logs available at `/var/log/enclave-audit.log`

### Auto-Shutdown
- Vulnerable VMs automatically shutdown after 4 hours idle (configurable)
- Daily scheduled shutdown at 2 AM (configurable)
- Manual emergency shutdown available via `enclave-shutdown`

## Testing

### Verify Network Isolation

From attacker VM (10.10.0.10):

```bash
# Should FAIL - blocked by firewall
ping 192.168.0.200  # Prometheus
curl http://192.168.0.201  # Grafana
ssh 192.168.0.111  # K3s node

# Should SUCCEED - allowed by firewall
ping 8.8.8.8  # Internet
nslookup google.com  # DNS
ping 10.10.0.100  # Internal enclave
```

### Verify Monitoring

On enclave bastion:

```bash
# View real-time monitoring
enclave-monitor

# Check audit logs
tail -f /var/log/enclave-audit.log

# View auto-shutdown logs
tail -f /var/log/enclave-auto-shutdown.log
```

## Troubleshooting

### VMs Not Starting

Check Proxmox resources:
```bash
pvesh get /nodes/pve-mac/status
```

### Network Connectivity Issues

Check firewall rules on Proxmox host:
```bash
iptables -L -n -v | grep enclave
```

Check routing on enclave router:
```bash
ssh 192.168.0.251
router-status
```

### Auto-Shutdown Not Working

Check cron jobs on bastion:
```bash
crontab -l
tail -f /var/log/enclave-auto-shutdown.log
```

## Molecule Testing

Test the role with Molecule:

```bash
cd ansible_collections/homelab/proxmox_lxc
molecule test -s secure-enclave
```

## Examples

### Basic Pentesting Workflow

1. **Access enclave:**
   ```bash
   ssh pbs@192.168.0.250  # Bastion
   enclave-connect        # Attacker VM
   ```

2. **Discover targets:**
   ```bash
   nmap -sn 10.10.0.0/24
   nmap -sV -sC 10.10.0.100
   ```

3. **Test DVWA:**
   ```bash
   firefox http://10.10.0.100 &
   sqlmap -u "http://10.10.0.100/vulnerabilities/sqli/?id=1&Submit=Submit" --cookie="security=low; PHPSESSID=xxx"
   ```

4. **Cleanup:**
   ```bash
   exit  # Leave attacker VM
   enclave-shutdown  # Shutdown all VMs
   ```

### CTF Competition Setup

Deploy additional vulnerable VMs for CTF:

```yaml
enclave_vulnerable_vms:
  - name: ctf-web
    vm_id: 256
    hostname: ctf-web-challenge
    ip_address: 10.10.0.110
    description: "CTF Web Challenge"
    deployment_type: docker
    docker_image: myctf/web-challenge

  - name: ctf-pwn
    vm_id: 257
    hostname: ctf-pwn-challenge
    ip_address: 10.10.0.111
    description: "CTF Binary Exploitation Challenge"
    deployment_type: docker
    docker_image: myctf/pwn-challenge
```

## License

MIT

## Author

Created for the homelab infrastructure collection.

## References

- [OWASP DVWA](https://github.com/digininja/DVWA)
- [Metasploitable3](https://github.com/rapid7/metasploitable3)
- [Kali Linux](https://www.kali.org/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
