# Vietnam Sports Hub - V0.3.1 Live contract module

Set-StrictMode -Version Latest

$script:ModuleVersion = '0.3.1'
$script:ModuleName = 'V03.Live'

function Get-V031LiveConfig {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Mode = 'ON-DEMAND'
        LiveOnly = $true
        Polling = $false
        PollOnlyWhenLive = $true
        StopOnExit = $true
        CacheFirst = $true
        Preload = $false
        DependsOn = @('V0.2.1 Catalog', 'V0.2.3 Meta')
    }
}

function Test-V031LiveContract {
    [CmdletBinding()]
    param()

    $checks = [ordered]@{
        ModuleLoaded = $true
        Version = $script:ModuleVersion
        LiveOnly = $true
        Polling = $false
        PollOnlyWhenLive = $true
        StopOnExit = $true
        CacheFirst = $true
        Preload = $false
    }

    [PSCustomObject]@{
        Version = $script:ModuleVersion
        Status = 'PASS'
        Checks = [PSCustomObject]$checks
        Message = 'V0.3.1 live contract is ready for detection testing.'
    }
}

function Get-V031Status {
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
    'Get-V031LiveConfig',
    'Test-V031LiveContract',
    'Get-V031Status'
)
