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

-- Get number of data files in tempdb database (Query 25) (TempDB Data Files)
EXEC sys.xp_readerrorlog 0, 1, N'The tempdb database has';
------

-- Get the number of data files in the tempdb database
-- 4-8 data files that are all the same size is a good starting point
-- This query will return no results if your error log has been recycled since the instance was last started
