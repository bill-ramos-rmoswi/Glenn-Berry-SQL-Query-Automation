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

-- Get Query Store Options for this database (Query 80) (Query Store Options)
SELECT actual_state_desc, desired_state_desc, [interval_length_minutes],
       current_storage_size_mb, [max_storage_size_mb], 
	   query_capture_mode_desc, size_based_cleanup_mode_desc, wait_stats_capture_mode_desc
FROM sys.database_query_store_options WITH (NOLOCK) OPTION (RECOMPILE);
------

-- New for SQL Server 2016
-- Requires that Query Store is enabled for this database

-- Make sure that the actual_state_desc is the same as desired_state_desc
-- Make sure that the current_storage_size_mb is less than the max_storage_size_mb

-- Tuning Workload Performance with Query Store
-- https://bit.ly/1kHSl7w

-- Emergency shutoff for Query Store (SQL Server 2019 CU6 or newer)
-- ALTER DATABASE [DatabaseName] SET QUERY_STORE = OFF(FORCED);
