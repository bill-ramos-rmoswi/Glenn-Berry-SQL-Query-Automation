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

-- Host information (Query 11) (Host Info)
SELECT host_platform, host_distribution, host_release, 
       host_service_pack_level, host_sku, os_language_version
FROM sys.dm_os_host_info WITH (NOLOCK) OPTION (RECOMPILE); 
------

-- host_release codes (only valid for Windows)
-- 10.0 is either Windows 10, Windows Server 2016 or Windows Server 2019
-- 6.3 is either Windows 8.1 or Windows Server 2012 R2 
-- 6.2 is either Windows 8 or Windows Server 2012


-- host_sku codes (only valid for Windows)
-- 4 is Enterprise Edition
-- 7 is Standard Server Edition
-- 8 is Datacenter Server Edition
-- 10 is Enterprise Server Edition
-- 48 is Professional Edition
-- 161 is Pro for Workstations

-- 1033 for os_language_version is US-English

-- SQL Server 2017 requires Windows Server 2012 or newer

-- Hardware and Software Requirements for Installing SQL Server
-- https://bit.ly/2y3ka5L

-- Using SQL Server in Windows 8 and later versions of Windows operating system
-- https://bit.ly/2F7Ax0P 
