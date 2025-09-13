# Proxmox LXC Collection Testing

## Quick Start

### Podman Testing (Development)
```bash
# Test basic service functionality
molecule test

# Test specific services
molecule test --tags prometheus,grafana
```

### Real Infrastructure Testing
```bash
# Set required environment variables
export PROXMOX_PASSWORD="your-password"
export CONTAINER_PASSWORD="test-password"

# Test on actual LXC containers
molecule test -s proxmox-integration

# Test service integration
molecule test -s service-stack
```

## Available Test Scenarios

### `default` - Podman-based Testing
- **Platform**: Podman containers
- **Purpose**: Fast development feedback
- **Services Tested**: Prometheus, Grafana, Loki, Promtail
- **Runtime**: ~5-10 minutes

### `proxmox-integration` - Real LXC Testing  
- **Platform**: Proxmox LXC (pve-mac:192.168.0.56)
- **Purpose**: Production-like validation
- **Container**: 192.168.0.250 (auto-created/destroyed)
- **Services Tested**: Core monitoring stack
- **Runtime**: ~10-15 minutes

### `service-stack` - Multi-Service Integration
- **Platform**: Podman (multi-container)
- **Purpose**: Test service interactions
- **Services Tested**: Monitoring + Networking stacks
- **Runtime**: ~10-15 minutes

## Test Coverage

| Role | Unit Test | Integration | Infrastructure |
|------|-----------|-------------|----------------|
| prometheus | ✅ | ✅ | ✅ |
| grafana | ✅ | ✅ | ✅ |
| loki | ✅ | ✅ | ✅ |
| promtail | ✅ | ✅ | ✅ |
| traefik | ✅ | ✅ | ⚠️ |
| unbound | ⚠️ | ⚠️ | ⚠️ |
| openwrt | ⚠️ | ⚠️ | ⚠️ |

## Environment Setup

### Required Collections
```bash
ansible-galaxy install -r requirements.yml
```

### Environment Variables
```bash
# For Proxmox testing
export PROXMOX_PASSWORD="your-proxmox-root-password"
export CONTAINER_PASSWORD="password-for-test-containers" 
export SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"

# Optional overrides
export PROXMOX_HOST="192.168.0.56"  # Default: pve-mac
export PROXMOX_NODE="pve-mac"       # Default: pve-mac
```

## Troubleshooting

### Proxmox Connection Issues
```bash
# Test Proxmox API connectivity
curl -k -d "username=root@pam&password=$PROXMOX_PASSWORD" \
  https://192.168.0.56:8006/api2/json/access/ticket
```

### Container Creation Failures
- Check IP 192.168.0.250 is available
- Verify container template exists: `ubuntu-22.04-standard_22.04-1_amd64.tar.zst`
- Ensure sufficient resources on Proxmox node

### Service Startup Issues
```bash
# Debug running container
molecule login -s proxmox-integration -h molecule-test-lxc
systemctl status prometheus
journalctl -u prometheus -n 50
```