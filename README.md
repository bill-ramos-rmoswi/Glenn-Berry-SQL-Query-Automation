# Glenn-Berry-SQL-Query-Automation

Automates running Glenn Berry's [SQL Server Diagnostic Information Queries](https://glennsqlperformance.com/resources/)
against one or more SQL Server instances and exporting each query's results to CSV.

## How it works

1. **`SQL-Diag-Source-Files/`** holds Glenn Berry's unmodified, version-specific `.sql` scripts (one per SQL Server
   version). Treat these as vendored/third-party — don't edit them.
2. **`Scripts/Split-DiagnosticQueries.ps1`** parses each source file and splits it into one `.sql` file per query
   under `Scripts/QueryLibrary/<version>/{Instance,Database}/`, plus a `manifest.json` describing every query
   (number, short name, scope, file path). The generated `QueryLibrary/` is already checked into this repo, so you
   only need to re-run the splitter if you add a new Glenn Berry source file.
3. **`Scripts/Invoke-DiagnosticRun.ps1`** tests connectivity to every server listed in `Scripts/config/servers.json`
   (retrying with `Encrypt=False` if the initial `Encrypt=True` connection attempt fails), detects each reachable
   server's SQL Server version, runs the matching instance-level queries, then runs the database-level queries
   against every online, non-excluded user database. Results for each server are exported as CSV under a
   per-server folder under `Results/<timestamp>/`.

## Prerequisites

- **PowerShell 5.1+** or PowerShell 7+
- **[SqlServer](https://www.powershellgallery.com/packages/SqlServer) module** (provides `Invoke-Sqlcmd`):
  ```powershell
  Install-Module -Name SqlServer -Scope CurrentUser
  ```
- **[Pester](https://pester.dev/) 5.0+** (only needed to run the test suite):
  ```powershell
  Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser
  ```
- Network access and permission to connect to the target SQL Server instance(s). Connections use Windows
  Authentication (`Integrated Security=True`) — run PowerShell as a user with `VIEW SERVER STATE` and read access
  on the target instance(s). Connections try `Encrypt=True;TrustServerCertificate=True` first and automatically
  retry with `Encrypt=False;TrustServerCertificate=True` if that fails (e.g. the instance has no valid TLS
  certificate) before giving up on that server.

## Setup

1. Clone the repo.
2. Edit `Scripts/config/servers.json` to list the SQL Server instance(s) you want to run against:
   ```json
   [
     { "ServerName": "localhost" },
     { "ServerName": "MYHOST\\INSTANCENAME" }
   ]
   ```
3. Optionally edit `Scripts/config/exclusions.json` to skip specific databases or query numbers:
   ```json
   {
     "ExcludedDatabases": ["SomeDbToSkip"],
     "ExcludedQueryNumbers": [10, 25]
   }
   ```

SQL Server 2016 SP2, 2017, 2019, 2022, and 2025 have a generated query library today. Running against another
version, or a version whose query library folder is missing, will log an error for that server and continue
(see below).

## Running a diagnostic pass

```powershell
powershell -NoProfile -File Scripts/Invoke-DiagnosticRun.ps1
```

For each configured server, this first tests connectivity with `SELECT @@VERSION;` (retrying with
`Encrypt=False` if `Encrypt=True` fails); a server that can't be reached either way is logged and skipped, and
the run moves on to the next server in the list.

This creates `Results/<yyyyMMdd_HHmmss>/<ServerName>/` — one subfolder per configured server — containing:

- `<ServerName>-Query-<N>-<ShortName>.csv` for each instance-level query.
- `<ServerName>-<DatabaseName>-Query-<N>-<ShortName>.csv` for each database-level query, per database. These CSVs
  include `ServerName`/`DatabaseName` prefix columns so results from multiple servers/databases can be concatenated.
- `errors.csv` — only created if that server had any failure (including a failed connection or an unsupported
  version); one row per failure with the server, database, query number, and error message. A server or query
  erroring does not stop the run; it's logged in that server's folder and the run continues.

`Results/` is gitignored — each run's output stays local.

## Packaging for a customer

To hand a customer a self-contained zip they can run without cloning the repo:

```powershell
powershell -NoProfile -File Scripts/New-CustomerPackage.ps1
```

This stages the runtime-only files (`Invoke-DiagnosticRun.ps1`, `Modules/`, `config/`, `QueryLibrary/`) plus
`CUSTOMER_INSTRUCTIONS.md` into `dist/GlennBerryDiagnostics_<timestamp>/` and zips it. `dist/` is gitignored.
The customer edits `config/servers.json`, runs the script, and zips the resulting `Results/` folder back to you.

## Regenerating the query library

Only needed if you add a new Glenn Berry source file to `SQL-Diag-Source-Files/`:

```powershell
powershell -NoProfile -File Scripts/Split-DiagnosticQueries.ps1
```

## Running tests

```powershell
Import-Module Pester -MinimumVersion 5.0.0 -Force
Invoke-Pester -Path Scripts/Tests -Output Detailed
```

## Repository structure

- `SQL-Diag-Source-Files/` — unmodified upstream Glenn Berry diagnostic query scripts, one per SQL Server version.
- `Scripts/QueryLibrary/` — generated, per-query `.sql` files and manifests (checked in).
- `Scripts/Modules/DiagnosticSplitter.psm1` — splits a source file into the query library.
- `Scripts/Modules/DiagnosticDriver.psm1` — tests connectivity (with `Encrypt` fallback), runs queries against
  configured servers, and exports CSVs to a per-server results folder.
- `Scripts/Split-DiagnosticQueries.ps1` / `Scripts/Invoke-DiagnosticRun.ps1` — CLI entry points.
- `Scripts/config/` — `servers.json` (targets) and `exclusions.json` (databases/queries to skip).
- `Scripts/Tests/` — Pester test suite.

## Prior art

[dbatools](https://dbatools.io/)'s `Invoke-DbaDiagnosticQuery` cmdlet is an existing community solution for running
these queries in an automated fashion.
