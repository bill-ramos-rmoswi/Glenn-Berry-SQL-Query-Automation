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

-- Get database scoped configuration values for current database (Query 57) (Database-scoped Configurations)
SELECT configuration_id, [name], [value] AS [value_for_primary], value_for_secondary, is_value_default
FROM sys.database_scoped_configurations WITH (NOLOCK) OPTION (RECOMPILE);
------

-- This lets you see the value of these new properties for the current database

-- Clear plan cache for current database
-- ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;

-- ALTER DATABASE SCOPED CONFIGURATION (Transact-SQL)
-- https://bit.ly/2sOH7nb

-- New in SQL Server 2022
-- PAUSED_RESUMABLE_INDEX_ABORT_DURATION_MINUTES
-- DW_COMPATIBILITY_LEVEL
-- EXEC_QUERY_STATS_FOR_SCALAR_FUNCTIONS
-- PARAMETER_SENSITIVE_PLAN_OPTIMIZATION
-- ASYNC_STATS_UPDATE_WAIT_AT_LOW_PRIORITY
-- CE_FEEDBACK
-- MEMORY_GRANT_FEEDBACK_PERSISTENCE
-- MEMORY_GRANT_FEEDBACK_PERCENTILE_GRANT
-- OPTIMIZED_PLAN_FORCING
-- DOP_FEEDBACK
-- LEDGER_DIGEST_STORAGE_ENDPOINT
-- FORCE_SHOWPLAN_RUNTIME_PARAMETER_COLLECTION
