# Homelab Security Architecture

## Network Security Zones

### Zone 1: Management (192.168.0.110)
- **k3s-bastion** (192.168.0.110) - Secured Ansible control node
- Purpose: All infrastructure automation and management
- Security: Fail2ban, UFW, key-based SSH only, unprivileged LXC

### Zone 2: DNS Security Layer (192.168.0.202-204)
- **Unbound** (192.168.0.202) - Recursive DNS resolver (upstream)
- **AdGuard Home** (192.168.0.204) - DNS filtering and blocking (downstream)
- **Chain**: Clients → AdGuard → Unbound → Internet
- Security: DNS over HTTPS/TLS, malware blocking, ad blocking

### Zone 3: VPN Access (192.168.0.203)
- **WireGuard** (192.168.0.203) - Secure remote access
- Purpose: Encrypted tunnel for remote management
- Security: Modern cryptography, minimal attack surface

### Zone 4: Reverse Proxy (192.168.0.205)
- **Traefik** (192.168.0.205) - Central ingress with security headers
- Purpose: SSL termination, security headers, rate limiting
- Security: HSTS, CSP, automatic HTTPS redirects

### Zone 5: K3s Cluster (192.168.0.111-114)
- Raspberry Pi cluster for containerized workloads
- Isolated from LXC services, managed via Traefik
- Security: RBAC, network policies, pod security standards

### Zone 6: Monitoring (192.168.0.200-201, 206-207)
- Prometheus, Grafana, AlertManager, PVE Exporter
- Purpose: Observability and alerting
- Security: Authentication, encrypted metrics collection

### Zone 7: Automation (192.168.0.208)
- Home Assistant for IoT device management
- Security: Isolated IoT network integration

## Security Improvements

### 1. DNS Security Stack
```
Internet ← Unbound (DoH/DoT) ← AdGuard ← Internal Clients
         (Recursive resolver)  (Filter/Block)
```

### 2. Network Access Control
- All external access through WireGuard VPN
- No direct SSH to internal services
- Bastion host as single entry point for management

### 3. Zero-Trust Principles
- All services behind Traefik with authentication
- TLS everywhere with Let's Encrypt automation
- Service-to-service authentication

### 4. Monitoring & Alerting
- Failed login attempts (Fail2ban → AlertManager)
- DNS query anomalies (AdGuard → Prometheus)
- VPN connection monitoring
- Certificate expiration alerts

### 5. Backup & Recovery
- Automated LXC container snapshots
- K3s etcd backups
- Configuration as code (this repository)

## Deployment Security Model

1. **Phase 1**: Create bastion from external system
2. **Phase 2+**: All operations from within bastion
3. **Access**: VPN → Bastion → Internal resources
4. **Secrets**: Stored only within bastion container