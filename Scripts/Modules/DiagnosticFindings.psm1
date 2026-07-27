function Get-FindingNaturalKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServerName,

        [string]$DatabaseName,

        [Parameter(Mandatory)]
        [string]$FindingType,

        [Parameter(Mandatory)]
        [string]$ObjectName
    )

    $dbPart = if ($null -eq $DatabaseName -or $DatabaseName -is [System.DBNull]) { '' } else { $DatabaseName }
    return "$ServerName|$dbPart|$FindingType|$ObjectName"
}

function Get-FindingsDelta {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$PreviousOpenFindings,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$CurrentCandidates
    )

    $previousByKey = @{}
    foreach ($f in $PreviousOpenFindings) {
        $key = Get-FindingNaturalKey -ServerName $f.ServerName -DatabaseName $f.DatabaseName -FindingType $f.FindingType -ObjectName $f.ObjectName
        $previousByKey[$key] = $f
    }

    $matchedKeys = [System.Collections.Generic.HashSet[string]]::new()
    $toInsert = [System.Collections.Generic.List[pscustomobject]]::new()
    $toUpdate = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($c in $CurrentCandidates) {
        $key = Get-FindingNaturalKey -ServerName $c.ServerName -DatabaseName $c.DatabaseName -FindingType $c.FindingType -ObjectName $c.ObjectName
        if ($previousByKey.ContainsKey($key)) {
            [void]$matchedKeys.Add($key)
            $prev = $previousByKey[$key]
            $toUpdate.Add([pscustomobject]@{
                FindingId = $prev.FindingId
                Severity  = $c.Severity
                Detail    = $c.Detail
            })
        }
        else {
            $toInsert.Add($c)
        }
    }

    $toResolve = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($key in $previousByKey.Keys) {
        if (-not $matchedKeys.Contains($key)) {
            $toResolve.Add($previousByKey[$key])
        }
    }

    $result = [pscustomobject]@{
        ToInsert  = @($toInsert.ToArray())
        ToUpdate  = @($toUpdate.ToArray())
        ToResolve = @($toResolve.ToArray())
    }
    return $result
}

function Add-DiagnosticSqlParameter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.SqlClient.SqlCommand]$Command,

        [Parameter(Mandatory)]
        [string]$Name,

        $Value
    )

    $isNull = ($null -eq $Value) -or ($Value -is [System.DBNull])
    $sqlValue = if ($isNull) { [System.DBNull]::Value } else { $Value }
    [void]$Command.Parameters.AddWithValue($Name, $sqlValue)
}

function Invoke-DiagnosticFindingsWrite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionString,

        [Parameter(Mandatory)]
        [int]$RunId,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$ToInsert,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$ToUpdate,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$ToResolve
    )

    $connection = [System.Data.SqlClient.SqlConnection]::new($ConnectionString)
    $connection.Open()
    try {
        foreach ($item in $ToInsert) {
            $cmd = $connection.CreateCommand()
            $cmd.CommandText = @'
INSERT INTO dbo.Findings (ServerName, DatabaseName, FindingType, ObjectName, Severity, Detail, FirstDetectedRunId, LastDetectedRunId)
VALUES (@ServerName, @DatabaseName, @FindingType, @ObjectName, @Severity, @Detail, @RunId, @RunId);
'@
            Add-DiagnosticSqlParameter -Command $cmd -Name '@ServerName' -Value $item.ServerName
            Add-DiagnosticSqlParameter -Command $cmd -Name '@DatabaseName' -Value $item.DatabaseName
            Add-DiagnosticSqlParameter -Command $cmd -Name '@FindingType' -Value $item.FindingType
            Add-DiagnosticSqlParameter -Command $cmd -Name '@ObjectName' -Value $item.ObjectName
            Add-DiagnosticSqlParameter -Command $cmd -Name '@Severity' -Value $item.Severity
            Add-DiagnosticSqlParameter -Command $cmd -Name '@Detail' -Value $item.Detail
            Add-DiagnosticSqlParameter -Command $cmd -Name '@RunId' -Value $RunId
            [void]$cmd.ExecuteNonQuery()
        }

        foreach ($item in $ToUpdate) {
            $cmd = $connection.CreateCommand()
            $cmd.CommandText = 'UPDATE dbo.Findings SET LastDetectedRunId = @RunId, Severity = @Severity, Detail = @Detail WHERE FindingId = @FindingId;'
            Add-DiagnosticSqlParameter -Command $cmd -Name '@RunId' -Value $RunId
            Add-DiagnosticSqlParameter -Command $cmd -Name '@Severity' -Value $item.Severity
            Add-DiagnosticSqlParameter -Command $cmd -Name '@Detail' -Value $item.Detail
            Add-DiagnosticSqlParameter -Command $cmd -Name '@FindingId' -Value $item.FindingId
            [void]$cmd.ExecuteNonQuery()
        }

        foreach ($item in $ToResolve) {
            $cmd = $connection.CreateCommand()
            $cmd.CommandText = 'UPDATE dbo.Findings SET ResolvedRunId = @RunId WHERE FindingId = @FindingId;'
            Add-DiagnosticSqlParameter -Command $cmd -Name '@RunId' -Value $RunId
            Add-DiagnosticSqlParameter -Command $cmd -Name '@FindingId' -Value $item.FindingId
            [void]$cmd.ExecuteNonQuery()
        }
    }
    finally {
        $connection.Close()
    }
}

function Update-DiagnosticFindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionString,

        [Parameter(Mandatory)]
        [int]$RunId,

        [Parameter(Mandatory)]
        [string]$AnalysisScriptsFolder,

        [Parameter(Mandatory)]
        [hashtable]$Thresholds
    )

    $scriptFiles = @(Get-ChildItem -LiteralPath $AnalysisScriptsFolder -Filter '*.sql' -File | Sort-Object Name)

    $sqlVariables = @("RunId=$RunId")
    foreach ($key in $Thresholds.Keys) {
        $sqlVariables += "$key=$($Thresholds[$key])"
    }

    $summary = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($scriptFile in $scriptFiles) {
        $ruleName = [System.IO.Path]::GetFileNameWithoutExtension($scriptFile.Name)
        try {
            $candidates = @(Invoke-Sqlcmd -ConnectionString $ConnectionString -InputFile $scriptFile.FullName -Variable $sqlVariables -ErrorAction Stop)

            # Every rule file in this repo emits exactly one FindingType matching its own base
            # name (see Scripts/Analysis/*.sql). Scope "previously open" to that FindingType so a
            # rule with zero candidates this run still resolves what it previously flagged.
            # Invoke-Sqlcmd has no -SqlParameters binding in this module version, so this uses a
            # manually quote-escaped literal rather than a real bound parameter; $ruleName is our
            # own script file's base name, not external input, so this is safe.
            $escapedRuleName = $ruleName -replace "'", "''"
            $previousOpen = @(Invoke-Sqlcmd -ConnectionString $ConnectionString `
                -Query "SELECT FindingId, ServerName, DatabaseName, FindingType, ObjectName, Severity, Detail FROM dbo.Findings WHERE ResolvedRunId IS NULL AND FindingType = '$escapedRuleName'" `
                -ErrorAction Stop)

            $delta = Get-FindingsDelta -PreviousOpenFindings $previousOpen -CurrentCandidates $candidates
            Invoke-DiagnosticFindingsWrite -ConnectionString $ConnectionString -RunId $RunId `
                -ToInsert $delta.ToInsert -ToUpdate $delta.ToUpdate -ToResolve $delta.ToResolve

            $summary.Add([pscustomobject]@{
                Rule      = $ruleName
                Inserted  = $delta.ToInsert.Count
                StillOpen = $delta.ToUpdate.Count
                Resolved  = $delta.ToResolve.Count
                Failed    = $false
            })
        }
        catch {
            Write-Warning "Analysis rule '$ruleName' failed: $($_.Exception.Message)"
            $summary.Add([pscustomobject]@{
                Rule      = $ruleName
                Inserted  = 0
                StillOpen = 0
                Resolved  = 0
                Failed    = $true
            })
        }
    }

    return @($summary.ToArray())
}

Export-ModuleMember -Function Get-FindingNaturalKey, Get-FindingsDelta, Invoke-DiagnosticFindingsWrite, Update-DiagnosticFindings
