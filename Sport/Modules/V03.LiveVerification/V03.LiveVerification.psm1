# Vietnam Sports Hub - V0.3.4 Live verification module

Set-StrictMode -Version Latest

$script:ModuleVersion = '0.3.4'
$script:ModuleName = 'V03.LiveVerification'
$script:ApiBase = 'https://www.thesportsdb.com/api/v1/json/123'

function Get-V034LiveVerificationConfig {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Mode = 'ON-DEMAND'
        SessionScoped = $true
        VerifyOnlyAfterSelection = $true
        VerifyOnlyAfterPlay = $true
        RequestsPerVerification = 1
        Polling = $false
        CacheFirst = $true
        Preload = $false
    }
}

function Get-V034EventFromMetaCache {
    param([Parameter(Mandatory)][string]$EventId)

    $metaTemplate = Join-Path $PSScriptRoot '..\..\..\Data\Cache\V02.Meta\event-{0}.json'
    $metaPath = $metaTemplate -f $EventId
    if (-not (Test-Path $metaPath)) {
        return $null
    }

    try {
        return Get-Content -Path $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Get-V034ApiEvent {
    param([Parameter(Mandatory)][string]$EventId)

    $uri = "$($script:ApiBase)/lookupevent.php?id=$([uri]::EscapeDataString($EventId))"
    Write-Host "[V0.3.4][API] GET $uri"
    $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 20
    if ($response -and $response.events) {
        return @($response.events)[0]
    }
    return $null
}

function ConvertTo-V034VerificationState {
    param([Parameter(Mandatory)]$Event)

    $statusText = ''
    if ($Event.PSObject.Properties['strStatus'] -and $Event.strStatus) {
        $statusText = [string]$Event.strStatus
    }

    $normalized = $statusText.Trim().ToLowerInvariant()

    $isLive = $false
    if ($normalized -match 'live|in progress|playing') {
        $isLive = $true
    }

    $state = if ($isLive) { 'LIVE' } elseif ($normalized -match 'postpon|cancel|abandon') { 'NOT_LIVE' } elseif ($normalized -match 'finish|final|ft') { 'FINISHED' } elseif ($normalized) { 'NOT_LIVE' } else { 'UNKNOWN' }

    [PSCustomObject]@{
        State = $state
        SourceStatus = $statusText
        IsLive = $isLive
    }
}

function Test-V034LiveVerification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EventId
    )

    $status = [ordered]@{
        Version = $script:ModuleVersion
        Status = 'FAIL'
        Source = 'ACTIVE SESSION ONLY'
        EventId = $EventId
        CatalogRead = $false
        MetaCacheRead = $false
        Selected = $true
        PlayRequested = $true
        ApiRequests = 0
        Verified = $false
        IsLive = $false
        LiveState = 'UNKNOWN'
        SourceStatus = ''
        Error = $null
    }

    try {
        $cacheRoot = Join-Path $PSScriptRoot '..\..\..\Data\Cache\V02.Catalog'
        if (-not (Test-Path $cacheRoot)) {
            throw 'V0.2.1 catalog cache directory was not found.'
        }

        # Prefer the newest cached Catalog. This avoids assuming the UTC date
        # matches the Vietnam local date used by V0.2.1.
        $catalogFiles = Get-ChildItem -Path $cacheRoot -Filter 'catalog-*.json' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending
        if (-not $catalogFiles) {
            throw 'V0.2.1 catalog cache was not found.'
        }
        $catalogPath = $catalogFiles[0].FullName

        $catalog = Get-Content -Path $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $items = @($catalog.metas)
        $match = $null
        foreach ($item in $items) {
            if ($item -and $item.PSObject.Properties['event'] -and $item.event -and $item.event.PSObject.Properties['eventId']) {
                if ([string]$item.event.eventId -eq [string]$EventId) {
                    $match = $item
                    break
                }
            }
        }
        if (-not $match) {
            throw "Selected event $EventId was not found in the Catalog cache."
        }
        $status.CatalogRead = $true

        $meta = Get-V034EventFromMetaCache -EventId $EventId
        if ($meta) {
            $status.MetaCacheRead = $true
        }

        # V0.3.4 verifies only the active selected/played match. One request at most.
        $event = Get-V034ApiEvent -EventId $EventId
        $status.ApiRequests = 1
        if (-not $event) {
            throw "TheSportsDB returned no event for $EventId."
        }

        $verification = ConvertTo-V034VerificationState -Event $event
        $status.LiveState = $verification.State
        $status.SourceStatus = $verification.SourceStatus
        $status.IsLive = [bool]$verification.IsLive
        $status.Verified = $true
        $status.Status = 'PASS'
    } catch {
        $status.Error = $_.Exception.Message
    }

    [PSCustomObject]$status
}

function Get-V034Status {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Status = 'DEVELOPMENT'
        Frozen = $false
        DependsOn = @('V0.2.1 Catalog Cache', 'V0.2.3 Meta Cache', 'V0.3.1 Live Contract', 'V0.3.2 Local Time State', 'V0.3.3 Active Match Session')
    }
}

Export-ModuleMember -Function @(
    'Get-V034LiveVerificationConfig',
    'Test-V034LiveVerification',
    'Get-V034Status'
)
