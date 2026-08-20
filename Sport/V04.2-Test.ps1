$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Join-Path $projectRoot 'V04.AddonServer'
$addonScript = Join-Path $addonRoot 'addon.js'
$port = 7000
$base = "http://127.0.0.1:$port"
$process = $null

function Test-Endpoint {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Url
    )

    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -ne 200) {
            throw "$Name returned HTTP $($response.StatusCode)."
        }
        $json = $response.Content | ConvertFrom-Json
        [PSCustomObject]@{ Name = $Name; Pass = $true; StatusCode = $response.StatusCode; Json = $json }
    }
    catch {
        [PSCustomObject]@{ Name = $Name; Pass = $false; StatusCode = $null; Json = $null; Error = $_.Exception.Message }
    }
}

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.2'
Write-Host '       HTTP ADDON SERVER CONTRACT'
Write-Host '==============================================='

try {
    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) { throw 'Node.js is not installed or not available on PATH.' }
    if (-not (Test-Path $addonScript)) { throw "Addon server not found: $addonScript" }

    $process = Start-Process -FilePath $node.Source -ArgumentList @($addonScript) -WorkingDirectory $addonRoot -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 1200

    $health = Test-Endpoint -Name 'Health' -Url "$base/health"
    $manifest = Test-Endpoint -Name 'Manifest' -Url "$base/manifest.json"
    $catalog = Test-Endpoint -Name 'Catalog' -Url "$base/catalog/tv/vietnam-sports.json"
    $meta = Test-Endpoint -Name 'Meta' -Url "$base/meta/tv/sports%3Aevent%3A2397275.json"
    $stream = Test-Endpoint -Name 'Stream' -Url "$base/stream/tv/sports%3Aevent%3A2397275.json"

    $manifestValid = $manifest.Pass -and
        $manifest.Json.id -eq 'org.vietnam.sports.hub' -and
        $manifest.Json.version -eq '0.4.1' -and
        @($manifest.Json.resources).Count -eq 3 -and
        @($manifest.Json.types) -contains 'tv'

    $catalogValid = $catalog.Pass -and @($catalog.Json.metas).Count -gt 0
    $metaValid = $meta.Pass -and $meta.Json.meta.id -eq 'sports:event:2397275'
    $streamValid = $stream.Pass -and @($stream.Json.streams).Count -gt 0

    $allPass = $health.Pass -and $manifestValid -and $catalogValid -and $metaValid -and $streamValid

    Write-Host "Version            : 0.4.2"
    Write-Host "Status             : $(if ($allPass) { 'PASS' } else { 'FAIL' })"
    Write-Host "Node Available     : $($true)"
    Write-Host "Server Started     : $(-not $process.HasExited)"
    Write-Host "Health             : $($health.Pass)"
    Write-Host "Manifest Endpoint  : $manifestValid"
    Write-Host "Catalog Endpoint   : $catalogValid"
    Write-Host "Meta Endpoint      : $metaValid"
    Write-Host "Stream Endpoint    : $streamValid"
    Write-Host "Base URL           : $base"
    Write-Host "Manifest URL       : $base/manifest.json"

    if (-not $allPass) {
        foreach ($r in @($health, $manifest, $catalog, $meta, $stream)) {
            if (-not $r.Pass) { Write-Host "Error $($r.Name): $($r.Error)" -ForegroundColor Red }
        }
    }
}
catch {
    Write-Host 'Version            : 0.4.2'
    Write-Host 'Status             : FAIL' -ForegroundColor Red
    Write-Host "Error              : $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
}

Read-Host 'Press Enter'
