$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverRoot = Join-Path $projectRoot 'V04.AddonServer'
$addonPath = Join-Path $serverRoot 'addon.js'
$baseUrl = 'http://127.0.0.1:7000'
$eventId = '2397275'
$expectedMetaId = "sports:event:$eventId"
$expectedCatalogId = "sports:event:$eventId"
$approvedHosts = @('test-streams.mux.dev','stream.mux.com')

function Get-JsonResponse([string]$uri) {
    $response = Invoke-WebRequest -Uri $uri -Method Get -UseBasicParsing
    return ($response.Content | ConvertFrom-Json)
}

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.8'
Write-Host '       STREMIO END-TO-END VERIFICATION'
Write-Host '==============================================='

$process = $null
try {
    $process = Start-Process -FilePath 'node' -ArgumentList @($addonPath) -WorkingDirectory $serverRoot -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 800

    $manifest = Get-JsonResponse "$baseUrl/manifest.json"
    $health = Get-JsonResponse "$baseUrl/health"
    $catalog = Get-JsonResponse "$baseUrl/catalog/tv/vietnam-sports.json"
    $meta = Get-JsonResponse "$baseUrl/meta/tv/$expectedMetaId.json"
    $stream = Get-JsonResponse "$baseUrl/stream/tv/$expectedMetaId.json"

    $resourcesValid = @('catalog','meta','stream') | ForEach-Object { $manifest.resources -contains $_ } | Where-Object { -not $_ } | Measure-Object | Select-Object -ExpandProperty Count
    $typesValid = $manifest.types -contains 'tv'
    $prefixValid = $manifest.idPrefixes -contains 'sports:event:'
    $catalogValid = $manifest.catalogs | Where-Object { $_.type -eq 'tv' -and $_.id -eq 'vietnam-sports' } | Measure-Object | Select-Object -ExpandProperty Count

    $catalogItems = if ($null -ne $catalog.metas) { @($catalog.metas) } else { @() }
    $catalogCount = $catalogItems.Count
    $catalogEvent = $catalogItems | Where-Object { $_.id -eq $expectedCatalogId } | Select-Object -First 1
    $catalogEventValid = $null -ne $catalogEvent

    $metaIdValid = $null -ne $meta.meta -and $meta.meta.id -eq $expectedMetaId -and $meta.meta.type -eq 'tv'
    $metaNameValid = $null -ne $meta.meta -and -not [string]::IsNullOrWhiteSpace([string]$meta.meta.name)

    $streams = if ($null -ne $stream.streams) { @($stream.streams) } else { @() }
    $streamCount = $streams.Count
    $streamUrl = if ($streamCount -gt 0 -and $null -ne $streams[0].url) { [string]$streams[0].url } else { '' }
    $streamUri = $null
    $streamHostValid = $false
    if ($streamUrl) {
        try {
            $streamUri = [Uri]$streamUrl
            $streamHostValid = $approvedHosts -contains $streamUri.Host.ToLowerInvariant()
        }
        catch { $streamHostValid = $false }
    }
    $streamPolicyValid = $null -ne $stream.meta -and [string]$stream.meta.sourcePolicy -eq 'AUTHORIZED-ONLY'
    $streamValid = $streamCount -eq 1 -and $streamHostValid -and $streamPolicyValid

    $healthValid = $health.status -eq 'OK' -and $health.version -eq '0.4.7' -and $health.sourcePolicy -eq 'AUTHORIZED-ONLY'
    $manifestValid = $manifest.id -eq 'org.vietnam.sports.hub' -and $manifest.name -eq 'Vietnam Sports Hub' -and $resourcesValid -eq 0 -and $typesValid -and $prefixValid -and $catalogValid -gt 0
    $overallPass = $healthValid -and $manifestValid -and $catalogCount -eq 3 -and $catalogEventValid -and $metaIdValid -and $metaNameValid -and $streamValid

    Write-Host "Version                 : 0.4.8"
    Write-Host "Status                  : $(if ($overallPass) { 'PASS' } else { 'FAIL' })"
    Write-Host "Server Started          : $($process.HasExited -eq $false)"
    Write-Host "Health                  : $healthValid"
    Write-Host "Manifest                : $manifestValid"
    Write-Host "Catalog Endpoint        : True"
    Write-Host "Catalog Count            : $catalogCount"
    Write-Host "Catalog Event ID        : $(if ($catalogEvent) { $catalogEvent.id } else { '' })"
    Write-Host "Catalog Event Valid     : $catalogEventValid"
    Write-Host "Meta Endpoint           : True"
    Write-Host "Meta Event ID           : $(if ($meta.meta) { $meta.meta.id } else { '' })"
    Write-Host "Meta Valid              : $($metaIdValid -and $metaNameValid)"
    Write-Host "Stream Endpoint         : True"
    Write-Host "Stream Count            : $streamCount"
    Write-Host "Stream Host             : $(if ($streamUri) { $streamUri.Host } else { '' })"
    Write-Host "Authorized Source Only  : $streamPolicyValid"
    Write-Host "Stream Valid            : $streamValid"
    Write-Host "Integration Complete    : $overallPass"
    if (-not $streamValid) {
        Write-Host "Stream Diagnostic       : $($stream | ConvertTo-Json -Depth 10 -Compress)" -ForegroundColor Yellow
    }
    Write-Host "Base URL                : $baseUrl"
    Write-Host "Manifest URL            : $baseUrl/manifest.json"
}
catch {
    Write-Host 'Version                 : 0.4.8'
    Write-Host 'Status                  : FAIL'
    Write-Host "Error                   : $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
}

Read-Host 'Press Enter'
