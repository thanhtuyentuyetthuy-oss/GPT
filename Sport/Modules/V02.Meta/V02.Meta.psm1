# Vietnam Sports Hub - V0.2.3 Meta on-demand module

Set-StrictMode -Version Latest

$script:ModuleVersion = '0.2.3'
$script:ModuleName = 'V02.Meta'
$script:ApiBase = 'https://www.thesportsdb.com/api/v1/json/123'
$script:CatalogCacheRoot = Join-Path $PSScriptRoot '..\..\..\Data\Cache\V02.Catalog'
$script:MetaCacheRoot = Join-Path $PSScriptRoot '..\..\..\Data\Cache\V02.Meta'

function Ensure-V023MetaCacheDirectory {
    if (-not (Test-Path $script:MetaCacheRoot)) {
        New-Item -ItemType Directory -Force -Path $script:MetaCacheRoot | Out-Null
    }
}

function Get-V023CatalogCachePath {
    param([Parameter(Mandatory)][datetime]$Date)
    Join-Path $script:CatalogCacheRoot ("catalog-{0:yyyy-MM-dd}.json" -f $Date)
}

function Get-V023MetaCachePath {
    param([Parameter(Mandatory)][string]$EventId)
    Ensure-V023MetaCacheDirectory
    $safeId = $EventId -replace '[^0-9A-Za-z_.-]', '_'
    Join-Path $script:MetaCacheRoot ("event-$safeId.json")
}

function Get-V023SelectableEvents {
    [CmdletBinding()]
    param(
        [datetime]$Date = (Get-Date).Date
    )

    $catalogPath = Get-V023CatalogCachePath -Date $Date
    if (-not (Test-Path $catalogPath)) {
        throw "V0.2.1 catalog cache was not found: $catalogPath"
    }

    $payload = Get-Content -Path $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $items = @($payload.metas)

    $rows = @(
        foreach ($item in $items) {
            $eventId = $null
            $name = 'Unknown Match'
            $league = ''

            if ($item -and $item.PSObject.Properties['event']) {
                $eventData = $item.event
                if ($eventData -and $eventData.PSObject.Properties['eventId']) {
                    $eventId = [string]$eventData.eventId
                }
                elseif ($item.PSObject.Properties['id']) {
                    $idText = [string]$item.id
                    if ($idText -match 'sports:event:(.+)$') { $eventId = $Matches[1] }
                }
                if ($eventData -and $eventData.PSObject.Properties['league']) {
                    $league = [string]$eventData.league
                }
            }
            elseif ($item -and $item.PSObject.Properties['id']) {
                $idText = [string]$item.id
                if ($idText -match 'sports:event:(.+)$') { $eventId = $Matches[1] }
            }

            if ($item -and $item.PSObject.Properties['name'] -and $item.name) {
                $name = [string]$item.name
            }

            if (-not [string]::IsNullOrWhiteSpace($eventId)) {
                [PSCustomObject]@{
                    EventId = $eventId
                    Name = $name
                    League = $league
                }
            }
        }
    )

    @($rows)
}

function Invoke-V023MetaApi {
    param([Parameter(Mandatory)][string]$EventId)

    $uri = "$($script:ApiBase)/lookupevent.php?id=$EventId"
    Write-Host "[V0.2.3][API] GET $uri"
    Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 20
}

function Get-V023EventMeta {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EventId,
        [switch]$Refresh
    )

    $cachePath = Get-V023MetaCachePath -EventId $EventId

    if ((Test-Path $cachePath) -and -not $Refresh) {
        try {
            $cached = Get-Content -Path $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json
            Write-Host "[V0.2.3][CACHE HIT] event $EventId"
            return [PSCustomObject]@{
                Version = $script:ModuleVersion
                EventId = $EventId
                Source = 'CACHE'
                ApiRequests = 0
                CacheHit = $true
                CachePath = $cachePath
                Event = $cached.Event
            }
        }
        catch {
            Write-Host '[V0.2.3][CACHE INVALID] Rebuilding metadata cache.' -ForegroundColor Yellow
        }
    }

    $response = Invoke-V023MetaApi -EventId $EventId
    $event = @($response.events) | Select-Object -First 1
    if (-not $event) {
        throw "No event metadata was returned for event ID $EventId."
    }

    $payload = [PSCustomObject]@{
        version = $script:ModuleVersion
        generatedAtUtc = [datetime]::UtcNow.ToString('o')
        eventId = $EventId
        event = $event
    }

    $payload | ConvertTo-Json -Depth 30 | Set-Content -Path $cachePath -Encoding UTF8
    Write-Host "[V0.2.3][CACHE WRITE] event $EventId"

    [PSCustomObject]@{
        Version = $script:ModuleVersion
        EventId = $EventId
        Source = 'API'
        ApiRequests = 1
        CacheHit = $false
        CachePath = $cachePath
        Event = $event
    }
}

function Test-V023MetaOnDemand {
    [CmdletBinding()]
    param(
        [string]$EventId = '',
        [datetime]$Date = (Get-Date).Date,
        [switch]$Refresh
    )

    $status = [ordered]@{
        Version = $script:ModuleVersion
        Status = 'FAIL'
        Source = 'V0.2.1 CACHE -> SELECTED EVENT ONLY'
        EventId = ''
        ApiRequests = 0
        CatalogRead = $false
        MetaCacheHit = $false
        MetaLoaded = $false
        MetaCachePath = ''
        Error = $null
    }

    try {
        $selectable = @(Get-V023SelectableEvents -Date $Date)
        $status.CatalogRead = $true

        if ([string]::IsNullOrWhiteSpace($EventId)) {
            if ($selectable.Count -lt 1) {
                throw 'No selectable events were found in the V0.2.1 catalog cache.'
            }
            $EventId = [string]$selectable[0].EventId
        }

        $selected = $selectable | Where-Object { [string]$_.EventId -eq [string]$EventId } | Select-Object -First 1
        if (-not $selected) {
            throw "Selected event ID $EventId was not found in the V0.2.1 catalog cache."
        }

        $status.EventId = $EventId
        $result = Get-V023EventMeta -EventId $EventId -Refresh:$Refresh
        $status.ApiRequests = [int]$result.ApiRequests
        $status.MetaCacheHit = [bool]$result.CacheHit
        $status.MetaLoaded = [bool]($null -ne $result.Event)
        $status.MetaCachePath = [string]$result.CachePath
        $status.Status = 'PASS'
    }
    catch {
        $status.Error = $_.Exception.Message
    }

    [PSCustomObject]$status
}

function Get-V023Status {
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
    'Get-V023SelectableEvents',
    'Get-V023EventMeta',
    'Test-V023MetaOnDemand',
    'Get-V023Status'
)
