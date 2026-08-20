# Vietnam Sports Hub - shared configuration

Set-StrictMode -Version Latest

function Get-SportProjectConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot
    )

    [PSCustomObject]@{
        ProjectRoot = $ProjectRoot
        CacheRoot = Join-Path $ProjectRoot 'Data\Cache'
        LogRoot = Join-Path $ProjectRoot 'Logs'
        TimeZone = 'Asia/Ho_Chi_Minh'
        PriorityLeagues = @(
            'UEFA Champions League',
            'Premier League',
            'La Liga',
            'Bundesliga'
        )
    }
}

Export-ModuleMember -Function @('Get-SportProjectConfig')
