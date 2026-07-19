[CmdletBinding()]
param(
    [string]$ServersConfigPath,
    [string]$ExclusionsConfigPath,
    [string]$QueryLibraryRoot,
    [string]$ResultsRoot
)

if (-not $ServersConfigPath) { $ServersConfigPath = Join-Path $PSScriptRoot 'config/servers.json' }
if (-not $ExclusionsConfigPath) { $ExclusionsConfigPath = Join-Path $PSScriptRoot 'config/exclusions.json' }
if (-not $QueryLibraryRoot) { $QueryLibraryRoot = Join-Path $PSScriptRoot 'QueryLibrary' }
if (-not $ResultsRoot) { $ResultsRoot = Join-Path $PSScriptRoot '../Results' }

Import-Module (Join-Path $PSScriptRoot 'Modules/DiagnosticDriver.psm1') -Force

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runFolder = Join-Path $ResultsRoot $timestamp

$result = Invoke-DiagnosticRun -ServersConfigPath $ServersConfigPath -ExclusionsConfigPath $ExclusionsConfigPath -QueryLibraryRoot $QueryLibraryRoot -RunFolder $runFolder

Write-Host "Run complete: $($result.RunFolder) ($($result.ErrorCount) errors)"
