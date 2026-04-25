# Arr Stack Full Integration Guide

Complete wiring guide for all media stack components. For qBittorrent setup see
[QBITTORRENT-ARR-STACK-GUIDE.md](./QBITTORRENT-ARR-STACK-GUIDE.md).

## Service Map

All services run as Docker containers on a single Ubuntu VM at **192.168.0.230**.
Access via browser uses the VM IP. Service-to-service communication uses Docker container names.

| Service     | Browser URL                   | Container name | Port |
|-------------|-------------------------------|----------------|------|
| Prowlarr    | http://192.168.0.230:9696     | `prowlarr`     | 9696 |
| Sonarr      | http://192.168.0.230:8989     | `sonarr`       | 8989 |
| Radarr      | http://192.168.0.230:7878     | `radarr`       | 7878 |
| Bazarr      | http://192.168.0.230:6767     | `bazarr`       | 6767 |
| qBittorrent | http://192.168.0.230:8080     | `gluetun`      | 8080 |
| Jellyfin    | http://192.168.0.230:8096     | `jellyfin`     | 8096 |

> **qBittorrent container name is `gluetun`** — qBittorrent shares gluetun's network namespace,
> so its port is exposed on the `gluetun` container. Use `gluetun:8080` anywhere you configure
> a qBittorrent download client.

## Shared Filesystem Convention

All services mount the same NAS path so hard-linking works:

```
/mnt/nas/downloads/      ← qBittorrent writes here
  complete/
    tv/                  ← tv-sonarr category
    movies/              ← radarr category
  incomplete/

/mnt/nas/media/          ← Sonarr/Radarr/Jellyfin/Bazarr all read from here
  tv/
  movies/
```

> Hard-linking requires `/downloads` and `/media` to be on the **same filesystem**.
> Both are under `/mnt/nas` (single TrueNAS NFS mount), so hard-linking works correctly.

---

## 1. Prowlarr → Sonarr & Radarr

**Settings → Apps → Add Application** (add one for each):

```
Name:             Sonarr
Prowlarr Server:  http://prowlarr:9696
Radarr Server:    http://sonarr:8989
API Key:          <Sonarr → Settings → General → API Key>
Sync Level:       Full Sync
```

```
Name:             Radarr
Prowlarr Server:  http://prowlarr:9696
Radarr Server:    http://radarr:7878
API Key:          <Radarr → Settings → General → API Key>
Sync Level:       Full Sync
```

Click **Sync App Indexers** after saving. All indexers now appear in Sonarr/Radarr automatically.

---

## 2. qBittorrent → Sonarr & Radarr

Repeat in **both** Sonarr and Radarr:

**Settings → Download Clients → Add → qBittorrent:**

```
Host:      gluetun        ← NOT the VM IP or "qbittorrent"
Port:      8080
Username:  admin
Password:  <vault_qbittorrent_admin_password>
Category:  tv-sonarr      ← Sonarr only
Category:  radarr         ← Radarr only
```

> qBittorrent shares gluetun's network namespace. The port is exposed on the `gluetun`
> container — using `qbittorrent` or `192.168.0.230` as the host will fail.
> Only torrent traffic is tunnelled through NordVPN; the WebUI is accessible on the LAN.

---

## 3. Bazarr → Sonarr & Radarr

Bazarr downloads subtitles after Sonarr/Radarr import files.

**Settings → Sonarr:**
```
Enable:   ✓
Host:     sonarr
Port:     8989
API Key:  <Sonarr API Key>
```

**Settings → Radarr:**
```
Enable:   ✓
Host:     radarr
Port:     7878
API Key:  <Radarr API Key>
```

**Settings → Subtitles → Subtitle providers:**
- Add at minimum: OpenSubtitles.com (free account required) or Subscene
- Set **Languages** to your preferred language(s)
- Enable **Automatic Subtitles Synchronization** if available

Bazarr will automatically download subtitles for any media Sonarr/Radarr imports.

---

## 4. Jellyfin Library Setup

Jellyfin reads from `/mnt/nas/media` — point each library at the correct subfolder.

**Dashboard → Libraries → Add Media Library:**

| Library Name | Type   | Folder                |
|--------------|--------|-----------------------|
| TV Shows     | Shows  | `/mnt/nas/media/tv`   |
| Movies       | Movies | `/mnt/nas/media/movies` |

**Recommended metadata agents (Plugins → Catalog):**
- TMDb (movies)
- TVDb (TV shows)

After adding libraries: **Dashboard → Libraries → Scan All Libraries**

### Jellyfin API Key (needed for Sonarr/Radarr notifications)

**Dashboard → API Keys → + → name it** `sonarr` or `radarr`

---

## 5. Sonarr/Radarr → Jellyfin (Library Refresh on Import)

Tell Sonarr and Radarr to trigger a Jellyfin library scan after importing a file.

In **both** Sonarr and Radarr:

**Settings → Connect → Add → Emby/Jellyfin:**
```
Name:    Jellyfin
Host:    jellyfin
Port:    8096
API Key: <Jellyfin API Key from step 4>
```

Enable triggers:
- On Download: ✓
- On Upgrade: ✓
- On Rename: ✓

Jellyfin will now refresh the relevant library section immediately when new media is imported.

---

## 6. Full Automation Flow

```
                    ┌─────────────────────────────────────┐
                    │            Prowlarr :9696            │
                    │  (manages all torrent indexers)      │
                    └─────────┬──────────────┬────────────┘
                              │ syncs        │ syncs
                    ┌─────────▼──┐      ┌────▼────────┐
                    │ Sonarr     │      │ Radarr      │
                    │ :8989      │      │ :7878       │
                    └─────┬──┬──┘      └──┬──┬───────┘
                          │  │            │  │
              grab torrent │  └─notify────┘  │ grab torrent
                          │    Bazarr        │
                          │    :6767         │
                          ▼                  ▼
                    ┌─────────────────────────────────────┐
                    │         qBittorrent :8080            │
                    │  (traffic via NordVPN/Gluetun)       │
                    │  downloads to /downloads/complete    │
                    └────────────────┬────────────────────┘
                                     │ import complete
                                     ▼
                    ┌─────────────────────────────────────┐
                    │     Sonarr/Radarr hard-links file    │
                    │     /downloads → /media/tv|movies    │
                    └────────────────┬────────────────────┘
                         ┌───────────┴──────────┐
                         ▼                      ▼
                  ┌──────────────┐     ┌────────────────┐
                  │ Jellyfin     │     │ Bazarr         │
                  │ :8096        │     │ fetches subs   │
                  │ (notified,   │     │ → /media/...   │
                  │ library scan)│     └────────────────┘
                  └──────────────┘
```

---

## 7. Verification Checklist

- [ ] Prowlarr: indexers show green status, synced to Sonarr + Radarr
- [ ] Sonarr: qBittorrent download client tests green
- [ ] Radarr: qBittorrent download client tests green
- [ ] Bazarr: Sonarr + Radarr connections test green, at least one subtitle provider configured
- [ ] Jellyfin: `/media/tv` and `/media/movies` libraries populated after scan
- [ ] Sonarr/Radarr: Jellyfin connect notification tests green
- [ ] End-to-end test: add a movie in Radarr → watch it appear in qBittorrent → confirm it lands in Jellyfin

---

## Tips

- **PUID/PGID consistency**: All containers use `1000:1000`. Ensure your NAS mount and
  `/media` directory are owned/writable by UID 1000 to avoid permission errors on import.
- **VPN killswitch**: qBittorrent is routed through Gluetun. If the VPN drops, torrents
  pause automatically — configure NordVPN credentials in vault as
  `vault_nordvpn_openvpn_username` and `vault_nordvpn_openvpn_password`.
- **Rename on import**: Enable renaming in Sonarr/Radarr so Jellyfin metadata matching
  works reliably (ambiguous filenames cause mis-identification).
- **Bazarr sync**: Bazarr checks for missing subtitles on a schedule — force a scan via
  **System → Tasks → Search for Missing Subtitles** after initial setup.
