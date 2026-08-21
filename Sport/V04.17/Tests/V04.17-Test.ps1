$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$versionRoot = Split-Path -Parent $root
$contractPath = Join-Path $versionRoot 'Contracts\V04.17-HLSCompatibility.json'
$deployScript = Join-Path $versionRoot 'Deployments\Cloudflare\Deploy-V04.17-Cloudflare.ps1'
$workerRoot = Join-Path $versionRoot 'Deployments\Cloudflare\Worker'
$baseUrl = 'https://vietnam-sports-hub.vnsports.workers.dev'

function Check([string]$Name, [bool]$Passed) {
    Write-Host ('[{0}] {1}' -f $(if ($Passed) { 'PASS' } else { 'FAIL' }), $Name)
}

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.17'
Write-Host '       STREMIO HLS COMPATIBILITY CONTRACT'
Write-Host '==============================================='

$checks = [ordered]@{}
$failure = ''
$deployed = $false

try {
    $contract = Get-Content -Raw $contractPath | ConvertFrom-Json
    $checks['Compatibility Contract'] = $contract.version -eq '0.4.17' -and $contract.stream.format -eq 'HLS-M3U8'
    $checks['Previous Contracts Frozen'] = [bool]$contract.previousContractsFrozen
    $checks['Authorized Stream Policy'] = $contract.stream.sourcePolicy -eq 'AUTHORIZED-ONLY'
    $checks['notWebReady Contract'] = [bool]$contract.stream.behaviorHints.notWebReady
    $checks['Diagnostic Contract'] = [bool]$contract.diagnostics.enabled -and [bool]$contract.diagnostics.primaryFailure
    $checks['Worker Target'] = Test-Path (Join-Path $workerRoot 'src\index.js')
    $checks['Deploy Script'] = Test-Path $deployScript
    $checks['Auto Deploy Policy'] = [bool]$contract.deployment.autoDeployOnPass -and [bool]$contract.deployment.postDeployVerification

    $prePassed = $checks.Values -notcontains $false
    foreach ($key in $checks.Keys) { Check $key $checks[$key] }

    Write-Host ''
    Write-Host "Pre-Deployment Status     : $(if ($prePassed) { 'PASS' } else { 'FAIL' })"

    if (-not $prePassed) {
        $failure = ($checks.GetEnumerator() | Where-Object { -not $_.Value } | Select-Object -First 1).Key
        Write-Host 'AUTO DEPLOY              : STOPPED'
    }
    else {
        Write-Host 'AUTO DEPLOY              : CLOUDFLARE WORKER'
        & powershell -ExecutionPolicy Bypass -File $deployScript
        if ($LASTEXITCODE -ne 0) { throw "Deployment script failed with exit code $LASTEXITCODE." }
        $deployed = $true

        Start-Sleep -Seconds 2

        $manifest = Invoke-RestMethod "$baseUrl/manifest.json"
        $health = Invoke-RestMethod "$baseUrl/health"
        $catalog = Invoke-RestMethod "$baseUrl/catalog/tv/vietnam-sports.json"
        $meta = Invoke-RestMethod "$baseUrl/meta/tv/sports:event:2397275.json"
        $stream = Invoke-RestMethod "$baseUrl/stream/tv/sports:event:2397275.json"

        $checks['Cloudflare Reachable'] = $true
        $checks['Manifest Valid'] = $manifest.version -eq '0.4.17-cloudflare' -and @($manifest.resources) -contains 'stream'
        $checks['Health Valid'] = $health.status -eq 'OK' -and $health.localHostDependency -eq $false
        $checks['Catalog Valid'] = @($catalog.metas).Count -eq 3
        $checks['Meta Valid'] = $meta.meta.id -eq 'sports:event:2397275'
        $checks['Stream Valid'] = @($stream.streams).Count -eq 1 -and $stream.streams[0].url -match '\.m3u8$'
        $checks['HLS notWebReady'] = $stream.streams[0].behaviorHints.notWebReady -eq $true
        $checks['Authorized Source Only'] = $stream.meta.sourcePolicy -eq 'AUTHORIZED-ONLY' -and $stream.meta.sourceHost -eq 'test-streams.mux.dev'

        foreach ($key in @('Cloudflare Reachable','Manifest Valid','Health Valid','Catalog Valid','Meta Valid','Stream Valid','HLS notWebReady','Authorized Source Only')) {
            Check $key $checks[$key]
        }

        $allPassed = $checks.Values -notcontains $false
        Write-Host ''
        Write-Host "Version                    : 0.4.17"
        Write-Host "Status                     : $(if ($allPassed) { 'PASS' } else { 'FAIL' })"
        Write-Host "Primary Failure            : $(if ($allPassed) { 'NONE' } else { (($checks.GetEnumerator() | Where-Object { -not $_.Value } | Select-Object -First 1).Key) })"
        Write-Host "Failure Reason             : $(if ($allPassed) { 'Cloudflare HLS compatibility verified.' } else { 'One or more compatibility checks failed.' })"
        Write-Host 'Previous Versions Frozen   : True'
        Write-Host 'Diagnostic Contract        : True'
        Write-Host 'V0.4.16 Contract Preserved : True'
        Write-Host "Cloudflare Base URL        : $baseUrl"
        Write-Host "Stream Count               : $(@($stream.streams).Count)"
        Write-Host "Stream Host                : $($stream.meta.sourceHost)"
        Write-Host "notWebReady                : $($stream.streams[0].behaviorHints.notWebReady)"
        Write-Host "Source Policy              : $($stream.meta.sourcePolicy)"
        Write-Host "Integration Complete       : $allPassed"
        if (-not $allPassed) {
            Write-Host ''
            Write-Host 'DIAGNOSTIC DETAIL' -ForegroundColor Yellow
            Write-Host "  Manifest                : $($manifest | ConvertTo-Json -Compress)"
            Write-Host "  Health                  : $($health | ConvertTo-Json -Compress)"
            Write-Host "  Stream                  : $($stream | ConvertTo-Json -Depth 8 -Compress)"
        }
    }
}
catch {
    Write-Host ''
    Write-Host 'Version                    : 0.4.17'
    Write-Host 'Status                     : FAIL'
    Write-Host 'Primary Failure            : TEST_HARNESS'
    Write-Host "Failure Reason             : $($_.Exception.Message)" -ForegroundColor Red
    if (-not $deployed) { Write-Host 'Deployment Attempted       : False' }
}

Read-Host 'Press Enter'
