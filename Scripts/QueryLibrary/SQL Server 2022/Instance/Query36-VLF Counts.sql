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

-- Get VLF Counts for all databases on the instance (Query 36) (VLF Counts)
SELECT db.[name] AS [Database Name], li.[VLF Count]
FROM sys.databases AS db WITH (NOLOCK)
CROSS APPLY (SELECT file_id, COUNT(*) AS [VLF Count]
		     FROM sys.dm_db_log_info (db.database_id)
			 GROUP BY file_id) AS li
ORDER BY li.[VLF Count] DESC OPTION (RECOMPILE);
------

-- High VLF counts can affect write performance to the log file
-- and they can make full database restores and crash recovery take much longer
-- Try to keep your VLF counts under 200 in most cases (depending on log file size)

-- sys.dm_db_log_info (Transact-SQL)
-- https://bit.ly/3jpmqsd

-- sys.databases (Transact-SQL)
-- https://bit.ly/2G5wqaX

-- SQL Server Transaction Log Architecture and Management Guide
-- https://bit.ly/2JjmQRZ

-- VLF Growth Formula (SQL Server 2022 and newer)
-- If the log growth increment is less than 1/8th the current size of the log
--		Then:            1 new VLF
-- Otherwise:
--		Up to 64MB:      1 new VLF
--		64MB to 1GB:     8 new VLFs
--		More than 1GB:  16 new VLFs	

-- Virtual Log Files (VLFs)
-- https://bit.ly/3TN6en1
