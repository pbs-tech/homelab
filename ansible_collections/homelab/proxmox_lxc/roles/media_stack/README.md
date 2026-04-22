# media_stack

Deploys a unified media management and streaming stack on a single Ubuntu KVM VM on pve-nas.

## Why a VM instead of LXC containers?

Unprivileged LXC containers remap UIDs: container UID 1000 becomes host UID 101000. When combined
with NFS exports owned by UID 1000 (TrueNAS default), Docker containers running as PUID=1000 cannot
write to NFS-mounted paths — they appear as `nobody` (65534) to the NFS server. This is a
fundamental incompatibility, not a configuration problem.

A KVM VM has no UID remapping: PUID=1000 inside the VM maps directly to filesystem UID 1000, NFS
mounts work natively, and Docker Compose operates with a standard well-understood setup.

## Architecture

```
                      VM: 192.168.0.230
                     ┌──────────────────────────────────────┐
Traefik              │  Docker Compose (media-stack.service) │
192.168.0.205 ──────►│  sonarr    :8989                      │
                     │  radarr    :7878                      │
                     │  bazarr    :6767                      │──► TrueNAS NFS
                     │  prowlarr  :9696                      │    192.168.0.220
                     │  gluetun ──► NordVPN                  │    /mnt/tank/data
                     │  qbittorrent (via gluetun) :8080      │
                     │  jellyfin  :8096                      │
                     └──────────────────────────────────────┘
```

## Services

| Service      | Port | URL (via Traefik)           |
|--------------|------|-----------------------------|
| Sonarr       | 8989 | sonarr.homelab.lan          |
| Radarr       | 7878 | radarr.homelab.lan          |
| Bazarr       | 6767 | bazarr.homelab.lan          |
| Prowlarr     | 9696 | prowlarr.homelab.lan        |
| qBittorrent  | 8080 | qbittorrent.homelab.lan     |
| Jellyfin     | 8096 | jellyfin.homelab.lan        |

## Prerequisites

1. **Cloud-init template on pve-nas** — Template ID 9001 must exist on pve-nas. Proxmox VM IDs are
   cluster-wide, so pve-nas needs its own template ID distinct from pve-mac's (9000):
   ```bash
   ansible-playbook playbooks/create-vm-template.yml --ask-vault-pass \
     --limit pve-nas -e vm_template_id=9001
   ```

2. **Fix TrueNAS ownership** — Ensure media files are owned by UID 1000:
   ```bash
   ssh admin@192.168.0.220 "sudo chown -R 1000:1000 /mnt/tank/data"
   ```

3. **Vault variables** — The following must exist in `inventory/group_vars/all/vault.yml`:
   ```yaml
   vault_nordvpn_openvpn_username: "your-nordvpn-service-username"
   vault_nordvpn_openvpn_password: "your-nordvpn-service-password"
   ```
   NordVPN service credentials (for OpenVPN) differ from your account login.
   Generate them at: My Account → Manual Setup → Service credentials.

## Variables

### VM Provisioning

| Variable                    | Default | Description                                       |
|-----------------------------|---------|---------------------------------------------------|
| `media_stack_vm_template_id`| 9001    | Template ID to clone from on pve-nas              |
| `media_stack_cores`         | 2       | vCPU count                                        |
| `media_stack_memory`        | 4096    | RAM in MB                                         |
| `media_stack_disk_size`     | 32      | OS disk size in GB                                |

The VM ID and IP are taken from the inventory host (`vm_id` and `ansible_host`).

### Shared Settings

| Variable                    | Default         | Description              |
|-----------------------------|-----------------|--------------------------|
| `media_stack_puid`          | 1000            | User ID for all services |
| `media_stack_pgid`          | 1000            | Group ID for all services|
| `media_stack_timezone`      | Europe/London   | Timezone                 |
| `media_stack_data_dir`      | /opt/media-stack| Config root on VM        |
| `media_stack_restart_policy`| unless-stopped  | Docker restart policy    |

### NFS

| Variable                | Default                          | Description       |
|-------------------------|----------------------------------|-------------------|
| `media_stack_nfs_server`| 192.168.0.220                    | TrueNAS IP        |
| `media_stack_nfs_src`   | `<nfs_server>:/mnt/tank/data`    | NFS export path   |
| `media_stack_nfs_mount` | /mnt/nas                         | Mount point in VM |
| `media_stack_nfs_opts`  | rw,nfsvers=3,hard,...            | Mount options     |

### NordVPN / Gluetun (qBittorrent VPN)

All torrent traffic is routed through NordVPN via a Gluetun sidecar. qBittorrent uses
`network_mode: "service:gluetun"` — if the VPN tunnel drops, qBittorrent loses network access
entirely (built-in kill-switch).

| Variable                          | Default      | Description                        |
|-----------------------------------|--------------|------------------------------------|
| `qbittorrent_vpn_enabled`         | true         | Set `false` to skip Gluetun        |
| `qbittorrent_vpn_service_provider`| nordvpn      | VPN provider name                  |
| `qbittorrent_vpn_type`            | openvpn      | `openvpn` or `wireguard`           |
| `qbittorrent_vpn_server_countries`| Switzerland  | Preferred server country           |
| `qbittorrent_vpn_openvpn_username`| (vault)      | NordVPN service username           |
| `qbittorrent_vpn_openvpn_password`| (vault)      | NordVPN service password           |

When `qbittorrent_vpn_enabled: false`:
- The gluetun service is omitted from the compose file
- qBittorrent exposes port 8080 directly
- UFW allows the torrent port (6881) TCP/UDP

### Jellyfin Hardware Acceleration

| Variable                   | Default              | Description               |
|----------------------------|----------------------|---------------------------|
| `jellyfin_hardware_accel`  | false                | Enable VAAPI/QSV           |
| `jellyfin_gpu_device`      | /dev/dri/renderD128  | GPU device path            |

Hardware acceleration requires an Intel GPU accessible at the device path. Confirm with
`ls /dev/dri/` on the VM after provisioning, then set `jellyfin_hardware_accel: true`.

## Deployment

```bash
# 1. Create VM template on pve-nas (one-time setup)
ansible-playbook playbooks/create-vm-template.yml --ask-vault-pass \
  --limit pve-nas -e vm_template_id=9001

# 2. Fix TrueNAS ownership (one-time setup)
ssh admin@192.168.0.220 "sudo chown -R 1000:1000 /mnt/tank/data"

# 3. Deploy the media stack VM
ansible-playbook playbooks/applications.yml --tags media-stack --ask-vault-pass

# 4. Update Traefik routing (all arr services now at 192.168.0.230)
ansible-playbook playbooks/infrastructure.yml --tags traefik --ask-vault-pass
```

The role destroys and recreates the VM on each run. This is intentional — it ensures the VM is
always in a known-clean state. Configuration data lives on NFS, so redeploying is safe.

## Post-Install Configuration

After the stack is running, configure each service via its web UI:

1. **Prowlarr** (`prowlarr.homelab.lan`) — Add indexers, then sync to Sonarr/Radarr
2. **Radarr** (`radarr.homelab.lan`) — Settings → Media Management → Add root folder: `/mnt/nas/media/movies`
3. **Sonarr** (`sonarr.homelab.lan`) — Settings → Media Management → Add root folder: `/mnt/nas/media/tv`
4. **Bazarr** (`bazarr.homelab.lan`) — Add Sonarr/Radarr under Settings → Sonarr/Radarr
5. **qBittorrent** (`qbittorrent.homelab.lan`) — Set default save path to `/mnt/nas/downloads`
6. **Jellyfin** (`jellyfin.homelab.lan`) — Add library pointing to `/mnt/nas/media`

## Troubleshooting

**NFS permission denied:**
```bash
ssh ansible@192.168.0.230 "ls -lan /mnt/nas/media/"
# Files should show UID 1000, not 65534 (nobody)
# Fix: ssh admin@192.168.0.220 "sudo chown -R 1000:1000 /mnt/tank/data"
```

**VPN not connecting:**
```bash
ssh ansible@192.168.0.230 "sudo docker logs gluetun 2>&1 | tail -50"
# Check: OPENVPN_USER/PASSWORD correct? Server country available?
```

**Service not starting:**
```bash
ssh ansible@192.168.0.230 "sudo systemctl status media-stack"
ssh ansible@192.168.0.230 "sudo docker compose -f /opt/media-stack/docker-compose.yml logs"
```

**Write test (confirms NFS ownership is correct):**
```bash
ssh ansible@192.168.0.230 "sudo docker exec -u 1000 radarr touch /mnt/nas/media/movies/test && echo OK"
# Should print OK; if Permission denied, fix TrueNAS ownership (see above)
```
