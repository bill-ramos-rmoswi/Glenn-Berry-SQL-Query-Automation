Describe 'ConvertTo-DiagnosticHtmlEncoded' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticReport.psm1" -Force
    }

    It 'HTML-encodes angle brackets and ampersands' {
        ConvertTo-DiagnosticHtmlEncoded -Text '<script>a & b</script>' | Should -Be '&lt;script&gt;a &amp; b&lt;/script&gt;'
    }

    It 'returns an empty string for $null' {
        ConvertTo-DiagnosticHtmlEncoded -Text $null | Should -Be ''
    }

    It 'returns an empty string for DBNull' {
        ConvertTo-DiagnosticHtmlEncoded -Text ([System.DBNull]::Value) | Should -Be ''
    }
}

Describe 'New-DiagnosticSeverityBadge' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticReport.psm1" -Force
    }

    It 'uses the critical badge class for Critical' {
        New-DiagnosticSeverityBadge -Severity 'Critical' | Should -Match "badge-critical"
    }

    It 'uses the warning badge class for Warning' {
        New-DiagnosticSeverityBadge -Severity 'Warning' | Should -Match "badge-warning"
    }

    It 'falls back to the info badge class for anything else' {
        New-DiagnosticSeverityBadge -Severity 'Info' | Should -Match "badge-info"
    }
}

Describe 'New-DiagnosticDataTable' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticReport.psm1" -Force
    }

    It 'renders one <th> per column and one <tr> per row' {
        $html = New-DiagnosticDataTable -Columns @('A', 'B') -Rows @(@('1', '2'), @('3', '4')) -TableId 'tbl1'
        ([regex]::Matches($html, '<th>')).Count | Should -Be 2
        ([regex]::Matches($html, '<tr>')).Count | Should -Be 3 # 1 header row + 2 body rows
        $html | Should -Match '>1<'
        $html | Should -Match '>4<'
    }

    It 'includes a filter input only when -Filterable is passed' {
        $withFilter = New-DiagnosticDataTable -Columns @('A') -Rows @() -TableId 'tbl2' -Filterable
        $withoutFilter = New-DiagnosticDataTable -Columns @('A') -Rows @() -TableId 'tbl3'
        $withFilter | Should -Match "data-target='tbl2'"
        $withoutFilter | Should -Not -Match 'diag-filter'
    }

    It 'renders an empty tbody for zero rows without error' {
        { New-DiagnosticDataTable -Columns @('A') -Rows @() -TableId 'tbl4' } | Should -Not -Throw
    }
}

Describe 'New-DiagnosticHtmlPage' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticReport.psm1" -Force
    }

    It 'wraps the body in a full html document and encodes the title' {
        $html = New-DiagnosticHtmlPage -Title 'A & B' -BodyHtml '<p>hi</p>'
        $html | Should -Match '<title>A &amp; B</title>'
        $html | Should -Match '<p>hi</p>'
        $html | Should -Match '<!doctype html>'
    }
}

Describe 'New-DiagnosticIndexPage' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticReport.psm1" -Force
    }

    It 'summarizes finding counts by severity and links each server to servers/<LinkName>.html' {
        $servers = @(
            [pscustomobject]@{ ServerName = 'srv1'; LinkName = 'srv1'; VersionLabel = 'SQL Server 2019'; Edition = 'Enterprise'; Cores = 4; RamMB = 8192; MinDriveFreePercent = 20; CriticalCount = 1; WarningCount = 2 }
        )
        $findings = @(
            [pscustomobject]@{ Severity = 'Critical' }
            [pscustomobject]@{ Severity = 'Warning' }
            [pscustomobject]@{ Severity = 'Warning' }
        )

        $html = New-DiagnosticIndexPage -Servers $servers -OpenFindings $findings

        $html | Should -Match "href='servers/srv1.html'"
        $html | Should -Match "<span class='count'>1</span>Critical"
        $html | Should -Match "<span class='count'>2</span>Warning"
        $html | Should -Match 'attention.html'
    }

    It 'omits the attention link when there are no Critical/Warning findings' {
        $servers = @([pscustomobject]@{ ServerName = 'srv1'; LinkName = 'srv1'; VersionLabel = ''; Edition = ''; Cores = 1; RamMB = 1; MinDriveFreePercent = 99; CriticalCount = 0; WarningCount = 0 })
        $html = New-DiagnosticIndexPage -Servers $servers -OpenFindings @()
        $html | Should -Not -Match 'View all'
    }
}

Describe 'New-DiagnosticAttentionPage' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticReport.psm1" -Force
    }

    It 'sorts Critical findings before Warning findings' {
        $findings = @(
            [pscustomobject]@{ ServerName = 'srv1'; ServerLinkName = 'srv1'; DatabaseName = $null; DatabaseLinkName = $null; FindingType = 'DriveSpaceLow'; ObjectName = 'C:\'; Severity = 'Warning'; Detail = 'low'; FirstSeenLabel = '2026-01-01'; LastSeenLabel = '2026-02-01' }
            [pscustomobject]@{ ServerName = 'srv2'; ServerLinkName = 'srv2'; DatabaseName = $null; DatabaseLinkName = $null; FindingType = 'DriveSpaceLow'; ObjectName = 'D:\'; Severity = 'Critical'; Detail = 'very low'; FirstSeenLabel = '2026-01-01'; LastSeenLabel = '2026-02-01' }
        )

        $html = New-DiagnosticAttentionPage -OpenFindings $findings

        $criticalIndex = $html.IndexOf('very low')
        $warningIndex = $html.IndexOf('>low<')
        $criticalIndex | Should -BeGreaterThan -1
        $warningIndex | Should -BeGreaterThan -1
        $criticalIndex | Should -BeLessThan $warningIndex
    }

    It 'links a database-scoped finding to the database page, not just the server page' {
        $findings = @(
            [pscustomobject]@{ ServerName = 'srv1'; ServerLinkName = 'srv1'; DatabaseName = 'DbA'; DatabaseLinkName = 'DbA'; FindingType = 'DatabasePropertiesFlags'; ObjectName = 'AutoShrink'; Severity = 'Warning'; Detail = 'on'; FirstSeenLabel = 'x'; LastSeenLabel = 'y' }
        )
        $html = New-DiagnosticAttentionPage -OpenFindings $findings
        $html | Should -Match "href='servers/srv1/DbA.html'"
    }

    It 'links an instance-scope finding (DBNull DatabaseName, as Invoke-Sqlcmd returns for SQL NULL) to the server page, not a database page' {
        $findings = @(
            [pscustomobject]@{ ServerName = 'srv1'; ServerLinkName = 'srv1'; DatabaseName = [System.DBNull]::Value; DatabaseLinkName = $null; FindingType = 'NonDefaultConfig'; ObjectName = 'priority boost'; Severity = 'Warning'; Detail = 'on'; FirstSeenLabel = 'x'; LastSeenLabel = 'y' }
        )
        $html = New-DiagnosticAttentionPage -OpenFindings $findings
        $html | Should -Match "href='servers/srv1.html'"
        $html | Should -Not -Match "href='servers/srv1/"
    }
}

Describe 'New-DiagnosticServerPage' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticReport.psm1" -Force
    }

    It 'links each database to servers/<ServerLinkName>/<DbLinkName>.html' {
        $overview = [pscustomobject]@{ VersionLabel = 'SQL Server 2019'; Edition = 'Enterprise'; Cores = 4; RamMB = 8192; UpTimeHours = 100 }
        $databases = @([pscustomobject]@{ DatabaseName = 'ADP'; LinkName = 'ADP'; CriticalCount = 0; WarningCount = 1; InfoCount = 0 })

        $html = New-DiagnosticServerPage -ServerName 'cut1sqlp01' -ServerLinkName 'cut1sqlp01' -Overview $overview `
            -NonDefaultFindings @() -Drives @() -Databases $databases

        $html | Should -Match "href='cut1sqlp01/ADP.html'"
    }

    It 'shows the dormant index count in the Idle Indexes column when a database has one' {
        $overview = [pscustomobject]@{ VersionLabel = 'SQL Server 2019'; Edition = 'Enterprise'; Cores = 4; RamMB = 8192; UpTimeHours = 100 }
        $databases = @(
            [pscustomobject]@{ DatabaseName = 'ADP'; LinkName = 'ADP'; CriticalCount = 0; WarningCount = 0; InfoCount = 0; DormantIndexCount = 12 }
            [pscustomobject]@{ DatabaseName = 'Active'; LinkName = 'Active'; CriticalCount = 0; WarningCount = 0; InfoCount = 0; DormantIndexCount = $null }
        )

        $html = New-DiagnosticServerPage -ServerName 'cut1sqlp02' -ServerLinkName 'cut1sqlp02' -Overview $overview `
            -NonDefaultFindings @() -Drives @() -Databases $databases

        $html | Should -Match 'Idle Indexes'
        $html | Should -Match "href='cut1sqlp02/ADP.html'>ADP</a></td><td>0</td><td>0</td><td>0</td><td>12</td>"
        $html | Should -Match "href='cut1sqlp02/Active.html'>Active</a></td><td>0</td><td>0</td><td>0</td><td></td>"
    }

    It 'shows a muted message when there are no open non-default findings' {
        $overview = [pscustomobject]@{ VersionLabel = ''; Edition = ''; Cores = 1; RamMB = 1; UpTimeHours = 1 }
        $html = New-DiagnosticServerPage -ServerName 'srv1' -ServerLinkName 'srv1' -Overview $overview `
            -NonDefaultFindings @() -Drives @() -Databases @()
        $html | Should -Match 'None open'
    }
}

Describe 'New-DiagnosticDatabasePage' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticReport.psm1" -Force
    }

    It 'links back to the parent server page using ServerLinkName' {
        $html = New-DiagnosticDatabasePage -ServerName 'cut1sqlp01' -ServerLinkName 'cut1sqlp01' -DatabaseName 'ADP' `
            -FileSizes @() -NonDefaultFindings @() -UnusedIndexes @() -TableSizes @()
        $html | Should -Match "href='../cut1sqlp01.html'"
    }

    It 'shows a muted message when there are no unused index findings' {
        $html = New-DiagnosticDatabasePage -ServerName 'srv1' -ServerLinkName 'srv1' -DatabaseName 'db1' `
            -FileSizes @() -NonDefaultFindings @() -UnusedIndexes @() -TableSizes @()
        $html | Should -Match 'None flagged'
    }
}
