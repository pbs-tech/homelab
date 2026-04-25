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
always in a known-clean state. All service configuration is stored on NFS under
`{{ media_stack_nfs_mount }}/config/`, so redeploying the VM does not lose any settings.

The only local data is Jellyfin's thumbnail/metadata cache (`/opt/media-stack/jellyfin/cache`),
which is regenerated automatically on first library scan after a redeploy.

## Post-Install Configuration

All services share a Docker network (`arr_network`) and communicate using container names — not
the VM IP. Using `192.168.0.230` for service-to-service URLs will not work.

| Connecting from | Reaching Radarr         | Reaching Sonarr         | Reaching qBittorrent     |
|-----------------|-------------------------|-------------------------|--------------------------|
| Prowlarr        | `http://radarr:7878`    | `http://sonarr:8989`    | `http://gluetun:8080`    |
| Bazarr          | `http://radarr:7878`    | `http://sonarr:8989`    | —                        |
| Radarr/Sonarr   | —                       | —                       | `http://gluetun:8080`    |

> qBittorrent shares gluetun's network namespace. Reach its WebUI from other containers via
> `http://gluetun:8080`, not `http://qbittorrent:8080`.

### Step 1 — Prowlarr: configure VPN proxy (required if ISP blocks indexer sites)

If Prowlarr shows "SSL connection could not be established" when adding indexers, your ISP is
blocking direct connections to torrent sites via TCP RST injection. Route Prowlarr's outbound
traffic through the VPN:

**Settings → General → Proxy:**
```
Enable Proxy:  ✓
Type:          HTTP(S)
Hostname:      gluetun
Port:          8888
```

Gluetun exposes an HTTP proxy on port 8888. Prowlarr stays on `arr_network` for
container-to-container communication but all external requests exit via NordVPN.

### Step 2 — Prowlarr: add indexers

Open `prowlarr.homelab.lan` → **Indexers** → **Add Indexer**. Search for your preferred
indexers (e.g. 1337x, YIFY, NZBgeek), enter credentials, test and save each one.

### Step 3 — Prowlarr: connect to Radarr and Sonarr

1. **Settings → Apps → Add Application → Radarr**
   - Prowlarr Server: `http://prowlarr:9696`
   - Radarr Server: `http://radarr:7878`
   - API Key: Radarr → Settings → General → Security → API Key
   - Click **Test** then **Save**
2. Repeat for **Sonarr**: server `http://sonarr:8989`, API key from Sonarr → Settings → General
3. Click **Sync App Indexers** — Prowlarr pushes all indexers into both apps automatically

### Step 4 — Radarr: root folder and download client

1. **Settings → Media Management → Root Folders → Add**: `/mnt/nas/media/movies`
2. **Settings → Download Clients → Add → qBittorrent**
   - Host: `gluetun`
   - Port: `8080`
   - Password: value of `vault_qbittorrent_admin_password` in your vault

### Step 5 — Sonarr: root folder and download client

1. **Settings → Media Management → Root Folders → Add**: `/mnt/nas/media/tv`
2. **Settings → Download Clients → Add → qBittorrent** (same settings as Radarr above)

### Step 6 — Bazarr: connect to Sonarr and Radarr

1. **Settings → Sonarr**: URL `http://sonarr:8989`, API key from Sonarr
2. **Settings → Radarr**: URL `http://radarr:7878`, API key from Radarr
3. Enable subtitle providers under **Settings → Providers**

### Step 7 — qBittorrent: download paths and categories

1. **Tools → Options → Downloads → Default Save Path**: `/mnt/nas/downloads/complete`
2. Add category `radarr` with save path `/mnt/nas/downloads/complete/movies`
3. Add category `sonarr` with save path `/mnt/nas/downloads/complete/tv`

### Step 8 — Jellyfin: add media libraries

**Dashboard → Libraries → Add Media Library** for each type:

- Movies: `/mnt/nas/media/movies`
- TV shows: `/mnt/nas/media/tv`

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
