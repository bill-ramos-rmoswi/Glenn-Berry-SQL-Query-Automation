-- Flags LUNs/volumes hosting database files that are low on free space, per the guidance in
-- Scripts/QueryLibrary/<version>/Instance/Query27-Volume Info.sql ("Being low on free space can
-- negatively affect performance").
SET NOCOUNT ON;

IF OBJECT_ID('stg.Volume_Info') IS NOT NULL
BEGIN
    SELECT vi.ServerName, CAST(NULL AS NVARCHAR(128)) AS DatabaseName, 'DriveSpaceLow' AS FindingType,
           vi.volume_mount_point AS ObjectName,
           CASE WHEN TRY_CAST(vi.[Space Free %] AS DECIMAL(5,2)) <= $(DriveFreePercentCritical) THEN 'Critical' ELSE 'Warning' END AS Severity,
           vi.volume_mount_point + ' (' + ISNULL(vi.logical_volume_name, '?') + ') is ' + vi.[Space Free %] +
               '% free of ' + vi.[Total Size (GB)] + ' GB.' AS Detail
    FROM stg.Volume_Info vi
    WHERE vi.RunId = $(RunId)
      AND TRY_CAST(vi.[Space Free %] AS DECIMAL(5,2)) <= $(DriveFreePercentWarning);
END
ELSE
BEGIN
    SELECT CAST(NULL AS NVARCHAR(128)) AS ServerName, CAST(NULL AS NVARCHAR(128)) AS DatabaseName,
           CAST(NULL AS NVARCHAR(64)) AS FindingType, CAST(NULL AS NVARCHAR(256)) AS ObjectName,
           CAST(NULL AS NVARCHAR(16)) AS Severity, CAST(NULL AS NVARCHAR(4000)) AS Detail
    WHERE 1 = 0;
END
