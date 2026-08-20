# Vietnam Sports Hub - V0.4.1 Stremio manifest contract

Set-StrictMode -Version Latest

$script:ModuleVersion = '0.4.1'
$script:ModuleName = 'V04.Stremio'
$script:FixturePath = Join-Path $PSScriptRoot '..\..\TestFixtures\V04.1.Manifest.json'

function Get-V041ManifestContract {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        ManifestRequired = $true
        Resources = @('catalog','meta','stream')
        ContentType = 'tv'
        IdPrefix = 'sports:event:'
        CatalogId = 'vietnam-sports'
        SearchSupported = $true
        UserConfigRequired = $false
        LiveContent = $true
        LocalCacheCompatible = $true
        OnDemandStreams = $true
    }
}

function Get-V041ManifestFixture {
    [CmdletBinding()]
    param()

    if (-not (Test-Path $script:FixturePath)) {
        throw "V0.4.1 manifest fixture was not found: $script:FixturePath"
    }

    Get-Content -Path $script:FixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Test-V041ManifestContract {
    [CmdletBinding()]
    param()

    $status = [ordered]@{
        Version = $script:ModuleVersion
        Status = 'FAIL'
        ManifestLoaded = $false
        RequiredFields = $false
        ResourcesValid = $false
        TypesValid = $false
        CatalogValid = $false
        IdPrefixesValid = $false
        SearchSupported = $false
        LiveType = $false
        Error = $null
    }

    try {
        $manifest = Get-V041ManifestFixture
        $status.ManifestLoaded = $true

        $required = @('id','name','description','version','resources','types','catalogs')
        $status.RequiredFields = ($required | Where-Object {
            $manifest.PSObject.Properties[$_]
        }).Count -eq $required.Count

        $status.ResourcesValid = @('catalog','meta','stream') | ForEach-Object {
            $manifest.resources -contains $_
        } | Where-Object { $_ -eq $false } | Measure-Object | Select-Object -ExpandProperty Count
        $status.ResourcesValid = ([int]$status.ResourcesValid -eq 0)

        $status.TypesValid = @($manifest.types).Count -eq 1 -and $manifest.types[0] -eq 'tv'
        $status.CatalogValid = @($manifest.catalogs).Count -ge 1 -and [string]$manifest.catalogs[0].id -eq 'vietnam-sports' -and [string]$manifest.catalogs[0].type -eq 'tv'
        $status.IdPrefixesValid = @($manifest.idPrefixes).Count -eq 1 -and $manifest.idPrefixes[0] -eq 'sports:event:'
        $status.SearchSupported = @($manifest.catalogs[0].extra).Count -ge 1 -and @($manifest.catalogs[0].extra | Where-Object { $_.name -eq 'search' }).Count -eq 1
        $status.LiveType = ($manifest.types -contains 'tv')

        if (-not $status.RequiredFields) { throw 'Manifest required fields are incomplete.' }
        if (-not $status.ResourcesValid) { throw 'Manifest resources must include catalog, meta and stream.' }
        if (-not $status.TypesValid) { throw 'Manifest content type must be tv.' }
        if (-not $status.CatalogValid) { throw 'Manifest catalog definition is invalid.' }
        if (-not $status.IdPrefixesValid) { throw 'Manifest idPrefixes must contain sports:event:.' }
        if (-not $status.SearchSupported) { throw 'Catalog search support is missing.' }

        $status.Status = 'PASS'
    } catch {
        $status.Error = $_.Exception.Message
    }

    [PSCustomObject]$status
}

function Get-V041Status {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Module = $script:ModuleName
        Version = $script:ModuleVersion
        Status = 'DEVELOPMENT'
        Frozen = $false
        DependsOn = @('V0.2.1 Catalog', 'V0.2.3 Meta', 'V0.2.4 Stream', 'V0.3 Live Lifecycle')
    }
}

Export-ModuleMember -Function @(
    'Get-V041ManifestContract',
    'Get-V041ManifestFixture',
    'Test-V041ManifestContract',
    'Get-V041Status'
)
