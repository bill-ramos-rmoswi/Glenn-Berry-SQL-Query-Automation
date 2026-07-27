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
