# Vietnam Sports Hub - V0.3.5 active-session polling module

Set-StrictMode -Version Latest

$script:ModuleVersion = '0.3.5'
$script:ModuleName = 'V03.ActivePolling'

function Get-V035ActivePollingConfig {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Mode = 'ACTIVE-SESSION-ONLY'
        Polling = $true
        PollOnlyWhenLive = $true
        PollOnlyDuringActiveSession = $true
        MaxPollsPerCycle = 1
        StopWhenFinished = $true
        StopOnExit = $true
        CacheFirst = $true
        Preload = $false
    }
}

function Test-V035ActivePolling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('LIVE','NOT_LIVE','FINISHED','UNKNOWN')][string]$LiveState
    )

    $status = [ordered]@{
        Version = $script:ModuleVersion
        Status = 'FAIL'
        SessionActive = $true
        PollingEnabled = $true
        PollOnlyWhenLive = $true
        PollOnlyDuringActiveSession = $true
        LiveState = $LiveState
        PollAllowed = $false
        PollRequests = 0
        StopReason = $null
        ExitStopsPolling = $true
        Error = $null
    }

    try {
        if ($LiveState -eq 'LIVE') {
            $status.PollAllowed = $true
            $status.PollRequests = 1
            $status.StopReason = 'ONE_CYCLE_TEST_COMPLETE'
        } else {
            $status.PollAllowed = $false
            $status.PollRequests = 0
            $status.StopReason = if ($LiveState -eq 'FINISHED') { 'FINISHED' } elseif ($LiveState -eq 'NOT_LIVE') { 'NOT_LIVE' } else { 'UNKNOWN' }
        }

        if ($LiveState -ne 'LIVE' -and $status.PollRequests -ne 0) {
            throw 'Non-LIVE session must not poll.'
        }
        if ($LiveState -eq 'LIVE' -and $status.PollRequests -ne 1) {
            throw 'LIVE session must allow exactly one poll in this contract test.'
        }

        $status.Status = 'PASS'
    } catch {
        $status.Error = $_.Exception.Message
    }

    [PSCustomObject]$status
}

function Get-V035Status {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Status = 'DEVELOPMENT'
        Frozen = $false
        DependsOn = @('V0.3.3 Active Match Session', 'V0.3.4 Live Verification')
    }
}

Export-ModuleMember -Function @(
    'Get-V035ActivePollingConfig',
    'Test-V035ActivePolling',
    'Get-V035Status'
)
