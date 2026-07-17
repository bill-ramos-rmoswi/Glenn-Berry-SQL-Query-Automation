--******************************************************************************
--*   Copyright (C) 2026 Glenn Berry
--*   All rights reserved. 
--*
--*
--*   You may alter this code for your own *non-commercial* purposes. You may
--*   republish altered code as long as you include this copyright and give due credit. 
--*
--*
--*   THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
--*   ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
--*   TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
--*   PARTICULAR PURPOSE. 
--*
--******************************************************************************

-- Read most recent entries from all SQL Server Error Logs (Query 24) (Error Log Entries)
DROP TABLE IF EXISTS #ErrorLogFiles;
	CREATE TABLE #ErrorLogFiles
	([Archive #] INT,[Date] NVARCHAR(25),[Log File Size (Byte)]INT)

INSERT INTO #ErrorLogFiles
([Archive #],[Date],[Log File Size (Byte)])
EXEC master.sys.xp_enumerrorlogs;

DROP TABLE IF EXISTS #SQLErrorLog_AllLogs;
	CREATE TABLE #SQLErrorLog_AllLogs
	(LogDate DATETIME ,ProcessInfo NVARCHAR(12), LogText NVARCHAR(4000))

DECLARE @i INT = 0;
DECLARE @sql NVARCHAR(200) = N'';
DECLARE @logCount INT = (SELECT COUNT(*) FROM #ErrorLogFiles);

WHILE (@i < @logCount)
    BEGIN
        IF(@i in (SELECT [Archive #] FROM #ErrorLogFiles))
            BEGIN
                SET @sql = N'INSERT INTO #SQLErrorLog_AllLogs (LogDate, ProcessInfo, LogText)
                             EXEC master.sys.sp_readerrorlog ' + CAST(@i AS NVARCHAR(2)) + N';'
                EXEC master.sys.sp_executesql @sql;
            END
        SET @i += 1;
    END

SELECT TOP(1000)LogDate, ProcessInfo, LogText 
FROM #SQLErrorLog_AllLogs WITH (NOLOCK)
ORDER BY LogDate DESC OPTION (RECOMPILE);

DROP TABLE IF EXISTS #ErrorLogFiles;
DROP TABLE IF EXISTS #SQLErrorLog_AllLogs;
GO
------
