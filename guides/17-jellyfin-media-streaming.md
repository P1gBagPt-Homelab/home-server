# Guide 17: Jellyfin Media Streaming & Hardware Transcoding

> **Status**: ✅ **Fully Deployed & Operational on Project Janus**  
> * **Service**: [Jellyfin](https://jellyfin.org/) (Open-Source Media System)  
> * **Public SSL URL**: [`https://stream.your-domain.duckdns.org`](https://stream.your-domain.duckdns.org)  
> * **Local LAN Endpoint**: `http://192.168.1.68:8096`  
> * **Platform**: Coolify PaaS (Docker Compose)  
> * **Hardware Acceleration**: ASUS ROG Strix RTX 2070 (NVIDIA NVENC)  
> * **Storage Location**: SAMSUNG HD103SJ 1TB HDD (`/data/storage/media/`)  
> * **Metadata & Cache**: High-Speed SSD Pool (`/data/volumes/jellyfin/`)  
> * **Target Clients**: Xiaomi Google TV (Android TV), Web browser, iOS & Android devices  

---

## 1. Architecture & Storage Plan

To maximize performance and eliminate playback buffering:
* **Posters, Cache & Metadata on SSD Pool (`/data/volumes/jellyfin/`)**: Keeps the user interface, library scrolling, and poster loading instantaneous.
* **Movie & TV Video Files on 1TB HDD (`/data/storage/media/`)**: Sequential video reads place virtually zero load on mechanical drives, isolating large media files on dedicated bulk storage.

```text
/data/
├── volumes/jellyfin/             <-- Fast SSD Pool (~456GB)
│   ├── config/                   <-- Library databases, user preferences, watch history
│   └── cache/                    <-- Thumbnail images, transcoded trickplay scrubbers
└── storage/media/                <-- 1TB HDD (SAMSUNG HD103SJ)
    ├── movies/                   <-- Movie files (MKV, MP4, etc.)
    └── tv/                       <-- TV series organized by show / season
```

---

## 2. Directory Preparation on Janus

Created the directory structure on Ubuntu Server with proper ownership:

```bash
# Create SSD config and cache directories
sudo mkdir -p /data/volumes/jellyfin/config /data/volumes/jellyfin/cache

# Create HDD media libraries
sudo mkdir -p /data/storage/media/movies /data/storage/media/tv

# Ensure daniel user owns the folders
sudo chown -R $USER:$USER /data/volumes/jellyfin /data/storage/media
```

---

## 3. Coolify Docker Compose Service

Deployed directly via **Coolify PaaS** under **Core Services / Production**:

```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=UTC
    volumes:
      - /data/volumes/jellyfin/config:/config
      - /data/volumes/jellyfin/cache:/cache
      - /data/storage/media/movies:/media/movies:ro
      - /data/storage/media/tv:/media/tv:ro
    ports:
      - "8096:8096"
      # Auto-discovery broadcast ports (allows Xiaomi TV to discover Janus automatically)
      - "7359:7359/udp"
      - "1900:1900/udp"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

### Traefik Reverse Proxy & SSL Configuration
* **Domain**: `stream.your-domain.duckdns.org`
* **Internal Routing Port**: `8096`
* Automated Let's Encrypt Wildcard SSL handled by Traefik.

---

## 4. Hardware Transcoding Setup (RTX 2070 NVENC)

To ensure zero CPU strain during 4K or HDR playback:

1. Open **Jellyfin** -> Click hamburger menu (top left) -> **Dashboard** -> **Playback**.
2. Under **Hardware acceleration**, select **NVIDIA NVENC**.
3. Under **Enable hardware decoding for**, tick:
   * [x] **H.264**
   * [x] **HEVC (H.265)**
   * [x] **MPEG2**
   * [x] **VC1**
   * [x] **VP9**
4. Under **Hardware encoding options**:
   * [x] **Enable Hardware Encoding**
   * [x] **Enable VPP Tone mapping** (preserves colors when transcoding HDR content to SDR)
   * [x] **Enable Tone mapping**
5. Click **Save** at the bottom of the page.

---

## 5. Xiaomi Google TV App Setup

1. On your **Xiaomi TV / TV Box**, open the **Google Play Store**.
2. Search for and install **Jellyfin for Android TV** (official app).
3. Open the app:
   * Thanks to UDP port `7359` exposed in Docker, the app **automatically detects** `Janus` on your local network.
   * If prompted manually, enter: `http://192.168.1.68:8096`.
4. Log in with your admin/user credentials.
5. Enjoy smooth, remote-controlled playback with full Direct Play and zero transcoding delay!

---

## 6. Adding Movies & Series

Jellyfin automatically queries TheMovieDB (TMDb) for posters, plot summaries, ratings, and subtitles when you follow standard naming:

```text
/data/storage/media/movies/
└── Interstellar (2014)/
    └── Interstellar (2014) [1080p].mkv

/data/storage/media/tv/
└── Breaking Bad/
    └── Season 01/
        ├── Breaking Bad - S01E01 - Pilot.mkv
        └── Breaking Bad - S01E02 - Cat's in the Bag.mkv
```

### Uploading Files from Mac / PC
Connect via SFTP using **Cyberduck** or **FileZilla**:
* **Host**: `192.168.1.68` (or `stream.your-domain.duckdns.org`)
* **Port**: `22` (SSH)
* **Destination**: `/data/storage/media/movies/`

Or via Terminal:
```bash
scp -r "/path/to/movie-folder" daniel@192.168.1.68:/data/storage/media/movies/
```
