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

function Add-ResultPrefixColumns {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Rows,

        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$PrefixColumns
    )

    $output = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($row in $Rows) {
        $ordered = [ordered]@{}
        foreach ($key in $PrefixColumns.Keys) {
            $ordered[$key] = $PrefixColumns[$key]
        }
        foreach ($prop in $row.PSObject.Properties) {
            $ordered[$prop.Name] = $prop.Value
        }
        $output.Add([pscustomobject]$ordered)
    }

    $result = @($output.ToArray())
    return $result
}

function Get-ResultCsvPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RunFolder,

        [Parameter(Mandatory)]
        [string]$ServerName,

        [string]$DatabaseName = '',

        [Parameter(Mandatory)]
        [int]$QueryNumber,

        [Parameter(Mandatory)]
        [string]$ShortName
    )

    $invalidChars = [regex]::Escape(([System.IO.Path]::GetInvalidFileNameChars() -join ''))
    $pattern = "[$invalidChars]"

    $safeServer = $ServerName -replace $pattern, '-'
    $safeShort = $ShortName -replace $pattern, '-'

    if ([string]::IsNullOrEmpty($DatabaseName)) {
        $fileName = '{0}-Query-{1}-{2}.csv' -f $safeServer, $QueryNumber, $safeShort
    }
    else {
        $safeDb = $DatabaseName -replace $pattern, '-'
        $fileName = '{0}-{1}-Query-{2}-{3}.csv' -f $safeServer, $safeDb, $QueryNumber, $safeShort
    }

    return Join-Path $RunFolder $fileName
}

function Build-DiagnosticConnectionString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServerName,

        [string]$Database = 'master'
    )

    return "Server=$ServerName;Database=$Database;Integrated Security=True;Encrypt=Mandatory;TrustServerCertificate=True;Connection Timeout=15"
}

function Get-OnlineUserDatabaseNames {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$DatabaseRows,

        [string[]]$ExcludedDatabases = @()
    )

    $result = @(
        $DatabaseRows |
            Where-Object { $_.database_id -gt 4 -and $_.state_desc -eq 'ONLINE' -and ($ExcludedDatabases -notcontains $_.name) } |
            Sort-Object name |
            ForEach-Object { $_.name }
    )
    return $result
}

Export-ModuleMember -Function Get-VersionFolderName, Read-DiagnosticManifest, Get-FilteredManifestQueries, Add-ResultPrefixColumns, Get-ResultCsvPath, Build-DiagnosticConnectionString, Get-OnlineUserDatabaseNames
