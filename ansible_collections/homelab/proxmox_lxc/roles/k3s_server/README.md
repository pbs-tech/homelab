# K3s Server Role

Installs and configures K3s server (control plane) nodes with support for single-node deployments, high-availability clusters, and external database integration. Manages cluster initialization, token distribution, kubeconfig setup, and node verification.

## Features

- **Single Node Support** - Deploy standalone K3s server
- **High Availability** - Multi-server cluster with embedded etcd
- **External Database** - Support for external PostgreSQL/MySQL
- **Automatic Token Management** - Generates or uses provided cluster tokens
- **Kubeconfig Distribution** - Automatically configures kubectl on control node
- **Version Management** - Intelligent version detection and upgrade handling
- **Service Management** - Systemd service creation and lifecycle management
- **User kubectl Setup** - Optional kubectl configuration for cluster users
- **Cluster Verification** - Validates all server nodes join successfully
- **Configuration File Support** - YAML-based server configuration
- **Idempotent Operations** - Safe to run multiple times

## Requirements

- Ansible core 2.14 or higher
- Ubuntu 20.04+, Debian 11+, RHEL 8+, or Arch Linux
- Root or sudo access
- Network connectivity for K3s download (unless airgapped)
- Prerequisites configured (via prereq role)
- Minimum 2GB RAM (4GB+ recommended for HA)

## Role Variables

### Server Configuration

```yaml
# K3s version to install
k3s_version: "v1.28.5+k3s1"

# K3s data directory
k3s_server_location: /var/lib/rancher/k3s

# Systemd directory
systemd_dir: /etc/systemd/system

# Server node group name
server_group: server

# Agent node group name (for token distribution)
agent_group: agent
```

### Cluster Configuration

```yaml
# API server port
api_port: 6443

# API endpoint for kubeconfig (usually first server IP)
api_endpoint: 192.168.0.111

# Cluster token (optional, auto-generated if not provided)
token: "{{ vault_k3s_token | default(omit) }}"

# External database (optional)
use_external_database: false
datastore_endpoint: "postgres://user:pass@host:5432/k3s"
```

### Kubeconfig Settings

```yaml
# Kubeconfig location on control node
kubeconfig: ~/.kube/config.new

# Cluster context name
cluster_context: k3s-ansible

# Configure kubectl for ansible_user
user_kubectl: true
```

### Server Configuration File

```yaml
# Optional K3s server configuration (YAML)
server_config_yaml: |
  cluster-cidr: "10.42.0.0/16"
  service-cidr: "10.43.0.0/16"
  disable:
    - traefik
    - servicelb
  tls-san:
    - k3s.example.com
    - 192.168.0.100
  kube-apiserver-arg:
    - "audit-log-path=/var/log/k3s/audit.log"
    - "audit-log-maxage=30"
```

### Extra Configuration

```yaml
# Extra server arguments
extra_server_args: ""

# Extra installation environment variables
extra_install_envs: {}

# Extra service environment variables
extra_service_envs:
  - "NO_PROXY=localhost,127.0.0.1,0.0.0.0,10.0.0.0/8,192.168.0.0/16"
```

## Usage

### Single Server Deployment

```yaml
- name: Deploy single K3s server
  hosts: k3s_server
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
  roles:
    - homelab.proxmox_lxc.prereq
    - homelab.proxmox_lxc.k3s_server
```

### High Availability Cluster

```yaml
- name: Deploy HA K3s cluster
  hosts: k3s_servers
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
    token: "{{ vault_k3s_cluster_token }}"
  roles:
    - homelab.proxmox_lxc.prereq
    - homelab.proxmox_lxc.k3s_server
```

### With External Database

```yaml
- name: Deploy K3s with external PostgreSQL
  hosts: k3s_servers
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
    use_external_database: true
    datastore_endpoint: "postgres://k3s:{{ vault_db_password }}@postgres.example.com:5432/k3s"
  roles:
    - homelab.proxmox_lxc.k3s_server
```

### With Custom Configuration

```yaml
- name: Deploy K3s server with custom configuration
  hosts: k3s_servers
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
    server_config_yaml: |
      cluster-cidr: "10.50.0.0/16"
      service-cidr: "10.51.0.0/16"
      disable:
        - traefik
      tls-san:
        - k3s-api.homelab.local
        - 192.168.0.110
      kube-apiserver-arg:
        - "oidc-issuer-url=https://dex.example.com"
        - "oidc-client-id=k3s"
  roles:
    - homelab.proxmox_lxc.k3s_server
```

## Deployment Workflow

### Single Server

1. Download K3s binary and install script (or use airgap)
2. Copy K3s service file for single server
3. Start K3s service
4. Wait for service to be ready
5. Fetch kubeconfig and configure kubectl
6. Generate/read cluster token for agent nodes

### High Availability (First Server)

1. Download K3s binary and install script
2. Copy K3s service file with cluster-init flag
3. Add cluster token to service environment
4. Start K3s service
5. Fetch kubeconfig
6. Store cluster token for other servers

### High Availability (Additional Servers)

1. Get cluster token from first server
2. Copy K3s service file for HA mode
3. Add token and server URL to environment
4. Start K3s service
5. Verify all servers joined cluster

## Tasks Overview

The role performs the following operations:

1. **Version Detection** - Checks installed K3s version
2. **Binary Download** - Downloads K3s if needed (or uses airgap)
3. **Bash Completion** - Adds kubectl/k3s completion to user profile
4. **Config File** - Creates /etc/rancher/k3s/config.yaml if provided
5. **First Server Init** - Initializes cluster on first server node
6. **Service Creation** - Creates systemd service file
7. **Token Management** - Handles cluster token generation/distribution
8. **Service Start** - Starts and enables K3s service
9. **Kubeconfig Setup** - Configures kubectl on control node
10. **Additional Servers** - Joins remaining servers to cluster
11. **Cluster Verification** - Verifies all server nodes are ready
12. **User kubectl** - Configures kubectl for ansible_user

## Dependencies

This role requires:

- homelab.proxmox_lxc.prereq (or equivalent prerequisites)

## Files and Templates

### Service Templates

- **k3s-single.service.j2** - Single server systemd service
- **k3s-cluster-init.service.j2** - First server in HA cluster
- **k3s-ha.service.j2** - Additional servers in HA cluster

### Configuration Files

```bash
/etc/rancher/k3s/config.yaml         # Server configuration
/etc/rancher/k3s/k3s.yaml            # Kubeconfig
/etc/systemd/system/k3s.service      # Systemd service
/etc/systemd/system/k3s.service.env  # Service environment variables
```

### Kubeconfig Locations

```bash
# On server node
/etc/rancher/k3s/k3s.yaml

# On control node
~/.kube/config.new  (then merged to ~/.kube/config)

# For cluster user
~{{ ansible_user }}/.kube/config
```

## Handlers

This role does not define handlers. Service management is handled inline with conditional restarts.

## Examples

### Complete K3s Deployment

```yaml
- name: Deploy complete K3s infrastructure
  hosts: all
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
    cluster_cidr: "10.42.0.0/16"
    service_cidr: "10.43.0.0/16"

  tasks:
    - name: Configure prerequisites
      include_role:
        name: homelab.proxmox_lxc.prereq

- name: Deploy K3s servers
  hosts: k3s_servers
  become: yes
  serial: 1  # Deploy servers one at a time
  vars:
    server_config_yaml: |
      disable:
        - traefik
        - servicelb
      write-kubeconfig-mode: "0644"
  roles:
    - homelab.proxmox_lxc.k3s_server

- name: Deploy K3s agents
  hosts: k3s_agents
  become: yes
  roles:
    - homelab.proxmox_lxc.k3s_agent

- name: Verify cluster
  hosts: k3s_servers[0]
  become: yes
  tasks:
    - name: Get cluster nodes
      command: kubectl get nodes -o wide
      register: nodes
      changed_when: false

    - name: Display cluster status
      debug:
        var: nodes.stdout_lines
```

### Production HA Cluster

```yaml
- name: Deploy production K3s HA cluster
  hosts: k3s_servers
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
    token: "{{ vault_k3s_production_token }}"
    server_config_yaml: |
      cluster-cidr: "10.42.0.0/16"
      service-cidr: "10.43.0.0/16"
      disable:
        - traefik
        - local-storage
      tls-san:
        - k3s-api.prod.local
        - k3s-lb.prod.local
        - 192.168.1.100
      kube-apiserver-arg:
        - "audit-log-path=/var/log/k3s-audit.log"
        - "audit-log-maxage=30"
        - "audit-log-maxbackup=10"
        - "audit-log-maxsize=100"
      kube-controller-manager-arg:
        - "bind-address=0.0.0.0"
        - "node-monitor-period=5s"
        - "node-monitor-grace-period=20s"
      kubelet-arg:
        - "max-pods=150"

  roles:
    - homelab.proxmox_lxc.k3s_server

  post_tasks:
    - name: Wait for all servers to be ready
      command: kubectl wait --for=condition=Ready node --all --timeout=300s
      register: wait_result
      retries: 3
      delay: 10
      until: wait_result.rc == 0
      run_once: true
```

## Troubleshooting

### Server Won't Start

```bash
# Check service status
sudo systemctl status k3s

# View service logs
sudo journalctl -u k3s -f

# Check K3s server logs
sudo k3s check-config

# Verify configuration
sudo k3s server --dry-run
```

### Token Issues

```bash
# Check token file
sudo cat /var/lib/rancher/k3s/server/token

# Verify token in service environment
sudo cat /etc/systemd/system/k3s.service.env

# Reset token (if needed)
sudo rm /var/lib/rancher/k3s/server/token
sudo systemctl restart k3s
```

### Kubeconfig Problems

```bash
# Check kubeconfig exists
ls -la /etc/rancher/k3s/k3s.yaml

# Test kubeconfig locally
sudo kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get nodes

# Check permissions
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
```

### HA Cluster Issues

```bash
# Check etcd health
sudo k3s kubectl get endpoints -n kube-system kube-apiserver

# Verify all servers joined
sudo k3s kubectl get nodes -l node-role.kubernetes.io/control-plane=true

# Check etcd member list
sudo k3s etcd-snapshot save --name=test
sudo k3s etcd-snapshot ls
```

### Network/API Issues

```bash
# Test API server
curl -k https://localhost:6443/version

# Check API server arguments
ps aux | grep kube-apiserver

# Verify TLS certificates
sudo ls -la /var/lib/rancher/k3s/server/tls/
```

## Security Considerations

- **Cluster Token** - Store cluster token in Ansible Vault
- **Kubeconfig Security** - Restrict kubeconfig file permissions (600)
- **API Server TLS** - Use TLS SANs for all access methods
- **RBAC** - Enable and configure Kubernetes RBAC
- **Pod Security** - Enable Pod Security Standards
- **Audit Logging** - Enable API server audit logging
- **Network Policies** - Implement network segmentation
- **Secrets Management** - Use external secrets management (Vault, etc.)

## Performance Tuning

- **Resource Allocation** - Minimum 2 CPU cores, 4GB RAM per server
- **etcd Performance** - Use SSD storage for etcd data
- **API Server** - Tune API server flags for scale
- **Controller Manager** - Adjust monitoring intervals
- **Database Backend** - Consider external database for large clusters

## High Availability Best Practices

- **Odd Number of Servers** - Deploy 3 or 5 servers for quorum
- **Load Balancer** - Use external load balancer for API access
- **Backup Strategy** - Regular etcd snapshot backups
- **Node Placement** - Distribute servers across failure domains
- **Monitoring** - Monitor etcd and API server health

## Upgrade Considerations

- **Version Compatibility** - Check Kubernetes version skew policy
- **Rolling Upgrades** - Upgrade servers one at a time
- **Backup First** - Create etcd snapshot before upgrading
- **Test in Staging** - Test upgrades in non-production first
- **Use k3s_upgrade Role** - Consider using dedicated upgrade role

## License

Apache License 2.0 - See collection LICENSE file for details.
