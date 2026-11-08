#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Tron 2.0 is retail software with no public download. Use an existing v1.042 install in
# /config/Server, or set TRON2_ARCHIVE_URL to a zip of the game folder (at the zip root or in a
# single top-level folder), e.g. a LANCommander archive.

Invoke-Hook "PreInstallTron2"

$exe = Join-Path $Env:SERVER_DIR 'TRONSrv.exe'

if (Test-Path -Path $exe) {
    Write-Log "Tron 2.0 found in $Env:SERVER_DIR"
} elseif ($Env:TRON2_ARCHIVE_URL) {
    Write-Log "Downloading Tron 2.0 from $Env:TRON2_ARCHIVE_URL"

    $zip     = '/tmp/tron2.zip'
    $extract = '/tmp/tron2'

    curl -fL --retry 3 --output $zip "$Env:TRON2_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:TRON2_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue

    # The Killer App Mod installer and its backups of the files it replaced aren't needed to host
    unzip -q -o $zip -d $extract -x '*ka_mod_v1x1a_setup.exe' '*KAModBackups/*'
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $zip" }

    # Accept the game at the zip root or inside one top-level folder
    $root = Get-ChildItem -Path $extract -Filter 'TRONSrv.exe' -Recurse -File -Depth 1 |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $root) { throw "TRONSrv.exe not found in $Env:TRON2_ARCHIVE_URL" }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    Move-Item -Force -Path (Join-Path $root.FullName '*') -Destination $Env:SERVER_DIR
    chown -R "$($Env:UID):$($Env:GID)" $Env:SERVER_DIR

    Remove-Item -Recurse -Force -Path $zip, $extract

    # The overlay was mounted before Server/ was populated, and overlayfs doesn't reliably show
    # lower-dir changes made while mounted.
    mountpoint -q $Env:SERVER_ROOT
    if ($LASTEXITCODE -eq 0) {
        umount $Env:SERVER_ROOT
        Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue
        Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
        Write-Log "OverlayFS remounted"
    }

    Write-Log "Tron 2.0 installed"
} else {
    Write-Log -Level Error "TRONSrv.exe not found in $Env:SERVER_DIR. Copy a Tron 2.0 v1.042 install there or set TRON2_ARCHIVE_URL."
}

Invoke-Hook "PostInstallTron2"

Set-Location $Env:SERVER_ROOT
