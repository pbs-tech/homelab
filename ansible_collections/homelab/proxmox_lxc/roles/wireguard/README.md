# WireGuard VPN Role

**Status:** Partially Implemented (Configuration Only)

This role provides configuration management for WireGuard VPN server deployment in an LXC container. WireGuard provides secure remote access to the homelab infrastructure with modern cryptography and excellent performance.

## Features

- WireGuard VPN server configuration
- Client configuration management
- Pre-shared key support for additional security
- Network access policies
- Firewall rule management
- Persistent keepalive for NAT traversal
- Multi-client support

## Requirements

- Proxmox VE with LXC support
- Ubuntu 22.04 LTS template
- Kernel WireGuard support
- Public IP or dynamic DNS for external access
- UDP port forwarding configuration

### Required Vault Variables

The following vault variable must be configured before deployment:

- `vault_wireguard_server_private_key` - WireGuard server private key
  (generate with: `wg genkey`)

## Role Variables

### Server Configuration

```yaml
# WireGuard server settings
wireguard_port: 51820
wireguard_interface: wg0
wireguard_server_ip: 10.200.0.1/24
wireguard_server_network: 10.200.0.0/24
```

### Security Settings

```yaml
# Connection and security parameters
wireguard_mtu: 1420
wireguard_keepalive: 25
wireguard_enable_preshared_keys: true
```

### Client Configuration

```yaml
# Client definitions
wireguard_clients:
  - name: admin-laptop
    description: Primary admin laptop
    public_key: REPLACE_WITH_ACTUAL_PUBLIC_KEY
    allowed_ips: 10.200.0.2/32
    preshared_key: REPLACE_WITH_ACTUAL_PSK
    persistent_keepalive: 25
  - name: mobile-device
    description: Admin mobile device
    public_key: REPLACE_WITH_ACTUAL_PUBLIC_KEY
    allowed_ips: 10.200.0.3/32
    preshared_key: REPLACE_WITH_ACTUAL_PSK
    persistent_keepalive: 25
```

### Network Access Policies

```yaml
# Networks accessible via VPN
wireguard_allowed_networks:
  - "192.168.0.0/24"  # Homelab network
  - "10.42.0.0/16"    # K3s cluster network
  - "10.43.0.0/16"    # K3s services network
```

### Firewall Configuration

```yaml
# Firewall rules for WireGuard
wireguard_firewall_rules:
  - "iptables -A INPUT -i {{ wireguard_interface }} -j ACCEPT"
  - "iptables -A FORWARD -i {{ wireguard_interface }} -j ACCEPT"
  - "iptables -A FORWARD -o {{ wireguard_interface }} -j ACCEPT"
  - "iptables -A INPUT -p udp --dport {{ wireguard_port }} -j ACCEPT"
```

### Logging and Monitoring

```yaml
# Logging configuration
wireguard_enable_logging: true
wireguard_log_level: info
```

## Current Status

This role currently contains:
- ✅ Default variable definitions
- ✅ Configuration templates
- ⚠️ Task implementation needed
- ⚠️ Handler implementation needed
- ⚠️ Service management needed

## Manual Setup Until Role Completion

To deploy WireGuard manually:

```bash
# Install WireGuard
apt-get update
apt-get install wireguard

# Generate server keys
wg genkey | tee privatekey | wg pubkey > publickey

# Configure interface
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = <server-private-key>
Address = 10.200.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = <client-public-key>
PresharedKey = <preshared-key>
AllowedIPs = 10.200.0.2/32
PersistentKeepalive = 25
EOF

# Enable and start service
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
```

## Generating Keys

```bash
# Server keys
wg genkey | tee server-privatekey | wg pubkey > server-publickey

# Client keys
wg genkey | tee client-privatekey | wg pubkey > client-publickey

# Preshared key (optional but recommended)
wg genpsk > preshared.key
```

## Client Configuration Example

```ini
[Interface]
PrivateKey = <client-private-key>
Address = 10.200.0.2/32
DNS = 192.168.0.202  # Homelab DNS server

[Peer]
PublicKey = <server-public-key>
PresharedKey = <preshared-key>
Endpoint = vpn.yourdomain.com:51820
AllowedIPs = 192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16
PersistentKeepalive = 25
```

## Security Considerations

- **Key Management** - Keep private keys secure, never commit to version control
- **Preshared Keys** - Enable for post-quantum security
- **Firewall Rules** - Restrict access to necessary networks only
- **Port Forwarding** - Configure router to forward UDP port 51820
- **Key Rotation** - Periodically rotate keys for enhanced security
- **Client Revocation** - Remove client configurations when no longer needed

## Integration with Homelab Services

### DNS Integration

Configure WireGuard clients to use homelab DNS:
```yaml
wireguard_dns_servers:
  - 192.168.0.202  # AdGuard/Unbound
```

### Monitoring Integration

Monitor WireGuard connections with Prometheus:
```yaml
wireguard_enable_metrics: true
wireguard_metrics_port: 9586
```

### Traefik Integration

Access internal services via VPN:
- Connect to VPN
- Access services at their internal URLs (e.g., http://grafana.homelab.local)

## Troubleshooting

### Connection Issues

```bash
# Check WireGuard status
wg show

# Check interface status
ip addr show wg0

# Check routing
ip route show table all | grep wg0

# View logs
journalctl -u wg-quick@wg0 -f
```

### Firewall Issues

```bash
# Verify firewall rules
iptables -L -v -n
iptables -t nat -L -v -n

# Check IP forwarding
sysctl net.ipv4.ip_forward
```

### Performance Issues

```bash
# Check MTU settings
ip link show wg0

# Test bandwidth
iperf3 -s  # On server
iperf3 -c <server-vpn-ip>  # On client
```

## Related Documentation

- [WireGuard Official Documentation](https://www.wireguard.com/)
- [WireGuard Quick Start](https://www.wireguard.com/quickstart/)

## License

Apache License 2.0 - See collection LICENSE file for details.
