[CmdletBinding()]
param(
    [int]$RunId,
    [Parameter(Mandatory)]
    [string]$OutputFolder,

    [string]$StagingServerInstance = 'localhost',
    [string]$StagingDatabase = 'GlennBerrySQLDiag',
    [string]$CredentialProtocol = 'sql',
    [string]$CredentialHost = 'localhost',
    [string]$CredentialPath = 'GlennBerrySQLDiag/LLMAgent',

    [switch]$IncludeQueryDetails
)

Import-Module (Join-Path $PSScriptRoot 'Modules/DiagnosticStaging.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/DiagnosticDriver.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/DiagnosticReport.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/DiagnosticSplitter.psm1') -Force
Import-Module SqlServer -Force

$cred = Get-DiagnosticStagingCredential -Protocol $CredentialProtocol -HostName $CredentialHost -Path $CredentialPath
$connStr = New-DiagnosticSqlAuthConnectionString -ServerName $StagingServerInstance -Database $StagingDatabase `
    -Username $cred.Username -Password $cred.Password

if (-not $RunId) {
    $latest = Invoke-Sqlcmd -ConnectionString $connStr -Query 'SELECT TOP 1 RunId FROM dbo.Runs ORDER BY RunTimestamp DESC' -ErrorAction Stop
    if (-not $latest) {
        throw "No rows in dbo.Runs -- import a Results folder first with Import-DiagnosticResults.ps1."
    }
    $RunId = [int]$latest.RunId
}

$versionMap = @{ '13' = 'SQL Server 2016 SP2'; '14' = 'SQL Server 2017'; '15' = 'SQL Server 2019'; '16' = 'SQL Server 2022'; '17' = 'SQL Server 2025' }

$runsById = @{}
foreach ($r in @(Invoke-Sqlcmd -ConnectionString $connStr -Query 'SELECT RunId, RunTimestamp FROM dbo.Runs' -ErrorAction Stop)) {
    $runsById[[int]$r.RunId] = $r.RunTimestamp
}
function Get-RunLabel { param($id) if ($id -and $runsById.ContainsKey([int]$id)) { $runsById[[int]$id].ToString('yyyy-MM-dd') } else { '?' } }

$serverPropsRows = @(Invoke-Sqlcmd -ConnectionString $connStr -Query "SELECT ServerName, Edition, ProductVersion, ProductMajorVersion FROM stg.Server_Properties WHERE RunId = $RunId" -ErrorAction Stop)
$hwRows = @(Invoke-Sqlcmd -ConnectionString $connStr -Query "SELECT ServerName, [Logical CPU Count], [Physical Memory (MB)], [SQL Server Up Time (hrs)] FROM stg.Hardware_Info WHERE RunId = $RunId" -ErrorAction Stop)
$volumeRows = @(Invoke-Sqlcmd -ConnectionString $connStr -Query "SELECT ServerName, volume_mount_point, logical_volume_name, [Total Size (GB)], [Space Free %] FROM stg.Volume_Info WHERE RunId = $RunId" -ErrorAction Stop)
$dbListRows = @(Invoke-Sqlcmd -ConnectionString $connStr -Query "SELECT DISTINCT ServerName, DatabaseName FROM stg.File_Sizes_and_Space WHERE RunId = $RunId" -ErrorAction Stop)

$allOpenFindings = @(Invoke-Sqlcmd -ConnectionString $connStr -Query 'SELECT ServerName, DatabaseName, FindingType, ObjectName, Severity, Detail, FirstDetectedRunId, LastDetectedRunId FROM dbo.Findings WHERE ResolvedRunId IS NULL' -ErrorAction Stop)

# Reuse Scripts/Analysis/DormantDatabase.sql directly (rather than re-deriving the same "every
# index in this database is idle" logic here) to drive the per-server "Idle Indexes" column.
$thresholds = @{}
(Get-Content (Join-Path $PSScriptRoot 'config/analysis-thresholds.json') -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $thresholds[$_.Name] = $_.Value }
$analysisVariables = @("RunId=$RunId")
foreach ($key in $thresholds.Keys) {
    $analysisVariables += "$key=$($thresholds[$key])"
}
$dormantDbRows = @(Invoke-Sqlcmd -ConnectionString $connStr -InputFile (Join-Path $PSScriptRoot 'Analysis/DormantDatabase.sql') -Variable $analysisVariables -ErrorAction Stop)

foreach ($f in $allOpenFindings) {
    $f | Add-Member -NotePropertyName ServerLinkName -NotePropertyValue (Get-SanitizedFileSystemName -Name $f.ServerName)
    # $f.DatabaseName comes back as [System.DBNull]::Value (not $null) for instance-scope findings
    # when read via Invoke-Sqlcmd, and DBNull is truthy in a plain `if ($f.DatabaseName)` check.
    $f | Add-Member -NotePropertyName DatabaseLinkName -NotePropertyValue $(if (-not [string]::IsNullOrEmpty($f.DatabaseName)) { Get-SanitizedFileSystemName -Name $f.DatabaseName } else { $null })
    $f | Add-Member -NotePropertyName FirstSeenLabel -NotePropertyValue (Get-RunLabel $f.FirstDetectedRunId)
    $f | Add-Member -NotePropertyName LastSeenLabel -NotePropertyValue (Get-RunLabel $f.LastDetectedRunId)
}

# -IncludeQueryDetails precompute: batch-load every staged query's raw rows for this run ONCE
# (grouped in-memory by server / server+database), rather than one SQL round trip per generated
# detail page -- see CLAUDE.md-style reasoning in the plan: this keeps round trips proportional to
# "distinct staged tables in the run" (~100-150), not to page count.
$queryLibraryRoot = Join-Path $PSScriptRoot 'QueryLibrary'
$manifestByVersion = @{}
$versionFolderByServer = @{}
$tableScope = @{}
$rowsByServer = @{}
$rowsByServerDb = @{}
$descriptionCache = @{}
$sourceTextCache = @{}

function Get-CachedQueryDescription {
    param([string]$VersionFolder, [string]$RelativeFile)
    $key = "$VersionFolder|$RelativeFile"
    if (-not $descriptionCache.ContainsKey($key)) {
        $fullPath = Join-Path (Join-Path $queryLibraryRoot $VersionFolder) $RelativeFile
        $blocks = @(Get-DiagnosticQueryBlocks -Lines (Get-Content -LiteralPath $fullPath))
        $descriptionCache[$key] = if ($blocks.Count -gt 0) { $blocks[0].Description } else { '' }
    }
    return $descriptionCache[$key]
}

# The source query is embedded directly into the detail page (see Get-CachedQuerySourceText below)
# rather than linked as a separate .sql file -- a link to a .sql file gets treated as an
# unrecognized download by the browser instead of opening inline, both under file:// and under
# SharePoint's "Strict" file handling (see README).
function Get-CachedQuerySourceText {
    param([string]$VersionFolder, [string]$RelativeFile)
    $key = "$VersionFolder|$RelativeFile"
    if (-not $sourceTextCache.ContainsKey($key)) {
        $fullPath = Join-Path (Join-Path $queryLibraryRoot $VersionFolder) $RelativeFile
        $sourceTextCache[$key] = Get-Content -LiteralPath $fullPath -Raw
    }
    return $sourceTextCache[$key]
}

if ($IncludeQueryDetails) {
    foreach ($sp0 in $serverPropsRows) {
        $vf = Get-VersionFolderName -ProductMajorVersion ([int]$sp0.ProductMajorVersion) -QueryLibraryRoot $queryLibraryRoot
        $versionFolderByServer[$sp0.ServerName] = $vf
        if ($vf -and -not $manifestByVersion.ContainsKey($vf)) {
            $manifestPath = Join-Path (Join-Path $queryLibraryRoot $vf) 'manifest.json'
            if (Test-Path -LiteralPath $manifestPath) {
                $manifestByVersion[$vf] = Read-DiagnosticManifest -ManifestPath $manifestPath
            }
        }
    }

    $stgTableSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($tr in @(Invoke-Sqlcmd -ConnectionString $connStr -Query "SELECT name FROM sys.tables WHERE schema_id = SCHEMA_ID('stg')" -ErrorAction Stop)) {
        [void]$stgTableSet.Add("stg.$($tr.name)")
    }

    $stgTableColumns = @{}
    foreach ($cr in @(Invoke-Sqlcmd -ConnectionString $connStr -Query "SELECT t.name AS TableName, c.name AS ColumnName FROM sys.columns c JOIN sys.tables t ON c.object_id = t.object_id WHERE t.schema_id = SCHEMA_ID('stg') ORDER BY t.name, c.column_id" -ErrorAction Stop)) {
        $tn = "stg.$($cr.TableName)"
        if (-not $stgTableColumns.ContainsKey($tn)) { $stgTableColumns[$tn] = [System.Collections.Generic.List[string]]::new() }
        $stgTableColumns[$tn].Add($cr.ColumnName)
    }

    foreach ($vf in $manifestByVersion.Keys) {
        foreach ($qEntry in $manifestByVersion[$vf]) {
            $tn = Get-StagingTableName -ShortName $qEntry.ShortName
            if (-not $stgTableSet.Contains($tn)) { continue }
            if (-not $tableScope.ContainsKey($tn)) { $tableScope[$tn] = $qEntry.Scope }
        }
    }

    foreach ($tn in $tableScope.Keys) {
        $cols = $stgTableColumns[$tn]
        if (-not $cols) { continue }
        if ($tableScope[$tn] -eq 'Database' -and -not ($cols -contains 'DatabaseName')) {
            # Framework doesn't guarantee a DatabaseName column on database-scope tables -- see
            # CLAUDE.md; without it we can't scope rows to a single database, so skip entirely.
            continue
        }

        $allRows = @(Invoke-Sqlcmd -ConnectionString $connStr -Query "SELECT * FROM $tn WHERE RunId = $RunId" -ErrorAction SilentlyContinue)
        if ($allRows.Count -eq 0) { continue }

        if ($tableScope[$tn] -eq 'Instance') {
            $grouped = @{}
            foreach ($r in $allRows) {
                if (-not $grouped.ContainsKey($r.ServerName)) { $grouped[$r.ServerName] = [System.Collections.Generic.List[object]]::new() }
                $grouped[$r.ServerName].Add($r)
            }
            $rowsByServer[$tn] = $grouped
        }
        else {
            $grouped = @{}
            foreach ($r in $allRows) {
                $key = "$($r.ServerName)|$($r.DatabaseName)"
                if (-not $grouped.ContainsKey($key)) { $grouped[$key] = [System.Collections.Generic.List[object]]::new() }
                $grouped[$key].Add($r)
            }
            $rowsByServerDb[$tn] = $grouped
        }
    }
}

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$serversFolder = Join-Path $OutputFolder 'servers'
New-Item -ItemType Directory -Path $serversFolder -Force | Out-Null

$serverSummaries = [System.Collections.Generic.List[pscustomobject]]::new()

foreach ($sp in $serverPropsRows) {
    $serverName = $sp.ServerName
    $linkName = Get-SanitizedFileSystemName -Name $serverName
    $hw = $hwRows | Where-Object ServerName -eq $serverName | Select-Object -First 1
    $drives = @($volumeRows | Where-Object ServerName -eq $serverName)
    $minDriveFree = if ($drives.Count -gt 0) { ($drives | ForEach-Object { [decimal]$_.'Space Free %' } | Measure-Object -Minimum).Minimum } else { $null }

    $serverFindings = @($allOpenFindings | Where-Object { $_.ServerName -eq $serverName })
    $nonDefaultFindings = @($serverFindings | Where-Object { $_.FindingType -in @('NonDefaultConfig', 'DatabasePropertiesFlags') })

    $overview = [pscustomobject]@{
        VersionLabel = if ($versionMap.ContainsKey("$($sp.ProductMajorVersion)")) { $versionMap["$($sp.ProductMajorVersion)"] } else { $sp.ProductVersion }
        Edition      = $sp.Edition
        Cores        = if ($hw) { $hw.'Logical CPU Count' } else { '?' }
        RamMB        = if ($hw) { $hw.'Physical Memory (MB)' } else { '?' }
        UpTimeHours  = if ($hw) { $hw.'SQL Server Up Time (hrs)' } else { '?' }
    }

    $driveObjs = @(foreach ($d in $drives) {
        [pscustomobject]@{
            VolumeMountPoint  = $d.volume_mount_point
            LogicalVolumeName = $d.logical_volume_name
            TotalSizeGB       = $d.'Total Size (GB)'
            FreePercent       = $d.'Space Free %'
        }
    })

    $dbNames = @($dbListRows | Where-Object ServerName -eq $serverName | Select-Object -ExpandProperty DatabaseName)
    $databaseSummaries = [System.Collections.Generic.List[pscustomobject]]::new()

    $dbFolder = Join-Path $serversFolder $linkName
    New-Item -ItemType Directory -Path $dbFolder -Force | Out-Null

    $serverQueryLinks = [System.Collections.Generic.List[pscustomobject]]::new()
    $versionFolder = $versionFolderByServer[$serverName]
    if ($IncludeQueryDetails -and $versionFolder -and $manifestByVersion.ContainsKey($versionFolder)) {
        $instanceQueriesFolder = Join-Path $dbFolder 'queries'
        foreach ($qEntry in (Get-FilteredManifestQueries -ManifestQueries $manifestByVersion[$versionFolder] -Scope 'Instance')) {
            $tn = Get-StagingTableName -ShortName $qEntry.ShortName
            if (-not $rowsByServer.ContainsKey($tn)) { continue }
            $rowsForServer = $rowsByServer[$tn][$serverName]
            if (-not $rowsForServer -or $rowsForServer.Count -eq 0) { continue }

            New-Item -ItemType Directory -Path $instanceQueriesFolder -Force | Out-Null
            $description = Get-CachedQueryDescription -VersionFolder $versionFolder -RelativeFile $qEntry.File
            $sourceText = Get-CachedQuerySourceText -VersionFolder $versionFolder -RelativeFile $qEntry.File

            $displayColumns = @($stgTableColumns[$tn] | Where-Object { $_ -notin @('RunId', 'ServerName') })
            $displayRows = @(foreach ($r in $rowsForServer) {
                , @(foreach ($col in $displayColumns) { ConvertTo-DiagnosticHtmlEncoded "$($r.$col)" })
            })

            $qLinkName = Get-SanitizedFileSystemName -Name $qEntry.ShortName
            $navHtml = "<a href='../../../index.html'>Home</a> <a href='../../../attention.html'>Attention Needed</a> <a href='../../$linkName.html'>$(ConvertTo-DiagnosticHtmlEncoded $serverName)</a>"
            $detailPage = New-DiagnosticQueryDetailPage -Title $qEntry.ShortName -Description $description -ContextLabel "on $serverName" `
                -Columns $displayColumns -Rows $displayRows -TableId 'query-detail-table' -SqlSource $sourceText -NavHtml $navHtml
            Set-Content -LiteralPath (Join-Path $instanceQueriesFolder "$qLinkName.html") -Value $detailPage -Encoding UTF8

            $serverQueryLinks.Add([pscustomobject]@{
                Number      = $qEntry.Number
                ShortName   = $qEntry.ShortName
                Description = $description
                Href        = "$linkName/queries/$qLinkName.html"
            })
        }
    }

    foreach ($dbName in $dbNames) {
        $dbLinkName = Get-SanitizedFileSystemName -Name $dbName
        $dbFindings = @($allOpenFindings | Where-Object { $_.ServerName -eq $serverName -and $_.DatabaseName -eq $dbName -and $_.FindingType -in @('DatabasePropertiesFlags', 'FileNearMaxSize') })
        $unusedIndexFindings = @($allOpenFindings | Where-Object { $_.ServerName -eq $serverName -and $_.DatabaseName -eq $dbName -and $_.FindingType -eq 'UnusedIndex' })

        $fileRows = @(Invoke-Sqlcmd -ConnectionString $connStr -Query @"
SELECT [File Name], [Filegroup Name], [Total Size in MB], [Used Space in MB]
FROM stg.File_Sizes_and_Space
WHERE RunId = $RunId AND ServerName = N'$($serverName -replace "'", "''")' AND DatabaseName = N'$($dbName -replace "'", "''")'
"@ -ErrorAction SilentlyContinue)

        $fileObjs = @(foreach ($fr in $fileRows) {
            [pscustomobject]@{
                FileName     = $fr.'File Name'
                FileType     = $fr.'Filegroup Name'
                TotalSizeMB  = $fr.'Total Size in MB'
                UsedSpaceMB  = $fr.'Used Space in MB'
                MaxSizePercent = '' # see FileNearMaxSize findings above for files that are actually close to their cap
            }
        })

        $tableRows = @()
        if ((Invoke-Sqlcmd -ConnectionString $connStr -Query "SELECT OBJECT_ID('stg.Table_Sizes') AS Id" -ErrorAction SilentlyContinue).Id) {
            $tableRows = @(Invoke-Sqlcmd -ConnectionString $connStr -Query @"
SELECT TOP 20 [Table Name], [Row Count], [Object Size (MB)]
FROM stg.Table_Sizes
WHERE RunId = $RunId AND ServerName = N'$($serverName -replace "'", "''")' AND DatabaseName = N'$($dbName -replace "'", "''")'
ORDER BY TRY_CAST([Object Size (MB)] AS DECIMAL(18,2)) DESC
"@ -ErrorAction SilentlyContinue)
        }
        $tableObjs = @(foreach ($tr in $tableRows) {
            [pscustomobject]@{ TableName = $tr.'Table Name'; RowCounts = $tr.'Row Count'; TotalSpaceMB = $tr.'Object Size (MB)' }
        })

        $dbQueryLinks = [System.Collections.Generic.List[pscustomobject]]::new()
        if ($IncludeQueryDetails -and $versionFolder -and $manifestByVersion.ContainsKey($versionFolder)) {
            $dbDetailFolder = Join-Path $dbFolder $dbLinkName
            $dbQueriesFolder = Join-Path $dbDetailFolder 'queries'
            foreach ($qEntry in (Get-FilteredManifestQueries -ManifestQueries $manifestByVersion[$versionFolder] -Scope 'Database')) {
                $tn = Get-StagingTableName -ShortName $qEntry.ShortName
                if (-not $rowsByServerDb.ContainsKey($tn)) { continue }
                $rowsForDb = $rowsByServerDb[$tn]["$serverName|$dbName"]
                if (-not $rowsForDb -or $rowsForDb.Count -eq 0) { continue }

                New-Item -ItemType Directory -Path $dbQueriesFolder -Force | Out-Null
                $description = Get-CachedQueryDescription -VersionFolder $versionFolder -RelativeFile $qEntry.File
                $sourceText = Get-CachedQuerySourceText -VersionFolder $versionFolder -RelativeFile $qEntry.File

                $displayColumns = @($stgTableColumns[$tn] | Where-Object { $_ -notin @('RunId', 'ServerName', 'DatabaseName') })
                $displayRows = @(foreach ($r in $rowsForDb) {
                    , @(foreach ($col in $displayColumns) { ConvertTo-DiagnosticHtmlEncoded "$($r.$col)" })
                })

                $qLinkName = Get-SanitizedFileSystemName -Name $qEntry.ShortName
                $navHtml = "<a href='../../../../index.html'>Home</a> <a href='../../../../attention.html'>Attention Needed</a> <a href='../../../$linkName.html'>$(ConvertTo-DiagnosticHtmlEncoded $serverName)</a> <a href='../../$dbLinkName.html'>$(ConvertTo-DiagnosticHtmlEncoded $dbName)</a>"
                $detailPage = New-DiagnosticQueryDetailPage -Title $qEntry.ShortName -Description $description -ContextLabel "$dbName on $serverName" `
                    -Columns $displayColumns -Rows $displayRows -TableId 'query-detail-table' -SqlSource $sourceText -NavHtml $navHtml
                Set-Content -LiteralPath (Join-Path $dbQueriesFolder "$qLinkName.html") -Value $detailPage -Encoding UTF8

                $dbQueryLinks.Add([pscustomobject]@{
                    Number      = $qEntry.Number
                    ShortName   = $qEntry.ShortName
                    Description = $description
                    Href        = "$dbLinkName/queries/$qLinkName.html"
                })
            }
        }

        $dbPage = New-DiagnosticDatabasePage -ServerName $serverName -ServerLinkName $linkName -DatabaseName $dbName `
            -FileSizes $fileObjs -NonDefaultFindings $dbFindings -UnusedIndexes $unusedIndexFindings -TableSizes $tableObjs -QueryLinks @($dbQueryLinks.ToArray())
        Set-Content -LiteralPath (Join-Path $dbFolder "$dbLinkName.html") -Value $dbPage -Encoding UTF8

        $dormantRow = $dormantDbRows | Where-Object { $_.ServerName -eq $serverName -and $_.DatabaseName -eq $dbName } | Select-Object -First 1

        $databaseSummaries.Add([pscustomobject]@{
            DatabaseName       = $dbName
            LinkName           = $dbLinkName
            CriticalCount      = @($dbFindings + $unusedIndexFindings | Where-Object Severity -eq 'Critical').Count
            WarningCount       = @($dbFindings + $unusedIndexFindings | Where-Object Severity -eq 'Warning').Count
            InfoCount          = @($dbFindings + $unusedIndexFindings | Where-Object Severity -eq 'Info').Count
            DormantIndexCount  = if ($dormantRow) { $dormantRow.IndexCount } else { $null }
        })
    }

    $serverPage = New-DiagnosticServerPage -ServerName $serverName -ServerLinkName $linkName -Overview $overview `
        -NonDefaultFindings $nonDefaultFindings -Drives $driveObjs -Databases @($databaseSummaries.ToArray()) -QueryLinks @($serverQueryLinks.ToArray())
    Set-Content -LiteralPath (Join-Path $serversFolder "$linkName.html") -Value $serverPage -Encoding UTF8

    $serverSummaries.Add([pscustomobject]@{
        ServerName          = $serverName
        LinkName            = $linkName
        VersionLabel        = $overview.VersionLabel
        Edition             = $overview.Edition
        Cores               = $overview.Cores
        RamMB               = $overview.RamMB
        MinDriveFreePercent = if ($null -ne $minDriveFree) { [Math]::Round($minDriveFree, 1) } else { '?' }
        CriticalCount       = @($serverFindings | Where-Object Severity -eq 'Critical').Count
        WarningCount        = @($serverFindings | Where-Object Severity -eq 'Warning').Count
    })
}

$indexPage = New-DiagnosticIndexPage -Servers @($serverSummaries.ToArray()) -OpenFindings $allOpenFindings
Set-Content -LiteralPath (Join-Path $OutputFolder 'index.html') -Value $indexPage -Encoding UTF8

$attentionPage = New-DiagnosticAttentionPage -OpenFindings @($allOpenFindings | Where-Object Severity -in @('Critical', 'Warning'))
Set-Content -LiteralPath (Join-Path $OutputFolder 'attention.html') -Value $attentionPage -Encoding UTF8

Write-Host "Report for RunId $RunId written to '$OutputFolder' ($($serverSummaries.Count) servers)."
