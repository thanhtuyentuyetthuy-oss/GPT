# Vietnam Sports Hub - Project Controller
# Single entry point for the modular PowerShell project.

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesRoot = Join-Path $ProjectRoot 'Modules'
$SharedRoot  = Join-Path $ProjectRoot 'Shared'

function Import-SportModule {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path $Path) {
        Import-Module $Path -Force -ErrorAction Stop
        return $true
    }
    return $false
}

$sharedModules = @(
    (Join-Path $SharedRoot 'Logging.psm1'),
    (Join-Path $SharedRoot 'GitHub.psm1'),
    (Join-Path $SharedRoot 'Config.psm1'),
    (Join-Path $SharedRoot 'Cache.psm1')
)

foreach ($module in $sharedModules) {
    if (Test-Path $module) { Import-SportModule -Path $module | Out-Null }
}

function Show-SportMenu {
    Clear-Host
    Write-Host '==============================================='
    Write-Host '         VIETNAM SPORTS HUB - CONTROL'
    Write-Host '==============================================='
    Write-Host ''
    Write-Host '[1] Check project structure'
    Write-Host '[2] Check module status'
    Write-Host '[3] Run V0.1 test'
    Write-Host '[4] Run V0.2.1 Catalog test'
    Write-Host '[5] Run V0.2.1 API/Cache integration test'
    Write-Host '[6] Run V0.2.2 League priority test'
    Write-Host '[7] Show latest log'
    Write-Host '[8] Publish log to GitHub'
    Write-Host '[0] Exit'
    Write-Host ''
}

function Invoke-V01 {
    $module = Join-Path $ModulesRoot 'V01.Catalog/V01.Catalog.psm1'
    if (-not (Import-SportModule -Path $module)) {
        Write-Host 'V0.1 module is not installed yet.' -ForegroundColor Yellow
        return
    }
    if (Get-Command Test-V01Catalog -ErrorAction SilentlyContinue) {
        Test-V01Catalog
    } else {
        Write-Host 'Test-V01Catalog is not exported by the V0.1 module.' -ForegroundColor Yellow
    }
}

function Invoke-V02Contract {
    $module = Join-Path $ModulesRoot 'V02.Catalog/V02.Catalog.psm1'
    if (-not (Import-SportModule -Path $module)) {
        Write-Host 'V0.2.1 Catalog module is not installed yet.' -ForegroundColor Yellow
        return
    }

    $result = Test-V02Catalog
    Write-Host "Version: $($result.Version)"
    Write-Host "Status : $($result.Status)"
    Write-Host $result.Message
    $result.Checks | Format-List
}

function Invoke-V02Integration {
    $module = Join-Path $ModulesRoot 'V02.Catalog/V02.Catalog.psm1'
    if (-not (Import-SportModule -Path $module)) {
        Write-Host 'V0.2.1 Catalog module is not installed yet.' -ForegroundColor Yellow
        return
    }

    $result = Test-V02CatalogIntegration
    Write-Host "Version      : $($result.Version)"
    Write-Host "Status       : $($result.Status)"
    Write-Host "API Reachable: $($result.ApiReachable)"
    Write-Host "Catalog Count: $($result.CatalogCount)"
    Write-Host "Cache Path   : $($result.CachePath)"
    if ($result.Error) {
        Write-Host "Error        : $($result.Error)" -ForegroundColor Red
    }
}

function Invoke-V022LeaguePriority {
    $module = Join-Path $ModulesRoot 'V02.Leagues/V02.Leagues.psm1'
    if (-not (Import-SportModule -Path $module)) {
        Write-Host 'V0.2.2 League priority module is not installed yet.' -ForegroundColor Yellow
        return
    }

    $result = Test-V022LeaguePriority
    Write-Host "Version     : $($result.Version)"
    Write-Host "Status      : $($result.Status)"
    Write-Host "Source      : $($result.Source)"
    Write-Host "API Requests: $($result.ApiRequests)"
    Write-Host "Cache Read  : $($result.CacheRead)"
    Write-Host "Total       : $($result.Total)"
    Write-Host "Priority    : $($result.Priority)"
    Write-Host "Other       : $($result.Other)"
    if ($result.Error) {
        Write-Host "Error       : $($result.Error)" -ForegroundColor Red
    }
}

function Show-Status {
    $candidates = Get-ChildItem -Path $ModulesRoot -Directory -ErrorAction SilentlyContinue
    if (-not $candidates) {
        Write-Host 'No version modules have been added yet.' -ForegroundColor Yellow
        return
    }
    foreach ($dir in $candidates) {
        $passFile = Join-Path $dir.FullName 'PASS.md'
        if (Test-Path $passFile) {
            Write-Host "[$($dir.Name)] PASS/FREEZE" -ForegroundColor Green
        } else {
            Write-Host "[$($dir.Name)] DEVELOPMENT" -ForegroundColor Cyan
        }
    }
}

while ($true) {
    Show-SportMenu
    $choice = Read-Host 'Select'
    switch ($choice) {
        '1' {
            Write-Host "Project: $ProjectRoot"
            Write-Host "Modules: $ModulesRoot"
            Write-Host "Shared : $SharedRoot"
            Read-Host 'Press Enter'
        }
        '2' {
            Show-Status
            Read-Host 'Press Enter'
        }
        '3' {
            Invoke-V01
            Read-Host 'Press Enter'
        }
        '4' {
            Invoke-V02Contract
            Read-Host 'Press Enter'
        }
        '5' {
            Invoke-V02Integration
            Read-Host 'Press Enter'
        }
        '6' {
            Invoke-V022LeaguePriority
            Read-Host 'Press Enter'
        }
        '7' {
            $latest = Join-Path $ProjectRoot 'Logs/log.txt'
            if (Test-Path $latest) { Get-Content $latest -Tail 60 } else { Write-Host 'No log file yet.' -ForegroundColor Yellow }
            Read-Host 'Press Enter'
        }
        '8' {
            if (Get-Command Publish-SportLog -ErrorAction SilentlyContinue) {
                Publish-SportLog -RepoRoot $ProjectRoot
            } else {
                Write-Host 'GitHub module not installed yet.' -ForegroundColor Yellow
            }
            Read-Host 'Press Enter'
        }
        '0' {
            Write-Host 'Exiting Vietnam Sports Hub...'
            return
        }
        default {
            Write-Host 'Invalid selection.' -ForegroundColor Yellow
            Start-Sleep -Milliseconds 700
        }
    }
}
