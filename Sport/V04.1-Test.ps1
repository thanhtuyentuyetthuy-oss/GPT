# V0.4.1 standalone manifest contract test
Set-StrictMode -Version Latest

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $root 'Modules\V04.Stremio\V04.Stremio.psm1'

if (-not (Test-Path $modulePath)) {
    Write-Host 'V0.4.1 module is not installed.' -ForegroundColor Yellow
    exit 1
}

Import-Module $modulePath -Force -ErrorAction Stop
$result = Test-V041ManifestContract

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.1'
Write-Host '       STREMIO MANIFEST CONTRACT'
Write-Host '==============================================='
Write-Host "Version          : $($result.Version)"
Write-Host "Status           : $($result.Status)"
Write-Host "Manifest Loaded  : $($result.ManifestLoaded)"
Write-Host "Required Fields  : $($result.RequiredFields)"
Write-Host "Resources Valid  : $($result.ResourcesValid)"
Write-Host "Types Valid      : $($result.TypesValid)"
Write-Host "Catalog Valid    : $($result.CatalogValid)"
Write-Host "ID Prefixes      : $($result.IdPrefixesValid)"
Write-Host "Search Supported : $($result.SearchSupported)"
Write-Host "Live Type        : $($result.LiveType)"

if ($result.Error) {
    Write-Host "Error            : $($result.Error)" -ForegroundColor Red
    exit 1
}

Read-Host 'Press Enter'
