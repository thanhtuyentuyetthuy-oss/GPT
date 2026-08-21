[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$workerRoot = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Worker'
$wranglerConfig = Join-Path $workerRoot 'wrangler.jsonc'

if (-not (Test-Path $workerRoot)) { throw "Worker root not found: $workerRoot" }
if (-not (Test-Path $wranglerConfig)) { throw "wrangler.jsonc not found: $wranglerConfig" }
if ($null -eq (Get-Command 'npx.cmd' -ErrorAction SilentlyContinue)) { throw 'npx.cmd was not found in PATH.' }

Push-Location $workerRoot
try {
    if ($DryRun) { & npx.cmd wrangler deploy --dry-run }
    else { & npx.cmd wrangler deploy }
    if ($LASTEXITCODE -ne 0) { throw "Wrangler deploy failed with exit code $LASTEXITCODE." }
}
finally { Pop-Location }

Write-Host 'Deployment Result : PASS'
