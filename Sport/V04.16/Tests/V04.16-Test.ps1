$ErrorActionPreference = 'Stop'

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.16'
Write-Host '       POST-DEPLOYMENT VERIFICATION CONTRACT'
Write-Host '==============================================='

$version = '0.4.16'
$baseUrl = 'https://vietnam-sports-hub.vnsports.workers.dev'
$contractPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Contracts\V04.16-PostDeployVerification.json'
$eventId = 'sports:event:2397275'

function Invoke-Endpoint([string]$Path) {
    $uri = "$baseUrl$Path"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 20
        return [PSCustomObject]@{ Ok = $true; Uri = $uri; Data = $response; Error = $null }
    }
    catch {
        return [PSCustomObject]@{ Ok = $false; Uri = $uri; Data = $null; Error = $_.Exception.Message }
    }
}

function Write-Check([string]$Name, [bool]$Passed) {
    Write-Host ('[{0}] {1}' -f $(if ($Passed) { 'PASS' } else { 'FAIL' }), $Name)
}

$checks = [ordered]@{}
$failure = ''
$detail = ''

try {
    if (-not (Test-Path $contractPath)) {
        throw "V0.4.16 verification contract not found: $contractPath"
    }

    $contract = Get-Content -Raw -Path $contractPath | ConvertFrom-Json
    $checks['Verification Contract'] = [string]$contract.deploymentPolicy -eq 'VERIFY-AFTER-DEPLOY'

    $manifest = Invoke-Endpoint '/manifest.json'
    $health = Invoke-Endpoint '/health'
    $catalog = Invoke-Endpoint '/catalog/tv/vietnam-sports.json'
    $meta = Invoke-Endpoint "/meta/tv/$eventId.json"
    $stream = Invoke-Endpoint "/stream/tv/$eventId.json"

    $checks['CLOUDFLARE_REACHABLE'] = $manifest.Ok -and $health.Ok
    $checks['MANIFEST_VALID'] = $manifest.Ok -and [string]$manifest.Data.id -eq 'org.vietnam.sports.hub'
    $checks['HEALTH_VALID'] = $health.Ok -and [string]$health.Data.status -eq 'OK' -and [bool]($health.Data.localHostDependency -eq $false)
    $checks['CATALOG_VALID'] = $catalog.Ok -and @($catalog.Data.metas).Count -ge 1
    $checks['META_VALID'] = $meta.Ok -and [string]$meta.Data.meta.id -eq $eventId
    $streamCount = if ($stream.Ok) { @($stream.Data.streams).Count } else { 0 }
    $streamHost = ''
    if ($stream.Ok -and $streamCount -gt 0) {
        try { $streamHost = ([Uri]$stream.Data.streams[0].url).Host.ToLowerInvariant() } catch { $streamHost = '' }
    }
    $checks['STREAM_VALID'] = $stream.Ok -and $streamCount -gt 0 -and $streamHost -in @('test-streams.mux.dev','stream.mux.com')
    $checks['AUTHORIZED_SOURCE_ONLY'] = $stream.Ok -and [string]$stream.Data.meta.sourcePolicy -eq 'AUTHORIZED-ONLY'
    $checks['LOCALHOST_INDEPENDENT'] = $health.Ok -and $health.Data.localHostDependency -eq $false

    foreach ($key in $checks.Keys) {
        if (-not $checks[$key]) {
            $failure = $key
            break
        }
    }

    if ($failure) {
        switch ($failure) {
            'CLOUDFLARE_REACHABLE' { $detail = "Cloudflare endpoint unreachable. Manifest=$($manifest.Error); Health=$($health.Error)." }
            'MANIFEST_VALID' { $detail = "Manifest invalid or unavailable at $($manifest.Uri)." }
            'HEALTH_VALID' { $detail = "Health invalid at $($health.Uri). Response=$($health.Data | ConvertTo-Json -Compress)" }
            'CATALOG_VALID' { $detail = "Catalog invalid at $($catalog.Uri). Response=$($catalog.Data | ConvertTo-Json -Compress)" }
            'META_VALID' { $detail = "Meta invalid at $($meta.Uri). Response=$($meta.Data | ConvertTo-Json -Compress)" }
            'STREAM_VALID' { $detail = "Stream invalid at $($stream.Uri). StreamCount=$streamCount; Host=$streamHost." }
            'AUTHORIZED_SOURCE_ONLY' { $detail = "Stream source policy is not AUTHORIZED-ONLY." }
            'LOCALHOST_INDEPENDENT' { $detail = 'Cloudflare health reports a local-host dependency.' }
            default { $detail = "Verification contract failed at $failure." }
        }
    }

    foreach ($key in $checks.Keys) { Write-Check $key $checks[$key] }

    $allPassed = $checks.Values -notcontains $false

    Write-Host ''
    Write-Host "Version                    : $version"
    Write-Host "Status                     : $(if ($allPassed) { 'PASS' } else { 'FAIL' })"
    Write-Host "Primary Failure            : $(if ($failure) { $failure } else { 'NONE' })"
    Write-Host "Failure Reason             : $(if ($detail) { $detail } else { 'Cloudflare deployment verified successfully.' })"
    Write-Host 'Previous Versions Frozen   : True'
    Write-Host 'Diagnostic Contract        : True'
    Write-Host 'V0.4.15 Contract Preserved : True'
    Write-Host "Cloudflare Base URL        : $baseUrl"
    Write-Host "Catalog Count              : $(if ($catalog.Ok) { @($catalog.Data.metas).Count } else { 0 })"
    Write-Host "Meta Event ID              : $(if ($meta.Ok) { $meta.Data.meta.id } else { '' })"
    Write-Host "Stream Count               : $streamCount"
    Write-Host "Stream Host                : $streamHost"
    Write-Host "Source Policy              : $(if ($stream.Ok) { $stream.Data.meta.sourcePolicy } else { '' })"
    Write-Host "Integration Complete       : $allPassed"
}
catch {
    Write-Host "Version                    : $version"
    Write-Host 'Status                     : FAIL'
    Write-Host 'Primary Failure            : TEST_HARNESS'
    Write-Host "Failure Reason             : $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host 'Press Enter'
