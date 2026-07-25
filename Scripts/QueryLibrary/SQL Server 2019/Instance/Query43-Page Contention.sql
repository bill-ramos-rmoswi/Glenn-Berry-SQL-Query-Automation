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

-- Show page level contention (Query 43) (Page Contention)
SELECT er.[session_id], er.wait_type, er.wait_resource, 
OBJECT_NAME(pinfo.[object_id], pinfo.database_id) AS [object_name], 
er.blocking_session_id, er.command,
          SUBSTRING(st.text, (er.statement_start_offset/2)+1,
          ((CASE er.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
              ELSE er.statement_end_offset
              END - er.statement_start_offset)/2) + 1) AS statement_text,
DB_NAME(pinfo.database_id) AS [Database Name], 
pinfo.[file_id], pinfo.page_id, pinfo.[object_id], pinfo.index_id, pinfo.page_type_desc
FROM sys.dm_exec_requests AS er WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) AS st
CROSS APPLY sys.fn_PageResCracker(er.page_resource) AS r
CROSS APPLY sys.dm_db_page_info(r.[db_id], r.[file_id], r.page_id, N'DETAILED') AS pinfo
WHERE  er.wait_type LIKE N'%page%' OPTION (RECOMPILE);
------

-- sys.fn_PageResCracker (Transact-SQL)
-- https://bit.ly/3sgwp9B
