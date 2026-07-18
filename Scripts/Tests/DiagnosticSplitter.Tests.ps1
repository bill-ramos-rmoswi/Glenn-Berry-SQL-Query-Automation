Describe 'Get-DiagnosticQueryBlocks' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticSplitter.psm1" -Force
    }

    It 'extracts instance and database scoped query blocks with correct numbers, names, and scope' {
        $lines = @(
            '-- Instance level queries *******************************'
            ''
            '-- Get selected server properties (Query 3) (Server Properties)'
            'SELECT 1 AS Foo;'
            '------'
            ''
            '-- Get instance-level configuration values for instance  (Query 4) (Configuration Values)'
            'SELECT 2 AS Bar;'
            ''
            '-- Database specific queries *****************************************************************'
            ''
            '-- **** Please switch to a user database that you are interested in! *****'
            '--USE YourDatabaseName;'
            '--GO'
            ''
            '-- Get database properties (Query 52) (DB Properties)'
            'SELECT 3 AS Baz;'
        )

        $result = @(Get-DiagnosticQueryBlocks -Lines $lines)

        $result.Count | Should -Be 3

        $result[0].Number | Should -Be 3
        $result[0].ShortName | Should -Be 'Server Properties'
        $result[0].Scope | Should -Be 'Instance'
        $result[0].Content | Should -Match 'SELECT 1 AS Foo;'
        $result[0].Content | Should -Not -Match 'Configuration Values'

        $result[1].Number | Should -Be 4
        $result[1].Scope | Should -Be 'Instance'

        $result[2].Number | Should -Be 52
        $result[2].ShortName | Should -Be 'DB Properties'
        $result[2].Scope | Should -Be 'Database'
        $result[2].Content | Should -Not -Match 'YourDatabaseName'
    }

    It 'trims trailing blank lines from block content' {
        $lines = @(
            '-- Get thing (Query 1) (Thing)'
            'SELECT 1;'
            ''
            ''
        )

        $result = @(Get-DiagnosticQueryBlocks -Lines $lines)
        $expected = @('-- Get thing (Query 1) (Thing)', 'SELECT 1;') -join [Environment]::NewLine

        $result[0].Content | Should -Be $expected
    }
}

Describe 'Split-DiagnosticQueryFile' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticSplitter.psm1" -Force
    }

    BeforeEach {
        $sourceDir = Join-Path $TestDrive 'source'
        $outputRoot = Join-Path $TestDrive 'output'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null

        $script:sourcePath = Join-Path $sourceDir 'SQL Server 2022 Diagnostic Information Queries.sql'
        $script:outputRoot = $outputRoot

        @'

-- SQL Server 2022 Diagnostic Information Queries
-- Glenn Berry

--******************************************************************************
--*   Copyright (C) 2026 Glenn Berry
--*   All rights reserved.
--******************************************************************************

IF NOT EXISTS (SELECT * WHERE 1 = 0)
    PRINT N'version guard';

-- Instance level queries *******************************

-- Get selected server properties (Query 3) (Server Properties)
SELECT 1 AS Foo;
------

-- Database specific queries *****************************************************************

-- **** Please switch to a user database that you are interested in! *****
--USE YourDatabaseName;
--GO

-- Get database properties (Query 52) (DB Properties)
SELECT 2 AS Bar;
'@ | Set-Content -LiteralPath $sourcePath -Encoding UTF8
    }

    It 'writes per-query files under Instance/Database folders with the copyright block prepended' {
        $result = Split-DiagnosticQueryFile -SourcePath $sourcePath -OutputRoot $outputRoot

        $result.VersionFolder | Should -Be 'SQL Server 2022'
        $result.InstanceCount | Should -Be 1
        $result.DatabaseCount | Should -Be 1

        $instanceFile = Join-Path $outputRoot 'SQL Server 2022/Instance/Query03-Server Properties.sql'
        $databaseFile = Join-Path $outputRoot 'SQL Server 2022/Database/Query52-DB Properties.sql'

        Test-Path $instanceFile | Should -Be $true
        Test-Path $databaseFile | Should -Be $true

        $instanceContent = Get-Content -LiteralPath $instanceFile -Raw
        $instanceContent | Should -Match 'Copyright \(C\) 2026 Glenn Berry'
        $instanceContent | Should -Match 'SELECT 1 AS Foo;'
        $instanceContent | Should -Not -Match 'version guard'
    }

    It 'writes a manifest.json describing every split query' {
        Split-DiagnosticQueryFile -SourcePath $sourcePath -OutputRoot $outputRoot | Out-Null

        $manifestPath = Join-Path $outputRoot 'SQL Server 2022/manifest.json'
        Test-Path $manifestPath | Should -Be $true

        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifest.Count | Should -Be 2
        $manifest[0].Number | Should -Be 3
        $manifest[0].Scope | Should -Be 'Instance'
        $manifest[0].File | Should -Be 'Instance/Query03-Server Properties.sql'
        $manifest[1].Number | Should -Be 52
        $manifest[1].Scope | Should -Be 'Database'
    }
}
