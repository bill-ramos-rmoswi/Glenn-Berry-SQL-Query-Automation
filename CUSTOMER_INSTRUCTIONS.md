# SQL Server Diagnostic Query Collector — Instructions

This package runs a set of read-only diagnostic queries against your SQL Server instance(s) and saves the
results as CSV files. Nothing is changed on your server — every query only reads data.

## 1. Unzip

Unzip this package anywhere on a machine that has network access to your SQL Server instance(s), for
example `C:\GlennBerryDiagnostics\`.

## 2. Prerequisites

- **Windows PowerShell 5.1+** (already included in Windows) or PowerShell 7+.
- **SqlServer PowerShell module.** Open PowerShell and run:
  ```powershell
  Install-Module -Name SqlServer -Scope CurrentUser
  ```
  (If prompted about an untrusted repository, answer `Y`.)
- A Windows account with permission to connect to the target SQL Server instance(s) and with
  `VIEW SERVER STATE` plus read access on the databases you want diagnosed. Run PowerShell as this user.
- Network access to each target SQL Server instance. The tool tests each connection first and automatically
  falls back to an unencrypted connection if an encrypted one fails, so no manual connection-string changes are
  needed either way.

## 3. Configure which server(s) to check

Open `config\servers.json` in a text editor and list each SQL Server instance to run against:

```json
[
  { "ServerName": "localhost" },
  { "ServerName": "MYHOST\\INSTANCENAME" }
]
```

SQL Server 2016 SP2, 2017, 2019, 2022, and 2025 are currently supported. If you list a server running a
different version, it will be skipped with an error logged — everything else still runs.

Optional: edit `config\exclusions.json` to skip specific databases or query numbers:

```json
{
  "ExcludedDatabases": ["SomeDbToSkip"],
  "ExcludedQueryNumbers": [10, 25]
}
```

## 4. Run it

In PowerShell, from inside the unzipped folder:

```powershell
powershell -NoProfile -File Invoke-DiagnosticRun.ps1
```

This tests the connection to each configured server, runs the diagnostic queries, and writes CSV files to a new
`Results\<yyyyMMdd_HHmmss>\<ServerName>\` folder — one subfolder per server, so it's easy to tell whose results
are whose. It may take several minutes depending on the number of databases.

If a query or a whole server fails (for example, it can't be reached, or its SQL Server version isn't
supported), it's logged to `errors.csv` inside that server's results folder and the run continues with the
next server — a single failure won't stop the collection.

## 5. Send the results back

Right-click the `Results\<yyyyMMdd_HHmmss>` folder that was created, choose **Send to > Compressed
(zipped) folder**, and send the resulting `.zip` file back for analysis.
