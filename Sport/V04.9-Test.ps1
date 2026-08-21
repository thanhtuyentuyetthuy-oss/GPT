$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $projectRoot
$serverRoot = Join-Path $projectRoot 'V04.AddonServer'
$addonPath = Join-Path $serverRoot 'addon.js'
$cacheRoot = Join-Path $repoRoot 'Data\Cache'
$baseUrl = 'http://127.0.0.1:7000'
$eventId = '2397275'
$approvedHosts = @('test-streams.mux.dev','stream.mux.com')

function Read-JsonFile([string]$path) {
    if (-not (Test-Path $path)) { throw "Required cache/file not found: $path" }
    return (Get-Content -Raw -Path $path | ConvertFrom-Json)
}

function Get-JsonResponse([string]$uri) {
    $response = Invoke-WebRequest -Uri $uri -Method Get -UseBasicParsing
    return ($response.Content | ConvertFrom-Json)
}

function Get-PropertyValue($object, [string]$name) {
    if ($null -eq $object) { return $null }
    $property = $object.PSObject.Properties | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-JsonArrayItems($value) {
    if ($null -eq $value) { return @() }
    return @($value | ForEach-Object { $_ })
}

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.9'
Write-Host '       CROSS-VERSION REGRESSION CHECK'
Write-Host '==============================================='

$process = $null
try {
    # V0.2.x continuity: catalog/meta/stream caches must still exist.
    $catalogDir = Join-Path $cacheRoot 'V02.Catalog'
    $metaPath = Join-Path $cacheRoot "V02.Meta\event-$eventId.json"
    $streamPath = Join-Path $cacheRoot "V02.Stream\event-$eventId.json"

    if (-not (Test-Path $catalogDir)) { throw "V0.2.1 catalog cache directory not found: $catalogDir" }
    $catalogFiles = @(Get-ChildItem -Path $catalogDir -Filter 'catalog-*.json' -File)
    if ($catalogFiles.Count -eq 0) { throw "No V0.2.1 catalog cache file found in $catalogDir" }

    $metaCache = Read-JsonFile $metaPath
    $streamCache = Read-JsonFile $streamPath

    $cacheCatalogOk = $catalogFiles.Count -gt 0
    $cacheMetaOk = ([string]$metaCache.eventId -eq $eventId) -and ($null -ne $metaCache.event)
    $cacheStreamUrl = [string]$streamCache.sourceUrl
    $cacheStreamUri = $null
    $cacheStreamHostOk = $false
    if ($cacheStreamUrl) {
        try {
            $cacheStreamUri = [Uri]$cacheStreamUrl
            $cacheStreamHostOk = $approvedHosts -contains $cacheStreamUri.Host.ToLowerInvariant()
        }
        catch { $cacheStreamHostOk = $false }
    }
    $cacheStreamOk = ([string]$streamCache.eventId -eq $eventId) -and $cacheStreamHostOk

    # V0.3.x continuity: session/live/exit modules must remain present.
    $v031 = Test-Path (Join-Path $projectRoot 'Modules\V03.Live\V03.Live.psm1')
    $v033 = Test-Path (Join-Path $projectRoot 'Modules\V03.LiveSession\V03.LiveSession.psm1')
    $v035 = Test-Path (Join-Path $projectRoot 'Modules\V03.ActivePolling\V03.ActivePolling.psm1')
    $v036 = Test-Path (Join-Path $projectRoot 'Modules\V03.ExitStop\V03.ExitStop.psm1')
    $v03Continuity = $v031 -and $v033 -and $v035 -and $v036

    # V0.4.x end-to-end contract: addon must still expose the same integrated chain.
    $process = Start-Process -FilePath 'node' -ArgumentList @($addonPath) -WorkingDirectory $serverRoot -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 800

    $manifest = Get-JsonResponse "$baseUrl/manifest.json"
    $health = Get-JsonResponse "$baseUrl/health"
    $catalog = Get-JsonResponse "$baseUrl/catalog/tv/vietnam-sports.json"
    $meta = Get-JsonResponse "$baseUrl/meta/tv/sports:event:$eventId.json"
    $stream = Get-JsonResponse "$baseUrl/stream/tv/sports:event:$eventId.json"

    $catalogMetas = Get-PropertyValue $catalog 'metas'
    $catalogItems = Get-JsonArrayItems $catalogMetas

    # Read Stream properties explicitly to avoid Windows PowerShell 5.1
    # enumeration quirks with JSON arrays.
    $streamValues = Get-JsonArrayItems (Get-PropertyValue $stream 'streams')
    $streamCount = @($streamValues | Measure-Object).Count
    $streamItem = if ($streamCount -gt 0) { @($streamValues | Select-Object -First 1)[0] } else { $null }
    $streamUrl = if ($null -ne $streamItem) { [string](Get-PropertyValue $streamItem 'url') } else { '' }
    $streamMeta = Get-PropertyValue $stream 'meta'
    $streamPolicy = if ($null -ne $streamMeta) { [string](Get-PropertyValue $streamMeta 'sourcePolicy') } else { '' }

    $runtimeStreamHostOk = $false
    $runtimeStreamUri = $null
    if ($streamUrl) {
        try {
            $runtimeStreamUri = [Uri]$streamUrl
            $runtimeStreamHostOk = $approvedHosts -contains $runtimeStreamUri.Host.ToLowerInvariant()
        }
        catch { $runtimeStreamHostOk = $false }
    }

    $manifestResources = Get-JsonArrayItems (Get-PropertyValue $manifest 'resources')
    $manifestId = [string](Get-PropertyValue $manifest 'id')
    $manifestOk = $manifestId -eq 'org.vietnam.sports.hub' -and ($manifestResources -contains 'catalog') -and ($manifestResources -contains 'meta') -and ($manifestResources -contains 'stream')
    $healthStatus = [string](Get-PropertyValue $health 'status')
    $healthSourcePolicy = [string](Get-PropertyValue $health 'sourcePolicy')
    $healthOk = $healthStatus -eq 'OK' -and $healthSourcePolicy -eq 'AUTHORIZED-ONLY'
    $catalogOk = $catalogItems.Count -eq 3 -and (@($catalogItems | Where-Object { [string](Get-PropertyValue $_ 'id') -eq "sports:event:$eventId" }).Count -eq 1)
    $metaObject = Get-PropertyValue $meta 'meta'
    $metaId = if ($null -ne $metaObject) { [string](Get-PropertyValue $metaObject 'id') } else { '' }
    $metaType = if ($null -ne $metaObject) { [string](Get-PropertyValue $metaObject 'type') } else { '' }
    $metaOk = ($null -ne $metaObject) -and $metaId -eq "sports:event:$eventId" -and $metaType -eq 'tv'
    $runtimeStreamOk = $streamCount -eq 1 -and $runtimeStreamHostOk -and $streamPolicy -eq 'AUTHORIZED-ONLY'

    $overallPass = $cacheCatalogOk -and $cacheMetaOk -and $cacheStreamOk -and $v03Continuity -and $manifestOk -and $healthOk -and $catalogOk -and $metaOk -and $runtimeStreamOk

    Write-Host "Version                   : 0.4.9"
    Write-Host "Status                    : $(if ($overallPass) { 'PASS' } else { 'FAIL' })"
    Write-Host "V0.2.1 Catalog Cache      : $cacheCatalogOk"
    Write-Host "V0.2.3 Meta Cache         : $cacheMetaOk"
    Write-Host "V0.2.4 Stream Cache       : $cacheStreamOk"
    Write-Host "V0.3.1 Live Module        : $v031"
    Write-Host "V0.3.3 Live Session       : $v033"
    Write-Host "V0.3.5 Active Polling     : $v035"
    Write-Host "V0.3.6 Exit/Stop          : $v036"
    Write-Host "V0.3 Continuity           : $v03Continuity"
    Write-Host "V0.4 Manifest             : $manifestOk"
    Write-Host "V0.4 Health               : $healthOk"
    Write-Host "V0.4 Catalog              : $catalogOk"
    Write-Host "V0.4 Meta                 : $metaOk"
    Write-Host "V0.4 Stream               : $runtimeStreamOk"
    Write-Host "Runtime Stream Host       : $(if ($runtimeStreamUri) { $runtimeStreamUri.Host } else { '' })"
    Write-Host "Authorized Source Only    : $($streamPolicy -eq 'AUTHORIZED-ONLY')"
    Write-Host "Event ID                  : $eventId"
    Write-Host "Cross-Version Integration : $overallPass"
    if (-not $runtimeStreamOk) {
        Write-Host "V0.4 Diagnostic           : CatalogCount=$($catalogItems.Count); StreamCount=$streamCount; StreamHost=$(if ($runtimeStreamUri) { $runtimeStreamUri.Host } else { '' }); SourcePolicy=$streamPolicy" -ForegroundColor Yellow
        Write-Host "Stream Diagnostic         : $($stream | ConvertTo-Json -Depth 10 -Compress)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host 'Version                   : 0.4.9'
    Write-Host 'Status                    : FAIL'
    Write-Host "Error                     : $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
}

Read-Host 'Press Enter'
