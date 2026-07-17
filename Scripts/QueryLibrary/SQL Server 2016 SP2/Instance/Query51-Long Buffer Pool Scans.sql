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

-- Look for long duration buffer pool scans (Query 51) (Long Buffer Pool Scans)
EXEC sys.xp_readerrorlog 0, 1, N'Buffer pool scan took';
------

-- Finds buffer pool scans that took more than 10 seconds in the current SQL Server Error log
-- Only in SQL Server 2016 SP3 and later

-- Operations that trigger buffer pool scan may run slowly on large-memory computers - SQL Server | Microsoft Docs
-- https://bit.ly/3QrFC81




-- **** Please switch to a user database that you are interested in! *****
--USE YourDatabaseName; -- make sure to change to an actual database on your instance, not the master system database
--GO
