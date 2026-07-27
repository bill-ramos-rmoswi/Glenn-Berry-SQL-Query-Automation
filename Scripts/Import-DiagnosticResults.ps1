[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ResultsFolder,

    [string]$StagingServerInstance = 'localhost',
    [string]$StagingDatabase = 'GlennBerrySQLDiag',
    [string]$CredentialProtocol = 'sql',
    [string]$CredentialHost = 'localhost',
    [string]$CredentialPath = 'GlennBerrySQLDiag/LLMAgent'
)

Import-Module (Join-Path $PSScriptRoot 'Modules/DiagnosticStaging.psm1') -Force
Import-Module SqlServer -Force

$resultsFolder = (Resolve-Path -LiteralPath $ResultsFolder).Path

$cred = Get-DiagnosticStagingCredential -Protocol $CredentialProtocol -HostName $CredentialHost -Path $CredentialPath
$securePassword = ConvertTo-SecureString -String $cred.Password -AsPlainText -Force
$securePassword.MakeReadOnly()
$pscred = [pscredential]::new($cred.Username, $securePassword)

$result = Import-DiagnosticResultsFolder -ResultsFolder $resultsFolder -ServerInstance $StagingServerInstance `
    -Database $StagingDatabase -Credential $pscred

Write-Host "Imported run '$($result.RunFolderName)' as RunId $($result.RunId): $($result.ImportedCount) files imported, $($result.SkippedCount) already up to date, $($result.FailedCount) failed."
if ($result.FailedCount -gt 0) {
    Write-Host "Re-run this exact command to retry the failed files -- already-succeeded files are skipped automatically (see dbo.ImportLog)."
}
