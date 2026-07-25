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

-- Get SQL Server Agent jobs and Category information (Query 10) (SQL Server Agent Jobs)
SELECT sj.[name] AS [Job Name], sj.[description] AS [Job Description], 
sc.[name] AS [CategoryName], SUSER_SNAME(sj.owner_sid) AS [Job Owner],
sj.date_created AS [Date Created], sj.[enabled] AS [Job Enabled], h.run_status,
CONVERT(DATETIME, RTRIM(h.run_date) + ' ' + STUFF(STUFF(REPLACE(STR(RTRIM(h.run_time),6,0),' ','0'),3,0,':'),6,0,':')) AS [Last Start Date],
RIGHT(STUFF(STUFF(REPLACE(STR(h.run_duration, 7, 0), ' ', '0'), 4, 0, ':'), 7, 0, ':'),8) AS [Last Duration - HHMMSS],
s.[name] AS [Schedule Name], s.[enabled] AS [Schedule Enabled], js.next_run_date, js.next_run_time
FROM msdb.dbo.sysjobs AS sj WITH (NOLOCK)
LEFT OUTER JOIN
    (SELECT job_id, instance_id = MAX(instance_id)
     FROM msdb.dbo.sysjobhistory WITH (NOLOCK)
     GROUP BY job_id) AS l
ON sj.job_id = l.job_id
LEFT OUTER JOIN msdb.dbo.syscategories AS sc WITH (NOLOCK)
ON sj.category_id = sc.category_id
LEFT OUTER JOIN msdb.dbo.sysjobhistory AS h WITH (NOLOCK)
ON h.job_id = l.job_id
AND h.instance_id = l.instance_id
LEFT OUTER JOIN msdb.dbo.sysjobs_view AS jv WITH (NOLOCK)
ON jv.job_id = sj.job_id
LEFT OUTER JOIN msdb.dbo.sysjobschedules AS js WITH (NOLOCK)
ON jv.job_id = js.job_id
LEFT OUTER JOIN msdb.dbo.sysschedules AS s WITH (NOLOCK)
ON s.schedule_id = js.schedule_id
ORDER BY CONVERT(INT, h.run_duration) DESC, [Last Start Date] DESC OPTION (RECOMPILE);
------

-- run_status	
-- Value   Status of the job execution
-- 0 =     Failed
-- 1 =     Succeeded
-- 2 =     Retry
-- 3 =     Canceled
-- 4 =     In Progress


-- Gives you some basic information about your SQL Server Agent jobs, who owns them and how they are configured
-- Look for Agent jobs that are not owned by sa
-- Look for jobs that have a notify_email_operator_id set to 0 (meaning no operator)
-- Look for jobs that have a notify_level_email set to 0 (meaning no e-mail is ever sent)
--
-- MSDN sysjobs documentation
-- https://bit.ly/2paDEOP 

-- SQL Server Maintenance Solution (Ola Hallengren)
-- https://bit.ly/1pgchQu  

-- You can use this script to add default schedules to the standard Ola Hallengren Maintenance Solution jobs
-- https://bit.ly/3ane0gN
