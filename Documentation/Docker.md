---
sidebar_label: Docker
---

# Tron 2.0 Docker Container

This Docker container runs a Tron 2.0 dedicated server. It is built on the WINE image and runs the game's stand-alone server, `TRONSrv.exe` from the 1.042 update, on a virtual display. The container doesn't download the game, so you provide the files.

## Quick Start

```yaml
services:
  tron2:
    image: lancommander/tron2:latest
    container_name: tron2

    ports:
      - 27888:27888/udp

    volumes:
      - "/data/Servers/Tron 2.0/Disc Arena:/config"

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

Before the first start, copy a Tron 2.0 v1.042 install, the folder that contains `TRONSrv.exe`, into `Server/`. You can instead set `TRON2_ARCHIVE_URL` to a zip of that folder.

## How It Starts

1. `PostInitialization/10-InitializeWinePrefix.ps1` (from the WINE image) creates the Wine prefix in `/config/wineprefix`.
2. `PostInitialization/20-InstallTron2.ps1` checks for `Server/TRONSrv.exe`. If it's missing and `TRON2_ARCHIVE_URL` is set, the hook downloads and extracts the archive and remounts the overlay.
3. `PostInitialization/30-ConfigureTron2.ps1` creates `ServerData/<TRON2_CONFIG>.txt` with the game's defaults if it doesn't exist, then writes the non-empty `TRON2_*` settings and the map rotation into it.
4. `START_EXE` (`/usr/local/bin/tron2-server`) writes the rez list and mod into the Wine registry (see [Resources and Mods](#resources-and-mods)), then runs `TRONSrv.exe -config <TRON2_CONFIG> [START_ARGS]` from the game folder under Wine and Xvfb. `-config` makes TRONSrv load the configuration and host without asking which one to use.

TRONSrv's console is a list box in its window, so `docker logs` ends at:

```
Extra rez files: -rez gamep5.rez -rez gamep6.REZ -rez tcdg\GAME
Mod: Retail
Starting: TRONSrv.exe -config lancommander
Game port and status queries on 27888/udp
```

To check that the server is up, send a GameSpy status query to the game port:

```bash
python3 -c 'import socket; s=socket.socket(2,2); s.settimeout(3); s.sendto(b"\\status\\",("<server>",27888)); print(s.recvfrom(4096)[0])'
# b'\\hostname\\My Tron 2.0 Server\\gamever\\1.019\\mapname\\DISCARENA01\\gametype\\DiscArena\\numplayers\\0\\maxplayers\\16\\...\\modname\\Retail\\dedicated\\1\\...'
```

`gamever` reads 1.019 on a 1.042 install.

## Configuration Options

### Ports

- **27888/udp**: Game and GameSpy status queries (`TRON2_PORT`)

### Environment Variables

See the [README](../README.md#environment-variables) for the full table.

### Server Configuration (`ServerData/<name>.txt`)

The game writes these files from its Multiplayer > Host menu, and TRONSrv reads them. It is an INI file. The hook edits it through the merged view, so the edited copy is in `Overlay/ServerData/` and is yours to change. A key that also has a non-empty `TRON2_*` variable is overwritten on every start. Set `TRON2_MAPS=config` to manage the rotation in the file yourself. A configuration saved by the game works too: copy it to `Overlay/ServerData/` and set `TRON2_CONFIG` to its name.

| Section | Keys |
|---------|------|
| `[Settings]` | `ServerName`, `Port`, `GameType`, `Password`, `Locked` (`1` = password required), `AllowSCMD`, `SCMDPassword`, `LANOnly`, `Bandwidth` (preset), `BandwidthCustom`, `Dedicated` |
| `[DiscArena]` | `Map00`-`Map31` (rotation, e.g. `"Worlds\RetailMultiPlayer\DiscArena\DISCARENA01"`), `MaxPlayers`, `TimeLimit`, `WinLimit`, `PointsPerMatch`, `MatchTimeLimit`, `MaxTeamSize`, `FriendlyFire`, `AllowAutoAim`, `AirControl`, `PreGameDelay`, `MaxPing`, `GamesPerMap` |
| `[DiscTournament]` | Maps, `MaxPlayers`, `PointsPerMatch`, `MatchTimeLimit`, `MaxTeamSize`, `TournamentMode`, `TeamsToStart`, `FriendlyFire`, ... |
| `[Lightcycles]` | Maps, `MaxPlayers`, `TotalRaces`, `TotalPoints`, `TotalTime`, `GameSpeed`, `TrailLength`, `MaxTeamSize`, point values, `PowerupAllow*` (`TRUE`/`FALSE`) |
| `[Deathmatch]` | Maps, `MaxPlayers`, `TimeLimit`, `WinLimit`, `RunSpeed`, `AirControl`, ... |
| `[TeamDeathmatch]` | As Deathmatch, plus `MaxTeamSize`, `FriendlyFire`, `Team1Name`/`Team1Color`, `Team2Name`/`Team2Color` |

`GameType` numbers: 4 Deathmatch, 5 Disc Arena, 6 Disc Tournament, 7 Light Cycles, 8 Team Deathmatch. 0-3 are single player modes, which TRONSrv can't host.

### Resources and Mods

`TRONSrv.exe` has a fixed list of rez files (`game.rez`, `game2.rez`, `sound.rez`, ...) that doesn't include the 1.042 update's `gamep5.rez`, which holds the multiplayer game code. The update's installer adds it through the registry, `HKLM\Software\Monolith Productions\TRON 2.0\1.0`: `UpdateNum` and `UpdateCommandLine0`..., whose `-rez <file>` entries the server also loads. The launcher writes those values on every start from `TRON2_REZ`. It also writes `SelectedMod` (`TRON2_MOD`), which makes the server load every rez in `Custom\Mods\<mod>\`.

The defaults match LANCommander's Tron 2.0 client, which plays with the Killer App Mod: `gamep5.rez`, `gamep6.rez`, the mod's loose files in `tcdg\game` and `Custom\Mods\Retail\Killer_App_Mod.REZ`. On a plain install the missing ones are skipped.

### SCMD

With `TRON2_SCMD_PASSWORD` set, players log in by typing `SCMD login <password>` in chat. `SCMD help` lists the commands: `listclients`, `bootname`, `bootid`, `addban`, `listbans`, `removeban`, `banclient`, `listmaps`, `nextmap`, `setmap`.

### Hooks

| Hook | When |
|------|------|
| `PreInstallTron2` / `PostInstallTron2` | Around the game file check/download |
| `PreInitializeWinePrefix` / `PostInitializeWinePrefix` | Around Wine prefix creation (WINE image) |

Put `.ps1` scripts in `config/Scripts/Hooks/<HookName>/`.

## Troubleshooting

- **The server exits or no port is bound, with "Unable to load resources" on the virtual display**: `gamep5.rez` isn't loaded. Check that it's in the game folder and in the launcher's `Extra rez files:` line, and that `TRON2_REZ` (if set) lists it.
- **`wine: Unhandled page fault ... at address 0040AC1C` and `nodrv_CreateWindow` in the log**: TRONSrv started without a display. Keep `WINE_XVFB=true`. The launcher waits for the wineserver used by `wine reg` to exit for this reason; a custom `START_EXE` must do the same.
- **The port is bound but status queries get no reply**: the configuration has no maps for the game type, a map doesn't exist, or the game type is 0-3. TRONSrv then shows an error on the virtual display. Check the map names and the hook's log line.
- **No console output or console commands**: the console only exists in TRONSrv's window. Use SCMD in game, or change settings and restart.
- **Not in the in-game server list**: LAN discovery is untested with this image. Discovery by broadcast needs the container on the LAN itself (macvlan/ipvlan, or `network_mode: host`). Clients can always join by IP.
- **CPU**: an idle server uses about 7% of a core and 240 MB of memory.
