# Unbound DNS Role

Deploys and configures Unbound recursive DNS server in an LXC container, providing secure, fast, and lightweight DNS resolution with DNSSEC validation and caching.

## Features

- **Recursive DNS Resolution** - Full recursive resolver without third-party dependencies
- **DNSSEC Validation** - Cryptographic verification of DNS responses
- **DNS Caching** - High-performance caching for improved response times
- **Security Blocklist** - Integrated malware and threat domain blocking
- **Custom Local Zones** - Define local DNS records for homelab services
- **DNS Forwarding** - Optional forwarding to upstream resolvers
- **Access Control** - Network-based access control lists
- **Prometheus Metrics** - Metrics export for monitoring integration
- **Systemd Integration** - Proper service management and logging

## Requirements

- Proxmox VE with LXC support
- Ubuntu 22.04 LTS template
- Network configuration for DNS services (port 53)
- Adequate memory for DNS cache (256MB minimum recommended)

## Role Variables

### Basic Configuration

```yaml
# Unbound version and service
unbound_port: 53
unbound_interface: "0.0.0.0"

# Cache configuration
unbound_cache_min_ttl: 300
unbound_cache_max_ttl: 86400
unbound_cache_size: "256m"

# Logging
unbound_log_queries: false
unbound_log_replies: false
unbound_verbosity: 1
```

### Security Settings

```yaml
# DNSSEC
unbound_dnssec_enabled: true
unbound_root_hints_update: true

# Security blocklist
unbound_blocklist_enabled: true
unbound_blocklist_url: "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

# Access control (CIDR ranges allowed to query)
unbound_access_control:
  - "192.168.0.0/24 allow"
  - "10.0.0.0/8 allow"
  - "127.0.0.0/8 allow"
```

### Local Zones

```yaml
# Local DNS records for homelab services
unbound_local_zones:
  - name: "homelab.local"
    type: "static"
    records:
      - "prometheus.homelab.local. IN A 192.168.0.200"
      - "grafana.homelab.local. IN A 192.168.0.201"
      - "traefik.homelab.local. IN A 192.168.0.205"
```

### Forwarding Configuration

```yaml
# Forward zones (optional - use upstream resolvers)
unbound_forward_zones:
  - name: "."
    forward_addresses:
      - "1.1.1.1"
      - "8.8.8.8"
```

## Usage

### Basic Deployment

```yaml
- hosts: unbound-lxc
  become: true
  roles:
    - homelab.proxmox_lxc.unbound
```

### With Custom Local Zones

```yaml
- hosts: unbound-lxc
  become: true
  vars:
    unbound_local_zones:
      - name: "homelab.local"
        type: "static"
        records:
          - "nas.homelab.local. IN A 192.168.0.100"
          - "pve.homelab.local. IN A 192.168.0.56"
  roles:
    - homelab.proxmox_lxc.unbound
```

## Dependencies

- homelab.common.container_base (recommended)
- homelab.common.security_hardening (recommended)

## Files and Templates

- `templates/unbound.conf.j2` - Main Unbound configuration
- `handlers/main.yml` - Service restart handlers

## Troubleshooting

### Check Service Status

```bash
# Check if Unbound is running
pct exec 202 -- systemctl status unbound

# View logs
pct exec 202 -- journalctl -u unbound -f

# Test DNS resolution
pct exec 202 -- dig @localhost google.com

# Validate configuration
pct exec 202 -- unbound-checkconf
```

### Common Issues

```bash
# Check listening ports
pct exec 202 -- ss -tlnp | grep :53

# Test DNSSEC validation
pct exec 202 -- dig @localhost dnssec-failed.org

# Verify cache statistics
pct exec 202 -- unbound-control stats
```

## Integration with AdGuard

Unbound is commonly used as upstream DNS for AdGuard Home:

```yaml
# In AdGuard configuration
adguard_upstream_dns:
  - "192.168.0.202"  # Unbound IP
```

## Security Considerations

- Restrict access using `unbound_access_control` to prevent DNS amplification attacks
- Enable DNSSEC validation for cryptographic security
- Use the security blocklist to block known malicious domains
- Consider running on a private network only

## License

MIT License - See collection LICENSE file for details.
