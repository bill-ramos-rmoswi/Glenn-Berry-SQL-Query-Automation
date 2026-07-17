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

-- Get detailed accelerator status information (Query 9) (Accelerator Status)
SELECT accelerator, accelerator_desc, config, config_in_use , mode, mode_desc, 
       mode_reason, mode_reason_desc, accelerator_hardware_detected, 
	   accelerator_library_version, accelerator_driver_version
FROM sys.dm_server_accelerator_status WITH (NOLOCK) OPTION (RECOMPILE);
------

-- This shows which accelerators are present and their detailed status information

-- sys.dm_server_accelerator_status (Transact-SQL)
-- https://bit.ly/3B6Fczw

-- How to Enable Intel QAT Backup Compression in SQL Server 2022
-- https://bit.ly/3Cudwpy
