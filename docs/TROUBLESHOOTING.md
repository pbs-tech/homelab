# Homelab Troubleshooting Guide

Comprehensive troubleshooting guide for common issues in the homelab infrastructure, covering deployment problems, service issues, networking problems, and performance optimization.

## Quick Diagnostics

### System Health Check

```bash
#!/bin/bash
# homelab-health-check.sh

echo "=== Homelab Health Check ==="

# Check Proxmox hosts
echo "Checking Proxmox hosts..."
for host in pve-mac pve-nas; do
  echo -n "$host: "
  ping -c1 -W2 $host.homelab.local >/dev/null 2>&1 && echo "OK" || echo "FAILED"
done

# Check K3s nodes
echo "Checking K3s nodes..."
for i in {1..4}; do
  echo -n "k3s-0$i: "
  ping -c1 -W2 192.168.0.11$i >/dev/null 2>&1 && echo "OK" || echo "FAILED"
done

# Check core services
echo "Checking core services..."
services=("traefik:205" "prometheus:200" "grafana:201" "adguard:204")
for service in "${services[@]}"; do
  name=${service%:*}
  ip=${service#*:}
  echo -n "$name (192.168.0.$ip): "
  curl -s -o /dev/null -w "%{http_code}" "http://192.168.0.$ip" | grep -q "200\|401\|302" && echo "OK" || echo "FAILED"
done

echo "=== Health Check Complete ==="
```

## Common Issues and Solutions

### Deployment Issues

#### 1. Container Creation Failures

**Symptoms:**

- LXC container creation fails
- "Template not found" errors
- Resource allocation failures

**Diagnostics:**

```bash
# Check Proxmox API connectivity
curl -k -u "root@pam:password" "https://pve-mac:8006/api2/json/version"

# Verify template availability
pveam available | grep ubuntu-22.04
pveam list local

# Check storage availability
pvesh get /nodes/pve-mac/storage/local/status
df -h /var/lib/vz
```

**Solutions:**

```bash
# Download missing templates
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst

# Clean up storage space
pveam remove local:vztmpl/old-template.tar.zst
pct destroy old_container_id

# Fix permissions
chown -R root:root /var/lib/vz/template/cache
chmod 644 /var/lib/vz/template/cache/*.tar.zst
```

#### 2. Ansible Connection Issues

**Symptoms:**

- SSH connection timeouts
- "Unreachable" host errors
- Permission denied errors

**Diagnostics:**

```bash
# Test basic connectivity
ansible all -m ping -i inventory/hosts.yml

# Check SSH configuration
ssh -vvv pbs@192.168.0.200

# Verify SSH keys
ssh-add -l
```

**Solutions:**

```bash
# Fix SSH key permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# Add SSH key to agent
ssh-add ~/.ssh/id_rsa

# Update known_hosts
ssh-keyscan 192.168.0.200 >> ~/.ssh/known_hosts
```

#### 3. Playbook Execution Errors

**Symptoms:**

- Task failures during deployment
- Variable undefined errors
- Template rendering failures

**Diagnostics:**

```bash
# Run with maximum verbosity
ansible-playbook -vvv site.yml --tags "traefik"

# Check variable definitions
ansible-inventory --list -i inventory/hosts.yml | jq '.all.vars'

# Validate templates locally
ansible localhost -m template -a "src=template.j2 dest=/tmp/test.conf"
```

**Solutions:**

```bash
# Use check mode to validate
ansible-playbook --check --diff site.yml

# Run step by step
ansible-playbook site.yml --step --start-at-task="Install packages"

# Override problematic variables
ansible-playbook site.yml -e "problematic_var=fixed_value"
```

### Service Issues

#### 1. Traefik Problems

**Symptoms:**

- Services not accessible via domain names
- SSL certificate errors
- "Gateway timeout" errors

**Diagnostics:**

```bash
# Check Traefik logs
pct exec 205 -- journalctl -u traefik -f

# Verify configuration
pct exec 205 -- traefik validate --configfile=/etc/traefik/traefik.yml

# Check service discovery
curl -s "https://traefik.homelab.local:8080/api/http/routers" | jq '.'

# Test backend connectivity
curl -v http://192.168.0.200:9090/metrics
```

**Solutions:**

```bash
# Restart Traefik service
pct exec 205 -- systemctl restart traefik

# Fix certificate permissions
pct exec 205 -- chmod 600 /etc/traefik/acme.json

# Update DNS resolution
echo "192.168.0.205 prometheus.homelab.local" >> /etc/hosts

# Regenerate certificates
pct exec 205 -- rm /etc/traefik/acme.json
pct exec 205 -- systemctl restart traefik
```

#### 2. Prometheus Issues

**Symptoms:**

- Targets down in Prometheus
- Missing metrics
- High memory usage

**Diagnostics:**

```bash
# Check Prometheus status
curl -s http://192.168.0.200:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'

# Verify configuration
pct exec 200 -- promtool check config /etc/prometheus/prometheus.yml

# Check disk space
pct exec 200 -- df -h /var/lib/prometheus

# Monitor memory usage
pct exec 200 -- ps aux --sort=-%mem | head -10
```

**Solutions:**

```bash
# Restart Prometheus
pct exec 200 -- systemctl restart prometheus

# Clean old data
pct exec 200 -- find /var/lib/prometheus/data -name "*.tmp" -delete

# Adjust retention policy
pct exec 200 -- sed -i 's/--storage.tsdb.retention.time=15d/--storage.tsdb.retention.time=7d/' /etc/systemd/system/prometheus.service

# Increase container memory
pct set 200 -memory 4096
pct reboot 200
```

#### 3. DNS Resolution Problems

**Symptoms:**

- Domain names not resolving
- Slow DNS queries
- Ad blocking not working

**Diagnostics:**

```bash
# Test DNS resolution
nslookup prometheus.homelab.local 192.168.0.204
dig @192.168.0.202 google.com

# Check AdGuard Home logs
pct exec 204 -- tail -f /opt/adguard/logs/querylog.json

# Verify Unbound configuration
pct exec 202 -- unbound-checkconf /etc/unbound/unbound.conf
```

**Solutions:**

```bash
# Restart DNS services
pct exec 204 -- systemctl restart adguard
pct exec 202 -- systemctl restart unbound

# Clear DNS cache
pct exec 204 -- AdGuardHome --config /opt/adguard/AdGuardHome.yaml --purge-cache

# Update blocklists
pct exec 204 -- curl -X POST "http://localhost/control/filtering/refresh"

# Fix DNS chain
echo "nameserver 192.168.0.204" > /etc/resolv.conf
```

#### 4. VPN Connectivity Issues

**Symptoms:**

- WireGuard connection failures
- No internet access via VPN
- Slow VPN performance

**Diagnostics:**

```bash
# Check WireGuard status
pct exec 203 -- wg show
pct exec 203 -- systemctl status wg-quick@wg0

# Test connectivity
ping -c 3 192.168.0.203
traceroute 192.168.0.203

# Check routing
pct exec 203 -- ip route show
```

**Solutions:**

```bash
# Restart WireGuard
pct exec 203 -- systemctl restart wg-quick@wg0

# Regenerate client configs
ansible-playbook site.yml --tags "wireguard_client" -e "client_name=laptop"

# Fix IP forwarding
pct exec 203 -- echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
pct exec 203 -- sysctl -p
```

### Network Issues

#### 1. Container Network Problems

**Symptoms:**

- Containers can't reach external networks
- Inter-container communication failures
- Port binding conflicts

**Diagnostics:**

```bash
# Check container network configuration
for i in {200..210}; do
  echo "Container $i:"
  pct config $i | grep net
  pct exec $i -- ip addr show
done

# Test connectivity between containers
pct exec 200 -- ping -c 3 192.168.0.201
pct exec 205 -- telnet 192.168.0.200 9090

# Check port usage
ss -tuln | grep -E ':(80|443|9090|3000)'
```

**Solutions:**

```bash
# Fix network bridge
systemctl restart networking
brctl show

# Restart problematic containers
pct stop 200 && pct start 200

# Fix IP conflicts
pct set 200 -net0 name=eth0,bridge=vmbr0,ip=192.168.0.200/24,gw=192.168.0.1
```

#### 2. Firewall Issues

**Symptoms:**

- Services not accessible from specific networks
- Connection timeouts
- Blocked legitimate traffic

**Diagnostics:**

```bash
# Check UFW status on containers
for i in {200..210}; do
  echo "Container $i firewall:"
  pct exec $i -- ufw status numbered
done

# Check iptables rules
pct exec 200 -- iptables -L -v -n

# Monitor blocked connections
pct exec 200 -- tail -f /var/log/ufw.log
```

**Solutions:**

```bash
# Allow specific ports
pct exec 200 -- ufw allow from 192.168.0.205 to any port 9090

# Reset firewall rules
pct exec 200 -- ufw --force reset
ansible-playbook site.yml --tags "security" --limit "prometheus"

# Temporarily disable firewall for testing
pct exec 200 -- ufw disable
```

### Performance Issues

#### 1. High Resource Usage

**Symptoms:**

- Container performance degradation
- High CPU or memory usage
- Slow response times

**Diagnostics:**

```bash
# Monitor resource usage
for i in {200..210}; do
  echo "=== Container $i ==="
  pct exec $i -- top -b -n1 | head -10
  pct exec $i -- free -h
  pct exec $i -- df -h
done

# Check Proxmox resource allocation
pvesh get /nodes/pve-mac/lxc/200/status/current
```

**Solutions:**

```bash
# Increase container resources
pct set 200 -memory 4096 -cores 4
pct reboot 200

# Optimize service configuration
# Reduce Prometheus retention
pct exec 200 -- sed -i 's/15d/7d/' /etc/systemd/system/prometheus.service

# Clean up logs
for i in {200..210}; do
  pct exec $i -- journalctl --vacuum-time=7d
done
```

#### 2. Storage Issues

**Symptoms:**

- Disk space warnings
- Slow I/O performance
- Database corruption

**Diagnostics:**

```bash
# Check storage usage
pvesh get /nodes/pve-mac/storage/local/status
df -h /var/lib/vz

# Monitor I/O usage
iostat -x 1 5

# Check for large files
for i in {200..210}; do
  echo "Container $i large files:"
  pct exec $i -- find / -size +100M -type f 2>/dev/null | head -5
done
```

**Solutions:**

```bash
# Clean up old data
pct exec 200 -- find /var/lib/prometheus/data -name "*.tmp" -delete
pct exec 201 -- grafana-cli admin clean-logs

# Increase storage
pct resize 200 rootfs +10G

# Move data to external storage
# Backup and restore to different storage
```

### K3s Cluster Issues

#### 1. Node Communication Problems

**Symptoms:**

- Nodes showing as "NotReady"
- Pod scheduling failures
- Network connectivity issues

**Diagnostics:**

```bash
# Check cluster status
kubectl get nodes -o wide
kubectl describe node k3-01

# Check K3s service status
for i in {1..4}; do
  echo "=== k3s-0$i ==="
  ssh pbs@192.168.0.11$i "sudo systemctl status k3s"
done

# Check network connectivity
kubectl get pods -n kube-system
kubectl logs -n kube-system -l app=flannel
```

**Solutions:**

```bash
# Restart K3s service
ssh pbs@192.168.0.111 "sudo systemctl restart k3s"

# Rejoin problematic nodes
ssh pbs@192.168.0.112 "sudo systemctl stop k3s-agent"
ssh pbs@192.168.0.112 "sudo rm -rf /var/lib/rancher/k3s/agent/data"
ssh pbs@192.168.0.112 "sudo systemctl start k3s-agent"

# Check token validity
k3s token list
```

#### 2. Ingress Controller Issues

**Symptoms:**

- K3s services not accessible via Traefik
- Ingress resources not working
- SSL certificate issues

**Diagnostics:**

```bash
# Check ingress resources
kubectl get ingress --all-namespaces
kubectl describe ingress -n default example-ingress

# Verify service account permissions
kubectl get clusterrolebinding traefik-ingress-controller
kubectl auth can-i get ingresses --as=system:serviceaccount:traefik-system:traefik-ingress-controller
```

**Solutions:**

```bash
# Update kubeconfig on Traefik container
scp /etc/rancher/k3s/k3s.yaml pbs@192.168.0.205:/tmp/
pct exec 205 -- cp /tmp/k3s.yaml /etc/traefik/kubeconfig
pct exec 205 -- systemctl restart traefik

# Fix RBAC permissions
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: traefik-ingress-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-ingress-controller
subjects:
- kind: ServiceAccount
  name: traefik-ingress-controller
  namespace: traefik-system
EOF
```

## Monitoring and Alerting Issues

### 1. Missing Metrics

**Symptoms:**

- Grafana dashboards showing no data
- Prometheus targets down
- Missing alert notifications

**Diagnostics:**

```bash
# Check Prometheus targets
curl -s http://192.168.0.200:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'

# Verify metric endpoints
curl -s http://192.168.0.111:9100/metrics | head -10
curl -s http://192.168.0.200:9090/metrics | head -10

# Check AlertManager
curl -s http://192.168.0.206:9093/api/v1/alerts | jq '.'
```

**Solutions:**

```bash
# Restart monitoring stack
pct exec 200 -- systemctl restart prometheus
pct exec 201 -- systemctl restart grafana-server
pct exec 206 -- systemctl restart alertmanager

# Update service discovery configuration
ansible-playbook site.yml --tags "monitoring" --limit "prometheus"

# Fix data source connections in Grafana
curl -X PUT "http://admin:password@192.168.0.201:3000/api/datasources/1" \
  -H "Content-Type: application/json" \
  -d '{"url": "http://192.168.0.200:9090", "access": "proxy"}'
```

### 2. Log Aggregation Issues

**Symptoms:**

- Logs not appearing in Loki
- Promtail connection failures
- Log parsing errors

**Diagnostics:**

```bash
# Check Loki status
curl -s http://192.168.0.210:3100/ready
curl -s http://192.168.0.210:3100/metrics | grep loki_ingester

# Verify Promtail configuration
for i in {200..210}; do
  pct exec $i -- systemctl status promtail
  pct exec $i -- promtail --config.file=/etc/promtail/promtail.yml --dry-run
done
```

**Solutions:**

```bash
# Restart log services
pct exec 210 -- systemctl restart loki
for i in {200..210}; do
  pct exec $i -- systemctl restart promtail
done

# Fix Promtail configuration
ansible-playbook site.yml --tags "logging" --limit "all"
```

## Emergency Procedures

### 1. Service Recovery

```bash
#!/bin/bash
# emergency-recovery.sh

echo "Starting emergency service recovery..."

# Stop all containers
for i in {200..210}; do
  pct stop $i 2>/dev/null
done

# Start core services first
for service in 205 202 204; do  # Traefik, Unbound, AdGuard
  echo "Starting container $service..."
  pct start $service
  sleep 10
done

# Start monitoring services
for service in 200 201 206 210; do  # Prometheus, Grafana, AlertManager, Loki
  echo "Starting container $service..."
  pct start $service
  sleep 5
done

# Start remaining services
for i in {203,207,208,209}; do
  pct start $i 2>/dev/null
done

echo "Emergency recovery complete. Check service status."
```

### 2. Configuration Rollback

```bash
# Rollback to previous configuration
git checkout HEAD~1 -- inventory/group_vars/all.yml
ansible-playbook site.yml --check --diff

# Restore from backup
cp /backup/configs/$(date -d "1 day ago" +%Y%m%d)/all.yml inventory/group_vars/all.yml
ansible-playbook site.yml --limit "affected_service"
```

### 3. Data Recovery

```bash
# Restore from LXC snapshots
pct rollback 200 snapshot_name

# Restore from file backups
pct exec 200 -- systemctl stop prometheus
pct exec 200 -- tar -xzf /backup/prometheus-data.tar.gz -C /var/lib/prometheus/
pct exec 200 -- systemctl start prometheus
```

## Preventive Maintenance

### Daily Checks

- Service health monitoring via Grafana
- Log review for errors
- Resource usage monitoring
- Backup verification

### Weekly Maintenance

- Security updates
- Log rotation and cleanup
- Performance optimization
- Configuration backup

### Monthly Tasks

- SSL certificate renewal check
- Storage cleanup
- Security audit
- Documentation updates

## Getting Help

### Log Analysis Tools

```bash
# Centralized log analysis
journalctl --since "1 hour ago" | grep -i error

# Service-specific debugging
pct exec 205 -- journalctl -u traefik --since "10 minutes ago" -f

# Performance analysis
htop  # System resources
iotop  # I/O usage
nethogs  # Network usage by process
```

### Debug Mode Activation

```bash
# Enable debug logging
ansible-playbook site.yml --tags "traefik" -e "debug_mode=true"

# Verbose Ansible output
ansible-playbook site.yml -vvv --step
```

### Community Resources

- Repository issues tracker
- Homelab community forums
- Ansible community documentation
- Service-specific documentation

This troubleshooting guide provides systematic approaches to diagnosing and resolving common issues in the homelab infrastructure. Regular updates ensure accuracy as the infrastructure evolves.
