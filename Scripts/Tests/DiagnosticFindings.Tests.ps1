Describe 'Get-FindingNaturalKey' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticFindings.psm1" -Force
    }

    It 'builds a pipe-delimited key from server, database, finding type, and object name' {
        Get-FindingNaturalKey -ServerName 'srv1' -DatabaseName 'db1' -FindingType 'DriveSpaceLow' -ObjectName 'C:\' | Should -Be 'srv1|db1|DriveSpaceLow|C:\'
    }

    It 'treats a $null DatabaseName the same as DBNull (instance-scope findings)' {
        $withNull = Get-FindingNaturalKey -ServerName 'srv1' -DatabaseName $null -FindingType 'NonDefaultConfig' -ObjectName 'priority boost'
        $withDbNull = Get-FindingNaturalKey -ServerName 'srv1' -DatabaseName ([System.DBNull]::Value) -FindingType 'NonDefaultConfig' -ObjectName 'priority boost'
        $withNull | Should -Be $withDbNull
        $withNull | Should -Be 'srv1||NonDefaultConfig|priority boost'
    }
}

Describe 'Get-FindingsDelta' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticFindings.psm1" -Force
    }

    It 'puts a candidate with no matching previous finding into ToInsert' {
        $previous = @()
        $current = @([pscustomobject]@{ ServerName = 'srv1'; DatabaseName = $null; FindingType = 'DriveSpaceLow'; ObjectName = 'C:\'; Severity = 'Warning'; Detail = '10% free' })

        $delta = Get-FindingsDelta -PreviousOpenFindings $previous -CurrentCandidates $current

        $delta.ToInsert.Count | Should -Be 1
        $delta.ToInsert[0].ObjectName | Should -Be 'C:\'
        $delta.ToUpdate.Count | Should -Be 0
        $delta.ToResolve.Count | Should -Be 0
    }

    It 'puts a still-detected finding into ToUpdate, carrying the FindingId and refreshed Severity/Detail' {
        $previous = @([pscustomobject]@{ FindingId = 42; ServerName = 'srv1'; DatabaseName = $null; FindingType = 'DriveSpaceLow'; ObjectName = 'C:\'; Severity = 'Warning'; Detail = '10% free' })
        $current = @([pscustomobject]@{ ServerName = 'srv1'; DatabaseName = $null; FindingType = 'DriveSpaceLow'; ObjectName = 'C:\'; Severity = 'Critical'; Detail = '3% free' })

        $delta = Get-FindingsDelta -PreviousOpenFindings $previous -CurrentCandidates $current

        $delta.ToInsert.Count | Should -Be 0
        $delta.ToResolve.Count | Should -Be 0
        $delta.ToUpdate.Count | Should -Be 1
        $delta.ToUpdate[0].FindingId | Should -Be 42
        $delta.ToUpdate[0].Severity | Should -Be 'Critical'
        $delta.ToUpdate[0].Detail | Should -Be '3% free'
    }

    It 'puts a previously-open finding not re-detected this run into ToResolve' {
        $previous = @([pscustomobject]@{ FindingId = 7; ServerName = 'srv1'; DatabaseName = $null; FindingType = 'DriveSpaceLow'; ObjectName = 'D:\'; Severity = 'Warning'; Detail = 'was low' })
        $current = @()

        $delta = Get-FindingsDelta -PreviousOpenFindings $previous -CurrentCandidates $current

        $delta.ToInsert.Count | Should -Be 0
        $delta.ToUpdate.Count | Should -Be 0
        $delta.ToResolve.Count | Should -Be 1
        $delta.ToResolve[0].FindingId | Should -Be 7
    }

    It 'handles a mixed run: one new, one still-open, one resolved' {
        $previous = @(
            [pscustomobject]@{ FindingId = 1; ServerName = 'srv1'; DatabaseName = $null; FindingType = 'DriveSpaceLow'; ObjectName = 'C:\'; Severity = 'Warning'; Detail = 'x' }
            [pscustomobject]@{ FindingId = 2; ServerName = 'srv1'; DatabaseName = $null; FindingType = 'DriveSpaceLow'; ObjectName = 'D:\'; Severity = 'Warning'; Detail = 'y' }
        )
        $current = @(
            [pscustomobject]@{ ServerName = 'srv1'; DatabaseName = $null; FindingType = 'DriveSpaceLow'; ObjectName = 'C:\'; Severity = 'Warning'; Detail = 'x' }
            [pscustomobject]@{ ServerName = 'srv1'; DatabaseName = $null; FindingType = 'DriveSpaceLow'; ObjectName = 'E:\'; Severity = 'Critical'; Detail = 'z' }
        )

        $delta = Get-FindingsDelta -PreviousOpenFindings $previous -CurrentCandidates $current

        $delta.ToInsert.Count | Should -Be 1
        $delta.ToInsert[0].ObjectName | Should -Be 'E:\'
        $delta.ToUpdate.Count | Should -Be 1
        $delta.ToUpdate[0].FindingId | Should -Be 1
        $delta.ToResolve.Count | Should -Be 1
        $delta.ToResolve[0].FindingId | Should -Be 2
    }

    It 'distinguishes findings with the same ObjectName in different databases' {
        $previous = @([pscustomobject]@{ FindingId = 1; ServerName = 'srv1'; DatabaseName = 'DbA'; FindingType = 'UnusedIndex'; ObjectName = 'dbo.T.IX_1'; Severity = 'Info'; Detail = 'x' })
        $current = @([pscustomobject]@{ ServerName = 'srv1'; DatabaseName = 'DbB'; FindingType = 'UnusedIndex'; ObjectName = 'dbo.T.IX_1'; Severity = 'Info'; Detail = 'x' })

        $delta = Get-FindingsDelta -PreviousOpenFindings $previous -CurrentCandidates $current

        $delta.ToInsert.Count | Should -Be 1
        $delta.ToResolve.Count | Should -Be 1
    }

    It 'handles empty previous and empty current with no errors' {
        $delta = Get-FindingsDelta -PreviousOpenFindings @() -CurrentCandidates @()
        $delta.ToInsert.Count | Should -Be 0
        $delta.ToUpdate.Count | Should -Be 0
        $delta.ToResolve.Count | Should -Be 0
    }
}

Describe 'Get-DiagnosticRunServerNames' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticFindings.psm1" -Force
    }

    It 'returns an empty array when stg.Server_Properties does not exist' {
        Mock -CommandName Invoke-Sqlcmd -ModuleName DiagnosticFindings -MockWith { [pscustomobject]@{ Id = $null } } -ParameterFilter { $Query -like 'SELECT OBJECT_ID*' }

        $result = @(Get-DiagnosticRunServerNames -ConnectionString 'fake' -RunId 1)

        $result.Count | Should -Be 0
        Should -Invoke Invoke-Sqlcmd -ModuleName DiagnosticFindings -Times 1 -Exactly
    }

    It 'returns the distinct ServerNames staged for that RunId' {
        Mock -CommandName Invoke-Sqlcmd -ModuleName DiagnosticFindings -MockWith { [pscustomobject]@{ Id = 123 } } -ParameterFilter { $Query -like 'SELECT OBJECT_ID*' }
        Mock -CommandName Invoke-Sqlcmd -ModuleName DiagnosticFindings -MockWith {
            @(
                [pscustomobject]@{ ServerName = 'localhost' }
                [pscustomobject]@{ ServerName = 'otherserver' }
            )
        } -ParameterFilter { $Query -like 'SELECT DISTINCT ServerName*' }

        $result = @(Get-DiagnosticRunServerNames -ConnectionString 'fake' -RunId 2)

        $result.Count | Should -Be 2
        $result | Should -Contain 'localhost'
        $result | Should -Contain 'otherserver'
    }
}

Describe 'Update-DiagnosticFindings' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticFindings.psm1" -Force
    }

    It 'scopes previously-open findings to the servers actually staged in this run, so servers absent from the run are never resolved' {
        # Regression test: a run against a subset of servers (e.g. one server) must not resolve
        # findings belonging to servers that weren't part of this run at all -- reproduced for
        # real against dbo.Findings before this scoping was added (see Update-DiagnosticFindings).
        $analysisFolder = Join-Path $TestDrive 'Analysis'
        New-Item -ItemType Directory -Path $analysisFolder -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $analysisFolder 'FakeRule.sql') -Value '-- fake rule' -Encoding UTF8

        Mock -CommandName Get-DiagnosticRunServerNames -ModuleName DiagnosticFindings -MockWith { @('localhost') }
        Mock -CommandName Invoke-DiagnosticFindingsWrite -ModuleName DiagnosticFindings -MockWith { }

        Mock -CommandName Invoke-Sqlcmd -ModuleName DiagnosticFindings -MockWith { @() } -ParameterFilter { $null -ne $InputFile }
        Mock -CommandName Invoke-Sqlcmd -ModuleName DiagnosticFindings -MockWith { @() } -ParameterFilter { $null -ne $Query }

        Update-DiagnosticFindings -ConnectionString 'fake' -RunId 2 -AnalysisScriptsFolder $analysisFolder -Thresholds @{}

        Should -Invoke Invoke-Sqlcmd -ModuleName DiagnosticFindings -Times 1 -Exactly -ParameterFilter {
            $null -ne $Query -and $Query -match "ServerName IN \('localhost'\)"
        }
    }

    It 'excludes every previously-open finding when the run has no known staged servers, rather than resolving all of them' {
        $analysisFolder = Join-Path $TestDrive 'AnalysisEmpty'
        New-Item -ItemType Directory -Path $analysisFolder -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $analysisFolder 'FakeRule.sql') -Value '-- fake rule' -Encoding UTF8

        Mock -CommandName Get-DiagnosticRunServerNames -ModuleName DiagnosticFindings -MockWith { @() }
        Mock -CommandName Invoke-DiagnosticFindingsWrite -ModuleName DiagnosticFindings -MockWith { }

        Mock -CommandName Invoke-Sqlcmd -ModuleName DiagnosticFindings -MockWith { @() } -ParameterFilter { $null -ne $InputFile }
        Mock -CommandName Invoke-Sqlcmd -ModuleName DiagnosticFindings -MockWith { @() } -ParameterFilter { $null -ne $Query }

        Update-DiagnosticFindings -ConnectionString 'fake' -RunId 99 -AnalysisScriptsFolder $analysisFolder -Thresholds @{}

        Should -Invoke Invoke-Sqlcmd -ModuleName DiagnosticFindings -Times 1 -Exactly -ParameterFilter {
            $null -ne $Query -and $Query -match 'AND 1 = 0'
        }
    }
}
