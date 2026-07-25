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

-- Returns a list of all global trace flags that are enabled (Query 5) (Global Trace Flags)
DBCC TRACESTATUS (-1);
------

-- If no global trace flags are enabled, no results will be returned.
-- It is very useful to know what global trace flags are currently enabled as part of the diagnostic process.

-- Common trace flags that should be enabled in most cases
-- TF 460  - Improvement: Optional replacement for "String or binary data would be truncated" message with extended information in SQL Server 2017
--           https://bit.ly/2sboMli (added in CU12)

-- TF 3226 - Suppresses logging of successful database backup messages to the SQL Server Error Log
--           https://bit.ly/38zDNAK  

-- TF 6534 - Enables use of native code to improve performance with spatial data
--           https://bit.ly/2HrQUpU         

-- TF 7745 - Prevents Query Store data from being written to disk in case of a failover or shutdown command
--           https://bit.ly/2GU69Km

-- TF 7752 - Enables asynchronous load of Query Store 
--           This allows a database to become online and queries to be executed before the Query Store has been fully recovered 
 

-- The behavior of TF 1117, 1118 are enabled for tempdb in SQL Server 2016 by default
-- SQL 2016 – It Just Runs Faster: -T1117 and -T1118 changes for TEMPDB and user databases
-- https://bit.ly/2lbNWxK           

-- The behavior of TF 2371 is enabled by default in SQL Server 2016 and newer (in compat level 130 and higher)

-- DBCC TRACEON - Trace Flags (Transact-SQL)
-- https://bit.ly/2FuSvPg

-- Recommended updates and configuration options for SQL Server 2017 and 2016 with high-performance workloads
-- https://bit.ly/2VVRGTY
