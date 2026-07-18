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

function Invoke-SqlFileQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$QueryFilePath
    )

    $commandText = Get-Content -LiteralPath $QueryFilePath -Raw
    $command = $Connection.CreateCommand()
    $command.CommandText = $commandText
    $command.CommandTimeout = 120

    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
    $table = New-Object System.Data.DataTable
    [void]$adapter.Fill($table)

    $rows = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($row in $table.Rows) {
        $ordered = [ordered]@{}
        foreach ($col in $table.Columns) {
            $ordered[$col.ColumnName] = $row[$col]
        }
        $rows.Add([pscustomobject]$ordered)
    }

    $result = @($rows.ToArray())
    return $result
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

        $majorVersion = $null
        try {
            $conn = New-Object System.Data.SqlClient.SqlConnection (Build-DiagnosticConnectionString -ServerName $serverName)
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT CONVERT(int, SERVERPROPERTY('ProductMajorVersion'))"
            $majorVersion = [int]$cmd.ExecuteScalar()
            $conn.Close()
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

        $conn = New-Object System.Data.SqlClient.SqlConnection (Build-DiagnosticConnectionString -ServerName $serverName)
        try {
            $conn.Open()
        }
        catch {
            $errors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = ''; QueryNumber = ''; ShortName = ''; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
            continue
        }

        foreach ($q in $instanceQueries) {
            try {
                $rows = Invoke-SqlFileQuery -Connection $conn -QueryFilePath (Join-Path $versionRoot $q.File)
                $csvPath = Get-ResultCsvPath -RunFolder $RunFolder -ServerName $serverName -QueryNumber $q.Number -ShortName $q.ShortName
                $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
            }
            catch {
                $errors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = ''; QueryNumber = $q.Number; ShortName = $q.ShortName; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
            }
        }

        $dbTable = New-Object System.Data.DataTable
        try {
            $dbCmd = $conn.CreateCommand()
            $dbCmd.CommandText = 'SELECT name, database_id, state_desc FROM sys.databases'
            $dbAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $dbCmd
            [void]$dbAdapter.Fill($dbTable)
        }
        catch {
            $errors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = ''; QueryNumber = ''; ShortName = ''; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
            $conn.Close()
            continue
        }
        $conn.Close()

        $databaseRows = foreach ($row in $dbTable.Rows) {
            [pscustomobject]@{ name = $row['name']; database_id = $row['database_id']; state_desc = $row['state_desc'] }
        }
        $databaseNames = Get-OnlineUserDatabaseNames -DatabaseRows @($databaseRows) -ExcludedDatabases $excludedDatabases

        foreach ($dbName in $databaseNames) {
            $dbConn = New-Object System.Data.SqlClient.SqlConnection (Build-DiagnosticConnectionString -ServerName $serverName -Database $dbName)
            try {
                $dbConn.Open()
            }
            catch {
                $errors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = $dbName; QueryNumber = ''; ShortName = ''; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
                continue
            }

            foreach ($q in $databaseQueries) {
                try {
                    $rows = Invoke-SqlFileQuery -Connection $dbConn -QueryFilePath (Join-Path $versionRoot $q.File)
                    $prefixed = Add-ResultPrefixColumns -Rows $rows -PrefixColumns ([ordered]@{ ServerName = $serverName; DatabaseName = $dbName })
                    $csvPath = Get-ResultCsvPath -RunFolder $RunFolder -ServerName $serverName -DatabaseName $dbName -QueryNumber $q.Number -ShortName $q.ShortName
                    $prefixed | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
                }
                catch {
                    $errors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = $dbName; QueryNumber = $q.Number; ShortName = $q.ShortName; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
                }
            }

            $dbConn.Close()
        }
    }

    if ($errors.Count -gt 0) {
        $errors | Export-Csv -LiteralPath (Join-Path $RunFolder 'errors.csv') -NoTypeInformation -Encoding UTF8
    }

    return [pscustomobject]@{ RunFolder = $RunFolder; ErrorCount = $errors.Count }
}

Export-ModuleMember -Function Get-VersionFolderName, Read-DiagnosticManifest, Get-FilteredManifestQueries, Add-ResultPrefixColumns, Get-ResultCsvPath, Build-DiagnosticConnectionString, Get-OnlineUserDatabaseNames, Invoke-SqlFileQuery, Invoke-DiagnosticRun
