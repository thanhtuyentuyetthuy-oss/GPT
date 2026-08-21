# Vietnam Sports Hub - V0.4.14 daily catalog adapter

Set-StrictMode -Version Latest

$script:ModuleVersion = '0.4.14'
$script:ModuleName = 'V04.DailyCatalog'

function Get-V0414DailyCatalogConfig {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Mode = 'DAILY-CATALOG-REFERENCE'
        SourceRole = 'CATALOG-ONLY'
        UpstreamRequests = 0
        StreamResolution = 'DEFERRED'
        CacheFirst = $true
    }
}

function Resolve-V0414DailyState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('SCHEDULED','LIVE','FINISHED','CANCELLED')][string]$Status,
        [Parameter(Mandatory)][datetime]$KickoffUtc
    )

    switch ($Status) {
        'LIVE' { return 'LIVE-CANDIDATE' }
        'FINISHED' { return 'FINISHED' }
        'CANCELLED' { return 'FINISHED' }
        'SCHEDULED' {
            if ($KickoffUtc -le [datetime]::UtcNow) { return 'LIVE-CANDIDATE' }
            return 'UPCOMING'
        }
    }
}

function ConvertTo-V0414CatalogItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$Fixture
    )

    $status = [string]$Fixture.status
    $kickoffUtc = [datetime]$Fixture.kickoffUtc
    $state = Resolve-V0414DailyState -Status $status -KickoffUtc $kickoffUtc
    $marker = switch ($state) {
        'LIVE-CANDIDATE' { '[LIVE] ' }
        'UPCOMING' { '[NEXT] ' }
        default { '[DONE] ' }
    }

    [PSCustomObject]@{
        id = "sports:event:$($Fixture.eventId)"
        type = 'tv'
        name = "$marker$($Fixture.homeTeam) vs $($Fixture.awayTeam)"
        description = "State: $state"
        genres = @('FOOTBALL')
        releaseInfo = $kickoffUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
        behaviorHints = [PSCustomObject]@{ defaultVideoId = "sports:event:$($Fixture.eventId)" }
    }
}

function Test-V0414CatalogItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$Fixture,
        [Parameter(Mandatory)][pscustomobject]$CatalogItem
    )

    $expectedState = Resolve-V0414DailyState -Status ([string]$Fixture.status) -KickoffUtc ([datetime]$Fixture.kickoffUtc)
    $expectedMarker = switch ($expectedState) {
        'LIVE-CANDIDATE' { '[LIVE]' }
        'UPCOMING' { '[NEXT]' }
        default { '[DONE]' }
    }

    [PSCustomObject]@{
        Version = $script:ModuleVersion
        Status = 'FAIL'
        CatalogOnly = $true
        StreamResolutionDeferred = $true
        EventIdValid = ([string]$CatalogItem.id -eq "sports:event:$($Fixture.eventId)")
        TypeValid = ([string]$CatalogItem.type -eq 'tv')
        TeamsValid = ([string]$CatalogItem.name -match [regex]::Escape([string]$Fixture.homeTeam)) -and ([string]$CatalogItem.name -match [regex]::Escape([string]$Fixture.awayTeam))
        StateValid = ([string]$CatalogItem.description -match [regex]::Escape("State: $expectedState"))
        MarkerValid = ([string]$CatalogItem.name -match "^$([regex]::Escape($expectedMarker))\s")
        HasStreamUrl = $false
        Error = $null
    }
}

function Get-V0414Status {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Status = 'DEVELOPMENT'
        Frozen = $false
        DependsOn = @('V0.4.11 State Contract', 'V0.4.13 Runtime Verification')
    }
}

Export-ModuleMember -Function @(
    'Get-V0414DailyCatalogConfig',
    'Resolve-V0414DailyState',
    'ConvertTo-V0414CatalogItem',
    'Test-V0414CatalogItem',
    'Get-V0414Status'
)
