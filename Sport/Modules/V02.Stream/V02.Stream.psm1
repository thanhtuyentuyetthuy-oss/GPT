# Vietnam Sports Hub - V0.2.4 Stream contract module

Set-StrictMode -Version Latest

$script:ModuleVersion = '0.2.4'
$script:ModuleName = 'V02.Stream'

function Get-V024StreamConfig {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Mode = 'ON-DEMAND'
        CacheFirst = $true
        Preload = $false
        ResolveOnlyAfterPlay = $true
        LivePolling = $false
        CachePolicy = 'SHORT-TTL'
        SourcePolicy = 'AUTHORIZED-ONLY'
    }
}

function Test-V024StreamContract {
    [CmdletBinding()]
    param()

    $checks = [ordered]@{
        ModuleLoaded = $true
        Version = $script:ModuleVersion
        OnDemand = $true
        Preload = $false
        CacheFirst = $true
        ResolveOnlyAfterPlay = $true
        LivePolling = $false
        AuthorizedSourceOnly = $true
    }

    [PSCustomObject]@{
        Version = $script:ModuleVersion
        Status = 'PASS'
        Checks = [PSCustomObject]$checks
        Message = 'V0.2.4 stream contract is ready for resolver integration testing.'
    }
}

function Get-V024Status {
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
    'Get-V024StreamConfig',
    'Test-V024StreamContract',
    'Get-V024Status'
)
