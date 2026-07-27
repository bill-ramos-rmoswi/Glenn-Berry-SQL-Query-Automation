-- Flags entire databases where EVERY index (across all tables, per
-- Database/Query75-Overall Index Usage - Reads.sql and Query76-...-Writes.sql) shows zero reads
-- and zero writes since the last restart -- a database-wide, stronger version of
-- UnusedIndex.sql's per-index signal. A database like this is a candidate for "has this actually
-- been migrated off this server, or is it just idle" review; it does not by itself mean the
-- database is safe to drop. Guarded by the same SQL Server uptime floor as UnusedIndex.sql, since
-- the underlying index-usage DMV resets on every restart and a short uptime makes a zero-usage
-- reading meaningless.
--
-- Unlike UnusedIndex.sql, this intentionally does not exclude HEAP tables (index_id = 0) or
-- corroborate against CPU/IO share -- a HEAP with real traffic would show nonzero reads/writes
-- here too, so including it only makes the "every index is idle" signal stricter, not looser.
--
-- IndexCount is included alongside the standard Finding columns so New-DiagnosticReport.ps1 can
-- reuse this same query to populate the per-server "Idle Indexes" report column, rather than
-- re-deriving the same logic a second time.
SET NOCOUNT ON;

IF OBJECT_ID('stg.Overall_Index_Usage_Reads') IS NOT NULL
   AND OBJECT_ID('stg.Overall_Index_Usage_Writes') IS NOT NULL
   AND OBJECT_ID('stg.Hardware_Info') IS NOT NULL
BEGIN
    ;WITH Uptime AS (
        SELECT ServerName, TRY_CAST([SQL Server Up Time (hrs)] AS DECIMAL(18,2)) AS UpTimeHours
        FROM stg.Hardware_Info
        WHERE RunId = $(RunId)
    ),
    ReadTotals AS (
        SELECT ServerName, DatabaseName,
               COUNT(*) AS IndexCount,
               SUM(ISNULL(TRY_CAST([Total Reads] AS BIGINT), 0)) AS TotalReads
        FROM stg.Overall_Index_Usage_Reads
        WHERE RunId = $(RunId)
        GROUP BY ServerName, DatabaseName
    ),
    WriteTotals AS (
        SELECT ServerName, DatabaseName,
               SUM(ISNULL(TRY_CAST(Writes AS BIGINT), 0)) AS TotalWrites
        FROM stg.Overall_Index_Usage_Writes
        WHERE RunId = $(RunId)
        GROUP BY ServerName, DatabaseName
    )
    SELECT r.ServerName, r.DatabaseName, 'DormantDatabase' AS FindingType,
           r.DatabaseName AS ObjectName,
           'Info' AS Severity,
           CAST(r.IndexCount AS VARCHAR(10)) + ' index(es) with zero reads and zero writes since the last restart (' +
               CAST(CAST(u.UpTimeHours / 24.0 AS DECIMAL(10,1)) AS VARCHAR(20)) +
               ' days up). May be idle, or may already be migrated off this server -- verify before assuming it can be removed.' AS Detail,
           r.IndexCount
    FROM ReadTotals r
    JOIN WriteTotals w ON w.ServerName = r.ServerName AND w.DatabaseName = r.DatabaseName
    JOIN Uptime u ON u.ServerName = r.ServerName
    WHERE r.TotalReads = 0 AND w.TotalWrites = 0
      AND u.UpTimeHours >= ($(UnusedIndexMinUptimeDays) * 24.0);
END
ELSE
BEGIN
    SELECT CAST(NULL AS NVARCHAR(128)) AS ServerName, CAST(NULL AS NVARCHAR(128)) AS DatabaseName,
           CAST(NULL AS NVARCHAR(64)) AS FindingType, CAST(NULL AS NVARCHAR(256)) AS ObjectName,
           CAST(NULL AS NVARCHAR(16)) AS Severity, CAST(NULL AS NVARCHAR(4000)) AS Detail,
           CAST(NULL AS INT) AS IndexCount
    WHERE 1 = 0;
END
