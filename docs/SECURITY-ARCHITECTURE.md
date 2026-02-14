# Security Architecture Documentation

Comprehensive security architecture documentation for the homelab infrastructure, covering defense-in-depth strategies, network segmentation, authentication, and threat modeling.

## Table of Contents

1. [Security Overview](#security-overview)
2. [Defense-in-Depth Model](#defense-in-depth-model)
3. [Network Architecture](#network-architecture)
4. [Authentication and Access Control](#authentication-and-access-control)
5. [Threat Model](#threat-model)
6. [Security Controls](#security-controls)
7. [Secure Enclave Architecture](#secure-enclave-architecture)
8. [Certificate Management](#certificate-management)
9. [Container Security](#container-security)
10. [Monitoring and Auditing](#monitoring-and-auditing)
11. [Compliance Considerations](#compliance-considerations)

---

## Security Overview

The homelab infrastructure implements a multi-layered security approach designed to protect against both external and internal threats while maintaining operational flexibility for legitimate access.

### Security Principles

- **Defense in Depth**: Multiple security layers that don't depend on any single control
- **Least Privilege**: Users and services have minimum required permissions
- **Zero Trust**: Verify explicitly, use least privileged access, assume breach
- **Separation of Concerns**: Critical services isolated from general workloads
- **Security by Default**: Secure configurations applied automatically

### Key Security Components

| Component | Purpose | IP Address |
|-----------|---------|------------|
| Bastion Hosts | Secure SSH jump points | 192.168.0.109-110 |
| WireGuard VPN | Encrypted remote access | 192.168.0.203 |
| Traefik | TLS termination and reverse proxy | 192.168.0.205 |
| AdGuard Home | DNS filtering and security | 192.168.0.204 |
| Unbound | Recursive DNS with DNSSEC | 192.168.0.202 |
| Secure Enclave | Isolated pentesting environment | 10.10.0.0/24 |

---

## Defense-in-Depth Model

### Layer 1: Network Perimeter

```
┌──────────────────────────────────────────────────────────────┐
│                        INTERNET                               │
└──────────────────────────┬───────────────────────────────────┘
                           │
                    ┌──────┴──────┐
                    │   Firewall  │
                    │  (Router)   │
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              │                         │
        ┌─────┴─────┐            ┌──────┴──────┐
        │ WireGuard │            │   Traefik   │
        │   VPN     │            │ (HTTPS/443) │
        │ UDP:51820 │            └─────────────┘
        └───────────┘
```

**Controls:**
- Firewall blocks all inbound except VPN (51820/UDP) and HTTPS (443)
- WireGuard provides encrypted tunnel for administrative access
- Traefik handles TLS termination for web services
- No direct SSH exposure to internet

### Layer 2: Bastion Architecture

All administrative access must traverse bastion hosts:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────┐
│   Admin     │────▶│   Bastion   │────▶│  Target Host    │
│   Device    │ SSH │   Host      │ SSH │  (LXC/K3s/etc)  │
└─────────────┘     └─────────────┘     └─────────────────┘
                          │
                    Security Controls:
                    - SSH key auth only
                    - Session logging
                    - Rate limiting
                    - Fail2ban
```

**Bastion Hosts:**
- **k3s-bastion** (192.168.0.110): Primary bastion for K3s and core services
- **nas-bastion** (192.168.0.109): Bastion for NAS and media services

### Layer 3: Network Segmentation

Services grouped by security requirements:

| Segment | CIDR | Purpose | Security Level |
|---------|------|---------|----------------|
| Core Services | 192.168.0.200-210 | Monitoring, DNS, proxy | High |
| K3s Cluster | 192.168.0.111-114 | Kubernetes workloads | High |
| NAS Services | 192.168.0.230-240 | Media, storage | Medium |
| Secure Enclave | 10.10.0.0/24 | Pentesting (isolated) | Air-gapped |

### Layer 4: Application Security

- All services behind Traefik reverse proxy
- TLS everywhere (Let's Encrypt certificates)
- Service-specific authentication
- Rate limiting on public endpoints

### Layer 5: Data Security

- Ansible Vault for secrets management
- No plaintext credentials in configuration
- Encrypted backups
- Audit logging

---

## Network Architecture

### Production Network (192.168.0.0/24)

```
                    ┌─────────────────────────────────────────────────┐
                    │           Production Network                     │
                    │              192.168.0.0/24                       │
                    │                                                   │
  ┌─────────────────┼─────────────────────────────────────────────────┼────────────────┐
  │                 │                                                   │                │
  │  ┌──────────────┴──────────────┐   ┌───────────────────────────────┴──────────┐    │
  │  │     Security Segment         │   │          Service Segment                  │    │
  │  │                              │   │                                           │    │
  │  │  Bastion-1   192.168.0.110  │   │  Prometheus    192.168.0.200             │    │
  │  │  Bastion-2   192.168.0.109  │   │  Grafana       192.168.0.201             │    │
  │  │  Unbound     192.168.0.202  │   │  WireGuard     192.168.0.203             │    │
  │  │  AdGuard     192.168.0.204  │   │  Traefik       192.168.0.205             │    │
  │  │  Enclave-B   192.168.0.250  │   │  AlertManager  192.168.0.206             │    │
  │  └──────────────────────────────┘   │  Home Asst.   192.168.0.208             │    │
  │                                     │  Loki         192.168.0.210             │    │
  │  ┌──────────────────────────────┐   └─────────────────────────────────────────┘    │
  │  │      K3s Cluster              │                                                  │
  │  │                              │   ┌─────────────────────────────────────────┐    │
  │  │  k3-01 (server) 192.168.0.111│   │          NAS Services                    │    │
  │  │  k3-02 (agent)  192.168.0.112│   │                                          │    │
  │  │  k3-03 (agent)  192.168.0.113│   │  Sonarr       192.168.0.230             │    │
  │  │  k3-04 (agent)  192.168.0.114│   │  Radarr       192.168.0.231             │    │
  │  └──────────────────────────────┘   │  Bazarr       192.168.0.232             │    │
  │                                     │  Prowlarr     192.168.0.233             │    │
  │                                     │  qBittorrent  192.168.0.234             │    │
  │                                     │  Jellyfin     192.168.0.235             │    │
  │                                     └─────────────────────────────────────────┘    │
  └────────────────────────────────────────────────────────────────────────────────────┘
```

### Secure Enclave Network (10.10.0.0/24)

Completely isolated network for security testing:

```
  ┌────────────────────────────────────────────────────────────────────┐
  │                    SECURE ENCLAVE (Isolated)                        │
  │                       10.10.0.0/24                                  │
  │                                                                     │
  │   ┌──────────────────────────────────────────────────────────────┐ │
  │   │  Production Access (Restricted)                               │ │
  │   │                                                               │ │
  │   │  Enclave Bastion  192.168.0.250 ──┐                          │ │
  │   │  Enclave Router   192.168.0.251 ──┼── Dual-homed             │ │
  │   └───────────────────────────────────┼──────────────────────────┘ │
  │                                       │                            │
  │   ┌───────────────────────────────────┴──────────────────────────┐ │
  │   │  Isolated Network (No production access)                      │ │
  │   │                                                               │ │
  │   │  Router Gateway   10.10.0.1                                   │ │
  │   │  Kali Attacker    10.10.0.10                                  │ │
  │   │  DVWA Target      10.10.0.100                                 │ │
  │   │  Metasploitable   10.10.0.101                                 │ │
  │   │                                                               │ │
  │   │  ⛔ BLOCKED: All traffic to 192.168.0.0/24                   │ │
  │   │  ✅ ALLOWED: Internet access for updates                      │ │
  │   └───────────────────────────────────────────────────────────────┘ │
  └────────────────────────────────────────────────────────────────────┘
```

### Firewall Rules Summary

| Source | Destination | Ports | Action | Purpose |
|--------|-------------|-------|--------|---------|
| Internet | VPN Server | 51820/UDP | Allow | WireGuard access |
| Internet | Traefik | 80, 443 | Allow | Web services |
| VPN Clients | Production | All | Allow | Admin access |
| Bastion | All hosts | 22 | Allow | SSH management |
| Enclave | Production | All | **Deny** | Isolation |
| Enclave | Internet | All | Allow | Updates only |

---

## Authentication and Access Control

### SSH Authentication

**Configuration applied by `security_hardening` role:**

```yaml
# SSH daemon settings
ssh_config:
  port: 22
  permit_root_login: "prohibit-password"
  password_authentication: false
  pubkey_authentication: true
  max_auth_tries: 3
  login_grace_time: 30
  client_alive_interval: 300
  client_alive_count_max: 2
```

**Key Requirements:**
- SSH key-based authentication only
- No password authentication
- Root login only via SSH key
- Session timeout after inactivity

### VPN Authentication

WireGuard uses cryptographic keys:
- Each client has unique public/private key pair
- Preshared keys for additional security
- No usernames/passwords (purely cryptographic)

### API Token Authentication

**Proxmox API:**
```yaml
# Token structure
vault_proxmox_api_tokens:
  pve_mac:
    token_id: "automation@pve!ansible"
    token_secret: "<secret>"
  pve_nas:
    token_id: "automation@pve!ansible"
    token_secret: "<secret>"
```

**Required Privileges:**
- VM.Allocate
- VM.Config.*
- VM.Console
- VM.PowerMgmt
- Datastore.AllocateSpace
- Sys.Audit

### Service Authentication

| Service | Authentication Method | Notes |
|---------|----------------------|-------|
| Grafana | Username/password, API key | Admin password in vault |
| Home Assistant | Long-lived access tokens | Created via UI |
| AdGuard Home | Basic auth | Min 12 char password |
| Prometheus | Via Traefik basic auth | Internal access unauthenticated |
| Traefik Dashboard | Basic auth | Optional |

---

## Threat Model

### STRIDE Analysis

#### Spoofing

| Threat | Mitigation |
|--------|------------|
| Impersonating admin | SSH key authentication, VPN cryptographic auth |
| Fake DNS responses | DNSSEC via Unbound, internal DNS servers |
| Rogue services | TLS certificates validate service identity |

#### Tampering

| Threat | Mitigation |
|--------|------------|
| Config modification | Ansible for declarative config, Git tracking |
| Network traffic modification | TLS everywhere, VPN encryption |
| Container escape | Unprivileged containers, AppArmor profiles |

#### Repudiation

| Threat | Mitigation |
|--------|------------|
| Denying admin actions | Centralized logging (Loki), audit trails |
| Unauthorized changes | Git history for all configuration |
| Access denial | SSH session logging, VPN logs |

#### Information Disclosure

| Threat | Mitigation |
|--------|------------|
| Credential exposure | Ansible Vault encryption |
| Network sniffing | TLS, VPN encryption |
| Log leakage | Restricted log access, retention policies |

#### Denial of Service

| Threat | Mitigation |
|--------|------------|
| Service flooding | Rate limiting via Traefik |
| Resource exhaustion | Container resource limits |
| Network flooding | Firewall rules, fail2ban |

#### Elevation of Privilege

| Threat | Mitigation |
|--------|------------|
| Container breakout | Unprivileged containers |
| SSH key compromise | Key rotation, bastion isolation |
| Lateral movement | Network segmentation, least privilege |

### Attack Surface

**External Attack Surface:**
- WireGuard VPN (UDP 51820) - Minimal, cryptographic
- HTTPS (443) via Traefik - Web services only

**Internal Attack Surface:**
- Service APIs (authenticated)
- Container inter-communication
- Proxmox management interfaces

---

## Security Controls

### Automated Security Hardening

The `security_hardening` role applies:

```yaml
security_controls:
  # System hardening
  - Disable unnecessary services
  - Configure secure kernel parameters
  - Set file permissions
  - Configure firewall rules

  # SSH hardening
  - Key-only authentication
  - Restricted ciphers/MACs
  - Session timeouts

  # Audit logging
  - Enable auditd
  - Log authentication events
  - Monitor file changes
```

### Secrets Management

**Ansible Vault Structure:**
```
inventory/group_vars/
├── vault.yml              # Encrypted secrets
└── vault.yml.example      # Template (no secrets)
```

**Required Vault Variables:**
```yaml
# Proxmox API
vault_proxmox_api_tokens:
  pve_mac:
    token_id: "..."
    token_secret: "..."

# Service passwords
vault_grafana_admin_password: "..."
vault_grafana_secret_key: "..."
vault_adguard_admin_password: "..."
vault_wireguard_server_private_key: "..."
vault_ssl_email: "..."
```

### CI/CD Security

- **Secret Scanning**: TruffleHog OSS for credential detection
- **Security Linting**: ansible-lint with security profile
- **Dependency Scanning**: OWASP Dependency Check
- **Static Analysis**: CodeQL for security issues

---

## Secure Enclave Architecture

The secure enclave provides an isolated environment for security testing and training.

### Design Principles

1. **Complete Isolation**: No network path to production
2. **Controlled Access**: Only via enclave bastion
3. **Audit Trail**: All access logged
4. **Auto-Shutdown**: Temporary mode shuts down after 4h idle
5. **Explicit Acknowledgement**: Requires security acknowledgement flag

### Network Isolation

```yaml
# Firewall rules on enclave router
enclave_firewall_rules:
  # BLOCK all production access
  - iptables -A FORWARD -s 10.10.0.0/24 -d 192.168.0.0/24 -j DROP
  - iptables -A FORWARD -s 10.10.0.0/24 -d 10.42.0.0/16 -j DROP
  - iptables -A FORWARD -s 10.10.0.0/24 -d 10.43.0.0/16 -j DROP

  # ALLOW internet (for updates/tools)
  - iptables -A FORWARD -s 10.10.0.0/24 -j ACCEPT
```

### Deployment Modes

**Temporary Mode (Default):**
```bash
# Auto-shutdown after 4h idle, doesn't start on boot
ansible-playbook playbooks/enclave.yml \
  -e enclave_security_acknowledged=true
```

**Persistent Mode:**
```bash
# Runs continuously, starts on boot
ansible-playbook playbooks/enclave.yml \
  -e enclave_security_acknowledged=true \
  -e enclave_persistent_mode=true
```

### Enclave Components

| Component | IP | Purpose |
|-----------|-------|---------|
| Enclave Bastion | 192.168.0.250 | Jump host for enclave access |
| Enclave Router | 192.168.0.251 / 10.10.0.1 | Firewall, network isolation |
| Kali Attacker | 10.10.0.10 | Security testing workstation |
| DVWA | 10.10.0.100 | Web application testing target |
| Metasploitable | 10.10.0.101 | System exploitation target |

---

## Certificate Management

### TLS Certificate Strategy

Traefik handles all certificate management using Let's Encrypt:

```yaml
# Traefik configuration
traefik_acme:
  email: "{{ vault_ssl_email }}"
  storage: /etc/traefik/acme.json
  challenge: http  # or dns for wildcard
```

### Certificate Scope

| Domain Pattern | Certificate Type | Notes |
|----------------|------------------|-------|
| *.homelab.local | Internal CA | For internal services |
| service.domain.com | Let's Encrypt | For external access |

### Internal TLS

For internal services not exposed externally:
- Self-signed certificates
- Internal CA (optional)
- mTLS between services (future enhancement)

---

## Proxmox Firewall Architecture

The Proxmox firewall operates at three independent levels. Understanding this hierarchy is
essential for correctly configuring network access for VMs and LXC containers.

### Three-Level Firewall Hierarchy

```
Level 1: Cluster (/etc/pve/firewall/cluster.fw)
  - Defines cluster-wide options (default policies, enable/disable)
  - Defines reusable security groups
  - [RULES] section applies to Proxmox HOST traffic only

Level 2: Host (/etc/pve/nodes/<node>/host.fw)
  - Per-node firewall rules
  - Supplements cluster-level host rules

Level 3: VM/CT (/etc/pve/firewall/<vmid>.fw)
  - Per-VM/container firewall rules
  - References security groups defined in cluster.fw
  - This is the ONLY level that filters VM/CT traffic
```

### Security Groups

Security groups are defined in `cluster.fw` and can be referenced from any VM/CT firewall config.

| Group | Rules | Applied By Default |
|-------|-------|--------------------|
| `basic-network` | DHCP, DNS (UDP+TCP), ICMP | Yes (via Ansible) |
| `allow-ssh` | SSH from LAN (192.168.0.0/24) | Yes (via Ansible) |
| `allow-web` | HTTP (80), HTTPS (443) | No (opt-in) |

### How Firewall Rules Are Applied

**Ansible-provisioned containers** (`container_base` role):
- The role automatically deploys `/etc/pve/firewall/<vmid>.fw` with `basic-network` and
  `allow-ssh` groups, plus a blanket LAN access rule
- Controlled by `container_firewall_groups` and `container_firewall_extra_rules` variables
- Bastion hosts have `container_network.firewall: false` and manage their own iptables

**VMs/CTs created via the Proxmox web UI** require manual firewall configuration:

1. Go to **Datacenter > Firewall > Security Group** to verify groups exist
2. Select the VM/CT > **Firewall > Insert: Security Group**
3. Add `basic-network` (for DHCP/DNS/ICMP)
4. Add `allow-ssh` if SSH access is needed
5. Add `allow-web` if the VM serves HTTP/HTTPS
6. Optionally add custom rules for service-specific ports

Alternatively, create a per-VM firewall file directly:

```bash
# SSH to a Proxmox host and create the firewall config
cat > /etc/pve/firewall/<vmid>.fw << 'EOF'
[OPTIONS]
enable: 1

[RULES]
GROUP basic-network
GROUP allow-ssh
IN ACCEPT -source 192.168.0.0/24 -log nolog # Allow LAN traffic
EOF
```

### Customizing Per-Container Firewall Rules

Override the defaults in your inventory to add security groups or rules per container:

```yaml
# inventory/host_vars/traefik-lxc.yml
container_firewall_groups:
  - basic-network
  - allow-ssh
  - allow-web

container_firewall_extra_rules:
  - "IN ACCEPT -source 192.168.0.0/24 -log nolog # Allow LAN traffic"
  - "IN ACCEPT -p tcp -dport 8080 -log nolog # Traefik dashboard"
```

### Why Cluster [RULES] Don't Protect VMs

A common misconception: adding `GROUP basic-network` to the `[RULES]` section of `cluster.fw`
does **not** apply those rules to VMs/CTs. Cluster-level `[RULES]` only filter traffic
destined to the Proxmox hosts themselves. Each VM/CT with `firewall=1` on its NIC has a
separate firewall chain that only evaluates:

1. Connection tracking (ESTABLISHED/RELATED traffic is always accepted)
2. Rules from `/etc/pve/firewall/<vmid>.fw`
3. The default `policy_in` (inherited from cluster: DROP)

Without a per-VM firewall file, new VMs default to DROP all inbound except return traffic.

---

## Container Security

### LXC Container Hardening

**Default Security Settings:**
```yaml
container_defaults:
  unprivileged: true      # Non-root user namespace
  onboot: true            # Controlled startup
  swap: 0                 # No swap (prevent disclosure)
```

**Per-Container Security:**
- Resource limits (CPU, memory, disk)
- Network isolation (no inter-container by default)
- Read-only root filesystem (where possible)
- No privileged operations

### Kubernetes Security (K3s)

- Pod Security Standards: restricted
- Network Policies: default deny
- RBAC: least privilege
- Audit logging enabled

---

## Monitoring and Auditing

### Security Monitoring Stack

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Promtail   │───▶│     Loki     │───▶│   Grafana    │
│  (Log agent) │    │ (Log storage)│    │ (Dashboards) │
└──────────────┘    └──────────────┘    └──────────────┘
                           │
                    Security Dashboards:
                    - Authentication failures
                    - SSH access logs
                    - Container events
                    - Network anomalies
```

### Audit Logging

**Logged Events:**
- SSH authentication (success/failure)
- Sudo usage
- Service restarts
- Configuration changes
- Container lifecycle events

**Retention:**
```yaml
security_config:
  audit_enabled: true
  log_retention_days: 30
```

### Alerting

AlertManager routes security alerts:
- Failed authentication attempts
- Service down events
- Resource exhaustion
- Enclave access events

---

## Compliance Considerations

### Security Standards Alignment

The infrastructure aligns with:

| Standard | Coverage | Notes |
|----------|----------|-------|
| CIS Benchmarks | Partial | Container and K8s hardening |
| NIST Cybersecurity | Core | Identity, Protect, Detect, Respond |
| OWASP | Web services | Secure headers, input validation |

### Security Checklist

Before production deployment:

- [ ] All vault variables configured
- [ ] SSH keys unique per user
- [ ] Default passwords changed
- [ ] Firewall rules reviewed
- [ ] SSL certificates valid
- [ ] Monitoring enabled
- [ ] Security hardening applied
- [ ] Backup strategy implemented
- [ ] Incident response plan documented

---

## Quick Reference

### Security Contact

Report security issues via `.github/SECURITY.md`

### Emergency Procedures

**Suspected Breach:**
1. Isolate affected systems (stop containers/VMs)
2. Preserve logs
3. Rotate all credentials
4. Review access logs
5. Document findings

**Enclave Emergency Shutdown:**
```bash
make enclave-shutdown
# Or manually:
ansible-playbook playbooks/enclave.yml --tags shutdown
```

### Related Documentation

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Issue resolution
- [API.md](API.md) - API authentication details
- [CLIENT-VPN-SETUP.md](CLIENT-VPN-SETUP.md) - VPN client configuration
- [INSTALLATION.md](INSTALLATION.md) - Initial setup

---

**Last Updated:** 2026-02-01
**Version:** 1.0.0
