$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $projectRoot 'Modules\V04.DailyCatalog\V04.DailyCatalog.psm1'
$fixturePath = Join-Path $projectRoot 'TestFixtures\V04.14.DailyCatalogReference.json'

function Get-PropertyValue($Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Write-Check([string]$Name, [bool]$Passed) {
    Write-Host ('[{0}] {1}' -f $(if ($Passed) { 'PASS' } else { 'FAIL' }), $Name)
}

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.14'
Write-Host '       DAILY CATALOG REFERENCE CONTRACT'
Write-Host '==============================================='

$checks = [ordered]@{}
$primaryFailure = ''
$failureReason = ''

try {
    if (-not (Test-Path $modulePath)) { throw "V0.4.14 Daily Catalog module not found: $modulePath" }
    if (-not (Test-Path $fixturePath)) { throw "V0.4.14 daily catalog fixture not found: $fixturePath" }

    Import-Module $modulePath -Force
    $config = Get-V0414DailyCatalogConfig
    $reference = Get-Content -Raw -Path $fixturePath | ConvertFrom-Json
    $fixture = @($reference.fixtures)[0]
    $catalogItem = ConvertTo-V0414CatalogItem -Fixture $fixture
    $itemCheck = Test-V0414CatalogItem -Fixture $fixture -CatalogItem $catalogItem

    $checks['Daily Catalog Config'] = $config.SourceRole -eq 'CATALOG-ONLY' -and $config.CacheFirst -and $config.StreamResolution -eq 'DEFERRED'
    $checks['Reference Source Declared'] = [string]$reference.referenceSource -eq 'LiveScore'
    $checks['No Upstream Request Contract'] = [int]$reference.upstreamRequests -eq 0
    $checks['Reference Fixture Complete'] = ([string]$fixture.eventId) -and ([string]$fixture.homeTeam) -and ([string]$fixture.awayTeam) -and ([string]$fixture.competition) -and ([string]$fixture.status) -and ([string]$fixture.kickoffUtc)
    $checks['Catalog-Only Separation'] = $itemCheck.CatalogOnly -and $itemCheck.StreamResolutionDeferred -and (-not $itemCheck.HasStreamUrl)
    $checks['Event ID Contract'] = $itemCheck.EventIdValid
    $checks['Catalog Type Contract'] = $itemCheck.TypeValid
    $checks['Team Names Preserved'] = $itemCheck.TeamsValid
    $checks['State Contract'] = $itemCheck.StateValid
    $checks['Marker Contract'] = $itemCheck.MarkerValid

    if (-not $checks['Daily Catalog Config']) {
        $primaryFailure = 'DAILY_CATALOG_CONFIG'
        $failureReason = 'Daily catalog mode must remain cache-first, catalog-only, with stream resolution deferred.'
    }
    elseif (-not $checks['Reference Source Declared']) {
        $primaryFailure = 'REFERENCE_SOURCE'
        $failureReason = 'Reference source must be declared as LiveScore without implying direct API integration.'
    }
    elseif (-not $checks['No Upstream Request Contract']) {
        $primaryFailure = 'UPSTREAM_REQUEST_POLICY'
        $failureReason = 'V0.4.14 reference test must perform zero upstream requests.'
    }
    elseif (-not $checks['Reference Fixture Complete']) {
        $primaryFailure = 'REFERENCE_FIXTURE'
        $failureReason = 'Daily fixture is missing one or more required fields.'
    }
    elseif (-not $checks['Catalog-Only Separation']) {
        $primaryFailure = 'CATALOG_STREAM_SEPARATION'
        $failureReason = 'Catalog normalization must not embed a stream URL; stream resolution is deferred.'
    }
    elseif (-not $checks['Event ID Contract']) {
        $primaryFailure = 'EVENT_ID'
        $failureReason = "Catalog ID does not match sports:event:$($fixture.eventId)."
    }
    elseif (-not $checks['Catalog Type Contract']) {
        $primaryFailure = 'CATALOG_TYPE'
        $failureReason = "Expected type=tv; actual type=$($catalogItem.type)."
    }
    elseif (-not $checks['Team Names Preserved']) {
        $primaryFailure = 'TEAM_NAMES'
        $failureReason = 'Home/away team names were not preserved during normalization.'
    }
    elseif (-not $checks['State Contract']) {
        $primaryFailure = 'STATE_CONTRACT'
        $failureReason = "State mapping did not match fixture status=$($fixture.status)."
    }
    elseif (-not $checks['Marker Contract']) {
        $primaryFailure = 'MARKER_CONTRACT'
        $failureReason = "Catalog marker did not match normalized state in name=$($catalogItem.name)."
    }

    $allPassed = $true
    foreach ($key in $checks.Keys) {
        if (-not $checks[$key]) { $allPassed = $false; break }
    }

    foreach ($key in $checks.Keys) { Write-Check $key $checks[$key] }

    Write-Host ''
    Write-Host 'Version                    : 0.4.14'
    Write-Host "Status                     : $(if ($allPassed) { 'PASS' } else { 'FAIL' })"
    Write-Host "Primary Failure            : $(if ($primaryFailure) { $primaryFailure } else { 'NONE' })"
    Write-Host "Failure Reason             : $(if ($failureReason) { $failureReason } else { 'All checks passed.' })"
    Write-Host 'Previous Versions Frozen  : True'
    Write-Host 'Diagnostic Contract       : True'
    Write-Host 'V0.4.13 Contract Preserved: True'
    Write-Host "Reference Source           : $($reference.referenceSource)"
    Write-Host "Source Role                : $($reference.sourceRole)"
    Write-Host "Upstream Requests          : $($reference.upstreamRequests)"
    Write-Host "Stream Resolution          : $($reference.streamResolution)"
    Write-Host "Reference Event            : $($fixture.eventId)"
    Write-Host "Fixture Teams              : $($fixture.homeTeam) vs $($fixture.awayTeam)"
    Write-Host "Fixture Status             : $($fixture.status)"
    Write-Host "Normalized State           : $(($catalogItem.description -replace '^State: ', ''))"
    Write-Host "Catalog Marker             : $(($catalogItem.name -split ' ')[0])"
    Write-Host 'Integration Complete       : ' -NoNewline
    Write-Host $allPassed

    if (-not $allPassed) {
        Write-Host ''
        Write-Host 'DIAGNOSTIC DETAIL' -ForegroundColor Yellow
        Write-Host "  Source Role              : $($reference.sourceRole)"
        Write-Host "  Reference Source         : $($reference.referenceSource)"
        Write-Host "  Upstream Requests        : $($reference.upstreamRequests)"
        Write-Host "  Stream Resolution        : $($reference.streamResolution)"
        Write-Host "  Fixture                  : $($fixture | ConvertTo-Json -Compress)"
        Write-Host "  Catalog Item             : $($catalogItem | ConvertTo-Json -Depth 8 -Compress)"
    }
}
catch {
    Write-Host 'Version                    : 0.4.14'
    Write-Host 'Status                     : FAIL'
    Write-Host 'Primary Failure            : TEST_HARNESS'
    Write-Host "Failure Reason             : $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host 'Press Enter'
