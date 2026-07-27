-- Flags servers with more than the configured threshold of sysadmin role members, from the
-- custom Scripts/CustomQueries/Instance/Query100-Server Role Members.sql (no query in Glenn
-- Berry's own set covers server-role membership). Returns nothing until a Results\<timestamp>\
-- folder collected after Query100 was added gets imported -- older runs simply won't have
-- stg.Server_Role_Members yet.
SET NOCOUNT ON;

IF OBJECT_ID('stg.Server_Role_Members') IS NOT NULL
BEGIN
    ;WITH Counts AS (
        SELECT ServerName, COUNT(*) AS SysadminCount
        FROM stg.Server_Role_Members
        WHERE RunId = $(RunId) AND [Server Role] = 'sysadmin'
        GROUP BY ServerName
    )
    SELECT c.ServerName, CAST(NULL AS NVARCHAR(128)) AS DatabaseName, 'TooManySysadmins' AS FindingType,
           'sysadmin' AS ObjectName,
           CASE WHEN c.SysadminCount >= $(SysadminCountWarning) * 2 THEN 'Critical' ELSE 'Warning' END AS Severity,
           CAST(c.SysadminCount AS VARCHAR(10)) + ' logins are members of the sysadmin server role (threshold ' +
               CAST($(SysadminCountWarning) AS VARCHAR(10)) + '). Review membership; each is a full-control account.' AS Detail
    FROM Counts c
    WHERE c.SysadminCount >= $(SysadminCountWarning);
END
ELSE
BEGIN
    SELECT CAST(NULL AS NVARCHAR(128)) AS ServerName, CAST(NULL AS NVARCHAR(128)) AS DatabaseName,
           CAST(NULL AS NVARCHAR(64)) AS FindingType, CAST(NULL AS NVARCHAR(256)) AS ObjectName,
           CAST(NULL AS NVARCHAR(16)) AS Severity, CAST(NULL AS NVARCHAR(4000)) AS Detail
    WHERE 1 = 0;
END
