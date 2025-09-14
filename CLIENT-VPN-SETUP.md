# WireGuard Client Setup Guide

## Security Model

- All remote access to homelab must go through WireGuard VPN
- VPN clients get access to homelab network (192.168.0.0/24)
- Bastion host (192.168.0.110) is the entry point for all management
- No direct external access to any services

## Client Configuration Generation

### 1. Generate Client Keys (run on bastion host)

```bash
# Generate private key
wg genkey > client-private.key

# Generate public key
wg pubkey < client-private.key > client-public.key

# Generate preshared key for added security
wg genpsk > client-preshared.key
```

### 2. Example Client Configuration

```ini
[Interface]
PrivateKey = CLIENT_PRIVATE_KEY_HERE
Address = 10.200.0.2/32
DNS = 192.168.0.204  # AdGuard Home for DNS filtering

[Peer]
PublicKey = SERVER_PUBLIC_KEY_HERE
PresharedKey = PRESHARED_KEY_HERE
Endpoint = YOUR_PUBLIC_IP:51820
AllowedIPs = 192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16
PersistentKeepalive = 25
```

### 3. Access Workflow

```text
Internet → WireGuard VPN → Homelab Network
                        ↓
                   192.168.0.204 (AdGuard DNS)
                        ↓
                   192.168.0.110 (Bastion SSH)
                        ↓
                   Internal Services
```

## Security Benefits

### DNS Security Chain

```text
VPN Client → AdGuard (Filter/Block) → Unbound (DoT/DoH) → Internet
```

- Malware/phishing protection even for VPN clients
- Ad blocking and tracking protection
- Encrypted DNS queries to upstream resolvers

### Network Isolation

- VPN clients isolated from each other (no peer-to-peer)
- Access only to specific homelab networks
- All management through single bastion host

### Authentication Layers

1. **WireGuard**: Cryptographic key authentication
2. **Preshared Keys**: Additional symmetric key for quantum resistance
3. **SSH Keys**: Bastion host access via public key authentication
4. **Service Auth**: Individual service authentication (Traefik, etc.)

## Client Device Recommendations

### Mobile Devices

- Official WireGuard app
- Auto-connect on untrusted networks
- Kill switch enabled

### Laptops/Desktops

- WireGuard official client
- System-level VPN (not browser-only)
- DNS leak protection

### Router-Level VPN

- For IoT devices and guests
- Separate VLAN for VPN traffic
- Firewall rules for network segmentation
