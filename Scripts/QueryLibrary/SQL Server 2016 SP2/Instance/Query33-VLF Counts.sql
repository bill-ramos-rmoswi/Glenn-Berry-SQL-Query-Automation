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

-- Get VLF Counts for all databases on the instance (Query 33) (VLF Counts)
SELECT [name] AS [Database Name], [VLF Count]
FROM sys.databases AS db WITH (NOLOCK)
CROSS APPLY (SELECT file_id, COUNT(*) AS [VLF Count]
		     FROM sys.dm_db_log_info(db.database_id)
			 GROUP BY file_id) AS li
ORDER BY [VLF Count] DESC OPTION (RECOMPILE);
------

-- High VLF counts can affect write performance to the log file
-- and they can make full database restores and crash recovery take much longer
-- Try to keep your VLF counts under 200 in most cases (depending on log file size)

-- Important change to VLF creation algorithm in SQL Server 2014
-- https://bit.ly/2Hsjbg4

-- SQL Server Transaction Log Architecture and Management Guide
-- https://bit.ly/2JjmQRZ
