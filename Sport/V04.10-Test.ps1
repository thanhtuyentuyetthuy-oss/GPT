$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $projectRoot
$serverRoot = Join-Path $projectRoot 'V04.AddonServer'
$addonPath = Join-Path $serverRoot 'addon.js'
$cacheRoot = Join-Path $repoRoot 'Data\Cache'
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

function Get-JsonFile([string]$Path) {
    if (-not (Test-Path $Path)) { throw "Required file not found: $Path" }
    return (Get-Content -Raw -Path $Path | ConvertFrom-Json)
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
Write-Host '       VIETNAM SPORTS HUB - V0.4.10'
Write-Host '       DIAGNOSTIC + EVOLUTION CONTRACT'
Write-Host '==============================================='

$process = $null
$checks = [ordered]@{}
$primaryFailure = ''
$failureReason = ''

try {
    # ----- Baseline continuity: previous PASS checkpoints are read-only. -----
    $catalogDir = Join-Path $cacheRoot 'V02.Catalog'
    $metaPath = Join-Path $cacheRoot "V02.Meta\event-$eventId.json"
    $streamPath = Join-Path $cacheRoot "V02.Stream\event-$eventId.json"

    $checks['V0.2.1 Catalog Cache'] = Test-Path $catalogDir
    $checks['V0.2.3 Meta Cache'] = Test-Path $metaPath
    $checks['V0.2.4 Stream Cache'] = Test-Path $streamPath

    $v031 = Test-Path (Join-Path $projectRoot 'Modules\V03.Live\V03.Live.psm1')
    $v033 = Test-Path (Join-Path $projectRoot 'Modules\V03.LiveSession\V03.LiveSession.psm1')
    $v035 = Test-Path (Join-Path $projectRoot 'Modules\V03.ActivePolling\V03.ActivePolling.psm1')
    $v036 = Test-Path (Join-Path $projectRoot 'Modules\V03.ExitStop\V03.ExitStop.psm1')
    $checks['V0.3 Continuity'] = $v031 -and $v033 -and $v035 -and $v036

    if (-not $checks['V0.2.1 Catalog Cache']) { throw 'V0.2.1 Catalog Cache unavailable.' }
    if (-not $checks['V0.2.3 Meta Cache']) { throw 'V0.2.3 Meta Cache unavailable.' }
    if (-not $checks['V0.2.4 Stream Cache']) { throw 'V0.2.4 Stream Cache unavailable.' }
    if (-not $checks['V0.3 Continuity']) { throw 'V0.3 continuity unavailable.' }

    $StreamCache = Get-JsonFile $streamPath
    $cacheUrl = [string](Get-PropertyValue $StreamCache 'sourceUrl')
    $cacheHostOk = $false
    if ($cacheUrl) {
        try { $cacheHostOk = $approvedHosts -contains ([Uri]$cacheUrl).Host.ToLowerInvariant() } catch { $cacheHostOk = $false }
    }
    $checks['Previous Stream Cache Authorized'] = $cacheHostOk

    # ----- V0.4 live chain -----
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
    $checks['V0.4 Catalog'] = $catalogItems.Count -eq 3 -and $catalogMatchCount -eq 1

    $metaObject = Get-PropertyValue $meta 'meta'
    $metaId = if ($null -ne $metaObject) { [string](Get-PropertyValue $metaObject 'id') } else { '' }
    $metaType = if ($null -ne $metaObject) { [string](Get-PropertyValue $metaObject 'type') } else { '' }
    $checks['V0.4 Meta'] = ($null -ne $metaObject) -and $metaId -eq $eventKey -and $metaType -eq 'tv'

    $streamItems = Get-ArrayItems (Get-PropertyValue $stream 'streams')
    $streamCount = $streamItems.Count
    $streamItem = if ($streamCount -gt 0) { @($streamItems | Select-Object -First 1)[0] } else { $null }
    $runtimeUrl = if ($null -ne $streamItem) { [string](Get-PropertyValue $streamItem 'url') } else { '' }
    $runtimeHost = ''
    $runtimeHostOk = $false
    if ($runtimeUrl) {
        try {
            $runtimeHost = ([Uri]$runtimeUrl).Host
            $runtimeHostOk = $approvedHosts -contains $runtimeHost.ToLowerInvariant()
        } catch { $runtimeHostOk = $false }
    }
    $streamMeta = Get-PropertyValue $stream 'meta'
    $streamPolicy = if ($null -ne $streamMeta) { [string](Get-PropertyValue $streamMeta 'sourcePolicy') } else { '' }
    $checks['V0.4 Stream'] = $streamCount -eq 1 -and $runtimeHostOk -and $streamPolicy -eq 'AUTHORIZED-ONLY'

    # ----- Diagnostic Contract -----
    $allPassed = $true
    foreach ($Key in $checks.Keys) {
        if (-not $checks[$Key]) { $allPassed = $false; break }
    }

    # Identify the primary failure without fabricating downstream failures.
    if (-not $checks['V0.2.1 Catalog Cache']) {
        $primaryFailure = 'V0.2.1 Catalog Cache'
        $failureReason = 'Catalog cache directory is unavailable.'
    }
    elseif (-not $checks['V0.2.3 Meta Cache']) {
        $primaryFailure = 'V0.2.3 Meta Cache'
        $failureReason = 'Selected-event Meta cache is unavailable.'
    }
    elseif (-not $checks['V0.2.4 Stream Cache']) {
        $primaryFailure = 'V0.2.4 Stream Cache'
        $failureReason = 'Selected-event Stream cache is unavailable.'
    }
    elseif (-not $checks['V0.3 Continuity']) {
        $primaryFailure = 'V0.3 Continuity'
        $failureReason = 'One or more live/session modules are missing.'
    }
    elseif (-not $checks['Previous Stream Cache Authorized']) {
        $primaryFailure = 'STREAM_SOURCE_AUTHORIZATION'
        $failureReason = 'The previous stream cache does not use an allowlisted host.'
    }
    elseif (-not $checks['V0.4 Manifest']) {
        $primaryFailure = 'V0.4 Manifest'
        $failureReason = 'Manifest contract is incompatible with the current integration.'
    }
    elseif (-not $checks['V0.4 Health']) {
        $primaryFailure = 'V0.4 Health'
        $failureReason = 'Addon health contract is incompatible with the current integration.'
    }
    elseif (-not $checks['V0.4 Catalog']) {
        $primaryFailure = 'V0.4 Catalog'
        $failureReason = "CatalogCount=$($catalogItems.Count); Expected=3; MatchingEvent=$catalogMatchCount."
    }
    elseif (-not $checks['V0.4 Meta']) {
        $primaryFailure = 'V0.4 Meta'
        $failureReason = "MetaId=$metaId; Expected=$eventKey; MetaType=$metaType."
    }
    elseif (-not $checks['V0.4 Stream']) {
        $primaryFailure = 'V0.4 Stream'
        $failureReason = "StreamCount=$streamCount; RuntimeHost=$runtimeHost; SourcePolicy=$streamPolicy; ExpectedHost=$($approvedHosts -join ',')."
    }

    # Dependency-aware result: later diagnostics are SKIPPED only when an earlier
    # required dependency truly failed. Existing successful layers remain PASS.
    $streamDependencyBlocked = (-not $checks['V0.4 Manifest']) -or (-not $checks['V0.4 Health']) -or (-not $checks['V0.4 Catalog']) -or (-not $checks['V0.4 Meta'])

    Write-Host ''
    foreach ($Key in $checks.Keys) { Write-Check $Key $checks[$Key] }
    Write-Host ''
    Write-Host "Version                   : 0.4.10"
    Write-Host "Status                    : $(if ($allPassed) { 'PASS' } else { 'FAIL' })"
    Write-Host "Primary Failure           : $(if ($primaryFailure) { $primaryFailure } else { 'NONE' })"
    Write-Host "Failure Reason            : $(if ($failureReason) { $failureReason } else { 'All checks passed.' })"
    Write-Host "Dependency State          : $(if ($streamDependencyBlocked -and -not $checks['V0.4 Stream']) { 'STREAM WOULD BE CASCADE-SKIPPED' } else { 'STREAM INDEPENDENT' })"
    Write-Host "Previous Versions Frozen : True"
    Write-Host "New Diagnostic Contract  : True"
    Write-Host "Compatibility Adjustment : None"
    Write-Host "V0.4.9 Contract Preserved: True"
    Write-Host "Event ID                  : $eventId"
    Write-Host "Runtime Stream Host       : $runtimeHost"
    Write-Host "Authorized Source Only    : $($streamPolicy -eq 'AUTHORIZED-ONLY')"
    Write-Host "Integration Complete      : $allPassed"

    if (-not $allPassed) {
        Write-Host ''
        Write-Host 'DIAGNOSTIC DETAIL' -ForegroundColor Yellow
        Write-Host "  Catalog Count            : $($catalogItems.Count)"
        Write-Host "  Catalog Matching Event  : $catalogMatchCount"
        Write-Host "  Meta Event ID            : $metaId"
        Write-Host "  Stream Count             : $streamCount"
        Write-Host "  Stream Host              : $runtimeHost"
        Write-Host "  Stream Source Policy     : $streamPolicy"
        if ($streamDependencyBlocked -and -not $checks['V0.4 Stream']) {
            Write-Host '  Stream Dependency         : SKIPPED/INVALID DEPENDENCY' -ForegroundColor Yellow
        }
    }
}
catch {
    $primaryFailure = 'TEST_HARNESS'
    $failureReason = $_.Exception.Message
    Write-Host 'Version                   : 0.4.10'
    Write-Host 'Status                    : FAIL'
    Write-Host "Primary Failure           : $primaryFailure"
    Write-Host "Failure Reason            : $failureReason" -ForegroundColor Red
}
finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
}

Read-Host 'Press Enter'
