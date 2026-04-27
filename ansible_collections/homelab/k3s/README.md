# Homelab K3s Collection

An Ansible collection for deploying and managing K3s Kubernetes clusters on Raspberry Pi nodes, with integrated security hardening and monitoring.

## Features

- **Automated K3s deployment** on Raspberry Pi hardware
- **High availability** cluster configuration
- **Security hardening** with CIS benchmarks compliance
- **Integrated monitoring** with Prometheus and Grafana
- **Traefik integration** for unified ingress with LXC services
- **Airgap installation** support for offline environments

## Architecture

```text
┌─────────────────────────────────────────────────────┐
│                K3s Cluster                          │
│                                                     │
│  ┌──────────────┐  ┌──────────────┐ ┌─────────────┐ │
│  │   k3-01      │  │   k3-02      │ │   k3-03     │ │
│  │ (Server)     │  │ (Agent)      │ │  (Agent)    │ │
│  │ .111         │  │ .112         │ │   .113      │ │
│  └──────────────┘  └──────────────┘ └─────────────┘ │
│                                                     │
│  ┌──────────────┐                                   │
│  │   k3-04      │                                   │
│  │ (Agent)      │                                   │
│  │ .114         │                                   │
│  └──────────────┘                                   │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │   Traefik LXC        │
              │   192.168.0.205      │
              │ (Ingress Controller) │
              └──────────────────────┘
```

## Requirements

- Ansible >= 2.15.0
- Raspberry Pi nodes with SSH access
- Ubuntu Server 22.04 LTS (recommended)
- homelab.common collection installed
- Network connectivity between nodes

## Installation

```bash
# Install the collection
ansible-galaxy collection install homelab.k3s

# Or install from source
ansible-galaxy collection install -p . /path/to/homelab/k3s

# Install dependencies
ansible-galaxy install -r requirements.yml
```

## Usage

### Basic Deployment

```bash
cd ansible_collections/homelab/k3s/
ansible-playbook playbooks/site.yml
```

### Cluster Management

```bash
# Deploy K3s cluster
ansible-playbook playbooks/site.yml

# Upgrade cluster
ansible-playbook playbooks/upgrade.yml

# Reset cluster (destructive)
ansible-playbook playbooks/reset.yml

# Security hardening only
ansible-playbook playbooks/security-hardening.yml
```

### Selective Deployment

```bash
# Deploy prerequisites only
ansible-playbook playbooks/site.yml --tags "prereq"

# Deploy server nodes only
ansible-playbook playbooks/site.yml --tags "k3s_server"

# Deploy agent nodes only
ansible-playbook playbooks/site.yml --tags "k3s_agent"

# Security hardening only
ansible-playbook playbooks/site.yml --tags "security"
```

## Configuration

### Inventory Setup

Configure your Raspberry Pi nodes in `inventory/hosts.yml`:

```yaml
all:
  children:
    k3s_cluster:
      children:
        server:
          hosts:
            k3-01:
              ansible_host: 192.168.0.111
              ansible_user: pbs
        agent:
          hosts:
            k3-02:
              ansible_host: 192.168.0.112
              ansible_user: pbs
            k3-03:
              ansible_host: 192.168.0.113
              ansible_user: pbs
            k3-04:
              ansible_host: 192.168.0.114
              ansible_user: pbs
```

### Cluster Configuration

Customize cluster settings in `inventory/group_vars/all.yml`:

```yaml
# K3s version and configuration
k3s_version: v1.28.3+k3s2
k3s_token: "{{ vault_k3s_token }}"

# Network configuration
k3s_server_location: "/var/lib/rancher/k3s"
k3s_cluster_cidr: "10.42.0.0/16"
k3s_service_cidr: "10.43.0.0/16"

# Feature gates
k3s_server_config_yaml: |
  cluster-init: true
  disable:
    - traefik  # Using external Traefik LXC
  write-kubeconfig-mode: "0644"
  node-label:
    - "node.kubernetes.io/instance-type=raspberry-pi"
```

### Security Configuration

Enable security hardening:

```yaml
# Security settings
security_hardening_enabled: true
k3s_audit_log_enabled: true

# CIS compliance
k3s_enable_cis_hardening: true
k3s_pod_security_standards: restricted
```

### Resource Management

Configure resource limits:

```yaml
# Node resource configuration
k3s_node_resources:
  memory_limit: "2Gi"
  cpu_limit: "2000m"
  ephemeral_storage: "10Gi"

# Default pod resources
k3s_default_resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

## Roles

### prereq

System prerequisites and package installation.

**Features:**

- Package management for Raspberry Pi
- Kernel modules configuration
- cgroups v2 setup
- Network optimization

### raspberrypi

Raspberry Pi specific optimizations.

**Features:**

- GPU memory split configuration
- Boot configuration optimization
- Hardware-specific tuning
- Performance optimizations

### k3s_server

K3s server node deployment.

**Features:**

- K3s server installation
- Cluster initialization
- Token management
- High availability configuration

### k3s_agent

K3s agent node deployment.

**Features:**

- Agent node joining
- Server discovery
- Node labeling
- Resource configuration

### k3s_upgrade

Cluster upgrade management.

**Features:**

- Rolling upgrade strategy
- Version compatibility checking
- Backup before upgrade
- Rollback capability

### security_hardening

Security configuration and hardening.

**Features:**

- CIS Kubernetes Benchmark compliance
- Pod Security Standards enforcement
- Network policies implementation
- RBAC configuration
- Audit logging setup

## Integration

### Traefik LXC Integration

The K3s collection integrates with Traefik running in LXC:

```yaml
# Traefik integration settings
traefik_k3s_integration:
  enabled: true
  kubeconfig_path: "/var/lib/rancher/k3s/server/cred/admin.kubeconfig"
  service_account: "traefik-ingress-controller"
  namespace: "traefik-system"
```

### Monitoring Integration

Integration with Prometheus and Grafana:

```yaml
# Monitoring configuration
monitoring_enabled: true
node_exporter_port: 9100
kubelet_metrics_enabled: true

# Prometheus integration
prometheus_k3s_config:
  scrape_configs:
    - job_name: 'kubernetes-nodes'
      kubernetes_sd_configs:
        - role: node
```

### Service Mesh Integration

Optional service mesh deployment:

```yaml
# Service mesh options
service_mesh:
  enabled: false
  type: "linkerd"  # or "istio"
  monitoring: true
```

## Security

### Security Features

- **CIS Benchmark compliance** - Automated hardening based on CIS Kubernetes Benchmark
- **Pod Security Standards** - Enforcement of restricted pod security policies
- **Network Policies** - Default deny network policies with selective allow rules
- **RBAC** - Least-privilege role-based access control
- **Audit Logging** - Comprehensive audit trail of API server activities
- **Secrets Management** - Encrypted secrets with proper RBAC

### Security Configuration

Enable comprehensive security:

```yaml
security_config:
  cis_hardening: true
  pod_security_standards: "restricted"
  network_policies: true
  audit_logging: true
  rbac_enabled: true
  admission_controllers:
    - "NodeRestriction"
    - "ResourceQuota"
    - "LimitRanger"
```

### Compliance

The collection helps achieve:

- CIS Kubernetes Benchmark v1.7.0
- NIST Cybersecurity Framework
- SOC 2 Type II controls
- PCI DSS requirements (where applicable)

## Monitoring and Observability

### Metrics Collection

Integrated monitoring stack:

```yaml
monitoring_stack:
  node_exporter: true
  kube_state_metrics: true
  cadvisor: true
  prometheus_operator: false  # Using external Prometheus LXC
```

### Log Aggregation

Integration with Loki:

```yaml
logging_config:
  enabled: true
  loki_endpoint: "http://192.168.0.210:3100"
  retention_period: "168h"  # 7 days
```

### Alerting Rules

Pre-configured alerting:

```yaml
alerting_rules:
  - name: "k3s-cluster-health"
    rules:
      - alert: "NodeDown"
        expr: 'up{job="kubernetes-nodes"} == 0'
        for: "5m"
        annotations:
          summary: "Node {{ $labels.instance }} is down"
```

## Backup and Recovery

### etcd Backups

Automated backup configuration:

```yaml
backup_config:
  enabled: true
  schedule: "0 2 * * *"  # Daily at 2 AM
  retention_days: 30
  storage_path: "/var/lib/rancher/k3s/server/db/snapshots"
```

### Disaster Recovery

Recovery procedures:

```bash
# List available snapshots
k3s etcd-snapshot list

# Restore from snapshot
k3s server --cluster-reset --cluster-reset-restore-path=/path/to/snapshot
```

## Testing

### Molecule Testing

```bash
cd ansible_collections/homelab/k3s/
molecule test -s raspberry-pi
```

See [TESTING.md](TESTING.md) for detailed information about Molecule 6.0+ testing, including driver configuration and requirements.

### Production Testing

```bash
# Validate cluster health
kubectl get nodes
kubectl get pods --all-namespaces

# Run cluster validation
ansible-playbook playbooks/validate.yml
```

## Troubleshooting

### Common Issues

#### Node Join Failures

```bash
# Check token validity
k3s token list

# Regenerate token
k3s token create

# Check connectivity
curl -k https://server-ip:6443/version
```

#### Performance Issues

```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Review logs
journalctl -u k3s -f
```

#### Network Connectivity

```bash
# Check CNI configuration
kubectl get pods -n kube-system | grep -E 'flannel|coredns'

# Test pod networking
kubectl run test-pod --image=busybox --rm -it -- sh
```

### Debug Mode

Enable debug logging:

```yaml
k3s_server_config_yaml: |
  log-level: debug
  alsologtostderr: true
```

## Advanced Configuration

### Custom CNI

Replace default Flannel:

```yaml
k3s_server_config_yaml: |
  flannel-backend: none
  disable-network-policy: true

# Then install Calico or Cilium
```

### Multiple Server Nodes

High availability setup:

```yaml
k3s_server_config_yaml: |
  cluster-init: true
  server: https://first-server:6443
  datastore-endpoint: "etcd"
```

### Custom Workloads

Deploy applications:

```yaml
k3s_workloads:
  - name: "hello-world"
    manifest: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: hello-world
      spec:
        replicas: 3
        selector:
          matchLabels:
            app: hello-world
        template:
          metadata:
            labels:
              app: hello-world
          spec:
            containers:
            - name: hello-world
              image: nginx:alpine
              ports:
              - containerPort: 80
```

## Contributing

1. Follow Ansible best practices
2. Update documentation for new features
3. Add molecule tests for new roles
4. Test against actual Raspberry Pi hardware
5. Submit pull requests with clear descriptions

## Version Compatibility

- Ansible: >= 2.15.0
- K3s: >= v1.25.0
- Python: >= 3.8
- Kubernetes: >= 1.25

## License

Apache License 2.0 - See LICENSE file for details.

## Support

- Documentation: See collection README files
- Issues: GitHub issue tracker
- Testing: See TESTING.md in repository root
- Security: See SECURITY.md for security policies
