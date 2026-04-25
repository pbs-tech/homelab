# Container and VM Provisioning Guide

How LXC containers and VMs are provisioned in this homelab, how they get network and internet access, and how to add new ones.

## Table of Contents

1. [How It Works](#how-it-works)
2. [Network Architecture](#network-architecture)
3. [Provisioning a New Container](#provisioning-a-new-container)
4. [Provisioning a QEMU VM](#provisioning-a-qemu-vm)
5. [Firewall Configuration](#firewall-configuration)
6. [DNS Configuration](#dns-configuration)
7. [Secure Enclave (Isolated Network)](#secure-enclave-isolated-network)
8. [Troubleshooting](#troubleshooting)

---

## How It Works

### LXC Containers

All production services are deployed as LXC containers through the `homelab.common.container_base` role, which handles:

1. **Proxmox API validation** - Confirms API token authentication works
2. **Container creation** - Creates the LXC container via `community.proxmox.proxmox`
3. **Network interface setup** - Assigns a static IP on the `vmbr0` bridge with gateway
4. **Per-container firewall** - Deploys firewall rules to `/etc/pve/firewall/<vmid>.fw`
5. **Container startup** - Starts the container and waits for SSH
6. **User provisioning** - Creates `ansible` and `pbs` users with SSH keys and sudo access
7. **Startup order** - Sets boot priority based on service group

The main entry points are:

- `playbooks/infrastructure.yml` (recommended, phased deployment)
- `playbooks/foundation.yml` (Phase 1 only: bastion hosts + container provisioning)
- `playbooks/provision-containers.yml` (container creation only)

### QEMU VMs

The codebase currently uses LXC containers exclusively (including the secure enclave). However, QEMU VMs can be provisioned via the `community.proxmox.proxmox_kvm` module when you need:

- Full kernel isolation (e.g., running non-Linux guests or untrusted workloads)
- Hardware passthrough (GPU, USB devices)
- Workloads that require custom kernels or kernel modules
- ISOs that can't run in an LXC container (e.g., Kali installer, Windows)

The secure enclave's `attacker_vm.yml` includes Kali ISO download logic for future VM-based deployment, but currently falls back to an LXC container for speed. The `metasploitable3` target is defined with `deployment_type: vm` but has no provisioning tasks yet.

The network model is the same for both LXC and QEMU: static IP on a Proxmox bridge (`vmbr0` for production, `vmbr1` for enclave) with a gateway for internet access.

---

## Network Architecture

### How Containers Get Internet Access

All standard containers sit on the same Layer 2 network as the Proxmox hosts and your LAN. There is no NAT involved for production containers.

```text
Internet
   │
   ▼
┌──────────────────┐
│ Router/Gateway   │  192.168.0.1
│ (your LAN router)│
└────────┬─────────┘
         │
    ┌────┴────┐  Physical network (192.168.0.0/24)
    │  vmbr0  │  Proxmox bridge
    ├─────────┤
    │         │
┌───┴───┐ ┌──┴────┐
│pve-mac│ │pve-nas│  Proxmox hosts (.56, .57)
└───┬───┘ └───┬───┘
    │         │
    ▼         ▼
 ┌─────┐  ┌─────┐
 │CT200│  │CT230│   LXC containers (.200, .230, etc.)
 │CT201│  │CT231│   Each has: static IP, gateway=.1, DNS
 │ ... │  │ ... │
 └─────┘  └─────┘
```

Each container's network interface is configured as:

```text
net0: name=eth0, bridge=vmbr0, ip=192.168.0.X/24, gw=192.168.0.1, firewall=1
```

This means every container:
- Gets a static IP on the `192.168.0.0/24` subnet
- Routes traffic through the LAN gateway (`192.168.0.1`) for internet access
- Is attached to the `vmbr0` bridge (the default Proxmox bridge connected to the physical NIC)
- Has Proxmox firewall enabled per-container (except bastion hosts)

### Key Network Variables

These are defined in `inventory/group_vars/lxc_containers.yml`:

```yaml
homelab_network:
  gateway_ip: 192.168.0.1
  dns_servers:
    - 1.1.1.1
    - 1.0.0.1

homelab_domain: homelab.lan
```

And extended in `ansible_collections/homelab/common/inventory/group_vars/all.yml`:

```yaml
homelab_network:
  gateway_ip: 192.168.0.1
  dns_servers:
    - 192.168.0.202   # Unbound (primary)
    - 192.168.0.204   # AdGuard (secondary)
    - 1.1.1.1         # Cloudflare fallback
```

### UFW Route Rules on Proxmox Hosts

The `playbooks/bootstrap-proxmox.yml` playbook configures UFW on each Proxmox host to allow routed traffic to and from the container network:

```yaml
- name: Allow routed traffic TO container network
  community.general.ufw:
    rule: allow
    route: true
    dest: "{{ container_network_cidr | default('192.168.0.0/24') }}"

- name: Allow routed traffic FROM container network
  community.general.ufw:
    rule: allow
    route: true
    src: "{{ container_network_cidr | default('192.168.0.0/24') }}"
```

Without these rules, UFW on the Proxmox host would block forwarded traffic between the bridge and the physical NIC.

---

## Provisioning a New Container

### Step 1: Add the Host to Inventory

Edit `inventory/hosts.yml` and add your new container under the appropriate group:

```yaml
monitoring:
  hosts:
    my-new-service:
      ansible_host: 192.168.0.215
      container_id: 215
      proxmox_node: pve-mac     # or pve-nas
      service_port: 8080
```

Key fields:
- `ansible_host` - Static IP address (pick an unused one in the 192.168.0.0/24 range)
- `container_id` - Proxmox VMID (must be unique, usually matches the last IP octet)
- `proxmox_node` - Which Proxmox host to create the container on
- `service_port` - The port your service listens on (used by monitoring/proxy roles)

### Step 2: Set Resource Defaults (Optional)

If your container needs non-default resources, add a group vars file or set host-level vars:

```yaml
# inventory/group_vars/my_group.yml
lxc_cores: 2
lxc_memory: 1024
lxc_swap: 256
lxc_disk_size: 16
```

Default resources (from `container_base/defaults/main.yml`):

| Setting | Default |
|---------|---------|
| Cores | 1 |
| Memory | 512 MB |
| Swap | 0 MB |
| Disk | 8 GB |
| Unprivileged | true |
| Boot on start | true |
| Template | `ubuntu-22.04-standard_22.04-1_amd64.tar.zst` |
| Bridge | `vmbr0` |
| Firewall | enabled |

### Step 3: Add a Play to the Provisioning Playbook

If you created a new inventory group, add a play to `playbooks/provision-containers.yml`:

```yaml
- name: Provision my-group containers
  hosts: my_group
  gather_facts: false
  become: false
  serial: 1
  tasks:
    - name: Create my-group LXC container
      include_role:
        name: homelab.common.container_base
      vars:
        container_resources:
          cores: "{{ lxc_cores | default(1) }}"
          memory: "{{ lxc_memory | default(512) }}"
          swap: "{{ lxc_swap | default(0) }}"
          disk_size: "{{ lxc_disk_size | default(8) }}"
      when: container_id is defined
  tags: [provision, containers, my_group]
```

Also ensure the group is a child of `lxc_containers` in your inventory so it inherits the shared variables.

### Step 4: Run the Provisioning

```bash
# Provision all containers (recommended for first-time setup)
ansible-playbook playbooks/foundation.yml --ask-vault-pass

# Provision only your new container
ansible-playbook playbooks/provision-containers.yml --ask-vault-pass --limit my-new-service

# Or as part of the full phased deployment
ansible-playbook playbooks/infrastructure.yml --ask-vault-pass --tags "foundation,phase1"
```

### Step 5: Verify

After provisioning, you should be able to:

```bash
# SSH into the container
ssh ansible@192.168.0.215
ssh pbs@192.168.0.215

# Verify internet access from within the container
ping -c 3 8.8.8.8
curl -s https://example.com

# Verify DNS resolution
nslookup google.com
```

---

## Provisioning a QEMU VM

QEMU VMs use a different Proxmox module (`community.proxmox.proxmox_kvm`) but follow the same networking model as LXC containers: a static IP on a bridge with a gateway.

### VM vs LXC: When to Use Which

| | LXC Container | QEMU VM |
|---|---|---|
| **Overhead** | Near-zero, shares host kernel | Full virtual hardware, higher resource use |
| **Boot time** | Seconds | 30-60 seconds |
| **Isolation** | Process-level (shared kernel) | Full kernel isolation |
| **Use cases** | Services, web apps, Docker hosts | Non-Linux guests, untrusted workloads, hardware passthrough |
| **Ansible module** | `community.proxmox.proxmox` | `community.proxmox.proxmox_kvm` |
| **Network config** | `netif` parameter (JSON) | `net` parameter (string) |
| **User setup** | `pct exec` from Proxmox host | Cloud-init or SSH after boot |

### Step 1: Add the Host to Inventory

```yaml
# inventory/hosts.yml
my_vms:
  hosts:
    my-new-vm:
      ansible_host: 192.168.0.220
      vm_id: 220
      proxmox_node: pve-mac
```

### Step 2: Create a Provisioning Playbook or Task

Use `community.proxmox.proxmox_kvm` to create the VM. The key networking parameters mirror the LXC approach:

```yaml
- name: Provision QEMU VM
  hosts: my_vms
  gather_facts: false
  become: false
  tasks:
    - name: Create QEMU VM
      community.proxmox.proxmox_kvm:
        api_host: "{{ proxmox_config[proxmox_node].host }}"
        api_user: "{{ proxmox_config[proxmox_node].user }}"
        api_token_id: "{{ proxmox_config[proxmox_node].api_token_id.split('!')[1] }}"
        api_token_secret: "{{ proxmox_config[proxmox_node].api_token_secret }}"
        validate_certs: false

        vmid: "{{ vm_id }}"
        node: "{{ proxmox_config[proxmox_node].node }}"
        name: "{{ inventory_hostname }}"

        # Hardware
        cores: 2
        memory: 2048
        scsihw: virtio-scsi-single
        scsi:
          scsi0: "local-lvm:32,format=raw"

        # Network - same bridge and gateway as LXC containers
        net:
          net0: "virtio,bridge=vmbr0,firewall=1"

        # Boot media (ISO or cloud-init image)
        ide:
          ide2: "local:iso/my-image.iso,media=cdrom"

        state: present
      delegate_to: localhost
```

### Step 3: Configure Networking Inside the VM

Unlike LXC containers (where the IP is injected via `netif`), VMs need their network configured from inside. There are two approaches:

#### Option A: Cloud-Init (Recommended)

Cloud-init lets you inject network config, SSH keys, and user setup at boot time. Add `cicustom` or `ipconfig` parameters to `proxmox_kvm`:

```yaml
    - name: Create VM with cloud-init networking
      community.proxmox.proxmox_kvm:
        # ... api params ...
        vmid: "{{ vm_id }}"
        node: "{{ proxmox_config[proxmox_node].node }}"
        name: "{{ inventory_hostname }}"

        cores: 2
        memory: 2048
        scsi:
          scsi0: "local-lvm:32,format=raw"

        net:
          net0: "virtio,bridge=vmbr0,firewall=1"

        # Cloud-init settings
        ipconfig:
          ipconfig0: "ip={{ ansible_host }}/24,gw={{ homelab_network.gateway_ip }}"
        nameservers: "{{ homelab_network.dns_servers | join(' ') }}"
        searchdomains: "{{ homelab_domain }}"
        sshkeys: "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"
        ciuser: ansible
        cipassword: "{{ vault_vm_password | default(omit) }}"

        state: present
      delegate_to: localhost
```

This gives the VM the same network setup as an LXC container: static IP on `vmbr0`, gateway `192.168.0.1`, and DNS servers injected automatically.

#### Option B: Manual Configuration After Boot

If using an ISO installer (not a cloud-init image), configure networking after the OS is installed:

```bash
# Inside the VM after OS installation
# /etc/netplan/01-netcfg.yaml (Ubuntu/Debian with Netplan)
network:
  version: 2
  ethernets:
    ens18:
      addresses:
        - 192.168.0.220/24
      routes:
        - to: default
          via: 192.168.0.1
      nameservers:
        addresses:
          - 192.168.0.202
          - 192.168.0.204
          - 1.1.1.1
        search:
          - homelab.lan
```

### Step 4: Firewall for VMs

Per-VM firewall files work identically to per-container files. Deploy a firewall config to `/etc/pve/firewall/<vmid>.fw` on the Proxmox host:

```ini
[OPTIONS]
enable: 1

[RULES]
GROUP basic-network
GROUP allow-ssh
IN ACCEPT -source 192.168.0.0/24 -log nolog # Allow LAN traffic
```

You can reuse the same shell heredoc pattern from `container_base`:

```yaml
- name: Deploy per-VM firewall configuration
  ansible.builtin.shell:
    cmd: |
      cat > '/etc/pve/firewall/{{ vm_id }}.fw' << 'FWEOF'
      [OPTIONS]
      enable: 1

      [RULES]
      GROUP basic-network
      GROUP allow-ssh
      IN ACCEPT -source 192.168.0.0/24 -log nolog # Allow LAN traffic
      FWEOF
    executable: /bin/bash
  delegate_to: "{{ proxmox_config[proxmox_node].host }}"
  become: true
  vars:
    ansible_user: ansible
```

### Step 5: Start and Verify

```yaml
- name: Start VM
  community.proxmox.proxmox_kvm:
    # ... api params ...
    vmid: "{{ vm_id }}"
    node: "{{ proxmox_config[proxmox_node].node }}"
    state: started
  delegate_to: localhost

- name: Wait for VM SSH
  ansible.builtin.wait_for:
    host: "{{ ansible_host }}"
    port: 22
    delay: 30
    timeout: 300
  delegate_to: localhost
```

Then verify from the VM:

```bash
ssh ansible@192.168.0.220
ping -c 3 8.8.8.8
nslookup google.com
```

### Isolated Network VMs (Enclave)

To place a VM on the isolated enclave network (`vmbr1`) instead of production:

```yaml
net:
  net0: "virtio,bridge=vmbr1,firewall=0"

ipconfig:
  ipconfig0: "ip=10.10.0.101/24,gw=10.10.0.1"
```

The enclave router at `10.10.0.1` provides NAT for internet access while blocking all traffic to the production `192.168.0.0/24` network. See the [Secure Enclave](#secure-enclave-isolated-network) section for details.

---

## Firewall Configuration

### Cluster-Level Firewall

The cluster firewall is deployed by `playbooks/bootstrap-proxmox.yml` to `/etc/pve/firewall/cluster.fw`. It defines security groups that individual containers reference:

| Security Group | What It Allows |
|---------------|----------------|
| `basic-network` | DHCP, DNS (UDP+TCP), ICMP/ping |
| `allow-ssh` | SSH (port 22) from LAN (192.168.0.0/24) |
| `allow-web` | HTTP (80) and HTTPS (443) from anywhere |

The cluster `[RULES]` section applies only to Proxmox host traffic, not container traffic.

### Per-Container Firewall

Each container gets its own firewall config at `/etc/pve/firewall/<vmid>.fw`, deployed by `container_base`. The defaults are:

```yaml
# container_base/defaults/main.yml
container_firewall_groups:
  - basic-network
  - allow-ssh

container_firewall_extra_rules:
  - "IN ACCEPT -source 192.168.0.0/24 -log nolog # Allow LAN traffic"
```

This produces a per-container firewall file like:

```ini
[OPTIONS]
enable: 1

[RULES]
GROUP basic-network
GROUP allow-ssh
IN ACCEPT -source 192.168.0.0/24 -log nolog # Allow LAN traffic
```

### Customizing Firewall Rules for a Container

Override `container_firewall_groups` and `container_firewall_extra_rules` in your host or group vars:

```yaml
# inventory/host_vars/my-new-service.yml
container_firewall_groups:
  - basic-network
  - allow-ssh
  - allow-web

container_firewall_extra_rules:
  - "IN ACCEPT -source 192.168.0.0/24 -log nolog # Allow LAN traffic"
  - "IN ACCEPT -p tcp -dport 8080 -log nolog # Allow service port"
```

### Disabling the Proxmox Firewall

Bastion hosts manage their own firewall (iptables) and disable the Proxmox firewall:

```yaml
# inventory/group_vars/bastion_hosts.yml
container_network:
  bridge: vmbr0
  ip_config: dhcp
  firewall: false
```

### Important: pmxcfs Limitation

The Proxmox cluster filesystem (`/etc/pve/`) does not support Ansible's atomic file operations (`copy`/`template` modules). The `container_base` role works around this by using `ansible.builtin.shell` with a heredoc to write firewall files directly.

---

## DNS Configuration

### How DNS Is Set on Containers

During container creation, DNS servers and the search domain are injected via the Proxmox API:

```yaml
nameserver: "{{ homelab_network.dns_servers | join(' ') }}"
searchdomain: "{{ homelab_domain }}"
```

This results in a `/etc/resolv.conf` inside each container like:

```text
search homelab.lan
nameserver 192.168.0.202
nameserver 192.168.0.204
nameserver 1.1.1.1
```

### DNS Services

Two dedicated DNS containers handle resolution for the entire homelab:

- **Unbound** (`192.168.0.202`) - Recursive DNS resolver with DNSSEC validation
- **AdGuard Home** (`192.168.0.204`) - DNS filtering with ad/tracker blocking

These DNS containers themselves use external resolvers (Cloudflare `1.1.1.1`) to avoid circular dependencies.

### When DNS Containers Aren't Deployed Yet

During initial provisioning (before Phase 2 networking), containers use the fallback DNS (`1.1.1.1`) defined in `homelab_network.dns_servers`. Once Unbound and AdGuard are deployed in Phase 2, they become the primary resolvers.

---

## Secure Enclave (Isolated Network)

The secure enclave is a separate, isolated network for pentesting that uses a different networking model with NAT. All enclave components are currently deployed as LXC containers (not QEMU VMs), though the defaults define `metasploitable3` with `deployment_type: vm` for future use.

### Enclave Network Architecture

```text
Production Network (192.168.0.0/24)
         │
    ┌────┴────┐
    │  vmbr0  │  Production bridge
    └────┬────┘
         │
   ┌─────┴──────┐
   │ Proxmox    │  IP forwarding + iptables
   │ Host       │  NAT: 10.10.0.0/24 → vmbr0
   └─────┬──────┘
         │
    ┌────┴────┐
    │  vmbr1  │  Enclave bridge (10.10.0.1/24)
    └────┬────┘
         │
    ┌────┴──────────────┐
    │ Enclave targets   │  10.10.0.0/24 (isolated)
    │ (LXC containers)  │  Kali, DVWA, Juice Shop
    └───────────────────┘
```

### Enclave Components

| Component | Type | VMID | Management IP | Isolated IP | Notes |
|-----------|------|------|---------------|-------------|-------|
| enclave-bastion | LXC | 250 | 192.168.0.250 | - | SSH jump host, single-homed on vmbr0 |
| enclave-router | LXC | 251 | 192.168.0.251 | 10.10.0.1 | Dual-homed, NAT gateway + firewall |
| kali-attacker | LXC | 252 | 192.168.0.252 | 10.10.0.10 | Dual-homed, privileged (pentesting tools) |
| dvwa | LXC+Docker | 253 | - | 10.10.0.100 | Isolated only, runs Docker image |
| juice-shop | LXC+Docker | 255 | - | 10.10.0.102 | Isolated only, runs Docker image |

Infrastructure containers (bastion, router, attacker) are **dual-homed** with interfaces on both `vmbr0` and `vmbr1`. Vulnerable targets are **single-homed** on `vmbr1` only, reachable exclusively from inside the enclave.

### How Enclave Internet Access Works

Unlike production containers (which route directly through the LAN gateway), enclave targets on `vmbr1` get internet access through NAT:

1. The Proxmox host creates bridge `vmbr1` with IP `10.10.0.1/24`
2. IP forwarding is enabled on the Proxmox host
3. An iptables MASQUERADE rule translates enclave traffic:

   ```text
   iptables -t nat -A POSTROUTING -s 10.10.0.0/24 -o vmbr0 -j MASQUERADE
   ```

4. Firewall rules on the Proxmox host **block** all traffic from the enclave to production (`192.168.0.0/24`), except DNS to Unbound (`192.168.0.202`)
5. Non-RFC1918 traffic (internet) is **allowed** through

### Key Differences from Production

- Uses a **separate bridge** (`vmbr1`) with its own subnet (`10.10.0.0/24`)
- **NAT/masquerade** provides internet access (traffic is translated at the Proxmox host)
- **Firewall rules block** all traffic to the production `192.168.0.0/24` network
- Only DNS traffic to Unbound (`192.168.0.202`) is allowed through to production
- Internet access is allowed for updates and tool downloads
- Vulnerable targets use the **enclave router** (`10.10.0.1`) as their gateway, not the LAN router

### Adding a VM to the Enclave

To add a QEMU VM (e.g., Metasploitable3) to the enclave isolated network, use `proxmox_kvm` with `vmbr1`:

```yaml
- name: Create enclave VM
  community.proxmox.proxmox_kvm:
    # ... api params ...
    vmid: 254
    node: "{{ proxmox_config[enclave_proxmox_node].node }}"
    name: metasploitable3

    cores: 2
    memory: 2048
    scsi:
      scsi0: "local-lvm:40,format=raw"

    # Isolated network only - no management interface
    net:
      net0: "virtio,bridge=vmbr1,firewall=0"

    # Cloud-init (if the image supports it)
    ipconfig:
      ipconfig0: "ip=10.10.0.101/24,gw=10.10.0.1"
    nameservers: "{{ homelab_network.dns_servers | join(' ') }}"

    state: present
  delegate_to: localhost
```

The VM will get internet access via the enclave router's NAT while remaining blocked from production infrastructure.

See the [CLAUDE.md Secure Enclave section](../CLAUDE.md) for deployment commands.

---

## Troubleshooting

### Container Has No Internet Access

1. **Check the gateway is set correctly** inside the container:

   ```bash
   # Inside the container
   ip route show
   # Should show: default via 192.168.0.1 dev eth0
   ```

2. **Check DNS resolution**:

   ```bash
   # Inside the container
   cat /etc/resolv.conf
   ping -c 1 1.1.1.1        # Test raw connectivity
   nslookup google.com       # Test DNS
   ```

3. **Check the Proxmox bridge**:

   ```bash
   # On the Proxmox host
   brctl show vmbr0          # Verify bridge exists and has interfaces
   ```

4. **Check UFW route rules on the Proxmox host**:

   ```bash
   # On the Proxmox host
   sudo ufw status verbose   # Look for ALLOW route rules
   ```

   If missing, re-run:

   ```bash
   ansible-playbook playbooks/bootstrap-proxmox.yml --ask-vault-pass
   ```

5. **Check Proxmox firewall** isn't blocking outbound traffic:

   ```bash
   # On the Proxmox host — check the per-container firewall
   cat /etc/pve/firewall/<vmid>.fw
   ```

   The default `policy_out: ACCEPT` in the cluster firewall means outbound traffic is allowed. If your container can't reach the internet, the issue is likely routing, not firewall.

### Container or VM SSH Not Reachable

1. **Check the container/VM is running**:

   ```bash
   # On the Proxmox host
   pct list | grep <vmid>     # LXC containers
   qm list | grep <vmid>      # QEMU VMs
   ```

2. **Check from the Proxmox host console**:

   ```bash
   # LXC container
   pct enter <vmid>
   ip addr show              # Verify IP is assigned
   systemctl status ssh      # Verify SSH is running

   # QEMU VM (open a VNC console via Proxmox web UI, or use serial)
   qm terminal <vmid>
   ```

3. **Check the ansible user exists** (LXC only):

   ```bash
   pct exec <vmid> -- id ansible
   pct exec <vmid> -- cat /home/ansible/.ssh/authorized_keys
   ```

4. **For VMs with cloud-init**, verify the cloud-init config was applied:

   ```bash
   # Inside the VM
   cloud-init status
   cat /var/log/cloud-init-output.log
   ```

### Proxmox API Authentication Fails

The `container_base` role requires valid API tokens. Verify with:

```bash
ansible-playbook playbooks/bootstrap-proxmox.yml --ask-vault-pass --tags always
```

Ensure your vault file (`inventory/group_vars/all/vault.yml`) has the correct token values. See the [Vault Setup section in CLAUDE.md](../CLAUDE.md) for required variables.

### Firewall Rules Not Applied

Per-container firewall files are only deployed when `container_network.firewall: true` (the default). If you changed this, the firewall file won't be created.

To manually verify and redeploy:

```bash
# Check if the file exists on the Proxmox host
cat /etc/pve/firewall/<vmid>.fw

# Re-run provisioning for that container
ansible-playbook playbooks/provision-containers.yml --ask-vault-pass --limit my-container
```
