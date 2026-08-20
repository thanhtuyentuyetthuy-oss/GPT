# Vietnam Sports Hub - shared cache helpers

Set-StrictMode -Version Latest

function Get-SportCachePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CacheRoot,
        [Parameter(Mandatory)][string]$Key
    )

    $safeKey = ($Key -replace '[^A-Za-z0-9_.-]', '_')
    Join-Path $CacheRoot ($safeKey + '.json')
}

function Test-SportCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$MaxAgeSeconds = 86400
    )

    if (-not (Test-Path $Path)) { return $false }
    $age = ((Get-Date) - (Get-Item $Path).LastWriteTime).TotalSeconds
    return ($age -le $MaxAgeSeconds)
}

function Read-SportCache {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) { return $null }
    Get-Content $Path -Raw | ConvertFrom-Json
}

function Write-SportCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Data
    )

    $parent = Split-Path $Path -Parent
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $Data | ConvertTo-Json -Depth 20 | Set-Content -Path $Path -Encoding UTF8
}

Export-ModuleMember -Function @(
    'Get-SportCachePath',
    'Test-SportCache',
    'Read-SportCache',
    'Write-SportCache'
)
