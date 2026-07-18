[CmdletBinding()]
param(
    [string]$ServersConfigPath = (Join-Path $PSScriptRoot 'config/servers.json'),
    [string]$ExclusionsConfigPath = (Join-Path $PSScriptRoot 'config/exclusions.json'),
    [string]$QueryLibraryRoot = (Join-Path $PSScriptRoot 'QueryLibrary'),
    [string]$ResultsRoot = (Join-Path $PSScriptRoot '../Results')
)

Import-Module (Join-Path $PSScriptRoot 'Modules/DiagnosticDriver.psm1') -Force

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runFolder = Join-Path $ResultsRoot $timestamp

$result = Invoke-DiagnosticRun -ServersConfigPath $ServersConfigPath -ExclusionsConfigPath $ExclusionsConfigPath -QueryLibraryRoot $QueryLibraryRoot -RunFolder $runFolder

Write-Host "Run complete: $($result.RunFolder) ($($result.ErrorCount) errors)"
