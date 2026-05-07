param(
    [switch]$Force  # repackage even if commit hasn't changed
)

$ErrorActionPreference = "Stop"

$root         = $PSScriptRoot
$buildDir     = Join-Path $root "build\msvc2022"
$distDir      = Join-Path $root "dist"
$releasesFile = Join-Path $root "releases.json"
$staging      = Join-Path $root "_staging"

# --- Git info ---
$commitShort = git -C $root rev-parse --short HEAD
$commitMsg   = git -C $root log -1 --pretty=%s

# --- Load releases.json ---
$data     = Get-Content $releasesFile | ConvertFrom-Json
$releases = @($data.releases)
$last     = if ($releases.Count -gt 0) { $releases[-1] } else { $null }

# --- Already packaged? ---
if (-not $Force -and $last -and $last.commit -eq $commitShort) {
    Write-Host "Already packaged as $($last.zip). Nothing to do."
    Write-Host "Use -Force to repackage the same commit."
    exit 0
}

# --- Next version ---
$versionNum = if ($releases.Count -eq 0) { 0 } else { [int]$last.version + 1 }
$versionTag = "v{0:D2}" -f $versionNum
$zipName    = "cybershow-wifi-$versionTag.zip"
$zipPath    = Join-Path $distDir $zipName

Write-Host ""
Write-Host "=== Packaging $versionTag ==="
Write-Host "  Commit : $commitShort — $commitMsg"
Write-Host "  Output : $zipName"
Write-Host ""

# --- Build ---
Write-Host ">> Configuring..."
cmake -S $root -B $buildDir -DCMAKE_BUILD_TYPE=Release 2>&1 | Out-Null

Write-Host ">> Building Release..."
cmake --build $buildDir --config Release
if ($LASTEXITCODE -ne 0) { Write-Error "Build failed."; exit 1 }

# --- Stage files ---
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory "$staging\plugins\platforms"   | Out-Null
New-Item -ItemType Directory "$staging\plugins\multimedia"  | Out-Null
New-Item -ItemType Directory "$staging\resources"           | Out-Null
New-Item -ItemType Directory "$staging\scripts"             | Out-Null

$out = Join-Path $buildDir "Release"
Copy-Item "$out\public_wifi.exe"                                    $staging
Copy-Item "$out\Qt6Core.dll"                                        $staging
Copy-Item "$out\Qt6Gui.dll"                                         $staging
Copy-Item "$out\Qt6Multimedia.dll"                                  $staging
Copy-Item "$out\Qt6Network.dll"                                     $staging
Copy-Item "$out\Qt6Widgets.dll"                                     $staging
Copy-Item "$out\Qt6Svg.dll"                                         $staging
Copy-Item "$out\plugins\platforms\qwindows.dll"                     "$staging\plugins\platforms\"
Copy-Item "$out\plugins\multimedia\windowsmediaplugin.dll"          "$staging\plugins\multimedia\"
Copy-Item "$root\resources\regions.json"                            "$staging\resources\"
Copy-Item "$root\resources\services.json"                           "$staging\resources\"
Copy-Item "$root\scripts\*.sh"                                      "$staging\scripts\"
Copy-Item "$root\RUNBOOK.md"                                        $staging

# --- Zip ---
Write-Host ">> Creating zip..."
if (-not (Test-Path $distDir)) { New-Item -ItemType Directory $distDir | Out-Null }
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$staging\*" -DestinationPath $zipPath
Remove-Item $staging -Recurse -Force

# --- Update releases.json ---
$entry = [PSCustomObject]@{
    version = $versionNum
    commit  = $commitShort
    date    = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
    message = $commitMsg
    zip     = $zipName
}
$releases += $entry
$data.releases = $releases
$data | ConvertTo-Json -Depth 5 | Set-Content $releasesFile -Encoding UTF8

# --- Git tag ---
Write-Host ">> Tagging commit as $versionTag..."
git -C $root tag $versionTag 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "   Note: tag $versionTag already exists, skipped."
}

# --- Summary ---
$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
Write-Host ""
Write-Host "=== Done ==="
Write-Host "  Version : $versionTag"
Write-Host "  Commit  : $commitShort — $commitMsg"
Write-Host "  Zip     : $zipName ($sizeMB MB)"
Write-Host "  Path    : $zipPath"
Write-Host ""
