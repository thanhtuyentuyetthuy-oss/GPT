# Vietnam Sports Hub - shared logging helpers

Set-StrictMode -Version Latest

function Initialize-SportLog {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$LogRoot)

    New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
    $path = Join-Path $LogRoot 'log.txt'
    if (-not (Test-Path $path)) {
        "$(Get-Date -Format o) [INIT] Vietnam Sports Hub log" | Set-Content -Path $path -Encoding UTF8
    }
    return $path
}

function Write-SportLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','DEBUG','WARN','ERROR','PASS','FAIL')][string]$Level = 'INFO'
    )

    $line = "$(Get-Date -Format o) [$Level] $Message"
    Add-Content -Path $Path -Value $line -Encoding UTF8
}

function Get-SportLatestLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$Tail = 60
    )

    if (Test-Path $Path) { Get-Content $Path -Tail $Tail }
    else { Write-Host "No log file yet: $Path" -ForegroundColor Yellow }
}

Export-ModuleMember -Function @(
    'Initialize-SportLog',
    'Write-SportLog',
    'Get-SportLatestLog'
)
