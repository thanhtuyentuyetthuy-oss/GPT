# Vietnam Sports Hub - V0.4.3 Catalog Adapter
Set-StrictMode -Version Latest

$script:ModuleVersion = '0.4.3'
$script:ModuleName = 'V04.CatalogAdapter'

function ConvertTo-V043StremioCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$CatalogPayload,
        [datetime]$Now = (Get-Date)
    )

    $items = @($CatalogPayload.metas)
    $metas = foreach ($item in $items) {
        $event = $item.event
        $state = 'UPCOMING'
        $kickoff = $null
        if ($event.kickoffUtc) {
            try { $kickoff = [datetime]::Parse([string]$event.kickoffUtc).ToUniversalTime() } catch {}
        }
        if ($event.status -match 'FT|FINISHED|CANCEL|POST') {
            $state = 'FINISHED'
        } elseif ($kickoff -and $kickoff -le [datetime]::UtcNow) {
            $state = 'LIVE-CANDIDATE'
        }

        $prefix = switch ($state) {
            'LIVE-CANDIDATE' { '[LIVE] ' }
            'UPCOMING' { '[NEXT] ' }
            default { '[DONE] ' }
        }

        [PSCustomObject]@{
            id = [string]$item.id
            type = 'tv'
            name = "$prefix$($item.name)"
            poster = $item.poster
            description = if ($item.description) { "$($item.description) • State: $state" } else { "State: $state" }
            genres = @('FOOTBALL')
            releaseInfo = [string]$item.releaseInfo
            behaviorHints = @{ defaultVideoId = [string]$item.id }
        }
    }

    [PSCustomObject]@{
        metas = @($metas)
        cacheMaxAge = 60
    }
}

function Get-V043Status {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Status = 'DEVELOPMENT'
        Frozen = $false
        Source = 'V0.2.1 DAILY CACHE'
        ApiRequests = 0
        CacheFirst = $true
        LocalTimeState = $true
    }
}

function Test-V043CatalogAdapter {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$CatalogPayload)

    $items = @($CatalogPayload.metas)
    $adapter = ConvertTo-V043StremioCatalog -CatalogPayload $CatalogPayload
    $ok = $null -ne $CatalogPayload -and $items.Count -gt 0 -and @($adapter.metas).Count -eq $items.Count -and @($adapter.metas)[0].type -eq 'tv'

    [PSCustomObject]@{
        Version = $script:ModuleVersion
        Status = if ($ok) { 'PASS' } else { 'FAIL' }
        Source = 'V0.2.1 DAILY CACHE'
        ApiRequests = 0
        CacheRead = $true
        InputCount = $items.Count
        OutputCount = @($adapter.metas).Count
        TypeMappedToTv = (@($adapter.metas) | Where-Object { $_.type -eq 'tv' }).Count -eq $items.Count
        LocalTimeState = $true
        Error = if ($ok) { $null } else { 'Catalog adapter validation failed.' }
    }
}

Export-ModuleMember -Function @('ConvertTo-V043StremioCatalog','Get-V043Status','Test-V043CatalogAdapter')
