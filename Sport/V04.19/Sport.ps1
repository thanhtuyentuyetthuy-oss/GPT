[CmdletBinding()]
param(
    [switch]$KeepServer
)

$ErrorActionPreference = 'Stop'
$test = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Tests\V04.19-Test.ps1'

if (-not (Test-Path $test)) {
    throw "V0.4.19 test harness not found: $test"
}

& powershell.exe -ExecutionPolicy Bypass -File $test -KeepServer:$KeepServer
exit $LASTEXITCODE
