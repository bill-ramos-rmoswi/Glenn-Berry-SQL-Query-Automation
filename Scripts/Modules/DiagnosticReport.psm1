function ConvertTo-DiagnosticHtmlEncoded {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text
    )

    if ($null -eq $Text -or $Text -is [System.DBNull]) {
        return ''
    }
    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function Get-DiagnosticReportStyleBlock {
    [CmdletBinding()]
    param()

    return @'
<style>
:root { color-scheme: light dark; }
body { font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif; margin: 0; padding: 0 1.5rem 3rem; line-height: 1.4; }
header.page-header { padding: 1rem 0; border-bottom: 1px solid #8884; margin-bottom: 1rem; }
header.page-header nav a { margin-right: 0.75rem; }
h1 { font-size: 1.5rem; margin: 0 0 0.25rem; }
h2 { font-size: 1.15rem; margin-top: 2rem; }
table.diag-table { border-collapse: collapse; width: 100%; margin: 0.5rem 0 1.5rem; font-size: 0.9rem; }
table.diag-table th, table.diag-table td { border: 1px solid #8886; padding: 0.35rem 0.6rem; text-align: left; vertical-align: top; }
table.diag-table th { cursor: pointer; user-select: none; background: #80808022; position: sticky; top: 0; }
table.diag-table th.sorted-asc::after { content: ' \25B2'; }
table.diag-table th.sorted-desc::after { content: ' \25BC'; }
table.diag-table tbody tr:nth-child(even) { background: #80808011; }
input.diag-filter { padding: 0.35rem 0.5rem; margin: 0.5rem 0; width: 100%; max-width: 24rem; box-sizing: border-box; }
.badge { display: inline-block; padding: 0.1rem 0.5rem; border-radius: 0.75rem; font-size: 0.8rem; font-weight: 600; }
.badge-critical { background: #c0392b; color: #fff; }
.badge-warning { background: #d68910; color: #fff; }
.badge-info { background: #2471a3; color: #fff; }
.summary-cards { display: flex; gap: 1rem; flex-wrap: wrap; margin: 1rem 0 1.5rem; }
.summary-card { border: 1px solid #8886; border-radius: 0.5rem; padding: 0.75rem 1rem; min-width: 8rem; }
.summary-card .count { font-size: 1.6rem; font-weight: 700; display: block; }
.muted { opacity: 0.7; font-size: 0.85rem; }
a { color: inherit; }
</style>
'@
}

function Get-DiagnosticReportScript {
    [CmdletBinding()]
    param()

    return @'
<script>
document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('table.diag-table').forEach(function (table) {
        var headers = table.querySelectorAll('thead th');
        headers.forEach(function (th, colIndex) {
            th.addEventListener('click', function () {
                var tbody = table.querySelector('tbody');
                var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr'));
                var asc = !th.classList.contains('sorted-asc');
                headers.forEach(function (h) { h.classList.remove('sorted-asc', 'sorted-desc'); });
                th.classList.add(asc ? 'sorted-asc' : 'sorted-desc');
                rows.sort(function (a, b) {
                    var av = a.children[colIndex].getAttribute('data-sort') || a.children[colIndex].textContent;
                    var bv = b.children[colIndex].getAttribute('data-sort') || b.children[colIndex].textContent;
                    var an = parseFloat(av), bn = parseFloat(bv);
                    var cmp = (!isNaN(an) && !isNaN(bn)) ? (an - bn) : av.localeCompare(bv);
                    return asc ? cmp : -cmp;
                });
                rows.forEach(function (r) { tbody.appendChild(r); });
            });
        });
    });

    document.querySelectorAll('input.diag-filter').forEach(function (input) {
        input.addEventListener('input', function () {
            var table = document.getElementById(input.getAttribute('data-target'));
            var needle = input.value.toLowerCase();
            table.querySelectorAll('tbody tr').forEach(function (row) {
                row.style.display = row.textContent.toLowerCase().indexOf(needle) === -1 ? 'none' : '';
            });
        });
    });
});
</script>
'@
}

function New-DiagnosticSeverityBadge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Severity
    )

    $cssClass = switch ($Severity) {
        'Critical' { 'badge-critical' }
        'Warning'  { 'badge-warning' }
        default    { 'badge-info' }
    }
    return "<span class='badge $cssClass'>$(ConvertTo-DiagnosticHtmlEncoded $Severity)</span>"
}

function New-DiagnosticHtmlPage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$BodyHtml,

        [string]$NavHtml = ''
    )

    $html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$(ConvertTo-DiagnosticHtmlEncoded $Title)</title>
$(Get-DiagnosticReportStyleBlock)
</head>
<body>
<header class="page-header">
<nav>$NavHtml</nav>
</header>
$BodyHtml
$(Get-DiagnosticReportScript)
</body>
</html>
"@
    return $html
}

function New-DiagnosticDataTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Columns,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Rows,

        [Parameter(Mandatory)]
        [string]$TableId,

        [switch]$Filterable
    )

    $sb = [System.Text.StringBuilder]::new()
    if ($Filterable) {
        [void]$sb.Append("<input class='diag-filter' type='search' placeholder='Filter...' data-target='$TableId'>")
    }
    [void]$sb.Append("<table class='diag-table' id='$TableId'><thead><tr>")
    foreach ($col in $Columns) {
        [void]$sb.Append("<th>$(ConvertTo-DiagnosticHtmlEncoded $col)</th>")
    }
    [void]$sb.Append('</tr></thead><tbody>')
    foreach ($row in $Rows) {
        [void]$sb.Append('<tr>')
        foreach ($cell in $row) {
            [void]$sb.Append("<td>$cell</td>")
        }
        [void]$sb.Append('</tr>')
    }
    [void]$sb.Append('</tbody></table>')
    return $sb.ToString()
}

function New-DiagnosticIndexPage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Servers,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$OpenFindings
    )

    $criticalCount = @($OpenFindings | Where-Object Severity -eq 'Critical').Count
    $warningCount = @($OpenFindings | Where-Object Severity -eq 'Warning').Count
    $infoCount = @($OpenFindings | Where-Object Severity -eq 'Info').Count

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('<h1>SFFCU SQL Server Diagnostic Report</h1>')
    [void]$sb.Append("<div class='summary-cards'>")
    [void]$sb.Append("<div class='summary-card'><span class='count'>$criticalCount</span>Critical</div>")
    [void]$sb.Append("<div class='summary-card'><span class='count'>$warningCount</span>Warning</div>")
    [void]$sb.Append("<div class='summary-card'><span class='count'>$infoCount</span>Info</div>")
    [void]$sb.Append("<div class='summary-card'><span class='count'>$($Servers.Count)</span>Servers</div>")
    [void]$sb.Append('</div>')

    if ($criticalCount -gt 0 -or $warningCount -gt 0) {
        [void]$sb.Append("<p><a href='attention.html'>&raquo; View all $($criticalCount + $warningCount) Critical/Warning findings needing attention</a></p>")
    }

    [void]$sb.Append('<h2>Servers</h2>')
    $rows = @(foreach ($server in $Servers) {
        $link = "servers/$($server.LinkName).html"
        , @(
            "<a href='$link'>$(ConvertTo-DiagnosticHtmlEncoded $server.ServerName)</a>",
            (ConvertTo-DiagnosticHtmlEncoded $server.VersionLabel),
            (ConvertTo-DiagnosticHtmlEncoded $server.Edition),
            $server.Cores,
            $server.RamMB,
            "$($server.MinDriveFreePercent)%",
            $server.CriticalCount,
            $server.WarningCount
        )
    })
    [void]$sb.Append((New-DiagnosticDataTable -Columns @('Server', 'Version', 'Edition', 'Cores', 'RAM (MB)', 'Lowest Drive Free %', 'Critical', 'Warning') -Rows $rows -TableId 'servers-table' -Filterable))

    return New-DiagnosticHtmlPage -Title 'SFFCU SQL Server Diagnostic Report' -BodyHtml $sb.ToString() -NavHtml "<a href='index.html'>Home</a> <a href='attention.html'>Attention Needed</a>"
}

function New-DiagnosticAttentionPage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$OpenFindings
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('<h1>Attention Needed</h1>')
    [void]$sb.Append('<p class=''muted''>Open findings across all servers, most severe first. "First seen" / "still open since" reflect prior diagnostic runs so you can tell whether an issue is new or was already flagged.</p>')

    $ordered = $OpenFindings | Sort-Object @{Expression = { switch ($_.Severity) { 'Critical' { 0 } 'Warning' { 1 } default { 2 } } } }, ServerName, DatabaseName

    $rows = @(foreach ($f in $ordered) {
        $serverLink = "servers/$($f.ServerLinkName).html"
        # DBNull (SQL NULL for instance-scope findings) is truthy in a plain `if ($f.DatabaseName)`
        # check, so this must test for it explicitly rather than relying on truthiness.
        $target = if (-not [string]::IsNullOrEmpty($f.DatabaseName)) { "servers/$($f.ServerLinkName)/$($f.DatabaseLinkName).html" } else { $serverLink }
        , @(
            (New-DiagnosticSeverityBadge -Severity $f.Severity),
            "<a href='$target'>$(ConvertTo-DiagnosticHtmlEncoded $f.ServerName)</a>",
            (ConvertTo-DiagnosticHtmlEncoded $f.DatabaseName),
            (ConvertTo-DiagnosticHtmlEncoded $f.FindingType),
            (ConvertTo-DiagnosticHtmlEncoded $f.ObjectName),
            (ConvertTo-DiagnosticHtmlEncoded $f.Detail),
            (ConvertTo-DiagnosticHtmlEncoded $f.FirstSeenLabel),
            (ConvertTo-DiagnosticHtmlEncoded $f.LastSeenLabel)
        )
    })
    [void]$sb.Append((New-DiagnosticDataTable -Columns @('Severity', 'Server', 'Database', 'Type', 'Object', 'Detail', 'First Seen', 'Still Open As Of') -Rows $rows -TableId 'attention-table' -Filterable))

    return New-DiagnosticHtmlPage -Title 'Attention Needed' -BodyHtml $sb.ToString() -NavHtml "<a href='index.html'>Home</a> <a href='attention.html'>Attention Needed</a>"
}

function New-DiagnosticServerPage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServerName,

        [Parameter(Mandatory)]
        [string]$ServerLinkName,

        [Parameter(Mandatory)]
        [pscustomobject]$Overview,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$NonDefaultFindings,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Drives,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Databases
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append("<h1>$(ConvertTo-DiagnosticHtmlEncoded $ServerName)</h1>")
    [void]$sb.Append("<p><strong>Version:</strong> $(ConvertTo-DiagnosticHtmlEncoded $Overview.VersionLabel) &nbsp; ")
    [void]$sb.Append("<strong>Edition:</strong> $(ConvertTo-DiagnosticHtmlEncoded $Overview.Edition) &nbsp; ")
    [void]$sb.Append("<strong>Cores:</strong> $($Overview.Cores) &nbsp; ")
    [void]$sb.Append("<strong>RAM:</strong> $($Overview.RamMB) MB &nbsp; ")
    [void]$sb.Append("<strong>Uptime:</strong> $($Overview.UpTimeHours) hrs</p>")

    [void]$sb.Append('<h2>Drives</h2>')
    $driveRows = @(foreach ($d in $Drives) {
        , @((ConvertTo-DiagnosticHtmlEncoded $d.VolumeMountPoint), (ConvertTo-DiagnosticHtmlEncoded $d.LogicalVolumeName), $d.TotalSizeGB, $d.FreePercent)
    })
    [void]$sb.Append((New-DiagnosticDataTable -Columns @('Volume', 'Label', 'Total (GB)', 'Free %') -Rows $driveRows -TableId 'drives-table'))

    [void]$sb.Append('<h2>Non-Default Server / Database Settings</h2>')
    if ($NonDefaultFindings.Count -eq 0) {
        [void]$sb.Append("<p class='muted'>None open.</p>")
    }
    else {
        $findingRows = @(foreach ($f in $NonDefaultFindings) {
            , @((New-DiagnosticSeverityBadge -Severity $f.Severity), (ConvertTo-DiagnosticHtmlEncoded $f.DatabaseName), (ConvertTo-DiagnosticHtmlEncoded $f.ObjectName), (ConvertTo-DiagnosticHtmlEncoded $f.Detail))
        })
        [void]$sb.Append((New-DiagnosticDataTable -Columns @('Severity', 'Database', 'Setting', 'Detail') -Rows $findingRows -TableId 'server-findings-table' -Filterable))
    }

    [void]$sb.Append('<h2>Databases</h2>')
    [void]$sb.Append("<p class='muted'>'Idle Indexes' = every index in that database shows zero reads and zero writes since the server's last restart. May mean the database is genuinely idle, or that it's already been migrated off this server -- verify before assuming it's safe to remove. Click the column header to sort.</p>")
    $dbRows = @(foreach ($db in $Databases) {
        $idleLabel = if ($db.DormantIndexCount) { $db.DormantIndexCount } else { '' }
        , @("<a href='$ServerLinkName/$($db.LinkName).html'>$(ConvertTo-DiagnosticHtmlEncoded $db.DatabaseName)</a>", $db.CriticalCount, $db.WarningCount, $db.InfoCount, $idleLabel)
    })
    [void]$sb.Append((New-DiagnosticDataTable -Columns @('Database', 'Critical', 'Warning', 'Info', 'Idle Indexes') -Rows $dbRows -TableId 'databases-table' -Filterable))

    return New-DiagnosticHtmlPage -Title "$ServerName - SFFCU Diagnostic Report" -BodyHtml $sb.ToString() -NavHtml "<a href='../index.html'>Home</a> <a href='../attention.html'>Attention Needed</a>"
}

function New-DiagnosticDatabasePage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServerName,

        [Parameter(Mandatory)]
        [string]$ServerLinkName,

        [Parameter(Mandatory)]
        [string]$DatabaseName,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$FileSizes,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$NonDefaultFindings,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$UnusedIndexes,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$TableSizes
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append("<h1>$(ConvertTo-DiagnosticHtmlEncoded $DatabaseName)</h1>")
    [void]$sb.Append("<p class='muted'>on $(ConvertTo-DiagnosticHtmlEncoded $ServerName)</p>")

    [void]$sb.Append('<h2>Files</h2>')
    $fileRows = @(foreach ($f in $FileSizes) {
        , @((ConvertTo-DiagnosticHtmlEncoded $f.FileName), (ConvertTo-DiagnosticHtmlEncoded $f.FileType), $f.TotalSizeMB, $f.UsedSpaceMB, $f.MaxSizePercent)
    })
    [void]$sb.Append((New-DiagnosticDataTable -Columns @('File', 'Type', 'Total (MB)', 'Used (MB)', '% of Max Size') -Rows $fileRows -TableId 'files-table'))

    [void]$sb.Append('<h2>Non-Default Settings / Log Health</h2>')
    if ($NonDefaultFindings.Count -eq 0) {
        [void]$sb.Append("<p class='muted'>None open.</p>")
    }
    else {
        $findingRows = @(foreach ($f in $NonDefaultFindings) {
            , @((New-DiagnosticSeverityBadge -Severity $f.Severity), (ConvertTo-DiagnosticHtmlEncoded $f.ObjectName), (ConvertTo-DiagnosticHtmlEncoded $f.Detail))
        })
        [void]$sb.Append((New-DiagnosticDataTable -Columns @('Severity', 'Setting', 'Detail') -Rows $findingRows -TableId 'db-findings-table' -Filterable))
    }

    [void]$sb.Append('<h2>Unused Indexes (candidates for review)</h2>')
    if ($UnusedIndexes.Count -eq 0) {
        [void]$sb.Append("<p class='muted'>None flagged.</p>")
    }
    else {
        $idxRows = @(foreach ($i in $UnusedIndexes) {
            , @((ConvertTo-DiagnosticHtmlEncoded $i.ObjectName), (ConvertTo-DiagnosticHtmlEncoded $i.Detail))
        })
        [void]$sb.Append((New-DiagnosticDataTable -Columns @('Index', 'Detail') -Rows $idxRows -TableId 'unused-index-table' -Filterable))
    }

    [void]$sb.Append('<h2>Largest Tables</h2>')
    $tableRows = @(foreach ($t in $TableSizes) {
        , @((ConvertTo-DiagnosticHtmlEncoded $t.TableName), $t.RowCounts, $t.TotalSpaceMB)
    })
    [void]$sb.Append((New-DiagnosticDataTable -Columns @('Table', 'Row Count', 'Total Space (MB)') -Rows $tableRows -TableId 'table-sizes-table' -Filterable))

    return New-DiagnosticHtmlPage -Title "$DatabaseName on $ServerName - SFFCU Diagnostic Report" -BodyHtml $sb.ToString() -NavHtml "<a href='../../index.html'>Home</a> <a href='../../attention.html'>Attention Needed</a> <a href='../$ServerLinkName.html'>$(ConvertTo-DiagnosticHtmlEncoded $ServerName)</a>"
}

Export-ModuleMember -Function ConvertTo-DiagnosticHtmlEncoded, Get-DiagnosticReportStyleBlock, Get-DiagnosticReportScript, `
    New-DiagnosticSeverityBadge, New-DiagnosticHtmlPage, New-DiagnosticDataTable, New-DiagnosticIndexPage, `
    New-DiagnosticAttentionPage, New-DiagnosticServerPage, New-DiagnosticDatabasePage
