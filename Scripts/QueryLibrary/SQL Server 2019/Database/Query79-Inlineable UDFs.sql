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

-- Determine which scalar UDFs are in-lineable (Query 79) (Inlineable UDFs)
SELECT OBJECT_NAME(m.[object_id]) AS [Function Name], m.is_inlineable, 
       m.inline_type, m.is_schema_bound, m.null_on_null_input,
       efs.total_worker_time, efs.execution_count, efs.cached_time
FROM sys.sql_modules AS m WITH (NOLOCK) 
LEFT OUTER JOIN sys.dm_exec_function_stats AS efs WITH (NOLOCK)
ON m.[object_id] = efs.[object_id]
WHERE efs.[type_desc] = N'SQL_SCALAR_FUNCTION'
ORDER BY efs.total_worker_time DESC OPTION (RECOMPILE);
------

-- Scalar UDF Inlining
-- https://bit.ly/2JU971M

-- sys.sql_modules (Transact-SQL)
-- https://bit.ly/2Qt216S
