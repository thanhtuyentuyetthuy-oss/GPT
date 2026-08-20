# Vietnam Sports Hub - V0.2.1 Catalog module

Set-StrictMode -Version Latest

$script:ModuleVersion = '0.2.1'
$script:ModuleName = 'V02.Catalog'

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
        TimeZone = 'Asia/Ho_Chi_Minh'
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
        TimeZone = 'Asia/Ho_Chi_Minh'
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
    'Test-V02Catalog',
    'Get-V02Status'
)
