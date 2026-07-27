[CmdletBinding()]
param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot '../SQL-Diag-Source-Files'),
    [string]$OutputRoot = (Join-Path $PSScriptRoot 'QueryLibrary'),
    [string]$CustomQueriesRoot = (Join-Path $PSScriptRoot 'CustomQueries')
)

Import-Module (Join-Path $PSScriptRoot 'Modules/DiagnosticSplitter.psm1') -Force

$sourceFiles = Get-ChildItem -LiteralPath $SourceRoot -Filter '*.sql'
foreach ($file in $sourceFiles) {
    $result = Split-DiagnosticQueryFile -SourcePath $file.FullName -OutputRoot $OutputRoot
    Write-Host "Split '$($file.Name)' -> '$($result.VersionFolder)' ($($result.InstanceCount) instance, $($result.DatabaseCount) database queries)"

    $versionRoot = Join-Path $OutputRoot $result.VersionFolder
    $customResult = Add-CustomDiagnosticQueries -VersionRoot $versionRoot -CustomQueriesRoot $CustomQueriesRoot
    if ($customResult.AddedCount -gt 0) {
        Write-Host "  + merged $($customResult.AddedCount) custom quer$(if ($customResult.AddedCount -eq 1) { 'y' } else { 'ies' }) -> '$($result.VersionFolder)' ($($customResult.TotalCount) total)"
    }
}
