-- Flags database-level settings called out in Glenn Berry's "Things to look at" guidance in
-- Scripts/QueryLibrary/<version>/Instance/Query32-Database Properties.sql: page verify should
-- be CHECKSUM, auto_shrink/auto_close should not be enabled, target_recovery_time_in_seconds
-- should be 60, and the transaction log should not be close to full.
SET NOCOUNT ON;

IF OBJECT_ID('stg.Database_Properties') IS NOT NULL
BEGIN
    SELECT dp.ServerName, dp.[Database Name] AS DatabaseName, 'DatabasePropertiesFlags' AS FindingType,
           'PageVerifyOption' AS ObjectName, 'Warning' AS Severity,
           'Page Verify Option is ''' + ISNULL(dp.[Page Verify Option], '?') + ''', should be CHECKSUM to detect torn/corrupt pages.' AS Detail
    FROM stg.Database_Properties dp
    WHERE dp.RunId = $(RunId) AND ISNULL(dp.[Page Verify Option], '') <> 'CHECKSUM'

    UNION ALL

    SELECT dp.ServerName, dp.[Database Name], 'DatabasePropertiesFlags', 'AutoShrink', 'Warning',
           'AUTO_SHRINK is enabled; this can cause severe fragmentation and I/O storms and should generally stay off.'
    FROM stg.Database_Properties dp
    WHERE dp.RunId = $(RunId) AND dp.is_auto_shrink_on IN ('True', '1')

    UNION ALL

    SELECT dp.ServerName, dp.[Database Name], 'DatabasePropertiesFlags', 'AutoClose', 'Warning',
           'AUTO_CLOSE is enabled; this closes/reopens the database on every disconnect, hurting performance on busy databases.'
    FROM stg.Database_Properties dp
    WHERE dp.RunId = $(RunId) AND dp.is_auto_close_on IN ('True', '1')

    UNION ALL

    SELECT dp.ServerName, dp.[Database Name], 'DatabasePropertiesFlags', 'TargetRecoveryTime', 'Info',
           'target_recovery_time_in_seconds is ' + ISNULL(dp.target_recovery_time_in_seconds, '?') + ', expected 60.'
    FROM stg.Database_Properties dp
    WHERE dp.RunId = $(RunId) AND ISNULL(dp.target_recovery_time_in_seconds, '') <> '60'

    UNION ALL

    SELECT dp.ServerName, dp.[Database Name], 'DatabasePropertiesFlags', 'LogUsedPercent',
           CASE WHEN TRY_CAST(dp.[Log Used %] AS DECIMAL(5,2)) >= $(LogUsedPercentCritical) THEN 'Critical' ELSE 'Warning' END,
           'Transaction log is ' + dp.[Log Used %] + '% used (recovery model ' + ISNULL(dp.[Recovery Model], '?') +
               ', log reuse wait ' + ISNULL(dp.[Log Reuse Wait Description], '?') + ').'
    FROM stg.Database_Properties dp
    WHERE dp.RunId = $(RunId) AND TRY_CAST(dp.[Log Used %] AS DECIMAL(5,2)) >= $(LogUsedPercentWarning);
END
ELSE
BEGIN
    SELECT CAST(NULL AS NVARCHAR(128)) AS ServerName, CAST(NULL AS NVARCHAR(128)) AS DatabaseName,
           CAST(NULL AS NVARCHAR(64)) AS FindingType, CAST(NULL AS NVARCHAR(256)) AS ObjectName,
           CAST(NULL AS NVARCHAR(16)) AS Severity, CAST(NULL AS NVARCHAR(4000)) AS Detail
    WHERE 1 = 0;
END
