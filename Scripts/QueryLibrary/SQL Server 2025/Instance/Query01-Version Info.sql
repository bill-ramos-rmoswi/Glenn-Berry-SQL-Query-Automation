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

-- SQL and OS Version information for current instance  (Query 1) (Version Info)
SELECT @@SERVERNAME AS [Server Name], @@VERSION AS [SQL Server and OS Version Info];
------

-- @@SERVERNAME - Returns the name of the local server
-- @@VERSION - Returns a detailed string containing the SQL Server product version, the build number, the architecture (e.g., x64), and the operating system version/build information


-- SQL Server 2025 build versions
-- https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2025/build-versions

-- SQL Server 2025 Builds																		
-- Build			Description							Release Date	URL to KB Article
-- 17.0.1000.7		RTM									11/18/2025		https://learn.microsoft.com/en-us/sql/sql-server/sql-server-2025-release-notes
-- 17.0.1050.2		GDR									1/13/2026		https://support.microsoft.com/en-US/servicing/SQL/sql-server-2025/general-distribution-release/kb5073177-description-of-the-security-update-for-sql-server-2025-gdr-january-13-2026	
-- 17.0.4006.2		CU1									1/29/2026		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2025/cumulativeupdate1
-- 17.0.4015.4		CU2									2/12/2026		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2025/cumulativeupdate2
-- 17.0.4020.2		CU2 + GDR							3/10/2026		https://support.microsoft.com/en-US/servicing/SQL/sql-server-2025/cumulative-update/kb5077466-description-of-the-security-update-for-sql-server-2025-cu2-march-10-2026
-- 17.0.4025.3		CU3									3/12/2026		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2025/cumulativeupdate3
-- 17.0.4030.1		CU3 + GDR							4/14/2026		https://support.microsoft.com/en-US/servicing/SQL/sql-server-2025/cumulative-update/kb5083245-description-of-the-security-update-for-sql-server-2025-cu3-april-14-2026
-- 17.0.4035.5		CU4									4/16/2026		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2025/cumulativeupdate4
-- 17.0.4040.1		CU4 + GDR							5/12/2026		https://support.microsoft.com/en-US/servicing/SQL/sql-server-2025/cumulative-update/kb5089899-description-of-the-security-update-for-sql-server-2025-cu4-may-12-2026
-- 17.0.4045.5		CU5									5/20/2026		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2025/cumulativeupdate5
-- 17.0.4055.5		CU6									6/18/2026		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2025/cumulativeupdate6
-- 17.0.4060.2		CU6 + GDR							7/14/2026		https://support.microsoft.com/en-us/servicing/sql/sql-server-2025/general-distribution-release/kb5101346-july
-- 17.0.4065.4		CU7									7/16/2026		https://support.microsoft.com/en-us/servicing/sql/sql-server-2025/cumulative-update/kb5096981-cu7


-- SQL Server 2025 will fall out of Mainstream Support on Jan 6, 2031
-- SQL Server 2025 will fall out of Extended Support on Jan 6, 2036
-- https://learn.microsoft.com/en-us/lifecycle/products/sql-server-2025

-- How to determine the version, edition and update level of SQL Server and its components 
-- https://bit.ly/2oAjKgW	

-- Announcing the Modern Servicing Model for SQL Server
-- https://bit.ly/2KtJ8SS

-- Update Center for Microsoft SQL Server
-- https://bit.ly/2pZptuQ

-- Download SQL Server Management Studio (SSMS)
-- https://bit.ly/1OcupT9

-- SQL Server 2025 Configuration Manager is SQLServerManager17.msc

-- SQL Server troubleshooting (Microsoft documentation resources)
-- http://bit.ly/2YY0pb1
