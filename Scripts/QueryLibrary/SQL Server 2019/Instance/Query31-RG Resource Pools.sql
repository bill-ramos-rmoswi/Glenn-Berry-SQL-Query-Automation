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

-- Resource Governor Resource Pool information (Query 31) (RG Resource Pools)
SELECT pool_id, [name], statistics_start_time,
       min_memory_percent, max_memory_percent,  
       max_memory_kb/1024 AS [max_memory_mb],  
       used_memory_kb/1024 AS [used_memory_mb],   
       target_memory_kb/1024 AS [target_memory_mb],
	   min_iops_per_volume, max_iops_per_volume
FROM sys.dm_resource_governor_resource_pools WITH (NOLOCK) OPTION (RECOMPILE);
------

-- sys.dm_resource_governor_resource_pools (Transact-SQL)
-- https://bit.ly/2MVU0Vy
