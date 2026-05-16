param(
    [switch]$Force  # repackage even if commit hasn't changed
)

$ErrorActionPreference = "Stop"

$root         = $PSScriptRoot
$workspaceRoot = Split-Path $root -Parent
$projectName  = Split-Path $root -Leaf
$buildDir     = Join-Path $root "cmake-build-release"
$distRoot     = Join-Path $workspaceRoot "dist_qt"
$distDir      = Join-Path $distRoot $projectName
$releasesFile = Join-Path $root "releases.json"
$staging      = Join-Path $root "_staging"
$appName      = "under_attack_public_wifi"

function Invoke-Git {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )
    & git "-c" "safe.directory=*" -C $root @Args
}

function Initialize-MsvcEnvironment {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { return }
    $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vsPath) { return }
    $vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
    if (-not (Test-Path $vcvars)) { return }
    Write-Host ">> Initializing MSVC environment..."
    $envLines = cmd /c "`"$vcvars`" > nul 2>&1 && set"
    foreach ($line in $envLines) {
        if ($line -match "^([^=]+)=(.*)$") {
            [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
        }
    }
}

function Ensure-ReleaseBuildDir {
    $cache = Join-Path $buildDir "CMakeCache.txt"
    if (-not (Test-Path $cache)) { return }
    $expected = [IO.Path]::GetFullPath($root).Replace('\','/')
    $homeLine = Select-String -Path $cache -Pattern '^CMAKE_HOME_DIRECTORY:INTERNAL=' | Select-Object -First 1
    if (-not $homeLine) { return }
    $actual = ($homeLine.Line -replace '^CMAKE_HOME_DIRECTORY:INTERNAL=', '').Replace('\','/')
    if ($actual -ieq $expected) { return }
    Write-Host ">> Rebuilding cmake-build-release because cache points to old source dir:"
    Write-Host "   $actual"
    Remove-Item -LiteralPath $buildDir -Recurse -Force
    New-Item -ItemType Directory -Path $buildDir | Out-Null
}

function Test-GitRepo {
    Invoke-Git "rev-parse" "--is-inside-work-tree" 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

# --- Git info ---
$hasGit = Test-GitRepo
if ($hasGit) {
    $commitShort = Invoke-Git "rev-parse" "--short" "HEAD"
    $commitMsg   = Invoke-Git "log" "-1" "--pretty=%s"
} else {
    $commitShort = "nogit"
    $commitMsg   = "Unversioned public wifi package"
}

# --- Load releases.json ---
$data     = Get-Content $releasesFile | ConvertFrom-Json
$releases = @($data.releases)
$last     = if ($releases.Count -gt 0) { $releases[-1] } else { $null }
$alreadyPackaged = $last -and $last.commit -eq $commitShort
$versionNum = if ($alreadyPackaged) { [int]$last.version } elseif ($releases.Count -eq 0) { 0 } else { [int]$last.version + 1 }
$versionTag = "v{0:D2}" -f $versionNum
$zipName    = "bajo-ataque-under_attack_public_wifi-$versionTag.zip"
$zipPath    = Join-Path $distDir $zipName
$shouldPublishRelease = $Force -or (-not $alreadyPackaged) -or (-not (Test-Path $distDir))

# --- Already packaged? ---
if (-not $shouldPublishRelease) {
    Write-Host "Already packaged as $($last.zip) and published to $distDir. Nothing to do."
    Write-Host "Use -Force to republish the same commit."
    exit 0
}

Write-Host ""
Write-Host "=== Packaging $versionTag ==="
Write-Host "  Commit : $commitShort - $commitMsg"
Write-Host "  Output : $zipName"
Write-Host ""

Initialize-MsvcEnvironment
Ensure-ReleaseBuildDir

# --- Build ---
if (-not (Test-Path "$buildDir\CMakeCache.txt")) {
    Write-Host ">> Configuring (no existing build found)..."
    cmake -S $root -B $buildDir -DCMAKE_BUILD_TYPE=Release 2>&1 | Out-Null
} else {
    Write-Host ">> Reusing existing cmake configuration in cmake-build-release..."
}

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
if (-not (Test-Path (Join-Path $out "under_attack_public_wifi.exe"))) {
    $out = $buildDir
}
Copy-Item "$out\under_attack_public_wifi.exe"                       $staging
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
Copy-Item "$root\scripts\*.awk"                                     "$staging\scripts\"
Copy-Item "$root\scripts\oui.txt"                                   "$staging\scripts\"
Copy-Item "$root\RUNBOOK.md"                                        $staging

$entryDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
$metadata = [PSCustomObject]@{
    app     = $appName
    version = $versionNum
    commit  = $commitShort
    date    = $entryDate
    message = $commitMsg
    zip     = $zipName
}
$metadata | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $staging "version.json") -Encoding UTF8
@(
    "app=$($metadata.app)"
    "version=$($metadata.version)"
    "commit=$($metadata.commit)"
    "date=$($metadata.date)"
    "message=$($metadata.message)"
    "zip=$($metadata.zip)"
) | Set-Content (Join-Path $staging "BUILD_INFO.txt") -Encoding UTF8

# --- Zip ---
Write-Host ">> Creating zip..."
if (-not (Test-Path $distRoot)) { New-Item -ItemType Directory -Path $distRoot | Out-Null }
if (Test-Path $distDir) { Remove-Item -LiteralPath $distDir -Recurse -Force }
New-Item -ItemType Directory -Path $distDir | Out-Null
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$staging\*" -DestinationPath $zipPath
Expand-Archive -LiteralPath $zipPath -DestinationPath $distDir -Force
Remove-Item $staging -Recurse -Force

# --- Update releases.json ---
if (-not $alreadyPackaged) {
    $entry = [PSCustomObject]@{
        version = $versionNum
        commit  = $commitShort
        date    = $entryDate
        message = $commitMsg
        zip     = $zipName
    }
    $releases += $entry
    $data.releases = $releases
    $data | ConvertTo-Json -Depth 5 | Set-Content $releasesFile -Encoding UTF8
}

# --- Git tag ---
if ($hasGit) {
    Write-Host ">> Tagging commit as $versionTag..."
    Invoke-Git "tag" $versionTag 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   Note: tag $versionTag already exists, skipped."
    }
} else {
    Write-Host ">> Not in a git repository; tag creation skipped."
}

# --- Summary ---
$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
Write-Host ""
Write-Host "=== Done ==="
Write-Host "  Version : $versionTag"
Write-Host "  Commit  : $commitShort - $commitMsg"
Write-Host "  Zip     : $zipName ($sizeMB MB)"
Write-Host "  Path    : $distDir"
Write-Host ""
