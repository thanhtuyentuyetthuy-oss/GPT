# Vietnam Sports Hub - Project Controller
# Single entry point for the modular PowerShell project.

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesRoot = Join-Path $ProjectRoot 'Modules'
$SharedRoot  = Join-Path $ProjectRoot 'Shared'

function Import-SportModule {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path $Path) {
        Import-Module $Path -Force -ErrorAction Stop
        return $true
    }
    return $false
}

$sharedModules = @(
    (Join-Path $SharedRoot 'Logging.psm1'),
    (Join-Path $SharedRoot 'GitHub.psm1'),
    (Join-Path $SharedRoot 'Config.psm1'),
    (Join-Path $SharedRoot 'Cache.psm1')
)

foreach ($module in $sharedModules) {
    if (Test-Path $module) { Import-SportModule -Path $module | Out-Null }
}

function Show-SportMenu {
    Clear-Host
    Write-Host '==============================================='
    Write-Host '         VIETNAM SPORTS HUB - CONTROL'
    Write-Host '==============================================='
    Write-Host ''
    Write-Host '[1] Check project structure'
    Write-Host '[2] Check module status'
    Write-Host '[3] Run V0.1 test'
    Write-Host '[4] Run V0.2.1 Catalog test'
    Write-Host '[5] Run V0.2.1 API/Cache integration test'
    Write-Host '[6] Run V0.2.2 League priority test'
    Write-Host '[7] Run V0.2.3 Select/Meta on-demand test'
    Write-Host '[8] Run V0.2.4 Stream contract test'
    Write-Host '[9] Run V0.2.4 Resolver integration test'
    Write-Host '[10] Run V0.2.4 Stream cache test'
    Write-Host '[11] Run V0.3.1 Live contract test'
    Write-Host '[12] Run V0.3.2 Local time state test'
    Write-Host '[13] Run V0.3.3 Active-match Live session contract test'
    Write-Host '[14] Run V0.3.4 Live verification test'
    Write-Host '[15] Run V0.3.5 Active-session polling test'
    Write-Host '[16] Show latest log'
    Write-Host '[17] Publish log to GitHub'
    Write-Host '[0] Exit'
    Write-Host ''
}

function Invoke-V01 {
    $module = Join-Path $ModulesRoot 'V01.Catalog/V01.Catalog.psm1'
    if (-not (Import-SportModule -Path $module)) { Write-Host 'V0.1 module is not installed yet.' -ForegroundColor Yellow; return }
    if (Get-Command Test-V01Catalog -ErrorAction SilentlyContinue) { Test-V01Catalog } else { Write-Host 'Test-V01Catalog is not exported by the V0.1 module.' -ForegroundColor Yellow }
}

function Invoke-V02Contract {
    $module = Join-Path $ModulesRoot 'V02.Catalog/V02.Catalog.psm1'
    if (-not (Import-SportModule -Path $module)) { Write-Host 'V0.2.1 Catalog module is not installed yet.' -ForegroundColor Yellow; return }
    $result = Test-V02Catalog
    Write-Host "Version: $($result.Version)"
    Write-Host "Status : $($result.Status)"
    Write-Host $result.Message
    $result.Checks | Format-List
}

function Invoke-V02Integration {
    $module = Join-Path $ModulesRoot 'V02.Catalog/V02.Catalog.psm1'
    if (-not (Import-SportModule -Path $module)) { Write-Host 'V0.2.1 Catalog module is not installed yet.' -ForegroundColor Yellow; return }
    $result = Test-V02CatalogIntegration
    Write-Host "Version      : $($result.Version)"
    Write-Host "Status       : $($result.Status)"
    Write-Host "API Reachable: $($result.ApiReachable)"
    Write-Host "Catalog Count: $($result.CatalogCount)"
    Write-Host "Cache Path   : $($result.CachePath)"
    if ($result.Error) { Write-Host "Error        : $($result.Error)" -ForegroundColor Red }
}

function Invoke-V022LeaguePriority {
    $module = Join-Path $ModulesRoot 'V02.Leagues/V02.Leagues.psm1'
    if (-not (Import-SportModule -Path $module)) { Write-Host 'V0.2.2 League priority module is not installed yet.' -ForegroundColor Yellow; return }
    $result = Test-V022LeaguePriority
    Write-Host "Version     : $($result.Version)"
    Write-Host "Status      : $($result.Status)"
    Write-Host "Source      : $($result.Source)"
    Write-Host "API Requests: $($result.ApiRequests)"
    Write-Host "Cache Read  : $($result.CacheRead)"
    Write-Host "Total       : $($result.Total)"
    Write-Host "Priority    : $($result.Priority)"
    Write-Host "Other       : $($result.Other)"
    if ($result.Error) { Write-Host "Error       : $($result.Error)" -ForegroundColor Red }
}

function Invoke-V023Meta {
    $module = Join-Path $ModulesRoot 'V02.Meta/V02.Meta.psm1'
    if (-not (Import-SportModule -Path $module)) { Write-Host 'V0.2.3 Meta module is not installed yet.' -ForegroundColor Yellow; return }
    $eventId = Read-Host 'Selected Event ID (Enter = first event in current catalog cache)'
    $result = Test-V023MetaOnDemand -EventId $eventId
    Write-Host "Version        : $($result.Version)"
    Write-Host "Status         : $($result.Status)"
    Write-Host "Source         : $($result.Source)"
    Write-Host "Event ID       : $($result.EventId)"
    Write-Host "API Requests   : $($result.ApiRequests)"
    Write-Host "Catalog Read   : $($result.CatalogRead)"
    Write-Host "Meta Cache Hit : $($result.MetaCacheHit)"
    Write-Host "Meta Loaded    : $($result.MetaLoaded)"
    Write-Host "Meta Cache Path: $($result.MetaCachePath)"
    if ($result.Error) { Write-Host "Error          : $($result.Error)" -ForegroundColor Red }
}

function Invoke-V024StreamContract {
    $module = Join-Path $ModulesRoot 'V02.Stream/V02.Stream.psm1'
    if (-not (Import-SportModule -Path $module)) { Write-Host 'V0.2.4 Stream module is not installed yet.' -ForegroundColor Yellow; return }
    $result = Test-V024StreamContract
    Write-Host "Version              : $($result.Version)"
    Write-Host "Status               : $($result.Status)"
    Write-Host $result.Message
    $result.Checks | Format-List
}

function Invoke-V024Resolver {
    $module = Join-Path $ModulesRoot 'V02.Stream/V02.Stream.psm1'
    if (-not (Import-SportModule -Path $module)) { Write-Host 'V0.2.4 Stream module is not installed yet.' -ForegroundColor Yellow; return }
    $eventId = Read-Host 'Selected Event ID'
    $sourceUrl = Read-Host 'Authorized public/official source URL'
    $result = Test-V024ResolverIntegration -EventId $eventId -SourceUrl $sourceUrl
    Write-Host "Version                : $($result.Version)"
    Write-Host "Status                 : $($result.Status)"
    Write-Host "Event ID               : $($result.EventId)"
    Write-Host "Play Requested         : $($result.PlayRequested)"
    Write-Host "Authorized Source Only : $($result.AuthorizedSourceOnly)"
    Write-Host "Source Provided        : $($result.SourceProvided)"
    Write-Host "URL Valid              : $($result.UrlValid)"
    Write-Host "Resolver Requests      : $($result.ResolverRequest)"
    Write-Host "Resolved               : $($result.Resolved)"
    if ($result.Error) { Write-Host "Error                  : $($result.Error)" -ForegroundColor Red }
}

function Invoke-V024StreamCache {
    $module = Join-Path $ModulesRoot 'V02.Stream/V02.Stream.psm1'
    if (-not (Import-SportModule -Path $module)) { Write-Host 'V0.2.4 Stream module is not installed yet.' -ForegroundColor Yellow; return }
    $eventId = Read-Host 'Selected Event ID'
    $sourceUrl = Read-Host 'Authorized public/official source URL'
    $ttlText = Read-Host 'TTL seconds (Enter = default 120)'
    $ttlSeconds = 120
    if (-not [string]::IsNullOrWhiteSpace($ttlText)) { [int]$ttlSeconds = $ttlText }
    $result = Test-V024StreamCache -EventId $eventId -SourceUrl $sourceUrl -TtlSeconds $ttlSeconds
    Write-Host "Version                : $($result.Version)"
    Write-Host "Status                 : $($result.Status)"
    Write-Host "Event ID               : $($result.EventId)"
    Write-Host "Source Policy          : $($result.SourcePolicy)"
    Write-Host "Play Requested         : $($result.PlayRequested)"
    Write-Host "First Cache Hit        : $($result.FirstCacheHit)"
    Write-Host "First Cache Write      : $($result.FirstCacheWrite)"
    Write-Host "Second Cache Hit       : $($result.SecondCacheHit)"
    Write-Host "Resolver Requests #1   : $($result.ResolverRequestsFirst)"
    Write-Host "Resolver Requests #2   : $($result.ResolverRequestsSecond)"
    Write-Host "TTL Seconds            : $($result.TtlSeconds)"
    Write-Host "Cache Path             : $($result.CachePath)"
    if ($result.Error) { Write-Host "Error                  : $($result.Error)" -ForegroundColor Red }
}

function Invoke-V031LiveContract {
    $module = Join-Path $ModulesRoot 'V03.Live/V03.Live.psm1'
    if (-not (Import-SportModule -Path $module)) { Write-Host 'V0.3.1 Live module is not installed yet.' -ForegroundColor Yellow; return }
    $result = Test-V031LiveContract
    Write-Host "Version    : $($result.Version)"
    Write-Host "Status     : $($result.Status)"
    Write-Host $result.Message
    $result.Checks | Format-List
}

function Invoke-V032LocalTimeState {
    $module = Join-Path $ModulesRoot 'V03.LocalTimeState/V03.LocalTimeState.psm1'
    if (-not (Import-SportModule -Path $module)) { Write-Host 'V0.3.2 Local Time State module is not installed yet.' -ForegroundColor Yellow; return }
    $result = Test-V032LocalTimeState
    Write-Host "Version       : $($result.Version)"
    Write-Host "Status        : $($result.Status)"
    Write-Host "Source        : $($result.Source)"
    Write-Host "API Requests  : $($result.ApiRequests)"
    Write-Host "Cache Read    : $($result.CacheRead)"
    Write-Host "Total         : $($result.Total)"
    Write-Host "Live Candidate: $($result.LiveCandidate)"
    Write-Host "Upcoming      : $($result.Upcoming)"
    Write-Host "Unknown       : $($result.Unknown)"
    Write-Host "TimeZone      : $($result.TimeZone)"
    if ($result.Error) { Write-Host "Error         : $($result.Error)" -ForegroundColor Red }
}

function Invoke-V033LiveSessionContract {
    $module = Join-Path $ModulesRoot 'V03.LiveSession/V03.LiveSession.psm1'
    if (-not (Import-SportModule -Path $module)) { Write-Host 'V0.3.3 Live Session module is not installed yet.' -ForegroundColor Yellow; return }
    $result = Test-V033LiveSessionContract
    Write-Host "Version                   : $($result.Version)"
    Write-Host "Status                    : $($result.Status)"
    Write-Host $result.Message
    $result.Checks | Format-List
}

function Invoke-V034LiveVerification {
    $module = Join-Path $ModulesRoot 'V03.LiveVerification/V03.LiveVerification.psm1'
    if (-not (Import-SportModule -Path $module)) { Write-Host 'V0.3.4 Live Verification module is not installed yet.' -ForegroundColor Yellow; return }
    $eventId = Read-Host 'Selected Event ID (Enter = 2397275)'
    if ([string]::IsNullOrWhiteSpace($eventId)) { $eventId = '2397275' }
    $result = Test-V034LiveVerification -EventId $eventId
    Write-Host "Version       : $($result.Version)"
    Write-Host "Status        : $($result.Status)"
    Write-Host "Source        : $($result.Source)"
    Write-Host "Event ID      : $($result.EventId)"
    Write-Host "Catalog Read  : $($result.CatalogRead)"
    Write-Host "Meta Cache Read: $($result.MetaCacheRead)"
    Write-Host "Selected      : $($result.Selected)"
    Write-Host "Play Requested: $($result.PlayRequested)"
    Write-Host "API Requests  : $($result.ApiRequests)"
    Write-Host "Verified      : $($result.Verified)"
    Write-Host "Is Live       : $($result.IsLive)"
    Write-Host "Live State    : $($result.LiveState)"
    Write-Host "Source Status : $($result.SourceStatus)"
    if ($result.Error) { Write-Host "Error         : $($result.Error)" -ForegroundColor Red }
}

function Invoke-V035ActivePolling {
    $module = Join-Path $ModulesRoot 'V03.ActivePolling/V03.ActivePolling.psm1'
    if (-not (Import-SportModule -Path $module)) { Write-Host 'V0.3.5 Active Polling module is not installed yet.' -ForegroundColor Yellow; return }
    $liveState = Read-Host 'Live state (Enter = FINISHED)'
    if ([string]::IsNullOrWhiteSpace($liveState)) { $liveState = 'FINISHED' }
    $liveState = $liveState.ToUpperInvariant()
    try {
        $result = Test-V035ActivePolling -LiveState $liveState
        Write-Host "Version                  : $($result.Version)"
        Write-Host "Status                   : $($result.Status)"
        Write-Host "Session Active           : $($result.SessionActive)"
        Write-Host "Polling Enabled          : $($result.PollingEnabled)"
        Write-Host "Poll Only When LIVE      : $($result.PollOnlyWhenLive)"
        Write-Host "Active Session Only      : $($result.PollOnlyDuringActiveSession)"
        Write-Host "Live State               : $($result.LiveState)"
        Write-Host "Poll Allowed             : $($result.PollAllowed)"
        Write-Host "Poll Requests            : $($result.PollRequests)"
        Write-Host "Stop Reason              : $($result.StopReason)"
        Write-Host "Exit Stops Polling       : $($result.ExitStopsPolling)"
        if ($result.Error) { Write-Host "Error                    : $($result.Error)" -ForegroundColor Red }
    } catch {
        Write-Host "Error                    : $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-Status {
    $candidates = Get-ChildItem -Path $ModulesRoot -Directory -ErrorAction SilentlyContinue
    if (-not $candidates) { Write-Host 'No version modules have been added yet.' -ForegroundColor Yellow; return }
    foreach ($dir in $candidates) {
        $passFile = Join-Path $dir.FullName 'PASS.md'
        if (Test-Path $passFile) { Write-Host "[$($dir.Name)] PASS/FREEZE" -ForegroundColor Green }
        else { Write-Host "[$($dir.Name)] DEVELOPMENT" -ForegroundColor Cyan }
    }
}

while ($true) {
    Show-SportMenu
    $choice = Read-Host 'Select'
    switch ($choice) {
        '1' { Write-Host "Project: $ProjectRoot"; Write-Host "Modules: $ModulesRoot"; Write-Host "Shared : $SharedRoot"; Read-Host 'Press Enter' }
        '2' { Show-Status; Read-Host 'Press Enter' }
        '3' { Invoke-V01; Read-Host 'Press Enter' }
        '4' { Invoke-V02Contract; Read-Host 'Press Enter' }
        '5' { Invoke-V02Integration; Read-Host 'Press Enter' }
        '6' { Invoke-V022LeaguePriority; Read-Host 'Press Enter' }
        '7' { Invoke-V023Meta; Read-Host 'Press Enter' }
        '8' { Invoke-V024StreamContract; Read-Host 'Press Enter' }
        '9' { Invoke-V024Resolver; Read-Host 'Press Enter' }
        '10' { Invoke-V024StreamCache; Read-Host 'Press Enter' }
        '11' { Invoke-V031LiveContract; Read-Host 'Press Enter' }
        '12' { Invoke-V032LocalTimeState; Read-Host 'Press Enter' }
        '13' { Invoke-V033LiveSessionContract; Read-Host 'Press Enter' }
        '14' { Invoke-V034LiveVerification; Read-Host 'Press Enter' }
        '15' { Invoke-V035ActivePolling; Read-Host 'Press Enter' }
        '16' { $latest = Join-Path $ProjectRoot 'Logs/log.txt'; if (Test-Path $latest) { Get-Content $latest -Tail 60 } else { Write-Host 'No log file yet.' -ForegroundColor Yellow }; Read-Host 'Press Enter' }
        '17' { if (Get-Command Publish-SportLog -ErrorAction SilentlyContinue) { Publish-SportLog -RepoRoot $ProjectRoot } else { Write-Host 'GitHub module not installed yet.' -ForegroundColor Yellow }; Read-Host 'Press Enter' }
        '0' { Write-Host 'Exiting Vietnam Sports Hub...'; return }
        default { Write-Host 'Invalid selection.' -ForegroundColor Yellow; Start-Sleep -Milliseconds 700 }
    }
}
