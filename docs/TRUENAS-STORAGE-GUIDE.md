# TrueNAS SCALE Storage Configuration Guide

Configuration guide for TrueNAS SCALE (192.168.0.220) as shared storage for the arr media stack
and general file storage. Covers Proxmox drive passthrough, pool and L2ARC setup, dataset layout,
NFS exports, SMB shares, and LXC container mount configuration.

---

## Hardware Layout

| Device | Size | Role |
|--------|------|------|
| Proxmox virtual disk (local-lvm on pve-nas) | 32 GB | TrueNAS OS boot |
| HDD (passed through) | 1.8 TB | ZFS data pool (`tank`) |
| SSD (passed through) | 238 GB | ZFS L2ARC read cache for `tank` |

TrueNAS runs as a KVM/QEMU VM on `pve-nas` (192.168.0.57). The OS disk is a standard Proxmox
virtual disk. The HDD and SSD are passed through as raw devices so ZFS has direct hardware
access — never put them behind a virtual disk layer.

**L2ARC role:** The SSD acts as a read cache between RAM (ARC) and the HDD pool. Frequently
read data — Jellyfin metadata, thumbnails, subtitle files, ZFS metadata — gets cached on the SSD
and served at SSD speed instead of HDD speed. Large sequential video reads (streaming) bypass
L2ARC and read directly from the HDD.

> **No RAID redundancy:** A single-disk stripe has no protection against drive failure.
> Snapshots and off-site replication (see [Section 9](#9-snapshot-and-replication-schedule))
> are your only safety net.

---

## 1. Proxmox Drive Passthrough

The TrueNAS VM is created by the `truenas` Ansible role, which provisions the OS virtual disk
automatically. The physical HDD and SSD must be passed through separately.

### Identify Physical Drives on pve-nas

SSH into `pve-nas` (192.168.0.57):

```bash
# List drives with model and serial — use these to identify HDD vs SSD
lsblk -o NAME,SIZE,ROTA,MODEL,SERIAL,TYPE | grep disk
# ROTA=1 → spinning HDD, ROTA=0 → SSD

# Get stable by-id paths (use these, not /dev/sdX which can change on reboot)
ls -la /dev/disk/by-id/ | grep -v part | grep -v wwn
```

Note the `/dev/disk/by-id/ata-...` path for both drives.

### Find the TrueNAS VM ID

```bash
qm list | grep -i truenas
# Example: 220  truenas  running  ...
```

### Attach Both Drives to the VM

```bash
# Attach the 1.8TB HDD as the ZFS data disk
qm set <VMID> --sata1 /dev/disk/by-id/ata-<HDD_SERIAL>

# Attach the 238GB SSD as the L2ARC cache disk
qm set <VMID> --sata2 /dev/disk/by-id/ata-<SSD_SERIAL>
```

> Use `--sata1`/`--sata2` (or `--scsi1`/`--scsi2`) leaving slot 0 for the existing OS virtual
> disk. Check which slots are already in use: `qm config <VMID>`.

Alternatively via the Proxmox UI — **VM → Hardware → Add → Hard Disk:**
- Bus/Device: SATA 1 (HDD), SATA 2 (SSD)
- Storage: select the physical disk directly (not a Proxmox storage pool)
- Enable **Discard** on the SSD entry only

### Verify Inside TrueNAS

After the VM restarts, open **System → Shell** in TrueNAS:

```bash
lsblk -o NAME,SIZE,ROTA,MODEL
# Expect the OS virtual disk (~32G), the HDD (1.8T, ROTA=1), and the SSD (238G, ROTA=0)
```

---

## 2. Storage Pool Setup

### Create the Pool

**Storage → Create Pool:**

| Setting | Value |
|---------|-------|
| Pool name | `tank` |
| Layout | Stripe (1 disk — no redundancy) |
| Disk | Select the 1.8TB HDD only |
| Ashift | Auto-detect (12 for 4K-sector drives) |

Do not add the SSD here — it is added as L2ARC after pool creation.

### Add the SSD as L2ARC

After `tank` is created:

**Storage → tank → Add Vdevs → Cache:**
- Select the 238GB SSD
- Click **Add Cache**

TrueNAS will immediately begin populating the L2ARC as data is read from the pool. There is no
manual warm-up — the cache builds automatically based on your read patterns.

### Enable Compression and Disable Access Time

**Storage → tank → Edit (root dataset):**

| Setting | Value |
|---------|-------|
| Compression | `lz4` |
| Access Time | `Off` |

`lz4` is a net throughput win on HDD — the CPU decompresses faster than the drive reads, so
effective read speed increases for compressible content (subtitles, configs, documents). Video
files are already compressed and see minimal benefit.

---

## 3. L2ARC Behaviour and Expectations

### What L2ARC Caches

L2ARC stores data evicted from RAM (ARC) that is still likely to be read again. On a media
server, the biggest beneficiaries are:

| Content | Benefit |
|---------|---------|
| Jellyfin image/thumbnail cache | High — small repeated reads |
| ZFS metadata (directory listings, file attributes) | High — every file access reads metadata |
| Subtitle files | High — small, frequently re-read |
| Sonarr/Radarr SQLite databases | Medium — regular small reads |
| 1080p/4K video streams | Low — large sequential reads bypass L2ARC |

### RAM Overhead

L2ARC metadata is stored in RAM ARC. The overhead is roughly **4–6 KB per 1 MB of L2ARC**.
For a fully populated 238GB cache:

```
238 GB × 5 KB/MB ≈ 1.2 GB of ARC used for L2ARC metadata
```

With the default 8 GB VM allocation, ~1.2 GB reserved for L2ARC metadata is acceptable.
If the VM is memory-constrained, reduce L2ARC size or increase VM RAM.

To check current ARC and L2ARC usage in TrueNAS Shell:

```bash
arc_summary | grep -E "ARC|L2ARC"
# or
cat /proc/spl/kstat/zfs/arcstats | grep -E "^size|l2_"
```

### L2ARC is Volatile

L2ARC does not persist across reboots — the cache is cold after every TrueNAS restart. It
warms up within hours of normal use. This is expected behaviour.

---

## 4. Dataset Structure

Hard-links require that both paths share the **same ZFS dataset** (filesystem), not just the
same pool. Each ZFS dataset has its own inode namespace — `ln` across dataset boundaries fails
with `Invalid cross-device link` even when both datasets are on `tank`.

The correct layout uses a **single `tank/data` dataset** for all arr stack storage, with
`media/` and `downloads/` as plain subdirectories inside it. `documents` and `backups` are
separate datasets because they have no hard-link relationship with the media stack.

```
tank/
├── data/               ← Single ZFS dataset — media and downloads share one inode namespace
│   ├── media/          ← Shared media library (NFS to LXC containers)
│   │   ├── tv/         ← Sonarr-managed TV shows
│   │   └── movies/     ← Radarr-managed movies
│   └── downloads/      ← qBittorrent active + completed downloads
│       ├── complete/
│       │   ├── tv/     ← tv-sonarr category landing zone
│       │   └── movies/ ← radarr category landing zone
│       └── incomplete/ ← In-progress torrent data
├── documents/          ← General file storage (SMB)
│   ├── shared/         ← Shared between all users
│   └── private/        ← Per-user subdirectories
└── backups/            ← Config backups from LXC containers
```

### Suggested Quotas (1.8TB HDD)

| Dataset | Quota | Notes |
|---------|-------|-------|
| `tank/data` | 1600 GB | Covers both media and downloads |
| `tank/documents` | 100 GB | General files |
| `tank/backups` | 50 GB | LXC configs are small |

Set via **Storage → [dataset] → Edit → Quota for this dataset**.

### Create Datasets

**Storage → tank → Add Dataset** for each entry.

Settings for `data/` (arr stack — media and downloads):

| Setting | Value |
|---------|-------|
| Record Size | `1M` (optimised for large video file reads/writes on HDD) |
| Compression | `lz4` |
| Case Sensitivity | `Insensitive` |
| ACL Mode | `Passthrough` |
| ACL Type | `POSIX` |

After creating `tank/data`, create the subdirectories inside it via **System → Shell** — do not
create them as child datasets or hard-links will break:

```bash
mkdir -p /mnt/tank/data/media/tv
mkdir -p /mnt/tank/data/media/movies
mkdir -p /mnt/tank/data/downloads/complete/tv
mkdir -p /mnt/tank/data/downloads/complete/movies
mkdir -p /mnt/tank/data/downloads/incomplete
chown -R 1000:1000 /mnt/tank/data
```

> Ansible creates these automatically during deployment — the `mkdir` above is only needed if
> you want the directories to exist before running the playbooks.

Settings for `documents/` (SMB):

| Setting | Value |
|---------|-------|
| Record Size | `128K` |
| ACL Type | `NFSv4` |
| ACL Mode | `Restricted` |
| Case Sensitivity | `Insensitive` |

Settings for `backups/`:

| Setting | Value |
|---------|-------|
| Record Size | `128K` |
| Compression | `zstd` (better ratio for text/config files) |
| ACL Type | `POSIX` |

---

## 5. User and Permission Setup

All arr stack containers run as `PUID=1000 PGID=1000`. Create a matching TrueNAS user so NFS
ownership aligns.

### Create the Media Group

**Credentials → Local Groups → Add:**

| Field | Value |
|-------|-------|
| Group Name | `media` |
| GID | `1000` |

### Create the Media User

**Credentials → Local Users → Add:**

| Field | Value |
|-------|-------|
| Full Name | `Media Services` |
| Username | `media` |
| UID | `1000` |
| Primary Group | `media` |
| Shell | `nologin` |

### Set Dataset Permissions

For the `tank/data` dataset:

**Storage → [dataset] → Edit Permissions:**

| Setting | Value |
|---------|-------|
| Owner User | `media` |
| Owner Group | `media` |
| User | Read, Write, Execute |
| Group | Read, Write, Execute |
| Other | Read, Execute |
| Apply permissions recursively | ✓ |

---

## 6. NFS Exports (for LXC Containers)

NFS preserves POSIX permissions and supports hard-linking — preferred over SMB for
Linux-to-Linux mounts.

### Enable NFS Service

**System → Services → NFS → Start Automatically → Enable**

### Create NFS Shares

**Shares → NFS → Add** for each export:

#### Arr Stack (media + downloads)

Export the entire `tank/data` dataset as a **single share**. Exporting `media` and `downloads`
as separate shares would create two mount points on the client — hard links would fail across
them even though the underlying ZFS dataset is the same.

| Field | Value |
|-------|-------|
| Path | `/mnt/tank/data` |
| Description | `Arr stack data (media + downloads)` |
| Maproot User | `root` |
| Maproot Group | `root` |
| Authorized Networks | `192.168.0.0/24` |

#### Backups

| Field | Value |
|-------|-------|
| Path | `/mnt/tank/backups` |
| Description | `LXC config backups` |
| Authorized Networks | `192.168.0.0/24` |

> Never set Authorized Networks to `0.0.0.0/0`.

### Verify Exports

```bash
showmount -e 192.168.0.220
```

Expected:
```
Export list for 192.168.0.220:
/mnt/tank/backups  192.168.0.0/24
/mnt/tank/data     192.168.0.0/24
```

---

## 7. SMB Shares (for Documents / Windows Clients)

### Enable SMB Service

**System → Services → SMB → Start Automatically → Enable**

**Shares → Windows (SMB) → Configuration:**

| Setting | Value |
|---------|-------|
| NetBIOS Name | `TRUENAS` |
| Workgroup | `WORKGROUP` |

### Create the Documents Share

**Shares → Windows (SMB) → Add:**

| Field | Value |
|-------|-------|
| Path | `/mnt/tank/documents` |
| Name | `documents` |
| Access Based Share Enumeration | ✓ |
| Use Apple-style Character Encoding | ✓ |

### Connect from Clients

| OS | Path |
|----|------|
| Windows | `\\192.168.0.220\documents` |
| macOS | `smb://192.168.0.220/documents` |
| Linux | `mount -t cifs //192.168.0.220/documents /mnt/documents -o username=user,uid=1000,gid=1000` |

---

## 8. Mounting NFS on LXC Containers

### How Mounting Works

Unprivileged LXC containers cannot call `mount(2)` — the kernel strips `CAP_SYS_ADMIN`.
Attempting NFS mounts inside the container produces `mount.nfs: Operation not permitted`.

The correct approach (implemented in `homelab.common.nas_mounts`):

1. `nfs-common` is installed and NFS shares are mounted on the **Proxmox host** (`pve-nas`)
2. LXC bind-mount entries are written to `/etc/pve/lxc/<vmid>.conf` via `pct set`
3. The container reboots to apply the bind mounts — Ansible reconnects automatically

The container sees `/mnt/nas/media` and `/mnt/nas/downloads` as local paths. No NFS
client is needed inside the container.

### Ansible Variable Overrides

Already configured in `inventory/group_vars/nas_services.yml`:

```yaml
nas_nfs_server: "192.168.0.220"

sonarr_media_dir: /mnt/nas/media/tv
sonarr_download_dir: /mnt/nas/downloads

radarr_media_dir: /mnt/nas/media/movies
radarr_download_dir: /mnt/nas/downloads

bazarr_media_dir: /mnt/nas/media
qbittorrent_download_dir: /mnt/nas/downloads
jellyfin_media_dir: /mnt/nas/media
```

### What the `homelab.common.nas_mounts` Role Does

All roles use a single NFS mount: `192.168.0.220:/mnt/tank/data` → `/mnt/nas` on the
Proxmox host, bind-mounted into the container at `/mnt/nas`. `media/` and `downloads/`
are subdirectories of that one mount — same filesystem, hard links work.

| Role | Subdirs created on share |
|------|--------------------------|
| sonarr | `media/tv` |
| radarr | `media/movies` |
| bazarr | — |
| qbittorrent | `downloads/complete/tv`, `downloads/complete/movies`, `downloads/incomplete` |
| jellyfin | — |

### NFS Mount Options (applied on Proxmox host)

| Option | Purpose |
|--------|---------|
| `nfsvers=4` | NFSv4 — better security and performance than v3 |
| `hard` | Retry indefinitely if NAS unavailable — prevents data corruption |
| `intr` | Allow process interrupts — prevents hung processes if NAS goes offline |
| `rsize=131072,wsize=131072` | 128KB transfer blocks — improves HDD sequential throughput |
| `_netdev` | Delay mount until network is up |

---

## 9. Snapshot and Replication Schedule

A single-disk pool cannot self-heal. Snapshots protect against accidental deletion; replication
protects against drive failure.

### Snapshot Tasks

**Data Protection → Periodic Snapshot Tasks → Add:**

| Dataset | Schedule | Lifetime | Notes |
|---------|----------|----------|-------|
| `tank/data` | Daily 03:00 | 14 days | Short — media is large, space is limited |
| `tank/documents` | Daily 03:30 | 60 days | Worth longer retention |
| `tank/backups` | Daily 02:30 | 30 days | Small files, keep more history |

Enable **Recursive** on all tasks.

### Off-Site Replication

**Data Protection → Replication Tasks → Add:**

Replicate at minimum `tank/data` and `tank/documents` to a second machine with ZFS (another
TrueNAS instance, or any Linux host with OpenZFS):

| Setting | Value |
|---------|-------|
| Source | `tank/data`, `tank/documents` |
| Transport | SSH |
| Schedule | Weekly |
| Recursive | ✓ |

---

## 10. Hard-Link Verification

Hard-links allow Sonarr/Radarr to import without copying — both the download path and media
path point to the same inode. Essential on HDD where a 20GB file copy is slow and wastes space.

```bash
# In TrueNAS System → Shell
touch /mnt/tank/data/downloads/complete/tv/test.mkv
ln /mnt/tank/data/downloads/complete/tv/test.mkv /mnt/tank/data/media/tv/test.mkv

# Verify same inode (column 1 must match)
ls -li /mnt/tank/data/downloads/complete/tv/test.mkv /mnt/tank/data/media/tv/test.mkv

rm /mnt/tank/data/downloads/complete/tv/test.mkv /mnt/tank/data/media/tv/test.mkv
```

`Invalid cross-device link` means the two paths are in different ZFS datasets. Hard-links
require the **same dataset** (filesystem), not just the same pool. Both paths must be inside
`tank/data` — they cannot be in separate child datasets such as `tank/media` and
`tank/downloads`.

---

## 11. Service-Specific Configuration

### qBittorrent (192.168.0.234)

**Tools → Options → Downloads:**
- Default Save Path: `/mnt/nas/downloads/complete`
- Keep incomplete in: `/mnt/nas/downloads/incomplete`

Categories:

| Category | Save Path |
|----------|-----------|
| `tv-sonarr` | `/mnt/nas/downloads/complete/tv` |
| `radarr` | `/mnt/nas/downloads/complete/movies` |

**Tools → Options → BitTorrent → Seeding Limits:** set a ratio limit (e.g. 1.0) before removal
so Sonarr/Radarr have time to hard-link the file before qBittorrent deletes it.

### Sonarr (192.168.0.230)

**Settings → Media Management:**
- Use Hardlinks instead of Copy: ✓
- Root Folders: `/mnt/nas/media/tv`

**Settings → Download Clients → qBittorrent:** Category: `tv-sonarr`

### Radarr (192.168.0.231)

**Settings → Media Management:**
- Use Hardlinks instead of Copy: ✓
- Root Folders: `/mnt/nas/media/movies`

**Settings → Download Clients → qBittorrent:** Category: `radarr`

### Jellyfin (192.168.0.235)

**Dashboard → Libraries → Add Media Library:**

| Library | Path |
|---------|------|
| TV Shows | `/mnt/nas/media/tv` |
| Movies | `/mnt/nas/media/movies` |

Enable **Real-time Monitoring** for both libraries.

The L2ARC SSD will cache Jellyfin's image/thumbnail database and metadata reads, noticeably
improving library browse speed. Large video file streaming reads directly from the HDD and is
unaffected by L2ARC — prefer direct play in clients to avoid transcoding load.

### Bazarr (192.168.0.232)

Ensure the container mounts `/mnt/nas/media` — subtitles are written alongside video files.
See [ARR-STACK-INTEGRATION-GUIDE.md](./ARR-STACK-INTEGRATION-GUIDE.md) for API key wiring.

---

## 12. Troubleshooting

### L2ARC Not Populated / No Cache Hit Improvement

L2ARC is cold after every reboot and builds passively. After a day of normal use, run in
TrueNAS Shell:

```bash
arc_summary | grep -A5 "L2 ARC"
```

If `L2 ARC size` remains at 0 after extended use, confirm the SSD vdev was added correctly:

```bash
zpool status tank
# Should show a 'cache' section listing the SSD
```

If missing, re-add via **Storage → tank → Add Vdevs → Cache**.

### NFS Mount Fails on Container Boot

**Cause:** NFS not ready when Docker starts.
**Fix:** Confirm `_netdev` is in `/etc/fstab`. Add `After=network-online.target remote-fs.target`
to the Docker service unit if needed.

### Permission Denied Writing to NFS Share

**Fix:**
1. Confirm TrueNAS `media` user UID=1000 and dataset owner is `media`
2. Re-apply permissions recursively on the dataset
3. Confirm `Maproot User: root` is set on the NFS share

### Hard-Links Not Working

**Fix:** Both NFS exports must come from the same `tank` pool. Run `df -h` inside the container
— both mount sources should show `192.168.0.220:/mnt/tank/...`.

### Slow NFS Throughput

**Fix:**
- Confirm `rsize=131072,wsize=131072` is in mount options
- Run a ZFS scrub to rule out read errors slowing the pool: **Data Protection → Scrub Tasks → Run Now**
- Check HDD health: **Storage → Disks → [disk] → Edit → Run S.M.A.R.T. Test (short)**

### Pool Degraded or SMART Errors

```bash
# In TrueNAS Shell
zpool status tank
zpool scrub tank
```

A single-disk stripe cannot self-heal. On any SMART errors or checksum failures, back up
immediately and replace the HDD.

### TrueNAS WebUI Unreachable

```bash
# From pve-nas (192.168.0.57)
ping 192.168.0.220
qm list | grep -i truenas
qm status <VMID>
qm console <VMID>
```
