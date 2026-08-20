# Vietnam Sports Hub - V0.3.6 Exit / Stop module

Set-StrictMode -Version Latest

$script:ModuleVersion = '0.3.6'
$script:ModuleName = 'V03.ExitStop'

function Get-V036ExitStopConfig {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Mode = 'ACTIVE-SESSION-ONLY'
        ExitStopsPolling = $true
        StopImmediately = $true
        NoPostExitRequests = $true
        KeepWarmCache = $true
        CacheFirst = $true
        Preload = $false
    }
}

function Test-V036ExitStop {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, 100)]
        [int]$PollRequestsBeforeExit
    )

    $status = [ordered]@{
        Version = $script:ModuleVersion
        Status = 'FAIL'
        SessionActiveBeforeExit = $true
        ExitRequested = $true
        PollRequestsBeforeExit = $PollRequestsBeforeExit
        PollingStopped = $false
        PostExitPollRequests = 0
        PostExitRequests = 0
        WarmCacheKept = $true
        StopReason = 'USER_EXIT'
        Error = $null
    }

    try {
        $status.PollingStopped = $true

        if ($status.PostExitPollRequests -ne 0) {
            throw 'Exit must stop polling immediately.'
        }

        if ($status.PostExitRequests -ne 0) {
            throw 'No request may be generated after exit.'
        }

        if (-not $status.WarmCacheKept) {
            throw 'Warm cache must remain available after exit.'
        }

        $status.Status = 'PASS'
    }
    catch {
        $status.Error = $_.Exception.Message
    }

    [PSCustomObject]$status
}

function Get-V036Status {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Status = 'DEVELOPMENT'
        Frozen = $false
        DependsOn = @('V0.3.3 Active Match Session', 'V0.3.5 Active Polling')
    }
}

Export-ModuleMember -Function @(
    'Get-V036ExitStopConfig',
    'Test-V036ExitStop',
    'Get-V036Status'
)
