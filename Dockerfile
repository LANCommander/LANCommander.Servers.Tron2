# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Tron 2.0 Game Server" \
      org.opencontainers.image.description="Dedicated server for Tron 2.0 (TRONSrv.exe v1.042) running under Wine" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Tron 2.0" \
      app.lancommander.server.external-id.hq="5a68f5d5-1528-4eaa-b1fb-f202df0dffd4" \
      app.lancommander.server.external-id.igdb="6217" \
      app.lancommander.server.external-id.steam="327740" \
      app.lancommander.server.external-id.gog="1655444396"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Tron 2.0 v1.042 install (TRONSrv.exe, Game.rez,
#     gamep5.rez, ...) in /config/Server, or set TRON2_ARCHIVE_URL to a zip of one
#   - TRONSrv.exe is a GUI app. `-config <name>` loads ServerData\<name>.txt and hosts right away.
#     The configure hook creates that file and writes the TRON2_* settings below into it on every
#     start (empty settings are left alone)
#   - TRON2_GAME_TYPE: discarena, disctournament, lightcycles, deathmatch, teamdeathmatch (or 4-8)
#   - TRON2_MAPS is a comma-separated rotation for that game type; bare names are looked up in the
#     retail folders (DM-*, DISCARENA*, LC_*). Empty uses every retail map of that game type;
#     "config" keeps the list in the config file
#   - TRON2_REZ is the comma-separated list of extra rez files/folders the server loads after the
#     ones built into TRONSrv.exe. Empty means gamep5.rez, gamep6.rez and tcdg\game (the Killer
#     App Mod's loose files), whichever exist. TRON2_MOD loads every rez in Custom\Mods\<mod>
#   - The server needs a window, so it runs under Xvfb
# ----------------------------
ENV TRON2_ARCHIVE_URL="" \
    TRON2_CONFIG="lancommander" \
    TRON2_SERVER_NAME="Tron 2.0" \
    TRON2_PORT="27888" \
    TRON2_GAME_TYPE="discarena" \
    TRON2_MAPS="" \
    TRON2_MAX_PLAYERS="" \
    TRON2_TIME_LIMIT="" \
    TRON2_WIN_LIMIT="" \
    TRON2_FRIENDLY_FIRE="" \
    TRON2_GAMES_PER_MAP="" \
    TRON2_OPTIONS="" \
    TRON2_PASSWORD="" \
    TRON2_SCMD_PASSWORD="" \
    TRON2_LAN="true" \
    TRON2_REZ="" \
    TRON2_MOD="Retail" \
    WINE_XVFB="true" \
    START_EXE="/usr/local/bin/tron2-server" \
    START_ARGS=""

COPY Scripts/tron2-server /usr/local/bin/tron2-server
RUN chmod +x /usr/local/bin/tron2-server

COPY Hooks/ "${BASE_HOOKS}/"

# 27888/udp: game and GameSpy status queries (TRON2_PORT)
EXPOSE 27888/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
