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

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PRODUCTION NETWORK (192.168.0.0/24)                 │
│  ┌─────────────┐  ┌──────────┐  ┌─────────┐  ┌──────────┐  ┌────────────┐  │
│  │ K3s Cluster │  │Prometheus│  │ Grafana │  │  Traefik │  │ NAS Svcs   │  │
│  │ .111-.114   │  │  .200    │  │  .201   │  │  .205    │  │ .230-.235  │  │
│  └─────────────┘  └──────────┘  └─────────┘  └──────────┘  └────────────┘  │
│         │               │             │            │              │          │
│         └───────────────┴─────────────┴────────────┴──────────────┘          │
│                                    │                                         │
│                                vmbr0 (Bridge)                                │
│                                    │                                         │
│  ┌──────────────────────────────────┴──────────────────────────────────┐    │
│  │                      INTERNET ACCESS                                 │    │
│  │                      ┌──────────────┐                                │    │
│  │                      │   Gateway    │                                │    │
│  │                      │ 192.168.0.1  │                                │    │
│  └──────────────────────┴──────────────┴────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ SSH from .110 (prod bastion)
                                    │ Strict firewall rules
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                       SECURE ENCLAVE - MANAGEMENT LAYER                     │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Enclave Bastion (192.168.0.250)                                     │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐ │  │
│  │  │  • SSH jump host (fail2ban: 3 attempts/10min)                   │ │  │
│  │  │  • Audit logging (90-day retention)                             │ │  │
│  │  │  • Monitoring dashboard (enclave-monitor)                       │ │  │
│  │  │  • Helper scripts (enclave-connect, enclave-shutdown)           │ │  │
│  │  │  • Security hardening (UFW, key-only auth)                      │ │  │
│  │  └─────────────────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                    │                                         │
│                                    │ Internal network                        │
│                                    ↓                                         │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Enclave Router (192.168.0.251 + 10.10.0.1)                          │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐ │  │
│  │  │  FIREWALL RULES (iptables):                                     │ │  │
│  │  │  ┌─ Priority 1: Allow DNS → 192.168.0.202:53                   │ │  │
│  │  │  ┌─ Priority 2-9: Block production IPs (.111-.114, .200-.235)  │ │  │
│  │  │  ┌─ Priority 10: Block all 192.168.0.0/24                      │ │  │
│  │  │  ┌─ Priority 11: Allow enclave internal 10.10.0.0/24           │ │  │
│  │  │  └─ Priority 12: Allow internet (NAT via vmbr0)                │ │  │
│  │  │                                                                 │ │  │
│  │  │  • Dual-homed (vmbr0 + vmbr1)                                  │ │  │
│  │  │  • IP forwarding enabled                                        │ │  │
│  │  │  • Unprivileged LXC with NET_ADMIN capability                  │ │  │
│  │  │  • Persistent firewall rules (systemd service)                 │ │  │
│  │  └─────────────────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ vmbr1 (Isolated Bridge, VLAN 10)
                                    │ COMPLETE ISOLATION FROM PRODUCTION
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ISOLATED PENTESTING NETWORK (10.10.0.0/24)               │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  Attacker VM (10.10.0.10) - Kali Linux 2024.3                      │    │
│  │  ┌───────────────────────────────────────────────────────────────┐ │    │
│  │  │  Tools: nmap, metasploit, burpsuite, sqlmap, nikto, wireshark│ │    │
│  │  │  Wordlists: SecLists, rockyou, dirb                          │ │    │
│  │  │  Scripts: PEASS, LinEnum, PayloadsAllTheThings               │ │    │
│  │  │  Resources: 4 cores, 4GB RAM, 50GB disk                      │ │    │
│  │  └───────────────────────────────────────────────────────────────┘ │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                           Attack Traffic ↓                                  │
│                                                                             │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌────────────────┐    │
│  │ DVWA (10.10.0.100)   │  │ Metasploitable3      │  │ Custom Targets │    │
│  │ ┌──────────────────┐ │  │ (10.10.0.101)        │  │ (10.10.0.102+) │    │
│  │ │ SQL injection    │ │  │ ┌──────────────────┐ │  │                │    │
│  │ │ XSS              │ │  │ │ Known CVEs       │ │  │ Your custom    │    │
│  │ │ Command injection│ │  │ │ Weak passwords   │ │  │ vulnerable     │    │
│  │ │ File upload      │ │  │ │ Misconfigurations│ │  │ applications   │    │
│  │ │ CSRF             │ │  │ └──────────────────┘ │  │                │    │
│  │ └──────────────────┘ │  │ Docker/VM based      │  │ Docker/VM/LXC  │    │
│  │ Web app (PHP/MySQL) │  │ Ubuntu 14.04         │  │ Flexible       │    │
│  └──────────────────────┘  └──────────────────────┘  └────────────────┘    │
│                                                                             │
│  Safety Features:                                                           │
│  • Auto-shutdown after 4h idle (cron-based monitoring)                      │
│  • Daily scheduled shutdown at 2 AM                                         │
│  • Emergency shutdown script (enclave-shutdown)                             │
│  • Resource limits (max 16 cores, 16GB RAM, 200GB disk)                     │
└─────────────────────────────────────────────────────────────────────────────┘

Network Traffic Flows:
═══════════════════════
  ✓ Isolated → Internet           : ALLOWED (NAT via router)
  ✓ Isolated → DNS (192.168.0.202): ALLOWED (UDP port 53 only)
  ✓ Isolated ↔ Isolated           : ALLOWED (internal traffic)
  ✓ Production → Bastion (.250)   : ALLOWED (SSH from .110 only)
  ✓ Bastion → Attacker            : ALLOWED (jump host access)

  ✗ Isolated → Production (.0-.254): BLOCKED (by firewall)
  ✗ Isolated → K3s (.111-.114)     : BLOCKED (explicit deny)
  ✗ Isolated → Monitoring (.200-)  : BLOCKED (explicit deny)
  ✗ Isolated → NAS (.230-.235)     : BLOCKED (explicit deny)
  ✗ Production → Isolated (direct) : BLOCKED (network isolation)

Security Boundaries:
════════════════════
  [Layer 1] Network Isolation:  vmbr1 bridge separate from production vmbr0
  [Layer 2] Firewall Rules:     iptables blocks on router container
  [Layer 3] Access Control:     Bastion jump host with fail2ban
  [Layer 4] Audit Logging:      All access logged, 90-day retention
  [Layer 5] Auto-Shutdown:      Time-based and idle-based VM shutdown
```

## Requirements

- Proxmox VE 7.0+
- Ansible 2.17+
- `community.general` collection
- `ansible.posix` collection
- Proxmox API token with appropriate permissions
- Available IP addresses in 192.168.0.250-254 range
- Storage for LXC containers and VMs

### Security Acknowledgement

Before deploying the secure enclave, you **must** acknowledge the security risks by setting:

```yaml
enclave_security_acknowledged: true
```

This can be set via:
- Extra vars: `-e enclave_security_acknowledged=true`
- Inventory: `group_vars/all.yml`
- Host vars: `host_vars/proxmox.yml`

This requirement exists because the enclave deploys components that may require elevated
privileges (network routing, firewall management). Review the security notice in
`defaults/main.yml` before proceeding.

## Installation

This role is part of the `homelab.proxmox_lxc` collection:

```bash
ansible-galaxy collection install homelab.proxmox_lxc
```

## Usage

### Basic Deployment

Deploy the entire secure enclave (requires security acknowledgement):

```bash
ansible-playbook playbooks/secure-enclave.yml -e enclave_security_acknowledged=true
```

### Selective Deployment

Deploy specific components using tags:

```bash
# Network isolation only
ansible-playbook playbooks/secure-enclave.yml --tags network,firewall -e enclave_security_acknowledged=true

# Bastion and infrastructure
ansible-playbook playbooks/secure-enclave.yml --tags infrastructure -e enclave_security_acknowledged=true

# Attacker VM only
ansible-playbook playbooks/secure-enclave.yml --tags attacker -e enclave_security_acknowledged=true

# Vulnerable targets only
ansible-playbook playbooks/secure-enclave.yml --tags vulnerable -e enclave_security_acknowledged=true
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

## Maintenance

### Quarterly Maintenance Tasks

The secure enclave requires periodic maintenance to ensure security and functionality:

#### 1. Update Kali Linux ISO (Quarterly)

Kali Linux releases new versions approximately quarterly. The ISO checksum in `defaults/main.yml` must be updated to match the latest release.

**Update Procedure:**

```bash
# 1. Check current Kali version
curl -s https://www.kali.org/get-kali/ | grep -o 'kali-linux-[0-9]\{4\}\.[0-9]'

# 2. Download new ISO (or just get checksum)
cd /var/lib/vz/template/iso/
wget https://cdimage.kali.org/kali-2024.4/kali-linux-2024.4-installer-amd64.iso

# 3. Calculate SHA256 checksum
sha256sum kali-linux-2024.4-installer-amd64.iso

# 4. Update defaults/main.yml
# Edit enclave_attacker.iso_url and enclave_attacker.iso_checksum
```

**Update Configuration:**

Edit `ansible_collections/homelab/proxmox_lxc/roles/secure_enclave/defaults/main.yml`:

```yaml
enclave_attacker:
  # ... other settings ...
  iso_url: "https://cdimage.kali.org/kali-2024.4/kali-linux-2024.4-installer-amd64.iso"
  iso_checksum: "sha256:NEW_CHECKSUM_HERE"
```

**Maintenance Schedule:**

| Task | Frequency | Last Updated | Next Due |
|------|-----------|--------------|----------|
| Kali ISO checksum | Quarterly (Jan, Apr, Jul, Oct) | YYYY-MM-DD | YYYY-MM-DD |
| Security patches | Monthly | Automated via unattended-upgrades | N/A |
| SSH key rotation | Annually | See SECRETS.md | YYYY-MM-DD |
| API token rotation | Quarterly (90 days) | See SECRETS.md | YYYY-MM-DD |
| Vulnerable VM updates | Quarterly | Manual | YYYY-MM-DD |

#### 2. Update Security Patches

Security patches are applied automatically via unattended-upgrades, but manual updates are recommended monthly:

```bash
# On bastion host
ssh pbs@192.168.0.250
sudo apt update && sudo apt upgrade -y

# On attacker VM
ssh root@10.10.0.10
apt update && apt upgrade -y
```

#### 3. Review and Rotate Credentials

Follow the rotation schedule in `SECRETS.md`:
- SSH keys: Annually
- Proxmox API tokens: Quarterly (90 days)
- Vault password: Every 180 days

#### 4. Audit Log Review

Review audit logs monthly for suspicious activity:

```bash
# Review last 30 days of audit logs
ssh pbs@192.168.0.250
sudo journalctl -u auditd --since "30 days ago"

# Check for failed login attempts
sudo grep "Failed password" /var/log/auth.log | tail -20

# Review enclave-specific logs
sudo tail -100 /var/log/enclave-audit.log
```

#### 5. Update Vulnerable VMs

Update vulnerable target VMs quarterly to latest versions:

```bash
# Update DVWA
ansible-playbook playbooks/secure-enclave.yml --tags vulnerable -e "update_vulnerable_vms=true"

# Or manually
ssh root@10.10.0.100
docker pull vulnerables/web-dvwa:latest
docker restart dvwa
```

### Automated Maintenance

Some maintenance tasks are automated:

- **Security patches**: unattended-upgrades (daily)
- **Log rotation**: logrotate (daily)
- **Auto-shutdown**: cron (configurable)
- **Audit log cleanup**: 30-day retention (automated)

### Maintenance Logs

Track maintenance activities in `/var/log/enclave-maintenance.log`:

```bash
# Log maintenance activity
echo "$(date): Updated Kali ISO to 2024.4" | sudo tee -a /var/log/enclave-maintenance.log
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

## Operational Runbook

### Common Operational Scenarios

#### Scenario 1: Daily Enclave Access

**Objective**: Access the enclave for security testing

**Steps**:
```bash
# 1. Connect to production bastion (from your workstation)
ssh pbs@192.168.0.110

# 2. Connect to enclave bastion
ssh pbs@192.168.0.250

# 3. Check enclave status
enclave-status

# 4. Connect to attacker VM
enclave-connect  # or ssh root@10.10.0.10

# 5. Verify network isolation
ping 192.168.0.200  # Should FAIL (Prometheus blocked)
ping 8.8.8.8        # Should SUCCEED (Internet allowed)
nmap -sn 10.10.0.0/24  # Discover targets
```

**Expected Results**:
- Production services unreachable from attacker VM
- Internet access working
- All vulnerable targets visible on 10.10.0.0/24

**Troubleshooting**:
- If can't connect to bastion: Check fail2ban status, verify SSH key
- If targets unreachable: Check VM status with `enclave-status`
- If internet blocked: Verify router firewall rules

---

#### Scenario 2: Adding a New Vulnerable Target

**Objective**: Deploy additional vulnerable VM to the enclave

**Steps**:
```bash
# 1. Edit role defaults
vim ansible_collections/homelab/proxmox_lxc/roles/secure_enclave/defaults/main.yml

# 2. Add new VM to enclave_vulnerable_vms list
enclave_vulnerable_vms:
  # ... existing VMs ...
  - name: juice-shop
    vm_id: 255
    hostname: juice-shop
    ip_address: 10.10.0.105
    description: "OWASP Juice Shop - Modern vulnerable web app"
    cores: 2
    memory_mb: 2048
    disk_size_gb: 20
    deployment_type: docker
    docker_image: bkimminich/juice-shop

# 3. Re-run deployment (only deploys new VM)
ansible-playbook playbooks/secure-enclave.yml --tags vulnerable

# 4. Verify deployment
ssh root@10.10.0.10
nmap -p- 10.10.0.105
curl http://10.10.0.105:3000
```

**Expected Results**:
- New VM deployed and accessible from attacker VM
- All existing VMs unaffected
- Network isolation maintained

**Rollback**:
```bash
# Remove VM manually if needed
pvesh delete /nodes/pve-mac/qemu/255
```

---

#### Scenario 3: Emergency Shutdown

**Objective**: Immediately shutdown all enclave VMs due to security incident or maintenance

**Steps**:
```bash
# Option 1: From enclave bastion (recommended)
ssh pbs@192.168.0.250
enclave-shutdown

# Option 2: From Proxmox host
ssh root@pve-mac
for vm in 250 251 252 253 254; do
  qm stop $vm &  # VMs
  pct stop $vm & # LXC containers
done
wait

# Option 3: Via playbook (graceful with cleanup)
ansible-playbook playbooks/teardown-secure-enclave.yml
```

**Expected Results**:
- All VMs/containers stopped within 60 seconds
- Audit logs preserved
- Network still isolated (router stopped)

**Recovery**:
```bash
# Restart all VMs
ssh root@pve-mac
for vm in 250 251 252 253 254; do
  qm start $vm &
  pct start $vm &
done
```

---

#### Scenario 4: Investigating Failed Login Attempts

**Objective**: Review and investigate suspicious failed login attempts

**Steps**:
```bash
# 1. Connect to enclave bastion
ssh pbs@192.168.0.250

# 2. Check fail2ban status
sudo fail2ban-client status enclave-sshd

# 3. View banned IPs
sudo fail2ban-client get enclave-sshd banip

# 4. Review auth logs for failed attempts
sudo grep "Failed password" /var/log/auth.log | tail -50

# 5. Check enclave audit log for correlation
sudo tail -100 /var/log/enclave-audit.log | grep -E "fail2ban|Banned"

# 6. Analyze patterns
sudo journalctl -u sshd --since "1 hour ago" | grep -i failed
```

**Expected Results**:
- Clear view of failed login attempts
- fail2ban automatically bans after 3 attempts
- Audit log contains ban events

**Remediation**:
```bash
# Unban IP if legitimate (e.g., forgotten password)
sudo fail2ban-client set enclave-sshd unbanip 192.168.0.110

# Permanently ban malicious IP
echo "sshd: 203.0.113.50" | sudo tee -a /etc/hosts.deny

# Rotate SSH keys if compromise suspected
./rotate-enclave-keys.sh  # See SECRETS.md
```

---

#### Scenario 5: Extending Auto-Shutdown Timeout

**Objective**: Extend idle timeout for long-running pentests

**Steps**:
```bash
# Option 1: Temporary extension (disable auto-shutdown)
ssh pbs@192.168.0.250
sudo crontab -l > /tmp/cron.backup
sudo crontab -r  # Remove all cron jobs temporarily
# Restore later: sudo crontab /tmp/cron.backup

# Option 2: Permanent configuration change
# Edit defaults/main.yml
enclave_auto_shutdown:
  enabled: true
  idle_timeout_hours: 8  # Changed from 4 to 8 hours
  shutdown_schedule: "0 4 * * *"  # Changed from 2 AM to 4 AM

# Re-deploy auto-shutdown configuration
ansible-playbook playbooks/secure-enclave.yml --tags auto-shutdown

# Option 3: One-time manual override
ssh pbs@192.168.0.250
# Touch a file to reset idle timer
for vm in 252 253 254; do
  ssh root@10.10.0.$((vm-252+10)) "date > /tmp/keepalive"
done
```

**Expected Results**:
- VMs remain running for extended period
- Auto-shutdown still occurs at scheduled time
- Manual control over shutdown timing

---

#### Scenario 6: Network Isolation Test Failure

**Objective**: Diagnose and fix network isolation test failures

**Symptoms**:
```
Test 3: Prometheus (192.168.0.200) - FAIL ✗ (should be blocked!)
# Attacker VM can reach production services (BAD!)
```

**Diagnosis Steps**:
```bash
# 1. Check firewall rules on router
ssh pbs@192.168.0.251
sudo iptables -L -n -v | grep enclave

# 2. Verify firewall initialization script
cat /usr/local/bin/enclave-firewall-init

# 3. Check if firewall service is running
sudo systemctl status enclave-firewall

# 4. Test connectivity from router itself
ping -c 1 192.168.0.200  # Should succeed (router on production network)

# 5. Test from isolated network (should fail)
ssh root@10.10.0.10
timeout 5 nc -zv 192.168.0.200 9090
```

**Fix**:
```bash
# Option 1: Reinitialize firewall rules
ssh pbs@192.168.0.251
sudo /usr/local/bin/enclave-firewall-init
sudo iptables -L -n -v | grep "Block Prometheus"  # Verify rule exists

# Option 2: Re-deploy network isolation
ansible-playbook playbooks/secure-enclave.yml --tags network,firewall

# Option 3: Manual rule addition (temporary)
sudo iptables -I FORWARD 1 -s 10.10.0.0/24 -d 192.168.0.200 -j DROP -m comment --comment "Block Prometheus"
```

**Verification**:
```bash
# Re-run isolation tests
ansible-playbook playbooks/test-enclave-isolation.yml

# Expected: All 6/6 tests pass
```

---

#### Scenario 7: Resource Limit Exceeded

**Objective**: Handle resource allocation failures

**Symptoms**:
```
ERROR: RESOURCE LIMIT EXCEEDED - MEMORY
Total memory requested: 18432MB
Maximum allowed: 16384MB
Exceeded by: 2048MB
```

**Resolution Steps**:
```bash
# Option 1: Reduce VM allocations
vim ansible_collections/homelab/proxmox_lxc/roles/secure_enclave/defaults/main.yml

# Reduce attacker VM from 4GB to 2GB
enclave_attacker:
  memory_mb: 2048  # Was 4096

# Reduce vulnerable VMs
enclave_vulnerable_vms:
  - name: dvwa
    memory_mb: 1024  # Was 2048

# Option 2: Increase resource limits (if hardware supports)
enclave_resource_limits:
  max_total_memory_mb: 20480  # Increased from 16384

# Option 3: Deploy fewer vulnerable VMs
# Comment out some VMs in defaults/main.yml temporarily

# Option 4: Check actual Proxmox capacity
ssh root@pve-mac
free -h  # Check available memory
df -h    # Check available disk
```

**Verification**:
```bash
# Re-run deployment with validation
ansible-playbook playbooks/secure-enclave.yml --tags validation
```

---

#### Scenario 8: Audit Log Full / Disk Space Issue

**Objective**: Handle audit log disk space issues

**Symptoms**:
```
/var/log/enclave-audit.log: No space left on device
```

**Resolution Steps**:
```bash
# 1. Check disk usage
ssh pbs@192.168.0.250
df -h /var/log
du -sh /var/log/enclave-audit.log*

# 2. Manually trigger log rotation
sudo logrotate -f /etc/logrotate.d/enclave-audit

# 3. Archive old logs to remote storage (if needed)
sudo tar -czf /tmp/enclave-logs-$(date +%F).tar.gz /var/log/enclave-audit.log.*
scp /tmp/enclave-logs-*.tar.gz admin@storage-server:/backups/
sudo rm /var/log/enclave-audit.log.*.gz

# 4. Adjust retention if needed (reduce from 90 to 60 days)
sudo vim /etc/logrotate.d/enclave-audit
# Change: rotate 60

# 5. Increase LXC container disk size
ssh root@pve-mac
pct resize 250 rootfs +5G  # Add 5GB to bastion container
```

**Prevention**:
```bash
# Set up monitoring alert for disk usage
# Add to monitoring.yml or create separate alert
```

---

### Quick Reference

#### Essential Commands

| Command | Description | Location |
|---------|-------------|----------|
| `enclave-status` | Check all VM/container status | Bastion |
| `enclave-connect` | SSH to attacker VM | Bastion |
| `enclave-monitor` | Real-time monitoring dashboard | Bastion |
| `enclave-shutdown` | Emergency shutdown all VMs | Bastion |
| `fail2ban-client status enclave-sshd` | Check SSH protection status | Bastion |
| `iptables -L -n -v \| grep enclave` | View firewall rules | Router |
| `tail -f /var/log/enclave-audit.log` | Monitor audit logs | Bastion |

#### Playbook Tags

| Tag | Purpose | Example |
|-----|---------|---------|
| `network,firewall` | Deploy only network isolation | `--tags network,firewall` |
| `infrastructure` | Deploy bastion and router | `--tags infrastructure` |
| `attacker` | Deploy only attacker VM | `--tags attacker` |
| `vulnerable` | Deploy only target VMs | `--tags vulnerable` |
| `monitoring` | Deploy only monitoring/audit | `--tags monitoring` |
| `validation` | Run validation checks | `--tags validation` |

#### Log Locations

| Log File | Purpose | Retention |
|----------|---------|-----------|
| `/var/log/enclave-audit.log` | All enclave activity | 90 days |
| `/var/log/enclave-auto-shutdown.log` | Auto-shutdown events | 7 days |
| `/var/log/auth.log` | SSH authentication | 30 days |
| `/var/log/fail2ban.log` | fail2ban actions | 30 days |

## License

MIT

## Author

Created for the homelab infrastructure collection.

## References

- [OWASP DVWA](https://github.com/digininja/DVWA)
- [Metasploitable3](https://github.com/rapid7/metasploitable3)
- [Kali Linux](https://www.kali.org/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
