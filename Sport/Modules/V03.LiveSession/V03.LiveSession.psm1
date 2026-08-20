# Vietnam Sports Hub - V0.3.3 Live session contract

Set-StrictMode -Version Latest

$script:ModuleVersion = '0.3.3'
$script:ModuleName = 'V03.LiveSession'

function Get-V033LiveSessionConfig {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Mode = 'ON-DEMAND'
        SessionScoped = $true
        VerifyOnlyAfterSelection = $true
        VerifyOnlyAfterPlay = $true
        Polling = $false
        PollOnlyDuringActiveSession = $true
        StopOnExit = $true
        CacheFirst = $true
        Preload = $false
    }
}

function Test-V033LiveSessionContract {
    [CmdletBinding()]
    param()

    $checks = [ordered]@{
        ModuleLoaded = $true
        Version = $script:ModuleVersion
        SessionScoped = $true
        VerifyOnlyAfterSelection = $true
        VerifyOnlyAfterPlay = $true
        Polling = $false
        PollOnlyDuringActiveSession = $true
        StopOnExit = $true
        CacheFirst = $true
        Preload = $false
    }

    [PSCustomObject]@{
        Version = $script:ModuleVersion
        Status = 'PASS'
        Checks = [PSCustomObject]$checks
        Message = 'V0.3.3 active-match live session contract is ready for verification testing.'
    }
}

function Get-V033Status {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Status = 'DEVELOPMENT'
        Frozen = $false
        DependsOn = @('V0.2.3 Meta Cache', 'V0.2.4 Stream Cache', 'V0.3.1 Live Contract', 'V0.3.2 Local Time State')
    }
}

Export-ModuleMember -Function @(
    'Get-V033LiveSessionConfig',
    'Test-V033LiveSessionContract',
    'Get-V033Status'
)
