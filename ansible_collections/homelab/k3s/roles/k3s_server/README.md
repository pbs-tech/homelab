# K3s Server Role

Deploys and configures K3s server (control plane) nodes for Kubernetes cluster management on Raspberry Pi and other Linux systems. Handles both single-server and high-availability (HA) multi-server deployments with embedded etcd or external database support.

## Features

- **Single and HA Deployments** - Supports single server and multi-server HA configurations
- **Automatic Token Management** - Generates or uses provided cluster tokens
- **Kubeconfig Distribution** - Automatically configures kubectl on control node
- **Version Management** - Intelligent version detection and upgrade handling
- **External Database Support** - Optional external database instead of embedded etcd
- **Service Account Integration** - Configures service accounts and RBAC
- **Auto-completion Setup** - Configures kubectl and k3s command completion
- **User kubectl Access** - Optional kubectl configuration for non-root users

## Requirements

- Ubuntu 22.04 LTS, Raspberry Pi OS, or other supported Linux distributions
- Root or sudo access
- Network connectivity for K3s installation (unless using airgap mode)
- homelab.common collection installed
- prereq role must be executed before this role

## Role Variables

### Server Configuration

```yaml
# K3s version to install
k3s_version: "v1.28.3+k3s1"

# Server data directory
k3s_server_location: /var/lib/rancher/k3s

# Systemd directory
systemd_dir: /etc/systemd/system

# Inventory groups
server_group: server
agent_group: agent
```

### API and Network Settings

```yaml
# API server port
api_port: 6443

# API endpoint for kubeconfig (IP or hostname)
api_endpoint: "{{ ansible_default_ipv4.address }}"

# Cluster context name
cluster_context: k3s-ansible
```

### Authentication and Security

```yaml
# Cluster join token (optional - will be generated if not provided)
# token: "your-secure-token-here"

# Optional server configuration file
server_config_yaml: |
  write-kubeconfig-mode: "0644"
  tls-san:
    - "k3s.homelab.local"
    - "192.168.0.111"
  disable:
    - traefik  # Disable if using external Traefik
```

### High Availability Configuration

```yaml
# Use external database for HA (instead of embedded etcd)
use_external_database: false

# External database connection (if use_external_database is true)
# datastore_endpoint: "mysql://username:password@tcp(hostname:3306)/database"
```

### Installation Options

```yaml
# Extra arguments for K3s server
extra_server_args: "--disable traefik --disable servicelb"

# Extra environment variables for installation
extra_install_envs:
  INSTALL_K3S_CHANNEL: "stable"

# Extra environment variables for systemd service
extra_service_envs:
  - "K3S_NODE_NAME={{ inventory_hostname }}"
  - "K3S_CLUSTER_INIT=true"
```

### Kubeconfig Options

```yaml
# Kubeconfig destination on control node
kubeconfig: ~/.kube/config.new

# Setup kubectl for ansible_user on cluster nodes
user_kubectl: true
```

## Usage

### Basic Single Server Deployment

```yaml
- hosts: server
  become: yes
  roles:
    - homelab.k3s.prereq
    - homelab.k3s.raspberrypi
    - homelab.k3s.k3s_server
```

### High Availability Multi-Server Deployment

```yaml
- hosts: server
  become: yes
  vars:
    k3s_version: "v1.28.3+k3s1"
    server_config_yaml: |
      write-kubeconfig-mode: "0644"
      cluster-cidr: "10.42.0.0/16"
      service-cidr: "10.43.0.0/16"
  roles:
    - homelab.k3s.prereq
    - homelab.k3s.raspberrypi
    - homelab.k3s.k3s_server
```

### With External Database

```yaml
- hosts: server
  become: yes
  vars:
    use_external_database: true
    extra_server_args: "--datastore-endpoint=mysql://k3s:password@tcp(mysql.homelab.local:3306)/k3s"
  roles:
    - homelab.k3s.prereq
    - homelab.k3s.k3s_server
```

### Custom Configuration with Security Hardening

```yaml
- hosts: server
  become: yes
  vars:
    k3s_version: "v1.28.3+k3s1"
    server_config_yaml: |
      write-kubeconfig-mode: "0640"
      tls-san:
        - "k3s.homelab.local"
      secrets-encryption: true
      protect-kernel-defaults: true
      kube-apiserver-arg:
        - "audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log"
        - "audit-log-maxage=30"
        - "audit-log-maxbackup=10"
        - "audit-log-maxsize=100"
    extra_server_args: "--disable traefik --disable servicelb --protect-kernel-defaults"
  roles:
    - homelab.k3s.prereq
    - homelab.k3s.raspberrypi
    - homelab.k3s.security_hardening
    - homelab.k3s.k3s_server
```

## Deployment Modes

### Single Server Mode

- Creates standalone K3s server without HA
- Uses embedded SQLite database
- Suitable for development or small deployments
- Automatically configured when only one server in inventory

### HA Mode (Embedded etcd)

- Creates multi-server cluster with embedded etcd
- First server initializes with `--cluster-init`
- Additional servers join with `--server` flag
- Requires 3 or 5 servers for etcd quorum
- Automatically configured when multiple servers in inventory

### HA Mode (External Database)

- Uses external MySQL or PostgreSQL database
- All servers connect to shared database
- No etcd quorum requirements
- Enables 2-node HA configurations
- Activated with `use_external_database: true`

## Tasks Overview

### Version Management

1. **Check Installed Version** - Detects current K3s version if installed
2. **Version Comparison** - Determines if upgrade is needed
3. **Download Artifacts** - Downloads install script and binary if needed
4. **Skip Download (Airgap)** - Uses pre-staged artifacts in airgap mode

### First Server Initialization

1. **Service File Creation** - Creates appropriate systemd service file
2. **Token Management** - Generates or uses provided cluster token
3. **Service Start** - Enables and starts K3s service
4. **Kubeconfig Distribution** - Copies kubeconfig to control node
5. **Context Configuration** - Sets up kubectl context
6. **Token Retrieval** - Retrieves generated token for other nodes

### Additional Server Setup

1. **Token Retrieval** - Gets token from first server
2. **Service Configuration** - Creates HA-specific service file
3. **Cluster Join** - Joins existing cluster
4. **Node Verification** - Verifies all servers joined successfully

### User Configuration

1. **Kubectl Directory** - Creates .kube directory for user
2. **Kubeconfig Copy** - Copies kubeconfig to user directory
3. **Environment Setup** - Configures KUBECONFIG environment variable
4. **Auto-completion** - Sets up kubectl and k3s auto-completion

## Files and Templates

### Service Templates

- **k3s-single.service.j2** - Single server service file
- **k3s-cluster-init.service.j2** - First server in HA cluster
- **k3s-ha.service.j2** - Additional servers in HA cluster

### Configuration Files

- **/etc/rancher/k3s/config.yaml** - Server configuration
- **/etc/systemd/system/k3s.service.env** - Environment variables
- **/etc/rancher/k3s/k3s.yaml** - Kubeconfig file

## Handlers

This role does not define handlers. Service management is handled inline with conditional restarts based on configuration changes.

## Dependencies

- homelab.k3s.prereq - Must be run before this role
- homelab.k3s.raspberrypi - Recommended for Raspberry Pi deployments
- community.general (for ufw, systemd modules)
- ansible.posix (for sysctl, mount modules)

## Integration Points

### With Agent Nodes

- Generates token used by agent nodes to join cluster
- Token stored in hostvars for agent access
- API endpoint configured for agent communication

### With Traefik (External)

- Can disable built-in Traefik with `--disable traefik`
- Configures TLS SANs for external reverse proxy
- Service account and RBAC for Traefik integration

### With Monitoring

- Exposes metrics on port 10250 (kubelet)
- API server metrics available on 6443
- Can configure ServiceMonitors for Prometheus

## Cluster Operations

### Checking Cluster Status

```bash
# On server node
k3s kubectl get nodes
k3s kubectl cluster-info

# From control node (after kubeconfig distribution)
kubectl get nodes
kubectl get pods -A
```

### Accessing Cluster API

```bash
# View kubeconfig
cat /etc/rancher/k3s/k3s.yaml

# Use kubectl from server node
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

### Viewing Logs

```bash
# Service logs
journalctl -u k3s -f

# K3s server logs
tail -f /var/log/k3s.log
```

## Troubleshooting

### Server Won't Start

```bash
# Check service status
systemctl status k3s

# View detailed logs
journalctl -xeu k3s

# Check for port conflicts
netstat -tlnp | grep 6443

# Verify prerequisites
sysctl net.ipv4.ip_forward
```

### HA Cluster Issues

```bash
# Check etcd health
k3s kubectl get endpoints -n kube-system

# Verify all servers joined
k3s kubectl get nodes -o wide

# Check etcd member list
k3s etcd-snapshot ls
```

### Kubeconfig Problems

```bash
# Verify kubeconfig exists
ls -la /etc/rancher/k3s/k3s.yaml

# Check permissions
ls -la ~/.kube/config

# Test connectivity
kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get nodes
```

### Token Issues

```bash
# View token
cat /var/lib/rancher/k3s/server/token

# Verify token in environment
cat /etc/systemd/system/k3s.service.env | grep K3S_TOKEN
```

## Security Considerations

- **Token Security** - Cluster token provides full cluster access, protect carefully
- **Kubeconfig Permissions** - Default permissions are 0644, consider more restrictive
- **API Server Exposure** - Secure API endpoint with firewall rules
- **TLS Certificates** - K3s auto-generates TLS certs, rotate regularly
- **Secrets Encryption** - Enable secrets encryption at rest with `secrets-encryption: true`
- **Audit Logging** - Enable audit logs for compliance requirements
- **RBAC** - Configure role-based access control for users and services

## Performance Considerations

- **First Server** - Requires 30-60 seconds to initialize on Raspberry Pi
- **HA Join Time** - Additional servers need 10-20 seconds after first server ready
- **Resource Requirements** - Server node needs minimum 1GB RAM, 2GB recommended
- **Storage** - Embedded etcd requires fast storage (SD card acceptable for homelab)
- **Network** - Low latency required between server nodes in HA setup

## High Availability Best Practices

- **Server Count** - Use 3 or 5 servers for etcd quorum (odd numbers preferred)
- **Geographic Distribution** - Distribute servers across failure domains
- **Load Balancing** - Use external load balancer for API endpoint
- **Backup Strategy** - Regular etcd snapshots recommended
- **Upgrade Process** - Upgrade servers one at a time to maintain availability

## License

Apache License 2.0 - See collection LICENSE file for details.
