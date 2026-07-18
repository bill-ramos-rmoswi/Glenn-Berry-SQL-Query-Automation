[CmdletBinding()]
param(
    [string]$OutputRoot = (Join-Path $PSScriptRoot '../dist')
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$packageName = "GlennBerryDiagnostics_$timestamp"
$stagingDir = Join-Path $OutputRoot $packageName

if (-not (Test-Path $OutputRoot)) {
    New-Item -ItemType Directory -Path $OutputRoot | Out-Null
}
if (Test-Path $stagingDir) {
    Remove-Item -Path $stagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir | Out-Null

# Runtime-only files: what Invoke-DiagnosticRun.ps1 needs to execute a diagnostic pass.
Copy-Item -Path (Join-Path $repoRoot 'Scripts/Invoke-DiagnosticRun.ps1') -Destination $stagingDir
Copy-Item -Path (Join-Path $repoRoot 'Scripts/Modules') -Destination (Join-Path $stagingDir 'Modules') -Recurse
Copy-Item -Path (Join-Path $repoRoot 'Scripts/QueryLibrary') -Destination (Join-Path $stagingDir 'QueryLibrary') -Recurse

$configDir = Join-Path $stagingDir 'config'
New-Item -ItemType Directory -Path $configDir | Out-Null
@'
[
  {
    "ServerName": "localhost"
  }
]
'@ | Set-Content -Path (Join-Path $configDir 'servers.json') -Encoding utf8

Copy-Item -Path (Join-Path $repoRoot 'Scripts/config/exclusions.json') -Destination $configDir

Copy-Item -Path (Join-Path $repoRoot 'CUSTOMER_INSTRUCTIONS.md') -Destination (Join-Path $stagingDir 'INSTRUCTIONS.md')

$zipPath = Join-Path $OutputRoot "$packageName.zip"
if (Test-Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}
Compress-Archive -Path (Join-Path $stagingDir '*') -DestinationPath $zipPath

Write-Host "Customer package created: $zipPath"
