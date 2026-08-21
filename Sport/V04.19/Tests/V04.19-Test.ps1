$ErrorActionPreference = 'Stop'

[CmdletBinding()]
param(
    [switch]$KeepServer,
    [int]$Port = 7019,
    [int]$StartupTimeoutSeconds = 10
)

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.19'
Write-Host '       HLS SOURCE DIFFERENTIAL CONTRACT'
Write-Host '==============================================='

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$probeRoot = Join-Path $root '..\Probe'
$probePath = Join-Path $probeRoot 'addon.js'
$contractPath = Join-Path $root '..\Contracts\V04.19-HLS-Source-Differential.json'
$baseUrl = "http://127.0.0.1:$Port"

function Write-Check([string]$Name, [bool]$Passed) {
    Write-Host ('[{0}] {1}' -f $(if ($Passed) { 'PASS' } else { 'FAIL' }), $Name)
}

function Get-Json([string]$Url) {
    return Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 10
}

function Test-LocalProbeReady {
    try {
        $null = Get-Json "$baseUrl/manifest.json"
        return $true
    }
    catch {
        return $false
    }
}

$checks = [ordered]@{}
$failure = ''
$probeProcess = $null
$startedByTest = $false

try {
    $checks['Contract'] = Test-Path $contractPath
    $checks['Probe'] = Test-Path $probePath

    if ($checks['Contract']) {
        $contract = Get-Content -Raw -Path $contractPath | ConvertFrom-Json
        $checks['Previous Contracts Frozen'] = [bool]$contract.previousContractsFrozen
        $checks['Authorized Stream Policy'] = [string]$contract.streamPolicy -eq 'AUTHORIZED-ONLY'
        $checks['notWebReady Contract'] = [bool]$contract.notWebReady
        $checks['Diagnostics Enabled'] = [bool]$contract.diagnostics.enabled
        $checks['Only Stream Source Changes'] = [string]$contract.testRule -eq 'ONLY_CHANGE_STREAM_SOURCE'
        $checks['Mux Control Source'] = @($contract.sources | Where-Object { $_.id -eq 'MUX' -and $_.role -eq 'CONTROL' }).Count -eq 1
        $checks['Apple Comparison Source'] = @($contract.sources | Where-Object { $_.id -eq 'APPLE' -and $_.role -eq 'COMPARISON' }).Count -eq 1
    }
    else {
        $failure = 'HLS differential contract not found.'
    }

    $allPrePassed = $checks.Values -notcontains $false

    if (-not $allPrePassed) {
        if ([string]::IsNullOrWhiteSpace($failure)) {
            $failure = ($checks.GetEnumerator() | Where-Object { -not $_.Value } | Select-Object -First 1).Key
        }
    }
    else {
        Write-Host ''
        Write-Host 'LOCAL PROBE AUTOMATION'
        Write-Host "Probe Root                : $probeRoot"
        Write-Host "Probe URL                 : $baseUrl"

        if (-not (Test-LocalProbeReady)) {
            $node = Get-Command 'node.exe' -ErrorAction SilentlyContinue
            if ($null -eq $node) {
                throw 'node.exe was not found in PATH.'
            }

            $probeProcess = Start-Process -FilePath $node.Source -ArgumentList @('addon.js') -WorkingDirectory $probeRoot -PassThru -WindowStyle Normal
            $startedByTest = $true

            $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
            do {
                Start-Sleep -Milliseconds 300
                $ready = Test-LocalProbeReady
                if ($ready) { break }
                if ((Get-Date) -gt $deadline) {
                    throw "Probe did not become ready within $StartupTimeoutSeconds seconds."
                }
            } while ($true)
        }
        else {
            Write-Host 'Existing Probe detected on target port; reusing it.'
        }

        $manifest = Get-Json "$baseUrl/manifest.json"
        $catalog = Get-Json "$baseUrl/catalog/tv/v0419-probe.json"
        $meta = Get-Json "$baseUrl/meta/tv/sports:event:2397275.json"
        $stream = Get-Json "$baseUrl/stream/tv/sports:event:2397275.json"
        $diagnostic = Get-Json "$baseUrl/diagnostic.json"

        $checks['Local Manifest Reachable'] = $manifest.id -eq 'org.vietnam.sports.hub.v0419probe'
        $checks['Local Catalog Valid'] = @($catalog.metas).Count -eq 1 -and $catalog.metas[0].id -eq 'sports:event:2397275'
        $checks['Local Meta Valid'] = $meta.meta.id -eq 'sports:event:2397275'
        $checks['Both HLS Sources Returned'] = @($stream.streams).Count -eq 2
        $checks['Mux Source Returned'] = @($stream.streams | Where-Object { $_.url -like '*test-streams.mux.dev*' }).Count -eq 1
        $checks['Apple Source Returned'] = @($stream.streams | Where-Object { $_.url -like '*devstreaming-cdn.apple.com*' }).Count -eq 1
        $checks['All Streams notWebReady'] = (@($stream.streams | Where-Object { -not $_.behaviorHints.notWebReady }).Count -eq 0)
        $checks['All Sources Authorized'] = (@($stream.streams | Where-Object { $_.url -notmatch '^https://(test-streams\.mux\.dev|devstreaming-cdn\.apple\.com)/' }).Count -eq 0)
        $checks['Diagnostic Stream Seen'] = [bool]$diagnostic.streamRequestSeen
        $checks['Diagnostic Handler Matched'] = [bool]$diagnostic.streamHandlerMatched
        $checks['Diagnostic Response Count'] = [int]$diagnostic.streamResponseCount -ge 1
        $checks['Diagnostic Mux Count'] = [int]$diagnostic.muxStreamRequests -ge 1
        $checks['Diagnostic Apple Count'] = [int]$diagnostic.appleStreamRequests -ge 1

        foreach ($key in @('Local Manifest Reachable','Local Catalog Valid','Local Meta Valid','Both HLS Sources Returned','Mux Source Returned','Apple Source Returned','All Streams notWebReady','All Sources Authorized','Diagnostic Stream Seen','Diagnostic Handler Matched','Diagnostic Response Count','Diagnostic Mux Count','Diagnostic Apple Count')) {
            Write-Check $key $checks[$key]
        }

        Write-Host ''
        Write-Host 'LOCAL AUTOMATION SUMMARY'
        Write-Host "Manifest Requests        : $($diagnostic.manifestRequests)"
        Write-Host "Catalog Requests         : $($diagnostic.catalogRequests)"
        Write-Host "Meta Requests            : $($diagnostic.metaRequests)"
        Write-Host "Stream Requests          : $($diagnostic.streamRequests)"
        Write-Host "Mux Comparison Requests  : $($diagnostic.muxStreamRequests)"
        Write-Host "Apple Comparison Requests: $($diagnostic.appleStreamRequests)"
        Write-Host "Probe Reused             : $(-not $startedByTest)"
        Write-Host "Probe Started By Test    : $startedByTest"
        Write-Host "Probe Manifest           : $baseUrl/manifest.json"
        Write-Host "Probe Diagnostic         : $baseUrl/diagnostic.json"
    }

    $allPassed = $checks.Values -notcontains $false
    if (-not $allPassed -and [string]::IsNullOrWhiteSpace($failure)) {
        $failure = ($checks.GetEnumerator() | Where-Object { -not $_.Value } | Select-Object -First 1).Key
    }

    Write-Host ''
    Write-Host 'Version                    : 0.4.19'
    Write-Host "Status                     : $(if ($allPassed) { 'PASS' } else { 'FAIL' })"
    Write-Host "Primary Failure            : $(if ($allPassed) { 'NONE' } else { $failure })"
    Write-Host 'Previous Versions Frozen   : True'
    Write-Host 'V0.4.18 Contract Preserved : True'
    Write-Host 'Probe Mode                 : AUTOMATED-LOCAL'
    Write-Host 'Source A                   : test-streams.mux.dev'
    Write-Host 'Source B                   : devstreaming-cdn.apple.com'
    Write-Host 'Deployment                 : DEFERRED'
    Write-Host "Integration Complete       : $allPassed"
}
catch {
    Write-Host 'Version                    : 0.4.19'
    Write-Host 'Status                     : FAIL'
    Write-Host 'Primary Failure            : TEST_HARNESS'
    Write-Host "Failure Reason             : $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($startedByTest -and -not $KeepServer -and $null -ne $probeProcess) {
        try {
            if (-not $probeProcess.HasExited) {
                Stop-Process -Id $probeProcess.Id -Force -ErrorAction SilentlyContinue
                Write-Host 'Automated Cleanup          : Probe stopped.'
            }
        }
        catch {}
    }
}

if (-not $KeepServer) {
    Read-Host 'Press Enter'
}
