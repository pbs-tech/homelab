# WireGuard VPN Client Setup Guide

Complete guide for connecting clients to your homelab WireGuard VPN infrastructure.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Generating Client Keys](#generating-client-keys)
4. [Linux Client Setup](#linux-client-setup)
5. [macOS Client Setup](#macos-client-setup)
6. [Windows Client Setup](#windows-client-setup)
7. [Mobile Setup (iOS/Android)](#mobile-setup-iosandroid)
8. [Configuration File Format](#configuration-file-format)
9. [DNS Configuration](#dns-configuration)
10. [Split Tunneling vs Full Tunnel](#split-tunneling-vs-full-tunnel)
11. [Troubleshooting](#troubleshooting)
12. [Security Best Practices](#security-best-practices)

## Overview

This guide helps you configure WireGuard VPN clients to securely access your homelab infrastructure.

**Server Details:**

- Server IP: `192.168.0.203` (LXC container)
- VPN Network: `10.200.0.0/24`
- Server VPN IP: `10.200.0.1`
- Default Port: `51820` (UDP)
- Domain: `vpn.homelab.local`

**What You'll Access:**

- Homelab network: `192.168.0.0/24`
- K3s cluster network: `10.42.0.0/16`
- K3s services network: `10.43.0.0/16`
- DNS server: `192.168.0.202` (AdGuard/Unbound)

**Time Estimate:** 15-30 minutes per client

## Prerequisites

Before starting, ensure you have:

### Server Requirements

- WireGuard server deployed and running at `192.168.0.203`
- Server public key available (displayed during server deployment)
- Port forwarding configured on your router: `UDP port 51820 -> 192.168.0.203`
- Dynamic DNS or static public IP configured

### Client Requirements

- Administrative access to install software
- Basic command-line knowledge (for Linux/macOS CLI setup)
- Text editor for creating configuration files

### Information You'll Need

1. **Server public key** - Get from server admin or deployment logs
2. **Your assigned client IP** - Typically `10.200.0.X/32` (X = 2, 3, 4, etc.)
3. **Preshared key** - Optional but recommended for post-quantum security
4. **Public endpoint** - Your public IP or domain (e.g., `vpn.example.com:51820`)

## Generating Client Keys

Every client needs a unique key pair. Generate these on your client device (or on a secure machine).

### Linux/macOS

```bash
# Install WireGuard tools if not present
# Ubuntu/Debian:
sudo apt-get install wireguard-tools

# macOS (Homebrew):
brew install wireguard-tools

# Generate private key
wg genkey > client-privatekey

# Generate public key from private key
wg pubkey < client-privatekey > client-publickey

# Optional: Generate preshared key (recommended)
wg genpsk > preshared.key

# Display keys
echo "Private Key:"
cat client-privatekey
echo ""
echo "Public Key:"
cat client-publickey
echo ""
echo "Preshared Key:"
cat preshared.key

# Secure the private key
chmod 600 client-privatekey preshared.key
```

### Windows

```powershell
# Using official WireGuard app
# 1. Install WireGuard from https://www.wireguard.com/install/
# 2. Create new empty tunnel
# 3. App will auto-generate keys
# 4. Copy public key from interface section

# OR use WSL/Git Bash and follow Linux instructions
```

### Key Security

- **Private Key**: Keep absolutely secret. Never share or commit to version control.
- **Public Key**: Share with server administrator to authorize your client.
- **Preshared Key**: Optional additional security layer. Share securely with admin.

**Action Required:** Send your **public key** and desired **client IP** (e.g., 10.200.0.2/32) to your homelab administrator to be added to the server configuration.

## Linux Client Setup

### Method 1: wg-quick (Recommended for Simplicity)

**Step 1: Install WireGuard**

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install wireguard wireguard-tools resolvconf

# Fedora/RHEL
sudo dnf install wireguard-tools

# Arch Linux
sudo pacman -S wireguard-tools
```

**Step 2: Create Configuration File**

> **Common mistake:** The `PublicKey` in `[Peer]` must be the **server's** public key —
> not your own client public key. Your client public key is only sent to the admin for adding
> to the server. Run `pct exec 203 -- wg show wg0 public-key` on the Proxmox host to get
> the server's public key, or use the Ansible-generated config in `~/.wireguard/homelab/`.

```bash
# Create configuration directory
sudo mkdir -p /etc/wireguard
sudo chmod 700 /etc/wireguard

# Create configuration file (replace with your values)
sudo nano /etc/wireguard/wg0.conf
```

Add this configuration (replace placeholder values):

```ini
[Interface]
# Client private key (generate with: wg genkey)
PrivateKey = YOUR_CLIENT_PRIVATE_KEY
# Client VPN IP address
Address = 10.200.0.2/32
# DNS servers for homelab resolution
DNS = 192.168.0.202
# DNS integration for systems with NetworkManager/systemd-resolved (most modern Linux)
# This ensures DNS works correctly instead of being overridden by NetworkManager
PostUp = resolvectl dns %i 192.168.0.202; resolvectl domain %i ~homelab.local
PostDown = resolvectl revert %i

[Peer]
# Server public key (get from admin)
PublicKey = SERVER_PUBLIC_KEY
# Optional: Preshared key for additional security
PresharedKey = YOUR_PRESHARED_KEY
# Server endpoint (public IP or domain + port)
Endpoint = vpn.example.com:51820
# Networks accessible through VPN (split tunnel)
AllowedIPs = 192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16
# Keep connection alive through NAT (seconds)
PersistentKeepalive = 25
```

> **Note:** The `PostUp`/`PostDown` lines use `resolvectl` to properly integrate with
> systemd-resolved, which is used by NetworkManager on most modern Linux distributions.
> If you use a distribution without systemd-resolved, remove those lines and rely on the
> `DNS` directive alone. For legacy systems with `resolvconf`, use:
> `PostUp = resolvconf -a %i -m 0 -x` / `PostDown = resolvconf -d %i`

**Step 3: Secure Configuration File**

```bash
# Set proper permissions (important!)
sudo chmod 600 /etc/wireguard/wg0.conf
```

**Step 4: Start VPN Connection**

```bash
# Start VPN
sudo wg-quick up wg0

# Verify connection
sudo wg show
# You should see handshake information

# Test connectivity
ping 192.168.0.1  # Ping homelab gateway
ping 192.168.0.202  # Ping DNS server
```

**Step 5: Enable Auto-Start (Optional)**

```bash
# Enable VPN to start on boot
sudo systemctl enable wg-quick@wg0

# Manage VPN with systemd
sudo systemctl start wg-quick@wg0
sudo systemctl stop wg-quick@wg0
sudo systemctl status wg-quick@wg0
```

**Useful Commands:**

```bash
# Start VPN
sudo wg-quick up wg0

# Stop VPN
sudo wg-quick down wg0

# View connection status
sudo wg show

# View detailed connection info
sudo wg show wg0

# View routing
ip route show table all | grep wg0

# View logs
journalctl -u wg-quick@wg0 -f
```

### Method 2: NetworkManager with `nmcli` (Recommended for Arch/Modern Linux)

On systems where NetworkManager manages DNS (most modern Linux desktops), using `nmcli` is
preferred over `wg-quick`. NM handles DNS integration natively, avoiding conflicts with
`resolvconf` or `systemd-resolved`.

**Step 1: Import configuration**

```bash
sudo nmcli connection import type wireguard file /etc/wireguard/wg0.conf
```

**Step 2: Configure DNS**

```bash
nmcli connection modify wg0 ipv4.dns "192.168.0.202" ipv4.dns-search "homelab.local"
```

**Step 3: Connect**

```bash
nmcli connection up wg0
```

**Step 4: Verify DNS is working**

```bash
resolvectl status wg0
resolvectl query grafana.homelab.local
```

**Disconnect:**

```bash
nmcli connection down wg0
```

**Advantages:**

- No `resolvconf` signature mismatch errors
- NM handles DNS routing natively — `.homelab.local` queries go to `192.168.0.202`
- No need for `PostUp`/`PostDown` hooks
- GUI integration with desktop environment (connection also appears in system tray)
- No need for sudo to connect after initial import

## macOS Client Setup

### Method 1: Official WireGuard App (Recommended)

**Step 1: Install WireGuard**

1. Download from Mac App Store: Search "WireGuard"
2. Or download from [https://www.wireguard.com/install/](https://www.wireguard.com/install/)

**Step 2: Create Tunnel Configuration**

1. Open WireGuard app
2. Click "Add Empty Tunnel" or "Add Tunnel from File"
3. If creating manually, name it (e.g., "Homelab VPN")
4. Enter configuration:

```ini
[Interface]
PrivateKey = YOUR_CLIENT_PRIVATE_KEY
Address = 10.200.0.2/32
DNS = 192.168.0.202

[Peer]
PublicKey = SERVER_PUBLIC_KEY
PresharedKey = YOUR_PRESHARED_KEY
Endpoint = vpn.example.com:51820
AllowedIPs = 192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16
PersistentKeepalive = 25
```

5. Click "Save"

**Step 3: Connect**

1. Select your tunnel in the app
2. Click "Activate"
3. Verify connection in app status panel

**Features:**

- Menu bar integration
- One-click connect/disconnect
- Connection statistics
- QR code import (for mobile-generated configs)
- On-demand activation rules

**Step 4: Verify Connection**

```bash
# Open Terminal
ping 192.168.0.1  # Homelab gateway
ping 192.168.0.202  # DNS server

# Check WireGuard interface
ifconfig utun3  # Interface name may vary

# Test DNS resolution
dig grafana.homelab.local @192.168.0.202
```

### Method 2: Command Line (Homebrew)

**Step 1: Install WireGuard Tools**

```bash
brew install wireguard-tools
```

**Step 2: Create Configuration**

```bash
# Create config directory
sudo mkdir -p /etc/wireguard
sudo chmod 700 /etc/wireguard

# Create configuration file
sudo nano /etc/wireguard/wg0.conf
# Use same configuration format as Linux
```

**Step 3: Manage Connection**

```bash
# Start VPN
sudo wg-quick up wg0

# Stop VPN
sudo wg-quick down wg0

# Check status
sudo wg show
```

**Note:** Command-line method requires sudo for every connection. The GUI app is more convenient for daily use.

## Windows Client Setup

### Official WireGuard App (Only Method)

**Step 1: Download and Install**

1. Download from [https://www.wireguard.com/install/](https://www.wireguard.com/install/)
2. Run installer (requires administrator rights)
3. Launch WireGuard application

**Step 2: Create Tunnel**

**Option A: Import Configuration File**

1. Click "Add Tunnel" > "Add tunnel from file"
2. Select your `.conf` file
3. Click "Activate"

**Option B: Manual Configuration**

1. Click "Add Tunnel" > "Add empty tunnel"
2. Name tunnel (e.g., "Homelab VPN")
3. Enter configuration:

```ini
[Interface]
PrivateKey = YOUR_CLIENT_PRIVATE_KEY
Address = 10.200.0.2/32
DNS = 192.168.0.202

[Peer]
PublicKey = SERVER_PUBLIC_KEY
PresharedKey = YOUR_PRESHARED_KEY
Endpoint = vpn.example.com:51820
AllowedIPs = 192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16
PersistentKeepalive = 25
```

4. Click "Save"
5. Click "Activate"

**Step 3: Verify Connection**

Open PowerShell or Command Prompt:

```powershell
# Test connectivity
ping 192.168.0.1
ping 192.168.0.202

# View routing table
route print

# Test DNS resolution
nslookup grafana.homelab.local 192.168.0.202
```

**Features:**

- System tray integration
- Auto-start on Windows boot
- Connection statistics
- Export configuration (for backup)

**Auto-Start Configuration:**

1. Right-click tunnel in app
2. Select "Enable automatic startup"
3. VPN will connect automatically on Windows login

**Troubleshooting Windows:**

- **Firewall Issues**: Add WireGuard to Windows Firewall allowed apps
- **DNS Not Working**: Manually set DNS in adapter settings
- **No Internet**: Check AllowedIPs configuration (ensure it's split tunnel)

## Mobile Setup (iOS/Android)

### iOS Setup

**Step 1: Install App**

1. Download "WireGuard" from Apple App Store
2. Open app

**Step 2: Add Tunnel**

**Method A: QR Code (Easiest)**

If your server admin provides a QR code:

1. Tap "Add a tunnel"
2. Choose "Create from QR code"
3. Scan QR code with camera
4. Name tunnel (e.g., "Homelab VPN")
5. Save

**Method B: Manual Configuration**

1. Tap "Add a tunnel"
2. Choose "Create from scratch"
3. Name tunnel
4. Enter configuration:
   - **Interface Private Key**: Paste or generate
   - **Addresses**: `10.200.0.2/32`
   - **DNS Servers**: `192.168.0.202`
   - **Peer Public Key**: Server public key
   - **Preshared Key**: Your preshared key (optional)
   - **Endpoint**: `vpn.example.com:51820`
   - **Allowed IPs**: `192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16`
   - **Persistent Keepalive**: `25`
5. Save

**Method C: Import File**

1. Save configuration file to iCloud Drive/Files
2. In WireGuard app, tap "Add a tunnel"
3. Choose "Create from file or archive"
4. Select configuration file

**Step 3: Connect**

1. Toggle switch next to tunnel name
2. Allow VPN configuration if prompted
3. Verify VPN icon appears in status bar

**On-Demand Activation:**

1. Tap tunnel name (not the toggle)
2. Scroll to "On-Demand Activation"
3. Enable rules (e.g., connect on WiFi/Cellular)

### Android Setup

**Step 1: Install App**

1. Download "WireGuard" from Google Play Store
2. Open app

**Step 2: Add Tunnel**

**Method A: QR Code**

1. Tap "+" button
2. Select "Scan from QR code"
3. Scan QR code
4. Name tunnel
5. Create tunnel

**Method B: Import File**

1. Save `.conf` file to device
2. Tap "+" button
3. Select "Import from file or archive"
4. Navigate to file
5. Create tunnel

**Method C: Manual Configuration**

1. Tap "+" button
2. Select "Create from scratch"
3. Enter configuration:
   - **Interface Name**: `wg0`
   - **Private Key**: Generate or paste
   - **Addresses**: `10.200.0.2/32`
   - **DNS Servers**: `192.168.0.202`
   - **Public Key**: Server public key
   - **Preshared Key**: Your preshared key
   - **Endpoint**: `vpn.example.com:51820`
   - **Allowed IPs**: `192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16`
   - **Persistent Keepalive**: `25`
4. Save

**Step 3: Connect**

Tap toggle switch next to tunnel name to connect.

**Widget Support:**

Add WireGuard widget to home screen for quick toggle.

## Configuration File Format

### Complete Configuration Breakdown

```ini
[Interface]
# Client's private key (keep secret!)
# Generate with: wg genkey
PrivateKey = YOUR_PRIVATE_KEY_HERE

# Client's IP address in the VPN subnet
# Must be unique per client
# Format: IP/CIDR (e.g., 10.200.0.2/32 for single host)
Address = 10.200.0.2/32

# DNS servers to use when VPN is active
# Comma-separated list
# Use homelab DNS for .homelab.local resolution
DNS = 192.168.0.202

# Optional: Custom MTU (default: 1420)
# Reduce if experiencing fragmentation
#MTU = 1380

# Optional: Run commands after VPN starts
#PostUp = echo "VPN Connected"

# Optional: Run commands before VPN stops
#PostDown = echo "VPN Disconnected"

[Peer]
# Server's public key (get from admin)
PublicKey = SERVER_PUBLIC_KEY_HERE

# Optional: Preshared key for post-quantum security
# Recommended for enhanced security
PresharedKey = PRESHARED_KEY_HERE

# Server endpoint (public IP or domain + port)
# Format: hostname:port or IP:port
Endpoint = vpn.example.com:51820

# Networks accessible through VPN
# Split tunnel: Only homelab traffic goes through VPN
AllowedIPs = 192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16

# Full tunnel: All traffic goes through VPN
#AllowedIPs = 0.0.0.0/0, ::/0

# Keep connection alive through NAT
# Send keepalive packet every N seconds
# Recommended: 25 for mobile, 21-25 for stationary
PersistentKeepalive = 25
```

### Configuration Options Explained

**Interface Section:**

- **PrivateKey**: Your client's private key. Generate once, keep secret.
- **Address**: Your IP in VPN subnet. Must match server's allowed IPs for your peer.
- **DNS**: DNS servers used when VPN is active. Use homelab DNS (192.168.0.202) to resolve `.homelab.local` domains.
- **MTU**: Maximum transmission unit. Lower if experiencing packet loss (try 1380, 1360).
- **PostUp/PostDown**: Scripts run when VPN starts/stops. Useful for custom routing.

**Peer Section:**

- **PublicKey**: Server's public key. Get from server admin or deployment logs.
- **PresharedKey**: Additional encryption layer. Protects against quantum computing attacks.
- **Endpoint**: Server's public IP/domain and port. Must be reachable from internet.
- **AllowedIPs**: Networks routed through VPN. Split tunnel (specific networks) vs full tunnel (0.0.0.0/0).
- **PersistentKeepalive**: Seconds between keepalive packets. Prevents NAT timeout. Disable with 0 if behind stable connection.

### Example Configurations

**Split Tunnel (Recommended):**

```ini
[Interface]
PrivateKey = aB3cD4eF5gH6iJ7kL8mN9oP0qR1sT2uV3wX4yZ5aB6cD=
Address = 10.200.0.2/32
DNS = 192.168.0.202

[Peer]
PublicKey = sT9uV0wX1yZ2aB3cD4eF5gH6iJ7kL8mN9oP0qR1sT2u=
PresharedKey = cD7eF8gH9iJ0kL1mN2oP3qR4sT5uV6wX7yZ8aB9cD0eF=
Endpoint = 203.0.113.10:51820
AllowedIPs = 192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16
PersistentKeepalive = 25
```

**Full Tunnel (All Traffic Through VPN):**

```ini
[Interface]
PrivateKey = aB3cD4eF5gH6iJ7kL8mN9oP0qR1sT2uV3wX4yZ5aB6cD=
Address = 10.200.0.2/32
DNS = 192.168.0.202, 1.1.1.1

[Peer]
PublicKey = sT9uV0wX1yZ2aB3cD4eF5gH6iJ7kL8mN9oP0qR1sT2u=
PresharedKey = cD7eF8gH9iJ0kL1mN2oP3qR4sT5uV6wX7yZ8aB9cD0eF=
Endpoint = 203.0.113.10:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

**Mobile Optimized (Battery Saving):**

```ini
[Interface]
PrivateKey = aB3cD4eF5gH6iJ7kL8mN9oP0qR1sT2uV3wX4yZ5aB6cD=
Address = 10.200.0.3/32
DNS = 192.168.0.202
MTU = 1280

[Peer]
PublicKey = sT9uV0wX1yZ2aB3cD4eF5gH6iJ7kL8mN9oP0qR1sT2u=
Endpoint = vpn.homelab.example.com:51820
AllowedIPs = 192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16
PersistentKeepalive = 25
```

## DNS Configuration

### Why DNS Matters

Your homelab uses internal DNS names like `grafana.homelab.local`, `prometheus.homelab.local`. Without proper DNS configuration, you'll have to use IP addresses.

### Configure DNS in VPN Client

**Method 1: Configuration File (Automatic)**

```ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.200.0.2/32
DNS = 192.168.0.202  # Homelab DNS server
```

WireGuard automatically configures DNS when VPN connects.

**Method 2: PostUp/PostDown with resolvectl (Recommended for Linux with NetworkManager)**

On modern Linux systems with NetworkManager and systemd-resolved, the `DNS` directive alone
is often overridden by NetworkManager. Add `PostUp`/`PostDown` to your config to use `resolvectl`:

```ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.200.0.2/32
DNS = 192.168.0.202
PostUp = resolvectl dns %i 192.168.0.202; resolvectl domain %i ~homelab.local
PostDown = resolvectl revert %i
```

This tells systemd-resolved to route `.homelab.local` queries through the VPN DNS, while
leaving other DNS queries on the default resolver.

**Method 3: Manual DNS (If Auto-DNS Fails)**

**Linux:**

```bash
# Edit /etc/resolv.conf (temporary)
sudo nano /etc/resolv.conf

# Add (at top):
nameserver 192.168.0.202

# Or configure systemd-resolved (permanent)
sudo nano /etc/systemd/resolved.conf

# Add under [Resolve]:
DNS=192.168.0.202
Domains=~homelab.local

# Restart
sudo systemctl restart systemd-resolved
```

**macOS:**

1. System Preferences > Network
2. Select VPN interface
3. Advanced > DNS
4. Add DNS Server: `192.168.0.202`
5. Search Domains: `homelab.local`

**Windows:**

1. Control Panel > Network and Internet > Network Connections
2. Right-click VPN adapter > Properties
3. Select "Internet Protocol Version 4 (TCP/IPv4)" > Properties
4. Use following DNS servers:
   - Preferred: `192.168.0.202`
5. Advanced > DNS > Append these DNS suffixes: `homelab.local`

### Testing DNS Resolution

```bash
# Test homelab DNS server directly
nslookup grafana.homelab.local 192.168.0.202

# Test DNS through VPN (should use homelab DNS)
nslookup grafana.homelab.local

# Verify DNS server in use
# Linux/macOS:
cat /etc/resolv.conf

# Windows:
ipconfig /all
```

### DNS Troubleshooting

**Issue: Can ping IPs but not resolve hostnames**

```bash
# Check DNS configuration
cat /etc/resolv.conf  # Linux/macOS
ipconfig /all  # Windows

# Test DNS server directly
dig @192.168.0.202 grafana.homelab.local  # Linux/macOS
nslookup grafana.homelab.local 192.168.0.202  # Windows
```

**Solution:** Ensure `DNS = 192.168.0.202` in configuration file.

**Issue: DNS leaks (using ISP DNS instead of VPN DNS)**

```bash
# Test for DNS leaks
dig +short myip.opendns.com @resolver1.opendns.com
```

**Solution:** Use full tunnel or configure DNS to only use VPN DNS.

## Split Tunneling vs Full Tunnel

### Split Tunneling (Recommended for Homelab)

**What it is:** Only homelab traffic goes through VPN. Internet traffic uses your normal connection.

**Configuration:**

```ini
AllowedIPs = 192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16
```

**Advantages:**

- Faster internet browsing (doesn't go through VPN)
- Lower latency for non-homelab traffic
- Reduced VPN bandwidth usage
- Better for streaming, gaming

**Disadvantages:**

- Public internet traffic not encrypted
- IP address changes depending on destination
- More complex routing

**Use Cases:**

- Daily homelab access while working remotely
- Accessing internal services while maintaining fast internet
- Mobile devices (preserves battery and data)

### Full Tunneling

**What it is:** All traffic (including internet) goes through VPN server.

**Configuration:**

```ini
AllowedIPs = 0.0.0.0/0, ::/0
```

**Advantages:**

- All traffic encrypted
- Single IP address (homelab's public IP)
- Bypass geographic restrictions
- Enhanced privacy on public WiFi

**Disadvantages:**

- Slower internet (all traffic routed through homelab)
- Higher latency
- Increased VPN bandwidth usage
- Battery drain on mobile

**Use Cases:**

- Untrusted networks (coffee shop WiFi)
- Need to appear from home IP address
- Maximum privacy required
- Accessing region-locked content

### Hybrid Approach

Route specific internet traffic through VPN while keeping most traffic direct.

**Example: Route Google through VPN**

```ini
# Split tunnel + specific public IPs
AllowedIPs = 192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16, 8.8.8.8/32, 8.8.4.4/32
```

### Testing Your Configuration

```bash
# Check routing table
# Linux:
ip route show table all | grep wg0

# macOS:
netstat -rn | grep utun

# Windows:
route print

# Test what IP websites see
curl ifconfig.me  # Your current public IP

# Verify split tunnel (should show your ISP IP)
# Verify full tunnel (should show homelab public IP)
```

## Troubleshooting

### Connection Issues

**Problem: Cannot establish connection**

**Diagnostics:**

```bash
# Check if WireGuard is running
# Linux:
sudo wg show

# Check if interface exists
ip addr show wg0

# View logs
journalctl -u wg-quick@wg0 -n 50
```

**Common causes:**

1. **Firewall blocking UDP 51820**

```bash
# Test UDP connectivity
nc -u vpn.example.com 51820

# Linux: Allow WireGuard through firewall
sudo ufw allow 51820/udp
```

2. **Wrong endpoint or port**

Verify `Endpoint` matches server's public IP/domain and port in configuration.

3. **Server not running**

Contact homelab admin to verify server status.

4. **NAT/Router issues**

Try adding `PersistentKeepalive = 25` if not already present.

### Handshake Failures

**Problem: No handshake shown in `wg show`**

```bash
# Check WireGuard status
sudo wg show

# Look for:
# latest handshake: X seconds/minutes ago
# If "never" or very old, handshake failing
```

**Solutions:**

1. **Verify keys**

```bash
# Check your public key
wg pubkey < /etc/wireguard/wg0.conf | grep PrivateKey

# Ensure this matches what server admin added
```

2. **Check allowed IPs on server**

Server must allow your client's VPN IP (e.g., `10.200.0.2/32`).

3. **Verify endpoint reachability**

```bash
# Test if endpoint is reachable
ping vpn.example.com
nc -u -v vpn.example.com 51820
```

### No Peers Listed in `wg show`

**Problem: `wg show` displays the interface but no `[Peer]` section**

```
interface: wg0
  public key: <your-client-key>
  private key: (hidden)
  listening port: 51820
```

**Root cause:** The `PublicKey` in the `[Peer]` section of your client config is set to
your own client's public key instead of the **server's** public key. WireGuard cannot
match any peer and brings the tunnel up with no peers configured.

**Fix:** Get the server's public key and update your config:

```bash
# On the Proxmox host — get server public key
pct exec 203 -- wg show wg0 public-key

# Or read the file Ansible saved on the LXC
pct exec 203 -- cat /etc/wireguard/server_publickey

# Or use the Ansible-generated config (already has the correct key)
ls ~/.wireguard/homelab/
```

Update `/etc/wireguard/wg0.conf` — replace the `PublicKey` line under `[Peer]` with the
server's public key (not your client public key), then restart:

```bash
sudo wg-quick down wg0 && sudo wg-quick up wg0
sudo wg show  # Should now list a [Peer] section
```

### DNS Not Working

**Problem: Can ping IPs but not resolve .homelab.local names**

**Diagnostics:**

```bash
# Check DNS configuration
# Linux/macOS:
cat /etc/resolv.conf

# Should show: nameserver 192.168.0.202

# Windows:
ipconfig /all

# Look for DNS Servers: 192.168.0.202

# Test DNS directly
nslookup grafana.homelab.local 192.168.0.202
```

**Solutions:**

1. **If connecting via `nmcli`**, set DNS on the connection:

```bash
nmcli connection modify wg0 ipv4.dns "192.168.0.202" ipv4.dns-search "homelab.local"
nmcli connection down wg0 && nmcli connection up wg0
```

2. **If connecting via `wg-quick`**, add `PostUp`/`PostDown` hooks to `/etc/wireguard/wg0.conf`:

```ini
[Interface]
DNS = 192.168.0.202
PostUp = resolvectl dns %i 192.168.0.202; resolvectl domain %i ~homelab.local
PostDown = resolvectl revert %i
```

3. **Check DNS server is accessible**

```bash
ping 192.168.0.202

# If unreachable, routing issue — verify AllowedIPs includes 192.168.0.0/24
```

### `wg-quick` Fails with `resolvconf` Signature Mismatch

**Problem: `wg-quick up wg0` succeeds then immediately tears down the interface**

```
resolvconf: signature mismatch: /etc/resolv.conf
resolvconf: run `resolvconf -u` to update
[#] ip link delete dev wg0
```

**Root Cause:**

`/etc/resolv.conf` was modified outside of `resolvconf`'s management (e.g., by NetworkManager
or systemd-resolved). When `wg-quick` tries to configure DNS, it detects the checksum mismatch
and aborts, rolling back the entire interface setup.

**Solutions (in order of preference):**

**Option 1: Use `nmcli` if the config was generated by NetworkManager** (preferred — NM handles
DNS itself and avoids the conflict entirely):

```bash
sudo nmcli connection import type wireguard file /etc/wireguard/wg0.conf
nmcli connection up wg0
```

**Option 2: Update the resolvconf database first:**

```bash
sudo resolvconf -u
sudo wg-quick up wg0
```

**Option 3: Fix the symlink if using systemd-resolved (common on Arch Linux):**

```bash
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo resolvconf -u
sudo wg-quick up wg0
```

**Option 4: Remove the `DNS =` line from your config** if you don't need VPN-side DNS resolution.
The tunnel will still work; only DNS routing via the VPN is skipped.

### Routing Issues

**Problem: Can connect to VPN but not access homelab services**

**Diagnostics:**

```bash
# Check routing table
# Linux:
ip route show | grep wg0

# Should show routes for 192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16

# macOS:
netstat -rn | grep utun

# Windows:
route print | findstr "10.200"
```

**Solutions:**

1. **Verify AllowedIPs**

```ini
[Peer]
AllowedIPs = 192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16
```

2. **Check server forwarding**

Contact admin to verify server has IP forwarding enabled.

3. **Firewall on server**

Server firewall must allow traffic from VPN subnet (`10.200.0.0/24`).

### Performance Issues

**Problem: Slow speeds or high latency**

**Diagnostics:**

```bash
# Test latency
ping 192.168.0.1

# Test bandwidth
# On server:
iperf3 -s

# On client:
iperf3 -c 192.168.0.203
```

**Solutions:**

1. **Adjust MTU**

```ini
[Interface]
MTU = 1380  # Try 1380, 1360, 1280
```

2. **Check PersistentKeepalive**

Too frequent keepalives can cause overhead:

```ini
[Peer]
PersistentKeepalive = 25  # Try 0 if on stable connection
```

3. **Server resource constraints**

Contact admin to check server CPU/bandwidth usage.

### Mobile-Specific Issues

**Problem: VPN disconnects frequently on mobile**

**Solutions:**

1. **Enable PersistentKeepalive**

```ini
PersistentKeepalive = 25
```

2. **On-Demand rules (iOS)**

Configure to auto-reconnect when on WiFi/cellular.

3. **Battery optimization (Android)**

Disable battery optimization for WireGuard app:
Settings > Apps > WireGuard > Battery > Unrestricted

**Problem: High battery drain**

**Solutions:**

1. **Increase PersistentKeepalive**

```ini
PersistentKeepalive = 60  # Less frequent, saves battery
```

2. **Use on-demand rules**

Only connect when needed, not 24/7.

3. **Split tunnel instead of full tunnel**

Reduces traffic through VPN.

## Security Best Practices

### Key Management

**Do:**

- Generate unique keys for each device
- Store private keys securely (encrypted password manager)
- Use preshared keys for enhanced security
- Rotate keys periodically (every 6-12 months)

**Don't:**

- Share private keys between devices
- Commit keys to version control
- Email keys in plaintext
- Reuse keys from old/compromised devices

### Configuration Security

**File Permissions:**

```bash
# Linux/macOS: Restrict config file
chmod 600 /etc/wireguard/wg0.conf
sudo chown root:root /etc/wireguard/wg0.conf

# Verify permissions
ls -la /etc/wireguard/
```

**Secure Transmission:**

When sending public key to admin:

- Use encrypted communication (Signal, encrypted email)
- Never send private keys
- Verify admin identity before sharing

### Connection Security

**Enable Preshared Keys:**

```bash
# Generate preshared key
wg genpsk > preshared.key
chmod 600 preshared.key

# Add to configuration
[Peer]
PresharedKey = CONTENTS_OF_preshared.key
```

**Post-quantum security:** Preshared keys protect against future quantum computing attacks.

**Use Split Tunneling:**

Unless you need full tunnel, use split tunnel to minimize attack surface:

```ini
# Only route homelab traffic
AllowedIPs = 192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16
```

**Regular Updates:**

- Keep WireGuard client updated
- Update OS regularly (VPN kernel modules)
- Monitor WireGuard security advisories

### Monitoring and Auditing

**Check Active Connections:**

```bash
# Linux/macOS:
sudo wg show

# Look for unexpected handshakes
# Verify your endpoint matches expected IP
```

**Review Logs:**

```bash
# Linux:
journalctl -u wg-quick@wg0 -n 100

# Look for:
# - Unexpected connection attempts
# - Failed handshakes
# - Configuration errors
```

**Server-Side Monitoring:**

Contact admin if you suspect:

- Unauthorized access attempts
- Unusual traffic patterns
- Compromised credentials

### Compromised Key Response

**If you suspect key compromise:**

1. **Immediately notify homelab admin** to revoke access
2. **Generate new keys:**

```bash
# Generate new keypair
wg genkey | tee new-privatekey | wg pubkey > new-publickey

# Update configuration with new private key
sudo nano /etc/wireguard/wg0.conf

# Send new public key to admin
cat new-publickey
```

3. **Securely delete old keys:**

```bash
shred -u old-privatekey
shred -u preshared.key
```

4. **Restart VPN with new configuration**

### Best Practices Checklist

- [ ] Unique keys for each device
- [ ] Private keys stored securely (600 permissions)
- [ ] Preshared keys enabled
- [ ] Split tunneling configured (unless full tunnel needed)
- [ ] DNS configured to use homelab DNS
- [ ] VPN auto-disconnect on sleep (for laptops)
- [ ] Regular key rotation scheduled
- [ ] Monitoring enabled and reviewed
- [ ] Strong authentication on devices with VPN access
- [ ] VPN configuration backed up securely

### Additional Security Layers

**Device Security:**

- Full disk encryption (FileVault, BitLocker, LUKS)
- Strong device passwords/biometrics
- Screen lock when unattended
- Updated OS and applications

**Network Security:**

- Avoid public WiFi when possible
- Use full tunnel on untrusted networks
- Enable firewall on client device
- Disable unused network services

**Operational Security:**

- Don't access sensitive services on shared devices
- Clear browser cache/cookies regularly
- Use HTTPS for all web services
- Enable 2FA on homelab services

## Quick Reference

### Common Commands

**Linux/macOS:**

```bash
# Start VPN
sudo wg-quick up wg0

# Stop VPN
sudo wg-quick down wg0

# Check status
sudo wg show

# View logs
journalctl -u wg-quick@wg0 -f

# Test connectivity
ping 192.168.0.1
```

**Windows:**

Use WireGuard GUI application or PowerShell with admin rights.

### Configuration Template

Save as `homelab-vpn.conf`:

```ini
[Interface]
PrivateKey = REPLACE_WITH_YOUR_PRIVATE_KEY
Address = 10.200.0.X/32
DNS = 192.168.0.202
# For Linux with NetworkManager/systemd-resolved, add these two lines:
PostUp = resolvectl dns %i 192.168.0.202; resolvectl domain %i ~homelab.local
PostDown = resolvectl revert %i

[Peer]
PublicKey = REPLACE_WITH_SERVER_PUBLIC_KEY
PresharedKey = REPLACE_WITH_PRESHARED_KEY
Endpoint = REPLACE_WITH_PUBLIC_IP_OR_DOMAIN:51820
AllowedIPs = 192.168.0.0/24, 10.42.0.0/16, 10.43.0.0/16
PersistentKeepalive = 25
```

### Service Access

Once connected to VPN:

- **Grafana**: `http://grafana.homelab.local` or `http://192.168.0.201:3000`
- **Prometheus**: `http://prometheus.homelab.local` or `http://192.168.0.200:9090`
- **Home Assistant**: `http://homeassistant.homelab.local` or `http://192.168.0.208:8123`
- **AdGuard**: `http://adguard.homelab.local` or `http://192.168.0.204`
- **Traefik**: `http://traefik.homelab.local` or `http://192.168.0.205:8080`

### Getting Help

**Client-side issues:**

1. Check this troubleshooting guide
2. Verify configuration matches template
3. Test basic connectivity (ping gateway)
4. Review logs for errors

**Server-side issues:**

Contact your homelab administrator for:

- Adding new clients
- Revoking compromised keys
- Server status/debugging
- Network configuration changes

**Useful resources:**

- [WireGuard Official Documentation](https://www.wireguard.com/)
- [WireGuard Quick Start](https://www.wireguard.com/quickstart/)
- Homelab documentation: `/docs/` directory

---

**Last Updated:** 2026-02-01

**Version:** 1.0

**Feedback:** Submit issues or improvements to your homelab administrator.
