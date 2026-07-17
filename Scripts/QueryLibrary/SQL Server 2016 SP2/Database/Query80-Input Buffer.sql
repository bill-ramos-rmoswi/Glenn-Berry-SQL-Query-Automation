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

-- Get input buffer information for the current database (Query 80) (Input Buffer)
SELECT es.session_id, DB_NAME(es.database_id) AS [Database Name],
       es.[program_name], es.[host_name], es.login_name,
       es.login_time, es.cpu_time, es.logical_reads, es.memory_usage,
       es.[status], ib.event_info AS [Input Buffer]
FROM sys.dm_exec_sessions AS es WITH (NOLOCK)
CROSS APPLY sys.dm_exec_input_buffer(es.session_id, NULL) AS ib
WHERE es.database_id = DB_ID()
AND es.is_user_process = 1 OPTION (RECOMPILE);
------

-- Gives you input buffer information from all non-system sessions for the current database
-- Replaces DBCC INPUTBUFFER

-- New DMF for retrieving input buffer in SQL Server
-- https://bit.ly/2uHKMbz

-- sys.dm_exec_input_buffer (Transact-SQL)
-- https://bit.ly/2J5Hf9q
