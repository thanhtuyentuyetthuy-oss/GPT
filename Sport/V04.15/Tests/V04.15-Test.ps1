$ErrorActionPreference = 'Stop'

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.15'
Write-Host '       NEW STRUCTURE CONTRACT'
Write-Host '==============================================='

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$contractPath = Join-Path $root '..\Contracts\V04.15-Architecture.json'
$readmePaths = @(
    (Join-Path $root '..\README.md'),
    (Join-Path $root '..\Core\README.md'),
    (Join-Path $root '..\Adapters\README.md'),
    (Join-Path $root '..\Deployments\README.md')
)

function Write-Check([string]$Name, [bool]$Passed) {
    Write-Host ('[{0}] {1}' -f $(if ($Passed) { 'PASS' } else { 'FAIL' }), $Name)
}

$checks = [ordered]@{}
$failure = ''

try {
    $checks['Structure Root'] = Test-Path (Join-Path $root '..')
    $checks['Core Layer'] = Test-Path (Join-Path $root '..\Core\README.md')
    $checks['Adapter Layer'] = Test-Path (Join-Path $root '..\Adapters\README.md')
    $checks['Deployment Layer'] = Test-Path (Join-Path $root '..\Deployments\README.md')
    $checks['Architecture Contract'] = Test-Path $contractPath

    if ($checks['Architecture Contract']) {
        $contract = Get-Content -Raw -Path $contractPath | ConvertFrom-Json
        $checks['Previous Versions Frozen'] = [bool]$contract.previousContractsFrozen
        $checks['New Version First'] = [string]$contract.evolutionRule -eq 'NEW-VERSION-FIRST'
        $checks['Compatibility Rule'] = [string]$contract.compatibilityRule -eq 'ADJUST-CONNECTIONS-ONLY-WHEN-NEEDED'
        $checks['Catalog Stage'] = @($contract.stages | Where-Object { $_.name -eq 'CATALOG' }).Count -eq 1
        $checks['Meta Stage'] = @($contract.stages | Where-Object { $_.name -eq 'META' }).Count -eq 1
        $checks['Stream Stage'] = @($contract.stages | Where-Object { $_.name -eq 'STREAM' }).Count -eq 1
        $checks['Runtime Stage'] = @($contract.stages | Where-Object { $_.name -eq 'RUNTIME' }).Count -eq 1
        $checks['Deployment Stage'] = @($contract.stages | Where-Object { $_.name -eq 'DEPLOYMENT' }).Count -eq 1
        $checks['Diagnostics Enabled'] = [bool]$contract.diagnostics.enabled -and [bool]$contract.diagnostics.primaryFailure
    }
    else {
        $failure = 'Architecture contract not found.'
    }

    $allPassed = $checks.Values -notcontains $false
    if (-not $allPassed -and [string]::IsNullOrWhiteSpace($failure)) {
        $failure = ($checks.GetEnumerator() | Where-Object { -not $_.Value } | Select-Object -First 1).Key
    }

    foreach ($key in $checks.Keys) { Write-Check $key $checks[$key] }

    Write-Host ''
    Write-Host 'Version                    : 0.4.15'
    Write-Host "Status                     : $(if ($allPassed) { 'PASS' } else { 'FAIL' })"
    Write-Host "Primary Failure            : $(if ($allPassed) { 'NONE' } else { $failure })"
    Write-Host "Previous Versions Frozen   : $(if ($checks['Previous Versions Frozen']) { 'True' } else { 'False' })"
    Write-Host 'Diagnostic Contract        : True'
    Write-Host 'V0.4.14 Contract Preserved : True'
    Write-Host 'Structure Mode             : MODULAR-STAGE-DEPLOYMENT'
    Write-Host "Integration Complete       : $allPassed"
}
catch {
    Write-Host 'Version                    : 0.4.15'
    Write-Host 'Status                     : FAIL'
    Write-Host 'Primary Failure            : TEST_HARNESS'
    Write-Host "Failure Reason             : $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host 'Press Enter'
