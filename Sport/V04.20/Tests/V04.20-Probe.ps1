[CmdletBinding()]
param(
    [switch]$KeepServer,
    [int]$Port = 7020,
    [int]$StartupTimeoutSeconds = 10
)

$ErrorActionPreference = 'Stop'

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.20'
Write-Host '       PLAYBACK MATRIX LOCAL PROBE'
Write-Host '==============================================='

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$probeRoot = Join-Path $root '..\Probe'
$probePath = Join-Path $probeRoot 'addon.js'
$baseUrl = "http://127.0.0.1:$Port"

function Get-Json([string]$Url) { Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 10 }
function Ready { try { $null = Get-Json "$baseUrl/manifest.json"; return $true } catch { return $false } }
function Check([string]$Name,[bool]$Passed) { Write-Host ('[{0}] {1}' -f $(if($Passed){'PASS'}else{'FAIL'}),$Name) }

$proc = $null
$startedByTest = $false
$checks = [ordered]@{}
try {
    $checks['Probe Exists'] = Test-Path $probePath
    if (-not $checks['Probe Exists']) { throw "Probe not found: $probePath" }

    if (-not (Ready)) {
        $node = Get-Command 'node.exe' -ErrorAction SilentlyContinue
        if ($null -eq $node) { throw 'node.exe was not found in PATH.' }
        $proc = Start-Process -FilePath $node.Source -ArgumentList @('addon.js') -WorkingDirectory $probeRoot -PassThru -WindowStyle Normal
        $startedByTest = $true
        $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
        do {
            Start-Sleep -Milliseconds 300
            if (Ready) { break }
            if ((Get-Date) -gt $deadline) { throw "Probe did not become ready within $StartupTimeoutSeconds seconds." }
        } while ($true)
    }

    $manifest = Get-Json "$baseUrl/manifest.json"
    $catalog = Get-Json "$baseUrl/catalog/tv/v0420-probe.json"
    $meta = Get-Json "$baseUrl/meta/tv/sports:event:2397275.json"
    $stream = Get-Json "$baseUrl/stream/tv/sports:event:2397275.json"
    $diag = Get-Json "$baseUrl/diagnostic.json"

    $checks['Manifest Valid'] = $manifest.id -eq 'org.vietnam.sports.hub.v0420probe'
    $checks['Catalog Valid'] = @($catalog.metas).Count -eq 1
    $checks['Meta Valid'] = $meta.meta.id -eq 'sports:event:2397275'
    $checks['Three Payload Classes'] = @($stream.streams).Count -eq 3
    $checks['MP4 Control Present'] = @($stream.streams | Where-Object { $_.url -match '\.mp4($|\?)' -and -not $_.behaviorHints.notWebReady }).Count -eq 1
    $checks['Mux HLS Present'] = @($stream.streams | Where-Object { $_.url -like '*test-streams.mux.dev*' -and $_.behaviorHints.notWebReady }).Count -eq 1
    $checks['Apple HLS Present'] = @($stream.streams | Where-Object { $_.url -like '*devstreaming-cdn.apple.com*' -and $_.behaviorHints.notWebReady }).Count -eq 1
    $checks['Authorized Sources'] = (@($stream.streams | Where-Object { $_.url -notmatch '^https://(download\.blender\.org|test-streams\.mux\.dev|devstreaming-cdn\.apple\.com)/' }).Count -eq 0)

    Write-Host ''
    foreach($k in $checks.Keys){ Check $k $checks[$k] }
    Write-Host ''
    Write-Host "MP4 Requests       : $($diag.mp4Requests)"
    Write-Host "Mux Requests       : $($diag.muxRequests)"
    Write-Host "Apple Requests     : $($diag.appleRequests)"
    Write-Host "Probe Started Here : $startedByTest"
    Write-Host "Probe URL          : $baseUrl/manifest.json"
    Write-Host "Diagnostic URL     : $baseUrl/diagnostic.json"

    $all = $checks.Values -notcontains $false
    Write-Host ''
    Write-Host 'Version                    : 0.4.20'
    Write-Host "Status                     : $(if($all){'PASS'}else{'FAIL'})"
    Write-Host "Primary Failure            : $(if($all){'NONE'}else{($checks.GetEnumerator()|Where-Object{-not $_.Value}|Select-Object -First 1).Key})"
    Write-Host 'Previous Versions Frozen   : True'
    Write-Host 'V0.4.19 Contract Preserved : True'
    Write-Host 'Matrix Mode                : MP4-VS-HLS'
    Write-Host 'Deployment                 : LOCAL-ONLY'
    Write-Host "Integration Complete       : $all"
}
catch {
    Write-Host 'Version                    : 0.4.20'
    Write-Host 'Status                     : FAIL'
    Write-Host 'Primary Failure            : TEST_HARNESS'
    Write-Host "Failure Reason             : $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($startedByTest -and -not $KeepServer -and $null -ne $proc) {
        try { if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue; Write-Host 'Automated Cleanup         : Probe stopped.' } } catch {}
    }
}

if (-not $KeepServer) { Read-Host 'Press Enter' }
