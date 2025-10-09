# K3s Agent Role

Installs and configures K3s agent (worker) nodes that join an existing K3s cluster. Manages agent installation, cluster token authentication, and service lifecycle for compute workload nodes.

## Features

- **Automatic Server Discovery** - Connects to K3s server nodes automatically
- **Token Authentication** - Retrieves cluster token from server nodes
- **Version Management** - Intelligent version detection and upgrade handling
- **Configuration Support** - YAML-based agent configuration
- **Service Management** - Systemd service creation and lifecycle
- **Idempotent Operations** - Safe to run multiple times
- **Architecture Support** - Supports AMD64, ARM64, and ARM architectures
- **Airgap Support** - Works with airgapped installations
- **Resource Flexibility** - Configurable resource allocation
- **Health Verification** - Validates agent joins cluster successfully

## Requirements

- Ansible core 2.14 or higher
- Ubuntu 20.04+, Debian 11+, RHEL 8+, or Arch Linux
- Root or sudo access
- K3s server nodes already deployed
- Network connectivity to K3s server API (port 6443)
- Prerequisites configured (via prereq role)
- Minimum 1GB RAM (2GB+ recommended)

## Role Variables

### Agent Configuration

```yaml
# K3s version to install
k3s_version: "v1.28.5+k3s1"

# K3s data directory
k3s_server_location: /var/lib/rancher/k3s

# Systemd directory
systemd_dir: /etc/systemd/system

# Server node group name (for token retrieval)
server_group: server

# API server port
api_port: 6443
```

### Agent Arguments

```yaml
# Extra agent arguments
extra_agent_args: ""

# Extra installation environment variables
extra_install_envs: {}

# Extra service environment variables
extra_service_envs:
  - "NO_PROXY=localhost,127.0.0.1,10.0.0.0/8"
```

### Agent Configuration File

```yaml
# Optional K3s agent configuration (YAML)
agent_config_yaml: |
  node-label:
    - "workload=general"
    - "zone=us-east-1a"
  node-taint:
    - "gpu=true:NoSchedule"
  kubelet-arg:
    - "max-pods=150"
    - "image-gc-high-threshold=85"
    - "image-gc-low-threshold=80"
```

## Usage

### Basic Agent Deployment

```yaml
- name: Deploy K3s agent nodes
  hosts: k3s_agents
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
  roles:
    - homelab.proxmox_lxc.prereq
    - homelab.proxmox_lxc.k3s_agent
```

### With Custom Configuration

```yaml
- name: Deploy K3s agents with custom configuration
  hosts: k3s_agents
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
    agent_config_yaml: |
      node-label:
        - "role=worker"
        - "tier=compute"
      kubelet-arg:
        - "max-pods=200"
        - "eviction-hard=memory.available<500Mi"
  roles:
    - homelab.proxmox_lxc.k3s_agent
```

### GPU Worker Nodes

```yaml
- name: Deploy GPU-enabled agent nodes
  hosts: gpu_agents
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
    agent_config_yaml: |
      node-label:
        - "nvidia.com/gpu=true"
        - "workload=ml"
      node-taint:
        - "nvidia.com/gpu=true:NoSchedule"
  roles:
    - homelab.proxmox_lxc.k3s_agent

  post_tasks:
    - name: Install NVIDIA Container Toolkit
      apt:
        name: nvidia-container-toolkit
        state: present
```

### Multi-Zone Deployment

```yaml
- name: Deploy agents across availability zones
  hosts: k3s_agents
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
  roles:
    - homelab.proxmox_lxc.k3s_agent

  tasks:
    - name: Label nodes by zone
      command: >
        kubectl label node {{ inventory_hostname }}
        topology.kubernetes.io/zone={{ availability_zone }}
        --overwrite
      delegate_to: "{{ groups['k3s_servers'][0] }}"
      run_once: false
```

## Deployment Workflow

1. **Version Detection** - Checks installed K3s version
2. **Binary Download** - Downloads K3s if needed (or uses airgap)
3. **Config File** - Creates /etc/rancher/k3s/config.yaml if provided
4. **Token Retrieval** - Gets cluster token from first server node
5. **Environment Setup** - Configures service environment variables
6. **Service Creation** - Creates k3s-agent systemd service
7. **Service Start** - Starts and enables k3s-agent service

## Tasks Overview

The role performs the following operations:

1. **Version Detection** - Checks installed K3s version
2. **Binary Download** - Downloads K3s agent binary if needed
3. **Config File Setup** - Creates agent configuration file
4. **Token Retrieval** - Gets cluster token from server nodes
5. **Environment Variables** - Sets service environment variables
6. **Token Configuration** - Adds cluster token to service environment
7. **Service File Creation** - Creates k3s-agent.service systemd unit
8. **Service Start** - Starts and enables agent service

## Dependencies

This role requires:

- homelab.proxmox_lxc.prereq (or equivalent prerequisites)
- homelab.proxmox_lxc.k3s_server (must be deployed first)

## Files and Templates

### Service Template

- **k3s-agent.service.j2** - Agent systemd service template

### Configuration Files

```bash
/etc/rancher/k3s/config.yaml          # Agent configuration
/etc/systemd/system/k3s-agent.service # Systemd service
/etc/systemd/system/k3s-agent.service.env  # Service environment
```

### Service Environment Variables

```bash
K3S_TOKEN=<cluster-token>             # Cluster authentication token
K3S_URL=https://<server-ip>:6443      # Server API endpoint
```

## Handlers

This role does not define handlers. Service management is handled inline with conditional restarts.

## Examples

### Complete Cluster Deployment

```yaml
- name: Deploy K3s servers
  hosts: k3s_servers
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
  roles:
    - homelab.proxmox_lxc.prereq
    - homelab.proxmox_lxc.k3s_server

- name: Deploy K3s agents
  hosts: k3s_agents
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
  roles:
    - homelab.proxmox_lxc.prereq
    - homelab.proxmox_lxc.k3s_agent

- name: Verify cluster
  hosts: k3s_servers[0]
  become: yes
  tasks:
    - name: Wait for all nodes to be ready
      command: kubectl wait --for=condition=Ready node --all --timeout=300s
      register: wait_result
      retries: 3
      delay: 10
      until: wait_result.rc == 0

    - name: Get cluster nodes
      command: kubectl get nodes -o wide
      register: nodes
      changed_when: false

    - name: Display cluster status
      debug:
        var: nodes.stdout_lines
```

### Heterogeneous Cluster

```yaml
- name: Deploy mixed workload agents
  hosts: k3s_agents
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"

  tasks:
    - name: Configure general purpose agents
      include_role:
        name: homelab.proxmox_lxc.k3s_agent
      vars:
        agent_config_yaml: |
          node-label:
            - "workload=general"
      when: "'general' in group_names"

    - name: Configure database agents
      include_role:
        name: homelab.proxmox_lxc.k3s_agent
      vars:
        agent_config_yaml: |
          node-label:
            - "workload=database"
            - "storage=ssd"
          node-taint:
            - "workload=database:NoSchedule"
      when: "'database' in group_names"

    - name: Configure batch processing agents
      include_role:
        name: homelab.proxmox_lxc.k3s_agent
      vars:
        agent_config_yaml: |
          node-label:
            - "workload=batch"
            - "priority=low"
          kubelet-arg:
            - "max-pods=250"
      when: "'batch' in group_names"
```

### Raspberry Pi Agents

```yaml
- name: Deploy K3s agents on Raspberry Pi
  hosts: raspberrypi_agents
  become: yes
  vars:
    k3s_version: "v1.28.5+k3s1"
  roles:
    - homelab.proxmox_lxc.raspberrypi
    - homelab.proxmox_lxc.prereq
    - homelab.proxmox_lxc.k3s_agent

  post_tasks:
    - name: Configure Raspberry Pi-specific settings
      include_tasks: rpi_agent_config.yml
      when: raspberry_pi | default(false)
```

## Troubleshooting

### Agent Won't Start

```bash
# Check service status
sudo systemctl status k3s-agent

# View service logs
sudo journalctl -u k3s-agent -f

# Check agent logs
sudo k3s agent --help

# Verify server connectivity
curl -k https://<server-ip>:6443/version
```

### Token Issues

```bash
# Verify token in service environment
sudo cat /etc/systemd/system/k3s-agent.service.env | grep K3S_TOKEN

# Check token on server
ssh <server> sudo cat /var/lib/rancher/k3s/server/token

# Verify server URL
sudo cat /etc/systemd/system/k3s-agent.service.env | grep K3S_URL
```

### Node Not Joining Cluster

```bash
# Check from server node
kubectl get nodes

# View node events
kubectl describe node <agent-hostname>

# Check network connectivity
ping <server-ip>
nc -zv <server-ip> 6443

# Verify firewall rules
sudo ufw status
```

### Version Mismatch

```bash
# Check agent version
k3s --version

# Check server version
ssh <server> k3s --version

# Verify installed version
sudo systemctl cat k3s-agent | grep INSTALL_K3S_VERSION
```

## Security Considerations

- **Token Security** - Cluster token provides full cluster access
- **Network Security** - Secure communication between agents and servers
- **Node Authorization** - Enable Node authorization mode
- **TLS Certificates** - Verify TLS certificate validation
- **RBAC** - Ensure proper RBAC for kubelet
- **Pod Security** - Apply pod security standards to workloads
- **Image Security** - Scan container images for vulnerabilities
- **Resource Limits** - Set appropriate resource limits

## Performance Tuning

### Resource Allocation

```yaml
agent_config_yaml: |
  kubelet-arg:
    - "max-pods=150"              # Maximum pods per node
    - "pods-per-core=10"          # Pods per CPU core
    - "kube-reserved=cpu=200m,memory=512Mi"  # Reserve for Kubernetes
    - "system-reserved=cpu=200m,memory=512Mi"  # Reserve for OS
```

### Image Management

```yaml
agent_config_yaml: |
  kubelet-arg:
    - "image-gc-high-threshold=85"  # Start garbage collection
    - "image-gc-low-threshold=80"   # Stop garbage collection
    - "serialize-image-pulls=false" # Parallel image pulls
```

### Network Performance

```yaml
agent_config_yaml: |
  kubelet-arg:
    - "network-plugin=cni"
    - "cni-bin-dir=/opt/cni/bin"
    - "cni-conf-dir=/etc/cni/net.d"
```

## Node Labels and Taints

### Common Node Labels

```yaml
# Hardware type
node-label:
  - "node.kubernetes.io/instance-type=c5.2xlarge"
  - "kubernetes.io/arch=amd64"
  - "kubernetes.io/os=linux"

# Workload type
node-label:
  - "workload=compute"
  - "tier=production"

# Location
node-label:
  - "topology.kubernetes.io/region=us-east-1"
  - "topology.kubernetes.io/zone=us-east-1a"

# Hardware features
node-label:
  - "nvidia.com/gpu=true"
  - "storage=ssd"
```

### Common Node Taints

```yaml
# Dedicated nodes
node-taint:
  - "dedicated=database:NoSchedule"

# GPU nodes
node-taint:
  - "nvidia.com/gpu=true:NoSchedule"

# Experimental nodes
node-taint:
  - "experimental=true:NoExecute"
```

## Scaling Considerations

- **Horizontal Scaling** - Add more agent nodes for capacity
- **Resource Planning** - Plan CPU/memory based on workloads
- **Network Capacity** - Ensure adequate network bandwidth
- **Storage Planning** - Consider storage requirements per node
- **Monitoring** - Monitor resource utilization

## Upgrade Considerations

- **Version Compatibility** - Maintain compatibility with server version
- **Rolling Upgrades** - Upgrade agents gradually
- **Workload Migration** - Drain nodes before upgrading
- **Testing** - Test in non-production first
- **Use k3s_upgrade Role** - Consider dedicated upgrade role

## Integration with Server Nodes

The agent role automatically:

1. Discovers server nodes from inventory (server_group)
2. Retrieves cluster token from first server
3. Configures server URL for agent communication
4. Joins cluster with proper authentication

## License

Apache License 2.0 - See collection LICENSE file for details.
