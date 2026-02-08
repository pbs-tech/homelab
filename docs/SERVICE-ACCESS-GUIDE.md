# Service Access Guide

Complete reference for accessing all services in the homelab infrastructure, including URLs, ports, authentication methods, and health check commands.

## Quick Access Table

| Service | IP Address | Port | URL | Auth |
|---------|------------|------|-----|------|
| **Security & Networking** |
| Bastion (K3s) | 192.168.0.110 | 22 | `ssh pbs@192.168.0.110` | SSH Key |
| Bastion (NAS) | 192.168.0.109 | 22 | `ssh pbs@192.168.0.109` | SSH Key |
| Traefik | 192.168.0.205 | 80/443/8080 | `https://traefik.homelab.local` | Basic Auth |
| WireGuard VPN | 192.168.0.203 | 51820/UDP | N/A | WireGuard Key |
| AdGuard Home | 192.168.0.204 | 53/3000 | `http://adguard.homelab.local` | Username/Password |
| Unbound DNS | 192.168.0.202 | 53 | N/A (DNS only) | None |
| **Monitoring** |
| Prometheus | 192.168.0.200 | 9090 | `http://prometheus.homelab.local` | None (internal) |
| Grafana | 192.168.0.201 | 3000 | `http://grafana.homelab.local` | Username/Password |
| AlertManager | 192.168.0.206 | 9093 | `http://alertmanager.homelab.local` | None (internal) |
| Loki | 192.168.0.210 | 3100 | `http://loki.homelab.local` | None (internal) |
| **Applications** |
| Home Assistant | 192.168.0.208 | 8123 | `http://homeassistant.homelab.local` | Username/Password |
| OpenWrt | 192.168.0.209 | 80 | `http://openwrt.homelab.local` | Username/Password |
| **Media Services** |
| Sonarr | 192.168.0.230 | 8989 | `http://sonarr.homelab.local` | API Key |
| Radarr | 192.168.0.231 | 7878 | `http://radarr.homelab.local` | API Key |
| Bazarr | 192.168.0.232 | 6767 | `http://bazarr.homelab.local` | API Key |
| Prowlarr | 192.168.0.233 | 9696 | `http://prowlarr.homelab.local` | API Key |
| qBittorrent | 192.168.0.234 | 8080 | `http://qbittorrent.homelab.local` | Username/Password |
| Jellyfin | 192.168.0.235 | 8096 | `http://jellyfin.homelab.local` | Username/Password |
| **Infrastructure** |
| Proxmox (pve-mac) | 192.168.0.56 | 8006 | `https://192.168.0.56:8006` | Username/Password or API Token |
| Proxmox (pve-nas) | 192.168.0.57 | 8006 | `https://192.168.0.57:8006` | Username/Password or API Token |
| K3s API | 192.168.0.111 | 6443 | `https://192.168.0.111:6443` | kubeconfig |
| **Secure Enclave** |
| Enclave Bastion | 192.168.0.250 | 22 | `ssh pbs@192.168.0.250` | SSH Key |
| Enclave Router | 192.168.0.251 | 22 | `ssh pbs@192.168.0.251` | SSH Key |
| Kali Attacker | 10.10.0.10 | 22 | Via enclave bastion | SSH Key |

---

## Accessing Services

### Prerequisites

1. **VPN Connection** (for remote access): Connect via WireGuard VPN first
2. **DNS Configuration**: Configure DNS to use 192.168.0.202 or 192.168.0.204
3. **SSH Keys**: Ensure your SSH public key is deployed to bastion hosts

### Access Methods

#### Via Traefik (Recommended)

All web services are accessible through Traefik reverse proxy:

```bash
# Format: https://service-name.homelab.local
https://grafana.homelab.local
https://prometheus.homelab.local
https://homeassistant.homelab.local
```

#### Direct IP Access

For troubleshooting or when Traefik is unavailable:

```bash
# Format: http://IP:PORT
http://192.168.0.201:3000     # Grafana
http://192.168.0.200:9090     # Prometheus
http://192.168.0.208:8123     # Home Assistant
```

---

## Service Details

### Security & Networking

#### Bastion Hosts

Secure SSH jump points for all infrastructure access. Both `pbs` (operations) and `ansible` (provisioning) users are available on bastion hosts.

**Access:**
```bash
# K3s/Core services bastion
ssh pbs@192.168.0.110

# NAS services bastion
ssh pbs@192.168.0.109

# Using bastion as jump host
ssh -J pbs@192.168.0.110 pbs@192.168.0.200
```

**Recommended SSH Config (`~/.ssh/config`):**
```
# Bastion hosts
Host k3s-bastion
    HostName 192.168.0.110
    User pbs
    IdentityFile ~/.ssh/id_rsa

Host nas-bastion
    HostName 192.168.0.109
    User pbs
    IdentityFile ~/.ssh/id_rsa

# Jump through bastion to reach internal services
Host 192.168.0.2*
    User pbs
    ProxyJump k3s-bastion

# K3s nodes via bastion
Host k3-0*
    User pbs
    ProxyJump k3s-bastion

Host k3-01
    HostName 192.168.0.111
Host k3-02
    HostName 192.168.0.112
Host k3-03
    HostName 192.168.0.113
Host k3-04
    HostName 192.168.0.114
```

With this config you can run `ssh k3s-bastion` or `ssh k3-01` (auto-jumps through bastion).

**Health Check:**
```bash
ssh pbs@192.168.0.110 "uptime && df -h && free -m"
```

#### Traefik Reverse Proxy

Central reverse proxy and TLS termination for all web services.

**Access:**
- Dashboard: `http://192.168.0.205:8080/dashboard/` or `https://traefik.homelab.local`
- API: `http://192.168.0.205:8080/api/`

**Health Check:**
```bash
curl -s http://192.168.0.205:8080/api/overview | jq .
curl -s http://192.168.0.205:8080/ping
```

**View Configured Routes:**
```bash
curl -s http://192.168.0.205:8080/api/http/routers | jq '.[].name'
```

#### WireGuard VPN

Encrypted remote access to homelab network.

**Server Details:**
- Endpoint: `vpn.homelab.local:51820` or your public IP
- VPN Network: `10.200.0.0/24`
- Server IP: `10.200.0.1`

**Client Setup:**
See [CLIENT-VPN-SETUP.md](CLIENT-VPN-SETUP.md) for detailed instructions.

**Health Check (from server):**
```bash
pct exec 203 -- wg show
pct exec 203 -- systemctl status wg-quick@wg0
```

#### AdGuard Home

DNS filtering and ad blocking.

**Access:**
- Web UI: `http://192.168.0.204` or `https://adguard.homelab.local`
- DNS: `192.168.0.204:53`
- Setup (first time): `http://192.168.0.204:3000`

**Default Credentials:**
- Username: `admin`
- Password: Set in vault (`vault_adguard_admin_password`)

**Health Check:**
```bash
# Test DNS resolution
dig @192.168.0.204 google.com

# Check service status
pct exec 204 -- systemctl status AdGuardHome

# View statistics
curl -u admin:password http://192.168.0.204/control/stats | jq .
```

#### Unbound DNS

Recursive DNS resolver with DNSSEC validation.

**Access:**
- DNS: `192.168.0.202:53`

**Health Check:**
```bash
# Test DNS resolution
dig @192.168.0.202 google.com

# Check DNSSEC validation
dig @192.168.0.202 dnssec-failed.org  # Should fail
dig @192.168.0.202 google.com +dnssec # Should succeed

# Check service status
pct exec 202 -- systemctl status unbound
```

---

### Monitoring Stack

#### Prometheus

Metrics collection and storage.

**Access:**
- Web UI: `http://192.168.0.200:9090` or `https://prometheus.homelab.local`
- API: `http://192.168.0.200:9090/api/v1/`

**Health Check:**
```bash
# Check targets
curl -s http://192.168.0.200:9090/api/v1/targets | jq '.data.activeTargets | length'

# Test query
curl -s 'http://192.168.0.200:9090/api/v1/query?query=up' | jq .

# Check service
pct exec 200 -- systemctl status prometheus
```

**Common Queries:**
```bash
# Service availability
curl -s 'http://192.168.0.200:9090/api/v1/query?query=up' | jq '.data.result[] | {instance: .metric.instance, status: .value[1]}'

# Memory usage
curl -s 'http://192.168.0.200:9090/api/v1/query?query=node_memory_MemAvailable_bytes' | jq .
```

#### Grafana

Visualization and dashboards.

**Access:**
- Web UI: `http://192.168.0.201:3000` or `https://grafana.homelab.local`
- API: `http://192.168.0.201:3000/api/`

**Default Credentials:**
- Username: `admin`
- Password: Set in vault (`vault_grafana_admin_password`)

**Health Check:**
```bash
# API health
curl -s http://192.168.0.201:3000/api/health | jq .

# Check datasources
curl -u admin:password http://192.168.0.201:3000/api/datasources | jq '.[].name'

# Check service
pct exec 201 -- systemctl status grafana-server
```

**Pre-configured Dashboards:**
- Node Exporter Full
- Kubernetes Cluster Overview
- Traefik Dashboard
- Loki Logs Explorer

#### AlertManager

Alert routing and notification.

**Access:**
- Web UI: `http://192.168.0.206:9093` or `https://alertmanager.homelab.local`
- API: `http://192.168.0.206:9093/api/v2/`

**Health Check:**
```bash
# Check status
curl -s http://192.168.0.206:9093/api/v2/status | jq .

# View active alerts
curl -s http://192.168.0.206:9093/api/v2/alerts | jq '.[].labels.alertname'

# Check service
pct exec 206 -- systemctl status alertmanager
```

#### Loki

Log aggregation and storage.

**Access:**
- API: `http://192.168.0.210:3100`
- Query via Grafana (preferred)

**Health Check:**
```bash
# Check ready status
curl -s http://192.168.0.210:3100/ready

# List labels
curl -s http://192.168.0.210:3100/loki/api/v1/labels | jq .

# Query logs
curl -G -s http://192.168.0.210:3100/loki/api/v1/query \
  --data-urlencode 'query={job="syslog"}' | jq .

# Check service
pct exec 210 -- systemctl status loki
```

---

### Applications

#### Home Assistant

Home automation platform.

**Access:**
- Web UI: `http://192.168.0.208:8123` or `https://homeassistant.homelab.local`
- API: `http://192.168.0.208:8123/api/`

**Authentication:**
Create long-lived access token in UI: Profile → Security → Long-Lived Access Tokens

**Health Check:**
```bash
# API status
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://192.168.0.208:8123/api/ | jq .

# Check service
pct exec 208 -- systemctl status homeassistant
```

---

### Media Services

#### Sonarr

TV show management and automation.

**Access:**
- Web UI: `http://192.168.0.230:8989` or `https://sonarr.homelab.local`
- API: `http://192.168.0.230:8989/api/v3/`

**API Key:** Found in Settings → General → API Key

**Health Check:**
```bash
# System status
curl -H "X-Api-Key: YOUR_API_KEY" \
  http://192.168.0.230:8989/api/v3/system/status | jq .

# Check service
pct exec 230 -- systemctl status sonarr
```

#### Radarr

Movie management and automation.

**Access:**
- Web UI: `http://192.168.0.231:7878` or `https://radarr.homelab.local`
- API: `http://192.168.0.231:7878/api/v3/`

**API Key:** Found in Settings → General → API Key

**Health Check:**
```bash
# System status
curl -H "X-Api-Key: YOUR_API_KEY" \
  http://192.168.0.231:7878/api/v3/system/status | jq .

# Check service
pct exec 231 -- systemctl status radarr
```

#### Prowlarr

Indexer management for *arr stack.

**Access:**
- Web UI: `http://192.168.0.233:9696` or `https://prowlarr.homelab.local`
- API: `http://192.168.0.233:9696/api/v1/`

**Health Check:**
```bash
# System status
curl -H "X-Api-Key: YOUR_API_KEY" \
  http://192.168.0.233:9696/api/v1/system/status | jq .

# Check service
pct exec 233 -- systemctl status prowlarr
```

#### Jellyfin

Media streaming server.

**Access:**
- Web UI: `http://192.168.0.235:8096` or `https://jellyfin.homelab.local`
- API: `http://192.168.0.235:8096/`

**Health Check:**
```bash
# System info
curl http://192.168.0.235:8096/System/Info/Public | jq .

# Check service
pct exec 235 -- systemctl status jellyfin
```

#### qBittorrent

BitTorrent client.

**Access:**
- Web UI: `http://192.168.0.234:8080` or `https://qbittorrent.homelab.local`
- API: `http://192.168.0.234:8080/api/v2/`

**Default Credentials:**
- Username: `admin`
- Password: `adminadmin` (change immediately!)

**Health Check:**
```bash
# Check version
curl http://192.168.0.234:8080/api/v2/app/version

# Check service
pct exec 234 -- systemctl status qbittorrent-nox
```

---

### Infrastructure

#### Proxmox VE

Virtualization platform hosting all LXC containers and VMs.

**Access:**
- Web UI: `https://192.168.0.56:8006` (pve-mac), `https://192.168.0.57:8006` (pve-nas)
- API: `https://192.168.0.56:8006/api2/json`

**Authentication:**
- Web: Username/password
- API: API tokens (see [API.md](API.md))

**Health Check:**
```bash
# Check cluster status
curl -k -H "Authorization: PVEAPIToken=user@pam!token=SECRET" \
  https://192.168.0.56:8006/api2/json/cluster/status | jq .

# List running containers
curl -k -H "Authorization: PVEAPIToken=user@pam!token=SECRET" \
  https://192.168.0.56:8006/api2/json/nodes/pve-mac/lxc | jq '.data[] | {vmid, name, status}'
```

#### K3s Kubernetes Cluster

Lightweight Kubernetes distribution on Raspberry Pi nodes.

**Access:**
- API: `https://192.168.0.111:6443`
- Dashboard: Via Traefik ingress (if deployed)

**Authentication:**
```bash
# Get kubeconfig
scp pbs@192.168.0.111:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Update server address
sed -i 's/127.0.0.1/192.168.0.111/' ~/.kube/config
```

**Health Check:**
```bash
# Check nodes
kubectl get nodes

# Check pods
kubectl get pods --all-namespaces

# Check K3s service
ssh pbs@192.168.0.111 "sudo systemctl status k3s"
```

---

### Secure Enclave

Isolated pentesting environment. **Requires explicit deployment.**

#### Enclave Bastion

Jump host for enclave access.

**Access:**
```bash
# From production bastion
ssh pbs@192.168.0.250

# Convenience commands (on enclave bastion)
enclave-status     # Check enclave status
enclave-connect    # Connect to attacker VM
enclave-monitor    # Real-time monitoring
enclave-shutdown   # Emergency shutdown
```

#### Kali Attacker VM

Pentesting workstation with security tools.

**Access:**
```bash
# Via enclave bastion
ssh -J pbs@192.168.0.250 kali@10.10.0.10

# Or from enclave bastion
enclave-connect
```

---

## Health Check Scripts

### Quick Infrastructure Check

```bash
#!/bin/bash
# quick-health-check.sh

echo "=== Core Services ==="
for ip in 200 201 205 206 210; do
  name=$(case $ip in 200) echo "Prometheus";; 201) echo "Grafana";; 205) echo "Traefik";; 206) echo "AlertManager";; 210) echo "Loki";; esac)
  status=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.0.$ip:$(case $ip in 200) echo "9090";; 201) echo "3000";; 205) echo "8080";; 206) echo "9093";; 210) echo "3100";; esac)/health 2>/dev/null || echo "000")
  echo "$name (192.168.0.$ip): $([ "$status" == "200" ] && echo "✓ OK" || echo "✗ FAIL")"
done

echo ""
echo "=== DNS Services ==="
dig +short @192.168.0.202 google.com > /dev/null && echo "Unbound: ✓ OK" || echo "Unbound: ✗ FAIL"
dig +short @192.168.0.204 google.com > /dev/null && echo "AdGuard: ✓ OK" || echo "AdGuard: ✗ FAIL"

echo ""
echo "=== K3s Cluster ==="
kubectl get nodes --no-headers 2>/dev/null | while read line; do
  name=$(echo $line | awk '{print $1}')
  status=$(echo $line | awk '{print $2}')
  echo "$name: $([ "$status" == "Ready" ] && echo "✓ Ready" || echo "✗ $status")"
done
```

### Ansible Validation Playbook

```bash
# Run the quick smoke test
ansible-playbook tests/quick-smoke-test.yml

# Run full infrastructure validation
ansible-playbook tests/validate-infrastructure.yml

# Run service-specific validation
ansible-playbook tests/validate-services.yml
```

---

## Troubleshooting

### Service Not Accessible

1. **Check container is running:**
   ```bash
   pct list | grep <container_id>
   pct status <container_id>
   ```

2. **Check service is running:**
   ```bash
   pct exec <container_id> -- systemctl status <service_name>
   ```

3. **Check network connectivity:**
   ```bash
   ping 192.168.0.<ip>
   nc -zv 192.168.0.<ip> <port>
   ```

4. **Check Traefik routing:**
   ```bash
   curl -s http://192.168.0.205:8080/api/http/routers | jq '.[] | select(.name | contains("service-name"))'
   ```

### DNS Not Resolving

1. **Test direct IP access:**
   ```bash
   curl http://192.168.0.201:3000  # Should work if service is up
   ```

2. **Check DNS servers:**
   ```bash
   dig @192.168.0.202 grafana.homelab.local
   dig @192.168.0.204 grafana.homelab.local
   ```

3. **Verify DNS configuration:**
   ```bash
   cat /etc/resolv.conf  # Should include 192.168.0.202 or 192.168.0.204
   ```

### Authentication Failures

1. **Check vault credentials are correct:**
   ```bash
   ansible-vault view inventory/group_vars/vault.yml
   ```

2. **Test API authentication:**
   ```bash
   # Grafana
   curl -u admin:password http://192.168.0.201:3000/api/org

   # Proxmox
   curl -k -H "Authorization: PVEAPIToken=user@pam!token=secret" \
     https://192.168.0.56:8006/api2/json/version
   ```

### Bastion Access Issues

Bastion hosts manage their own iptables firewall (Proxmox-level NIC firewall is disabled). If you cannot SSH into a bastion, use `pct exec` from the Proxmox host to bypass both SSH and iptables.

#### fail2ban Banned Your IP

If repeated SSH attempts trigger a ban:

```bash
# Check banned IPs (run from Proxmox host)
pct exec 110 -- fail2ban-client status sshd

# Unban your IP
pct exec 110 -- fail2ban-client set sshd unbanip <YOUR_IP>

# View ban log
pct exec 110 -- tail -20 /var/log/fail2ban.log
```

#### iptables Lockout

If iptables rules prevent all connections:

```bash
# Access container directly from Proxmox host
pct exec 110 -- bash

# Flush rules and reset policy to restore access
pct exec 110 -- iptables -F
pct exec 110 -- iptables -P INPUT ACCEPT

# Then re-run the bastion role to restore proper rules
ansible-playbook playbooks/foundation.yml --tags "bastion"
```

#### Proxmox Firewall Conflict

Bastion containers intentionally disable the Proxmox NIC-level firewall (`container_network.firewall: false` in `inventory/group_vars/bastion_hosts.yml`). If someone re-enables the Proxmox firewall on the bastion NIC, it can conflict with iptables rules. Verify in the Proxmox web UI: select the container > Network > check that "Firewall" is unchecked on the NIC.

---

## Related Documentation

- [API.md](API.md) - Detailed API documentation
- [CLIENT-VPN-SETUP.md](CLIENT-VPN-SETUP.md) - VPN client setup guide
- [SECURITY-ARCHITECTURE.md](SECURITY-ARCHITECTURE.md) - Security architecture
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Detailed troubleshooting guide
- [INSTALLATION.md](INSTALLATION.md) - Installation guide

---

**Last Updated:** 2026-02-06
**Version:** 1.1.0
