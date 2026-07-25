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


-- SQL Server 2019 Builds																		
-- Build			Description							Release Date	URL to KB Article								
-- 15.0.1000.34		CTP 2.0								9/24/2018
-- 15.0.1100.94		CTP 2.1								11/7/2018
-- 15.0.1200.24		CTP 2.2								12/6/2018
-- 15.0.1300.359	CTP 2.3								3/1/2019
-- 15.0.1400.75		CTP 2.4								3/26/2019
-- 15.0.1500.28		CTP 2.5								4/23/2019
-- 15.0.1600.8		CTP 3.0								5/22/2019
-- 15.0.1700.37		CTP 3.1								6/26/2019
-- 15.0.1800.32		CTP 3.2								7/24/2019
-- 15.0.1900.25		RC1/RC1 Refresh						8/29/2019
-- 15.0.2000.5		RTM									11/4/2019
-- 15.0.2070.41		GDR1								11/4/2019		https://support.microsoft.com/en-us/help/4517790/servicing-update-for-sql-server-2019-rtm 
-- 15.0.4003.23		CU1									 1/7/2020		https://support.microsoft.com/en-us/help/4527376/cumulative-update-1-for-sql-server-2019
-- 15.0.4013.40		CU2									2/13/2020		https://support.microsoft.com/en-us/help/4536075/cumulative-update-2-for-sql-server-2019
-- 15.0.4023.6		CU3									3/12/2020		https://support.microsoft.com/en-us/help/4538853/cumulative-update-3-for-sql-server-2019
-- 15.0.4033.1		CU4									3/31/2020		https://support.microsoft.com/en-us/help/4548597/cumulative-update-4-for-sql-server-2019
-- 15.0.4043.16		CU5									6/22/2020		https://support.microsoft.com/en-us/help/4552255/cumulative-update-5-for-sql-server-2019
-- 15.0.4053.23		CU6									 8/4/2020		https://support.microsoft.com/en-us/help/4563110/cumulative-update-6-for-sql-server-2019
-- 15.0.4063.15		CU7									 9/2/2020		-- CU7 was removed by Microsoft
-- 15.0.4073.23		CU8									10/1/2020		https://support.microsoft.com/en-in/help/4577194/cumulative-update-8-for-sql-server-2019
-- 15.0.4083.2		CU8 Security Update				    1/12/2021		https://support.microsoft.com/en-us/help/4583459/kb4583459-security-update-for-sql-server-2019-cu8
-- 15.0.4102.2		CU9									2/11/2021		https://support.microsoft.com/en-in/help/5000642/cumulative-update-9-for-sql-server-2019
-- 15.0.4123.1		CU10								 4/6/2021       https://support.microsoft.com/en-us/topic/kb5001090-cumulative-update-10-for-sql-server-2019-b6b696ec-6598-48d9-80ee-f1b85d7a508b
-- 15.0.4138.2		CU11								6/10/2021		https://support.microsoft.com/en-us/topic/kb5003249-cumulative-update-11-for-sql-server-2019-657b2977-a0f1-4e1f-8b93-8c2ca8b6bef5
-- 15.0.4153.1		CU12								 8/4/2021		https://support.microsoft.com/en-us/topic/kb5004524-cumulative-update-12-for-sql-server-2019-45b2d82a-c7d0-4eb8-aa17-d4bad4059987
-- 15.0.4178.1		CU13								10/5/2021		https://support.microsoft.com/en-us/topic/kb5005679-cumulative-update-13-for-sql-server-2019-5c1be850-460a-4be4-a569-fe11f0adc535							
-- 15.0.4188.2		CU14							   11/22/2021		https://support.microsoft.com/sl-si/topic/kb5007182-cumulative-update-14-for-sql-server-2019-67b00a61-4f30-4a36-a5db-b506c47e563b
-- 15.0.4198.2		CU15								1/27/2022		https://support.microsoft.com/en-us/topic/kb5008996-cumulative-update-15-for-sql-server-2019-4b6a8ee9-1c61-482d-914f-36e429901fb6
-- 15.0.4223.1		CU16								4/18/2022		https://support.microsoft.com/en-us/topic/kb5011644-cumulative-update-16-for-sql-server-2019-74377be1-4340-4445-93a7-ff843d346896
-- 15.0.4236.7		CU16 Security Update				6/14/2022		https://support.microsoft.com/en-us/topic/kb5014353-description-of-the-security-update-for-sql-server-2019-cu16-june-14-2022-f0afe659-bd19-4c87-a417-a4c67a47e644
-- 15.0.4249.2		CU17								8/11/2022		https://support.microsoft.com/en-us/topic/kb5016394-cumulative-update-17-for-sql-server-2019-3033f654-b09d-41aa-8e49-e9d0c353c5f7
-- 15.0.4261.1		CU18								9/28/2022		https://support.microsoft.com/en-us/topic/kb5017593-cumulative-update-18-for-sql-server-2019-5fa00c36-edeb-446c-94e3-c4882b7526bc
-- 15.0.4280.7		CU18 GDR							2/14/2023		https://support.microsoft.com/en-us/topic/kb5021124-description-of-the-security-update-for-sql-server-2019-cu18-february-14-2023-cfb75a0a-33dc-4e05-8645-4cf16fcec049
-- 15.0.4298.1		CU19								2/16/2023		https://support.microsoft.com/en-us/topic/kb5023049-cumulative-update-19-for-sql-server-2019-b63d7163-e2e7-46f7-b50a-c3d1f2913219
-- 15.0.4312.2		CU20								4/13/2023		https://support.microsoft.com/en-us/topic/kb5024276-cumulative-update-20-for-sql-server-2019-4b282be9-b559-46ac-9b6a-badbd44785d2
-- 15.0.4316.3		CU21								6/15/2022		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/cumulativeupdate21
-- 15.0.4322.2		CU22								8/14/2023		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/cumulativeupdate22
-- 15.0.4326.1		CU22 + GDR							10/10/2023		https://support.microsoft.com/en-us/topic/kb5029378-description-of-the-security-update-for-sql-server-2019-cu22-october-10-2023-f4b5c5fb-b4cd-4599-8e5b-2a54dab85a33
-- 15.0.4335.1		CU23								10/12/2023		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/cumulativeupdate23		
-- 15.0.4345.5		CU24								12/14/2023		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/cumulativeupdate24	
-- 15.0.4355.3		CU25								2/15/2024		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/cumulativeupdate25
-- 15.0.4360.2		CU25 + GDR							4/9/2024		https://support.microsoft.com/en-us/topic/kb5036335-description-of-the-security-update-for-sql-server-2019-cu25-april-9-2024-eb3571d0-62ee-445e-9681-5715caf9bbc2
-- 15.0.4365.2		CU26								4/11/2024		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/cumulativeupdate26
-- 15.0.4375.4		CU27								6/13/2024		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/cumulativeupdate27
-- 15.0.4382.1		CU27 + GDR							7/9/2024		https://support.microsoft.com/en-us/topic/kb5040948-description-of-the-security-update-for-sql-server-2019-cu27-july-9-2024-6447dc00-9f1b-484c-9d3d-9e1f1b9f915c
-- 15.0.4385.2		CU28								8/1/2024		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/cumulativeupdate28
-- 15.0.4390.2		CU28 + GDR							9/10/2024		https://support.microsoft.com/en-us/topic/kb5042749-description-of-the-security-update-for-sql-server-2019-cu28-september-10-2024-17402ce5-07d3-4e30-9037-9ef997104f34
-- 15.0.4405.4		CU29								10/31/2024		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/cumulativeupdate29
-- 15.0.4410.1		CU29 + GDR							11/12/2024		https://support.microsoft.com/en-us/topic/kb5046860-description-of-the-security-update-for-sql-server-2019-cu29-november-12-2024-4bddde28-482c-4628-a6e2-2d4f542088b7
-- 15.0.4415.2		CU30								12/12/2024		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/cumulativeupdate30
-- 15.0.4420.2		CU31								2/13/2025		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/cumulativeupdate31
-- 15.0.4430.1      CU32                                2/27/2025       https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/cumulativeupdate32
-- 15.0.4435.7		CU32 + GDR							7-8-2025		https://support.microsoft.com/en-us/topic/kb5058722-description-of-the-security-update-for-sql-server-2019-cu32-july-8-2025-09dc5da9-3a60-4462-a8ac-a8e782d088d5
-- 15.0.4440.1		CU32 + GDR							8-12-2025	    https://support.microsoft.com/en-us/topic/kb5063757-description-of-the-security-update-for-sql-server-2019-cu32-august-12-2025-d4df46ef-6b1e-4a6c-aa8c-914d25f74345
-- 15.0.4445.1      CU32 + GDR							9-9-2025		https://support.microsoft.com/en-us/topic/kb5065222-description-of-the-security-update-for-sql-server-2019-cu32-september-9-2025-152ac456-cb04-4b88-8177-a77fe24ac80d
-- 15.0.4455.2		CU32 + GDR							11-11-2025		https://support.microsoft.com/en-us/topic/kb5068404-description-of-the-security-update-for-sql-server-2019-cu32-november-11-2025-c203bfbf-036e-46d2-bc10-6c01200dc48a
-- 15.0.4460.4		CU32 + GDR							3-10-2026		https://support.microsoft.com/en-us/topic/kb5077469-description-of-the-security-update-for-sql-server-2019-cu32-march-10-2026-5ec2c609-35cb-483d-aa80-5e66821e5c97
-- 15.0.4465.1		CU32 + GDR							4-14-2026		https://support.microsoft.com/en-us/topic/kb5084816-description-of-the-security-update-for-sql-server-2019-cu32-april-14-2026-b135e76b-1601-4477-9185-0520debd95a6
-- 15.0.4470.1		CU32 + GDR							5-12-2026		https://support.microsoft.com/en-us/topic/kb5090407-description-of-the-security-update-for-sql-server-2019-cu32-may-12-2026-3551e15f-b89c-4255-bb6a-97f745e642af
-- 15.0.4480.2      CU32 + GDR							7-14-2026		https://support.microsoft.com/en-us/servicing/sql/sql-server-2019/general-distribution-release/kb5102335-july


-- SQL Server 2019 fell out of Mainstream Support on Feb 28, 2025
-- SQL Server 2019 will fall out of Extended Support on Jan 8, 2030
-- https://learn.microsoft.com/en-us/lifecycle/products/sql-server-2019


-- How to determine the version, edition and update level of SQL Server and its components 
-- https://bit.ly/2oAjKgW	

-- SQL Server 2019 build versions
-- https://bit.ly/3EzGQZV

-- Performance and Stability Fixes in SQL Server 2019 CU Builds
-- https://bit.ly/3712NQQ

-- What's New in SQL Server 2019 (Database Engine)
-- https://bit.ly/2Q29fhz

-- What's New in SQL Server 2019
-- https://bit.ly/2PY442b

-- Announcing the Modern Servicing Model for SQL Server
-- https://bit.ly/2KtJ8SS

-- Update Center for Microsoft SQL Server
-- https://bit.ly/2pZptuQ

-- Download SQL Server Management Studio (SSMS)
-- https://bit.ly/1OcupT9

-- SQL Server 2019 Configuration Manager is SQLServerManager15.msc

-- SQL Server troubleshooting (Microsoft documentation resources)
-- http://bit.ly/2YY0pb1
