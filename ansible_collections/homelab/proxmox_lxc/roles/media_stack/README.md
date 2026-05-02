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
                     ┌──────────────────────────────────────────┐
Traefik              │  Docker Compose (media-stack.service)     │
192.168.0.205 ──────►│  sonarr          :8989                    │
                     │  radarr          :7878                    │
                     │  bazarr          :6767                    │──► TrueNAS NFS
                     │  prowlarr        :9696                    │    192.168.0.220
                     │  flaresolverr    (via gluetun network)    │    /mnt/tank/data
                     │  gluetun ──────► NordVPN                  │
                     │  qbittorrent     (via gluetun network)    │
                     │  jellyfin        :8096                    │
                     │  lettarrboxd-*   (internal)               │
                     └──────────────────────────────────────────┘
```

## Services

| Service         | Port | URL (via Traefik)           | Notes                                   |
|-----------------|------|-----------------------------|-----------------------------------------|
| Sonarr          | 8989 | sonarr.homelab.lan          |                                         |
| Radarr          | 7878 | radarr.homelab.lan          |                                         |
| Bazarr          | 6767 | bazarr.homelab.lan          |                                         |
| Prowlarr        | 9696 | prowlarr.homelab.lan        |                                         |
| FlareSolverr    | 8191 | —                           | Internal only; shares gluetun network   |
| qBittorrent     | 8080 | qbittorrent.homelab.lan     | Shares gluetun network namespace        |
| Jellyfin        | 8096 | jellyfin.homelab.lan        |                                         |
| Lettarrboxd     | —    | —                           | Internal; one container per watchlist   |

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
   vault_radarr_api_key: "your-radarr-api-key"       # required for Lettarrboxd
   ```
   NordVPN service credentials (for OpenVPN) differ from your account login.
   Generate them at: My Account → Manual Setup → Service credentials.

   The Radarr API key is found in Radarr → Settings → General → Security → API Key (after first
   deploy). Set it in vault and redeploy to activate Lettarrboxd.

## Variables

### VM Provisioning

| Variable                      | Default | Description                                         |
|-------------------------------|---------|-----------------------------------------------------|
| `media_stack_vm_template_id`  | 9001    | Template ID to clone from on pve-nas                |
| `media_stack_cores`           | 2       | vCPU count                                          |
| `media_stack_memory`          | 4096    | RAM in MB                                           |
| `media_stack_disk_size`       | 32      | OS disk size in GB                                  |
| `media_stack_force_recreate`  | false   | Destroy and recreate VM from template (destructive) |

The VM ID and IP are taken from the inventory host (`vm_id` and `ansible_host`).

`media_stack_force_recreate: true` wipes the VM's local disk and rebuilds from the cloud-init
template. Service configs stored on NFS (`/mnt/nas/config/`) survive. Jellyfin's SQLite databases
(`/opt/media-stack/jellyfin/data`) and thumbnail cache (`/opt/media-stack/jellyfin/cache`) are
wiped and regenerated on the next library scan.

### Shared Settings

| Variable                    | Default         | Description                                       |
|-----------------------------|-----------------|---------------------------------------------------|
| `media_stack_puid`          | 1000            | User ID for all services                          |
| `media_stack_pgid`          | 1000            | Group ID for all services                         |
| `media_stack_timezone`      | Europe/London   | Timezone                                          |
| `media_stack_data_dir`      | /opt/media-stack| Local VM dir — Jellyfin cache and SQLite data     |
| `media_stack_restart_policy`| unless-stopped  | Docker restart policy                             |

Service configs (Sonarr, Radarr, Bazarr, Prowlarr, qBittorrent, Jellyfin, Lettarrboxd) are stored
on NFS under `{{ media_stack_nfs_mount }}/config/` so they survive VM recreates. Jellyfin is an
exception: its SQLite databases (`/config/data`) are mounted from local disk to avoid NFS file
locking issues that cause "attempt to write a readonly database" errors. The databases and
thumbnail cache are regenerated automatically on the first library scan after a redeploy.

### NFS

| Variable                | Default                          | Description       |
|-------------------------|----------------------------------|-------------------|
| `media_stack_nfs_server`| 192.168.0.220                    | TrueNAS IP        |
| `media_stack_nfs_src`   | `<nfs_server>:/mnt/tank/data`    | NFS export path   |
| `media_stack_nfs_mount` | /mnt/nas                         | Mount point in VM |
| `media_stack_nfs_opts`  | rw,nfsvers=4,hard,...            | Mount options     |

NFS v4 is used (upgraded from v3). Media and downloads live on NFS; all service configs live on
NFS except Jellyfin's SQLite databases which live on local disk to avoid NFS locking issues.

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

### FlareSolverr

FlareSolverr is a headless browser proxy that solves Cloudflare bot challenges on behalf of
Prowlarr. It shares gluetun's network namespace so all Cloudflare bypass requests exit via VPN,
and is reachable from Prowlarr at `http://gluetun:8191` (no host port mapping).

| Variable               | Default                                      | Description                       |
|------------------------|----------------------------------------------|-----------------------------------|
| `flaresolverr_enabled` | true                                         | Deploy FlareSolverr               |
| `flaresolverr_image`   | ghcr.io/flaresolverr/flaresolverr:latest     | Container image                   |
| `flaresolverr_port`    | 8191                                         | FlareSolverr listen port          |

FlareSolverr requires `qbittorrent_vpn_enabled: true` (shares gluetun's network). Set
`flaresolverr_enabled: false` if you do not need Cloudflare bypass.

After deploying, register FlareSolverr in Prowlarr: Settings → Indexers → Add Indexer Proxy →
FlareSolverr, URL `http://gluetun:8191`. Then edit each Cloudflare-protected indexer and set its
proxy to FlareSolverr.

### Prowlarr VPN proxy (SSL/DNS fix)

Gluetun exposes an HTTP proxy on port **8888** (`HTTPPROXY=on`). Prowlarr's indexer requests must
be routed through it to fix "SSL connection could not be established" / "DNS/SSL issues" errors
caused by geo-blocking or IPv6 fallback failures.

This is configured in **Prowlarr UI** (not in docker-compose), because Prowlarr's `IndexerHttpClient`
uses its own proxy settings for indexer traffic rather than system-level `HTTP_PROXY` env vars.

Configure once after first deploy:
1. Prowlarr → Settings → General → Proxy
2. Set **Type**: `HTTP(S)`, **Hostname**: `gluetun`, **Port**: `8888`
3. **Bypass filter**: `sonarr,radarr,bazarr,jellyfin,localhost,127.0.0.1`
4. Save

> **Note:** Port 8080 is qBittorrent's WebUI (also on gluetun's network) — using it as a proxy
> returns HTTP 501. The correct proxy port is always 8888.

### Lettarrboxd

Lettarrboxd syncs one or more Letterboxd watchlists into Radarr automatically. One container is
spawned per configured instance. Requires `vault_radarr_api_key` in vault.

| Variable                                | Default                  | Description                                  |
|-----------------------------------------|--------------------------|----------------------------------------------|
| `lettarrboxd_instances`                 | []                       | List of watchlist configs (see below)        |
| `lettarrboxd_image`                     | ryanpage/lettarrboxd:latest | Container image                           |
| `lettarrboxd_memory`                    | 256m                     | Memory limit per instance                    |
| `lettarrboxd_check_interval`            | 60                       | Minutes between watchlist polls              |
| `lettarrboxd_radarr_quality_profile`    | Any                      | Radarr quality profile for added movies      |
| `lettarrboxd_radarr_minimum_availability` | released               | Radarr minimum availability                  |
| `lettarrboxd_radarr_add_unmonitored`    | false                    | Add movies as unmonitored in Radarr          |
| `lettarrboxd_radarr_api_key`            | (vault)                  | Radarr API key via `vault_radarr_api_key`    |

Configure instances in `inventory/group_vars/media_stack.yml`:

```yaml
lettarrboxd_instances:
  - name: mine
    letterboxd_url: "https://letterboxd.com/yourname/watchlist/"
  - name: partner
    letterboxd_url: "https://letterboxd.com/partnername/watchlist/"
    radarr_quality_profile: "HD-1080p"   # optional per-instance override
    check_interval: 120                  # optional per-instance override
```

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

# Redeploy without wiping the VM (default — safe to run repeatedly)
ansible-playbook playbooks/applications.yml --tags media-stack --ask-vault-pass

# Force full VM rebuild (wipes local disk, preserves NFS config)
ansible-playbook playbooks/applications.yml --tags media-stack --ask-vault-pass \
  -e media_stack_force_recreate=true
```

The VM is **not** destroyed and recreated on every run. Only provisioning steps (clone, cloud-init,
resize, start) are skipped when the VM already exists. Set `media_stack_force_recreate: true` to
rebuild from scratch.

Service configs are stored on NFS (`/mnt/nas/config/`) and survive VM recreates. Media and
downloads are also on NFS. Jellyfin's SQLite databases and thumbnail cache live on the VM's local
disk (NFS locking is unreliable for SQLite) and are regenerated on the first library scan after a
redeploy.

## Post-Install Configuration

All services share a Docker network (`arr_network`) and communicate using container names — not
the VM IP. Using `192.168.0.230` for service-to-service URLs will not work.

| Connecting from | Reaching Radarr         | Reaching Sonarr         | Reaching qBittorrent     | Reaching FlareSolverr  |
|-----------------|-------------------------|-------------------------|--------------------------|------------------------|
| Prowlarr        | `http://radarr:7878`    | `http://sonarr:8989`    | `http://gluetun:8080`    | `http://gluetun:8191`  |
| Bazarr          | `http://radarr:7878`    | `http://sonarr:8989`    | —                        | —                      |
| Radarr/Sonarr   | —                       | —                       | `http://gluetun:8080`    | —                      |
| Lettarrboxd     | `http://radarr:7878`    | —                       | —                        | —                      |

> qBittorrent and FlareSolverr share gluetun's network namespace. Reach them from other containers
> via `http://gluetun:<port>`, not their container names.

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

### Step 2 — Prowlarr: configure FlareSolverr (required for Cloudflare-protected indexers)

If indexers fail with Cloudflare challenges even with the VPN proxy enabled, add FlareSolverr:

**Settings → Indexers → Add Indexer Proxy → FlareSolverr:**
```
Name:  FlareSolverr
Host:  http://gluetun:8191
```

Click **Test** — you should see a green tick. FlareSolverr handles Cloudflare JavaScript
challenges that the plain HTTP proxy cannot solve. It shares gluetun's network so all bypass
requests exit via NordVPN.

### Step 3 — Prowlarr: add indexers

Open `prowlarr.homelab.lan` → **Indexers** → **Add Indexer**. Search for your preferred
indexers (e.g. 1337x, YIFY, NZBgeek), enter credentials, test and save each one.

### Step 4 — Prowlarr: connect to Radarr and Sonarr

1. **Settings → Apps → Add Application → Radarr**
   - Prowlarr Server: `http://prowlarr:9696`
   - Radarr Server: `http://radarr:7878`
   - API Key: Radarr → Settings → General → Security → API Key
   - Click **Test** then **Save**
2. Repeat for **Sonarr**: server `http://sonarr:8989`, API key from Sonarr → Settings → General
3. Click **Sync App Indexers** — Prowlarr pushes all indexers into both apps automatically

### Step 5 — Radarr: root folder and download client

1. **Settings → Media Management → Root Folders → Add**: `/mnt/nas/media/movies`
2. **Settings → Download Clients → Add → qBittorrent**
   - Host: `gluetun`
   - Port: `8080`
   - Password: value of `vault_qbittorrent_admin_password` in your vault

### Step 6 — Sonarr: root folder and download client

1. **Settings → Media Management → Root Folders → Add**: `/mnt/nas/media/tv`
2. **Settings → Download Clients → Add → qBittorrent** (same settings as Radarr above)

### Step 7 — Bazarr: connect to Sonarr and Radarr

1. **Settings → Sonarr**: URL `http://sonarr:8989`, API key from Sonarr
2. **Settings → Radarr**: URL `http://radarr:7878`, API key from Radarr
3. Enable subtitle providers under **Settings → Providers**

### Step 8 — qBittorrent: download paths and categories

1. **Tools → Options → Downloads → Default Save Path**: `/mnt/nas/downloads/complete`
2. Add category `radarr` with save path `/mnt/nas/downloads/complete/movies`
3. Add category `sonarr` with save path `/mnt/nas/downloads/complete/tv`

### Step 9 — Lettarrboxd: activate watchlist sync

Lettarrboxd starts automatically once `vault_radarr_api_key` is set and instances are configured.
Verify it is running:

```bash
ssh ansible@192.168.0.230 "sudo docker ps | grep lettarrboxd"
ssh ansible@192.168.0.230 "sudo docker logs lettarrboxd-mine 2>&1 | tail -30"
```

The container polls Letterboxd on the configured interval (`lettarrboxd_check_interval`, default
60 minutes) and adds any watchlisted movies to Radarr that are not already present.

### Step 10 — Jellyfin: add media libraries

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

**FlareSolverr not reachable from Prowlarr:**
```bash
ssh ansible@192.168.0.230 "sudo docker logs flaresolverr 2>&1 | tail -20"
# Verify flaresolverr_enabled: true in defaults
# Verify qbittorrent_vpn_enabled: true (FlareSolverr requires gluetun network)
```

**Lettarrboxd not syncing:**
```bash
ssh ansible@192.168.0.230 "sudo docker logs lettarrboxd-mine 2>&1 | tail -30"
# Check vault_radarr_api_key is set and matches Radarr → Settings → General → API Key
# Verify the Letterboxd URL is a valid public watchlist
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
