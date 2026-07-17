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

-- Get socket, physical core and logical core count from the SQL Server Error log (Query 2) (Core Counts)
-- This query might take a few seconds depending on the size of your error log
EXEC sys.xp_readerrorlog 0, 1, N'detected', N'socket';
------

-- This can help you determine the exact core counts used by SQL Server and whether HT is enabled or not
-- It can also help you confirm your SQL Server licensing model
-- Be on the lookout for this message "using 40 logical processors based on SQL Server licensing" 
-- (when you have more than 40 logical cores) which means grandfathered Server/CAL licensing
-- This query will return no results if your error log has been recycled since the instance was last started
