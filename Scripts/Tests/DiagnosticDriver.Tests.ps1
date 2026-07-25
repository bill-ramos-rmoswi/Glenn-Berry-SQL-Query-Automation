Describe 'Get-VersionFolderName' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticDriver.psm1" -Force
        $script:realQueryLibraryRoot = "$PSScriptRoot/../QueryLibrary"
    }

    It 'maps known ProductMajorVersion numbers to their query library folder when the folder exists' {
        Get-VersionFolderName -ProductMajorVersion 13 -QueryLibraryRoot $realQueryLibraryRoot | Should -Be 'SQL Server 2016 SP2'
        Get-VersionFolderName -ProductMajorVersion 14 -QueryLibraryRoot $realQueryLibraryRoot | Should -Be 'SQL Server 2017'
        Get-VersionFolderName -ProductMajorVersion 15 -QueryLibraryRoot $realQueryLibraryRoot | Should -Be 'SQL Server 2019'
        Get-VersionFolderName -ProductMajorVersion 16 -QueryLibraryRoot $realQueryLibraryRoot | Should -Be 'SQL Server 2022'
        Get-VersionFolderName -ProductMajorVersion 17 -QueryLibraryRoot $realQueryLibraryRoot | Should -Be 'SQL Server 2025'
    }

    It 'returns $null for an unmapped version' {
        Get-VersionFolderName -ProductMajorVersion 99 -QueryLibraryRoot $realQueryLibraryRoot | Should -Be $null
    }

    It 'returns $null for a mapped version whose query library folder does not exist' {
        $emptyRoot = Join-Path $TestDrive 'EmptyQueryLibrary'
        New-Item -ItemType Directory -Path $emptyRoot -Force | Out-Null

        Get-VersionFolderName -ProductMajorVersion 16 -QueryLibraryRoot $emptyRoot | Should -Be $null
    }
}

Describe 'Read-DiagnosticManifest' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticDriver.psm1" -Force
    }

    It 'reads manifest entries from a JSON file' {
        $manifestPath = Join-Path $TestDrive 'manifest.json'
        '[{"Number":1,"ShortName":"Thing","Scope":"Instance","File":"Instance/Query01-Thing.sql"}]' |
            Set-Content -LiteralPath $manifestPath -Encoding UTF8

        $result = @(Read-DiagnosticManifest -ManifestPath $manifestPath)

        $result.Count | Should -Be 1
        $result[0].Number | Should -Be 1
        $result[0].File | Should -Be 'Instance/Query01-Thing.sql'
    }

    It 'correctly handles multiple manifest entries without array wrapping' {
        $manifestPath = Join-Path $TestDrive 'manifest-multi.json'
        '[{"Number":1,"ShortName":"A","Scope":"Instance","File":"a.sql"},{"Number":2,"ShortName":"B","Scope":"Instance","File":"b.sql"}]' |
            Set-Content -LiteralPath $manifestPath -Encoding UTF8

        $result = @(Read-DiagnosticManifest -ManifestPath $manifestPath)

        $result.Count | Should -Be 2
        $result[0].Number | Should -Be 1
        $result[1].Number | Should -Be 2
    }
}

Describe 'Get-FilteredManifestQueries' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticDriver.psm1" -Force

        $script:manifest = @(
            [pscustomobject]@{ Number = 3; ShortName = 'A'; Scope = 'Instance'; File = 'Instance/Query03-A.sql' }
            [pscustomobject]@{ Number = 1; ShortName = 'B'; Scope = 'Instance'; File = 'Instance/Query01-B.sql' }
            [pscustomobject]@{ Number = 52; ShortName = 'C'; Scope = 'Database'; File = 'Database/Query52-C.sql' }
        )
    }

    It 'returns only queries matching the requested scope, sorted by number' {
        $result = @(Get-FilteredManifestQueries -ManifestQueries $manifest -Scope 'Instance' -ExcludedQueryNumbers @())

        $result.Count | Should -Be 2
        $result[0].Number | Should -Be 1
        $result[1].Number | Should -Be 3
    }

    It 'excludes query numbers in ExcludedQueryNumbers' {
        $result = @(Get-FilteredManifestQueries -ManifestQueries $manifest -Scope 'Instance' -ExcludedQueryNumbers @(3))

        $result.Count | Should -Be 1
        $result[0].Number | Should -Be 1
    }
}

Describe 'Add-ResultPrefixColumns' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticDriver.psm1" -Force
    }

    It 'prepends the given columns to every row, preserving original column order' {
        $rows = @(
            [pscustomobject]@{ DatabaseName2 = 'ignored-name-collision-check'; SizeMB = 100 }
            [pscustomobject]@{ DatabaseName2 = 'ignored-name-collision-check'; SizeMB = 200 }
        )
        $prefix = [ordered]@{ ServerName = 'localhost'; DatabaseName = 'LMS' }

        $result = @(Add-ResultPrefixColumns -Rows $rows -PrefixColumns $prefix)

        $result.Count | Should -Be 2
        $propNames = $result[0].PSObject.Properties.Name
        $propNames[0] | Should -Be 'ServerName'
        $propNames[1] | Should -Be 'DatabaseName'
        $propNames[2] | Should -Be 'DatabaseName2'
        $propNames[3] | Should -Be 'SizeMB'
        $result[0].ServerName | Should -Be 'localhost'
        $result[0].DatabaseName | Should -Be 'LMS'
        $result[1].SizeMB | Should -Be 200
    }

    It 'returns an empty array for empty input' {
        $result = @(Add-ResultPrefixColumns -Rows @() -PrefixColumns ([ordered]@{ ServerName = 'localhost' }))
        $result.Count | Should -Be 0
    }
}

Describe 'Get-ResultCsvPath' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticDriver.psm1" -Force
    }

    It 'builds an instance-level path with no database segment' {
        $path = Get-ResultCsvPath -RunFolder 'C:\Results\run1' -ServerName 'localhost' -QueryNumber 1 -ShortName 'Version Info'
        $path | Should -Be 'C:\Results\run1\localhost-Query-1-Version Info.csv'
    }

    It 'builds a database-level path including the database name' {
        $path = Get-ResultCsvPath -RunFolder 'C:\Results\run1' -ServerName 'localhost' -DatabaseName 'LMS' -QueryNumber 52 -ShortName 'DB Properties'
        $path | Should -Be 'C:\Results\run1\localhost-LMS-Query-52-DB Properties.csv'
    }

    It 'sanitizes filesystem-invalid characters in the short name' {
        $path = Get-ResultCsvPath -RunFolder 'C:\Results\run1' -ServerName 'localhost' -QueryNumber 1 -ShortName 'A/B:C'
        $path | Should -Be 'C:\Results\run1\localhost-Query-1-A-B-C.csv'
    }
}

Describe 'New-DiagnosticConnectionString' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticDriver.psm1" -Force
    }

    It 'defaults to the master database with Integrated Security and mandatory encryption' {
        $connString = New-DiagnosticConnectionString -ServerName 'localhost'
        $connString | Should -Be 'Server=localhost;Database=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connection Timeout=15'
    }

    It 'uses the given database name when provided' {
        $connString = New-DiagnosticConnectionString -ServerName 'localhost' -Database 'LMS'
        $connString | Should -Be 'Server=localhost;Database=LMS;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connection Timeout=15'
    }

    It 'uses Encrypt=False when -Encrypt $false is passed' {
        $connString = New-DiagnosticConnectionString -ServerName 'localhost' -Encrypt $false
        $connString | Should -Be 'Server=localhost;Database=master;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=15'
    }
}

Describe 'Test-ServerConnection' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticDriver.psm1" -Force
    }

    It 'succeeds on the first attempt with Encrypt=True' {
        Mock -CommandName Invoke-Sqlcmd -ModuleName DiagnosticDriver { return [pscustomobject]@{} }

        $result = Test-ServerConnection -ServerName 'localhost'

        $result.Success | Should -Be $true
        $result.Encrypt | Should -Be $true
        $result.ConnectionString | Should -Match 'Encrypt=True'
        Should -Invoke -CommandName Invoke-Sqlcmd -ModuleName DiagnosticDriver -Times 1
    }

    It 'falls back to Encrypt=False when the first attempt fails' {
        Mock -CommandName Invoke-Sqlcmd -ModuleName DiagnosticDriver {
            if ($ConnectionString -match 'Encrypt=True') {
                throw 'A connection was successfully established with the server, but then an error occurred'
            }
            return [pscustomobject]@{}
        }

        $result = Test-ServerConnection -ServerName 'localhost'

        $result.Success | Should -Be $true
        $result.Encrypt | Should -Be $false
        $result.ConnectionString | Should -Match 'Encrypt=False'
        Should -Invoke -CommandName Invoke-Sqlcmd -ModuleName DiagnosticDriver -Times 2
    }

    It 'reports failure with the last error message when both attempts fail' {
        Mock -CommandName Invoke-Sqlcmd -ModuleName DiagnosticDriver { throw 'Cannot connect' }

        $result = Test-ServerConnection -ServerName 'unreachable-host'

        $result.Success | Should -Be $false
        $result.ConnectionString | Should -Be $null
        $result.ErrorMessage | Should -Match 'Cannot connect'
        Should -Invoke -CommandName Invoke-Sqlcmd -ModuleName DiagnosticDriver -Times 2
    }
}

Describe 'Get-SanitizedFileSystemName' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticDriver.psm1" -Force
    }

    It 'replaces filesystem-invalid characters with a hyphen' {
        Get-SanitizedFileSystemName -Name 'A/B:C' | Should -Be 'A-B-C'
    }

    It 'leaves valid names unchanged' {
        Get-SanitizedFileSystemName -Name 'localhost' | Should -Be 'localhost'
    }
}

Describe 'Get-OnlineUserDatabaseNames' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticDriver.psm1" -Force

        $script:rows = @(
            [pscustomobject]@{ name = 'master'; database_id = 1; state_desc = 'ONLINE' }
            [pscustomobject]@{ name = 'LMS'; database_id = 5; state_desc = 'ONLINE' }
            [pscustomobject]@{ name = 'Archive'; database_id = 6; state_desc = 'OFFLINE' }
            [pscustomobject]@{ name = 'Scratch'; database_id = 7; state_desc = 'ONLINE' }
        )
    }

    It 'excludes system databases and offline databases' {
        $result = @(Get-OnlineUserDatabaseNames -DatabaseRows $rows -ExcludedDatabases @())
        $result | Should -Be @('LMS', 'Scratch')
    }

    It 'excludes names in ExcludedDatabases' {
        $result = @(Get-OnlineUserDatabaseNames -DatabaseRows $rows -ExcludedDatabases @('Scratch'))
        $result | Should -Be @('LMS')
    }
}
