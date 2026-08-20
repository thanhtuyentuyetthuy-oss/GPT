Set-StrictMode -Version Latest
$script:Version='0.4.4'
$script:SportRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:RepoRoot = Split-Path $script:SportRoot -Parent
$script:CacheRoot=Join-Path $script:RepoRoot 'Data\Cache\V02.Meta'

function Get-MetaCachePath {
 param([Parameter(Mandatory)][string]$EventId)
 if(-not (Test-Path $script:CacheRoot)){ return $null }
 $path=Join-Path $script:CacheRoot ("event-{0}.json" -f $EventId)
 if(Test-Path $path){ return $path }
 return $null
}

function ConvertTo-StremioMeta {
 param([Parameter(Mandatory)]$Item,[Parameter(Mandatory)][string]$EventId)
 $name = if($Item.PSObject.Properties['strEvent'] -and $Item.strEvent){[string]$Item.strEvent}elseif($Item.PSObject.Properties['eventName'] -and $Item.eventName){[string]$Item.eventName}else{'Selected Match'}
 $league = if($Item.PSObject.Properties['strLeague']){[string]$Item.strLeague}else{''}
 $thumb = if($Item.PSObject.Properties['strThumb']){[string]$Item.strThumb}else{''}
 $dateEvent = if($Item.PSObject.Properties['dateEvent']){$Item.dateEvent}else{$null}
 $id="sports:event:$EventId"
 [PSCustomObject]@{
   meta=[PSCustomObject]@{
     id=$id; type='tv'; name=$name
     description=$league
     poster=$thumb
     videos=@([PSCustomObject]@{ id=$id; title=$name; released=$dateEvent })
   }
 }
}

function Get-V044MetaOnDemand {
 [CmdletBinding()]param([Parameter(Mandatory)][string]$EventId)
 $cache=Get-MetaCachePath -EventId $EventId
 if(-not $cache){ throw "V0.2.3 meta cache not found for event $EventId. Run V0.2.3 Select/Meta test first. Expected cache root: $script:CacheRoot" }
 $payload=Get-Content -Path $cache -Raw -Encoding UTF8 | ConvertFrom-Json
 $item=$null
 if($payload.PSObject.Properties['event'] -and $payload.event){ $item=$payload.event }
 elseif($payload.PSObject.Properties['meta'] -and $payload.meta){ $item=$payload.meta }
 else { $item=$payload }
 if($null -eq $item){ throw "Meta cache payload contains no event metadata: $cache" }
 $stremioMeta=ConvertTo-StremioMeta -Item $item -EventId $EventId
 [PSCustomObject]@{Version=$script:Version;Status='PASS';Source='V0.2.3 META CACHE ONLY';EventId=$EventId;MetaCacheRead=$true;ApiRequests=0;MetaLoaded=$true;StremioMeta=$stremioMeta;MetaCachePath=$cache}
}

function Test-V044MetaAdapter {
 [CmdletBinding()]param([Parameter(Mandatory)][string]$EventId)
 try { $r=Get-V044MetaOnDemand -EventId $EventId
   [PSCustomObject]@{Version=$r.Version;Status='PASS';Source=$r.Source;EventId=$r.EventId;MetaCacheRead=$r.MetaCacheRead;ApiRequests=$r.ApiRequests;MetaLoaded=$r.MetaLoaded;StremioMetaValid=($r.StremioMeta.PSObject.Properties['meta'] -and $r.StremioMeta.meta.PSObject.Properties['id'] -and $r.StremioMeta.meta.id -eq "sports:event:$EventId" -and $r.StremioMeta.meta.PSObject.Properties['type'] -and $r.StremioMeta.meta.type -eq 'tv');MetaCachePath=$r.MetaCachePath}
 } catch { [PSCustomObject]@{Version=$script:Version;Status='FAIL';Source='V0.2.3 META CACHE ONLY';EventId=$EventId;MetaCacheRead=$false;ApiRequests=0;MetaLoaded=$false;StremioMetaValid=$false;MetaCachePath=$null;Error=$_.Exception.Message} }
}

Export-ModuleMember -Function Get-V044MetaOnDemand,Test-V044MetaAdapter
