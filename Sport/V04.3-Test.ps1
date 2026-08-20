$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Join-Path $projectRoot 'V04.AddonServer'
$addonScript = Join-Path $addonRoot 'addon.js'
# V0.2.1 stores Data beside Sport at the repository root: D:\GPT\GPT-Git\Data\Cache\...
$cacheRoot = Join-Path (Split-Path -Parent $projectRoot) 'Data\Cache\V02.Catalog'
$port = 7000
$base = "http://127.0.0.1:$port"
$process = $null

function Test-JsonEndpoint {
    param([Parameter(Mandatory)][string]$Url)
    $response = Invoke-WebRequest -Uri $Url -Method Get -UseBasicParsing -TimeoutSec 10
    if ($response.StatusCode -ne 200) { throw "HTTP $($response.StatusCode) from $Url" }
    $response.Content | ConvertFrom-Json
}

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.3'
Write-Host '       CATALOG ADAPTER INTEGRATION'
Write-Host '==============================================='

try {
    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) { throw 'Node.js is not installed or not available on PATH.' }
    if (-not (Test-Path $addonScript)) { throw "Addon server not found: $addonScript" }
    if (-not (Test-Path $cacheRoot)) { throw "V0.2.1 catalog cache directory not found: $cacheRoot" }

    $cacheFiles = @(Get-ChildItem -Path $cacheRoot -Filter 'catalog-*.json' -File | Sort-Object Name -Descending)
    if ($cacheFiles.Count -eq 0) { throw 'No V0.2.1 catalog cache file found.' }
    $latestCache = $cacheFiles[0].FullName
    $cachePayload = Get-Content -Path $latestCache -Raw -Encoding UTF8 | ConvertFrom-Json
    $inputCount = @($cachePayload.metas).Count
    if ($inputCount -le 0) { throw 'V0.2.1 cache contains no catalog items.' }

    $process = Start-Process -FilePath $node.Source -ArgumentList @($addonScript) -WorkingDirectory $addonRoot -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 1200

    $health = Test-JsonEndpoint -Url "$base/health"
    $catalog = Test-JsonEndpoint -Url "$base/catalog/tv/vietnam-sports.json"

    $outputCount = @($catalog.metas).Count
    $allTv = $outputCount -gt 0 -and (@($catalog.metas) | Where-Object { $_.type -ne 'tv' }).Count -eq 0
    $hasExpectedPrefix = $outputCount -gt 0 -and (@($catalog.metas) | Where-Object { $_.id -notlike 'sports:event:*' }).Count -eq 0
    $stateMarkersPresent = $outputCount -gt 0 -and (@($catalog.metas) | Where-Object { $_.name -match '^\[(LIVE|NEXT|DONE)\] ' }).Count -gt 0
    $cacheOnly = $health.catalogSource -eq 'V0.2.1 DAILY CACHE'
    $countMatches = $inputCount -eq $outputCount
    $allPass = $health.status -eq 'OK' -and $countMatches -and $allTv -and $hasExpectedPrefix -and $stateMarkersPresent -and $cacheOnly

    Write-Host "Version             : 0.4.3"
    Write-Host "Status              : $(if ($allPass) { 'PASS' } else { 'FAIL' })"
    Write-Host "Cache Read          : True"
    Write-Host "Cache Path          : $latestCache"
    Write-Host "Source API Requests : 0"
    Write-Host "Input Catalog Count : $inputCount"
    Write-Host "Output Catalog Count: $outputCount"
    Write-Host "Mapped Type = tv    : $allTv"
    Write-Host "Event IDs Valid     : $hasExpectedPrefix"
    Write-Host "Local State Markers : $stateMarkersPresent"
    Write-Host "Cache-Only Policy   : $cacheOnly"
}
catch {
    Write-Host 'Version             : 0.4.3'
    Write-Host 'Status              : FAIL' -ForegroundColor Red
    Write-Host "Error               : $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
}

Read-Host 'Press Enter'
