Describe 'Split-DiagnosticQueries.ps1' {
    BeforeEach {
        $script:sourceDir = Join-Path $TestDrive "source-$([guid]::NewGuid().ToString('N'))"
        $script:outputRoot = Join-Path $TestDrive "output-$([guid]::NewGuid().ToString('N'))"
        $script:emptyCustomRoot = Join-Path $TestDrive "custom-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        New-Item -ItemType Directory -Path $emptyCustomRoot -Force | Out-Null

        @'

--******************************************************************************
--*   Copyright (C) 2026 Glenn Berry
--*   All rights reserved.
--******************************************************************************

-- Instance level queries *******************************

-- Get a thing (Query 1) (Thing)
SELECT 1;
'@ | Set-Content -LiteralPath (Join-Path $sourceDir 'SQL Server 2099 Diagnostic Information Queries.sql') -Encoding UTF8

        $script:scriptPath = Join-Path $PSScriptRoot '../Split-DiagnosticQueries.ps1'
    }

    It 'splits every .sql file under SourceRoot into OutputRoot' {
        # Isolated, empty CustomQueriesRoot so this test doesn't depend on the repo's real
        # Scripts/CustomQueries contents.
        & $scriptPath -SourceRoot $sourceDir -OutputRoot $outputRoot -CustomQueriesRoot $emptyCustomRoot

        Test-Path (Join-Path $outputRoot 'SQL Server 2099/manifest.json') | Should -Be $true
        Test-Path (Join-Path $outputRoot 'SQL Server 2099/Instance/Query01-Thing.sql') | Should -Be $true
    }

    It 'merges custom queries from CustomQueriesRoot into every split version folder' {
        $customInstanceDir = Join-Path $emptyCustomRoot 'Instance'
        New-Item -ItemType Directory -Path $customInstanceDir -Force | Out-Null
        @'
-- List sysadmin members (Query 100) (Server Role Members)
SELECT 1;
'@ | Set-Content -LiteralPath (Join-Path $customInstanceDir 'Query100-Server Role Members.sql') -Encoding UTF8

        & $scriptPath -SourceRoot $sourceDir -OutputRoot $outputRoot -CustomQueriesRoot $emptyCustomRoot

        Test-Path (Join-Path $outputRoot 'SQL Server 2099/Instance/Query100-Server Role Members.sql') | Should -Be $true

        $parsedManifest = Get-Content -LiteralPath (Join-Path $outputRoot 'SQL Server 2099/manifest.json') -Raw | ConvertFrom-Json
        $manifest = @($parsedManifest)
        $manifest.Count | Should -Be 2
        ($manifest | Where-Object Number -eq 100).ShortName | Should -Be 'Server Role Members'
    }
}
