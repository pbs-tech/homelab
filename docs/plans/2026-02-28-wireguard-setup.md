# WireGuard End-to-End Setup Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Get WireGuard VPN fully operational — server provisioned, client config generated
with the correct server public key, and the control machine connecting via nmcli.

**Architecture:** The WireGuard LXC (VMID 203, IP 192.168.0.203) is discovered via the
dynamic Proxmox inventory by name prefix (`wireguard*`). The `networking.yml` playbook
applies the wireguard role to all hosts in the `networking` group. WireGuard vars
(endpoint, clients) live in `inventory/group_vars/networking.yml`. Client configs are
generated locally to `~/.wireguard/homelab/`.

**Tech Stack:** Ansible, community.proxmox dynamic inventory, WireGuard, NetworkManager/nmcli

---

## Prerequisites (manual — cannot be automated yet)

Before running any playbooks, the `ansible` user must exist on both Proxmox hosts.
Do this via the **Proxmox web console** on each host:

- pve-mac: `https://192.168.0.56:8006` → select node → Shell
- pve-nas: `https://192.168.0.57:8006` → select node → Shell

Run on each:

```bash
useradd -m -s /bin/bash ansible
mkdir -p /home/ansible/.ssh && chmod 700 /home/ansible/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMDp6d9l3RnKiD8ZxnoL9geJQ8/IrPMhTfCpSLpMrB+6 homelab-ansible' \
  > /home/ansible/.ssh/authorized_keys
chmod 600 /home/ansible/.ssh/authorized_keys
chown -R ansible:ansible /home/ansible/.ssh
echo 'ansible ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible
```

---

### Task 1: Verify Proxmox bootstrap

**Files:** none (verification only)

**Step 1: Confirm ansible user is reachable on both hosts**

```bash
ssh -i ~/.ssh/homelab_ed25519 ansible@192.168.0.56 "echo pve-mac ok"
ssh -i ~/.ssh/homelab_ed25519 ansible@192.168.0.57 "echo pve-nas ok"
```

Expected: `pve-mac ok` and `pve-nas ok`

**Step 2: Run bootstrap playbook to apply full config**

```bash
ansible-playbook playbooks/bootstrap-proxmox.yml --vault-password-file ~/.ansible_vault_pass
```

Expected: No failures. The playbook configures sudo, SSH hardening, and confirms the
ansible user is set up correctly on both hosts.

**Step 3: Commit** — no code changes, skip.

---

### Task 2: Generate client key pair on the control machine

**Files:** `~/.wireguard/` (local, not committed)

**Step 1: Create directory and generate keys**

```bash
mkdir -p ~/.wireguard
wg genkey | tee ~/.wireguard/client-privatekey | wg pubkey > ~/.wireguard/client-publickey
chmod 600 ~/.wireguard/client-privatekey
```

**Step 2: Note your public key — you'll need it in Task 3**

```bash
cat ~/.wireguard/client-publickey
```

Expected: a 44-character base64 string, e.g. `uMoFRDjObpCnl6+...`

**Step 3: Optionally generate a preshared key**

```bash
wg genpsk > ~/.wireguard/client-psk
chmod 600 ~/.wireguard/client-psk
cat ~/.wireguard/client-psk
```

---

### Task 3: Create networking group_vars with WireGuard config

**Files:**
- Create: `ansible_collections/homelab/proxmox_lxc/inventory/group_vars/networking.yml`

**Step 1: Find your public IP or DDNS hostname**

```bash
curl -s https://ifconfig.me
```

Note this — it becomes `wireguard_public_endpoint`.

**Step 2: Create the group vars file**

```yaml
# ansible_collections/homelab/proxmox_lxc/inventory/group_vars/networking.yml
---
# WireGuard server configuration
# Public endpoint — replace with your actual public IP or DDNS hostname
wireguard_public_endpoint: "YOUR_PUBLIC_IP_OR_DOMAIN"

# Client configurations
# Add one entry per device that needs VPN access
wireguard_clients:
  - name: control-machine
    description: Arch Linux control machine
    public_key: "PASTE_OUTPUT_OF_cat_~/.wireguard/client-publickey_HERE"
    allowed_ips: 10.200.0.2/32
    preshared_key: "PASTE_OUTPUT_OF_cat_~/.wireguard/client-psk_HERE"
    persistent_keepalive: 25
```

Replace both `PASTE_...` placeholders with the actual values from Task 2.
Replace `YOUR_PUBLIC_IP_OR_DOMAIN` with the output of `curl -s https://ifconfig.me`.

**Step 3: Commit**

```bash
git add ansible_collections/homelab/proxmox_lxc/inventory/group_vars/networking.yml
git commit -m "feat: add WireGuard networking group vars with client config"
```

---

### Task 4: Provision LXC containers

**Files:** none (playbook execution)

This creates the WireGuard LXC (and any other missing containers) on Proxmox.

**Step 1: Run the provisioning playbook**

```bash
ansible-playbook playbooks/provision-containers.yml --vault-password-file ~/.ansible_vault_pass
```

Expected: The WireGuard container is created at 192.168.0.203 and SSH is accessible.

**Step 2: Verify the WireGuard LXC is reachable**

```bash
ssh -i ~/.ssh/homelab_ed25519 ansible@192.168.0.203 "echo wireguard ok"
```

Expected: `wireguard ok`

**Step 3: Verify it appears in dynamic inventory**

```bash
cd ansible_collections/homelab/proxmox_lxc
ansible-inventory -i inventory/ --list | python3 -m json.tool | grep wireguard
```

Expected: a host beginning with `wireguard` appears under the `networking` group.

---

### Task 5: Deploy WireGuard role

**Files:** none (playbook execution)

**Step 1: Run the networking playbook scoped to WireGuard**

```bash
ansible-playbook playbooks/networking.yml --tags wireguard \
  --vault-password-file ~/.ansible_vault_pass
```

Expected output includes:
- `Generate server private key` → skipped (already exists) or changed (first run)
- `Display server public key` → shows a 44-char base64 key
- `Save server public key to file` → ok/changed
- `Fetch server public key to control machine` → ok
- `Generate client configuration files locally` → changed (one per client with real public key)

**Step 2: Verify artifacts were created locally**

```bash
ls -la ~/.wireguard/homelab/
```

Expected:
```
server_publickey
control-machine-wg0.conf
```

**Step 3: Check the generated config has the server key (not your client key)**

```bash
grep PublicKey ~/.wireguard/homelab/control-machine-wg0.conf
cat ~/.wireguard/homelab/server_publickey
```

Expected: the two values **match** — both are the server's public key.
If they match your `~/.wireguard/client-publickey`, something went wrong — stop and investigate.

---

### Task 6: Install client config and connect

**Files:** `/etc/wireguard/wg0.conf` (on control machine, not committed)

**Step 1: Install the generated config**

```bash
sudo mkdir -p /etc/wireguard
sudo cp ~/.wireguard/homelab/control-machine-wg0.conf /etc/wireguard/wg0.conf
sudo chmod 600 /etc/wireguard/wg0.conf
```

**Step 2: Inject your private key**

```bash
sudo sed -i "s|REPLACE_WITH_YOUR_CLIENT_PRIVATE_KEY|$(cat ~/.wireguard/client-privatekey)|" \
  /etc/wireguard/wg0.conf
```

**Step 3: Verify the config looks correct before connecting**

```bash
sudo cat /etc/wireguard/wg0.conf
```

Check:
- `[Interface] PrivateKey` = a real key (not the placeholder)
- `[Peer] PublicKey` = matches `~/.wireguard/homelab/server_publickey`
- `Endpoint` = your public IP/domain + `:51820`

**Step 4: Import into NetworkManager**

```bash
sudo nmcli connection import type wireguard file /etc/wireguard/wg0.conf
nmcli connection modify wg0 ipv4.dns "192.168.0.202" ipv4.dns-search "homelab.local"
```

**Step 5: Connect**

```bash
nmcli connection up wg0
```

**Step 6: Verify the tunnel has an active peer**

```bash
sudo wg show
```

Expected: a `[Peer]` section with `latest handshake: X seconds ago`.
If handshake is `never`, the server can't be reached — proceed to Task 7 (port forwarding).

---

### Task 7: Configure router port forwarding

**Files:** none (router UI — manual step)

WireGuard needs UDP port 51820 forwarded from your router to the LXC.

**Step 1: Log into your router admin panel**

Typically `http://192.168.0.1` — varies by router.

**Step 2: Add a port forwarding rule**

| Field | Value |
|-------|-------|
| Protocol | UDP |
| External port | 51820 |
| Internal IP | 192.168.0.203 |
| Internal port | 51820 |

Save and apply.

**Step 3: Verify from the control machine (while on WiFi, not VPN)**

```bash
# Disconnect VPN first if connected
nmcli connection down wg0

# Test UDP reachability (requires netcat)
nc -u -v YOUR_PUBLIC_IP 51820
# Press Ctrl+C after a few seconds — no error = port is open
```

---

### Task 8: End-to-end verification

**Step 1: Connect via VPN**

```bash
nmcli connection up wg0
```

**Step 2: Verify peer handshake**

```bash
sudo wg show
# latest handshake should be < 30 seconds ago
```

**Step 3: Verify routing to homelab**

```bash
ping -c 3 10.200.0.1       # VPN gateway
ping -c 3 192.168.0.202    # AdGuard/Unbound DNS
ping -c 3 192.168.0.56     # pve-mac Proxmox
```

**Step 4: Verify DNS resolution**

```bash
resolvectl query grafana.homelab.local
```

Expected: returns `192.168.0.201`

**Step 5: Disconnect and verify local access still works**

```bash
nmcli connection down wg0
ping -c 3 192.168.0.56     # Should still work via wlan0
```

---

## Troubleshooting Quick Reference

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `No route to host` to 192.168.0.x | wg0 is up and winning the route | `nmcli connection down wg0` |
| `wg show` shows no `[Peer]` | Wrong PublicKey in config | Check server_publickey matches `[Peer] PublicKey` |
| Handshake never completes | Port 51820 not forwarded | Complete Task 7 |
| DNS not resolving homelab names | nmcli DNS not set | Re-run `nmcli connection modify wg0 ipv4.dns ...` |
