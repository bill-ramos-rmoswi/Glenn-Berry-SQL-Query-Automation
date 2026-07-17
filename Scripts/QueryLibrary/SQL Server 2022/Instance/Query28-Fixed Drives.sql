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

-- Drive information for all fixed drives visible to the operating system (Query 28) (Fixed Drives)
SELECT fixed_drive_path, drive_type_desc, 
CONVERT(DECIMAL(18,2), free_space_in_bytes/1073741824.0) AS [Available Space (GB)]
FROM sys.dm_os_enumerate_fixed_drives WITH (NOLOCK) OPTION (RECOMPILE);
------

-- This shows all of your drives, not just LUNs with SQL Server database files
-- New in SQL Server 2017

-- sys.dm_os_enumerate_fixed_drives (Transact-SQL)
-- https://bit.ly/2EZoHLj
