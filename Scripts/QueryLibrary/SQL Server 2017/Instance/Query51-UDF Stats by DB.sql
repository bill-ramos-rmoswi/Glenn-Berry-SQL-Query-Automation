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

-- Look at UDF execution statistics (Query 51) (UDF Stats by DB)
SELECT TOP (25) DB_NAME(database_id) AS [Database Name], 
		   OBJECT_NAME(object_id, database_id) AS [Function Name],
		   total_worker_time, execution_count, total_elapsed_time,  
           total_elapsed_time/execution_count AS [avg_elapsed_time],  
           last_elapsed_time, last_execution_time, cached_time, [type_desc] 
FROM sys.dm_exec_function_stats WITH (NOLOCK) 
ORDER BY total_worker_time DESC OPTION (RECOMPILE);
------

-- sys.dm_exec_function_stats (Transact-SQL)
-- https://bit.ly/2q1Q6BM

-- Showplan Enhancements for UDFs
-- https://bit.ly/2LVqiQ1
