$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath=Join-Path $projectRoot 'Modules\V04.MetaAdapter\V04.MetaAdapter.psm1'
Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.4'
Write-Host '       META ADAPTER INTEGRATION'
Write-Host '==============================================='
try {
 if(-not (Test-Path $modulePath)){throw "Module not found: $modulePath"}
 Import-Module $modulePath -Force
 $eventId=Read-Host 'Selected Event ID (Enter = 2397275)'
 if([string]::IsNullOrWhiteSpace($eventId)){$eventId='2397275'}
 $r=Test-V044MetaAdapter -EventId $eventId
 Write-Host "Version           : $($r.Version)"
 Write-Host "Status            : $($r.Status)"
 Write-Host "Source             : $($r.Source)"
 Write-Host "Event ID           : $($r.EventId)"
 Write-Host "Meta Cache Read    : $($r.MetaCacheRead)"
 Write-Host "API Requests       : $($r.ApiRequests)"
 Write-Host "Meta Loaded        : $($r.MetaLoaded)"
 Write-Host "Stremio Meta Valid : $($r.StremioMetaValid)"
 Write-Host "Meta Cache Path    : $($r.MetaCachePath)"
 if($r.Error){Write-Host "Error              : $($r.Error)" -ForegroundColor Red}
} catch { Write-Host 'Version           : 0.4.4'; Write-Host 'Status            : FAIL' -ForegroundColor Red; Write-Host "Error             : $($_.Exception.Message)" -ForegroundColor Red }
Read-Host 'Press Enter'
