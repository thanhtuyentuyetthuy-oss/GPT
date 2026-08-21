[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkerRoot,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$resolvedWorkerRoot = [System.IO.Path]::GetFullPath($WorkerRoot)
$wranglerConfig = Join-Path $resolvedWorkerRoot 'wrangler.jsonc'

Write-Host '-----------------------------------------------'
Write-Host ' V0.4.15 CLOUDFLARE DEPLOYMENT GATE'
Write-Host '-----------------------------------------------'

if (-not (Test-Path $resolvedWorkerRoot)) {
    throw "Cloudflare Worker source directory not found: $resolvedWorkerRoot"
}

if (-not (Test-Path $wranglerConfig)) {
    throw "Cloudflare Worker wrangler.jsonc not found: $wranglerConfig"
}

if ($null -eq (Get-Command 'npx.cmd' -ErrorAction SilentlyContinue)) {
    throw 'npx.cmd was not found in PATH. Install Node.js/npm before deployment.'
}

Write-Host "Worker Root : $resolvedWorkerRoot"
Write-Host "Wrangler    : $wranglerConfig"
Write-Host "Dry Run     : $DryRun"

Push-Location $resolvedWorkerRoot
try {
    if ($DryRun) {
        & npx.cmd wrangler deploy --dry-run
    }
    else {
        & npx.cmd wrangler deploy
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Wrangler deploy command failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

Write-Host 'Deployment Result : PASS'
