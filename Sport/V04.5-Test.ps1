$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath=Join-Path $projectRoot 'Modules\V04.StreamAdapter\V04.StreamAdapter.psm1'
Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.5'
Write-Host '       STREAM ADAPTER INTEGRATION'
Write-Host '==============================================='
try {
    if(-not (Test-Path $modulePath)){ throw "Module not found: $modulePath" }
    Import-Module $modulePath -Force
    $eventId=Read-Host 'Selected Event ID (Enter = 2397275)'
    if([string]::IsNullOrWhiteSpace($eventId)){$eventId='2397275'}
    $r=Test-V045StreamAdapter -EventId $eventId
    Write-Host "Version                : $($r.Version)"
    Write-Host "Status                 : $($r.Status)"
    Write-Host "Source                 : $($r.Source)"
    Write-Host "Event ID               : $($r.EventId)"
    Write-Host "Stream Cache Read      : $($r.'Stream Cache Read')"
    Write-Host "Resolver Requests      : $($r.'Resolver Requests')"
    Write-Host "Stream Loaded          : $($r.'Stream Loaded')"
    Write-Host "Authorized Source Only : $($r.'Authorized Source Only')"
    Write-Host "Stremio Stream Valid   : $($r.'Stremio Stream Valid')"
    Write-Host "Stream Cache Path      : $($r.'Stream Cache Path')"
    if($r.Error){Write-Host "Error                  : $($r.Error)" -ForegroundColor Red}
} catch {
    Write-Host 'Version                : 0.4.5'
    Write-Host 'Status                 : FAIL' -ForegroundColor Red
    Write-Host "Error                  : $($_.Exception.Message)" -ForegroundColor Red
}
Read-Host 'Press Enter'
