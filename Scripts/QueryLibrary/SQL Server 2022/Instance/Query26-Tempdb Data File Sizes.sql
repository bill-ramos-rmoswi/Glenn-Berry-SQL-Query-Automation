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

-- Find unequal tempdb data initial file sizes (Query 26) (Tempdb Data File Sizes)
-- This query might take a few seconds depending on the size of your error log
EXEC sys.xp_readerrorlog 0, 1, N'The tempdb database data files are not configured with the same initial size';
------

-- You want this query to return no results
-- All of your tempdb data files should have the same initial size and autogrowth settings 
-- This query will also return no results if your error log has been recycled since the instance was last started
-- KB3170020 - Informational messages added for tempdb configuration in the SQL Server error log in SQL Server 2012 and 2014
-- https://bit.ly/3IsR8jh
