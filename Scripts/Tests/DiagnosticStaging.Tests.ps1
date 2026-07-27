Describe 'New-DiagnosticSqlAuthConnectionString' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticStaging.psm1" -Force
    }

    It 'builds a SQL-auth connection string with mandatory encryption by default' {
        $result = New-DiagnosticSqlAuthConnectionString -ServerName 'localhost' -Database 'GlennBerrySQLDiag' -Username 'Claude' -Password 'p@ss'
        $result | Should -Be 'Server=localhost;Database=GlennBerrySQLDiag;User Id=Claude;Password=p@ss;Encrypt=True;TrustServerCertificate=True;Connection Timeout=15'
    }

    It 'defaults to the master database when none is given' {
        $result = New-DiagnosticSqlAuthConnectionString -ServerName 'localhost' -Username 'Claude' -Password 'p@ss'
        $result | Should -Match 'Database=master;'
    }

    It 'uses Encrypt=False when -Encrypt $false is passed' {
        $result = New-DiagnosticSqlAuthConnectionString -ServerName 'localhost' -Username 'Claude' -Password 'p@ss' -Encrypt $false
        $result | Should -Match 'Encrypt=False;'
    }
}

Describe 'Get-StagingTableName' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticStaging.psm1" -Force
    }

    It 'replaces spaces and punctuation with underscores' {
        Get-StagingTableName -ShortName 'Server Properties' | Should -Be 'stg.Server_Properties'
        Get-StagingTableName -ShortName 'Overall Index Usage - Reads' | Should -Be 'stg.Overall_Index_Usage_Reads'
    }

    It 'trims leading and trailing underscores produced by punctuation at the edges' {
        Get-StagingTableName -ShortName '(Legacy) Missing Indexes!' | Should -Be 'stg.Legacy_Missing_Indexes'
    }

    It 'prefixes with T_ when the sanitized name would start with a digit' {
        Get-StagingTableName -ShortName '32-bit Settings' | Should -Be 'stg.T_32_bit_Settings'
    }

    It 'throws when the ShortName sanitizes to an empty string' {
        { Get-StagingTableName -ShortName '---' } | Should -Throw
    }
}

Describe 'Get-DiagnosticRunTimestamp' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticStaging.psm1" -Force
    }

    It 'parses a yyyyMMdd_HHmmss folder name into a DateTime' {
        $result = Get-DiagnosticRunTimestamp -RunFolderName '20260727_104902'
        $result | Should -Be ([datetime]::new(2026, 7, 27, 10, 49, 2))
    }

    It 'throws for a folder name that does not match the expected format' {
        { Get-DiagnosticRunTimestamp -RunFolderName 'latest' } | Should -Throw
    }
}

Describe 'Get-DiagnosticResultCsvMetadata' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticStaging.psm1" -Force
    }

    It 'parses an instance-scope file name with no database segment' {
        $result = Get-DiagnosticResultCsvMetadata -ServerFolderName 'cut1sqlp01' -FileName 'cut1sqlp01-Query-3-Server Properties.csv'
        $result.IsErrorsFile | Should -Be $false
        $result.DatabaseName | Should -BeNullOrEmpty
        $result.QueryNumber | Should -Be 3
        $result.ShortName | Should -Be 'Server Properties'
    }

    It 'parses a database-scope file name' {
        $result = Get-DiagnosticResultCsvMetadata -ServerFolderName 'cut1sqlp01' -FileName 'cut1sqlp01-ADP-Query-52-File Sizes and Space.csv'
        $result.IsErrorsFile | Should -Be $false
        $result.DatabaseName | Should -Be 'ADP'
        $result.QueryNumber | Should -Be 52
        $result.ShortName | Should -Be 'File Sizes and Space'
    }

    It 'handles server and database names that themselves contain hyphens' {
        $result = Get-DiagnosticResultCsvMetadata -ServerFolderName 'dc1-bi-vault-pr' -FileName 'dc1-bi-vault-pr-logicpathDRSFFireCU_CA-Query-52-File Sizes and Space.csv'
        $result.DatabaseName | Should -Be 'logicpathDRSFFireCU_CA'
        $result.QueryNumber | Should -Be 52
        $result.ShortName | Should -Be 'File Sizes and Space'
    }

    It 'recognizes errors.csv as a special errors file' {
        $result = Get-DiagnosticResultCsvMetadata -ServerFolderName 'cut1sqlp01' -FileName 'errors.csv'
        $result.IsErrorsFile | Should -Be $true
    }

    It 'throws when the file name does not start with the server folder prefix' {
        { Get-DiagnosticResultCsvMetadata -ServerFolderName 'cut1sqlp01' -FileName 'otherserver-Query-3-Server Properties.csv' } | Should -Throw
    }

    It 'throws when the remainder does not match the expected Query-N pattern' {
        { Get-DiagnosticResultCsvMetadata -ServerFolderName 'cut1sqlp01' -FileName 'cut1sqlp01-NotAQueryFile.csv' } | Should -Throw
    }
}

Describe 'ConvertTo-DiagnosticDataTable' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticStaging.psm1" -Force
    }

    It 'creates one column per property and one row per input object' {
        $rows = @(
            [pscustomobject]@{ RunId = 1; ServerName = 'srv1'; Value = 'a' }
            [pscustomobject]@{ RunId = 1; ServerName = 'srv1'; Value = 'b' }
        )

        $table = ConvertTo-DiagnosticDataTable -Rows $rows

        $table.Columns.Count | Should -Be 3
        $table.Rows.Count | Should -Be 2
        $table.Rows[0]['Value'] | Should -Be 'a'
        $table.Rows[1]['Value'] | Should -Be 'b'
    }

    It 'types an integer-valued property as an INT column and everything else as string' {
        $rows = @([pscustomobject]@{ RunId = 1; Name = 'x' })
        $table = ConvertTo-DiagnosticDataTable -Rows $rows

        $table.Columns['RunId'].DataType | Should -Be ([int])
        $table.Columns['Name'].DataType | Should -Be ([string])
    }

    It 'maps $null and DBNull property values to DBNull in the resulting row' {
        $rows = @([pscustomobject]@{ RunId = 1; A = $null; B = ([System.DBNull]::Value) })
        $table = ConvertTo-DiagnosticDataTable -Rows $rows

        $table.Rows[0]['A'] | Should -BeOfType [System.DBNull]
        $table.Rows[0]['B'] | Should -BeOfType [System.DBNull]
    }

    It 'returns an empty DataTable with no columns for zero input rows' {
        $table = ConvertTo-DiagnosticDataTable -Rows @()
        $table.Columns.Count | Should -Be 0
        $table.Rows.Count | Should -Be 0
    }
}

Describe 'Get-DiagnosticTableColumnPlan' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticStaging.psm1" -Force
    }

    It 'returns required columns that are not already present' {
        $missing = Get-DiagnosticTableColumnPlan -ExistingColumns @('RunId', 'ServerName') -RequiredColumns @('RunId', 'ServerName', 'allow_row_locks', 'optimize_for_sequential_key')
        $missing | Should -Be @('allow_row_locks', 'optimize_for_sequential_key')
    }

    It 'returns an empty array when every required column already exists' {
        $missing = Get-DiagnosticTableColumnPlan -ExistingColumns @('RunId', 'ServerName', 'Foo') -RequiredColumns @('RunId', 'Foo')
        @($missing).Count | Should -Be 0
    }

    It 'compares column names case-insensitively' {
        $missing = Get-DiagnosticTableColumnPlan -ExistingColumns @('runid') -RequiredColumns @('RunId')
        @($missing).Count | Should -Be 0
    }

    It 'treats every required column as missing when the table has no existing columns' {
        $missing = Get-DiagnosticTableColumnPlan -ExistingColumns @() -RequiredColumns @('RunId', 'ServerName')
        $missing | Should -Be @('RunId', 'ServerName')
    }
}

Describe 'Get-DiagnosticImportPlan' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticStaging.psm1" -Force
    }

    It 'builds an import plan from a Results\<timestamp>\ folder, keyed by ShortName not query number' {
        $runFolder = Join-Path $TestDrive '20260727_104902'
        $serverFolder = Join-Path $runFolder 'cut1sqlp01'
        New-Item -ItemType Directory -Path $serverFolder -Force | Out-Null

        'ServerName' | Set-Content -LiteralPath (Join-Path $serverFolder 'cut1sqlp01-Query-3-Server Properties.csv')
        'ServerName' | Set-Content -LiteralPath (Join-Path $serverFolder 'cut1sqlp01-ADP-Query-52-File Sizes and Space.csv')
        'ServerName' | Set-Content -LiteralPath (Join-Path $serverFolder 'errors.csv')

        $plan = Get-DiagnosticImportPlan -ResultsFolder $runFolder

        $plan.RunFolderName | Should -Be '20260727_104902'
        $plan.RunTimestamp | Should -Be ([datetime]::new(2026, 7, 27, 10, 49, 2))
        $plan.Items.Count | Should -Be 3

        $instanceItem = $plan.Items | Where-Object { $_.ShortName -eq 'Server Properties' }
        $instanceItem.TableName | Should -Be 'stg.Server_Properties'
        $instanceItem.DatabaseName | Should -BeNullOrEmpty

        $dbItem = $plan.Items | Where-Object { $_.ShortName -eq 'File Sizes and Space' }
        $dbItem.TableName | Should -Be 'stg.File_Sizes_and_Space'
        $dbItem.DatabaseName | Should -Be 'ADP'

        $errorsItem = $plan.Items | Where-Object { $_.IsErrorsFile }
        $errorsItem.TableName | Should -Be 'stg.RunErrors'
    }
}
