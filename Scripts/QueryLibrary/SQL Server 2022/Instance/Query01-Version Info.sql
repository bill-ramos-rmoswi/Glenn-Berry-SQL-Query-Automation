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

-- Server name, SQL Server and OS Version information for the current instance  (Query 1) (Version Info)
SELECT @@SERVERNAME AS [Server Name], @@VERSION AS [SQL Server and OS Version Info];
------

-- @@SERVERNAME - Returns the name of the local server
-- @@VERSION - Returns a detailed string containing the SQL Server product version, the build number, the architecture (e.g., x64), and the operating system version/build information


-- SQL Server 2022 build versions
-- https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/build-versions

-- SQL Server 2022 Builds																		
-- Build			Description							Release Date	URL to KB Article
-- 16.0.1000.6		RTM									11/16/2022		https://learn.microsoft.com/en-us/sql/sql-server/sql-server-2022-release-notes?view=sql-server-ver17
-- 16.0.1050.5		RTM GDR								2/14/2023		https://support.microsoft.com/en-us/topic/kb5021522-description-of-the-security-update-for-sql-server-2022-gdr-february-14-2023-7a5a84ed-e99c-4537-b064-fa4499549c8e
-- 16.0.4003.1		CU1									2/16/2023		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate1
-- 16.0.4015.1		CU2									3/15/2023		https://learn.microsoft.com/en-US/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate2
-- 16.0.4025.1		CU3									4/13/2023		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate3
-- 16.0.4035.4		CU4									5/11/2023		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate4
-- 16.0.4045.3		CU5									6/15/2023		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate5
-- 16.0.4055.4		CU6									7/13/2023		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate6
-- 16.0.4065.3		CU7									8/10/2023		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate7	
-- 16.0.4075.1		CU8									9/14/2023		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate8
-- 16.0.4080.1		CU8 + GDR							10/10/2023		https://support.microsoft.com/en-us/topic/kb5029503-description-of-the-security-update-for-sql-server-2022-cu8-october-10-2023-c9c267e2-adb6-47f1-b7e9-d99d3c9fb081
-- 16.0.4085.2		CU9									10/12/2023		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate9
-- 16.0.4095.4		CU10								11/16/2023		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate10	
-- 16.0.4100.1		CU10 + GDR							 1/9/2024		https://support.microsoft.com/en-us/topic/kb5033592-description-of-the-security-update-for-sql-server-2022-cu10-january-9-2024-0d807f8e-fa6a-4d42-88d3-71b101e71d18
-- 16.0.4105.2		CU11								1/11/2024		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate11
-- 16.0.4115.5		CU12								3/14/2024		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate12
-- 16.0.4120.1		CU12 + GDR							 4/9/2024		https://support.microsoft.com/en-us/topic/kb5036343-description-of-the-security-update-for-sql-server-2022-cu12-april-9-2024-e11a0715-435f-42be-89ff-4b3d8f9734fc
-- 16.0.4125.3		CU13								5/16/2024		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate13
-- 16.0.4131.2		CU13 + GDR							7/9/2024		https://support.microsoft.com/en-us/topic/kb5040939-description-of-the-security-update-for-sql-server-2022-cu13-july-9-2024-16a61a81-926c-46a5-b6c0-edbca541f2f6
-- 16.0.4135.4		CU14								7/23/2024		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate14
-- 16.0.4140.3		CU14 + GDR							9/10/2024		https://support.microsoft.com/en-us/topic/kb5042578-description-of-the-security-update-for-sql-server-2022-cu14-september-10-2024-560e6e4c-1f49-4c18-9eb7-054e9fdee3c7	
-- 16.0.4145.4		CU15								9/25/2024		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate15	
-- 16.0.4150.1		CU15 + GDR							10/8/2024		https://support.microsoft.com/en-us/topic/kb5046059-description-of-the-security-update-for-sql-server-2022-cu15-october-8-2024-b592d86f-3351-4f9f-9c80-ef495a0137c1
-- 16.0.4155.4		CU15 + GDR							11/12/2024		https://support.microsoft.com/en-us/topic/kb5046862-description-of-the-security-update-for-sql-server-2022-cu15-november-12-2024-ab9f3a55-8264-44e9-9a40-0b32bcd83df0				
-- 16.0.4165.4		CU16								11/14/2024		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate16
-- 16.0.4175.1		CU17								1/16/2025		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate17
-- 16.0.4185.3		CU18								3/13/2025		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate18
-- 16.0.4195.2		CU19								5/15/2025		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate19
-- 16.0.4200.1		CU19 + GDR							7/8/2025		https://support.microsoft.com/en-us/topic/kb5058721-description-of-the-security-update-for-sql-server-2022-cu19-july-8-2025-fcf14446-c16b-46b1-a096-f1b775dd45be
-- 16.0.4205.1		CU20								7/10/2025		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate20
-- 16.0.4210.1		CU20 + GDR							8/12/2025		https://support.microsoft.com/en-us/topic/kb5063814-description-of-the-security-update-for-sql-server-2022-cu20-august-12-2025-8744624f-a95c-4902-a191-5a25079d7f37
-- 16.0.4212.1		CU20 + GDR							9/9/2025		https://support.microsoft.com/en-us/topic/kb5065220-description-of-the-security-update-for-sql-server-2022-cu20-september-9-2025-e58e6d66-717c-4e33-adc1-4a89d3dd71f5
-- 16.0.4215.2		CU21								9/11/2025		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate21
-- 16.0.4222.2		CU21 + GDR							11/11/2025		https://support.microsoft.com/en-us/topic/kb5068406-description-of-the-security-update-for-sql-server-2022-cu21-november-11-2025-7403d389-606b-4176-a1d5-b0960fb7dc50
-- 16.0.4225.2		CU22								11/13/2025		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate22
-- 16.0.4230.2		CU22 + GDR							1/13/2026		https://support.microsoft.com/en-gb/topic/kb5072936-description-of-the-security-update-for-sql-server-2022-cu22-january-13-2026-c483559a-57d8-4c72-a010-5792bb668dc8
-- 16.0.4236.2		CU23								1/29/2026		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate23
-- 16.0.4240.4		CU23 + GDR							3/10/2026		https://support.microsoft.com/en-us/topic/kb5077464-description-of-the-security-update-for-sql-server-2022-cu23-march-10-2026-b57d8bd7-e9f5-48a8-8a6f-2a52d3ad29f0
-- 16.0.4245.2		CU24								3/12/2026		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate24
-- 16.0.4250.1		CU24 + GDR							4/14/2026		https://support.microsoft.com/en-us/topic/kb5083252-description-of-the-security-update-for-sql-server-2022-cu24-april-14-2026-0c8d572b-de26-4592-9ddc-09270c2a303c
-- 16.0.4252.3		CU24 + GDR							5/12/2026		https://support.microsoft.com/en-us/topic/kb5089900-description-of-the-security-update-for-sql-server-2022-cu24-may-12-2026-695c0545-c0d1-4341-bb92-2f1037fe09b2
-- 16.0.4255.1		CU25								5/20/2026		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/cumulativeupdate25
-- 16.0.4262.2		CU25 + GDR							7/14/2026		https://support.microsoft.com/en-us/servicing/sql/sql-server-2022/general-distribution-release/kb5101347-july
-- 16.0.4265.3		CU26								7/16/2026		https://support.microsoft.com/en-us/servicing/sql/sql-server-2022/cumulative-update/kb5093420-cu26


-- SQL Server 2022 will fall out of Mainstream Support on Jan 11, 2028
-- SQL Server 2022 will fall out of Extended Support on Jan 11, 2033
-- https://learn.microsoft.com/en-us/lifecycle/products/sql-server-2022

-- What's new in SQL Server 2022 (16.x)
-- https://bit.ly/3MJEjR1

-- How to determine the version, edition and update level of SQL Server and its components 
-- https://bit.ly/2oAjKgW	

-- Announcing the Modern Servicing Model for SQL Server
-- https://bit.ly/2KtJ8SS

-- Update Center for Microsoft SQL Server
-- https://bit.ly/2pZptuQ

-- Download SQL Server Management Studio (SSMS)
-- https://bit.ly/1OcupT9

-- SQL Server 2022 Configuration Manager is SQLServerManager16.msc

-- SQL Server troubleshooting (Microsoft documentation resources)
-- http://bit.ly/2YY0pb1
