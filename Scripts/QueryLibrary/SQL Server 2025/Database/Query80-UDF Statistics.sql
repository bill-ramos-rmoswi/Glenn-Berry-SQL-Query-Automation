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

-- Look at UDF execution statistics (Query 80) (UDF Statistics)
SELECT OBJECT_NAME(efs.[object_id]) AS [Function Name], efs.execution_count,
	   efs.total_worker_time, efs.total_worker_time/efs.execution_count AS [avg_worker_time],
	   efs.total_logical_reads, efs.total_physical_reads, efs.total_elapsed_time, 
	   efs.total_elapsed_time/efs.execution_count AS [avg_elapsed_time],
	   CONVERT(nvarchar(25), efs.last_execution_time, 20) AS [Last Execution Time],	
	   CONVERT(nvarchar(25), efs.cached_time, 20) AS [Plan Cached Time]	   
FROM sys.dm_exec_function_stats AS efs WITH (NOLOCK) 
WHERE efs.database_id = DB_ID()
ORDER BY efs.total_worker_time DESC OPTION (RECOMPILE); 
------

-- New for SQL Server 2016
-- Helps you investigate scalar UDF performance issues
-- Does not return information for table valued functions

-- sys.dm_exec_function_stats (Transact-SQL)
-- https://bit.ly/2q1Q6BM
