function Get-VersionFolderName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$ProductMajorVersion
    )

    $map = @{
        13 = 'SQL Server 2016 SP2'
        16 = 'SQL Server 2022'
    }

    if ($map.ContainsKey($ProductMajorVersion)) {
        return $map[$ProductMajorVersion]
    }
    return $null
}

function Read-DiagnosticManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath
    )

    $parsed = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    $result = @($parsed)
    return $result
}

function Get-FilteredManifestQueries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$ManifestQueries,

        [Parameter(Mandatory)]
        [ValidateSet('Instance', 'Database')]
        [string]$Scope,

        [int[]]$ExcludedQueryNumbers = @()
    )

    $result = @($ManifestQueries |
        Where-Object { $_.Scope -eq $Scope -and -not ($ExcludedQueryNumbers -contains $_.Number) } |
        Sort-Object Number)
    return $result
}

Export-ModuleMember -Function Get-VersionFolderName, Read-DiagnosticManifest, Get-FilteredManifestQueries
