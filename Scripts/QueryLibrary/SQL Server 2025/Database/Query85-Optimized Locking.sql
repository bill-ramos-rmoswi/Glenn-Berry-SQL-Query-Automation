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

-- Is Optimized Locking enabled for the current database? (Query 85) (Optimized Locking)
SELECT DATABASEPROPERTYEX(DB_NAME(), 'IsOptimizedLockingOn') AS [Is Optimized Locking On];
------ 

-- Result		Description
-- 0			Optimized locking is disabled
-- 1			Optimized locking is enabled
-- NULL			Optimized locking is not available

-- Optimized locking
-- https://learn.microsoft.com/en-us/sql/relational-databases/performance/optimized-locking?view=azuresqldb-current
