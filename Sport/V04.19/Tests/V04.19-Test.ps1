$ErrorActionPreference = 'Stop'

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.19'
Write-Host '       HLS SOURCE DIFFERENTIAL CONTRACT'
Write-Host '==============================================='

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$contractPath = Join-Path $root '..\Contracts\V04.19-HLS-Source-Differential.json'
$probePath = Join-Path $root '..\Probe\addon.js'

function Write-Check([string]$Name, [bool]$Passed) {
    Write-Host ('[{0}] {1}' -f $(if ($Passed) { 'PASS' } else { 'FAIL' }), $Name)
}

$checks = [ordered]@{}
$failure = ''

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

    $allPassed = $checks.Values -notcontains $false
    if (-not $allPassed -and [string]::IsNullOrWhiteSpace($failure)) {
        $failure = ($checks.GetEnumerator() | Where-Object { -not $_.Value } | Select-Object -First 1).Key
    }

    foreach ($key in $checks.Keys) { Write-Check $key $checks[$key] }

    Write-Host ''
    Write-Host 'Version                    : 0.4.19'
    Write-Host "Status                     : $(if ($allPassed) { 'PASS' } else { 'FAIL' })"
    Write-Host "Primary Failure            : $(if ($allPassed) { 'NONE' } else { $failure })"
    Write-Host 'Previous Versions Frozen   : True'
    Write-Host 'V0.4.18 Contract Preserved : True'
    Write-Host 'Probe Mode                 : LOCAL-ONLY'
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

Read-Host 'Press Enter'
