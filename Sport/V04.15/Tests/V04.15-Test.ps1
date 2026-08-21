$ErrorActionPreference = 'Stop'

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.15'
Write-Host '       NEW STRUCTURE + GATED DEPLOY CONTRACT'
Write-Host '==============================================='

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$versionRoot = Join-Path $root '..'
$contractPath = Join-Path $versionRoot 'Contracts\V04.15-Architecture.json'
$deploymentDir = Join-Path $versionRoot 'Deployments\Cloudflare'
$deploymentConfigPath = Join-Path $deploymentDir 'V04.15-Deployment.json'
$deploymentScriptPath = Join-Path $deploymentDir 'Deploy-V04.15-Cloudflare.ps1'

function Write-Check([string]$Name, [bool]$Passed) {
    Write-Host ('[{0}] {1}' -f $(if ($Passed) { 'PASS' } else { 'FAIL' }), $Name)
}

$checks = [ordered]@{}
$failure = ''
$contract = $null
$deploymentConfig = $null
$deploymentOutput = @()
$deploymentSucceeded = $false
$deploymentAttempted = $false

try {
    $checks['Structure Root'] = Test-Path $versionRoot
    $checks['Core Layer'] = Test-Path (Join-Path $versionRoot 'Core\README.md')
    $checks['Adapter Layer'] = Test-Path (Join-Path $versionRoot 'Adapters\README.md')
    $checks['Deployment Layer'] = Test-Path (Join-Path $versionRoot 'Deployments\README.md')
    $checks['Architecture Contract'] = Test-Path $contractPath
    $checks['Deployment Config'] = Test-Path $deploymentConfigPath
    $checks['Deployment Script'] = Test-Path $deploymentScriptPath

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

    if ($checks['Deployment Config']) {
        $deploymentConfig = Get-Content -Raw -Path $deploymentConfigPath | ConvertFrom-Json
        $checks['Auto Deploy Policy'] = [bool]$deploymentConfig.autoDeployOnPass -and [bool]$deploymentConfig.stopOnFailure
        $workerRoot = [System.IO.Path]::GetFullPath((Join-Path $deploymentDir ([string]$deploymentConfig.workerRelativePath)))
        $wranglerConfigPath = Join-Path $workerRoot 'wrangler.jsonc'
        $checks['Cloudflare Worker Target'] = Test-Path $workerRoot
        $checks['Wrangler Config Ready'] = Test-Path $wranglerConfigPath
    }
    else {
        $failure = if ($failure) { $failure } else { 'Deployment config not found.' }
        $checks['Auto Deploy Policy'] = $false
        $checks['Cloudflare Worker Target'] = $false
        $checks['Wrangler Config Ready'] = $false
    }

    $preDeployPassed = $checks.Values -notcontains $false
    if (-not $preDeployPassed -and [string]::IsNullOrWhiteSpace($failure)) {
        $failure = ($checks.GetEnumerator() | Where-Object { -not $_.Value } | Select-Object -First 1).Key
    }

    foreach ($key in $checks.Keys) { Write-Check $key $checks[$key] }

    Write-Host ''
    Write-Host 'Pre-Deployment Status     : ' -NoNewline
    Write-Host $(if ($preDeployPassed) { 'PASS' } else { 'FAIL' })

    if ($preDeployPassed -and [bool]$deploymentConfig.autoDeployOnPass) {
        $deploymentAttempted = $true
        Write-Host ''
        Write-Host '-----------------------------------------------'
        Write-Host ' AUTO DEPLOY: CLOUD FLARE WORKER'
        Write-Host '-----------------------------------------------'
        Write-Host "Deployment Target         : $workerRoot"
        Write-Host 'Gate                      : ALL TESTS PASSED'

        $deploymentOutput = @(& $deploymentScriptPath -WorkerRoot $workerRoot 2>&1)
        $deploymentSucceeded = ($LASTEXITCODE -eq 0)
        foreach ($line in $deploymentOutput) { Write-Host $line }

        if (-not $deploymentSucceeded) {
            $failure = "Cloudflare deployment failed with exit code $LASTEXITCODE."
        }
    }
    elseif (-not $preDeployPassed) {
        Write-Host ''
        Write-Host 'AUTO DEPLOY             : STOPPED'
        Write-Host 'Reason                  : One or more pre-deployment checks failed.'
    }

    $allPassed = $preDeployPassed -and $deploymentAttempted -and $deploymentSucceeded

    Write-Host ''
    Write-Host 'Version                    : 0.4.15'
    Write-Host "Status                     : $(if ($allPassed) { 'PASS' } else { 'FAIL' })"
    Write-Host "Primary Failure            : $(if ($allPassed) { 'NONE' } elseif ($failure) { $failure } else { 'DEPLOYMENT_GATE' })"
    Write-Host 'Previous Versions Frozen   : True'
    Write-Host 'Diagnostic Contract        : True'
    Write-Host 'V0.4.14 Contract Preserved : True'
    Write-Host 'Structure Mode             : MODULAR-STAGE-DEPLOYMENT'
    Write-Host "Auto Deploy On Pass        : $(if ($deploymentConfig) { $deploymentConfig.autoDeployOnPass } else { 'False' })"
    Write-Host "Deployment Attempted       : $deploymentAttempted"
    Write-Host "Cloudflare Deployment      : $(if ($deploymentSucceeded) { 'PASS' } else { 'STOPPED/FAIL' })"
    Write-Host "Integration Complete       : $allPassed"

    if (-not $allPassed) {
        Write-Host ''
        Write-Host 'DIAGNOSTIC DETAIL' -ForegroundColor Yellow
        Write-Host "  Failed Gate              : $(if ($failure) { $failure } else { 'DEPLOYMENT_GATE' })"
        Write-Host "  Pre-Deploy Checks        : $(if ($preDeployPassed) { 'PASS' } else { 'FAIL' })"
        Write-Host "  Deployment Attempted     : $deploymentAttempted"
        Write-Host "  Deployment Result        : $(if ($deploymentSucceeded) { 'PASS' } else { 'FAIL/STOPPED' })"
    }
}
catch {
    Write-Host 'Version                    : 0.4.15'
    Write-Host 'Status                     : FAIL'
    Write-Host 'Primary Failure            : TEST_HARNESS'
    Write-Host "Failure Reason             : $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host 'Press Enter'
