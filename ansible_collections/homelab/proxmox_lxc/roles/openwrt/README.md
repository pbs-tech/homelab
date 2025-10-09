# OpenWrt Role

Deploys and configures OpenWrt as a virtualized network router/firewall in an LXC container using QEMU/KVM. Provides advanced routing, firewall, VPN, and network management capabilities for homelab infrastructure.

## Features

- **Advanced Routing** - Static routes, policy-based routing, and multi-WAN support
- **Firewall** - Stateful packet filtering with zone-based firewall configuration
- **VPN Support** - WireGuard, OpenVPN, and IPsec VPN server and client
- **DHCP/DNS** - Integrated DHCP server and DNS resolver with dnsmasq
- **QoS** - Traffic shaping and quality of service controls
- **VLAN Support** - 802.1Q VLAN tagging for network segmentation
- **Web Interface** - LuCI web interface for easy management
- **Package Ecosystem** - Extensive package repository for additional functionality
- **Network Monitoring** - Built-in monitoring and logging capabilities

## Requirements

- Proxmox VE with LXC support and nested virtualization enabled
- Ubuntu 22.04 LTS template
- KVM support on Proxmox host
- Sufficient network interfaces or bridges for WAN/LAN connectivity
- QEMU and virtualization tools installed

## Architecture

This role deploys OpenWrt in a nested virtualization setup:

1. LXC container on Proxmox host
2. QEMU/KVM running inside LXC container
3. OpenWrt image running in QEMU VM
4. Virtual network bridges for WAN/LAN connectivity

```
Proxmox Host
  └── LXC Container (192.168.0.209)
      └── QEMU/KVM Process
          └── OpenWrt Router (192.168.1.1)
              ├── WAN Interface (eth0)
              └── LAN Interface (eth1)
```

## Role Variables

### Container Configuration

```yaml
# Container resource allocation
openwrt_resources:
  memory: 1024          # Memory in MB
  cores: 2              # CPU cores
  disk_size: "20"       # Disk size in GB

# Network configuration
openwrt_ip: "192.168.0.209"
openwrt_container_id: 209
openwrt_node: "pve-mac"  # Proxmox node name
```

### OpenWrt Version and Image

```yaml
# OpenWrt version configuration
openwrt_version: "23.05.4"
openwrt_arch: "x86_64"
openwrt_release_url: >
  https://downloads.openwrt.org/releases/{{ openwrt_version }}/targets/x86/64/
  openwrt-{{ openwrt_version }}-x86-64-generic-squashfs-combined.img.gz

# VM resource allocation (inside QEMU)
openwrt_vm_memory: "512M"
openwrt_vm_cores: 2
openwrt_vm_disk_size: "1G"
```

### Network Interface Configuration

```yaml
# Physical interface mapping
openwrt_wan_interface: "eth0"  # WAN connection
openwrt_lan_interface: "eth1"  # LAN network

# LAN network configuration
openwrt_lan_network: "192.168.1.0/24"
openwrt_lan_ip: "192.168.1.1"
openwrt_lan_netmask: "255.255.255.0"
```

### DHCP Configuration

```yaml
# DHCP server settings
openwrt_dhcp_enabled: true
openwrt_dhcp_start: 100        # Start of DHCP range (.100)
openwrt_dhcp_limit: 150        # Number of addresses in pool
openwrt_dhcp_lease: "24h"      # Lease time

# DHCP options
openwrt_dhcp_domain: "lan"
openwrt_dhcp_option:
  - "6,192.168.0.202,192.168.0.204"  # DNS servers
```

### DNS Configuration

```yaml
# DNS server configuration
openwrt_dns_servers:
  - "192.168.0.202"  # Unbound
  - "192.168.0.204"  # AdGuard Home

# DNS forwarding
openwrt_dns_forward_enabled: true
openwrt_dns_rebind_protection: true
```

### Firewall Configuration

```yaml
# Firewall zones
openwrt_firewall_zones:
  wan:
    input: REJECT
    output: ACCEPT
    forward: REJECT
    masq: true
  lan:
    input: ACCEPT
    output: ACCEPT
    forward: ACCEPT

# SSH access
openwrt_ssh_port: 22
openwrt_ssh_wan_access: false  # Disable SSH from WAN

# Web interface
openwrt_luci_port: 80
openwrt_luci_wan_access: false  # Disable LuCI from WAN

# VPN passthrough
openwrt_enable_vpn_passthrough: true
```

### Package Configuration

```yaml
# Packages to install
openwrt_packages:
  - luci                    # Web interface
  - luci-ssl                # HTTPS for LuCI
  - luci-app-firewall       # Firewall management
  - luci-app-ddns           # Dynamic DNS
  - luci-app-upnp           # UPnP support
  - wireguard-tools         # WireGuard VPN
  - kmod-wireguard          # WireGuard kernel module
  - luci-app-sqm            # QoS (optional)
  - luci-app-statistics     # Network statistics (optional)
```

### System Configuration

```yaml
# System settings
openwrt_hostname: "openwrt-router"
openwrt_timezone: "UTC"

# Root password (use Ansible Vault)
openwrt_root_password_hash: "{{ vault_openwrt_root_password_hash | mandatory }}"

# NTP servers
openwrt_ntp_servers:
  - "0.openwrt.pool.ntp.org"
  - "1.openwrt.pool.ntp.org"
```

### Logging Configuration

```yaml
# System logging
openwrt_log_level: "info"  # debug, info, notice, warn, err
openwrt_log_size: 64       # KB
openwrt_log_buffer_size: 64

# Remote syslog
openwrt_remote_syslog_server: "192.168.0.211"  # Loki/Logstash
openwrt_remote_syslog_port: 514
openwrt_remote_syslog_protocol: "udp"
```

### Wireless Configuration (Optional)

```yaml
# Wireless settings (if hardware supports)
openwrt_enable_wifi: false
openwrt_wifi_ssid: "OpenWrt"
openwrt_wifi_encryption: "psk2"
openwrt_wifi_password: "{{ vault_openwrt_wifi_password }}"
openwrt_wifi_channel: 11
openwrt_wifi_country: "US"
```

## Usage

### Basic Deployment

```yaml
- hosts: proxmox_hosts
  roles:
    - homelab.proxmox_lxc.openwrt
```

### Custom Network Configuration

```yaml
- hosts: proxmox_hosts
  vars:
    openwrt_lan_network: "10.0.0.0/24"
    openwrt_lan_ip: "10.0.0.1"
    openwrt_dhcp_start: 50
    openwrt_dhcp_limit: 200
    openwrt_dns_servers:
      - "192.168.0.202"
      - "1.1.1.1"
  roles:
    - homelab.proxmox_lxc.openwrt
```

### High-Performance Router

```yaml
- hosts: proxmox_hosts
  vars:
    openwrt_resources:
      memory: 2048
      cores: 4
      disk_size: "30"
    openwrt_vm_memory: "1024M"
    openwrt_vm_cores: 4
    openwrt_packages:
      - luci
      - luci-ssl
      - luci-app-firewall
      - luci-app-sqm
      - luci-app-statistics
      - wireguard-tools
      - kmod-wireguard
  roles:
    - homelab.proxmox_lxc.openwrt
```

## Initial Setup

### Post-Deployment Configuration

1. Access LuCI web interface at `http://192.168.1.1` (from LAN network)
2. Login with root and configured password
3. Complete initial setup wizard
4. Configure WAN interface for internet connectivity
5. Set up firewall rules and port forwarding as needed

### Network Bridge Setup (Proxmox Host)

Before deploying, ensure network bridges exist on the Proxmox host:

```bash
# On Proxmox host
# Create WAN bridge
ip link add br-wan type bridge
ip link set br-wan up

# Create LAN bridge (OpenWrt managed network)
ip link add br-openwrt type bridge
ip link set br-openwrt up

# Optional: Add physical interface to WAN bridge
ip link set eth1 master br-wan
```

Or configure in `/etc/network/interfaces`:

```
auto br-wan
iface br-wan inet manual
    bridge_ports eth1
    bridge_stp off
    bridge_fd 0

auto br-openwrt
iface br-openwrt inet manual
    bridge_ports none
    bridge_stp off
    bridge_fd 0
```

### LXC Container Configuration

The LXC container requires specific capabilities for nested virtualization:

```bash
# On Proxmox host - set container features
pct set 209 -features nesting=1,keyctl=1
pct set 209 -unprivileged 0  # Must be privileged for KVM

# Add network interfaces
pct set 209 -net0 name=eth0,bridge=vmbr0,ip=192.168.0.209/24,gw=192.168.0.1
pct set 209 -net1 name=eth1,bridge=br-wan
pct set 209 -net2 name=eth2,bridge=br-openwrt
```

## Management

### OpenWrt Management Script

The role installs `/usr/local/bin/manage-openwrt` for easy management:

```bash
# Start OpenWrt
pct exec 209 -- manage-openwrt start

# Stop OpenWrt
pct exec 209 -- manage-openwrt stop

# Restart OpenWrt
pct exec 209 -- manage-openwrt restart

# Check status
pct exec 209 -- manage-openwrt status
```

### Systemd Service

OpenWrt runs as a systemd service in the container:

```bash
# Check service status
pct exec 209 -- systemctl status openwrt

# View logs
pct exec 209 -- journalctl -u openwrt -f

# Enable/disable autostart
pct exec 209 -- systemctl enable openwrt
pct exec 209 -- systemctl disable openwrt
```

## Files and Templates

### Configuration Templates

- **network.j2** - UCI network interface configuration
- **system.j2** - UCI system configuration (hostname, timezone, etc.)
- **firewall.j2** - UCI firewall zone and rule configuration
- **dhcp.j2** - UCI DHCP and DNS configuration
- **wireless.j2** - UCI wireless configuration (if enabled)

### Management Scripts

- **manage-openwrt.sh.j2** - OpenWrt VM management script
- **openwrt.service.j2** - Systemd service unit file

### Logging Configuration

- **rsyslog-openwrt.conf.j2** - Remote syslog forwarding configuration

## Dependencies

- homelab.common.container_base
- homelab.common.security_hardening

## Handlers

- `reload systemd` - Reload systemd daemon
- `restart openwrt` - Restart OpenWrt VM
- `restart rsyslog` - Restart rsyslog service

## Examples

### Complete Router Setup

```yaml
- name: Deploy OpenWrt router with VPN
  hosts: proxmox_hosts
  vars:
    openwrt_resources:
      memory: 2048
      cores: 2
      disk_size: "30"

    openwrt_lan_network: "192.168.1.0/24"
    openwrt_lan_ip: "192.168.1.1"

    openwrt_dhcp_enabled: true
    openwrt_dhcp_start: 100
    openwrt_dhcp_limit: 150

    openwrt_dns_servers:
      - "192.168.0.202"  # Unbound
      - "192.168.0.204"  # AdGuard

    openwrt_packages:
      - luci
      - luci-ssl
      - luci-app-firewall
      - luci-app-ddns
      - wireguard-tools
      - kmod-wireguard
      - luci-app-wireguard
      - luci-app-sqm

    openwrt_remote_syslog_server: "192.168.0.211"

  roles:
    - homelab.proxmox_lxc.openwrt
```

### Guest Network Router

```yaml
- name: Deploy OpenWrt for guest network
  hosts: proxmox_hosts
  vars:
    openwrt_hostname: "guest-router"
    openwrt_lan_network: "192.168.100.0/24"
    openwrt_lan_ip: "192.168.100.1"

    openwrt_dhcp_start: 10
    openwrt_dhcp_limit: 240

    # Isolated guest network - no LAN access
    openwrt_firewall_zones:
      wan:
        input: REJECT
        output: ACCEPT
        forward: REJECT
        masq: true
      lan:
        input: ACCEPT
        output: ACCEPT
        forward: REJECT  # Block inter-VLAN routing

  roles:
    - homelab.proxmox_lxc.openwrt
```

## Troubleshooting

### QEMU/KVM Issues

```bash
# Check if KVM is available
pct exec 209 -- lsmod | grep kvm
pct exec 209 -- ls -la /dev/kvm

# Verify QEMU installation
pct exec 209 -- qemu-system-x86_64 --version

# Check VM process
pct exec 209 -- ps aux | grep qemu
pct exec 209 -- cat /var/run/openwrt.pid
```

### Network Connectivity Issues

```bash
# Check bridge status on host
ip link show br-wan
ip link show br-openwrt

# Verify LXC container network config
pct config 209 | grep net

# Check OpenWrt network interfaces
pct exec 209 -- ip link show
pct exec 209 -- ip addr show

# Monitor QEMU console output
pct exec 209 -- tail -f /var/log/openwrt/console.log
```

### OpenWrt Access Issues

```bash
# Connect to QEMU monitor
pct exec 209 -- socat - unix-connect:/var/run/openwrt.monitor

# In monitor, check VM status:
# > info status
# > info network

# Reset OpenWrt to defaults (if locked out)
# This requires accessing OpenWrt console during boot
pct exec 209 -- manage-openwrt stop
# Edit /opt/openwrt/config/network manually
pct exec 209 -- manage-openwrt start
```

### Service Not Starting

```bash
# Check systemd service logs
pct exec 209 -- journalctl -u openwrt -n 50 --no-pager

# Verify disk image
pct exec 209 -- ls -lh /opt/openwrt/openwrt.qcow2
pct exec 209 -- qemu-img info /opt/openwrt/openwrt.qcow2

# Check for port conflicts
pct exec 209 -- ss -tulpn | grep qemu

# Validate management script
pct exec 209 -- bash -x /usr/local/bin/manage-openwrt status
```

### Performance Issues

```bash
# Monitor VM resource usage
pct exec 209 -- htop

# Check QEMU CPU usage
pct exec 209 -- top -b -n 1 | grep qemu

# Verify KVM acceleration is enabled
pct exec 209 -- ps aux | grep qemu | grep "\-enable-kvm"

# Monitor network throughput
pct exec 209 -- iftop
```

### Configuration Issues

```bash
# Validate UCI configuration
# Access OpenWrt via console
pct exec 209 -- socat - unix-connect:/var/run/openwrt.monitor
# Then in QEMU console: uci show network

# Export current configuration
# SSH into OpenWrt and backup
ssh root@192.168.1.1 "sysupgrade -b /tmp/backup.tar.gz"

# Apply configuration changes
ssh root@192.168.1.1 "uci commit && /etc/init.d/network restart"
```

## Security Considerations

- **Privileged Container** - OpenWrt container must run privileged for KVM access
- **Network Isolation** - Properly segment WAN/LAN networks with bridges
- **Password Security** - Use strong root password, store in Ansible Vault
- **WAN Access** - Disable SSH and LuCI access from WAN interface
- **Firewall Rules** - Configure strict firewall rules, default deny
- **Updates** - Regularly update OpenWrt for security patches
- **VPN Security** - Use strong encryption for VPN configurations
- **Remote Access** - Use VPN for remote management, not direct WAN exposure

## Performance Tuning

- **CPU Allocation** - Assign sufficient cores for routing throughput
- **Memory** - 512MB minimum, 1GB+ recommended for many packages
- **Disk I/O** - Use SSD storage for better package management performance
- **Network Offloading** - Enable hardware offloading if supported
- **QoS** - Configure SQM (Smart Queue Management) for traffic shaping
- **Connection Tracking** - Adjust conntrack table size for high connection counts

## Advanced Configuration

### Port Forwarding

```bash
# SSH to OpenWrt
ssh root@192.168.1.1

# Add port forward rule
uci add firewall redirect
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].src_dport='8080'
uci set firewall.@redirect[-1].dest='lan'
uci set firewall.@redirect[-1].dest_ip='192.168.1.100'
uci set firewall.@redirect[-1].dest_port='80'
uci set firewall.@redirect[-1].proto='tcp'
uci commit firewall
/etc/init.d/firewall restart
```

### WireGuard VPN Server

```bash
# Install WireGuard (if not already installed)
ssh root@192.168.1.1
opkg update
opkg install wireguard-tools luci-app-wireguard

# Generate keys
wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey

# Configure via LuCI or UCI
# Network -> Interfaces -> Add new interface -> Protocol: WireGuard VPN
```

### VLAN Configuration

```bash
# Configure VLAN tagging
ssh root@192.168.1.1

# Add VLAN interface
uci set network.vlan10=interface
uci set network.vlan10.ifname='eth1.10'
uci set network.vlan10.proto='static'
uci set network.vlan10.ipaddr='192.168.10.1'
uci set network.vlan10.netmask='255.255.255.0'
uci commit network
/etc/init.d/network restart
```

## Integration with Homelab Services

- **Unbound/AdGuard** - DNS resolution for network clients
- **WireGuard** - VPN connectivity for remote access
- **Traefik** - Reverse proxy for internal services
- **Prometheus** - Network metrics monitoring
- **Loki** - Centralized log aggregation
- **DHCP** - Network device registration and tracking

## Backup and Recovery

### Configuration Backup

```bash
# Backup OpenWrt configuration
ssh root@192.168.1.1 "sysupgrade -b /tmp/backup-$(date +%Y%m%d).tar.gz"
scp root@192.168.1.1:/tmp/backup-*.tar.gz /mnt/backups/openwrt/

# Backup QEMU disk image
pct exec 209 -- cp /opt/openwrt/openwrt.qcow2 /mnt/backups/openwrt/openwrt-$(date +%Y%m%d).qcow2

# Backup UCI configuration files
pct exec 209 -- tar -czf /tmp/openwrt-uci-backup.tar.gz /opt/openwrt/config/
```

### Restore Configuration

```bash
# Restore OpenWrt from backup
scp /mnt/backups/openwrt/backup-20231215.tar.gz root@192.168.1.1:/tmp/
ssh root@192.168.1.1 "sysupgrade -r /tmp/backup-20231215.tar.gz"

# Restore QEMU disk image
pct exec 209 -- manage-openwrt stop
pct exec 209 -- cp /mnt/backups/openwrt/openwrt-20231215.qcow2 /opt/openwrt/openwrt.qcow2
pct exec 209 -- manage-openwrt start
```

## Upgrade Process

### OpenWrt Upgrade

```bash
# Download new firmware
ssh root@192.168.1.1
cd /tmp
wget https://downloads.openwrt.org/releases/23.05.4/targets/x86/64/openwrt-23.05.4-x86-64-generic-squashfs-combined.img.gz

# Backup before upgrade
sysupgrade -b /tmp/backup-pre-upgrade.tar.gz

# Upgrade (preserves configuration)
sysupgrade -v openwrt-23.05.4-x86-64-generic-squashfs-combined.img.gz
```

## License

MIT License - See collection LICENSE file for details.
