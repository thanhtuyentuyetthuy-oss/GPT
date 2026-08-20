# Vietnam Sports Hub - V0.3.2 Local Time State

Set-StrictMode -Version Latest

$script:ModuleVersion = '0.3.2'
$script:ModuleName = 'V03.LocalTimeState'
$script:TimeZoneId = 'Asia/Ho_Chi_Minh'
$script:WindowsTimeZoneId = 'SE Asia Standard Time'
$script:CacheRoot = Join-Path $PSScriptRoot '..\..\..\Data\Cache\V02.Catalog'

function Get-V032TimeZone {
    try { return [TimeZoneInfo]::FindSystemTimeZoneById($script:TimeZoneId) }
    catch { return [TimeZoneInfo]::FindSystemTimeZoneById($script:WindowsTimeZoneId) }
}

function Get-V032VietnamNow {
    $tz = Get-V032TimeZone
    return [TimeZoneInfo]::ConvertTimeFromUtc([datetime]::UtcNow, $tz)
}

function Get-V032CachePath {
    param([Parameter(Mandatory)][datetime]$Date)
    Join-Path $script:CacheRoot ("catalog-{0:yyyy-MM-dd}.json" -f $Date)
}

function ConvertTo-V032State {
    param([Parameter(Mandatory)]$Item,[Parameter(Mandatory)][datetime]$NowLocal)
    $eventData = $null
    if ($Item -and $Item.PSObject.Properties['event']) { $eventData = $Item.event }
    if (-not $eventData) { throw 'Catalog item does not contain event preview data.' }

    $kickoffUtc = $null
    if ($eventData.PSObject.Properties['kickoffUtc']) { $kickoffUtc = [string]$eventData.kickoffUtc }
    if ([string]::IsNullOrWhiteSpace($kickoffUtc)) {
        return [PSCustomObject]@{ State='UNKNOWN'; IsLiveCandidate=$false; KickoffLocal=$null }
    }

    try { $kickoff = [datetime]::Parse($kickoffUtc).ToLocalTime() }
    catch { throw "Invalid kickoffUtc: $kickoffUtc" }

    $state = 'UPCOMING'
    if ($NowLocal -ge $kickoff) { $state = 'LIVE-CANDIDATE' }

    [PSCustomObject]@{
        State = $state
        IsLiveCandidate = ($state -eq 'LIVE-CANDIDATE')
        KickoffLocal = $kickoff
    }
}

function Get-V032CatalogState {
    [CmdletBinding()]
    param([datetime]$NowLocal=(Get-V032VietnamNow),[datetime]$Date=(Get-V032VietnamNow).Date)

    $cachePath = Get-V032CachePath -Date $Date
    if (-not (Test-Path $cachePath)) { throw "V0.2.1 catalog cache was not found: $cachePath" }

    $payload = Get-Content -Path $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $items = @($payload.metas)
    $rows = @()

    foreach ($item in $items) {
        $eventData = $null
        if ($item -and $item.PSObject.Properties['event']) { $eventData = $item.event }
        if (-not $eventData) { continue }
        $state = ConvertTo-V032State -Item $item -NowLocal $NowLocal
        $rows += [PSCustomObject]@{
            eventId = if ($eventData.PSObject.Properties['eventId']) { [string]$eventData.eventId } else { '' }
            name = if ($item.PSObject.Properties['name']) { [string]$item.name } else { 'Unknown Match' }
            league = if ($eventData.PSObject.Properties['league']) { [string]$eventData.league } else { '' }
            kickoffLocal = $state.KickoffLocal
            state = $state.State
            isLiveCandidate = $state.IsLiveCandidate
            event = $item
        }
    }

    [PSCustomObject]@{
        version = $script:ModuleVersion
        nowLocal = $NowLocal.ToString('o')
        timeZone = $script:TimeZoneId
        sourceCache = $cachePath
        total = $rows.Count
        liveCandidate = @($rows | Where-Object { $_.state -eq 'LIVE-CANDIDATE' })
        upcoming = @($rows | Where-Object { $_.state -eq 'UPCOMING' } | Sort-Object kickoffLocal)
        unknown = @($rows | Where-Object { $_.state -eq 'UNKNOWN' })
        rows = $rows
    }
}

function Test-V032LocalTimeState {
    [CmdletBinding()]
    param()

    $status = [ordered]@{ Version=$script:ModuleVersion; Status='FAIL'; Source='V0.2.1 CACHE ONLY'; ApiRequests=0; CacheRead=$false; Total=0; LiveCandidate=0; Upcoming=0; Unknown=0; TimeZone=$script:TimeZoneId; Error=$null }
    try {
        $result = Get-V032CatalogState
        $status.CacheRead = $true
        $status.Total = [int]$result.total
        $status.LiveCandidate = @($result.liveCandidate).Count
        $status.Upcoming = @($result.upcoming).Count
        $status.Unknown = @($result.unknown).Count
        if ($status.Total -gt 0 -and $status.Total -eq ($status.LiveCandidate + $status.Upcoming + $status.Unknown)) { $status.Status='PASS' }
        else { throw 'Catalog state classification did not account for every cached item.' }
    } catch { $status.Error = $_.Exception.Message }
    [PSCustomObject]$status
}

function Get-V032Status {
    [CmdletBinding()]
    param()
    [PSCustomObject]@{ Module=$script:ModuleName; Version=$script:ModuleVersion; Status='DEVELOPMENT'; Frozen=$false; DependsOn='V0.2.1 Catalog Cache + V0.3.1 Live Contract' }
}

Export-ModuleMember -Function @('Get-V032CatalogState','Test-V032LocalTimeState','Get-V032Status')
