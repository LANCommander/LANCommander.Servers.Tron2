# Tron 2.0 Server (Docker)

This repository provides a Dockerized **Tron 2.0** dedicated server. Tron 2.0 (Monolith, 2003) ships a Windows-only stand-alone server, `TRONSrv.exe`, with its 1.042 update. The image runs it under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs `TRONSrv.exe -config <name>`, which hosts right away with no dialog
- Server name, port, game type, map rotation, limits and passwords are environment variables, written into the server configuration (`ServerData\<name>.txt`) on every start
- All five multiplayer game types: Disc Arena, Disc Tournament, Light Cycles, and the 1.042 update's Deathmatch and Team Deathmatch
- Loads the 1.042 update's content and mods (e.g. the Killer App Mod) the way the game client does
- TRONSrv is a GUI app, so it runs on a virtual display (Xvfb)
- GameSpy `\status\` queries on the game port for monitoring
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  tron2:
    image: lancommander/tron2:latest
    container_name: tron2

    ports:
      - "27888:27888/udp"

    volumes:
      - ./config:/config

    environment:
      TRON2_SERVER_NAME: "My Tron 2.0 Server"
      TRON2_GAME_TYPE: "discarena"
      TRON2_SCMD_PASSWORD: "changeme"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

---

## Game Files

Tron 2.0 is retail software with no public download. You must provide a v1.042 install (retail with the 1.042 update, or the GOG release), the folder that contains `TRONSrv.exe`, `server.dll`, `Game.rez`, `Game2.rez`, `Sound.rez`, `gamep5.rez` and `gamep6.rez`:

- copy that folder to `config/Server/`, **or**
- set `TRON2_ARCHIVE_URL` to a zip of that folder, e.g. a LANCommander archive. It is downloaded and extracted on first start, if `Server/TRONSrv.exe` doesn't exist yet. The Killer App Mod installer (`ka_mod_v1x1a_setup.exe`) and `KAModBackups/` are not extracted.

The server doesn't need `Movies/`.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Tron 2.0 install (TRONSrv.exe, server.dll, *.rez, Custom/ ...)
    ├── Overlay/           # Your files, layered on top of Server/ (the generated
    │                      # ServerData/<name>.txt lands here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).
The `TRON2_*` server settings are written into `ServerData\<TRON2_CONFIG>.txt` on every start. Settings left empty are not touched, so you can set them in that file instead. Limits and the map list apply to the section of the selected game type.

| Variable | Description | Default |
|----------|-------------|---------|
| `TRON2_CONFIG` | Server configuration, `ServerData\<name>.txt` (`-config`). Created with the game's defaults if missing | `lancommander` |
| `TRON2_SERVER_NAME` | `ServerName` | `Tron 2.0` |
| `TRON2_PORT` | Game and query port (`Port`) | `27888` |
| `TRON2_GAME_TYPE` | `discarena`, `disctournament`, `lightcycles`, `deathmatch`, `teamdeathmatch`, or `4`-`8` (`GameType`) | `discarena` |
| `TRON2_MAPS` | Comma-separated rotation, up to 32. Bare names are looked up in the retail folders (`DM-*`, `DISCARENA*`, `LC_*`); give a path with a backslash for others. Empty = every retail map of the game type; `config` = keep the file's list | |
| `TRON2_MAX_PLAYERS` | `MaxPlayers` | |
| `TRON2_TIME_LIMIT` | Minutes. `TimeLimit`; `MatchTimeLimit` in Disc Tournament, `TotalTime` in Light Cycles | |
| `TRON2_WIN_LIMIT` | `WinLimit` (derezzes, or matches in Disc Arena); `PointsPerMatch` in Disc Tournament, `TotalPoints` in Light Cycles | |
| `TRON2_FRIENDLY_FIRE` | `FriendlyFire` (Disc Arena, Disc Tournament, Team Deathmatch) | |
| `TRON2_GAMES_PER_MAP` | `GamesPerMap`. Light Cycles uses `TotalRaces` instead | |
| `TRON2_OPTIONS` | Any other keys of the game type's section, as `Key=Value;Key=Value` (e.g. `TotalRaces=3;GameSpeed=2`) | |
| `TRON2_PASSWORD` | Join password (`Password`, sets `Locked`). Empty = open server | |
| `TRON2_SCMD_PASSWORD` | Admin password (`SCMDPassword`, sets `AllowSCMD`), used in chat with `SCMD login <password>`. Empty = SCMD off | |
| `TRON2_LAN` | `LANOnly` | `true` |
| `TRON2_REZ` | Comma-separated extra rez files/folders, loaded after the ones built into `TRONSrv.exe`. Empty = `gamep5.rez`, `gamep6.rez`, `tcdg\game`, whichever exist | |
| `TRON2_MOD` | Mod folder; every rez in `Custom\Mods\<mod>` is loaded | `Retail` |
| `TRON2_ARCHIVE_URL` | Zip of the game folder, used if `Server/TRONSrv.exe` is missing | |
| `WINE_XVFB` | Run on a virtual display. TRONSrv needs one | `true` |
| `START_EXE` | Launcher | `/usr/local/bin/tron2-server` |
| `START_ARGS` | Added to the `TRONSrv.exe` command line | |

Default rotations:

- Disc Arena, Disc Tournament: `DISCARENA01`-`DISCARENA05`
- Deathmatch, Team Deathmatch: `DM-01`, `DM-02`, `DM-03`
- Light Cycles: `LC_01S01`-`LC_04S03` (12 maps)

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/tron2:local .
```

---

## License

Tron 2.0 and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
