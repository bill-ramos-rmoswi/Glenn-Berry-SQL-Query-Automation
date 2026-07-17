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

-- Log space usage for current database  (Query 53) (Log Space Usage)
SELECT DB_NAME(lsu.database_id) AS [Database Name], db.recovery_model_desc AS [Recovery Model],
		CAST(lsu.total_log_size_in_bytes/1048576.0 AS DECIMAL(10, 2)) AS [Total Log Space (MB)],
		CAST(lsu.used_log_space_in_bytes/1048576.0 AS DECIMAL(10, 2)) AS [Used Log Space (MB)], 
		CAST(lsu.used_log_space_in_percent AS DECIMAL(10, 2)) AS [Used Log Space %],
		CAST(lsu.log_space_in_bytes_since_last_backup/1048576.0 AS DECIMAL(10, 2)) AS [Used Log Space Since Last Backup (MB)],
		db.log_reuse_wait_desc		 
FROM sys.dm_db_log_space_usage AS lsu WITH (NOLOCK)
INNER JOIN sys.databases AS db WITH (NOLOCK)
ON lsu.database_id = db.database_id
OPTION (RECOMPILE);
------

-- Look at log file size and usage, along with the log reuse wait description for the current database

-- sys.dm_db_log_space_usage (Transact-SQL)
-- https://bit.ly/2H4MQw9
