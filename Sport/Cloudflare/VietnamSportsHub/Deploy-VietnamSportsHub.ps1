$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

Write-Host '==============================================='
Write-Host '   VIETNAM SPORTS HUB - CLOUDFLARE DEPLOY'
Write-Host '==============================================='
Write-Host ''
Write-Host 'This deploys the Cloudflare Worker only.'
Write-Host 'The local Node addon server is not required at runtime.'
Write-Host ''

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    throw 'Node.js/npx is not available. Install Node.js first.'
}

Write-Host '[1/2] Checking Wrangler authentication...'
npx wrangler whoami

Write-Host '[2/2] Deploying Vietnam Sports Hub Worker...'
npx wrangler deploy

Write-Host ''
Write-Host 'Deployment command completed.'
Write-Host 'Use the workers.dev URL printed by Wrangler as the Stremio base URL.'
Write-Host 'Manifest: <workers.dev-url>/manifest.json'
