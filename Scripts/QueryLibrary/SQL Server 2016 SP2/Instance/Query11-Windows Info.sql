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

-- Windows information (Query 11) (Windows Info)
SELECT windows_release, windows_service_pack_level, 
       windows_sku, os_language_version
FROM sys.dm_os_windows_info WITH (NOLOCK) OPTION (RECOMPILE);
------

-- Gives you major OS version, Service Pack, Edition, and language info for the operating system
-- 10.0 is either Windows 10 or Windows Server 2016
-- 6.3 is either Windows 8.1 or Windows Server 2012 R2 
-- 6.2 is either Windows 8 or Windows Server 2012


-- Windows SKU codes
-- 4 is Enterprise Edition
-- 7 is Standard Server Edition
-- 8 is Datacenter Server Edition
-- 10 is Enterprise Server Edition
-- 48 is Professional Edition
-- 161 is Pro for Workstations

-- 1033 for os_language_version is US-English

-- SQL Server 2016 requires Windows Server 2012 or newer

-- Quick-Start Installation of SQL Server 2016
-- https://bit.ly/2qtxQ3G

-- Hardware and Software Requirements for Installing SQL Server 2016
-- https://bit.ly/2JJIUTl

-- Using SQL Server in Windows 8 and later versions of Windows operating system 
-- https://bit.ly/2F7Ax0P
