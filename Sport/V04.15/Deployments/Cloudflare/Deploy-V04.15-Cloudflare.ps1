$ErrorActionPreference = 'Stop'

[CmdletBinding()]
param(
    [switch]$DryRun
)

$deploymentRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workerRoot = Join-Path $deploymentRoot 'Worker'
$wranglerConfig = Join-Path $workerRoot 'wrangler.jsonc'

Write-Host '-----------------------------------------------'
Write-Host ' V0.4.15 CLOUDFLARE DEPLOYMENT GATE'
Write-Host '-----------------------------------------------'

if (-not (Test-Path $workerRoot)) {
    throw "Cloudflare Worker source directory not found: $workerRoot"
}

if (-not (Test-Path $wranglerConfig)) {
    throw "Cloudflare Worker wrangler.jsonc not found: $wranglerConfig"
}

$wrangler = Get-Command 'npx.cmd' -ErrorAction SilentlyContinue
if ($null -eq $wrangler) {
    throw 'npx.cmd was not found in PATH. Install Node.js/npm before deployment.'
}

Write-Host "Worker Root : $workerRoot"
Write-Host "Wrangler    : $wranglerConfig"
Write-Host "Dry Run     : $DryRun"

Push-Location $workerRoot
try {
    if ($DryRun) {
        & npx.cmd wrangler deploy --dry-run
        if ($LASTEXITCODE -ne 0) {
            throw "Wrangler dry-run failed with exit code $LASTEXITCODE."
        }
    }
    else {
        & npx.cmd wrangler deploy
        if ($LASTEXITCODE -ne 0) {
            throw "Wrangler deploy failed with exit code $LASTEXITCODE."
        }
    }
}
finally {
    Pop-Location
}

Write-Host 'Deployment Result : PASS'
