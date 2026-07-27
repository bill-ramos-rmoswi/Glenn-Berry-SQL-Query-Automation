-- Flags indexes with zero reads and zero writes since the last restart, corroborated by the
-- owning database's negligible CPU/IO share so a busy database's momentarily-idle index isn't
-- mistaken for truly unused. Guarded by SQL Server uptime (index usage DMVs reset on restart --
-- a short uptime makes a zero-usage reading meaningless, per
-- Scripts/QueryLibrary/<version>/Database/Query75-Overall Index Usage - Reads.sql /
-- Query76-...-Writes.sql, cross-referenced with Instance/Query35-CPU Usage by Database.sql,
-- Instance/Query36-IO Usage By Database.sql, and Instance/Query17-Hardware Info.sql).
-- Informational only -- always needs human review before dropping an index.
SET NOCOUNT ON;

IF OBJECT_ID('stg.Overall_Index_Usage_Reads') IS NOT NULL
   AND OBJECT_ID('stg.Overall_Index_Usage_Writes') IS NOT NULL
   AND OBJECT_ID('stg.Hardware_Info') IS NOT NULL
   AND OBJECT_ID('stg.CPU_Usage_by_Database') IS NOT NULL
   AND OBJECT_ID('stg.IO_Usage_By_Database') IS NOT NULL
BEGIN
    ;WITH Uptime AS (
        SELECT ServerName, TRY_CAST([SQL Server Up Time (hrs)] AS DECIMAL(18,2)) AS UpTimeHours
        FROM stg.Hardware_Info
        WHERE RunId = $(RunId)
    ),
    CpuShare AS (
        SELECT ServerName, [Database Name] AS DatabaseName, TRY_CAST([CPU Percent] AS DECIMAL(5,2)) AS CpuPercent
        FROM stg.CPU_Usage_by_Database
        WHERE RunId = $(RunId)
    ),
    IoShare AS (
        SELECT ServerName, [Database Name] AS DatabaseName, TRY_CAST([Total I/O %] AS DECIMAL(5,2)) AS IoPercent
        FROM stg.IO_Usage_By_Database
        WHERE RunId = $(RunId)
    ),
    ZeroUsageIndexes AS (
        SELECT r.ServerName, r.DatabaseName, r.SchemaName, r.ObjectName, r.IndexName
        FROM stg.Overall_Index_Usage_Reads r
        JOIN stg.Overall_Index_Usage_Writes w
          ON w.RunId = r.RunId AND w.ServerName = r.ServerName AND w.DatabaseName = r.DatabaseName
         AND w.SchemaName = r.SchemaName AND w.ObjectName = r.ObjectName AND w.IndexName = r.IndexName
         AND w.index_id = r.index_id
        WHERE r.RunId = $(RunId)
          AND r.[Index Type] <> 'HEAP'
          AND ISNULL(TRY_CAST(r.[Total Reads] AS BIGINT), 0) = 0
          AND ISNULL(TRY_CAST(w.Writes AS BIGINT), 0) = 0
    )
    SELECT z.ServerName, z.DatabaseName, 'UnusedIndex' AS FindingType,
           z.SchemaName + '.' + z.ObjectName + '.' + z.IndexName AS ObjectName,
           'Info' AS Severity,
           'Zero reads and zero writes since the last restart (' + CAST(CAST(u.UpTimeHours / 24.0 AS DECIMAL(10,1)) AS VARCHAR(20)) +
               ' days up), and ' + z.DatabaseName + ' accounts for only ' + ISNULL(CAST(c.CpuPercent AS VARCHAR(20)), '?') +
               '% CPU / ' + ISNULL(CAST(i.IoPercent AS VARCHAR(20)), '?') +
               '% I/O on the instance. Candidate for review before dropping.' AS Detail
    FROM ZeroUsageIndexes z
    JOIN Uptime u ON u.ServerName = z.ServerName
    LEFT JOIN CpuShare c ON c.ServerName = z.ServerName AND c.DatabaseName = z.DatabaseName
    LEFT JOIN IoShare i ON i.ServerName = z.ServerName AND i.DatabaseName = z.DatabaseName
    WHERE u.UpTimeHours >= ($(UnusedIndexMinUptimeDays) * 24.0)
      AND ISNULL(c.CpuPercent, 0) <= $(UnusedIndexMaxCpuPercent)
      AND ISNULL(i.IoPercent, 0) <= $(UnusedIndexMaxIoPercent);
END
ELSE
BEGIN
    SELECT CAST(NULL AS NVARCHAR(128)) AS ServerName, CAST(NULL AS NVARCHAR(128)) AS DatabaseName,
           CAST(NULL AS NVARCHAR(64)) AS FindingType, CAST(NULL AS NVARCHAR(256)) AS ObjectName,
           CAST(NULL AS NVARCHAR(16)) AS Severity, CAST(NULL AS NVARCHAR(4000)) AS Detail
    WHERE 1 = 0;
END
