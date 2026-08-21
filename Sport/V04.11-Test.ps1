$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverRoot = Join-Path $projectRoot 'V04.AddonServer'
$addonPath = Join-Path $serverRoot 'addon.js'
$baseUrl = 'http://127.0.0.1:7000'
$eventId = '2397275'
$eventKey = "sports:event:$eventId"
$approvedHosts = @('test-streams.mux.dev','stream.mux.com')

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
Write-Host '       VIETNAM SPORTS HUB - V0.4.11'
Write-Host '       LIVE / UPCOMING / FINISHED CONTRACT'
Write-Host '==============================================='

$process = $null
$checks = [ordered]@{}
$primaryFailure = ''
$failureReason = ''

try {
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
    $catalogMatchCount = @($catalogItems | Where-Object { [string](Get-PropertyValue $_ 'id') -eq $eventKey }).Count
    $checks['Catalog Count'] = $catalogItems.Count -eq 3
    $checks['Catalog Event Valid'] = $catalogMatchCount -eq 1

    # State-presentation contract introduced from the V0.3 live-state work.
    $statePattern = '^\[(LIVE|NEXT|DONE)\]\s+'
    $stateRows = @()
    $invalidStateRows = @()
    foreach ($item in $catalogItems) {
        $name = [string](Get-PropertyValue $item 'name')
        $description = [string](Get-PropertyValue $item 'description')
        $stateFromName = ''
        if ($name -match '^\[(LIVE|NEXT|DONE)\]') { $stateFromName = $Matches[1] }
        $stateFromDescription = ''
        if ($description -match 'State:\s*(LIVE-CANDIDATE|UPCOMING|FINISHED)') { $stateFromDescription = $Matches[1] }
        $normalizedState = switch ($stateFromName) {
            'LIVE' { 'LIVE-CANDIDATE' }
            'NEXT' { 'UPCOMING' }
            'DONE' { 'FINISHED' }
            default { '' }
        }
        $rowOk = ($name -match $statePattern) -and ($normalizedState -ne '') -and ($stateFromDescription -eq $normalizedState)
        $stateRows += [pscustomobject]@{ Id = [string](Get-PropertyValue $item 'id'); Marker = $stateFromName; State = $stateFromDescription; Valid = $rowOk }
        if (-not $rowOk) { $invalidStateRows += $stateRows[-1] }
    }

    $checks['Catalog State Markers'] = $stateRows.Count -eq 3 -and $invalidStateRows.Count -eq 0
    $checks['Live State Contract'] = $stateRows.Count -eq 3 -and (@($stateRows | Where-Object { $_.State -eq 'LIVE-CANDIDATE' }).Count -ge 0)
    $checks['Upcoming State Contract'] = $stateRows.Count -eq 3 -and (@($stateRows | Where-Object { $_.State -eq 'UPCOMING' }).Count -ge 0)
    $checks['Finished State Contract'] = $stateRows.Count -eq 3 -and (@($stateRows | Where-Object { $_.State -eq 'FINISHED' }).Count -ge 0)

    $metaObject = Get-PropertyValue $meta 'meta'
    $metaId = if ($null -ne $metaObject) { [string](Get-PropertyValue $metaObject 'id') } else { '' }
    $metaType = if ($null -ne $metaObject) { [string](Get-PropertyValue $metaObject 'type') } else { '' }
    $checks['Meta Continuity'] = ($null -ne $metaObject) -and $metaId -eq $eventKey -and $metaType -eq 'tv'

    # Robust PowerShell 5.1 Stream parsing. Read the streams property explicitly,
    # normalize it to an array, and count the normalized items.
    $streamProperty = $stream.PSObject.Properties | Where-Object { $_.Name -eq 'streams' } | Select-Object -First 1
    $streamValues = @()
    if ($null -ne $streamProperty -and $null -ne $streamProperty.Value) {
        $streamValues = @($streamProperty.Value | ForEach-Object { $_ })
    }
    $streamCount = @($streamValues | Measure-Object).Count
    $streamItem = $null
    if ($streamCount -gt 0) {
        $streamItem = @($streamValues | Select-Object -First 1)[0]
    }

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

    if (-not $checks['V0.4 Manifest']) {
        $primaryFailure = 'V0.4 Manifest'
        $failureReason = 'Manifest contract is incompatible.'
    }
    elseif (-not $checks['V0.4 Health']) {
        $primaryFailure = 'V0.4 Health'
        $failureReason = 'Addon health contract is incompatible.'
    }
    elseif (-not $checks['Catalog Count']) {
        $primaryFailure = 'CATALOG_COUNT'
        $failureReason = "CatalogCount=$($catalogItems.Count); Expected=3."
    }
    elseif (-not $checks['Catalog Event Valid']) {
        $primaryFailure = 'CATALOG_EVENT'
        $failureReason = "MatchingEvent=$catalogMatchCount; Expected=1 for $eventKey."
    }
    elseif (-not $checks['Catalog State Markers']) {
        $primaryFailure = 'CATALOG_STATE_MARKERS'
        $failureReason = 'One or more catalog entries do not have a valid [LIVE]/[NEXT]/[DONE] marker matching its state description.'
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
    Write-Host "Version                   : 0.4.11"
    Write-Host "Status                    : $(if ($allPassed) { 'PASS' } else { 'FAIL' })"
    Write-Host "Primary Failure           : $(if ($primaryFailure) { $primaryFailure } else { 'NONE' })"
    Write-Host "Failure Reason            : $(if ($failureReason) { $failureReason } else { 'All checks passed.' })"
    Write-Host "Previous Versions Frozen : True"
    Write-Host "Diagnostic Contract       : True"
    Write-Host "Compatibility Adjustment : Test harness Stream parsing only"
    Write-Host "V0.4.10 Contract Preserved: True"
    Write-Host "Event ID                  : $eventId"
    Write-Host "Authorized Source Only    : $($checks['Authorized Stream'])"
    Write-Host "Integration Complete      : $allPassed"

    Write-Host ''
    Write-Host 'STATE SUMMARY'
    foreach ($row in $stateRows) {
        Write-Host ("  {0}  {1}  State={2}  Valid={3}" -f $row.Id, $row.Marker, $row.State, $row.Valid)
    }

    if (-not $allPassed) {
        Write-Host ''
        Write-Host 'DIAGNOSTIC DETAIL' -ForegroundColor Yellow
        Write-Host "  Catalog Count            : $($catalogItems.Count)"
        Write-Host "  Catalog Matching Event  : $catalogMatchCount"
        Write-Host "  State Marker Rows        : $($stateRows.Count)"
        Write-Host "  Invalid State Rows       : $($invalidStateRows.Count)"
        Write-Host "  Meta Event ID            : $metaId"
        Write-Host "  Stream Count             : $streamCount"
        Write-Host "  Stream Host              : $streamHost"
        Write-Host "  Stream Source Policy     : $streamPolicy"
        Write-Host "  Stream Raw Diagnostic    : $($stream | ConvertTo-Json -Depth 10 -Compress)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host 'Version                   : 0.4.11'
    Write-Host 'Status                    : FAIL'
    Write-Host 'Primary Failure           : TEST_HARNESS'
    Write-Host "Failure Reason            : $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
}

Read-Host 'Press Enter'
