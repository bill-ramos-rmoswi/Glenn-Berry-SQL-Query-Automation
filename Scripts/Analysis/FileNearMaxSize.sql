-- Flags data/log files approaching their configured autogrowth ceiling (max_size), from
-- Scripts/QueryLibrary/<version>/Instance/Query25-Database Filenames and Paths.sql. max_size is
-- in 8KB pages; -1 means unlimited growth (excluded here -- there's no ceiling to approach).
-- This is a different failure mode from DriveSpaceLow.sql: a file can hit its own configured
-- ceiling and stop growing even when the underlying volume still has plenty of free space.
SET NOCOUNT ON;

IF OBJECT_ID('stg.Database_Filenames_and_Paths') IS NOT NULL
BEGIN
    ;WITH F AS (
        SELECT ServerName, [Database Name] AS DatabaseName, [name] AS FileLogicalName, type_desc,
               TRY_CAST([Total Size in MB] AS DECIMAL(18,2)) AS TotalSizeMB,
               TRY_CAST(max_size AS BIGINT) AS MaxSizePages
        FROM stg.Database_Filenames_and_Paths
        WHERE RunId = $(RunId)
    )
    SELECT ServerName, DatabaseName, 'FileNearMaxSize' AS FindingType,
           FileLogicalName + ' (' + type_desc + ')' AS ObjectName,
           CASE WHEN (TotalSizeMB / (MaxSizePages / 128.0) * 100.0) >= 98 THEN 'Critical' ELSE 'Warning' END AS Severity,
           'File is ' + CAST(CAST(TotalSizeMB / (MaxSizePages / 128.0) * 100.0 AS DECIMAL(5,1)) AS VARCHAR(20)) +
               '% of its configured max size (' + CAST(TotalSizeMB AS VARCHAR(20)) + ' MB of ' +
               CAST(CAST(MaxSizePages / 128.0 AS DECIMAL(18,2)) AS VARCHAR(20)) +
               ' MB); autogrowth will fail once the limit is reached.' AS Detail
    FROM F
    WHERE MaxSizePages > 0
      AND TotalSizeMB IS NOT NULL
      AND (TotalSizeMB / (MaxSizePages / 128.0) * 100.0) >= $(FileNearMaxPercentWarning);
END
ELSE
BEGIN
    SELECT CAST(NULL AS NVARCHAR(128)) AS ServerName, CAST(NULL AS NVARCHAR(128)) AS DatabaseName,
           CAST(NULL AS NVARCHAR(64)) AS FindingType, CAST(NULL AS NVARCHAR(256)) AS ObjectName,
           CAST(NULL AS NVARCHAR(16)) AS Severity, CAST(NULL AS NVARCHAR(4000)) AS Detail
    WHERE 1 = 0;
END
