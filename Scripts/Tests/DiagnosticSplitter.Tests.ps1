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

Describe 'Add-CustomDiagnosticQueries' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticSplitter.psm1" -Force
    }

    BeforeEach {
        $script:versionRoot = Join-Path $TestDrive "version-$([guid]::NewGuid().ToString('N'))"
        $instanceDir = Join-Path $versionRoot 'Instance'
        $databaseDir = Join-Path $versionRoot 'Database'
        New-Item -ItemType Directory -Path $instanceDir -Force | Out-Null
        New-Item -ItemType Directory -Path $databaseDir -Force | Out-Null

        # Seed a manifest as if Split-DiagnosticQueryFile already ran (vendor queries 1 and 52).
        @(
            [pscustomobject]@{ Number = 1; ShortName = 'Version Info'; Scope = 'Instance'; File = 'Instance/Query01-Version Info.sql' }
            [pscustomobject]@{ Number = 52; ShortName = 'DB Properties'; Scope = 'Database'; File = 'Database/Query52-DB Properties.sql' }
        ) | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $versionRoot 'manifest.json') -Encoding UTF8

        $script:customRoot = Join-Path $TestDrive "custom-$([guid]::NewGuid().ToString('N'))"
        $script:customInstanceDir = Join-Path $customRoot 'Instance'
        New-Item -ItemType Directory -Path $customInstanceDir -Force | Out-Null

        @'
-- List sysadmin members (Query 100) (Server Role Members)
SELECT 1;
'@ | Set-Content -LiteralPath (Join-Path $customInstanceDir 'Query100-Server Role Members.sql') -Encoding UTF8
    }

    It 'copies the custom query file into the version folder and appends a manifest entry' {
        $result = Add-CustomDiagnosticQueries -VersionRoot $versionRoot -CustomQueriesRoot $customRoot

        $result.AddedCount | Should -Be 1
        $result.TotalCount | Should -Be 3

        Test-Path (Join-Path $versionRoot 'Instance/Query100-Server Role Members.sql') | Should -Be $true

        $parsedManifest = Get-Content -LiteralPath (Join-Path $versionRoot 'manifest.json') -Raw | ConvertFrom-Json
        $manifest = @($parsedManifest)
        $manifest.Count | Should -Be 3
        ($manifest | Where-Object Number -eq 1).ShortName | Should -Be 'Version Info'
        ($manifest | Where-Object Number -eq 52).ShortName | Should -Be 'DB Properties'
        $custom = $manifest | Where-Object Number -eq 100
        $custom.ShortName | Should -Be 'Server Role Members'
        $custom.Scope | Should -Be 'Instance'
        $custom.File | Should -Be 'Instance/Query100-Server Role Members.sql'
    }

    It 'does not disturb existing vendor manifest entries or collide with their numbers' {
        Add-CustomDiagnosticQueries -VersionRoot $versionRoot -CustomQueriesRoot $customRoot | Out-Null

        $parsedManifest = Get-Content -LiteralPath (Join-Path $versionRoot 'manifest.json') -Raw | ConvertFrom-Json
        $manifest = @($parsedManifest)
        $numbers = $manifest.Number | Sort-Object
        $numbers | Should -Be @(1, 52, 100)
    }

    It 'is idempotent: re-running does not duplicate the manifest entry and overwrites edited content' {
        Add-CustomDiagnosticQueries -VersionRoot $versionRoot -CustomQueriesRoot $customRoot | Out-Null

        @'
-- List sysadmin members (Query 100) (Server Role Members)
SELECT 2; -- edited
'@ | Set-Content -LiteralPath (Join-Path $customInstanceDir 'Query100-Server Role Members.sql') -Encoding UTF8

        $result = Add-CustomDiagnosticQueries -VersionRoot $versionRoot -CustomQueriesRoot $customRoot

        $result.TotalCount | Should -Be 3

        $parsedManifest = Get-Content -LiteralPath (Join-Path $versionRoot 'manifest.json') -Raw | ConvertFrom-Json
        $manifest = @($parsedManifest)
        @($manifest | Where-Object Number -eq 100).Count | Should -Be 1

        $copiedContent = Get-Content -LiteralPath (Join-Path $versionRoot 'Instance/Query100-Server Role Members.sql') -Raw
        $copiedContent | Should -Match 'SELECT 2; -- edited'
    }

    It 'is a no-op when the custom queries root has no matching Instance/Database subfolders' {
        $emptyCustomRoot = Join-Path $TestDrive "empty-custom-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $emptyCustomRoot -Force | Out-Null

        $result = Add-CustomDiagnosticQueries -VersionRoot $versionRoot -CustomQueriesRoot $emptyCustomRoot

        $result.AddedCount | Should -Be 0
        $result.TotalCount | Should -Be 2
    }

    It 'throws when a custom query file has no (Query N) (Short Name) header' {
        Set-Content -LiteralPath (Join-Path $customInstanceDir 'Query101-No Header.sql') -Value 'SELECT 1;' -Encoding UTF8

        { Add-CustomDiagnosticQueries -VersionRoot $versionRoot -CustomQueriesRoot $customRoot } | Should -Throw
    }
}
