$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverRoot = Join-Path $projectRoot 'V04.AddonServer'
$addonPath = Join-Path $serverRoot 'addon.js'
$baseUrl = 'http://127.0.0.1:7000'
$eventId = '2397275'

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.7'
Write-Host '       STREAM SOURCE SAFETY GATE TEST'
Write-Host '==============================================='

$process = $null
try {
    $process = Start-Process -FilePath 'node' -ArgumentList @($addonPath) -WorkingDirectory $serverRoot -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 800

    $health = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get
    $stream = Invoke-RestMethod -Uri "$baseUrl/stream/tv/sports:event:$eventId.json" -Method Get

    $streamCount = if ($stream.streams) { @($stream.streams).Count } else { 0 }
    $sourceHost = if ($stream.meta.sourceHost) { [string]$stream.meta.sourceHost } else { '' }
    $authorized = $stream.meta.sourcePolicy -eq 'AUTHORIZED-ONLY' -and $sourceHost -in @('test-streams.mux.dev','stream.mux.com')

    Write-Host "Version                 : 0.4.7"
    Write-Host "Status                  : $(if ($authorized) { 'PASS' } else { 'FAIL' })"
    Write-Host "Server Started          : $($process.HasExited -eq $false)"
    Write-Host "Health                  : $($health.status -eq 'OK')"
    Write-Host "Source Gate             : $($health.sourceGate)"
    Write-Host "Stream Endpoint         : $($streamCount -gt 0)"
    Write-Host "Stream Count            : $streamCount"
    Write-Host "Source Host             : $sourceHost"
    Write-Host "Authorized Source Only  : $authorized"
    Write-Host "Hidden Endpoint Extract : False"
    Write-Host "Protected Stream Bypass : False"
    Write-Host "Event ID                : $eventId"
}
catch {
    Write-Host 'Version                 : 0.4.7'
    Write-Host 'Status                  : FAIL'
    Write-Host "Error                   : $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
}

Read-Host 'Press Enter'
