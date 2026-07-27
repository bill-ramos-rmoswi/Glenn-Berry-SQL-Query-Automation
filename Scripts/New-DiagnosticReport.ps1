[CmdletBinding()]
param(
    [int]$RunId,
    [Parameter(Mandatory)]
    [string]$OutputFolder,

    [string]$StagingServerInstance = 'localhost',
    [string]$StagingDatabase = 'GlennBerrySQLDiag',
    [string]$CredentialProtocol = 'sql',
    [string]$CredentialHost = 'localhost',
    [string]$CredentialPath = 'GlennBerrySQLDiag/LLMAgent'
)

Import-Module (Join-Path $PSScriptRoot 'Modules/DiagnosticStaging.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/DiagnosticDriver.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/DiagnosticReport.psm1') -Force
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
SELECT TOP 20 [Table Name], [Row Counts], [Total Space (MB)]
FROM stg.Table_Sizes
WHERE RunId = $RunId AND ServerName = N'$($serverName -replace "'", "''")' AND DatabaseName = N'$($dbName -replace "'", "''")'
ORDER BY TRY_CAST([Total Space (MB)] AS DECIMAL(18,2)) DESC
"@ -ErrorAction SilentlyContinue)
        }
        $tableObjs = @(foreach ($tr in $tableRows) {
            [pscustomobject]@{ TableName = $tr.'Table Name'; RowCounts = $tr.'Row Counts'; TotalSpaceMB = $tr.'Total Space (MB)' }
        })

        $dbPage = New-DiagnosticDatabasePage -ServerName $serverName -ServerLinkName $linkName -DatabaseName $dbName `
            -FileSizes $fileObjs -NonDefaultFindings $dbFindings -UnusedIndexes $unusedIndexFindings -TableSizes $tableObjs
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
        -NonDefaultFindings $nonDefaultFindings -Drives $driveObjs -Databases @($databaseSummaries.ToArray())
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
