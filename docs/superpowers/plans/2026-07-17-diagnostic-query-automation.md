# Diagnostic Query Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split Glenn Berry's monolithic per-version diagnostic query files into individually executable per-query `.sql` files, and drive them against a list of SQL Server instances, exporting results to per-query CSVs.

**Architecture:** Two PowerShell modules (`DiagnosticSplitter.psm1`, `DiagnosticDriver.psm1`) hold all testable logic as pure or thin-I/O functions; two small CLI scripts (`Split-DiagnosticQueries.ps1`, `Invoke-DiagnosticRun.ps1`) wire them together for interactive use. JSON config files describe the server list and global exclusions.

**Tech Stack:** Windows PowerShell 5.1, Pester 5/6 (installed to CurrentUser scope) for unit tests, `System.Data.SqlClient` (built into .NET Framework, no extra install) for SQL connectivity.

## Global Constraints

- Windows/Integrated auth only for v1 — no SQL auth, no credential prompting (per approved spec).
- Every SQL connection string uses `Encrypt=Mandatory;TrustServerCertificate=True;Integrated Security=True`.
- Servers are processed sequentially, one at a time — no parallelism in v1.
- Query and database exclusions are global JSON lists (`Scripts/config/exclusions.json`), applied uniformly to every server in a run.
- Only the first result set of a query is captured (per spec, multi-result-set queries are out of scope for v1).
- The Copyright block from each source file must be prepended verbatim to every split per-query file; the top-of-file `ProductMajorVersion` version-check guard must NOT be duplicated into per-query files.
- Split output under `Scripts/QueryLibrary/` is committed to git.
- Result CSVs under `Results/` are run artifacts, not committed (gitignored).
- Instance-level query filenames: `<ServerName>-Query-<N>-<ShortName>.csv`. Database-level query filenames: `<ServerName>-<DatabaseName>-Query-<N>-<ShortName>.csv`, and database-level result rows get `ServerName`/`DatabaseName` prepended as the first two CSV columns; instance-level rows get no prefix columns.

---

## File Structure

```
Scripts/
  Modules/
    DiagnosticSplitter.psm1     # Get-DiagnosticQueryBlocks, Split-DiagnosticQueryFile
    DiagnosticDriver.psm1       # version mapping, manifest filtering, CSV shaping, SQL execution, orchestration
  Split-DiagnosticQueries.ps1   # CLI: split all SQL-Diag-Source-Files/*.sql into Scripts/QueryLibrary/
  Invoke-DiagnosticRun.ps1      # CLI: run a diagnostic pass against configured servers
  QueryLibrary/
    SQL Server 2022/
      manifest.json
      Instance/Query01-Version Info.sql ...
      Database/Query52-....sql ...
    SQL Server 2016 SP2/
      ... (same shape)
  config/
    servers.json
    exclusions.json
  Tests/
    DiagnosticSplitter.Tests.ps1
    DiagnosticDriver.Tests.ps1
Results/                        # gitignored, created at run time
.gitignore                      # updated to exclude Results/
```

---

### Task 1: Splitter module — query block parsing

**Files:**
- Create: `Scripts/Modules/DiagnosticSplitter.psm1`
- Test: `Scripts/Tests/DiagnosticSplitter.Tests.ps1`

**Interfaces:**
- Produces: `Get-DiagnosticQueryBlocks -Lines <string[]>` → array of `[pscustomobject]@{ Number:int; ShortName:string; Description:string; Scope:'Instance'|'Database'; Content:string }`, one per `(Query N) (ShortName)` header found in `Lines`, in source order. `Content` is the header line through the last non-blank line before the next header/EOF (trailing blank lines trimmed). Scope switches on `Instance level queries` / `Database specific queries` banner lines and applies to every block parsed after that point. Lines before the first header (including any version-check guard) are discarded.

- [ ] **Step 1: Write the failing test**

Create `Scripts/Tests/DiagnosticSplitter.Tests.ps1`:

```powershell
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticSplitter.Tests.ps1 -Output Detailed"`
Expected: FAIL — module file `Scripts/Modules/DiagnosticSplitter.psm1` does not exist / `Get-DiagnosticQueryBlocks` not recognized.

- [ ] **Step 3: Write minimal implementation**

Create `Scripts/Modules/DiagnosticSplitter.psm1`:

```powershell
function Get-DiagnosticQueryBlocks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Lines
    )

    $headerPattern = '^--\s*(?<desc>.+?)\s*\(Query\s+(?<num>\d+)\)\s*\((?<short>[^)]+)\)\s*$'

    $blocks = [System.Collections.Generic.List[pscustomobject]]::new()
    $currentScope = 'Instance'
    $current = $null
    $buffer = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $Lines) {
        if ($line -match 'Instance level queries') {
            $currentScope = 'Instance'
            continue
        }
        if ($line -match 'Database specific queries') {
            $currentScope = 'Database'
            continue
        }

        $headerMatch = [regex]::Match($line, $headerPattern)
        if ($headerMatch.Success) {
            if ($null -ne $current) {
                while ($buffer.Count -gt 0 -and [string]::IsNullOrWhiteSpace($buffer[$buffer.Count - 1])) {
                    $buffer.RemoveAt($buffer.Count - 1)
                }
                $current.Content = ($buffer -join [Environment]::NewLine)
                $blocks.Add($current)
            }

            $buffer = [System.Collections.Generic.List[string]]::new()
            $buffer.Add($line)
            $current = [pscustomobject]@{
                Number      = [int]$headerMatch.Groups['num'].Value
                ShortName   = $headerMatch.Groups['short'].Value.Trim()
                Description = $headerMatch.Groups['desc'].Value.Trim()
                Scope       = $currentScope
                Content     = ''
            }
            continue
        }

        if ($null -ne $current) {
            $buffer.Add($line)
        }
    }

    if ($null -ne $current) {
        while ($buffer.Count -gt 0 -and [string]::IsNullOrWhiteSpace($buffer[$buffer.Count - 1])) {
            $buffer.RemoveAt($buffer.Count - 1)
        }
        $current.Content = ($buffer -join [Environment]::NewLine)
        $blocks.Add($current)
    }

    return ,$blocks.ToArray()
}

Export-ModuleMember -Function Get-DiagnosticQueryBlocks
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticSplitter.Tests.ps1 -Output Detailed"`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add Scripts/Modules/DiagnosticSplitter.psm1 Scripts/Tests/DiagnosticSplitter.Tests.ps1
git commit -m "feat: add diagnostic query block parser"
```

---

### Task 2: Splitter module — writing per-query files and manifest

**Files:**
- Modify: `Scripts/Modules/DiagnosticSplitter.psm1`
- Modify: `Scripts/Tests/DiagnosticSplitter.Tests.ps1`

**Interfaces:**
- Consumes: `Get-DiagnosticQueryBlocks` from Task 1.
- Produces: `Split-DiagnosticQueryFile -SourcePath <string> -OutputRoot <string>` → `[pscustomobject]@{ VersionFolder:string; InstanceCount:int; DatabaseCount:int; ManifestPath:string }`. Writes `<OutputRoot>/<VersionFolder>/Instance/QueryNN-<ShortName>.sql`, `.../Database/QueryNN-<ShortName>.sql` (each prefixed with the source file's Copyright block), and `<OutputRoot>/<VersionFolder>/manifest.json` (array of `{Number, ShortName, Scope, File}` sorted by Number, `File` relative to the version folder, e.g. `Instance/Query03-Server Properties.sql`). `VersionFolder` is the source filename with `.sql` and trailing `" Diagnostic Information Queries"` stripped (e.g. `SQL Server 2022 Diagnostic Information Queries.sql` → `SQL Server 2022`). Re-running against the same `SourcePath`/`OutputRoot` deletes and regenerates that version folder.

- [ ] **Step 1: Write the failing test**

Append to `Scripts/Tests/DiagnosticSplitter.Tests.ps1`:

```powershell
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

        $manifest = @(Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json)
        $manifest.Count | Should -Be 2
        $manifest[0].Number | Should -Be 3
        $manifest[0].Scope | Should -Be 'Instance'
        $manifest[0].File | Should -Be 'Instance/Query03-Server Properties.sql'
        $manifest[1].Number | Should -Be 52
        $manifest[1].Scope | Should -Be 'Database'
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticSplitter.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Split-DiagnosticQueryFile` not recognized.

- [ ] **Step 3: Write minimal implementation**

Add to `Scripts/Modules/DiagnosticSplitter.psm1` (above the `Export-ModuleMember` line, and update that line):

```powershell
function Split-DiagnosticQueryFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$OutputRoot
    )

    $sourceLines = Get-Content -LiteralPath $SourcePath
    $sourceText = $sourceLines -join [Environment]::NewLine

    $copyrightMatch = [regex]::Match($sourceText, '(?s)--\*{10,}.*?Copyright.*?--\*{10,}')
    if (-not $copyrightMatch.Success) {
        throw "Could not find Copyright block in '$SourcePath'"
    }
    $copyrightBlock = $copyrightMatch.Value

    $versionFolderName = ([System.IO.Path]::GetFileNameWithoutExtension($SourcePath)) -replace '\s+Diagnostic Information Queries$', ''

    $blocks = Get-DiagnosticQueryBlocks -Lines $sourceLines

    $versionRoot = Join-Path $OutputRoot $versionFolderName
    $instanceDir = Join-Path $versionRoot 'Instance'
    $databaseDir = Join-Path $versionRoot 'Database'

    if (Test-Path -LiteralPath $versionRoot) {
        Remove-Item -LiteralPath $versionRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $instanceDir -Force | Out-Null
    New-Item -ItemType Directory -Path $databaseDir -Force | Out-Null

    $invalidChars = [regex]::Escape(([System.IO.Path]::GetInvalidFileNameChars() -join ''))
    $manifest = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($block in $blocks) {
        $safeShortName = $block.ShortName -replace "[$invalidChars]", '-'
        $fileName = 'Query{0:D2}-{1}.sql' -f $block.Number, $safeShortName
        $scopeDirName = $block.Scope
        $targetDir = if ($block.Scope -eq 'Instance') { $instanceDir } else { $databaseDir }
        $filePath = Join-Path $targetDir $fileName

        $fileContent = $copyrightBlock + [Environment]::NewLine + [Environment]::NewLine + $block.Content
        Set-Content -LiteralPath $filePath -Value $fileContent -Encoding UTF8

        $manifest.Add([pscustomobject]@{
            Number    = $block.Number
            ShortName = $block.ShortName
            Scope     = $block.Scope
            File      = "$scopeDirName/$fileName"
        })
    }

    $manifestPath = Join-Path $versionRoot 'manifest.json'
    ($manifest | Sort-Object Number) | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    return [pscustomobject]@{
        VersionFolder = $versionFolderName
        InstanceCount = @($manifest | Where-Object Scope -eq 'Instance').Count
        DatabaseCount = @($manifest | Where-Object Scope -eq 'Database').Count
        ManifestPath  = $manifestPath
    }
}

Export-ModuleMember -Function Get-DiagnosticQueryBlocks, Split-DiagnosticQueryFile
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticSplitter.Tests.ps1 -Output Detailed"`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add Scripts/Modules/DiagnosticSplitter.psm1 Scripts/Tests/DiagnosticSplitter.Tests.ps1
git commit -m "feat: write split query files and manifest to disk"
```

---

### Task 3: Splitter CLI wrapper

**Files:**
- Create: `Scripts/Split-DiagnosticQueries.ps1`
- Create: `Scripts/Tests/SplitDiagnosticQueries.Tests.ps1`

**Interfaces:**
- Consumes: `Split-DiagnosticQueryFile` from Task 2.
- Produces: a runnable script accepting `-SourceRoot` and `-OutputRoot` (both optional, defaulting to `SQL-Diag-Source-Files/` and `Scripts/QueryLibrary/` relative to the repo root), that calls `Split-DiagnosticQueryFile` once per `*.sql` file found directly under `SourceRoot`.

- [ ] **Step 1: Write the failing test**

Create `Scripts/Tests/SplitDiagnosticQueries.Tests.ps1`:

```powershell
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/SplitDiagnosticQueries.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Scripts/Split-DiagnosticQueries.ps1` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `Scripts/Split-DiagnosticQueries.ps1`:

```powershell
[CmdletBinding()]
param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot '../SQL-Diag-Source-Files'),
    [string]$OutputRoot = (Join-Path $PSScriptRoot 'QueryLibrary')
)

Import-Module (Join-Path $PSScriptRoot 'Modules/DiagnosticSplitter.psm1') -Force

$sourceFiles = Get-ChildItem -LiteralPath $SourceRoot -Filter '*.sql'
foreach ($file in $sourceFiles) {
    $result = Split-DiagnosticQueryFile -SourcePath $file.FullName -OutputRoot $OutputRoot
    Write-Host "Split '$($file.Name)' -> '$($result.VersionFolder)' ($($result.InstanceCount) instance, $($result.DatabaseCount) database queries)"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/SplitDiagnosticQueries.Tests.ps1 -Output Detailed"`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add Scripts/Split-DiagnosticQueries.ps1 Scripts/Tests/SplitDiagnosticQueries.Tests.ps1
git commit -m "feat: add CLI wrapper for splitting diagnostic query source files"
```

---

### Task 4: Split the real source files and commit the generated query library

**Files:**
- Create (generated): `Scripts/QueryLibrary/SQL Server 2022/**`
- Create (generated): `Scripts/QueryLibrary/SQL Server 2016 SP2/**`

**Interfaces:**
- Consumes: `Scripts/Split-DiagnosticQueries.ps1` from Task 3, against the real `SQL-Diag-Source-Files/`.

- [ ] **Step 1: Run the splitter against the real source files**

Run: `powershell -NoProfile -File Scripts/Split-DiagnosticQueries.ps1`
Expected output: two lines, one per source file, each reporting non-zero instance and database counts, e.g.:
```
Split 'SQL Server 2016 SP2 Diagnostic Information Queries.sql' -> 'SQL Server 2016 SP2' (N instance, M database queries)
Split 'SQL Server 2022 Diagnostic Information Queries.sql' -> 'SQL Server 2022' (N instance, M database queries)
```

- [ ] **Step 2: Verify query counts match the source files**

Run: `powershell -NoProfile -Command "(Select-String -Path 'SQL-Diag-Source-Files/SQL Server 2022 Diagnostic Information Queries.sql' -Pattern '\(Query \d+\)').Count"`
Compare against: `powershell -NoProfile -Command "(Get-ChildItem 'Scripts/QueryLibrary/SQL Server 2022/Instance','Scripts/QueryLibrary/SQL Server 2022/Database' -Filter '*.sql').Count"`
Expected: the two counts are equal. Repeat for the 2016 SP2 file/folder pair.

- [ ] **Step 3: Spot-check the Instance/Database boundary**

Run: `powershell -NoProfile -Command "Get-Content 'Scripts/QueryLibrary/SQL Server 2022/manifest.json' | ConvertFrom-Json | Where-Object { $_.Number -in 51,52 } | Format-Table Number,Scope,ShortName"`
Expected: query 51 shows `Scope: Instance`, query 52 shows `Scope: Database` (matching the boundary described in the design spec).

- [ ] **Step 4: Commit the generated query library**

```bash
git add Scripts/QueryLibrary
git commit -m "chore: generate split query library for SQL Server 2016 SP2 and 2022"
```

---

### Task 5: Driver module — SQL version to query-library folder mapping

**Files:**
- Create: `Scripts/Modules/DiagnosticDriver.psm1`
- Create: `Scripts/Tests/DiagnosticDriver.Tests.ps1`

**Interfaces:**
- Produces: `Get-VersionFolderName -ProductMajorVersion <int>` → the matching `Scripts/QueryLibrary` folder name, or `$null` if unmapped. Mapping: `13` → `SQL Server 2016 SP2`, `16` → `SQL Server 2022`.

- [ ] **Step 1: Write the failing test**

Create `Scripts/Tests/DiagnosticDriver.Tests.ps1`:

```powershell
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticDriver.Tests.ps1 -Output Detailed"`
Expected: FAIL — module does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `Scripts/Modules/DiagnosticDriver.psm1`:

```powershell
function Get-VersionFolderName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$ProductMajorVersion
    )

    $map = @{
        13 = 'SQL Server 2016 SP2'
        16 = 'SQL Server 2022'
    }

    if ($map.ContainsKey($ProductMajorVersion)) {
        return $map[$ProductMajorVersion]
    }
    return $null
}

Export-ModuleMember -Function Get-VersionFolderName
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticDriver.Tests.ps1 -Output Detailed"`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add Scripts/Modules/DiagnosticDriver.psm1 Scripts/Tests/DiagnosticDriver.Tests.ps1
git commit -m "feat: add SQL Server version to query-library folder mapping"
```

---

### Task 6: Driver module — manifest reading and query filtering

**Files:**
- Modify: `Scripts/Modules/DiagnosticDriver.psm1`
- Modify: `Scripts/Tests/DiagnosticDriver.Tests.ps1`

**Interfaces:**
- Produces:
  - `Read-DiagnosticManifest -ManifestPath <string>` → array of `{Number, ShortName, Scope, File}` parsed from the manifest JSON (same shape Task 2 writes).
  - `Get-FilteredManifestQueries -ManifestQueries <array> -Scope <'Instance'|'Database'> -ExcludedQueryNumbers <int[]>` → the subset of `ManifestQueries` matching `Scope`, excluding any `Number` in `ExcludedQueryNumbers`, sorted ascending by `Number`.

- [ ] **Step 1: Write the failing test**

Append to `Scripts/Tests/DiagnosticDriver.Tests.ps1`:

```powershell
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticDriver.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Read-DiagnosticManifest` / `Get-FilteredManifestQueries` not recognized.

- [ ] **Step 3: Write minimal implementation**

Add to `Scripts/Modules/DiagnosticDriver.psm1` (above `Export-ModuleMember`, and update that line):

```powershell
function Read-DiagnosticManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath
    )

    return ,@(Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json)
}

function Get-FilteredManifestQueries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$ManifestQueries,

        [Parameter(Mandatory)]
        [ValidateSet('Instance', 'Database')]
        [string]$Scope,

        [int[]]$ExcludedQueryNumbers = @()
    )

    return ,@(
        $ManifestQueries |
            Where-Object { $_.Scope -eq $Scope -and ($ExcludedQueryNumbers -notcontains $_.Number) } |
            Sort-Object Number
    )
}

Export-ModuleMember -Function Get-VersionFolderName, Read-DiagnosticManifest, Get-FilteredManifestQueries
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticDriver.Tests.ps1 -Output Detailed"`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add Scripts/Modules/DiagnosticDriver.psm1 Scripts/Tests/DiagnosticDriver.Tests.ps1
git commit -m "feat: add manifest reading and query filtering"
```

---

### Task 7: Driver module — CSV column prefixing for database-level results

**Files:**
- Modify: `Scripts/Modules/DiagnosticDriver.psm1`
- Modify: `Scripts/Tests/DiagnosticDriver.Tests.ps1`

**Interfaces:**
- Produces: `Add-ResultPrefixColumns -Rows <array> -PrefixColumns <System.Collections.Specialized.OrderedDictionary>` → new array of `pscustomobject`, each with `PrefixColumns`' keys/values as the first columns (in the given order) followed by every property of the corresponding input row, in that row's original order.

- [ ] **Step 1: Write the failing test**

Append to `Scripts/Tests/DiagnosticDriver.Tests.ps1`:

```powershell
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticDriver.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Add-ResultPrefixColumns` not recognized.

- [ ] **Step 3: Write minimal implementation**

Add to `Scripts/Modules/DiagnosticDriver.psm1` (above `Export-ModuleMember`, and update that line):

```powershell
function Add-ResultPrefixColumns {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Rows,

        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$PrefixColumns
    )

    $output = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($row in $Rows) {
        $ordered = [ordered]@{}
        foreach ($key in $PrefixColumns.Keys) {
            $ordered[$key] = $PrefixColumns[$key]
        }
        foreach ($prop in $row.PSObject.Properties) {
            $ordered[$prop.Name] = $prop.Value
        }
        $output.Add([pscustomobject]$ordered)
    }

    return ,$output.ToArray()
}

Export-ModuleMember -Function Get-VersionFolderName, Read-DiagnosticManifest, Get-FilteredManifestQueries, Add-ResultPrefixColumns
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticDriver.Tests.ps1 -Output Detailed"`
Expected: PASS (7 tests)

- [ ] **Step 5: Commit**

```bash
git add Scripts/Modules/DiagnosticDriver.psm1 Scripts/Tests/DiagnosticDriver.Tests.ps1
git commit -m "feat: add ServerName/DatabaseName column prefixing for database-level results"
```

---

### Task 8: Driver module — result CSV path builder

**Files:**
- Modify: `Scripts/Modules/DiagnosticDriver.psm1`
- Modify: `Scripts/Tests/DiagnosticDriver.Tests.ps1`

**Interfaces:**
- Produces: `Get-ResultCsvPath -RunFolder <string> -ServerName <string> [-DatabaseName <string>] -QueryNumber <int> -ShortName <string>` → full CSV path. When `-DatabaseName` is omitted/empty: `<RunFolder>/<ServerName>-Query-<QueryNumber>-<ShortName>.csv`. When provided: `<RunFolder>/<ServerName>-<DatabaseName>-Query-<QueryNumber>-<ShortName>.csv`. Filesystem-invalid characters in `ServerName`/`DatabaseName`/`ShortName` are replaced with `-`.

- [ ] **Step 1: Write the failing test**

Append to `Scripts/Tests/DiagnosticDriver.Tests.ps1`:

```powershell
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticDriver.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Get-ResultCsvPath` not recognized.

- [ ] **Step 3: Write minimal implementation**

Add to `Scripts/Modules/DiagnosticDriver.psm1` (above `Export-ModuleMember`, and update that line):

```powershell
function Get-ResultCsvPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RunFolder,

        [Parameter(Mandatory)]
        [string]$ServerName,

        [string]$DatabaseName = '',

        [Parameter(Mandatory)]
        [int]$QueryNumber,

        [Parameter(Mandatory)]
        [string]$ShortName
    )

    $invalidChars = [regex]::Escape(([System.IO.Path]::GetInvalidFileNameChars() -join ''))
    $pattern = "[$invalidChars]"

    $safeServer = $ServerName -replace $pattern, '-'
    $safeShort = $ShortName -replace $pattern, '-'

    if ([string]::IsNullOrEmpty($DatabaseName)) {
        $fileName = '{0}-Query-{1}-{2}.csv' -f $safeServer, $QueryNumber, $safeShort
    }
    else {
        $safeDb = $DatabaseName -replace $pattern, '-'
        $fileName = '{0}-{1}-Query-{2}-{3}.csv' -f $safeServer, $safeDb, $QueryNumber, $safeShort
    }

    return Join-Path $RunFolder $fileName
}

Export-ModuleMember -Function Get-VersionFolderName, Read-DiagnosticManifest, Get-FilteredManifestQueries, Add-ResultPrefixColumns, Get-ResultCsvPath
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticDriver.Tests.ps1 -Output Detailed"`
Expected: PASS (10 tests)

- [ ] **Step 5: Commit**

```bash
git add Scripts/Modules/DiagnosticDriver.psm1 Scripts/Tests/DiagnosticDriver.Tests.ps1
git commit -m "feat: add result CSV path builder"
```

---

### Task 9: Driver module — connection string builder

**Files:**
- Modify: `Scripts/Modules/DiagnosticDriver.psm1`
- Modify: `Scripts/Tests/DiagnosticDriver.Tests.ps1`

**Interfaces:**
- Produces: `Build-DiagnosticConnectionString -ServerName <string> [-Database <string>]` → connection string using Windows/Integrated auth with `Encrypt=Mandatory;TrustServerCertificate=True` (per Global Constraints). `Database` defaults to `master`.

- [ ] **Step 1: Write the failing test**

Append to `Scripts/Tests/DiagnosticDriver.Tests.ps1`:

```powershell
Describe 'Build-DiagnosticConnectionString' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../Modules/DiagnosticDriver.psm1" -Force
    }

    It 'defaults to the master database with Integrated Security and mandatory encryption' {
        $connString = Build-DiagnosticConnectionString -ServerName 'localhost'
        $connString | Should -Be 'Server=localhost;Database=master;Integrated Security=True;Encrypt=Mandatory;TrustServerCertificate=True;Connection Timeout=15'
    }

    It 'uses the given database name when provided' {
        $connString = Build-DiagnosticConnectionString -ServerName 'localhost' -Database 'LMS'
        $connString | Should -Be 'Server=localhost;Database=LMS;Integrated Security=True;Encrypt=Mandatory;TrustServerCertificate=True;Connection Timeout=15'
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticDriver.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Build-DiagnosticConnectionString` not recognized.

- [ ] **Step 3: Write minimal implementation**

Add to `Scripts/Modules/DiagnosticDriver.psm1` (above `Export-ModuleMember`, and update that line):

```powershell
function Build-DiagnosticConnectionString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServerName,

        [string]$Database = 'master'
    )

    return "Server=$ServerName;Database=$Database;Integrated Security=True;Encrypt=Mandatory;TrustServerCertificate=True;Connection Timeout=15"
}

Export-ModuleMember -Function Get-VersionFolderName, Read-DiagnosticManifest, Get-FilteredManifestQueries, Add-ResultPrefixColumns, Get-ResultCsvPath, Build-DiagnosticConnectionString
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticDriver.Tests.ps1 -Output Detailed"`
Expected: PASS (12 tests)

- [ ] **Step 5: Commit**

```bash
git add Scripts/Modules/DiagnosticDriver.psm1 Scripts/Tests/DiagnosticDriver.Tests.ps1
git commit -m "feat: add SQL Server connection string builder"
```

---

### Task 10: Driver module — online user database filtering

**Files:**
- Modify: `Scripts/Modules/DiagnosticDriver.psm1`
- Modify: `Scripts/Tests/DiagnosticDriver.Tests.ps1`

**Interfaces:**
- Produces: `Get-OnlineUserDatabaseNames -DatabaseRows <array> -ExcludedDatabases <string[]>` → sorted array of database names from `DatabaseRows` (each row has `name`, `database_id`, `state_desc`, matching a `sys.databases` query) where `database_id > 4` (excludes the four fixed system databases), `state_desc -eq 'ONLINE'`, and `name` is not in `ExcludedDatabases`.

- [ ] **Step 1: Write the failing test**

Append to `Scripts/Tests/DiagnosticDriver.Tests.ps1`:

```powershell
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticDriver.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Get-OnlineUserDatabaseNames` not recognized.

- [ ] **Step 3: Write minimal implementation**

Add to `Scripts/Modules/DiagnosticDriver.psm1` (above `Export-ModuleMember`, and update that line):

```powershell
function Get-OnlineUserDatabaseNames {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$DatabaseRows,

        [string[]]$ExcludedDatabases = @()
    )

    return ,@(
        $DatabaseRows |
            Where-Object { $_.database_id -gt 4 -and $_.state_desc -eq 'ONLINE' -and ($ExcludedDatabases -notcontains $_.name) } |
            Sort-Object name |
            ForEach-Object { $_.name }
    )
}

Export-ModuleMember -Function Get-VersionFolderName, Read-DiagnosticManifest, Get-FilteredManifestQueries, Add-ResultPrefixColumns, Get-ResultCsvPath, Build-DiagnosticConnectionString, Get-OnlineUserDatabaseNames
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticDriver.Tests.ps1 -Output Detailed"`
Expected: PASS (14 tests)

- [ ] **Step 5: Commit**

```bash
git add Scripts/Modules/DiagnosticDriver.psm1 Scripts/Tests/DiagnosticDriver.Tests.ps1
git commit -m "feat: add online user database filtering"
```

---

### Task 11: Driver module — SQL execution and run orchestration

**Files:**
- Modify: `Scripts/Modules/DiagnosticDriver.psm1`

**Interfaces:**
- Consumes: `Get-VersionFolderName`, `Read-DiagnosticManifest`, `Get-FilteredManifestQueries`, `Add-ResultPrefixColumns`, `Get-ResultCsvPath`, `Build-DiagnosticConnectionString`, `Get-OnlineUserDatabaseNames` from Tasks 5–10.
- Produces:
  - `Invoke-SqlFileQuery -Connection <System.Data.SqlClient.SqlConnection> -QueryFilePath <string>` → array of `pscustomobject`, one per result row, columns matching the query's result set (first result set only).
  - `Invoke-DiagnosticRun -ServersConfigPath <string> -ExclusionsConfigPath <string> -QueryLibraryRoot <string> -RunFolder <string>` → `[pscustomobject]@{ RunFolder:string; ErrorCount:int }`. Creates `RunFolder`, reads `servers.json` (array of `{ServerName}`) and `exclusions.json` (`{ExcludedDatabases:[], ExcludedQueryNumbers:[]}`), and for each server: resolves its version folder, runs all (non-excluded) `Instance` queries and exports each to CSV via `Get-ResultCsvPath`, then runs all (non-excluded) `Database` queries against every online non-excluded user database, prefixing rows with `Add-ResultPrefixColumns`. Any per-query or per-connection failure is caught and appended to an in-memory error list instead of stopping the run; if any errors occurred, they are written to `<RunFolder>/errors.csv` with columns `ServerName, DatabaseName, QueryNumber, ShortName, ErrorMessage, Timestamp`.

This task has no live database to test against in this environment, so it is not covered by a Pester test here — it's exercised end-to-end in Task 14 against your local SQL Server 2022 instance. Keep the code below exactly as specified since every function name and parameter it calls must match Tasks 5–10.

- [ ] **Step 1: Implement `Invoke-SqlFileQuery` and `Invoke-DiagnosticRun`**

Add to `Scripts/Modules/DiagnosticDriver.psm1` (above `Export-ModuleMember`, and update that line):

```powershell
function Invoke-SqlFileQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$QueryFilePath
    )

    $commandText = Get-Content -LiteralPath $QueryFilePath -Raw
    $command = $Connection.CreateCommand()
    $command.CommandText = $commandText
    $command.CommandTimeout = 120

    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
    $table = New-Object System.Data.DataTable
    [void]$adapter.Fill($table)

    $rows = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($row in $table.Rows) {
        $ordered = [ordered]@{}
        foreach ($col in $table.Columns) {
            $ordered[$col.ColumnName] = $row[$col]
        }
        $rows.Add([pscustomobject]$ordered)
    }

    return ,$rows.ToArray()
}

function Invoke-DiagnosticRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServersConfigPath,

        [Parameter(Mandatory)]
        [string]$ExclusionsConfigPath,

        [Parameter(Mandatory)]
        [string]$QueryLibraryRoot,

        [Parameter(Mandatory)]
        [string]$RunFolder
    )

    New-Item -ItemType Directory -Path $RunFolder -Force | Out-Null

    $servers = @(Get-Content -LiteralPath $ServersConfigPath -Raw | ConvertFrom-Json)
    $exclusions = Get-Content -LiteralPath $ExclusionsConfigPath -Raw | ConvertFrom-Json
    $excludedDatabases = @($exclusions.ExcludedDatabases)
    $excludedQueryNumbers = @($exclusions.ExcludedQueryNumbers)

    $errors = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($server in $servers) {
        $serverName = $server.ServerName
        Write-Host "=== $serverName ==="

        $majorVersion = $null
        try {
            $conn = New-Object System.Data.SqlClient.SqlConnection (Build-DiagnosticConnectionString -ServerName $serverName)
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT CONVERT(int, SERVERPROPERTY('ProductMajorVersion'))"
            $majorVersion = [int]$cmd.ExecuteScalar()
            $conn.Close()
        }
        catch {
            $errors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = ''; QueryNumber = ''; ShortName = ''; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
            continue
        }

        $versionFolder = Get-VersionFolderName -ProductMajorVersion $majorVersion
        if (-not $versionFolder) {
            $errors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = ''; QueryNumber = ''; ShortName = ''; ErrorMessage = "No query library for ProductMajorVersion $majorVersion"; Timestamp = (Get-Date -Format o) })
            continue
        }

        $versionRoot = Join-Path $QueryLibraryRoot $versionFolder
        $manifest = Read-DiagnosticManifest -ManifestPath (Join-Path $versionRoot 'manifest.json')

        $instanceQueries = Get-FilteredManifestQueries -ManifestQueries $manifest -Scope 'Instance' -ExcludedQueryNumbers $excludedQueryNumbers
        $databaseQueries = Get-FilteredManifestQueries -ManifestQueries $manifest -Scope 'Database' -ExcludedQueryNumbers $excludedQueryNumbers

        $conn = New-Object System.Data.SqlClient.SqlConnection (Build-DiagnosticConnectionString -ServerName $serverName)
        $conn.Open()

        foreach ($q in $instanceQueries) {
            try {
                $rows = Invoke-SqlFileQuery -Connection $conn -QueryFilePath (Join-Path $versionRoot $q.File)
                $csvPath = Get-ResultCsvPath -RunFolder $RunFolder -ServerName $serverName -QueryNumber $q.Number -ShortName $q.ShortName
                $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
            }
            catch {
                $errors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = ''; QueryNumber = $q.Number; ShortName = $q.ShortName; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
            }
        }

        $dbCmd = $conn.CreateCommand()
        $dbCmd.CommandText = 'SELECT name, database_id, state_desc FROM sys.databases'
        $dbAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $dbCmd
        $dbTable = New-Object System.Data.DataTable
        [void]$dbAdapter.Fill($dbTable)
        $conn.Close()

        $databaseRows = foreach ($row in $dbTable.Rows) {
            [pscustomobject]@{ name = $row['name']; database_id = $row['database_id']; state_desc = $row['state_desc'] }
        }
        $databaseNames = Get-OnlineUserDatabaseNames -DatabaseRows @($databaseRows) -ExcludedDatabases $excludedDatabases

        foreach ($dbName in $databaseNames) {
            $dbConn = New-Object System.Data.SqlClient.SqlConnection (Build-DiagnosticConnectionString -ServerName $serverName -Database $dbName)
            try {
                $dbConn.Open()
            }
            catch {
                $errors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = $dbName; QueryNumber = ''; ShortName = ''; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
                continue
            }

            foreach ($q in $databaseQueries) {
                try {
                    $rows = Invoke-SqlFileQuery -Connection $dbConn -QueryFilePath (Join-Path $versionRoot $q.File)
                    $prefixed = Add-ResultPrefixColumns -Rows $rows -PrefixColumns ([ordered]@{ ServerName = $serverName; DatabaseName = $dbName })
                    $csvPath = Get-ResultCsvPath -RunFolder $RunFolder -ServerName $serverName -DatabaseName $dbName -QueryNumber $q.Number -ShortName $q.ShortName
                    $prefixed | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
                }
                catch {
                    $errors.Add([pscustomobject]@{ ServerName = $serverName; DatabaseName = $dbName; QueryNumber = $q.Number; ShortName = $q.ShortName; ErrorMessage = $_.Exception.Message; Timestamp = (Get-Date -Format o) })
                }
            }

            $dbConn.Close()
        }
    }

    if ($errors.Count -gt 0) {
        $errors | Export-Csv -LiteralPath (Join-Path $RunFolder 'errors.csv') -NoTypeInformation -Encoding UTF8
    }

    return [pscustomobject]@{ RunFolder = $RunFolder; ErrorCount = $errors.Count }
}

Export-ModuleMember -Function Get-VersionFolderName, Read-DiagnosticManifest, Get-FilteredManifestQueries, Add-ResultPrefixColumns, Get-ResultCsvPath, Build-DiagnosticConnectionString, Get-OnlineUserDatabaseNames, Invoke-SqlFileQuery, Invoke-DiagnosticRun
```

- [ ] **Step 2: Sanity-check the module imports cleanly and exports every function**

Run: `powershell -NoProfile -Command "Import-Module Scripts/Modules/DiagnosticDriver.psm1 -Force; (Get-Command -Module DiagnosticDriver).Name | Sort-Object"`
Expected: lists all 9 function names with no import errors: `Add-ResultPrefixColumns, Build-DiagnosticConnectionString, Get-FilteredManifestQueries, Get-OnlineUserDatabaseNames, Get-ResultCsvPath, Get-VersionFolderName, Invoke-DiagnosticRun, Invoke-SqlFileQuery, Read-DiagnosticManifest`

- [ ] **Step 3: Re-run the full driver test suite to confirm nothing broke**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests/DiagnosticDriver.Tests.ps1 -Output Detailed"`
Expected: PASS (14 tests — unchanged from Task 10, since this task added no new unit tests)

- [ ] **Step 4: Commit**

```bash
git add Scripts/Modules/DiagnosticDriver.psm1
git commit -m "feat: add SQL execution and diagnostic run orchestration"
```

---

### Task 12: Config files and .gitignore

**Files:**
- Create: `Scripts/config/servers.json`
- Create: `Scripts/config/exclusions.json`
- Modify: `.gitignore` (create if it doesn't exist)

**Interfaces:**
- Consumes: shapes expected by `Invoke-DiagnosticRun` (Task 11): `servers.json` is an array of `{ServerName}`; `exclusions.json` is `{ExcludedDatabases:[], ExcludedQueryNumbers:[]}`.

- [ ] **Step 1: Create the server list config**

Create `Scripts/config/servers.json`:

```json
[
  {
    "ServerName": "localhost"
  }
]
```

- [ ] **Step 2: Create the exclusions config**

Create `Scripts/config/exclusions.json`:

```json
{
  "ExcludedDatabases": [],
  "ExcludedQueryNumbers": []
}
```

- [ ] **Step 3: Exclude run output from git**

Create or update `.gitignore` at the repo root to include:

```
Results/
```

- [ ] **Step 4: Verify**

Run: `powershell -NoProfile -Command "Get-Content Scripts/config/servers.json | ConvertFrom-Json | Format-Table; Get-Content Scripts/config/exclusions.json | ConvertFrom-Json | Format-List"`
Expected: prints the `localhost` server row and the empty exclusion lists with no parse errors.

- [ ] **Step 5: Commit**

```bash
git add Scripts/config/servers.json Scripts/config/exclusions.json .gitignore
git commit -m "chore: add default server/exclusions config and gitignore Results/"
```

---

### Task 13: Driver CLI wrapper

**Files:**
- Create: `Scripts/Invoke-DiagnosticRun.ps1`

**Interfaces:**
- Consumes: `Invoke-DiagnosticRun` from Task 11; `Scripts/config/servers.json` and `Scripts/config/exclusions.json` from Task 12.
- Produces: a runnable script accepting `-ServersConfigPath`, `-ExclusionsConfigPath`, `-QueryLibraryRoot`, `-ResultsRoot` (all optional, defaulting to the paths under `Scripts/`), that creates a timestamped subfolder under `ResultsRoot` and calls `Invoke-DiagnosticRun` against it.

- [ ] **Step 1: Write the CLI wrapper**

Create `Scripts/Invoke-DiagnosticRun.ps1`:

```powershell
[CmdletBinding()]
param(
    [string]$ServersConfigPath = (Join-Path $PSScriptRoot 'config/servers.json'),
    [string]$ExclusionsConfigPath = (Join-Path $PSScriptRoot 'config/exclusions.json'),
    [string]$QueryLibraryRoot = (Join-Path $PSScriptRoot 'QueryLibrary'),
    [string]$ResultsRoot = (Join-Path $PSScriptRoot '../Results')
)

Import-Module (Join-Path $PSScriptRoot 'Modules/DiagnosticDriver.psm1') -Force

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runFolder = Join-Path $ResultsRoot $timestamp

$result = Invoke-DiagnosticRun -ServersConfigPath $ServersConfigPath -ExclusionsConfigPath $ExclusionsConfigPath -QueryLibraryRoot $QueryLibraryRoot -RunFolder $runFolder

Write-Host "Run complete: $($result.RunFolder) ($($result.ErrorCount) errors)"
```

- [ ] **Step 2: Verify the script parses and parameters resolve correctly**

Run: `powershell -NoProfile -Command "$scriptInfo = Get-Command Scripts/Invoke-DiagnosticRun.ps1; $scriptInfo.Parameters.Keys -join ', '"`
Expected: lists `ServersConfigPath, ExclusionsConfigPath, QueryLibraryRoot, ResultsRoot` (plus common parameters) with no parse errors.

- [ ] **Step 3: Commit**

```bash
git add Scripts/Invoke-DiagnosticRun.ps1
git commit -m "feat: add CLI wrapper for running diagnostic queries against configured servers"
```

---

### Task 14: End-to-end verification against localhost

**Files:** none (verification only)

**Interfaces:**
- Consumes: everything from Tasks 1–13, run against a real SQL Server 2022 instance on `localhost` with Windows Authentication, `Encrypt=Mandatory`, `TrustServerCertificate=True` (per the spec's Testing section).

- [ ] **Step 1: Run a full diagnostic pass against localhost**

Run: `powershell -NoProfile -File Scripts/Invoke-DiagnosticRun.ps1`
Expected: prints `=== localhost ===` followed by `Run complete: .../Results/<timestamp> (N errors)`.

- [ ] **Step 2: Verify instance-level output**

Run: `powershell -NoProfile -Command "Get-ChildItem (Get-ChildItem Results | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName -Filter 'localhost-Query-*.csv' | Measure-Object"`
Expected: `Count` matches the number of `Instance` entries in `Scripts/QueryLibrary/SQL Server 2022/manifest.json`.

- [ ] **Step 3: Verify database-level output has ServerName/DatabaseName prefix columns**

Run: `powershell -NoProfile -Command "$runDir = (Get-ChildItem Results | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName; $dbCsv = Get-ChildItem $runDir -Filter 'localhost-*-Query-52-*.csv' | Select-Object -First 1; (Import-Csv $dbCsv.FullName | Select-Object -First 1).PSObject.Properties.Name[0,1]"`
Expected: `ServerName`, `DatabaseName` (in that order) as the first two columns.

- [ ] **Step 4: Review errors.csv if present**

Run: `powershell -NoProfile -Command "$runDir = (Get-ChildItem Results | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName; if (Test-Path (Join-Path $runDir 'errors.csv')) { Import-Csv (Join-Path $runDir 'errors.csv') | Format-Table } else { 'no errors.csv - run had zero errors' }"`
Expected: either no `errors.csv` (clean run), or a small number of rows for queries that don't apply to your local instance's configuration (e.g. AlwaysOn AG queries on a non-clustered instance) — confirm any listed errors are expected/benign, not a bug in the driver itself.

- [ ] **Step 5: Confirm the full unit test suite still passes**

Run: `powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0 -Force; Invoke-Pester -Path Scripts/Tests -Output Detailed"`
Expected: PASS (all tests across both test files, no failures)

No commit for this task — it's verification of already-committed code. If Step 4 surfaces a real bug, fix it as a new small task (write a failing test first per the TDD steps above) before considering the feature done.
