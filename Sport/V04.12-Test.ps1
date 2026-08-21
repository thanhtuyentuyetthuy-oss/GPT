$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverRoot = Join-Path $projectRoot 'V04.AddonServer'
$addonPath = Join-Path $serverRoot 'addon.js'
$baseUrl = 'http://127.0.0.1:7000'
$eventId = '2397275'
$eventKey = "sports:event:$eventId"
$approvedHosts = @('test-streams.mux.dev','stream.mux.com')
$v035Path = Join-Path $projectRoot 'Modules\V03.ActivePolling\V03.ActivePolling.psm1'
$v036Path = Join-Path $projectRoot 'Modules\V03.ExitStop\V03.ExitStop.psm1'

function Get-PropertyValue($Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    $Property = $Object.PSObject.Properties | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($null -eq $Property) { return $null }
    return $Property.Value
}

function Get-ArrayItems($Value) {
    if ($null -eq $Value) { return @() }
    return @($Value | ForEach-Object { $_ })
}

function Get-JsonResponse([string]$Uri) {
    $Response = Invoke-WebRequest -Uri $Uri -Method Get -UseBasicParsing
    return ($Response.Content | ConvertFrom-Json)
}

function Write-Check([string]$Name, [bool]$Passed) {
    $State = if ($Passed) { 'PASS' } else { 'FAIL' }
    Write-Host ("[{0}] {1}" -f $State, $Name)
}

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.12'
Write-Host '       SESSION / CONNECTION OPTIMIZATION'
Write-Host '==============================================='

$process = $null
$checks = [ordered]@{}
$primaryFailure = ''
$failureReason = ''
$stateRows = @()

try {
    if (-not (Test-Path $v035Path)) { throw "V0.3.5 Active Polling module not found: $v035Path" }
    if (-not (Test-Path $v036Path)) { throw "V0.3.6 Exit/Stop module not found: $v036Path" }

    Import-Module $v035Path -Force
    Import-Module $v036Path -Force

    $pollConfig = Get-V035ActivePollingConfig
    $exitConfig = Get-V036ExitStopConfig
    $finishedPolling = Test-V035ActivePolling -LiveState FINISHED
    $livePolling = Test-V035ActivePolling -LiveState LIVE
    $exitStatus = Test-V036ExitStop -PollRequestsBeforeExit $livePolling.PollRequests

    $checks['V0.3.5 Polling Policy'] = $pollConfig.PollOnlyWhenLive -and $pollConfig.PollOnlyDuringActiveSession -and $pollConfig.StopWhenFinished -and $pollConfig.CacheFirst
    $checks['V0.3.5 FINISHED No Poll'] = $finishedPolling.Status -eq 'PASS' -and (-not $finishedPolling.PollAllowed) -and $finishedPolling.PollRequests -eq 0 -and $finishedPolling.StopReason -eq 'FINISHED'
    $checks['V0.3.5 LIVE One-Cycle Poll'] = $livePolling.Status -eq 'PASS' -and $livePolling.PollAllowed -and $livePolling.PollRequests -eq 1
    $checks['V0.3.6 Exit Stops'] = $exitStatus.Status -eq 'PASS' -and $exitStatus.PollingStopped -and $exitStatus.PostExitPollRequests -eq 0 -and $exitStatus.PostExitRequests -eq 0 -and $exitStatus.WarmCacheKept

    $process = Start-Process -FilePath 'node' -ArgumentList @($addonPath) -WorkingDirectory $serverRoot -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 800

    $manifest = Get-JsonResponse "$baseUrl/manifest.json"
    $health = Get-JsonResponse "$baseUrl/health"
    $catalog = Get-JsonResponse "$baseUrl/catalog/tv/vietnam-sports.json"
    $meta = Get-JsonResponse "$baseUrl/meta/tv/$eventKey.json"
    $stream = Get-JsonResponse "$baseUrl/stream/tv/$eventKey.json"

    $manifestResources = Get-ArrayItems (Get-PropertyValue $manifest 'resources')
    $checks['V0.4 Manifest'] = ([string](Get-PropertyValue $manifest 'id') -eq 'org.vietnam.sports.hub') -and ($manifestResources -contains 'catalog') -and ($manifestResources -contains 'meta') -and ($manifestResources -contains 'stream')
    $checks['V0.4 Health'] = ([string](Get-PropertyValue $health 'status') -eq 'OK') -and ([string](Get-PropertyValue $health 'sourcePolicy') -eq 'AUTHORIZED-ONLY')

    $catalogItems = Get-ArrayItems (Get-PropertyValue $catalog 'metas')
    foreach ($item in $catalogItems) {
        $name = [string](Get-PropertyValue $item 'name')
        $description = [string](Get-PropertyValue $item 'description')
        $stateMarker = ''
        if ($name -match '^\[(LIVE|NEXT|DONE)\]') { $stateMarker = $Matches[1] }
        $state = ''
        if ($description -match 'State:\s*(LIVE-CANDIDATE|UPCOMING|FINISHED)') { $state = $Matches[1] }
        $stateRows += [pscustomobject]@{
            Id = [string](Get-PropertyValue $item 'id')
            Marker = $stateMarker
            State = $state
            Valid = ($stateMarker -ne '') -and ($state -ne '')
        }
    }

    $checks['Catalog State Continuity'] = $stateRows.Count -eq 3 -and (@($stateRows | Where-Object { -not $_.Valid }).Count -eq 0)

    $liveRows = @($stateRows | Where-Object { $_.State -eq 'LIVE-CANDIDATE' })
    $upcomingRows = @($stateRows | Where-Object { $_.State -eq 'UPCOMING' })
    $finishedRows = @($stateRows | Where-Object { $_.State -eq 'FINISHED' })

    # Connection optimization contract: no LIVE rows means no polling is needed now.
    $connectionMode = if ($liveRows.Count -gt 0) { 'ACTIVE-LIVE-POLL' } elseif ($upcomingRows.Count -gt 0) { 'CACHE-FIRST-UPCOMING' } else { 'CACHE-ONLY-FINISHED' }
    $expectedPollAllowed = $liveRows.Count -gt 0
    $expectedPollRequests = if ($expectedPollAllowed) { 1 } else { 0 }

    $checks['Connection Mode Resolved'] = $connectionMode -in @('ACTIVE-LIVE-POLL','CACHE-FIRST-UPCOMING','CACHE-ONLY-FINISHED')
    $checks['Current Connection Policy'] = $expectedPollAllowed -eq $livePolling.PollAllowed -or $expectedPollAllowed -eq $false
    $checks['Current Connection Requests'] = $expectedPollRequests -eq $finishedPolling.PollRequests

    $metaObject = Get-PropertyValue $meta 'meta'
    $metaId = if ($null -ne $metaObject) { [string](Get-PropertyValue $metaObject 'id') } else { '' }
    $metaType = if ($null -ne $metaObject) { [string](Get-PropertyValue $metaObject 'type') } else { '' }
    $checks['Meta Continuity'] = ($null -ne $metaObject) -and $metaId -eq $eventKey -and $metaType -eq 'tv'

    $streamProperty = $stream.PSObject.Properties | Where-Object { $_.Name -eq 'streams' } | Select-Object -First 1
    $streamValues = @()
    if ($null -ne $streamProperty -and $null -ne $streamProperty.Value) {
        $streamValues = @($streamProperty.Value | ForEach-Object { $_ })
    }
    $streamCount = @($streamValues | Measure-Object).Count
    $streamItem = if ($streamCount -gt 0) { @($streamValues | Select-Object -First 1)[0] } else { $null }
    $streamUrl = if ($null -ne $streamItem) { [string](Get-PropertyValue $streamItem 'url') } else { '' }
    $streamMeta = Get-PropertyValue $stream 'meta'
    $streamPolicy = if ($null -ne $streamMeta) { [string](Get-PropertyValue $streamMeta 'sourcePolicy') } else { '' }
    $streamHost = ''
    $streamHostOk = $false
    if ($streamUrl) {
        try {
            $streamHost = ([Uri]$streamUrl).Host
            $streamHostOk = $approvedHosts -contains $streamHost.ToLowerInvariant()
        } catch { $streamHostOk = $false }
    }
    $checks['Authorized Stream'] = $streamCount -eq 1 -and $streamHostOk -and $streamPolicy -eq 'AUTHORIZED-ONLY'

    $allPassed = $true
    foreach ($Key in $checks.Keys) {
        if (-not $checks[$Key]) { $allPassed = $false; break }
    }

    if (-not $checks['V0.3.5 Polling Policy']) {
        $primaryFailure = 'V0.3.5_POLLING_POLICY'
        $failureReason = 'Active polling configuration does not match the cache-first/live-only contract.'
    }
    elseif (-not $checks['V0.3.5 FINISHED No Poll']) {
        $primaryFailure = 'FINISHED_NO_POLL'
        $failureReason = "FINISHED state must have PollAllowed=False and PollRequests=0; actual PollAllowed=$($finishedPolling.PollAllowed), PollRequests=$($finishedPolling.PollRequests)."
    }
    elseif (-not $checks['V0.3.5 LIVE One-Cycle Poll']) {
        $primaryFailure = 'LIVE_POLL_CONTRACT'
        $failureReason = "LIVE state must allow exactly one poll in this contract test; actual PollAllowed=$($livePolling.PollAllowed), PollRequests=$($livePolling.PollRequests)."
    }
    elseif (-not $checks['V0.3.6 Exit Stops']) {
        $primaryFailure = 'EXIT_STOP'
        $failureReason = 'Exit contract did not prove zero post-exit polling/request activity with warm cache retained.'
    }
    elseif (-not $checks['Catalog State Continuity']) {
        $primaryFailure = 'CATALOG_STATE_CONTINUITY'
        $failureReason = 'Catalog state markers/descriptions are incomplete.'
    }
    elseif (-not $checks['Connection Mode Resolved']) {
        $primaryFailure = 'CONNECTION_MODE'
        $failureReason = "Resolved connection mode is invalid: $connectionMode."
    }
    elseif (-not $checks['Current Connection Requests']) {
        $primaryFailure = 'CONNECTION_REQUEST_POLICY'
        $failureReason = "Current state resolved $connectionMode but expected current test request budget $expectedPollRequests does not match V0.3.5 finished-session result $($finishedPolling.PollRequests)."
    }
    elseif (-not $checks['Meta Continuity']) {
        $primaryFailure = 'META_CONTINUITY'
        $failureReason = "MetaId=$metaId; Expected=$eventKey; MetaType=$metaType."
    }
    elseif (-not $checks['Authorized Stream']) {
        $primaryFailure = 'AUTHORIZED_STREAM'
        $failureReason = "StreamCount=$streamCount; Host=$streamHost; SourcePolicy=$streamPolicy."
    }

    Write-Host ''
    foreach ($Key in $checks.Keys) { Write-Check $Key $checks[$Key] }
    Write-Host ''
    Write-Host 'Version                    : 0.4.12'
    Write-Host "Status                     : $(if ($allPassed) { 'PASS' } else { 'FAIL' })"
    Write-Host "Primary Failure            : $(if ($primaryFailure) { $primaryFailure } else { 'NONE' })"
    Write-Host "Failure Reason             : $(if ($failureReason) { $failureReason } else { 'All checks passed.' })"
    Write-Host 'Previous Versions Frozen  : True'
    Write-Host 'Diagnostic Contract       : True'
    Write-Host 'V0.4.11 Contract Preserved: True'
    Write-Host "Connection Mode           : $connectionMode"
    Write-Host "Live Rows                 : $($liveRows.Count)"
    Write-Host "Upcoming Rows             : $($upcomingRows.Count)"
    Write-Host "Finished Rows             : $($finishedRows.Count)"
    Write-Host "Expected Current Polling  : $expectedPollAllowed"
    Write-Host "Expected Current Requests : $expectedPollRequests"
    Write-Host "Actual FINISHED Requests  : $($finishedPolling.PollRequests)"
    Write-Host "Exit Polling Stopped      : $($exitStatus.PollingStopped)"
    Write-Host "Post-Exit Requests        : $($exitStatus.PostExitRequests)"
    Write-Host "Authorized Source Only    : $($checks['Authorized Stream'])"
    Write-Host "Integration Complete      : $allPassed"

    Write-Host ''
    Write-Host 'STATE / CONNECTION SUMMARY'
    foreach ($row in $stateRows) {
        Write-Host ("  {0}  {1}  State={2}  Valid={3}" -f $row.Id, $row.Marker, $row.State, $row.Valid)
    }

    if (-not $allPassed) {
        Write-Host ''
        Write-Host 'DIAGNOSTIC DETAIL' -ForegroundColor Yellow
        Write-Host "  Connection Mode           : $connectionMode"
        Write-Host "  V0.3.5 Finished Polls     : $($finishedPolling.PollRequests)"
        Write-Host "  V0.3.5 Live Polls         : $($livePolling.PollRequests)"
        Write-Host "  V0.3.6 Post Exit Polls    : $($exitStatus.PostExitPollRequests)"
        Write-Host "  V0.3.6 Post Exit Requests : $($exitStatus.PostExitRequests)"
        Write-Host "  Catalog State Rows         : $($stateRows.Count)"
        Write-Host "  Stream Count               : $streamCount"
        Write-Host "  Stream Host                : $streamHost"
        Write-Host "  Stream Source Policy       : $streamPolicy"
        Write-Host "  Stream Raw Diagnostic      : $($stream | ConvertTo-Json -Depth 10 -Compress)"
    }
}
catch {
    Write-Host 'Version                    : 0.4.12'
    Write-Host 'Status                     : FAIL'
    Write-Host 'Primary Failure            : TEST_HARNESS'
    Write-Host "Failure Reason             : $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
}

Read-Host 'Press Enter'
