# Arr Stack Full Integration Guide

Complete wiring guide for all media stack components. For qBittorrent setup see
[QBITTORRENT-ARR-STACK-GUIDE.md](./QBITTORRENT-ARR-STACK-GUIDE.md).

## Service Map

| Service     | IP              | Port | Purpose                        |
|-------------|-----------------|------|--------------------------------|
| Prowlarr    | 192.168.0.233   | 9696 | Indexer management             |
| Sonarr      | 192.168.0.230   | 8989 | TV show automation             |
| Radarr      | 192.168.0.231   | 7878 | Movie automation               |
| Bazarr      | 192.168.0.232   | 6767 | Subtitle management            |
| qBittorrent | 192.168.0.234   | 8080 | Download client (VPN-wrapped)  |
| Jellyfin    | 192.168.0.235   | 8096 | Media streaming                |

## Shared Filesystem Convention

All containers mount the same underlying paths so hard-linking works:

```
/downloads/          ← qBittorrent writes here
  complete/
    tv/              ← tv-sonarr category
    movies/          ← radarr category
  incomplete/

/media/              ← Sonarr/Radarr/Jellyfin/Bazarr all read from here
  tv/
  movies/
```

> Hard-linking requires `/downloads` and `/media` to be on the **same filesystem**.
> If using a NAS mount, both must be under the same mount point.

---

## 1. Prowlarr → Sonarr & Radarr

**Settings → Apps → Add Application** (add one for each):

```
Name:       Sonarr
URL:        http://192.168.0.230:8989
API Key:    <Sonarr → Settings → General → API Key>
Sync Level: Full Sync
```

```
Name:       Radarr
URL:        http://192.168.0.231:7878
API Key:    <Radarr → Settings → General → API Key>
Sync Level: Full Sync
```

Click **Sync App Indexers** after saving. All indexers now appear in Sonarr/Radarr automatically.

---

## 2. qBittorrent → Sonarr & Radarr

Repeat in **both** Sonarr and Radarr:

**Settings → Download Clients → Add → qBittorrent:**

```
Host:      192.168.0.234
Port:      8080
Username:  admin
Password:  <your password>
Category:  tv-sonarr      ← Sonarr only
Category:  radarr         ← Radarr only
```

> Note: qBittorrent runs behind Gluetun (NordVPN). The WebUI is still accessible on the
> LAN at port 8080 — only torrent traffic is tunnelled through the VPN.

---

## 3. Bazarr → Sonarr & Radarr

Bazarr downloads subtitles after Sonarr/Radarr import files.

**Settings → Sonarr:**
```
Enable:   ✓
Host:     192.168.0.230
Port:     8989
API Key:  <Sonarr API Key>
```

**Settings → Radarr:**
```
Enable:   ✓
Host:     192.168.0.231
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

Jellyfin reads from `/media` — point each library at the correct subfolder.

**Dashboard → Libraries → Add Media Library:**

| Library Name | Type   | Folder          |
|--------------|--------|-----------------|
| TV Shows     | Shows  | `/media/tv`     |
| Movies       | Movies | `/media/movies` |

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
Host:    192.168.0.235
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
