#Requires -Modules Logging

# Write the TRON2_* settings into ServerData\<TRON2_CONFIG>.txt, the server configuration
# TRONSrv.exe loads with -config. It is an INI file: [Settings] (name, port, game type, passwords)
# and one section per game type (map rotation as Map00..Map31, limits). The game writes these
# files from its Host menu; when the file doesn't exist the hook creates it from the game's own
# defaults below. It is edited through the merged view, so the edited copy lands in Overlay/ and
# can be changed there; keys without a non-empty TRON2_* setting keep their value.

$name = if ($Env:TRON2_CONFIG) { $Env:TRON2_CONFIG } else { 'lancommander' }
$dir  = Join-Path $Env:SERVER_ROOT 'ServerData'
$file = Join-Path $dir "$name.txt"

if (-not (Test-Path -Path (Join-Path $Env:SERVER_ROOT 'TRONSrv.exe'))) {
    Write-Log -Level Error "TRONSrv.exe not found in $Env:SERVER_ROOT; skipping server configuration"
    return
}

# GameType numbers in [Settings] and the section each one reads. 0-3 are single player modes;
# TRONSrv.exe can't host them.
$gameTypes = [ordered]@{
    'deathmatch'     = @{ Id = 4; Section = 'Deathmatch' }
    'discarena'      = @{ Id = 5; Section = 'DiscArena' }
    'disctournament' = @{ Id = 6; Section = 'DiscTournament' }
    'lightcycles'    = @{ Id = 7; Section = 'Lightcycles' }
    'teamdeathmatch' = @{ Id = 8; Section = 'TeamDeathmatch' }
}

# The game's defaults for a new server configuration (Map00..Map31 are added per section)
$defaults = [ordered]@{
    'Settings' = [ordered]@{
        'Dedicated' = '1'; 'ServerName' = '"Tron 2.0"'; 'Port' = '27888'; 'GameType' = '5'
        'LANOnly' = '1'; 'Locked' = '0'; 'Password' = '""'; 'AllowSCMD' = '0'; 'SCMDPassword' = '""'
        'Bandwidth' = '5'; 'BandwidthCustom' = '256'
    }
    'DiscArena' = [ordered]@{
        'MaxPlayers' = '16'; 'TimeLimit' = '20'; 'PointsPerMatch' = '3'; 'MatchTimeLimit' = '5'
        'MaxPing' = '0'; 'WinLimit' = '5'; 'AllowAutoAim' = '1'; 'MaxTeamSize' = '4'
        'PreGameDelay' = '0'; 'FriendlyFire' = '0'; 'AirControl' = '50'; 'DiscsInSpectator' = '1'
        'GamesPerMap' = '1'
    }
    'DiscTournament' = [ordered]@{
        'MaxPlayers' = '8'; 'PointsPerMatch' = '3'; 'MatchTimeLimit' = '5'; 'MaxPing' = '0'
        'AllowAutoAim' = '1'; 'MaxTeamSize' = '2'; 'PreGameDelay' = '30'; 'TournamentMode' = '0'
        'FriendlyFire' = '0'; 'AirControl' = '50'; 'TeamsToStart' = '2'; 'DiscsInSpectator' = '1'
        'GamesPerMap' = '1'
    }
    'Lightcycles' = [ordered]@{
        'MaxPlayers' = '8'; 'MaxTeamSize' = '2'; 'MaxPing' = '80'; 'GameSpeed' = '1'
        'TrailLength' = '1'; 'TotalRaces' = '5'; 'TotalPoints' = '0'; 'TotalTime' = '0'
        'KillPointValue' = '1'; 'SelfKillPointValue' = '0'; 'WinRacePointValue' = '6'
        'WaitForPlayersTime' = '10'; 'AllowedCycleType' = '0'
        'PowerupAllowTurbo' = 'TRUE'; 'PowerupAllowForceUse' = 'TRUE'; 'PowerupAllowShield' = 'TRUE'
        'PowerupAllowTrailReset' = 'TRUE'; 'PowerupAllowTrailSpike' = 'TRUE'
        'PowerupAllowTurboCurse' = 'TRUE'; 'PowerupAllowMissile' = 'TRUE'
        'PowerupAllowGrab' = 'TRUE'; 'PowerupAllowWallExtender' = 'TRUE'
    }
    'Deathmatch' = [ordered]@{
        'MaxPlayers' = '16'; 'TimeLimit' = '5'; 'MaxPing' = '0'; 'WinLimit' = '10'
        'AllowAutoAim' = '1'; 'PreGameDelay' = '0'; 'AirControl' = '50'; 'RunSpeed' = '120'
        'GamesPerMap' = '1'
    }
    'TeamDeathmatch' = [ordered]@{
        'MaxPlayers' = '16'; 'TimeLimit' = '5'; 'MaxPing' = '0'; 'WinLimit' = '10'
        'AllowAutoAim' = '1'; 'MaxTeamSize' = '8'; 'PreGameDelay' = '0'; 'FriendlyFire' = '0'
        'AirControl' = '50'; 'RunSpeed' = '120'; 'Team1Name' = '"The Programs"'; 'Team1Color' = '0'
        'Team2Name' = '"The Corruption"'; 'Team2Color' = '2'; 'GamesPerMap' = '1'
    }
}

# Retail maps of each game type (Game2.rez and the 1.042 patch's gamep5.rez)
$folders = @{
    'dm'        = 'Worlds\RetailMultiPlayer\Deathmatch'
    'discarena' = 'Worlds\RetailMultiPlayer\DiscArena'
    'lc'        = 'Worlds\RetailLightCycle'
}
$discMaps = 'DISCARENA01,DISCARENA02,DISCARENA03,DISCARENA04,DISCARENA05'
$dmMaps   = 'DM-01,DM-02,DM-03'
$lcMaps   = (1..4 | ForEach-Object { $m = $_; 1..3 | ForEach-Object { 'LC_{0:D2}S{1:D2}' -f $m, $_ } }) -join ','
$defaultMaps = @{
    'DiscArena'      = $discMaps
    'DiscTournament' = $discMaps
    'Lightcycles'    = $lcMaps
    'Deathmatch'     = $dmMaps
    'TeamDeathmatch' = $dmMaps
}

$ini = [ordered]@{}

if (Test-Path -Path $file) {
    # Parse into ordered sections of ordered `Key = Value` pairs, keeping values verbatim
    $section = $null
    foreach ($line in [System.IO.File]::ReadAllLines($file)) {
        if ($line -match '^\s*\[([^\]]+)\]') {
            $section = $Matches[1]
            if (-not $ini.Contains($section)) { $ini[$section] = [ordered]@{} }
        } elseif ($section -and $line -match '^\s*([^=]+?)\s*=\s*(.*?)\s*$') {
            $ini[$section][$Matches[1]] = $Matches[2]
        }
    }
} else {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    foreach ($s in $defaults.GetEnumerator()) {
        $ini[$s.Key] = [ordered]@{}
        if ($s.Key -ne 'Settings') {
            for ($i = 0; $i -lt 32; $i++) { $ini[$s.Key]['Map{0:D2}' -f $i] = '""' }
        }
        foreach ($kv in $s.Value.GetEnumerator()) { $ini[$s.Key][$kv.Key] = $kv.Value }
    }
    Write-Log "Created ServerData/$name.txt"
}

function Set-Value([string] $Section, [string] $Key, [string] $Value) {
    if (-not $ini.Contains($Section)) { $ini[$Section] = [ordered]@{} }
    $ini[$Section][$Key] = $Value
}

function Set-String([string] $Section, [string] $Key, [string] $Value) {
    Set-Value $Section $Key "`"$($Value.Replace('"', ''))`""
}

function ConvertTo-Flag([string] $Value) {
    if ($Value -match '^(1|true|yes|on)$') { '1' } else { '0' }
}

# Game type
$type = $gameTypes['discarena']
if ($Env:TRON2_GAME_TYPE) {
    $key = $Env:TRON2_GAME_TYPE.ToLowerInvariant() -replace '[^a-z0-9]', ''
    $type = $gameTypes.Values | Where-Object { $_.Id -eq ($key -as [int]) -or $_.Section -ieq $key } | Select-Object -First 1
    if (-not $type) { $type = $gameTypes[$key] }
    if (-not $type) { throw "Unknown TRON2_GAME_TYPE '$Env:TRON2_GAME_TYPE' (use $($gameTypes.Keys -join ', ') or 4-8)" }
}
$typeSection = $type.Section

# A section the file doesn't have yet (e.g. a config saved by the game) starts from the defaults
if (-not $ini.Contains($typeSection)) {
    $ini[$typeSection] = [ordered]@{}
    foreach ($kv in $defaults[$typeSection].GetEnumerator()) { $ini[$typeSection][$kv.Key] = $kv.Value }
}

Set-Value 'Settings' 'Dedicated' '1'
Set-Value 'Settings' 'GameType' "$($type.Id)"

if ($Env:TRON2_SERVER_NAME) { Set-String 'Settings' 'ServerName' $Env:TRON2_SERVER_NAME }
if ($Env:TRON2_PORT)        { Set-Value  'Settings' 'Port' $Env:TRON2_PORT }
if ($Env:TRON2_LAN)         { Set-Value  'Settings' 'LANOnly' (ConvertTo-Flag $Env:TRON2_LAN) }

# The join password only applies while the server is Locked
if ($Env:TRON2_PASSWORD) {
    Set-String 'Settings' 'Password' $Env:TRON2_PASSWORD
    Set-Value  'Settings' 'Locked' '1'
} else {
    Set-String 'Settings' 'Password' ''
    Set-Value  'Settings' 'Locked' '0'
}

# Server admin commands (`SCMD login <password>` in chat). Off without a password.
if ($Env:TRON2_SCMD_PASSWORD) {
    Set-String 'Settings' 'SCMDPassword' $Env:TRON2_SCMD_PASSWORD
    Set-Value  'Settings' 'AllowSCMD' '1'
} else {
    Set-String 'Settings' 'SCMDPassword' ''
    Set-Value  'Settings' 'AllowSCMD' '0'
}

# Map rotation for the selected game type (at most 32). A bare name is looked up in the retail
# folder for its prefix; give a path with a backslash (e.g. Worlds\Custom\MyMap) for anything else.
$maps = if ($Env:TRON2_MAPS) { $Env:TRON2_MAPS } else { $defaultMaps[$typeSection] }

if ($maps -ine 'config') {
    $list = @($maps -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($list.Count -gt 32) {
        Write-Log -Level Warning "TRON2_MAPS has $($list.Count) maps; only the first 32 are used"
        $list = $list[0..31]
    }

    $rotation = [ordered]@{}
    for ($i = 0; $i -lt 32; $i++) {
        $map = ''
        if ($i -lt $list.Count) {
            $map = $list[$i].Replace('/', '\')
            if (-not $map.Contains('\')) {
                $folder = switch -Regex ($map) {
                    '^dm-'        { $folders['dm'] }
                    '^discarena'  { $folders['discarena'] }
                    '^lc_'        { $folders['lc'] }
                    default       { throw "Map '$map' has no folder; use its full path (e.g. Worlds\RetailMultiPlayer\DiscArena\$map)" }
                }
                $map = "$folder\$map"
            }
        }
        $rotation['Map{0:D2}' -f $i] = "`"$map`""
    }

    foreach ($s in $ini[$typeSection].GetEnumerator()) {
        if ($s.Key -notmatch '^Map\d+$') { $rotation[$s.Key] = $s.Value }
    }
    $ini[$typeSection] = $rotation
}

if (-not ($ini[$typeSection].Keys | Where-Object { $_ -match '^Map\d+$' -and $ini[$typeSection][$_] -ne '""' })) {
    Write-Log -Level Error "No maps in [$typeSection] of ServerData/$name.txt; TRONSrv will stop with 'This config file has no maps selected'"
}

# Limits. Disc Tournament plays matches (MatchTimeLimit, PointsPerMatch) and Light Cycles races
# (TotalTime, TotalPoints); the others use TimeLimit and WinLimit.
$timeKey, $winKey = switch ($typeSection) {
    'DiscTournament' { 'MatchTimeLimit', 'PointsPerMatch' }
    'Lightcycles'    { 'TotalTime', 'TotalPoints' }
    default          { 'TimeLimit', 'WinLimit' }
}

if ($Env:TRON2_MAX_PLAYERS)   { Set-Value $typeSection 'MaxPlayers' $Env:TRON2_MAX_PLAYERS }
if ($Env:TRON2_TIME_LIMIT)    { Set-Value $typeSection $timeKey $Env:TRON2_TIME_LIMIT }
if ($Env:TRON2_WIN_LIMIT)     { Set-Value $typeSection $winKey $Env:TRON2_WIN_LIMIT }
if ($Env:TRON2_GAMES_PER_MAP -and $typeSection -ne 'Lightcycles') {
    Set-Value $typeSection 'GamesPerMap' $Env:TRON2_GAMES_PER_MAP
}
if ($Env:TRON2_FRIENDLY_FIRE -and $ini[$typeSection].Contains('FriendlyFire')) {
    Set-Value $typeSection 'FriendlyFire' (ConvertTo-Flag $Env:TRON2_FRIENDLY_FIRE)
}

# Any other key of the game type's section, as `Key=Value;Key=Value`
if ($Env:TRON2_OPTIONS) {
    foreach ($pair in $Env:TRON2_OPTIONS -split ';') {
        if ($pair -match '^\s*([^=]+?)\s*=\s*(.*?)\s*$') {
            Set-Value $typeSection $Matches[1] $Matches[2]
        } elseif ($pair.Trim()) {
            Write-Log -Level Warning "Ignoring TRON2_OPTIONS entry '$pair' (expected Key=Value)"
        }
    }
}

$lines = foreach ($s in $ini.GetEnumerator()) {
    "[$($s.Key)]"
    foreach ($kv in $s.Value.GetEnumerator()) { "$($kv.Key) = $($kv.Value)" }
    ''
}

[System.IO.File]::WriteAllText($file, ($lines -join "`r`n"))
chown "$($Env:UID):$($Env:GID)" $file

Write-Log "Applied TRON2_* settings to ServerData/$name.txt ($typeSection)"
