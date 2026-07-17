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

-- Hardware information from SQL Server 2016 SP2  (Query 17) (Hardware Info)
SELECT cpu_count AS [Logical CPU Count], scheduler_count, 
       (socket_count * cores_per_socket) AS [Physical Core Count], 
       socket_count AS [Socket Count], cores_per_socket, numa_node_count,
       physical_memory_kb/1024 AS [Physical Memory (MB)], 
       max_workers_count AS [Max Workers Count], 
	   affinity_type_desc AS [Affinity Type], 
       sqlserver_start_time AS [SQL Server Start Time],
	   DATEDIFF(hour, sqlserver_start_time, GETDATE()) AS [SQL Server Up Time (hrs)],
	   virtual_machine_type_desc AS [Virtual Machine Type], 
       softnuma_configuration_desc AS [Soft NUMA Configuration], 
	   sql_memory_model_desc
FROM sys.dm_os_sys_info WITH (NOLOCK) OPTION (RECOMPILE);
------

-- Gives you some good basic hardware information about your database server
-- Note: virtual_machine_type_desc of HYPERVISOR does not automatically mean you are running SQL Server inside of a VM
-- It merely indicates that you have a hypervisor running on your host

-- sys.dm_os_sys_info (Transact-SQL)
-- https://bit.ly/2pczOYs

-- Soft NUMA configuration was a new column for SQL Server 2016
-- OFF = Soft-NUMA feature is OFF
-- ON = SQL Server automatically determines the NUMA node sizes for Soft-NUMA
-- MANUAL = Manually configured soft-NUMA

-- Configure SQL Server to Use Soft-NUMA (SQL Server)
-- https://bit.ly/2HTpKJt

-- sql_memory_model_desc values (Added in SQL Server 2016 SP1)
-- CONVENTIONAL
-- LOCK_PAGES
-- LARGE_PAGES
