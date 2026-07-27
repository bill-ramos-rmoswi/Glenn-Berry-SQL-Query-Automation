# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

This repository automates the execution and analysis of Glenn Berry's SQL Server Diagnostic Information Queries (see https://glennsqlperformance.com/resources/). Automation is implemented in PowerShell: source `.sql` files are split into a per-query library, then run against configured servers with results exported to CSV. A second stage stages those CSVs into a SQL Server database, runs best-practices rules against them with drift tracking across repeated runs, and generates a static HTML report. See the README for setup and usage instructions.

## Repository Structure

Two pipelines live in this repo: **collection** (run Glenn Berry's queries against real servers, export CSV)
and **analysis** (stage those CSVs into SQL Server, run best-practices rules, generate an HTML report). See
the README for full usage of both; this section is the file-level map.

Collection:
- `SQL-Diag-Source-Files/` — Unmodified, version-specific `.sql` source files from Glenn Berry, one per SQL Server version (e.g. `SQL Server 2016 SP2 Diagnostic Information Queries.sql`, `SQL Server 2022 Diagnostic Information Queries.sql`). Treat these as vendored/third-party reference material — do not edit them; if a newer version is released upstream, add it as a new file rather than modifying an existing one.
- `Scripts/QueryLibrary/` — Generated (checked-in) per-query `.sql` files and `manifest.json` per SQL Server version, produced by `Scripts/Split-DiagnosticQueries.ps1`. Regenerate rather than hand-edit if a source file changes.
- `Scripts/CustomQueries/{Instance,Database}/` — Hand-authored queries not from Glenn Berry's source (e.g. `Query100-Server Role Members.sql`, sysadmin membership). Numbered from 100 (instance) / 200 (database) to stay clear of vendor numbers; `Split-DiagnosticQueries.ps1` merges these into every version's `manifest.json` after each vendor split, so they survive re-splitting. Add new ones here, never directly under `QueryLibrary/`.
- `Scripts/Modules/DiagnosticSplitter.psm1` — Parses a source file into the query library (instance vs. database scope, per-query files, manifest) and merges `CustomQueries/` in.
- `Scripts/Modules/DiagnosticDriver.psm1` — Tests connectivity to each configured server first (retrying with `Encrypt=False` if `Encrypt=True` fails), runs the query library against reachable servers, exports CSVs to a per-server results folder, logs per-query and per-server errors without aborting the run.
- `Scripts/Split-DiagnosticQueries.ps1` / `Scripts/Invoke-DiagnosticRun.ps1` — CLI entry points.
- `Scripts/config/servers.json` / `exclusions.json` — run targets / databases & query numbers to skip.

Analysis (all against a SQL Server 2025+ dev-instance staging database named `GlennBerrySQLDiag`; see
"Staging Database, Resumability, and Error Recovery" below):
- `Scripts/Modules/DiagnosticStaging.psm1` — retrieves the staging-DB credential via `git credential fill` and imports a `Results\<timestamp>\` folder's CSVs into `stg.*` tables.
- `Scripts/Modules/DiagnosticFindings.psm1` — runs every `Scripts/Analysis/*.sql` rule and reconciles candidate rows into `dbo.Findings` (new / still-open / resolved) for drift tracking across runs.
- `Scripts/Modules/DiagnosticReport.psm1` — pure HTML-string-building functions for the generated report pages.
- `Scripts/Analysis/*.sql` — one best-practices rule per file; each is self-contained, guarded by `IF OBJECT_ID(...) IS NOT NULL` so a missing staged table degrades to zero findings rather than erroring.
- `Scripts/Database/Schema/*.sql` — `GlennBerrySQLDiag` schema (`dbo.Runs`, `dbo.Findings`, `dbo.ImportLog`), applied once per new script via `Invoke-Sqlcmd -InputFile`.
- `Scripts/Import-DiagnosticResults.ps1` / `Scripts/New-DiagnosticReport.ps1` — CLI entry points.
- `Scripts/config/analysis-thresholds.json` — finding severity thresholds, passed to `Scripts/Analysis/*.sql` as sqlcmd `-Variable`s.

Shared:
- `Scripts/Tests/` — Pester 5 test suite.

## Staging Database, Resumability, and Error Recovery

Essentials for touching `Scripts/Modules/DiagnosticStaging.psm1` or `Import-DiagnosticResultsFolder` — full
user-facing workflow is in the README's "Refreshing the data" / "Recovering from a failed or interrupted
import" sections.

- **One persistent `SqlConnection` for the whole import, not one per file.** An earlier version called
  `Write-SqlTableData` per CSV (5,600+ files in a real run), which both hammered the server with fresh
  SQL-auth/TLS handshakes (intermittent "Failed to connect" under load) and locked each staging table's shape
  to whichever file happened to create it first. The fix — one connection, `Confirm-DiagnosticStagingTable`
  (`CREATE`/`ALTER TABLE ADD` to evolve each table to the union of every column ever seen for that query
  short name) + `SqlBulkCopy` with explicit name-based `ColumnMappings` — is now the only way data lands in
  `stg.*`; don't reintroduce a per-file connection or `Write-SqlTableData` here.
- **Resumability is automatic, not a flag.** `Get-OrCreateDiagnosticRun` looks up `dbo.Runs` by
  `RunFolderName` before inserting, so re-running `Import-DiagnosticResults.ps1` against the same
  `Results\<timestamp>\` folder always reuses the same `RunId`. `dbo.ImportLog` (keyed on
  `(RunId, RelativeFilePath)`) then lets the import skip every file already logged `Status='Success'` and
  only (re)attempt what's missing or previously `Failed` — verified for real: interrupting a full import
  partway through and re-running the identical command picked up exactly the remaining files with zero
  duplicated rows. If you change what gets written to a table for an already-imported file, you must also
  change (or clear) its `ImportLog` row, or a future "resume" will silently keep skipping it.
- **`ServerName` is deliberately normalized to the Results-folder name for every staged table, including ones
  whose own query already returns a `ServerName` column (e.g. `Server_Properties`'s `SERVERPROPERTY('ServerName')`).**
  A server's actual reported name can differ from the alias/hostname used in `servers.json` / the results
  folder (verified: one SFFCU box reports `DC1-BI-Vault-Prod` but was configured and collected as
  `dc1-bi-vault-pr` — a real, silent mismatch, not a hypothetical). Every cross-table join in
  `New-DiagnosticReport.ps1` assumes one canonical `ServerName` per server across all of `stg.*`; if a new
  query's own self-reported name column ever gets left un-overridden, that table becomes the one that doesn't
  join and produces `?`/blank values in the report for that server.
- **A rule script that also needs to drive a live report value (not just a drift-tracked `dbo.Findings` row)
  should return that value as an extra column and get invoked directly from `New-DiagnosticReport.ps1`, not
  have its logic re-derived a second time.** `Scripts/Analysis/DormantDatabase.sql` returns `IndexCount`
  alongside the standard Finding columns for exactly this reason — `Update-DiagnosticFindings` ignores the
  extra column, `New-DiagnosticReport.ps1` reads it directly to populate the server page's "Idle Indexes"
  column. Keeps the "is this database fully idle" logic in one file instead of two that can drift apart.

## PowerShell Implementation Lessons Learned

Non-obvious gotchas discovered while building this automation — worth knowing before touching `Scripts/Modules/`:

- **Array-returning functions must not use a leading-comma `return`.** This codebase's convention is for every caller to wrap function calls in `@(FunctionName ...)`. A function that itself does `return ,@(pipeline)` (or `return ,$list.ToArray()`) double-wraps the result, which silently collapses multi-element arrays down to `Count = 1` at the call site. The correct pattern here is `$result = @(...); return $result` (no leading comma) — verified against `DiagnosticSplitter.psm1` and `DiagnosticDriver.psm1`. If you see a leading-comma return anywhere (including in a plan/spec's reference code), treat it as broken until proven otherwise with a 2+-element test case invoked through `@(...)`.
- **Zero-row query results must be wrapped in `@(...)` before being passed onward.** A bare `return` of an empty array unwraps to zero pipeline elements, so an unwrapped caller assignment (`$rows = Invoke-SqlFileQuery ...`) becomes `$null` instead of an empty array — which then fails binding against `[AllowEmptyCollection()][array]` parameters. Always wrap: `$rows = @(Invoke-SqlFileQuery ...)`.
- **Raw `System.Data.SqlClient` cannot run these multi-batch `.sql` files.** The source scripts contain `GO` batch separators, which raw `SqlConnection`/`SqlCommand`/`SqlDataAdapter` execution rejects ("Incorrect syntax near 'GO'"). Use `Invoke-Sqlcmd -ConnectionString ... -InputFile ...` (from the `SqlServer` PowerShell module) instead — it handles `GO` batching natively.
- **Connection string encryption value:** use `Encrypt=True;TrustServerCertificate=True`, not `Encrypt=Mandatory` — the latter is not a recognized value for the .NET connection string parser used here.
- **Don't hardcode per-version instance/database query-number boundaries from a plan or spec without verifying against the actual source file.** An early design draft assumed SQL Server 2022's split fell at query 51/52; the real boundary (confirmed by running the splitter against the actual source file) is 55/56.
- **`ConvertFrom-Json` also has a pipeline double-wrap trap, not just `return`.** `@(Get-Content -Raw $path | ConvertFrom-Json)` — wrapping `@()` directly around the pipeline — nests a multi-element JSON array inside a 1-element outer array, because `ConvertFrom-Json` emits its whole result as a single `Object[]` onto the pipeline for a `-Raw` (single-string) input. The fix is the same shape as the `return` rule: assign first (`$parsed = Get-Content -Raw $path | ConvertFrom-Json`), then `@($parsed)` the *variable* — `@()` on an already-materialized array just passes it through instead of re-wrapping. Verified breaking `Add-CustomDiagnosticQueries`'s manifest merge (and its own test's readback) until fixed this way; `Read-DiagnosticManifest` in `DiagnosticDriver.psm1` already used the safe form.
- **A `System.Data.DataTable` gets enumerated to its *rows* when written to the PowerShell pipeline, including via a bare `return $table`.** A 0-row table returns `$null` to the caller, a 1-row table returns a single `DataRow` (not the table), and an N-row table returns an `Object[]` of N `DataRow`s — never the `DataTable` itself, even though `$table -is [System.Collections.IEnumerable]` reports `$false` (this is PowerShell's `LanguagePrimitives` enumerator specifically special-casing `DataTable`, not a normal `IEnumerable` duck-type). The fix is `Write-Output -NoEnumerate $table` in place of `return $table` — verified breaking `ConvertTo-DiagnosticDataTable` in `DiagnosticStaging.psm1` until fixed this way, and its own test's `$table.Columns.Count` assertion silently passed against the *wrong* object (an array of `$null`s) until inspected closely. Unlike the array-function `return` convention elsewhere in this file, do **not** "fix" this with a leading comma (`return ,$table`) without also updating every caller — `,$table` also works, but callers here expect a single `DataTable` object back, not something they wrap in `@()`.
- **`[System.DBNull]::Value` is truthy in a plain `if ($value)` check.** A row property that's SQL `NULL`, read back via `Invoke-Sqlcmd`, comes through as `[DBNull]::Value`, not PowerShell `$null` — and `if ($f.DatabaseName)` treats that as true (it's neither `$null`, an empty string, nor zero), so code written to branch on "does this instance-scope finding have a database" took the database-scoped branch for every row and then failed parameter binding downstream once DBNull got coerced to `""`. Guard explicitly with `-not [string]::IsNullOrEmpty($value)` (which correctly treats DBNull as empty via coercion) rather than bare truthiness — verified breaking `New-DiagnosticReport.ps1` and `DiagnosticReport.psm1`'s `New-DiagnosticAttentionPage` until fixed this way. `ConvertTo-DiagnosticHtmlEncoded` in the same module already guarded correctly (`$Text -is [System.DBNull]`) — match that pattern for any new code touching nullable SQL columns.
- **Feeding a native executable's stdin from PowerShell needs OS-level redirection, not a pipe or a redirected `Process` stream.** `$lines | git credential fill` and manually writing to `[Diagnostics.Process]::Start(...).StandardInput` (even with an explicit no-BOM `UTF8Encoding` `StreamWriter`) both silently prepend a UTF-8 BOM that corrupts the first line, breaking git's `key=value` line parser (`fatal: refusing to work with credential missing protocol field`) — this reproduces in Windows PowerShell 5.1 regardless of encoding coaxing. PowerShell has no `<` input-redirection operator at all, so the reliable fix is: write the request to a BOM-less UTF-8 temp file, then shell out through `cmd /c "prog < ""$tmpFile"""` for true OS-level redirection. Bash's `git credential fill < file` was unaffected — this is specifically a PowerShell/.NET-stream issue. Relevant to `Get-DiagnosticStagingCredential` in `DiagnosticStaging.psm1`, which retrieves the `GlennBerrySQLDiag` staging-DB login this way.
- **A hardcoded `ProductMajorVersion` → query-library-folder map is fine, but must be paired with a filesystem check.** The folder names (`SQL Server 2019`, etc.) don't literally encode the version number, so the number→name mapping still has to live somewhere as a fixed table — verified once against each source file's version-check guard (`SQL-Diag-Source-Files/*.sql`, ~line 44): `13`→2016 SP2, `14`→2017, `15`→2019, `16`→2022, `17`→2025. But `Get-VersionFolderName` must also `Test-Path` the resolved folder under `QueryLibraryRoot` before returning it, rather than trusting the table blindly — otherwise a version whose library was never split (or was deleted) silently gets treated as supported.
- **PowerShell's approved-verb list is stricter than it looks — verify before naming a function.** `Build-` is not an approved verb (`New-` is the standard one for "construct and return a value"); using it doesn't error, but it makes `Import-Module` print an "unapproved verbs" warning on every load, which reads as unpolished in a public repo. Check with `Get-Verb | Where-Object Verb -eq '<Verb>'` before picking a verb for a new function, not after.
- **Pester's `Mock -CommandName` can't stand in for a command that isn't resolvable at all.** Mocking `Invoke-Sqlcmd` (from the `SqlServer` module) throws `CommandNotFoundException` unless the real `SqlServer` module is actually installed in the test environment — the mock replaces the implementation, but PowerShell still needs to resolve the command name first. Likewise, this repo's Pester 5 test suite needs Pester 5 explicitly installed (`Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser`); Windows PowerShell 5.1 ships an ancient Pester 3.4.0 by default that doesn't support this suite's syntax (`BeforeAll`, `Should -Invoke`, etc.).

## Structure of the Diagnostic Query Files

Each source file follows a consistent convention worth knowing before writing automation against it:

- A version-check guard near the top compares `SERVERPROPERTY('ProductMajorVersion')` against the expected value for that file and raises an error if the script is run against the wrong SQL Server version.
- Individual diagnostic queries are delimited by a trailing comment on the query's own header line in the form `-- <description> (Query N) (<Short Name>)`, e.g. `-- Get selected server properties (Query 3) (Server Properties)`. Some queries also have an explicit `-- End of Query N ...` marker.
- Queries are grouped into two major sections, marked by comment banners:
  - `-- Instance level queries *******************************` — server/instance-scoped diagnostics.
  - `-- Database specific queries *****************************************************************` — requires switching to a user database (`USE <database>`) before running; queries after this marker are scoped per-database rather than per-instance.
- Any automation that parses or drives these files (e.g. splitting into individually executable queries, mapping results to names) should key off the `(Query N) (<Short Name>)` comment convention and the instance-vs-database section boundary, since both are consistent across the version-specific files.

## Prior Art

The README notes that [dbatools](https://dbatools.io/)'s `Invoke-DbaDiagnosticQuery` cmdlet is an existing community solution for running these queries in an automated fashion — useful reference when designing this repo's own automation approach.
