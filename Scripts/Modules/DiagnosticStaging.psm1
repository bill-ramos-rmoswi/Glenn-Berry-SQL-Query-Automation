function Get-DiagnosticStagingCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Protocol,

        [Parameter(Mandatory)]
        [string]$HostName,

        [Parameter(Mandatory)]
        [string]$Path
    )

    # PowerShell has no native `<` stdin-redirection operator, and both a plain pipe
    # (`$lines | git credential fill`) and a manually-redirected .NET Process.StandardInput
    # stream (even with an explicit no-BOM UTF8Encoding StreamWriter) prepend a UTF-8 BOM that
    # corrupts the first "protocol=..." line and makes git reject the request. Writing the
    # request to a BOM-less temp file and shelling out through cmd.exe for real OS-level
    # redirection is the reliable path here (see CLAUDE.md PowerShell lessons learned).
    $tmpFile = [System.IO.Path]::GetTempFileName()
    try {
        $requestText = "protocol=$Protocol`nhost=$HostName`npath=$Path`n`n"
        [System.IO.File]::WriteAllText($tmpFile, $requestText, [System.Text.UTF8Encoding]::new($false))

        $output = & cmd /c "git credential fill < `"$tmpFile`"" 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        Remove-Item -LiteralPath $tmpFile -ErrorAction SilentlyContinue
    }

    if ($exitCode -ne 0) {
        throw "git credential fill failed (exit $exitCode) for protocol=$Protocol host=$HostName path=$Path`: $($output -join [Environment]::NewLine)"
    }

    $fields = @{}
    foreach ($line in $output) {
        if ($line -match '^(?<key>[^=]+)=(?<value>.*)$') {
            $fields[$Matches['key']] = $Matches['value']
        }
    }

    if (-not $fields.ContainsKey('username') -or -not $fields.ContainsKey('password')) {
        throw "git credential fill did not return a username/password for protocol=$Protocol host=$HostName path=$Path"
    }

    return [pscustomobject]@{
        Username = $fields['username']
        Password = $fields['password']
    }
}

function New-DiagnosticSqlAuthConnectionString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServerName,

        [string]$Database = 'master',

        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [string]$Password,

        [bool]$Encrypt = $true
    )

    $encryptValue = if ($Encrypt) { 'True' } else { 'False' }
    return "Server=$ServerName;Database=$Database;User Id=$Username;Password=$Password;Encrypt=$encryptValue;TrustServerCertificate=True;Connection Timeout=15"
}

function Get-StagingTableName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShortName
    )

    $sanitized = ($ShortName -replace '[^A-Za-z0-9]+', '_').Trim('_')
    if ([string]::IsNullOrEmpty($sanitized)) {
        throw "ShortName '$ShortName' sanitizes to an empty table name."
    }
    if ($sanitized -match '^[0-9]') {
        $sanitized = "T_$sanitized"
    }
    return "stg.$sanitized"
}

function Get-DiagnosticRunTimestamp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RunFolderName
    )

    $parsed = [datetime]::MinValue
    $ok = [datetime]::TryParseExact(
        $RunFolderName, 'yyyyMMdd_HHmmss', [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None, [ref]$parsed)

    if (-not $ok) {
        throw "Run folder name '$RunFolderName' is not in the expected 'yyyyMMdd_HHmmss' format."
    }
    return $parsed
}

function Get-DiagnosticResultCsvMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServerFolderName,

        [Parameter(Mandatory)]
        [string]$FileName
    )

    if ($FileName -eq 'errors.csv') {
        return [pscustomobject]@{
            IsErrorsFile = $true
            DatabaseName = $null
            QueryNumber  = $null
            ShortName    = $null
        }
    }

    $prefix = "$ServerFolderName-"
    if (-not $FileName.StartsWith($prefix)) {
        throw "File name '$FileName' does not start with the server folder prefix '$prefix'."
    }
    $remainder = $FileName.Substring($prefix.Length)

    # Instance-scope files are '<Server>-Query-<N>-<ShortName>.csv'; database-scope files are
    # '<Server>-<Database>-Query-<N>-<ShortName>.csv'. Both server and database names may
    # themselves contain hyphens, so the literal 'Query-' token (not position) disambiguates.
    if ($remainder -match '^Query-(?<num>\d+)-(?<short>.+)\.csv$') {
        return [pscustomobject]@{
            IsErrorsFile = $false
            DatabaseName = $null
            QueryNumber  = [int]$Matches['num']
            ShortName    = $Matches['short']
        }
    }
    elseif ($remainder -match '^(?<db>.+?)-Query-(?<num>\d+)-(?<short>.+)\.csv$') {
        return [pscustomobject]@{
            IsErrorsFile = $false
            DatabaseName = $Matches['db']
            QueryNumber  = [int]$Matches['num']
            ShortName    = $Matches['short']
        }
    }
    else {
        throw "File name '$FileName' does not match the expected '<Server>[-<Database>]-Query-<N>-<ShortName>.csv' pattern."
    }
}

function Get-DiagnosticImportPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResultsFolder
    )

    $runFolderName = Split-Path -Leaf ($ResultsFolder.TrimEnd('\', '/'))
    $runTimestamp = Get-DiagnosticRunTimestamp -RunFolderName $runFolderName

    $plan = [System.Collections.Generic.List[pscustomobject]]::new()

    $serverFolders = @(Get-ChildItem -LiteralPath $ResultsFolder -Directory)
    foreach ($serverFolder in $serverFolders) {
        $csvFiles = @(Get-ChildItem -LiteralPath $serverFolder.FullName -Filter '*.csv' -File)
        foreach ($csvFile in $csvFiles) {
            $meta = Get-DiagnosticResultCsvMetadata -ServerFolderName $serverFolder.Name -FileName $csvFile.Name

            $tableName = if ($meta.IsErrorsFile) { 'stg.RunErrors' } else { Get-StagingTableName -ShortName $meta.ShortName }

            $plan.Add([pscustomobject]@{
                ServerFolderName = $serverFolder.Name
                FilePath         = $csvFile.FullName
                IsErrorsFile     = $meta.IsErrorsFile
                DatabaseName     = $meta.DatabaseName
                QueryNumber      = $meta.QueryNumber
                ShortName        = $meta.ShortName
                TableName        = $tableName
            })
        }
    }

    $result = [pscustomobject]@{
        RunFolderName = $runFolderName
        RunTimestamp  = $runTimestamp
        Items         = @($plan.ToArray())
    }
    return $result
}

function ConvertTo-DiagnosticDataTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Rows
    )

    $table = [System.Data.DataTable]::new()
    if ($Rows.Count -eq 0) {
        # See the -NoEnumerate note below: without it this would return $null instead of an
        # empty DataTable, since PowerShell enumerates a 0-row DataTable to zero pipeline objects.
        Write-Output -NoEnumerate $table
        return
    }

    foreach ($prop in $Rows[0].PSObject.Properties) {
        $columnType = if ($prop.Value -is [int]) { [int] } else { [string] }
        [void]$table.Columns.Add($prop.Name, $columnType)
    }

    foreach ($row in $Rows) {
        $dataRow = $table.NewRow()
        foreach ($prop in $row.PSObject.Properties) {
            $value = $prop.Value
            $dataRow[$prop.Name] = if ($null -eq $value -or $value -is [System.DBNull]) { [System.DBNull]::Value } else { $value }
        }
        $table.Rows.Add($dataRow)
    }

    # A DataTable is enumerated to its rows when written to the pipeline like any other object
    # (return $table would hand the caller a DataRow, or an array of DataRows, or $null for zero
    # rows -- never the table itself). -NoEnumerate is required to return the table as one object.
    Write-Output -NoEnumerate $table
}

function Get-DiagnosticTableColumnPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ExistingColumns,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$RequiredColumns
    )

    $existingSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$ExistingColumns, [System.StringComparer]::OrdinalIgnoreCase)
    $missing = @($RequiredColumns | Where-Object { -not $existingSet.Contains($_) })
    return $missing
}

function Get-DiagnosticSqlColumnTypeName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [type]$DotNetType
    )

    if ($DotNetType -eq [int]) {
        return 'INT'
    }
    return 'NVARCHAR(MAX)'
}

function Confirm-DiagnosticStagingTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$SchemaName,

        [Parameter(Mandatory)]
        [string]$TableName,

        [Parameter(Mandatory)]
        [System.Data.DataTable]$DataTable
    )

    $fullName = "[$SchemaName].[$TableName]"
    $qualifiedName = "$SchemaName.$TableName"

    $checkCmd = $Connection.CreateCommand()
    $checkCmd.CommandText = 'SELECT OBJECT_ID(@QualifiedName)'
    [void]$checkCmd.Parameters.AddWithValue('@QualifiedName', $qualifiedName)
    $objectId = $checkCmd.ExecuteScalar()

    if ($null -eq $objectId -or $objectId -is [System.DBNull]) {
        $colDefs = foreach ($col in $DataTable.Columns) {
            "[$($col.ColumnName)] $(Get-DiagnosticSqlColumnTypeName -DotNetType $col.DataType)"
        }
        $createCmd = $Connection.CreateCommand()
        $createCmd.CommandText = "CREATE TABLE $fullName ($($colDefs -join ', '));"
        [void]$createCmd.ExecuteNonQuery()
        return
    }

    $existingCmd = $Connection.CreateCommand()
    $existingCmd.CommandText = 'SELECT name FROM sys.columns WHERE object_id = OBJECT_ID(@QualifiedName)'
    [void]$existingCmd.Parameters.AddWithValue('@QualifiedName', $qualifiedName)
    $reader = $existingCmd.ExecuteReader()
    $existingColumns = [System.Collections.Generic.List[string]]::new()
    try {
        while ($reader.Read()) {
            $existingColumns.Add($reader.GetString(0))
        }
    }
    finally {
        $reader.Close()
    }

    $requiredColumns = @($DataTable.Columns | ForEach-Object { $_.ColumnName })
    $missing = @(Get-DiagnosticTableColumnPlan -ExistingColumns @($existingColumns.ToArray()) -RequiredColumns $requiredColumns)

    foreach ($colName in $missing) {
        $col = $DataTable.Columns[$colName]
        $alterCmd = $Connection.CreateCommand()
        $alterCmd.CommandText = "ALTER TABLE $fullName ADD [$colName] $(Get-DiagnosticSqlColumnTypeName -DotNetType $col.DataType) NULL;"
        [void]$alterCmd.ExecuteNonQuery()
    }
}

function Invoke-DiagnosticBulkCopy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$SchemaName,

        [Parameter(Mandatory)]
        [string]$TableName,

        [Parameter(Mandatory)]
        [System.Data.DataTable]$DataTable
    )

    $bulkCopy = [System.Data.SqlClient.SqlBulkCopy]::new($Connection)
    try {
        $bulkCopy.DestinationTableName = "[$SchemaName].[$TableName]"
        foreach ($col in $DataTable.Columns) {
            [void]$bulkCopy.ColumnMappings.Add($col.ColumnName, $col.ColumnName)
        }
        $bulkCopy.WriteToServer($DataTable)
    }
    finally {
        $bulkCopy.Close()
    }
}

function Get-OrCreateDiagnosticRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$RunFolderName,

        [Parameter(Mandatory)]
        [datetime]$RunTimestamp
    )

    $selectCmd = $Connection.CreateCommand()
    $selectCmd.CommandText = 'SELECT RunId FROM dbo.Runs WHERE RunFolderName = @RunFolderName'
    [void]$selectCmd.Parameters.AddWithValue('@RunFolderName', $RunFolderName)
    $existing = $selectCmd.ExecuteScalar()

    if ($null -ne $existing -and -not ($existing -is [System.DBNull])) {
        return [int]$existing
    }

    $insertCmd = $Connection.CreateCommand()
    $insertCmd.CommandText = @'
INSERT INTO dbo.Runs (RunTimestamp, RunFolderName, ImportedAtUtc)
OUTPUT INSERTED.RunId
VALUES (@RunTimestamp, @RunFolderName, SYSUTCDATETIME());
'@
    [void]$insertCmd.Parameters.AddWithValue('@RunTimestamp', $RunTimestamp)
    [void]$insertCmd.Parameters.AddWithValue('@RunFolderName', $RunFolderName)
    $newId = $insertCmd.ExecuteScalar()
    return [int]$newId
}

function Get-DiagnosticSuccessfullyImportedFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory)]
        [int]$RunId
    )

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = "SELECT RelativeFilePath FROM dbo.ImportLog WHERE RunId = @RunId AND Status = 'Success'"
    [void]$cmd.Parameters.AddWithValue('@RunId', $RunId)
    $reader = $cmd.ExecuteReader()
    $result = [System.Collections.Generic.HashSet[string]]::new()
    try {
        while ($reader.Read()) {
            [void]$result.Add($reader.GetString(0))
        }
    }
    finally {
        $reader.Close()
    }
    # HashSet[string] implements IEnumerable, so a bare `return $result` would enumerate it to
    # its elements (0 items -> $null, 1 item -> that string, N items -> an array of strings)
    # instead of handing back the HashSet itself -- same class of bug as the DataTable case
    # documented in CLAUDE.md. -NoEnumerate keeps it a single HashSet object.
    Write-Output -NoEnumerate $result
}

function Set-DiagnosticImportLogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory)]
        [int]$RunId,

        [Parameter(Mandatory)]
        [string]$RelativeFilePath,

        [Parameter(Mandatory)]
        [string]$TableName,

        $RowCount,

        [Parameter(Mandatory)]
        [ValidateSet('Success', 'Failed')]
        [string]$Status,

        [string]$ErrorMessage
    )

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = @'
MERGE dbo.ImportLog AS target
USING (SELECT @RunId AS RunId, @RelativeFilePath AS RelativeFilePath) AS source
ON target.RunId = source.RunId AND target.RelativeFilePath = source.RelativeFilePath
WHEN MATCHED THEN UPDATE SET TableName = @TableName, [RowCount] = @RowCount, Status = @Status, ErrorMessage = @ErrorMessage, ImportedAtUtc = SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT (RunId, RelativeFilePath, TableName, [RowCount], Status, ErrorMessage)
    VALUES (@RunId, @RelativeFilePath, @TableName, @RowCount, @Status, @ErrorMessage);
'@
    [void]$cmd.Parameters.AddWithValue('@RunId', $RunId)
    [void]$cmd.Parameters.AddWithValue('@RelativeFilePath', $RelativeFilePath)
    [void]$cmd.Parameters.AddWithValue('@TableName', $TableName)
    [void]$cmd.Parameters.AddWithValue('@RowCount', $(if ($null -eq $RowCount) { [System.DBNull]::Value } else { $RowCount }))
    [void]$cmd.Parameters.AddWithValue('@Status', $Status)
    [void]$cmd.Parameters.AddWithValue('@ErrorMessage', $(if ([string]::IsNullOrEmpty($ErrorMessage)) { [System.DBNull]::Value } else { $ErrorMessage }))
    [void]$cmd.ExecuteNonQuery()
}

function Import-DiagnosticResultsFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResultsFolder,

        [Parameter(Mandatory)]
        [string]$ServerInstance,

        [Parameter(Mandatory)]
        [string]$Database,

        [Parameter(Mandatory)]
        [pscredential]$Credential
    )

    $connStr = New-DiagnosticSqlAuthConnectionString -ServerName $ServerInstance -Database $Database `
        -Username $Credential.UserName -Password $Credential.GetNetworkCredential().Password

    $plan = Get-DiagnosticImportPlan -ResultsFolder $ResultsFolder

    # A single persistent connection for the whole run (instead of one connection per file, which
    # under sustained load caused connection churn / "Failed to connect" errors) also lets a
    # dropped/failed file be retried without paying a fresh TLS handshake, and lets us reconnect
    # in place if the connection itself drops mid-run.
    $connection = [System.Data.SqlClient.SqlConnection]::new($connStr)
    $connection.Open()
    try {
        $runId = Get-OrCreateDiagnosticRun -Connection $connection -RunFolderName $plan.RunFolderName -RunTimestamp $plan.RunTimestamp
        $alreadyImported = Get-DiagnosticSuccessfullyImportedFiles -Connection $connection -RunId $runId

        $importedCount = 0
        $skippedCount = 0
        $failedCount = 0

        foreach ($item in $plan.Items) {
            $relativePath = Join-Path $item.ServerFolderName (Split-Path -Leaf $item.FilePath)

            if ($alreadyImported.Contains($relativePath)) {
                $skippedCount++
                continue
            }

            $succeeded = $false
            $lastError = $null
            $rowCount = 0

            for ($attempt = 1; $attempt -le 2 -and -not $succeeded; $attempt++) {
                try {
                    if ($connection.State -ne [System.Data.ConnectionState]::Open) {
                        $connection.Open()
                    }

                    $rows = @(Import-Csv -LiteralPath $item.FilePath)
                    if ($rows.Count -gt 0) {
                        $prefixed = foreach ($row in $rows) {
                            $ordered = [ordered]@{ RunId = $runId }
                            foreach ($prop in $row.PSObject.Properties) {
                                $ordered[$prop.Name] = $prop.Value
                            }
                            if (-not $item.IsErrorsFile) {
                                # Always use the canonical server-folder name, even for queries
                                # (like Server Properties) that already return their own
                                # ServerName column from SERVERPROPERTY() -- that can legitimately
                                # differ from the configured/folder hostname (e.g. a DNS alias),
                                # which would otherwise make that one table fail to join with
                                # every other staged table by ServerName.
                                $ordered['ServerName'] = $item.ServerFolderName
                            }
                            [pscustomobject]$ordered
                        }

                        $dataTable = ConvertTo-DiagnosticDataTable -Rows @($prefixed)
                        $schemaName, $tableNameOnly = $item.TableName -split '\.', 2
                        Confirm-DiagnosticStagingTable -Connection $connection -SchemaName $schemaName -TableName $tableNameOnly -DataTable $dataTable
                        Invoke-DiagnosticBulkCopy -Connection $connection -SchemaName $schemaName -TableName $tableNameOnly -DataTable $dataTable
                        $rowCount = $dataTable.Rows.Count
                    }

                    Set-DiagnosticImportLogEntry -Connection $connection -RunId $runId -RelativeFilePath $relativePath `
                        -TableName $item.TableName -RowCount $rowCount -Status 'Success'
                    $succeeded = $true
                }
                catch {
                    $lastError = $_.Exception.Message
                    if ($attempt -lt 2) {
                        Start-Sleep -Milliseconds 500
                    }
                }
            }

            if ($succeeded) {
                $importedCount++
            }
            else {
                Write-Warning "Failed to import '$($item.FilePath)' into '$($item.TableName)': $lastError"
                try {
                    if ($connection.State -ne [System.Data.ConnectionState]::Open) {
                        $connection.Open()
                    }
                    Set-DiagnosticImportLogEntry -Connection $connection -RunId $runId -RelativeFilePath $relativePath `
                        -TableName $item.TableName -RowCount $null -Status 'Failed' -ErrorMessage $lastError
                }
                catch {
                    Write-Warning "Additionally failed to record the failure in dbo.ImportLog for '$relativePath': $($_.Exception.Message)"
                }
                $failedCount++
            }
        }

        return [pscustomobject]@{
            RunId         = $runId
            RunFolderName = $plan.RunFolderName
            ImportedCount = $importedCount
            SkippedCount  = $skippedCount
            FailedCount   = $failedCount
        }
    }
    finally {
        $connection.Close()
    }
}

Export-ModuleMember -Function Get-DiagnosticStagingCredential, New-DiagnosticSqlAuthConnectionString, `
    Get-StagingTableName, Get-DiagnosticRunTimestamp, Get-DiagnosticResultCsvMetadata, `
    Get-DiagnosticImportPlan, ConvertTo-DiagnosticDataTable, Get-DiagnosticTableColumnPlan, `
    Get-DiagnosticSqlColumnTypeName, Confirm-DiagnosticStagingTable, Invoke-DiagnosticBulkCopy, `
    Get-OrCreateDiagnosticRun, Get-DiagnosticSuccessfullyImportedFiles, Set-DiagnosticImportLogEntry, `
    Import-DiagnosticResultsFolder
