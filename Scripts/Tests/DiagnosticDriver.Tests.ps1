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
