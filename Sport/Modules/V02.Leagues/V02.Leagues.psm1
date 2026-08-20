# Vietnam Sports Hub - V0.2.2 League priority module

Set-StrictMode -Version Latest

$script:ModuleVersion = '0.2.2'
$script:ModuleName = 'V02.Leagues'
$script:TimeZoneId = 'Asia/Ho_Chi_Minh'
$script:CacheRoot = Join-Path $PSScriptRoot '..\..\..\Data\Cache\V02.Catalog'

$script:PriorityRules = @(
    [PSCustomObject]@{ Rank = 1; Key = 'uefa champions league'; Name = 'UEFA Champions League'; ShortName = 'Champions League' }
    [PSCustomObject]@{ Rank = 2; Key = 'premier league'; Name = 'Premier League'; ShortName = 'Premier League' }
    [PSCustomObject]@{ Rank = 3; Key = 'la liga'; Name = 'La Liga'; ShortName = 'La Liga' }
    [PSCustomObject]@{ Rank = 4; Key = 'bundesliga'; Name = 'Bundesliga'; ShortName = 'Bundesliga' }
)

function Get-V022CachePath {
    param([Parameter(Mandatory)][datetime]$Date)
    Join-Path $script:CacheRoot ("catalog-{0:yyyy-MM-dd}.json" -f $Date)
}

function Normalize-V022Text {
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    return (($Text.ToLowerInvariant() -replace '[^a-z0-9 ]', ' ') -replace '\s+', ' ').Trim()
}

function Get-V022LeagueInfo {
    param([AllowNull()][string]$League)

    $normalized = Normalize-V022Text -Text $League
    foreach ($rule in $script:PriorityRules) {
        if ($normalized -eq $rule.Key -or $normalized -like "*$($rule.Key)*") {
            return $rule
        }
    }

    [PSCustomObject]@{
        Rank = 999
        Key = $normalized
        Name = if ([string]::IsNullOrWhiteSpace($League)) { 'Other Football' } else { [string]$League }
        ShortName = 'Other Football'
    }
}

function Get-V022PriorityCatalog {
    [CmdletBinding()]
    param(
        [datetime]$Date = (Get-Date).Date
    )

    $cachePath = Get-V022CachePath -Date $Date
    if (-not (Test-Path $cachePath)) {
        throw "V0.2.1 catalog cache was not found: $cachePath"
    }

    $payload = Get-Content -Path $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $items = @($payload.metas)

    $rows = @(
        foreach ($item in $items) {
            $eventData = $null
            $descriptionValue = $null

            if ($item -and $item.PSObject.Properties['event']) {
                $eventData = $item.event
            }
            if ($item -and $item.PSObject.Properties['description']) {
                $descriptionValue = [string]$item.description
            }

            $league = $null
            if ($eventData -and $eventData.PSObject.Properties['league'] -and $eventData.league) {
                $league = [string]$eventData.league
            }
            elseif ($descriptionValue) {
                $league = ($descriptionValue -split ' • ')[0]
            }

            $rule = Get-V022LeagueInfo -League $league

            [PSCustomObject]@{
                rank = $rule.Rank
                priority = ($rule.Rank -lt 999)
                league = $rule.Name
                event = $item
            }
        }
    )

    $priority = @($rows | Where-Object { $_.priority } | Sort-Object rank, @{Expression = {
        if ($_.PSObject.Properties['event'] -and $_.event -and $_.event.PSObject.Properties['name']) { [string]$_.event.name } else { '' }
    }})

    $other = @($rows | Where-Object { -not $_.priority } | Sort-Object @{Expression = {
        if ($_.PSObject.Properties['event'] -and $_.event -and $_.event.PSObject.Properties['releaseInfo']) { [string]$_.event.releaseInfo } else { '' }
    }}, @{Expression = {
        if ($_.PSObject.Properties['event'] -and $_.event -and $_.event.PSObject.Properties['name']) { [string]$_.event.name } else { '' }
    }})

    # Do not use $priority.event / $other.event because PowerShell 5.1
    # under StrictMode can throw when either collection is empty.
    $priorityEvents = @($priority | ForEach-Object { $_.event })
    $otherEvents = @($other | ForEach-Object { $_.event })

    [PSCustomObject]@{
        version = $script:ModuleVersion
        localDate = $payload.localDate
        timeZone = $payload.timeZone
        sourceCache = $cachePath
        total = $rows.Count
        priorityCount = $priority.Count
        otherCount = $other.Count
        priority = $priorityEvents
        other = $otherEvents
    }
}

function Test-V022LeaguePriority {
    [CmdletBinding()]
    param(
        [datetime]$Date = (Get-Date).Date
    )

    $status = [ordered]@{
        Version = $script:ModuleVersion
        Status = 'FAIL'
        Source = 'V0.2.1 CACHE ONLY'
        ApiRequests = 0
        CacheRead = $false
        Total = 0
        Priority = 0
        Other = 0
        Error = $null
    }

    try {
        $result = Get-V022PriorityCatalog -Date $Date
        $status.CacheRead = $true
        $status.Total = [int]$result.total
        $status.Priority = [int]$result.priorityCount
        $status.Other = [int]$result.otherCount
        $status.Status = 'PASS'
    }
    catch {
        $status.Error = $_.Exception.Message
    }

    [PSCustomObject]$status
}

function Get-V022Status {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Status = 'DEVELOPMENT'
        Frozen = $false
        DependsOn = 'V0.2.1 Catalog Cache'
    }
}

Export-ModuleMember -Function @(
    'Get-V022PriorityCatalog',
    'Test-V022LeaguePriority',
    'Get-V022Status'
)
