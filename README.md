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

## Custom queries

`Scripts/CustomQueries/{Instance,Database}/` holds hand-authored queries that aren't part of Glenn Berry's
source scripts (e.g. `Query100-Server Role Members.sql`, which lists sysadmin role membership — nothing in
Glenn Berry's own set covers server-role security). These are numbered starting at 100 (instance) and 200
(database) to stay clear of the vendor query numbers. `Split-DiagnosticQueries.ps1` merges them into every
version's `manifest.json` after each vendor split, so re-running the splitter never loses them — do **not**
hand-edit files under `Scripts/QueryLibrary/`, add new custom queries under `Scripts/CustomQueries/` instead
and re-run the splitter.

## Analyzing results and generating a report

For a repeatable best-practices analysis (non-default settings, low disk/log space, unused indexes, too many
sysadmins, etc.) with month-over-month drift tracking (new vs. still-open vs. resolved), results get staged
into a SQL Server database and analyzed with T-SQL rather than read as loose CSVs:

```powershell
# 1. Import a Results\<timestamp>\ folder into the staging database
powershell -NoProfile -File Scripts/Import-DiagnosticResults.ps1 -ResultsFolder Results/20260727_104902

# 2. Re-run every rule in Scripts/Analysis/*.sql against that run and update dbo.Findings
Import-Module Scripts/Modules/DiagnosticFindings.psm1 -Force
Import-Module Scripts/Modules/DiagnosticStaging.psm1 -Force
$cred = Get-DiagnosticStagingCredential -Protocol sql -HostName localhost -Path GlennBerrySQLDiag/LLMAgent
$connStr = New-DiagnosticSqlAuthConnectionString -ServerName localhost -Database GlennBerrySQLDiag -Username $cred.Username -Password $cred.Password
$thresholds = @{}
(Get-Content Scripts/config/analysis-thresholds.json -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $thresholds[$_.Name] = $_.Value }
Update-DiagnosticFindings -ConnectionString $connStr -RunId <RunId from step 1> -AnalysisScriptsFolder Scripts/Analysis -Thresholds $thresholds

# 3. Generate the static HTML report
powershell -NoProfile -File Scripts/New-DiagnosticReport.ps1 -OutputFolder dist/report
```

- Staging connects to a SQL Server instance (default `localhost`) as a SQL-auth login retrieved via
  `git credential fill` (see `Scripts/Modules/DiagnosticStaging.psm1`) rather than a config file, so no
  credentials are ever written to disk in this repo.
- CSVs are matched to staging tables by query **short name**, not query number — the same short name can
  carry a different query number across `Results/` runs and library revisions (see the "PowerShell
  Implementation Lessons Learned" section of `CLAUDE.md`).
- `Scripts/Analysis/*.sql` rules encode the "what to look for" guidance already present in each split query
  file's trailing comment block (e.g. `Query04-Configuration Values.sql`, `Query32-Database Properties.sql`)
  rather than an invented best-practices list, plus a couple of higher-level rules synthesized from those same
  staged queries — notably `DormantDatabase.sql`, which flags a database where *every* index has zero reads
  and zero writes since the server's last restart (surfaced as the "Idle Indexes" column on each server page,
  a strong "may already be migrated off this server" signal, not just an individually-unused index). Thresholds
  (drive free %, log used %, minimum uptime before trusting a zero-usage reading, etc.) live in
  `Scripts/config/analysis-thresholds.json`.
- `dbo.Findings` in the staging database tracks each issue's first-detected and last-detected run, and marks
  it resolved once a later run no longer detects it — that's what powers the "still open since" / "resolved"
  view in the generated report instead of every run starting from a blank slate.
- The generated report (`index.html`, `attention.html`, `servers/<server>.html`,
  `servers/<server>/<database>.html`) is self-contained static HTML/CSS/JS — no server needed, so the
  `-OutputFolder` contents can be uploaded as-is to a SharePoint/OneDrive document library.
  - **Don't click through the pages directly in the SharePoint web UI.** Modern SharePoint/OneDrive libraries
    default to "Strict" browser file handling, which forces `.html`/`.htm` files to download instead of
    rendering inline — `index.html` opens in a preview overlay, and every link (e.g. a server name) downloads
    another copy into the local Downloads folder instead of navigating. This is a SharePoint serving setting,
    not a problem with the report's links. Have recipients use SharePoint's **Download** button on the report
    folder to get a ZIP, extract it locally, and open `index.html` from disk — all the relative links between
    pages work correctly once viewed from a local folder.

### Refreshing the data (e.g. a monthly re-run)

1. Collect a new run against the current server list: `powershell -NoProfile -File Scripts/Invoke-DiagnosticRun.ps1`.
   This creates a brand-new `Results/<yyyyMMdd_HHmmss>/` folder — the old one is untouched.
2. Import it: `powershell -NoProfile -File Scripts/Import-DiagnosticResults.ps1 -ResultsFolder Results/<new timestamp>`.
   A different `RunFolderName` always gets a new `RunId` in `dbo.Runs`, so this is additive — it never
   overwrites or deletes a previous run's staged data.
3. Re-run `Update-DiagnosticFindings` (step 2 above) with that new `RunId`. Because `dbo.Findings` is keyed by
   `(ServerName, DatabaseName, FindingType, ObjectName)` across *all* runs, this is what produces the
   month-over-month comparison: an issue seen last month and still present this month stays open with its
   original "first seen" date; one that's no longer detected gets `ResolvedRunId` set automatically; a
   genuinely new one gets inserted fresh.
4. Regenerate the report: `Scripts/New-DiagnosticReport.ps1 -OutputFolder dist/report` — omit `-RunId` and it
   automatically uses the most recently imported run (highest `RunTimestamp` in `dbo.Runs`), so you don't need
   to look up the new `RunId` by hand for routine refreshes.

### Recovering from a failed or interrupted import

`Import-DiagnosticResultsFolder` records one row per file in `dbo.ImportLog` (`Status` = `Success` or
`Failed`), keyed by `(RunId, RelativeFilePath)`. This makes re-running safe and cheap after *any* interruption
— a crashed terminal, a network blip, `Ctrl+C`, a killed process:

```powershell
# Just run the exact same command again:
powershell -NoProfile -File Scripts/Import-DiagnosticResults.ps1 -ResultsFolder Results/20260727_104902
```

Because the `RunFolderName` is unchanged, this reuses the *same* `RunId` instead of creating a new one, and
every file already logged as `Success` is skipped without being re-read or re-copied — only files that never
ran, or that previously failed, get (re)attempted. There is no separate "resume" flag; this behavior is
always on. To see what's currently failed for a run before retrying:

```sql
SELECT RelativeFilePath, ErrorMessage, ImportedAtUtc
FROM dbo.ImportLog
WHERE RunId = <RunId> AND Status = 'Failed'
ORDER BY ImportedAtUtc DESC;
```

A file's own retry loop (2 attempts, reconnecting if the connection dropped) already smooths over most
one-off transient errors before they're even logged as `Failed`; anything still `Failed` after a second
full-command re-run reflects the CSV itself (e.g. a genuinely malformed row) rather than a connection issue —
check the `ErrorMessage` column above, or add `*> import.log` to the command to capture the same warnings to
a file as they happen.

## Running tests

```powershell
Import-Module Pester -MinimumVersion 5.0.0 -Force
Invoke-Pester -Path Scripts/Tests -Output Detailed
```

## Repository structure

- `SQL-Diag-Source-Files/` — unmodified upstream Glenn Berry diagnostic query scripts, one per SQL Server version.
- `Scripts/QueryLibrary/` — generated, per-query `.sql` files and manifests (checked in).
- `Scripts/CustomQueries/` — hand-authored queries (e.g. sysadmin role membership) merged into every version's
  query library after each split; see "Custom queries" above.
- `Scripts/Modules/DiagnosticSplitter.psm1` — splits a source file into the query library and merges custom queries.
- `Scripts/Modules/DiagnosticDriver.psm1` — tests connectivity (with `Encrypt` fallback), runs queries against
  configured servers, and exports CSVs to a per-server results folder.
- `Scripts/Modules/DiagnosticStaging.psm1` — retrieves the staging DB credential and imports a `Results\<timestamp>\`
  folder into the `GlennBerrySQLDiag` staging database (one persistent connection + `SqlBulkCopy`, schema-evolving
  `CREATE`/`ALTER TABLE`, and per-file resumability via `dbo.ImportLog` — see "Recovering from a failed or
  interrupted import" above).
- `Scripts/Modules/DiagnosticFindings.psm1` — runs `Scripts/Analysis/*.sql` and reconciles results into
  `dbo.Findings` (new / still-open / resolved) for drift tracking across runs.
- `Scripts/Modules/DiagnosticReport.psm1` — renders the static HTML report pages.
- `Scripts/Analysis/*.sql` — one best-practices rule per file, run against the staged data for a given run
  (e.g. `DormantDatabase.sql` — a whole database with zero index reads/writes since restart).
- `Scripts/Database/Schema/*.sql` — `GlennBerrySQLDiag` staging database schema (`dbo.Runs`, `dbo.Findings`,
  `dbo.ImportLog`).
- `Scripts/Split-DiagnosticQueries.ps1` / `Scripts/Invoke-DiagnosticRun.ps1` / `Scripts/Import-DiagnosticResults.ps1`
  / `Scripts/New-DiagnosticReport.ps1` — CLI entry points.
- `Scripts/config/` — `servers.json` (targets), `exclusions.json` (databases/queries to skip), and
  `analysis-thresholds.json` (finding severity thresholds).
- `Scripts/Tests/` — Pester test suite.

## Prior art

[dbatools](https://dbatools.io/)'s `Invoke-DbaDiagnosticQuery` cmdlet is an existing community solution for running
these queries in an automated fashion.
