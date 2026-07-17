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

-- Volume info for all LUNS that have database files on the current instance (Query 26) (Volume Info)
SELECT DISTINCT vs.volume_mount_point, vs.file_system_type, vs.logical_volume_name, 
CONVERT(DECIMAL(18,2), vs.total_bytes/1073741824.0) AS [Total Size (GB)],
CONVERT(DECIMAL(18,2), vs.available_bytes/1073741824.0) AS [Available Size (GB)],  
CONVERT(DECIMAL(18,2), vs.available_bytes * 1. / vs.total_bytes * 100.) AS [Space Free %],
vs.supports_compression, vs.is_compressed, 
vs.supports_sparse_files, vs.supports_alternate_streams
FROM sys.master_files AS f WITH (NOLOCK)
CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.[file_id]) AS vs 
ORDER BY vs.volume_mount_point OPTION (RECOMPILE);
------

-- Shows you the total and free space on the LUNs where you have database files
-- Being low on free space can negatively affect performance

-- sys.dm_os_volume_stats (Transact-SQL)
-- https://bit.ly/2oBPNNr
