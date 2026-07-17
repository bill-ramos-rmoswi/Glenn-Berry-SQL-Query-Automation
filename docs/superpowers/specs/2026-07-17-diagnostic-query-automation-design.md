# Diagnostic Query Automation — Design

Date: 2026-07-17

## Purpose

Automate running Glenn Berry's SQL Server Diagnostic Information Queries against a list of SQL Server instances, splitting each version's monolithic `.sql` source file into individually executable per-query files, and exporting results to CSV.

## Scope

- Split master diagnostic query files (`SQL-Diag-Source-Files/*.sql`) into per-query `.sql` files, organized by SQL Server version and by instance-vs-database scope.
- Run those per-query files against a configured list of SQL Server instances (Windows/Integrated auth only, v1).
- For each instance: run instance-level queries once, then run database-level queries against every "online" user database (minus a configured exclusion list).
- Support a global exclusion list of query numbers to skip.
- Write one CSV per query per server (and per database, for database-level queries) into a timestamped run folder, with `ServerName`/`DatabaseName` prefix columns on database-level query output.
- Log query failures without aborting the run.

Out of scope for v1: SQL authentication/credential prompting, parallel execution across servers, multi-result-set queries (first result set only), any GUI.

## Components

### 1. Splitter — `Scripts/Split-DiagnosticQueries.ps1`

**Input:** path to one master `.sql` file under `SQL-Diag-Source-Files/`.

**Parsing rules:**
- A query begins at a line matching `-- <description> (Query N) (<Short Name>)` and ends at the line before the next such header, the next section banner, or end of file.
- `-- Instance level queries *******************************` marks the start of instance-scoped queries.
- `-- Database specific queries *****************************************************************` marks the start of database-scoped queries. The commented-out `-- **** Please switch to a user database ... USE YourDatabaseName; --GO` block that follows this banner is a section separator, not a query, and is not emitted as its own file.
- The Copyright block (`--***...Copyright (C) <year> Glenn Berry...***`) is copied verbatim from the top of the source file and prepended to every generated per-query file.
- The top-of-file `ProductMajorVersion` version-check guard is **not** duplicated into per-query files (the driver already knows the version from the folder it's reading).

**Output layout**, derived from the source filename (e.g. `SQL Server 2022 Diagnostic Information Queries.sql` → version folder `SQL Server 2022`):

```
Scripts/QueryLibrary/<Version>/
  manifest.json
  Instance/
    Query01-Version Info.sql
    Query02-Core Counts.sql
    ...
  Database/
    Query52-<ShortName>.sql
    ...
```

`manifest.json` is an array of `{ Number, ShortName, Scope, File }` describing every split query in that version, in source order. The driver reads this instead of re-parsing filenames; it also serves as a human-readable index of what's in each version.

Split output is committed to git. Re-run the splitter only when a new/updated source file is added to `SQL-Diag-Source-Files/`.

### 2. Driver — `Scripts/Invoke-DiagnosticRun.ps1`

**Config files** (`Scripts/config/`):

- `servers.json` — array of `{ "ServerName": "localhost" }`. Connections use Windows/Integrated auth with `Encrypt=Mandatory;TrustServerCertificate=True`.
- `exclusions.json` — `{ "ExcludedDatabases": [...], "ExcludedQueryNumbers": [...] }`, applied globally across every server in the run.

**Version resolution:** connect to the server, read `SERVERPROPERTY('ProductMajorVersion')`, and map it to a `Scripts/QueryLibrary/<Version>` folder via a small lookup table in the driver (e.g. `13` → `SQL Server 2016 SP2` — this source also covers SP3 builds — `16` → `SQL Server 2022`). If no folder matches, log an error for that server and skip it.

**Per-server execution (sequential, one server at a time):**

1. Resolve version folder as above.
2. Load `manifest.json` for that version; filter out any query number present in `ExcludedQueryNumbers`.
3. Run each `Instance/` query in ascending query-number order against the server (default database context). Export the first result set to:
   `Results/<RunTimestamp>/<ServerName>-Query-<N>-<ShortName>.csv`
4. Query `sys.databases` for databases where `state_desc = 'ONLINE'` and `database_id > 4` (excludes system databases), minus anything in `ExcludedDatabases`.
5. For each remaining database: open a connection scoped to that database (`Initial Catalog=<db>`), and run each `Database/` query in ascending order. Prepend `ServerName` and `DatabaseName` columns to the result set, then export to:
   `Results/<RunTimestamp>/<ServerName>-<DatabaseName>-Query-<N>-<ShortName>.csv`
6. Any failure executing a query (connection error, permission error, unsupported feature on that version, etc.) is caught, appended as a row to `Results/<RunTimestamp>/errors.csv` (`ServerName, DatabaseName, QueryNumber, ShortName, ErrorMessage, Timestamp`), and execution continues with the next query.

### 3. Output

`Results/<yyyyMMdd_HHmmss>/` — one folder per run, containing all CSVs for that run plus `errors.csv`. Runs never overwrite each other's output.

## Error Handling

- Per-query failures are logged and skipped (see step 6 above); they do not abort the run for that server or move to the next server.
- A server that can't be connected to at all, or whose version doesn't map to a known query-library folder, is logged as a single error row and skipped entirely.

## Testing

- Splitter: run against both existing source files (`SQL Server 2016 SP2`, `SQL Server 2022`) and verify the generated folder structure, file count matches the number of `(Query N)` headers, and instance/database boundary matches the source banners.
- Driver: initial test run against `localhost` (SQL Server 2022, Windows auth, Encrypt Mandatory + Trust Server Certificate) to validate connection handling, CSV output, and the exclusion lists, before running against production 2016 SP2 servers.
