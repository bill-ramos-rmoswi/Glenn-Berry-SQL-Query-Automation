Describe 'Get-VersionFolderName' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticDriver.psm1" -Force
    }

    It 'maps known ProductMajorVersion numbers to their query library folder' {
        Get-VersionFolderName -ProductMajorVersion 16 | Should -Be 'SQL Server 2022'
        Get-VersionFolderName -ProductMajorVersion 13 | Should -Be 'SQL Server 2016 SP2'
    }

    It 'returns $null for an unmapped version' {
        Get-VersionFolderName -ProductMajorVersion 99 | Should -Be $null
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
