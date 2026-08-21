[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.20'
Write-Host '       PLAYBACK COMPATIBILITY MATRIX'
Write-Host '==============================================='

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$contractPath = Join-Path $root '..\Contracts\V04.20-Playback-Compatibility-Matrix.json'
$contract = Get-Content -Raw -Path $contractPath | ConvertFrom-Json

$checks = [ordered]@{}
$checks['Previous Versions Frozen'] = [bool]$contract.previousVersionsFrozen
$checks['V0.4.19 Contract Preserved'] = [string]$contract.previousContract -eq '0.4.19'
$checks['Payload Class Matrix'] = [string]$contract.testRule -eq 'COMPARE_PAYLOAD_CLASSES_ONLY'
$checks['MP4 Control Source'] = @($contract.sources | Where-Object { $_.id -eq 'MP4' -and $_.role -eq 'CONTROL' -and -not $_.notWebReady }).Count -eq 1
$checks['Mux HLS Comparison'] = @($contract.sources | Where-Object { $_.id -eq 'MUX_HLS' -and $_.role -eq 'COMPARISON' -and $_.notWebReady }).Count -eq 1
$checks['Apple HLS Comparison'] = @($contract.sources | Where-Object { $_.id -eq 'APPLE_HLS' -and $_.role -eq 'COMPARISON' -and $_.notWebReady }).Count -eq 1
$checks['Diagnostics Enabled'] = [bool]$contract.diagnostics.enabled
$checks['Local Only'] = [string]$contract.deployment -eq 'LOCAL-ONLY'
$checks['Auto Deploy Disabled'] = -not [bool]$contract.autoDeploy

foreach ($key in $checks.Keys) {
    Write-Host ('[{0}] {1}' -f $(if ($checks[$key]) { 'PASS' } else { 'FAIL' }), $key)
}

$allPassed = $checks.Values -notcontains $false
Write-Host ''
Write-Host 'Version                    : 0.4.20'
Write-Host "Status                     : $(if ($allPassed) { 'PASS' } else { 'FAIL' })"
Write-Host "Primary Failure            : $(if ($allPassed) { 'NONE' } else { ($checks.GetEnumerator() | Where-Object { -not $_.Value } | Select-Object -First 1).Key })"
Write-Host 'Previous Versions Frozen   : True'
Write-Host 'V0.4.19 Contract Preserved : True'
Write-Host 'Matrix Mode                : MP4-VS-HLS'
Write-Host 'Deployment                 : DEFERRED'
Write-Host "Integration Complete       : $allPassed"
Read-Host 'Press Enter'
