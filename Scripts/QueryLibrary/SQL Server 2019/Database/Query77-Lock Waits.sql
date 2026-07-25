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

-- Get lock waits for current database (Query 77) (Lock Waits)
SELECT o.[name] AS [table_name], i.[name] AS [index_name], ios.index_id, ios.partition_number,
        SUM(ios.row_lock_wait_count) AS [total_row_lock_waits], 
        SUM(ios.row_lock_wait_in_ms) AS [total_row_lock_wait_in_ms],
		SUM(ios.index_lock_promotion_attempt_count) AS [total index_lock_promotion_attempt_count],
        SUM(ios.index_lock_promotion_count) AS [ios.index_lock_promotion_count],
        SUM(ios.page_lock_wait_count) AS [total_page_lock_waits],
        SUM(ios.page_lock_wait_in_ms) AS [total_page_lock_wait_in_ms],
        SUM(ios.page_lock_wait_in_ms) + SUM(row_lock_wait_in_ms) AS [total_lock_wait_in_ms]           
FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) AS ios
INNER JOIN sys.objects AS o WITH (NOLOCK)
ON ios.[object_id] = o.[object_id]
INNER JOIN sys.indexes AS i WITH (NOLOCK)
ON ios.[object_id] = i.[object_id] 
AND ios.index_id = i.index_id
WHERE o.[object_id] > 100
GROUP BY o.[name], i.[name], ios.index_id, ios.partition_number
HAVING SUM(ios.page_lock_wait_in_ms) + SUM(row_lock_wait_in_ms) > 0
ORDER BY total_lock_wait_in_ms DESC OPTION (RECOMPILE);
------

-- This query is helpful for troubleshooting blocking and deadlocking issues

-- sys.dm_db_index_operational_stats (Transact-SQL)
-- https://bit.ly/3l5rGEw
