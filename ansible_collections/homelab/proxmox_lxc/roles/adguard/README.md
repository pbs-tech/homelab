# AdGuard Home Role

Deploys and configures AdGuard Home DNS server in an LXC container, providing network-wide ad blocking, privacy protection, and DNS filtering for all devices on the network.

## Features

- **Network-Wide Ad Blocking** - Block ads and trackers for all devices without client software
- **DNS Filtering** - Custom blocklists and allowlists for fine-grained control
- **Privacy Protection** - Prevent tracking and telemetry at the DNS level
- **HTTPS/DoT/DoH Support** - Encrypted DNS for enhanced privacy
- **Statistics Dashboard** - Query logging and analytics
- **Parental Controls** - Safe search and content filtering
- **Custom DNS Rewrites** - Local DNS records for homelab services
- **Upstream DNS Integration** - Works with Unbound for recursive resolution
- **Web UI** - User-friendly administration interface

## Requirements

- Proxmox VE with LXC support
- Ubuntu 22.04 LTS template
- Network configuration for DNS services (ports 53, 80, 443, 3000)
- Vault variable: `vault_adguard_admin_password` (minimum 12 characters)

## Role Variables

### Basic Configuration

```yaml
# AdGuard Home version
adguard_version: "latest"

# Network ports
adguard_dns_port: 53
adguard_web_port: 80
adguard_https_port: 443
adguard_setup_port: 3000

# Admin credentials
adguard_admin_username: "admin"
adguard_admin_password: "{{ vault_adguard_admin_password }}"
```

### DNS Configuration

```yaml
# Upstream DNS servers
adguard_upstream_dns:
  - "192.168.0.202"  # Unbound (recommended)
  - "1.1.1.1"        # Cloudflare fallback

# Bootstrap DNS (for resolving upstream hostnames)
adguard_bootstrap_dns:
  - "1.1.1.1"
  - "8.8.8.8"

# DNS rate limiting
adguard_ratelimit: 20
adguard_ratelimit_whitelist: []
```

### Filtering Configuration

```yaml
# Enable filtering
adguard_filtering_enabled: true

# Default blocklists
adguard_blocklists:
  - name: "AdGuard DNS filter"
    url: "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt"
    enabled: true
  - name: "AdAway Default Blocklist"
    url: "https://adaway.org/hosts.txt"
    enabled: true

# Custom allowlist
adguard_allowlist: []

# Custom blocklist
adguard_blocklist: []
```

### DNS Rewrites

```yaml
# Custom DNS records for local services
adguard_rewrites:
  - domain: "*.homelab.lan"
    answer: "192.168.0.205"  # Traefik
  - domain: "grafana.homelab.lan"
    answer: "192.168.0.201"
  - domain: "prometheus.homelab.lan"
    answer: "192.168.0.200"
```

### DHCP Configuration (Optional)

```yaml
# Enable DHCP server
adguard_dhcp_enabled: false
adguard_dhcp_interface: "eth0"
adguard_dhcp_gateway: "192.168.0.1"
adguard_dhcp_subnet: "255.255.255.0"
adguard_dhcp_range_start: "192.168.0.100"
adguard_dhcp_range_end: "192.168.0.199"
adguard_dhcp_lease_duration: 86400
```

## Usage

### Basic Deployment

```yaml
- hosts: adguard-lxc
  become: true
  vars:
    vault_adguard_admin_password: "{{ vault_adguard_admin_password }}"
  roles:
    - homelab.proxmox_lxc.adguard
```

### With Unbound Integration

```yaml
- hosts: adguard-lxc
  become: true
  vars:
    adguard_upstream_dns:
      - "192.168.0.202"  # Unbound as primary upstream
    adguard_rewrites:
      - domain: "*.homelab.lan"
        answer: "192.168.0.205"
  roles:
    - homelab.proxmox_lxc.adguard
```

## Dependencies

- homelab.common.container_base (recommended)
- homelab.common.security_hardening (recommended)

## Files and Templates

- `templates/AdGuardHome.yaml.j2` - Main AdGuard configuration
- `handlers/main.yml` - Service restart handlers

## Post-Installation Setup

1. Access the web UI at `http://192.168.0.204:3000` for initial setup
2. Complete the setup wizard
3. Configure your router/DHCP to use AdGuard as primary DNS (192.168.0.204)

## Troubleshooting

### Check Service Status

```bash
# Check if AdGuard is running
pct exec 204 -- systemctl status AdGuardHome

# View logs
pct exec 204 -- journalctl -u AdGuardHome -f

# Test DNS resolution
dig @192.168.0.204 google.com

# Check web interface
curl -I http://192.168.0.204:80
```

### Common Issues

```bash
# Verify ports are listening
pct exec 204 -- ss -tlnp | grep -E ':(53|80|443|3000)'

# Check configuration
pct exec 204 -- cat /opt/AdGuardHome/AdGuardHome.yaml

# Reset admin password
pct exec 204 -- /opt/AdGuardHome/AdGuardHome -s stop
pct exec 204 -- /opt/AdGuardHome/AdGuardHome --reset-password
```

## Integration with Homelab

- **Unbound** - Use as upstream DNS for recursive resolution
- **Traefik** - DNS rewrite rules point to reverse proxy
- **Prometheus** - Metrics available via `/metrics` endpoint
- **Grafana** - Dashboard for DNS query visualization

## Security Considerations

- Use a strong admin password (minimum 12 characters)
- Restrict web UI access to trusted networks
- Enable HTTPS for the web interface in production
- Regularly update blocklists
- Monitor query logs for unusual patterns

## License

MIT License - See collection LICENSE file for details.
