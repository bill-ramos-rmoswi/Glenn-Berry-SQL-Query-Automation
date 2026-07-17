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
