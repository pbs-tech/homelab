# qBittorrent + Arr Stack Guide

This guide covers configuring qBittorrent (192.168.0.234) to work with your arr stack (Sonarr/Radarr/Prowlarr) for automated media management.

---

## 1. qBittorrent Setup

### Access the Web UI
Navigate to `http://192.168.0.234` (or via Traefik if configured).

Default credentials are typically `admin` / `adminadmin` — change immediately.

### Configure Downloads

**Tools → Options → Downloads:**
- **Default Save Path**: `/downloads/complete` (or your NAS-mounted path)
- **Keep incomplete torrents in**: `/downloads/incomplete`
- **Automatically create subdirectories**: ✓
- **Delete .torrent files after adding**: ✓

### Configure the Web API (required for arr integration)

**Tools → Options → Web UI:**
- Enable Web User Interface: ✓
- Port: `8080`
- **Bypass authentication for clients on localhost**: ✓ (optional but useful)
- Note your username/password — the arr apps need these

### Category Setup

Create categories that the arr apps will use to route downloads:

**Right-click in sidebar → Add category:**

| Category | Save Path |
|----------|-----------|
| `tv-sonarr` | `/downloads/complete/tv` |
| `radarr` | `/downloads/complete/movies` |

---

## 2. Prowlarr Setup (Indexers)

Prowlarr manages torrent indexers centrally and syncs them to Sonarr/Radarr automatically.

### Add Indexers

**Indexers → Add Indexer:**
- Search for your preferred indexers (e.g., public ones like 1337x, RARBG mirrors, or private trackers)
- Configure each with your credentials/API keys
- Test the connection

### Connect to Arr Apps

**Settings → Apps → Add Application:**

Add both Sonarr and Radarr:
```
Application:  Sonarr
Server:       http://192.168.0.230
API Key:      <from Sonarr → Settings → General>
Sync Level:   Full Sync
```

```
Application:  Radarr
Server:       http://192.168.0.231
API Key:      <from Radarr → Settings → General>
Sync Level:   Full Sync
```

After saving, click **Sync App Indexers** — all your indexers will push to Sonarr and Radarr automatically.

---

## 3. Sonarr Setup (TV Shows)

### Add qBittorrent as Download Client

**Settings → Download Clients → Add:**
```
Name:       qBittorrent
Host:       192.168.0.234
Port:       8080
Username:   admin
Password:   <your password>
Category:   tv-sonarr
```

Click **Test** — should return a green checkmark.

### Configure Media Management

**Settings → Media Management:**
- Root Folders: Add your TV library path (e.g., `/media/tv`)
- Rename Episodes: ✓ (recommended for Jellyfin compatibility)
- Standard Episode Format: `{Series Title} - S{season:00}E{episode:00} - {Episode Title}`

### How Sonarr Works

1. Add a series via **Series → Add New**
2. Sonarr monitors for new episodes
3. When an episode airs, Sonarr searches your Prowlarr indexers
4. Matching torrents are sent to qBittorrent with the `tv-sonarr` category
5. On completion, Sonarr **hard-links** (or moves) the file to your media library
6. Jellyfin picks it up automatically

---

## 4. Radarr Setup (Movies)

Identical process to Sonarr.

### Add qBittorrent as Download Client

**Settings → Download Clients → Add:**
```
Name:       qBittorrent
Host:       192.168.0.234
Port:       8080
Username:   admin
Password:   <your password>
Category:   radarr
```

### Configure Media Management

**Settings → Media Management:**
- Root Folders: `/media/movies`
- Rename Movies: ✓
- Standard Movie Format: `{Movie Title} ({Release Year})`

### Add a Movie

**Movies → Add New** → search → select quality profile → **Add Movie**

Radarr will search immediately or wait for a better release depending on your quality profile.

---

## 5. Quality Profiles

All arr apps use **Quality Profiles** to control what gets grabbed.

**Settings → Profiles → Quality Profiles:**

Recommended starting profile:
```
Name: HD-1080p
Cutoff: Bluray-1080p
Qualities (ordered, best first):
  - Bluray-1080p
  - WEB-1080p
  - HDTV-1080p
```

The **Cutoff** means: once a release at or above this quality is downloaded, stop searching for upgrades.

---

## 6. The Full Automation Flow

```
Prowlarr (indexers)
    ↓ syncs to
Sonarr / Radarr
    ↓ sends grab to
qBittorrent (downloads to /downloads/complete/{category})
    ↓ notifies arr app on completion
Sonarr / Radarr (hard-links file to /media/tv or /media/movies)
    ↓
Jellyfin (scans library, available for streaming)
```

---

## 7. Verifying It Works

1. **Activity tab** in Sonarr/Radarr shows queued/downloading items
2. **qBittorrent Web UI** should show the torrent with the correct category label
3. After completion, check the file appears in your media root folder
4. In Jellyfin, trigger a library scan: **Dashboard → Libraries → Scan All Libraries**

---

## Tips for Your Setup

- **Hard links vs copies**: If `/downloads` and `/media` are on the **same filesystem** (same NAS mount), Sonarr/Radarr will hard-link — zero extra disk space used. If they're on different mounts, it will copy, using 2x space temporarily.
- **Bazarr** (192.168.0.232) handles subtitle downloading — connect it to both Sonarr and Radarr via their API keys after the above is working.
- **Seeding**: qBittorrent will keep seeding after arr apps import the file. Set a seed ratio limit under **Tools → Options → BitTorrent → Seeding Goals** to avoid indefinite seeding.
