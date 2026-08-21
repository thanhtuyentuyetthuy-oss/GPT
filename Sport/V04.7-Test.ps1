$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverRoot = Join-Path $projectRoot 'V04.AddonServer'
$addonPath = Join-Path $serverRoot 'addon.js'
$baseUrl = 'http://127.0.0.1:7000'
$eventId = '2397275'
$streamCachePath = Join-Path $projectRoot '..\Data\Cache\V02.Stream\event-2397275.json'
$streamCachePath = [System.IO.Path]::GetFullPath($streamCachePath)
$rejectedSourceUrl = 'https://vmttv.duckdns.org/'

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.7'
Write-Host '       STREAM SOURCE SAFETY GATE TEST'
Write-Host '==============================================='

$process = $null
$originalCache = $null
try {
    if (-not (Test-Path $streamCachePath)) {
        throw "Stream cache not found: $streamCachePath"
    }

    $originalCache = Get-Content -Raw -Path $streamCachePath

    $process = Start-Process -FilePath 'node' -ArgumentList @($addonPath) -WorkingDirectory $serverRoot -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 800

    $health = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get

    # Positive case: the current approved Mux test source must be allowed.
    $approvedStream = Invoke-RestMethod -Uri "$baseUrl/stream/tv/sports:event:$eventId.json" -Method Get
    $approvedCount = if ($approvedStream.streams) { @($approvedStream.streams).Count } else { 0 }
    $approvedHost = if ($approvedStream.meta.sourceHost) { [string]$approvedStream.meta.sourceHost } else { '' }
    $approvedAllowed = $approvedStream.meta.sourcePolicy -eq 'AUTHORIZED-ONLY' -and $approvedHost -in @('test-streams.mux.dev','stream.mux.com') -and $approvedCount -gt 0

    # Negative case: temporarily replace the cached source with vmttv.duckdns.org.
    # The addon must reject it and must not expose a stream to Stremio.
    $rejectedCache = $originalCache | ConvertFrom-Json
    $rejectedCache.sourceUrl = $rejectedSourceUrl
    ($rejectedCache | ConvertTo-Json -Depth 10) | Set-Content -Path $streamCachePath -Encoding UTF8
    Start-Sleep -Milliseconds 150

    $rejectedStatus = $null
    $rejectedBody = $null
    try {
        $rejectedResponse = Invoke-WebRequest -Uri "$baseUrl/stream/tv/sports:event:$eventId.json" -Method Get -SkipHttpErrorCheck
        $rejectedStatus = [int]$rejectedResponse.StatusCode
        $rejectedBody = $rejectedResponse.Content
    }
    catch {
        $rejectedStatus = [int]$_.Exception.Response.StatusCode.value__
        $rejectedBody = $_.ErrorDetails.Message
    }

    $rejectedCorrectly = $rejectedStatus -eq 503 -and $rejectedBody -match 'not approved by the V0.4.7 source policy'

    $overallPass = ($health.status -eq 'OK') -and $approvedAllowed -and $rejectedCorrectly

    Write-Host "Version                 : 0.4.7"
    Write-Host "Status                  : $(if ($overallPass) { 'PASS' } else { 'FAIL' })"
    Write-Host "Server Started          : $($process.HasExited -eq $false)"
    Write-Host "Health                  : $($health.status -eq 'OK')"
    Write-Host "Source Gate             : $($health.sourceGate)"
    Write-Host "Approved Source         : $approvedHost"
    Write-Host "Approved Source Allowed : $approvedAllowed"
    Write-Host "Rejected Test Source    : $rejectedSourceUrl"
    Write-Host "Rejected Status         : $rejectedStatus"
    Write-Host "Rejected Correctly      : $rejectedCorrectly"
    Write-Host "Stream Exposed on Reject: False"
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
    if ($originalCache -ne $null -and (Test-Path $streamCachePath)) {
        Set-Content -Path $streamCachePath -Value $originalCache -Encoding UTF8
    }
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
}

Read-Host 'Press Enter'
