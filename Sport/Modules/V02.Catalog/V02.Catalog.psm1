# Vietnam Sports Hub - V0.2.1 Catalog module

Set-StrictMode -Version Latest

$script:ModuleVersion = '0.2.1'
$script:ModuleName = 'V02.Catalog'
$script:TimeZoneId = 'Asia/Ho_Chi_Minh'
$script:WindowsTimeZoneId = 'SE Asia Standard Time'
$script:ApiBase = 'https://www.thesportsdb.com/api/v1/json/123'
$script:CacheRoot = Join-Path $PSScriptRoot '..\..\..\Data\Cache\V02.Catalog'

function Ensure-V02CacheDirectory {
    if (-not (Test-Path $script:CacheRoot)) {
        New-Item -ItemType Directory -Force -Path $script:CacheRoot | Out-Null
    }
}

function Get-V02TimeZone {
    [CmdletBinding()]
    param()

    # Windows PowerShell on Windows uses Windows time-zone IDs; .NET 6+ on
    # some platforms can use IANA IDs. Prefer the requested IANA ID when it
    # exists, then fall back to the Windows equivalent for compatibility.
    try {
        return [TimeZoneInfo]::FindSystemTimeZoneById($script:TimeZoneId)
    } catch {
        return [TimeZoneInfo]::FindSystemTimeZoneById($script:WindowsTimeZoneId)
    }
}

function Get-V02VietnamNow {
    $tz = Get-V02TimeZone
    [TimeZoneInfo]::ConvertTimeFromUtc([datetime]::UtcNow, $tz)
}

function Get-V02CachePath {
    param([Parameter(Mandatory)][datetime]$Date)
    Ensure-V02CacheDirectory
    Join-Path $script:CacheRoot ("catalog-{0:yyyy-MM-dd}.json" -f $Date)
}

function ConvertTo-V02Preview {
    param([Parameter(Mandatory)]$Event)

    $kickoffUtc = $null
    foreach ($candidate in @($Event.strTimestamp, "$($Event.dateEvent) $($Event.strTime)")) {
        if (-not $candidate) { continue }
        try {
            $kickoffUtc = ([datetime]::Parse([string]$candidate)).ToUniversalTime().ToString('o')
            break
        } catch {}
    }

    $descriptionParts = @()
    if ($Event.strLeague) { $descriptionParts += [string]$Event.strLeague }
    if ($Event.strStatus) { $descriptionParts += [string]$Event.strStatus }
    $description = $descriptionParts -join ' • '

    [PSCustomObject]@{
        id = "sports:event:$($Event.idEvent)"
        type = 'channel'
        name = if ($Event.strEvent) { [string]$Event.strEvent } else { 'Unknown Match' }
        poster = if ($Event.strThumb) { [string]$Event.strThumb } elseif ($Event.strPoster) { [string]$Event.strPoster } else { $null }
        description = $description
        genres = @('FOOTBALL')
        releaseInfo = [string]$Event.dateEvent
        behaviorHints = @{ defaultVideoId = "sports:event:$($Event.idEvent)" }
        event = [PSCustomObject]@{
            eventId = [string]$Event.idEvent
            leagueId = [string]$Event.idLeague
            league = [string]$Event.strLeague
            homeTeam = [string]$Event.strHomeTeam
            awayTeam = [string]$Event.strAwayTeam
            kickoffUtc = $kickoffUtc
            status = [string]$Event.strStatus
        }
    }
}

function Invoke-V02Api {
    param([Parameter(Mandatory)][datetime]$Date)

    $dateText = $Date.ToString('yyyy-MM-dd')
    $uri = "$($script:ApiBase)/eventsday.php?d=$dateText&s=Soccer"
    Write-Host "[V0.2.1][API] GET $uri"
    Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 20
}

function Get-V02DailyCatalog {
    [CmdletBinding()]
    param(
        [datetime]$Date = (Get-V02VietnamNow).Date,
        [switch]$Refresh
    )

    Ensure-V02CacheDirectory
    $cachePath = Get-V02CachePath -Date $Date

    if ((Test-Path $cachePath) -and -not $Refresh) {
        try {
            $cached = Get-Content -Path $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json
            Write-Host "[V0.2.1][CACHE HIT] $($Date.ToString('yyyy-MM-dd'))"
            return $cached
        } catch {
            Write-Host "[V0.2.1][CACHE INVALID] Rebuilding cache." -ForegroundColor Yellow
        }
    }

    $response = Invoke-V02Api -Date $Date
    $events = @($response.events)
    $previews = @($events | ForEach-Object { ConvertTo-V02Preview -Event $_ })

    $payload = [PSCustomObject]@{
        version = $script:ModuleVersion
        generatedAtUtc = [datetime]::UtcNow.ToString('o')
        localDate = $Date.ToString('yyyy-MM-dd')
        timeZone = $script:TimeZoneId
        count = $previews.Count
        metas = $previews
    }

    $payload | ConvertTo-Json -Depth 12 | Set-Content -Path $cachePath -Encoding UTF8
    Write-Host "[V0.2.1][CACHE WRITE] $($previews.Count) events"
    $payload
}

function Test-V02CatalogIntegration {
    [CmdletBinding()]
    param([switch]$Refresh)

    $status = [ordered]@{
        Version = $script:ModuleVersion
        Status = 'FAIL'
        ModuleLoaded = $true
        CacheFirst = $true
        PreviewOnly = $true
        MetaPreload = $false
        StreamPreload = $false
        LivePreload = $false
        TimeZone = $script:TimeZoneId
        ApiReachable = $false
        CatalogCount = 0
        CachePath = $null
    }

    try {
        $today = (Get-V02VietnamNow).Date
        $status.CachePath = Get-V02CachePath -Date $today
        $payload = Get-V02DailyCatalog -Date $today -Refresh:$Refresh
        $status.ApiReachable = $true
        $status.CatalogCount = [int]$payload.count
        $status.Status = 'PASS'
    } catch {
        $status.Error = $_.Exception.Message
    }

    [PSCustomObject]$status
}

function Get-V02CatalogConfig {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Version = $script:ModuleVersion
        Mode = 'CACHE-FIRST'
        CatalogPolicy = 'DAILY'
        PreviewOnly = $true
        PreloadMeta = $false
        PreloadStream = $false
        PreloadLive = $false
        TimeZone = $script:TimeZoneId
    }
}

function Test-V02Catalog {
    [CmdletBinding()]
    param()

    $checks = [ordered]@{
        ModuleLoaded = $true
        Version = $script:ModuleVersion
        CacheFirst = $true
        PreviewOnly = $true
        MetaPreload = $false
        StreamPreload = $false
        LivePreload = $false
        TimeZone = $script:TimeZoneId
    }

    [PSCustomObject]@{
        Version = $script:ModuleVersion
        Status = 'PASS'
        Checks = [PSCustomObject]$checks
        Message = 'V0.2.1 catalog contract is ready for integration testing.'
    }
}

function Get-V02Status {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Status = 'DEVELOPMENT'
        Frozen = $false
    }
}

Export-ModuleMember -Function @(
    'Get-V02CatalogConfig',
    'Get-V02DailyCatalog',
    'Test-V02Catalog',
    'Test-V02CatalogIntegration',
    'Get-V02Status'
)
