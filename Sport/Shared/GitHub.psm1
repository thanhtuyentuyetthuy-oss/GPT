# Vietnam Sports Hub - GitHub helper module
# Provides the function used by Sport.ps1 option [5].

function Test-GitRepository {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    if (-not (Test-Path $RepoRoot)) { return $false }

    Push-Location $RepoRoot
    try {
        git rev-parse --show-toplevel *> $null
        return ($LASTEXITCODE -eq 0)
    }
    finally {
        Pop-Location
    }
}

function Publish-SportLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [string]$LogPath = '',
        [string]$CommitMessage = ''
    )

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git is not installed or is not available in PATH.'
    }

    if (-not (Test-GitRepository -RepoRoot $RepoRoot)) {
        throw "'$RepoRoot' is not a Git repository. Use the cloned GitHub repository as the project root."
    }

    if ([string]::IsNullOrWhiteSpace($LogPath)) {
        $LogPath = Join-Path $RepoRoot 'Logs/log.txt'
    }

    if (-not (Test-Path $LogPath)) {
        Write-Host "No log file found: $LogPath" -ForegroundColor Yellow
        return $false
    }

    Push-Location $RepoRoot
    try {
        $remote = git remote get-url origin 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remote)) {
            throw 'Git remote ''origin'' is not configured.'
        }

        $relative = [System.IO.Path]::GetRelativePath($RepoRoot, $LogPath)
        git add -- $relative
        if ($LASTEXITCODE -ne 0) { throw 'git add failed.' }

        $changes = git status --porcelain
        if (-not $changes) {
            Write-Host 'No changes to publish.' -ForegroundColor Yellow
            return $true
        }

        if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
            $CommitMessage = 'Update sports addon test log'
        }

        git commit -m $CommitMessage
        if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }

        git push origin HEAD
        if ($LASTEXITCODE -ne 0) {
            throw 'git push failed. Check GitHub authentication and remote configuration.'
        }

        Write-Host 'GitHub push completed successfully.' -ForegroundColor Green
        Write-Host "Remote: $remote"
        Write-Host "Published: $relative"
        return $true
    }
    finally {
        Pop-Location
    }
}

function Get-GitRepositoryStatus {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    if (-not (Test-GitRepository -RepoRoot $RepoRoot)) {
        return [PSCustomObject]@{
            IsGitRepository = $false
            Remote = $null
            Status = 'NOT-A-GIT-REPOSITORY'
        }
    }

    Push-Location $RepoRoot
    try {
        $remote = git remote get-url origin 2>$null
        $status = git status --porcelain
        return [PSCustomObject]@{
            IsGitRepository = $true
            Remote = $remote
            Status = if ($status) { 'CHANGES' } else { 'CLEAN' }
        }
    }
    finally {
        Pop-Location
    }
}

Export-ModuleMember -Function @(
    'Test-GitRepository',
    'Publish-SportLog',
    'Get-GitRepositoryStatus'
)
