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

    return "Server=$ServerName;Database=$Database;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connection Timeout=15"
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

function Invoke-SqlFileQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionString,

        [Parameter(Mandatory)]
        [string]$QueryFilePath
    )

    $rows = @(Invoke-Sqlcmd -ConnectionString $ConnectionString -InputFile $QueryFilePath -ErrorAction Stop)

    $result = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($row in $rows) {
        $ordered = [ordered]@{}
        foreach ($col in $row.Table.Columns) {
            $ordered[$col.ColumnName] = $row[$col]
        }
        $result.Add([pscustomobject]$ordered)
    }

    $output = @($result.ToArray())
    return $output
}

function Invoke-DiagnosticRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServersConfigPath,

        [Parameter(Mandatory)]
        [string]$ExclusionsConfigPath,

        [Parameter(Mandatory)]
        [string]$QueryLibraryRoot,

        [Parameter(Mandatory)]
        [string]$RunFolder
    )

    New-Item -ItemType Directory -Path $RunFolder -Force | Out-Null

    $servers = @(Get-Content -LiteralPath $ServersConfigPath -Raw | ConvertFrom-Json)
    $exclusions = Get-Content -LiteralPath $ExclusionsConfigPath -Raw | ConvertFrom-Json
    $excludedDatabases = @($exclusions.ExcludedDatabases)
    $excludedQueryNumbers = @($exclusions.ExcludedQueryNumbers)

    $errors = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($server in $servers) {
        $serverName = $server.ServerName
        Write-Host "=== $serverName ==="

        $connStr = Build-DiagnosticConnectionString -ServerName $serverName

        $majorVersion = $null
        try {
            $verRow = Invoke-Sqlcmd -ConnectionString $connStr -Query "SELECT CONVERT(int, SERVERPROPERTY('ProductMajorVersion')) AS MajorVersion" -ErrorAction Stop
            $majorVersion = [int]$verRow.MajorVersion
        }
        catch {
            $errors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = ''; QueryNumber = ''; ShortName = ''; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
            continue
        }

        $versionFolder = Get-VersionFolderName -ProductMajorVersion $majorVersion
        if (-not $versionFolder) {
            $errors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = ''; QueryNumber = ''; ShortName = ''; ErrorMessage = "No query library for ProductMajorVersion $majorVersion"; Timestamp = (Get-Date -Format o) })
            continue
        }

        $versionRoot = Join-Path $QueryLibraryRoot $versionFolder
        $manifest = Read-DiagnosticManifest -ManifestPath (Join-Path $versionRoot 'manifest.json')

        $instanceQueries = Get-FilteredManifestQueries -ManifestQueries $manifest -Scope 'Instance' -ExcludedQueryNumbers $excludedQueryNumbers
        $databaseQueries = Get-FilteredManifestQueries -ManifestQueries $manifest -Scope 'Database' -ExcludedQueryNumbers $excludedQueryNumbers

        foreach ($q in $instanceQueries) {
            try {
                $rows = @(Invoke-SqlFileQuery -ConnectionString $connStr -QueryFilePath (Join-Path $versionRoot $q.File))
                $csvPath = Get-ResultCsvPath -RunFolder $RunFolder -ServerName $serverName -QueryNumber $q.Number -ShortName $q.ShortName
                $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
            }
            catch {
                $errors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = ''; QueryNumber = $q.Number; ShortName = $q.ShortName; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
            }
        }

        try {
            $dbRows = @(Invoke-Sqlcmd -ConnectionString $connStr -Query 'SELECT name, database_id, state_desc FROM sys.databases' -ErrorAction Stop)
        }
        catch {
            $errors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = ''; QueryNumber = ''; ShortName = ''; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
            continue
        }

        $databaseNames = Get-OnlineUserDatabaseNames -DatabaseRows $dbRows -ExcludedDatabases $excludedDatabases

        foreach ($dbName in $databaseNames) {
            $dbConnStr = Build-DiagnosticConnectionString -ServerName $serverName -Database $dbName

            foreach ($q in $databaseQueries) {
                try {
                    $rows = @(Invoke-SqlFileQuery -ConnectionString $dbConnStr -QueryFilePath (Join-Path $versionRoot $q.File))
                    $prefixed = Add-ResultPrefixColumns -Rows $rows -PrefixColumns ([ordered]@{ ServerName = $serverName; DatabaseName = $dbName })
                    $csvPath = Get-ResultCsvPath -RunFolder $RunFolder -ServerName $serverName -DatabaseName $dbName -QueryNumber $q.Number -ShortName $q.ShortName
                    $prefixed | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
                }
                catch {
                    $errors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = $dbName; QueryNumber = $q.Number; ShortName = $q.ShortName; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
                }
            }
        }
    }

    if ($errors.Count -gt 0) {
        $errors | Export-Csv -LiteralPath (Join-Path $RunFolder 'errors.csv') -NoTypeInformation -Encoding UTF8
    }

    return [pscustomobject]@{ RunFolder = $RunFolder; ErrorCount = $errors.Count }
}

Export-ModuleMember -Function Get-VersionFolderName, Read-DiagnosticManifest, Get-FilteredManifestQueries, Add-ResultPrefixColumns, Get-ResultCsvPath, Build-DiagnosticConnectionString, Get-OnlineUserDatabaseNames, Invoke-SqlFileQuery, Invoke-DiagnosticRun
