[CmdletBinding()]
param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot '../SQL-Diag-Source-Files'),
    [string]$OutputRoot = (Join-Path $PSScriptRoot 'QueryLibrary')
)

Import-Module (Join-Path $PSScriptRoot 'Modules/DiagnosticSplitter.psm1') -Force

$sourceFiles = Get-ChildItem -LiteralPath $SourceRoot -Filter '*.sql'
foreach ($file in $sourceFiles) {
    $result = Split-DiagnosticQueryFile -SourcePath $file.FullName -OutputRoot $OutputRoot
    Write-Host "Split '$($file.Name)' -> '$($result.VersionFolder)' ($($result.InstanceCount) instance, $($result.DatabaseCount) database queries)"
}
