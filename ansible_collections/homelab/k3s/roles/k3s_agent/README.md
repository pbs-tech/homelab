# K3s Agent Role

Deploys and configures K3s agent (worker) nodes that join an existing K3s cluster. Agent nodes run workloads and connect to the server nodes for cluster management.

## Features

- **Automatic Cluster Join** - Joins K3s cluster using server token
- **Version Management** - Intelligent version detection and upgrade handling
- **Service Configuration** - Systemd service management for k3s-agent
- **Dynamic Token Retrieval** - Automatically retrieves join token from server nodes
- **Configuration File Support** - Optional YAML configuration for agent settings
- **Airgap Support** - Works with airgap role for offline installations
- **Resource Optimization** - Configurable for resource-constrained environments

## Requirements

- Ubuntu 22.04 LTS, Raspberry Pi OS, or other supported Linux distributions
- Root or sudo access
- Network connectivity to K3s server nodes
- K3s server must be deployed and running
- homelab.common collection installed
- prereq role must be executed before this role

## Role Variables

### Agent Configuration

```yaml
# K3s version to install (should match server version)
k3s_version: "v1.28.3+k3s1"

# Systemd directory
systemd_dir: /etc/systemd/system

# API server port
api_port: 6443

# Server data directory
k3s_server_location: /var/lib/rancher/k3s
```

### Inventory Groups

```yaml
# Server group name (must match inventory)
server_group: server

# Cluster token (retrieved from first server automatically)
# token is set dynamically from hostvars[groups[server_group][0]].token
```

### Agent-Specific Settings

```yaml
# Extra arguments for K3s agent
extra_agent_args: "--node-label environment=homelab"

# Extra environment variables for installation
extra_install_envs:
  INSTALL_K3S_CHANNEL: "stable"

# Extra environment variables for systemd service
extra_service_envs:
  - "K3S_NODE_NAME={{ inventory_hostname }}"
```

### Optional Configuration

```yaml
# Optional agent configuration file
agent_config_yaml: |
  node-label:
    - "node.kubernetes.io/workload=general"
    - "topology.kubernetes.io/zone=homelab"
  node-taint:
    - "key=value:NoSchedule"
  kubelet-arg:
    - "max-pods=110"
    - "eviction-hard=memory.available<100Mi"
```

## Usage

### Basic Agent Deployment

```yaml
- hosts: agent
  become: yes
  roles:
    - homelab.k3s.prereq
    - homelab.k3s.raspberrypi
    - homelab.k3s.k3s_agent
```

### With Custom Node Labels

```yaml
- hosts: agent
  become: yes
  vars:
    extra_agent_args: "--node-label node-type=worker --node-label region=main"
  roles:
    - homelab.k3s.prereq
    - homelab.k3s.raspberrypi
    - homelab.k3s.k3s_agent
```

### With Resource Constraints

```yaml
- hosts: agent
  become: yes
  vars:
    agent_config_yaml: |
      kubelet-arg:
        - "max-pods=50"
        - "kube-reserved=cpu=200m,memory=200Mi"
        - "system-reserved=cpu=200m,memory=200Mi"
        - "eviction-hard=memory.available<100Mi"
        - "eviction-soft=memory.available<200Mi"
        - "eviction-soft-grace-period=memory.available=2m"
  roles:
    - homelab.k3s.prereq
    - homelab.k3s.raspberrypi
    - homelab.k3s.k3s_agent
```

### With Node Taints

```yaml
- hosts: agent
  become: yes
  vars:
    agent_config_yaml: |
      node-taint:
        - "workload=batch:NoSchedule"
      node-label:
        - "node.kubernetes.io/workload=batch"
  roles:
    - homelab.k3s.prereq
    - homelab.k3s.k3s_agent
```

## Deployment Process

### Version Detection

1. **Check Installed Version** - Detects current K3s version if installed
2. **Version Comparison** - Determines if upgrade is needed
3. **Skip Download (Current)** - Skips installation if version matches

### Artifact Download

1. **Download Install Script** - Downloads K3s installation script
2. **Install K3s Agent** - Runs installation with agent-specific settings
3. **Airgap Mode** - Uses pre-staged artifacts if airgap_dir is defined

### Configuration Setup

1. **Create Config Directory** - Creates /etc/rancher/k3s if needed
2. **Deploy Configuration** - Writes agent_config_yaml if provided
3. **Set Permissions** - Ensures proper file permissions

### Token and Environment

1. **Retrieve Token** - Gets cluster join token from first server
2. **Environment Setup** - Creates k3s-agent.service.env file
3. **Token Validation** - Ensures token matches across restarts
4. **Service Variables** - Adds extra environment variables

### Service Management

1. **Deploy Service File** - Creates systemd service from template
2. **Enable Service** - Enables k3s-agent for automatic startup
3. **Start/Restart Service** - Starts or restarts based on changes
4. **Daemon Reload** - Reloads systemd when service file changes

## Tasks Overview

### Pre-Installation Tasks

- Check for existing K3s installation
- Detect installed version
- Compare with target version
- Determine if installation/upgrade needed

### Installation Tasks

- Download K3s install script (if not airgapped)
- Execute installation with agent parameters
- Configure systemd directories
- Set file permissions

### Configuration Tasks

- Create configuration directory
- Deploy agent configuration YAML
- Set up environment variables
- Configure cluster join token

### Service Tasks

- Deploy k3s-agent systemd service
- Configure service environment
- Enable service for auto-start
- Start or restart service as needed

## Files and Templates

### Service Templates

- **k3s-agent.service.j2** - Systemd service file for K3s agent

### Configuration Files

- **/etc/rancher/k3s/config.yaml** - Agent configuration (optional)
- **/etc/systemd/system/k3s-agent.service.env** - Environment variables
- **/etc/systemd/system/k3s-agent.service** - Systemd service file

### Runtime Files

- **/var/lib/rancher/k3s/** - K3s data directory
- **/usr/local/bin/k3s** - K3s binary
- **/usr/local/bin/k3s-install.sh** - Installation script

## Handlers

This role does not define handlers. Service management is handled inline with conditional restarts based on configuration changes.

## Dependencies

- homelab.k3s.prereq - Must be run before this role
- homelab.k3s.raspberrypi - Recommended for Raspberry Pi deployments
- homelab.k3s.k3s_server - Server nodes must be deployed first
- community.general (for systemd modules)
- ansible.posix (for sysctl modules)

## Integration Points

### With Server Nodes

- Retrieves join token from first server via hostvars
- Connects to server API endpoint for cluster operations
- Registers with server node as cluster member

### With Monitoring

- Exposes kubelet metrics on port 10250
- Can be scraped by Prometheus for monitoring
- ServiceMonitors can target agent nodes

### With Workloads

- Runs Pods scheduled by Kubernetes scheduler
- Manages container runtime (containerd)
- Handles CNI networking (Flannel by default)

## Node Management

### Checking Node Status

```bash
# From server node
k3s kubectl get nodes
k3s kubectl describe node <agent-hostname>

# Check agent service
systemctl status k3s-agent
```

### Viewing Agent Logs

```bash
# Service logs
journalctl -u k3s-agent -f

# Full logs with timestamps
journalctl -u k3s-agent --since "1 hour ago"
```

### Node Labels and Taints

```bash
# View node labels
k3s kubectl get nodes --show-labels

# View node taints
k3s kubectl describe node <node-name> | grep Taints

# Add label manually
k3s kubectl label node <node-name> key=value

# Add taint manually
k3s kubectl taint node <node-name> key=value:NoSchedule
```

## Troubleshooting

### Agent Won't Join Cluster

```bash
# Check agent service status
systemctl status k3s-agent

# View detailed logs
journalctl -xeu k3s-agent

# Verify token
cat /etc/systemd/system/k3s-agent.service.env | grep K3S_TOKEN

# Check server connectivity
ping <server-ip>
nc -zv <server-ip> 6443
```

### Token Mismatch

```bash
# Verify token on server
ssh server-node "cat /var/lib/rancher/k3s/server/token"

# Check token on agent
cat /etc/systemd/system/k3s-agent.service.env

# Update token and restart
systemctl restart k3s-agent
```

### Network Issues

```bash
# Check Flannel CNI
ip link show flannel.1

# Verify routing
ip route show

# Check iptables rules
iptables -L -n -v

# Test pod network
k3s kubectl run test --image=busybox --restart=Never -- ping -c 3 google.com
```

### Resource Constraints

```bash
# Check node resources
k3s kubectl describe node <node-name>

# View resource usage
k3s kubectl top node <node-name>

# Check for pressure
k3s kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="MemoryPressure")].status}'
```

## Security Considerations

- **Token Security** - Join token provides cluster access, protect carefully
- **Node Authentication** - Agents authenticate to server with token and certificates
- **Network Security** - Secure communication between agents and servers
- **Container Isolation** - containerd provides container isolation
- **Resource Limits** - Configure resource limits to prevent DoS
- **Kernel Security** - Use security hardening role for kernel parameters

## Performance Considerations

- **Join Time** - Agent typically joins cluster within 10-30 seconds
- **Resource Requirements** - Minimum 512MB RAM, 1GB recommended
- **Storage** - Fast storage recommended for container images
- **Network Latency** - Low latency to server nodes improves performance
- **Pod Density** - Default max-pods is 110, adjust based on resources

## Node Configuration Best Practices

- **Consistent Versions** - Ensure agent version matches server version
- **Resource Allocation** - Reserve resources for system and kubelet
- **Eviction Policies** - Configure eviction thresholds to prevent OOM
- **Node Labels** - Use labels for workload scheduling and organization
- **Taints** - Apply taints for specialized workloads
- **Monitoring** - Enable metrics collection for visibility

## Common Use Cases

### General Purpose Worker Nodes

```yaml
extra_agent_args: "--node-label node-type=worker"
```

### Dedicated Storage Nodes

```yaml
agent_config_yaml: |
  node-label:
    - "node.kubernetes.io/storage=true"
  node-taint:
    - "storage=true:NoSchedule"
```

### Edge Computing Nodes

```yaml
agent_config_yaml: |
  node-label:
    - "node.kubernetes.io/location=edge"
    - "node.kubernetes.io/network=local"
  kubelet-arg:
    - "max-pods=30"
```

### GPU Worker Nodes

```yaml
agent_config_yaml: |
  node-label:
    - "accelerator=nvidia-gpu"
  kubelet-arg:
    - "feature-gates=DevicePlugins=true"
```

## License

Apache License 2.0 - See collection LICENSE file for details.
