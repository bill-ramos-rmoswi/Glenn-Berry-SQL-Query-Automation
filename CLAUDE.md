# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

This repository automates the execution and analysis of Glenn Berry's SQL Server Diagnostic Information Queries (see https://glennsqlperformance.com/resources/). Automation is implemented in PowerShell: source `.sql` files are split into a per-query library, then run against configured servers with results exported to CSV. See the README for setup and usage instructions.

## Repository Structure

- `SQL-Diag-Source-Files/` — Unmodified, version-specific `.sql` source files from Glenn Berry, one per SQL Server version (e.g. `SQL Server 2016 SP2 Diagnostic Information Queries.sql`, `SQL Server 2022 Diagnostic Information Queries.sql`). Treat these as vendored/third-party reference material — do not edit them; if a newer version is released upstream, add it as a new file rather than modifying an existing one.
- `Scripts/QueryLibrary/` — Generated (checked-in) per-query `.sql` files and `manifest.json` per SQL Server version, produced by `Scripts/Split-DiagnosticQueries.ps1`. Regenerate rather than hand-edit if a source file changes.
- `Scripts/Modules/DiagnosticSplitter.psm1` — Parses a source file into the query library (instance vs. database scope, per-query files, manifest).
- `Scripts/Modules/DiagnosticDriver.psm1` — Tests connectivity to each configured server first (retrying with `Encrypt=False` if `Encrypt=True` fails), runs the query library against reachable servers, exports CSVs to a per-server results folder, logs per-query and per-server errors without aborting the run.
- `Scripts/Split-DiagnosticQueries.ps1` / `Scripts/Invoke-DiagnosticRun.ps1` — CLI entry points.
- `Scripts/config/` — `servers.json` (run targets) and `exclusions.json` (databases/query numbers to skip).
- `Scripts/Tests/` — Pester 5 test suite.

## PowerShell Implementation Lessons Learned

Non-obvious gotchas discovered while building this automation — worth knowing before touching `Scripts/Modules/`:

- **Array-returning functions must not use a leading-comma `return`.** This codebase's convention is for every caller to wrap function calls in `@(FunctionName ...)`. A function that itself does `return ,@(pipeline)` (or `return ,$list.ToArray()`) double-wraps the result, which silently collapses multi-element arrays down to `Count = 1` at the call site. The correct pattern here is `$result = @(...); return $result` (no leading comma) — verified against `DiagnosticSplitter.psm1` and `DiagnosticDriver.psm1`. If you see a leading-comma return anywhere (including in a plan/spec's reference code), treat it as broken until proven otherwise with a 2+-element test case invoked through `@(...)`.
- **Zero-row query results must be wrapped in `@(...)` before being passed onward.** A bare `return` of an empty array unwraps to zero pipeline elements, so an unwrapped caller assignment (`$rows = Invoke-SqlFileQuery ...`) becomes `$null` instead of an empty array — which then fails binding against `[AllowEmptyCollection()][array]` parameters. Always wrap: `$rows = @(Invoke-SqlFileQuery ...)`.
- **Raw `System.Data.SqlClient` cannot run these multi-batch `.sql` files.** The source scripts contain `GO` batch separators, which raw `SqlConnection`/`SqlCommand`/`SqlDataAdapter` execution rejects ("Incorrect syntax near 'GO'"). Use `Invoke-Sqlcmd -ConnectionString ... -InputFile ...` (from the `SqlServer` PowerShell module) instead — it handles `GO` batching natively.
- **Connection string encryption value:** use `Encrypt=True;TrustServerCertificate=True`, not `Encrypt=Mandatory` — the latter is not a recognized value for the .NET connection string parser used here.
- **Don't hardcode per-version instance/database query-number boundaries from a plan or spec without verifying against the actual source file.** An early design draft assumed SQL Server 2022's split fell at query 51/52; the real boundary (confirmed by running the splitter against the actual source file) is 55/56.
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
