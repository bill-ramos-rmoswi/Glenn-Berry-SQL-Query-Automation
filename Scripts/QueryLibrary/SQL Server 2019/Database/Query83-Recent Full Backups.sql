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

-- Look at recent Full backups for the current database (Query 83) (Recent Full Backups)
SELECT TOP (30) bs.machine_name AS [Machine Name], bs.server_name AS [Server Name], 
bs.[database_name] AS [Database Name], bs.recovery_model AS [Recovery Model],
CONVERT (BIGINT, bs.backup_size / 1048576 ) AS [Uncompressed Backup Size (MB)],
CONVERT (BIGINT, bs.compressed_backup_size / 1048576 ) AS [Compressed Backup Size (MB)],
CONVERT (NUMERIC (20,2), (CONVERT (FLOAT, bs.backup_size) / CONVERT (FLOAT, bs.compressed_backup_size))) AS [Compression Ratio], 
bs.has_backup_checksums, bs.is_copy_only, bs.encryptor_type,
DATEDIFF (SECOND, bs.backup_start_date, bs.backup_finish_date) AS [Backup Elapsed Time (sec)],
bs.backup_finish_date AS [Backup Finish Date], bmf.physical_device_name AS [Backup Location], bmf.physical_block_size
FROM msdb.dbo.backupset AS bs WITH (NOLOCK)
INNER JOIN msdb.dbo.backupmediafamily AS bmf WITH (NOLOCK)
ON bs.media_set_id = bmf.media_set_id  
WHERE bs.database_name = DB_NAME(DB_ID())
AND bs.[type] = 'D' -- Change to L if you want Log backups
ORDER BY bs.backup_finish_date DESC OPTION (RECOMPILE);
------


-- Things to look at:
-- Are your backup sizes and times changing over time?
-- Are you using backup compression?
-- Are you using backup checksums?
-- Are you doing copy_only backups?
-- Are you doing encrypted backups?
-- Have you done any backup tuning with striped backups, or changing the parameters of the backup command?
-- Where are the backups going to?

-- In SQL Server 2016 and newer, native SQL Server backup compression actually works 
-- much better with databases that are using TDE than in previous versions
-- https://bit.ly/28Rpb2x


-- Microsoft Visual Studio Dev Essentials
-- https://bit.ly/2qjNRxi

-- Microsoft Azure Learn
-- https://bit.ly/2O0Hacc
