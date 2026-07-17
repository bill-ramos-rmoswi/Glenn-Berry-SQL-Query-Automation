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

-- New configuration options in SQL Server 2022 *********************************************************************************************************
-- ADR Cleaner Thread Count						Max number of threads ADR cleaner can assign
-- backup compression algorithm					Configure backup compression algorithm
-- Data processed daily limit in TB				SQL On-demand data processed daily limit in TB
-- Data processed monthly limit in TB			SQL On-demand data processed monthly limit in TB
-- Data processed weekly limit in TB			SQL On-demand data processed weekly limit in TB
-- hardware offload config						Offload processing to specialized hardware
-- max RPC request params (KB)					Maximum memory for RPC request parameters (kBytes) (added in CU13)
-- openrowset auto_create_statistics			Enable or disable auto create statistics for openrowset sources.
-- suppress recovery model errors				Return warning instead of error for unsupported ALTER DATABASE SET RECOVERY command
