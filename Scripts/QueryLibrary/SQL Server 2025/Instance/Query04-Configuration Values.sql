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

-- Get instance-level configuration values for instance  (Query 4) (Configuration Values)
SELECT [name], [value], value_in_use, minimum, maximum, [description], is_dynamic, is_advanced
FROM sys.configurations WITH (NOLOCK)
ORDER BY [name] OPTION (RECOMPILE);
------

-- Focus on these settings:
-- automatic soft-NUMA disabled (should be 0 in most cases)
-- backup checksum default (should be 1)
-- backup compression algorithm
-- backup compression default (should be 1 in most cases)
-- clr enabled (only enable if it is needed)
-- cost threshold for parallelism (depends on your workload)
-- lightweight pooling (should be zero)
-- max degree of parallelism (depends on your workload and hardware)
-- max server memory (MB) (set to an appropriate value, not the default)
-- optimize for ad hoc workloads (should be 1 in most cases)
-- priority boost (should be zero)
-- remote admin connections (should be 1)
-- tempdb metadata memory-optimized (0 by default, some workloads may benefit by enabling)

-- sys.configurations (Transact-SQL)
-- https://bit.ly/2HsyDZI

-- New configuration options in SQL Server 2025 *********************************************************************************************************
-- ADR cleaner lock timeout (s)					ADR cleaner lock timeout
-- allow server scoped db credentials			Enable or disable use of server managed identity in database scoped credentials
-- availability group commit time (ms)			Configure availability group commit time in milliseconds for SQL Server only.
-- external AI runtimes enabled					Enable or disable using external AI runtimes
-- external rest endpoint enabled				Enable or disable invocations of external REST endpoints
-- max lock manager cache memory (%)			Maximum size of lock manager cache memory as a percentage of the SQLOS committed memory (added in SQL Server 2025 CU5)
-- max server tiered memory (MB)				Maximum size of server tiered memory (MB)
-- max UCS send boxcars							Maximum number of UCS boxcars for sending messages.
-- SLOG memory quota (%)						SLOG memory quota percentage
-- tiered memory enabled						tiered memory memory-optimized is disabled by default.
