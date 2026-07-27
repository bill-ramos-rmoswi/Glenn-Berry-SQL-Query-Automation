-- Flags sp_configure settings that differ from Glenn Berry's own "Focus on these settings"
-- guidance in Scripts/QueryLibrary/<version>/Instance/Query04-Configuration Values.sql.
-- Settings the source comment calls out as workload-dependent (cost threshold for parallelism,
-- max degree of parallelism, tempdb metadata memory-optimized) are deliberately not enforced.
SET NOCOUNT ON;

IF OBJECT_ID('stg.Configuration_Values') IS NOT NULL
BEGIN
    ;WITH Rules AS (
        SELECT * FROM (VALUES
            ('automatic soft-NUMA disabled', '0', 'Warning', 'Soft-NUMA auto-disable should normally stay off (0) unless deliberately overridden.'),
            ('backup checksum default',      '1', 'Warning', 'Backup checksums should be on (1) so corrupt backups are caught at backup time, not restore time.'),
            ('backup compression default',   '1', 'Info',    'Backup compression is usually a net win (smaller/faster backups) unless the instance is CPU-constrained.'),
            ('lightweight pooling',          '0', 'Warning', 'Fiber-mode scheduling (lightweight pooling) is a legacy setting that should stay off (0).'),
            ('optimize for ad hoc workloads','1', 'Warning', 'Should be on (1) to avoid caching full plans for single-use ad hoc statements and bloating the plan cache.'),
            ('priority boost',               '0', 'Warning', 'Priority boost should stay off (0); enabling it can starve the OS and other processes.'),
            ('remote admin connections',     '1', 'Warning', 'Should be on (1) so a DAC connection is possible remotely if the instance becomes unresponsive.')
        ) AS r(SettingName, ExpectedValue, Severity, Guidance)
    )
    SELECT
        cv.ServerName,
        CAST(NULL AS NVARCHAR(128)) AS DatabaseName,
        'NonDefaultConfig' AS FindingType,
        cv.[name] AS ObjectName,
        r.Severity,
        'value_in_use=' + LTRIM(RTRIM(cv.value_in_use)) + ' (expected ' + r.ExpectedValue + '). ' + r.Guidance AS Detail
    FROM stg.Configuration_Values cv
    JOIN Rules r ON r.SettingName = cv.[name]
    WHERE cv.RunId = $(RunId)
      AND LTRIM(RTRIM(cv.value_in_use)) <> r.ExpectedValue

    UNION ALL

    SELECT
        cv.ServerName,
        NULL,
        'NonDefaultConfig',
        cv.[name],
        'Warning',
        'max server memory (MB) is left at the unconfigured default (essentially unlimited), which can starve the OS of memory. Set it explicitly.'
    FROM stg.Configuration_Values cv
    WHERE cv.RunId = $(RunId)
      AND cv.[name] = 'max server memory (MB)'
      AND LTRIM(RTRIM(cv.value_in_use)) = '2147483647'

    UNION ALL

    SELECT
        cv.ServerName,
        NULL,
        'NonDefaultConfig',
        cv.[name],
        'Info',
        'CLR integration is enabled (value_in_use=1). Only enable if actually needed by a deployed CLR object.'
    FROM stg.Configuration_Values cv
    WHERE cv.RunId = $(RunId)
      AND cv.[name] = 'clr enabled'
      AND LTRIM(RTRIM(cv.value_in_use)) = '1';
END
ELSE
BEGIN
    SELECT CAST(NULL AS NVARCHAR(128)) AS ServerName, CAST(NULL AS NVARCHAR(128)) AS DatabaseName,
           CAST(NULL AS NVARCHAR(64)) AS FindingType, CAST(NULL AS NVARCHAR(256)) AS ObjectName,
           CAST(NULL AS NVARCHAR(16)) AS Severity, CAST(NULL AS NVARCHAR(4000)) AS Detail
    WHERE 1 = 0;
END
