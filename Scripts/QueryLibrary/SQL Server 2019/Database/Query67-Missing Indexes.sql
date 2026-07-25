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

-- Missing Indexes for current database by Index Advantage  (Query 67) (Missing Indexes)
SELECT CONVERT(decimal(18,2), migs.user_seeks * migs.avg_total_user_cost * (migs.avg_user_impact * 0.01)) AS [Index Advantage], 
CONVERT(nvarchar(25), migs.last_user_seek, 20) AS [Last User Seek], mid.[statement] AS [Database.Schema.Table], 
COUNT(1) OVER(PARTITION BY mid.[statement]) AS [Missing Indexes for Table], 
COUNT(1) OVER(PARTITION BY mid.[statement], mid.equality_columns) AS [Similar Missing Indexes for Table], 
mid.equality_columns AS [Equality Columns], mid.inequality_columns AS [Inequality Columns], 
mid.included_columns AS [Included Columns], migs.user_seeks AS [User Seeks], 
CONVERT(decimal(18,2), migs.avg_total_user_cost) AS [Avg Total User Cost], 
CONVERT(decimal(18,2), migs.avg_user_impact) AS [Avg User Impact %],
REPLACE(REPLACE(LEFT(st.[text], 512), CHAR(10),''), CHAR(13),'') AS [Short Query Text],
OBJECT_NAME(mid.[object_id]) AS [Table Name], p.[rows] AS [Table Rows]
FROM sys.dm_db_missing_index_groups AS mig WITH (NOLOCK) 
INNER JOIN sys.dm_db_missing_index_group_stats_query AS migs WITH(NOLOCK) 
ON mig.index_group_handle = migs.group_handle 
CROSS APPLY sys.dm_exec_sql_text(migs.last_sql_handle) AS st 
INNER JOIN sys.dm_db_missing_index_details AS mid WITH (NOLOCK) 
ON mig.index_handle = mid.index_handle
INNER JOIN sys.partitions AS p WITH (NOLOCK)
ON p.[object_id] = mid.[object_id]
WHERE mid.database_id = DB_ID()
AND p.index_id < 2 
ORDER BY [Index Advantage] DESC OPTION (RECOMPILE);
------

-- Look at index advantage, last user seek time, number of user seeks to help determine source and importance
-- SQL Server is overly eager to add included columns, so beware
-- Do not just blindly add indexes that show up from this query!!!
-- Håkan Winther has given me some great suggestions for this query
