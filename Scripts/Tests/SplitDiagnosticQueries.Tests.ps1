Describe 'Split-DiagnosticQueries.ps1' {
    It 'splits every .sql file under SourceRoot into OutputRoot' {
        $sourceDir = Join-Path $TestDrive 'source'
        $outputRoot = Join-Path $TestDrive 'output'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null

        @'

--******************************************************************************
--*   Copyright (C) 2026 Glenn Berry
--*   All rights reserved.
--******************************************************************************

-- Instance level queries *******************************

-- Get a thing (Query 1) (Thing)
SELECT 1;
'@ | Set-Content -LiteralPath (Join-Path $sourceDir 'SQL Server 2099 Diagnostic Information Queries.sql') -Encoding UTF8

        $scriptPath = Join-Path $PSScriptRoot '../Split-DiagnosticQueries.ps1'
        & $scriptPath -SourceRoot $sourceDir -OutputRoot $outputRoot

        Test-Path (Join-Path $outputRoot 'SQL Server 2099/manifest.json') | Should -Be $true
        Test-Path (Join-Path $outputRoot 'SQL Server 2099/Instance/Query01-Thing.sql') | Should -Be $true
    }
}
