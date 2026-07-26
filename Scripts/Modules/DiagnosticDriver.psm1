function Get-VersionFolderName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$ProductMajorVersion,

        [Parameter(Mandatory)]
        [string]$QueryLibraryRoot
    )

    $map = @{
        13 = 'SQL Server 2016 SP2'
        14 = 'SQL Server 2017'
        15 = 'SQL Server 2019'
        16 = 'SQL Server 2022'
        17 = 'SQL Server 2025'
    }

    if (-not $map.ContainsKey($ProductMajorVersion)) {
        return $null
    }

    $folderPath = Join-Path $QueryLibraryRoot $map[$ProductMajorVersion]
    if (-not (Test-Path -LiteralPath $folderPath -PathType Container)) {
        return $null
    }
    return $map[$ProductMajorVersion]
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

function Get-SanitizedFileSystemName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $invalidChars = [regex]::Escape(([System.IO.Path]::GetInvalidFileNameChars() -join ''))
    return ($Name -replace "[$invalidChars]", '-')
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

    $safeServer = Get-SanitizedFileSystemName -Name $ServerName
    $safeShort = Get-SanitizedFileSystemName -Name $ShortName

    if ([string]::IsNullOrEmpty($DatabaseName)) {
        $fileName = '{0}-Query-{1}-{2}.csv' -f $safeServer, $QueryNumber, $safeShort
    }
    else {
        $safeDb = Get-SanitizedFileSystemName -Name $DatabaseName
        $fileName = '{0}-{1}-Query-{2}-{3}.csv' -f $safeServer, $safeDb, $QueryNumber, $safeShort
    }

    return Join-Path $RunFolder $fileName
}

function New-DiagnosticConnectionString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServerName,

        [string]$Database = 'master',

        [bool]$Encrypt = $true
    )

    $encryptValue = if ($Encrypt) { 'True' } else { 'False' }
    return "Server=$ServerName;Database=$Database;Integrated Security=True;Encrypt=$encryptValue;TrustServerCertificate=True;Connection Timeout=15"
}

function Test-ServerConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServerName
    )

    $lastError = $null
    foreach ($encrypt in @($true, $false)) {
        $connStr = New-DiagnosticConnectionString -ServerName $ServerName -Encrypt $encrypt
        try {
            Invoke-Sqlcmd -ConnectionString $connStr -Query 'SELECT @@VERSION;' -ErrorAction Stop | Out-Null
            return [pscustomobject]@{ Success = $true; ConnectionString = $connStr; Encrypt = $encrypt; ErrorMessage = $null }
        }
        catch {
            $lastError = $_.Exception.Message
        }
    }
    return [pscustomobject]@{ Success = $false; ConnectionString = $null; Encrypt = $null; ErrorMessage = $lastError }
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

    $serversJson = Get-Content -LiteralPath $ServersConfigPath -Raw | ConvertFrom-Json
    $servers = @($serversJson)
    $exclusions = Get-Content -LiteralPath $ExclusionsConfigPath -Raw | ConvertFrom-Json
    $excludedDatabases = @($exclusions.ExcludedDatabases)
    $excludedQueryNumbers = @($exclusions.ExcludedQueryNumbers)

    $totalErrorCount = 0

    foreach ($server in $servers) {
        $serverName = $server.ServerName
        Write-Host "=== $serverName ==="

        $serverFolder = Join-Path $RunFolder (Get-SanitizedFileSystemName -Name $serverName)
        New-Item -ItemType Directory -Path $serverFolder -Force | Out-Null

        $serverErrors = [System.Collections.Generic.List[pscustomobject]]::new()

        $connectionResult = Test-ServerConnection -ServerName $serverName
        if (-not $connectionResult.Success) {
            $serverErrors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = ''; QueryNumber = ''; ShortName = ''; ErrorMessage = $connectionResult.ErrorMessage; Timestamp = (Get-Date -Format o) })
            $serverErrors | Export-Csv -LiteralPath (Join-Path $serverFolder 'errors.csv') -NoTypeInformation -Encoding UTF8
            $totalErrorCount += $serverErrors.Count
            continue
        }

        $connStr = $connectionResult.ConnectionString
        $encrypt = $connectionResult.Encrypt

        $majorVersion = $null
        try {
            $verRow = Invoke-Sqlcmd -ConnectionString $connStr -Query "SELECT CONVERT(int, SERVERPROPERTY('ProductMajorVersion')) AS MajorVersion" -ErrorAction Stop
            $majorVersion = [int]$verRow.MajorVersion
        }
        catch {
            $serverErrors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = ''; QueryNumber = ''; ShortName = ''; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
            $serverErrors | Export-Csv -LiteralPath (Join-Path $serverFolder 'errors.csv') -NoTypeInformation -Encoding UTF8
            $totalErrorCount += $serverErrors.Count
            continue
        }

        $versionFolder = Get-VersionFolderName -ProductMajorVersion $majorVersion -QueryLibraryRoot $QueryLibraryRoot
        if (-not $versionFolder) {
            $serverErrors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = ''; QueryNumber = ''; ShortName = ''; ErrorMessage = "No query library for ProductMajorVersion $majorVersion"; Timestamp = (Get-Date -Format o) })
            $serverErrors | Export-Csv -LiteralPath (Join-Path $serverFolder 'errors.csv') -NoTypeInformation -Encoding UTF8
            $totalErrorCount += $serverErrors.Count
            continue
        }

        $versionRoot = Join-Path $QueryLibraryRoot $versionFolder
        $manifest = Read-DiagnosticManifest -ManifestPath (Join-Path $versionRoot 'manifest.json')

        $instanceQueries = Get-FilteredManifestQueries -ManifestQueries $manifest -Scope 'Instance' -ExcludedQueryNumbers $excludedQueryNumbers
        $databaseQueries = Get-FilteredManifestQueries -ManifestQueries $manifest -Scope 'Database' -ExcludedQueryNumbers $excludedQueryNumbers

        foreach ($q in $instanceQueries) {
            try {
                $rows = @(Invoke-SqlFileQuery -ConnectionString $connStr -QueryFilePath (Join-Path $versionRoot $q.File))
                $csvPath = Get-ResultCsvPath -RunFolder $serverFolder -ServerName $serverName -QueryNumber $q.Number -ShortName $q.ShortName
                $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
            }
            catch {
                $serverErrors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = ''; QueryNumber = $q.Number; ShortName = $q.ShortName; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
            }
        }

        try {
            $dbRows = @(Invoke-Sqlcmd -ConnectionString $connStr -Query 'SELECT name, database_id, state_desc FROM sys.databases' -ErrorAction Stop)
        }
        catch {
            $serverErrors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = ''; QueryNumber = ''; ShortName = ''; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
            if ($serverErrors.Count -gt 0) {
                $serverErrors | Export-Csv -LiteralPath (Join-Path $serverFolder 'errors.csv') -NoTypeInformation -Encoding UTF8
            }
            $totalErrorCount += $serverErrors.Count
            continue
        }

        $databaseNames = Get-OnlineUserDatabaseNames -DatabaseRows $dbRows -ExcludedDatabases $excludedDatabases

        foreach ($dbName in $databaseNames) {
            $dbConnStr = New-DiagnosticConnectionString -ServerName $serverName -Database $dbName -Encrypt $encrypt

            foreach ($q in $databaseQueries) {
                try {
                    $rows = @(Invoke-SqlFileQuery -ConnectionString $dbConnStr -QueryFilePath (Join-Path $versionRoot $q.File))
                    $prefixed = Add-ResultPrefixColumns -Rows $rows -PrefixColumns ([ordered]@{ ServerName = $serverName; DatabaseName = $dbName })
                    $csvPath = Get-ResultCsvPath -RunFolder $serverFolder -ServerName $serverName -DatabaseName $dbName -QueryNumber $q.Number -ShortName $q.ShortName
                    $prefixed | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
                }
                catch {
                    $serverErrors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = $dbName; QueryNumber = $q.Number; ShortName = $q.ShortName; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
                }
            }
        }

        if ($serverErrors.Count -gt 0) {
            $serverErrors | Export-Csv -LiteralPath (Join-Path $serverFolder 'errors.csv') -NoTypeInformation -Encoding UTF8
        }
        $totalErrorCount += $serverErrors.Count
    }

    return [pscustomobject]@{ RunFolder = $RunFolder; ErrorCount = $totalErrorCount }
}

Export-ModuleMember -Function Get-VersionFolderName, Read-DiagnosticManifest, Get-FilteredManifestQueries, Add-ResultPrefixColumns, Get-SanitizedFileSystemName, Get-ResultCsvPath, New-DiagnosticConnectionString, Test-ServerConnection, Get-OnlineUserDatabaseNames, Invoke-SqlFileQuery, Invoke-DiagnosticRun
