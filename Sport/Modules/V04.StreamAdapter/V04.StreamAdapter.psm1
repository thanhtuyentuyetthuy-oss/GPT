Set-StrictMode -Version Latest
$script:Version = '0.4.5'
$script:SportRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:RepoRoot = Split-Path $script:SportRoot -Parent
$script:CacheRoot = Join-Path $script:RepoRoot 'Data\Cache\V02.Stream'

function Get-V045StreamCachePath {
    param([Parameter(Mandatory)][string]$EventId)
    $safeId = $EventId -replace '[^0-9A-Za-z_.-]', '_'
    $path = Join-Path $script:CacheRoot ("event-{0}.json" -f $safeId)
    if (Test-Path $path) { return $path }
    return $null
}

function ConvertTo-StremioStreams {
    param([Parameter(Mandatory)]$Payload,[Parameter(Mandatory)][string]$EventId)
    $sourceUrl = if ($Payload.PSObject.Properties['sourceUrl']) { [string]$Payload.sourceUrl } else { '' }
    if ([string]::IsNullOrWhiteSpace($sourceUrl)) { throw "Stream cache contains no sourceUrl for event $EventId." }
    $uri = [Uri]$sourceUrl
    if (-not $uri.IsAbsoluteUri -or -not ($uri.Scheme -in @('http','https'))) { throw 'Cached sourceUrl must be an absolute HTTP(S) URL.' }
    [PSCustomObject]@{
        streams = @([PSCustomObject]@{
            name = 'Authorized public source'
            title = 'Public / authorized source'
            url = $sourceUrl
            behaviorHints = [PSCustomObject]@{ bingeGroup = 'v045-authorized-public' }
        })
        cacheMaxAge = if ($Payload.PSObject.Properties['ttlSeconds']) { [int]$Payload.ttlSeconds } else { 120 }
        meta = [PSCustomObject]@{ id = "sports:event:$EventId"; sourcePolicy = 'AUTHORIZED-ONLY' }
    }
}

function Test-V045StreamAdapter {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$EventId)
    try {
        $cache = Get-V045StreamCachePath -EventId $EventId
        if (-not $cache) { throw "V0.2.4 stream cache not found for event $EventId. Run the V0.2.4 Stream cache test first." }
        $payload = Get-Content -Path $cache -Raw -Encoding UTF8 | ConvertFrom-Json
        $result = ConvertTo-StremioStreams -Payload $payload -EventId $EventId
        $valid = @($result.streams).Count -gt 0 -and $result.streams[0].url -match '^https?://'
        [PSCustomObject]@{
            Version = $script:Version
            Status = if ($valid) { 'PASS' } else { 'FAIL' }
            Source = 'V0.2.4 STREAM CACHE ONLY'
            EventId = $EventId
            'Stream Cache Read' = $true
            'Resolver Requests' = 0
            'Stream Loaded' = $valid
            'Authorized Source Only' = ($payload.sourcePolicy -eq 'AUTHORIZED-ONLY')
            'Stremio Stream Valid' = $valid
            'Stream Cache Path' = $cache
            'Stremio Streams' = $result
            Error = $null
        }
    }
    catch {
        [PSCustomObject]@{
            Version = $script:Version
            Status = 'FAIL'
            Source = 'V0.2.4 STREAM CACHE ONLY'
            EventId = $EventId
            'Stream Cache Read' = $false
            'Resolver Requests' = 0
            'Stream Loaded' = $false
            'Authorized Source Only' = $false
            'Stremio Stream Valid' = $false
            'Stream Cache Path' = $null
            'Stremio Streams' = $null
            Error = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Test-V045StreamAdapter,ConvertTo-StremioStreams