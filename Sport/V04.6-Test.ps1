$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot=Join-Path $projectRoot 'V04.AddonServer'
$addonScript=Join-Path $addonRoot 'addon.js'
$port=7000
$base="http://127.0.0.1:$port"
$eventId='2397275'
$process=$null

function Get-JsonEndpoint {
 param([Parameter(Mandatory)][string]$Url)
 $response=Invoke-WebRequest -Uri $Url -Method Get -UseBasicParsing -TimeoutSec 10
 if($response.StatusCode -ne 200){throw "HTTP $($response.StatusCode) from $Url"}
 $response.Content | ConvertFrom-Json
}

Write-Host '==============================================='
Write-Host '       VIETNAM SPORTS HUB - V0.4.6'
Write-Host '       FULL STREMIO INTEGRATION'
Write-Host '==============================================='
try {
 $node=Get-Command node -ErrorAction SilentlyContinue
 if(-not $node){throw 'Node.js is not installed or not available on PATH.'}
 if(-not (Test-Path $addonScript)){throw "Addon server not found: $addonScript"}

 $process=Start-Process -FilePath $node.Source -ArgumentList @($addonScript) -WorkingDirectory $addonRoot -PassThru -WindowStyle Hidden
 Start-Sleep -Milliseconds 1200

 $manifest=Get-JsonEndpoint -Url "$base/manifest.json"
 $health=Get-JsonEndpoint -Url "$base/health"
 $catalog=Get-JsonEndpoint -Url "$base/catalog/tv/vietnam-sports.json"
 $meta=Get-JsonEndpoint -Url "$base/meta/tv/sports:event:$eventId.json"
 $stream=Get-JsonEndpoint -Url "$base/stream/tv/sports:event:$eventId.json"

 $catalogCount=@($catalog.metas).Count
 $catalogValid=$catalogCount -gt 0 -and (@($catalog.metas) | Where-Object { $_.type -ne 'tv' }).Count -eq 0
 $metaValid=$null -ne $meta.meta -and $meta.meta.id -eq "sports:event:$eventId" -and $meta.meta.type -eq 'tv'
 $streamCount=@($stream.streams).Count
 $streamValid=$streamCount -gt 0 -and (@($stream.streams) | Where-Object { $_.url -notmatch '^https?://' }).Count -eq 0
 $authorized=$stream.meta.sourcePolicy -eq 'AUTHORIZED-ONLY'
 $manifestValid=$manifest.id -eq 'org.vietnam.sports.hub' -and $manifest.version -eq '0.4.1'
 $healthValid=$health.status -eq 'OK'
 $allPass=$manifestValid -and $healthValid -and $catalogValid -and $metaValid -and $streamValid -and $authorized

 Write-Host "Version                 : 0.4.6"
 Write-Host "Status                  : $(if($allPass){'PASS'}else{'FAIL'})"
 Write-Host "Server Started          : True"
 Write-Host "Manifest                : $manifestValid"
 Write-Host "Health                  : $healthValid"
 Write-Host "Catalog Endpoint        : $catalogValid"
 Write-Host "Catalog Count            : $catalogCount"
 Write-Host "Meta Endpoint           : $metaValid"
 Write-Host "Meta Event ID           : $($meta.meta.id)"
 Write-Host "Stream Endpoint         : $streamValid"
 Write-Host "Stream Count            : $streamCount"
 Write-Host "Authorized Source Only  : $authorized"
 Write-Host "Integration Complete    : $allPass"
 Write-Host "Base URL                : $base"
 Write-Host "Manifest URL            : $base/manifest.json"
}
catch {
 Write-Host 'Version                 : 0.4.6'
 Write-Host 'Status                  : FAIL' -ForegroundColor Red
 Write-Host "Error                   : $($_.Exception.Message)" -ForegroundColor Red
}
finally {
 if($process -and -not $process.HasExited){Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue}
}

Read-Host 'Press Enter'
