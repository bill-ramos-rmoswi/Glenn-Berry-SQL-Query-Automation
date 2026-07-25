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


-- SQL Server 2017 Builds																		
-- Build			Description							Release Date	URL to KB Article								
-- 14.0.1000.169	RTM									10/2/2017
-- 14.0.3006.16		CU1									10/24/2017		https://support.microsoft.com/en-us/help/4038634
-- 14.0.3008.27		CU2									11/28/2017		https://support.microsoft.com/en-us/help/4052574
-- 14.0.3015.40		CU3									1/4/2018		https://support.microsoft.com/en-us/help/4052987
-- 14.0.3022.28		CU4									2/20/2018	    https://support.microsoft.com/en-us/help/4056498
-- 14.0.3023.8		CU5									3/20/2018		https://support.microsoft.com/en-us/help/4092643
-- 14.0.3025.34		CU6									4/17/2018	    https://support.microsoft.com/en-us/help/4101464
-- 14.0.3026.27		CU7									5/23/2018		https://support.microsoft.com/en-us/help/4229789
-- 14.0.3029.16		CU8									6/19/2018		https://support.microsoft.com/en-us/help/4338363
-- 14.0.3030.27		CU9									7/19/2018		https://support.microsoft.com/en-us/help/4341265
-- 14.0.3035.2		CU9 + Security Update				8/13/2018		https://www.microsoft.com/en-us/download/details.aspx?id=57263
-- 14.0.3037.1		CU10								8/27/2018		https://support.microsoft.com/en-us/help/4342123/cumulative-update-10-for-sql-server-2017
-- 14.0.3038.14		CU11								9/20/2018		https://support.microsoft.com/en-us/help/4462262	
-- 14.0.3045.24		CU12								10/23/2018		https://support.microsoft.com/en-us/help/4464082/cumulative-update-12-for-sql-server-2017
-- 14.0.3048.4		CU13								12/18/2018		https://support.microsoft.com/en-us/help/4466404/cumulative-update-13-for-sql-server-2017
-- 14.0.3076.1		CU14								3/25/2019		https://support.microsoft.com/en-us/help/4484710/cumulative-update-14-for-sql-server-2017	
-- 14.0.3103.1		CU14 + Security Update				5/14/2019		https://support.microsoft.com/en-us/help/4494352/security-update-for-sql-server-2017-cu-14-gdr-may-14-2019
-- 14.0.3162.1		CU15								5/23/2019		https://support.microsoft.com/en-us/help/4498951/cumulative-update-15-for-sql-server-2017
-- 14.0.3192.2		CU15 + Security Update				7/9/2019		https://support.microsoft.com/en-us/help/4505225/security-update-for-sql-server-2017-cu15-gdr-july-9-2019 
-- 14.0.3223.3		CU16								8/1/2019		https://support.microsoft.com/en-us/help/4508218/cumulative-update-16-for-sql-server-2017
-- 14.0.3238.1		CU17							    10/8/2019		https://support.microsoft.com/en-us/help/4515579/cumulative-update-17-for-sql-server-2017
-- 14.0.3257.3		CU18								12/9/2019		https://support.microsoft.com/en-us/help/4527377/cumulative-update-18-for-sql-server-2017
-- 14.0.3281.6		CU19								2/5/2020		https://support.microsoft.com/en-us/help/4535007/cumulative-update-19-for-sql-server-2017		
-- 14.0.3294.2		CU20								4/7/2020		https://support.microsoft.com/en-us/help/4541283/cumulative-update-20-for-sql-server-2017
-- 14.0.3335.7		CU21								7/1/2020		https://support.microsoft.com/en-us/help/4557397/cumulative-update-21-for-sql-server-2017
-- 14.0.3356.20		CU22								9/10/2020		https://support.microsoft.com/en-us/help/4577467/cumulative-update-22-for-sql-server-2017
-- 14.0.3370.1		CU22 + Security Update				1/12/2021		https://support.microsoft.com/en-us/help/4583457/kb4583457-security-update-for-sql-server-2017-cu22	
-- 14.0.3381.3		CU23								2/24/2021		https://support.microsoft.com/en-us/topic/kb5000685-cumulative-update-23-for-sql-server-2017-22b653c7-8487-4564-9db2-b5c1bd465145
-- 14.0.3391.2		CU24								5/10/2021		https://support.microsoft.com/en-us/topic/kb5001228-cumulative-update-24-for-sql-server-2017-fc49353e-cbb6-4862-9178-c319ce6f9db4															
-- 14.0.3401.7		CU25								7/12/2021		https://support.microsoft.com/en-us/topic/kb5003830-cumulative-update-25-for-sql-server-2017-357b80dc-43b5-447c-b544-7503eee189e9     
-- 14.0.3411.3		CU26								9/14/2021		https://support.microsoft.com/en-us/topic/kb5005226-cumulative-update-26-for-sql-server-2017-121ddf2b-d383-44dc-9a07-d0dd5de84977
-- 14.0.3421.10		CU27							   10/27/2021		https://support.microsoft.com/en-us/topic/kb5006944-cumulative-update-27-for-sql-server-2017-79117c8f-9d54-42f8-9727-5870fe475187
-- 14.0.3430.2		CU28							    1/13/2022		https://support.microsoft.com/en-us/topic/kb5008084-cumulative-update-28-for-sql-server-2017-b5c1f1ba-67d5-4313-87ad-087e6acde82a
-- 14.0.3436.1		CU29								3/30/2022		https://support.microsoft.com/en-us/topic/kb5010786-cumulative-update-29-for-sql-server-2017-8b3b4122-ed46-4d33-9d80-256c513ae42e
-- 14.0.3445.2		CU29 + GDR							6/14/2022		https://support.microsoft.com/en-us/topic/kb5014553-description-of-the-security-update-for-sql-server-2017-cu29-june-14-2022-024a90f1-1173-4ade-9c18-816ee7150458
-- 14.0 3451.2		CU30								7/14/2022		https://support.microsoft.com/en-us/topic/kb5013756-cumulative-update-30-for-sql-server-2017-274943fa-8dde-4844-90ed-d3b587fa0c7c
-- 14.0.3456.2		CU31								9/20/2022		https://support.microsoft.com/en-us/topic/kb5016884-cumulative-update-31-for-sql-server-2017-6aa612d0-c97e-4c54-a41f-37f53777ba4c
-- 14.0.3460.9		CU31 + GDR							2/14/2023		https://support.microsoft.com/en-us/topic/kb5021126-description-of-the-security-update-for-sql-server-2017-cu31-february-14-2023-2867280f-e66f-4598-a2f1-3d301e367683
-- 14.0.3465.1		CU31 + GDR						   10/10/2023		https://support.microsoft.com/en-us/topic/kb5029376-description-of-the-security-update-for-sql-server-2017-cu31-october-10-2023-ce23ddf7-b79e-4ba7-ba9d-2679f23a1ad8
-- 14.0.3471.2		CU31 + GDR							7/9/2024		https://support.microsoft.com/en-us/topic/kb5040940-description-of-the-security-update-for-sql-server-2017-cu31-july-9-2024-bff7ab26-e882-4419-aebb-30356125f5c9
-- 14.0.3475.1		CU31 + GDR							9/10/2024		https://support.microsoft.com/en-us/topic/kb5042215-description-of-the-security-update-for-sql-server-2017-cu31-september-10-2024-55bba26f-548d-466c-9c48-edfb51a53a8a
-- 14.0.3480.1		CU31 + GDR							10/8/2024		https://support.microsoft.com/en-us/topic/kb5046061-description-of-the-security-update-for-sql-server-2017-cu31-october-8-2024-af669e75-bc43-4679-bfbe-e153e679dd2f	
-- 14.0.3485.1		CU31 + GDR						   11/12/2024		https://support.microsoft.com/en-us/topic/kb5046858-description-of-the-security-update-for-sql-server-2017-cu31-november-12-2024-2984d3a5-0683-4f9b-9e6a-3888e67bd859
-- 14.0.3495.9		CU31 + GDR							7/8/20254		https://support.microsoft.com/en-us/topic/kb5058714-description-of-the-security-update-for-sql-server-2017-cu31-july-8-2025-cdc42d67-b4a1-4e6a-9f7a-11da1e733218
-- 14.0.3500.1		CU31 + GDR							8/12/2025		https://support.microsoft.com/en-us/topic/kb5063759-description-of-the-security-update-for-sql-server-2017-cu31-august-12-2025-7f5dfab6-e32b-4af3-87fe-0e527b5729d3
-- 14.0.3505.1		CU31 + GDR							9/9/2025		https://support.microsoft.com/en-us/topic/kb5065225-description-of-the-security-update-for-sql-server-2017-cu31-september-9-2025-b1addb22-3bfd-4870-b914-c020c2a3d2be	
-- 14.0.3515.1		CU31 + GDR						   11/11/2025		https://support.microsoft.com/en-us/topic/kb5068402-description-of-the-security-update-for-sql-server-2017-cu31-november-11-2025-1be08efe-ad14-4b95-a0de-ecbbf2703114
-- 14.0.3520.4		CU31 + GDR							3/10/2026		https://support.microsoft.com/en-us/topic/kb5077471-description-of-the-security-update-for-sql-server-2017-cu31-march-10-2026-f020d5eb-e356-42e8-a9ba-0ef061430b15
-- 14.0.3525.1		CU31 + GDR							4/14/2026		https://support.microsoft.com/en-us/topic/kb5084818-description-of-the-security-update-for-sql-server-2017-cu31-april-14-2026-0ddfecfe-673e-4f3e-8ffd-8dfeb66f97e4
-- 14.0.3530.2		CU31 + GDR							5/12/2026		https://support.microsoft.com/en-us/topic/kb5090354-description-of-the-security-update-for-sql-server-2017-cu31-may-12-2026-278c1395-f4e4-42d3-ba28-4b03067a9656
-- 14.0.3540.1		CU31 + GDR						    7/12/2026		https://support.microsoft.com/en-us/servicing/sql/sql-server-2017/general-distribution-release/kb5102337-july


-- SQL Server 2017 Azure Connect Pack builds
-- Azure Connect Feature Pack is optional and should be installed only if you intend to connect SQL Server with Azure SQL Managed Instance
-- 14.0.3490.10		Azure Connect Pack					3/6/2025		https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2017/azureconnect

-- SQL Server 2017 fell out of Mainstream Support on Oct 11, 2022
-- SQL Server 2017 will fall out of Extended Support on Oct 12, 2027
-- https://learn.microsoft.com/en-us/lifecycle/products/sql-server-2017


-- How to determine the version, edition and update level of SQL Server and its components 
-- https://bit.ly/2oAjKgW	

-- SQL Server 2017 build versions
-- https://bit.ly/2FLY88I

-- Recommended updates and configuration options for SQL Server 2017 and 2016 with high-performance workloads
-- https://bit.ly/2JsReue

-- Performance and Stability Fixes in SQL Server 2017 CU Builds
-- https://bit.ly/2GV3CNM

-- What's New in SQL Server 2017 (Database Engine)
-- https://bit.ly/2HjSeyQ

-- What's New in SQL Server 2017
-- https://bit.ly/2saQ4Yh

-- Announcing the Modern Servicing Model for SQL Server
-- https://bit.ly/2KtJ8SS

-- SQL Server Service Packs are discontinued starting from SQL Server 2017 
-- https://bit.ly/2GTkbgt 

-- Update Center for Microsoft SQL Server
-- https://bit.ly/2pZptuQ

-- Download SQL Server Management Studio (SSMS)
-- https://bit.ly/1OcupT9

-- SQL Server 2017 Configuration Manager is SQLServerManager14.msc

-- SQL Server troubleshooting (Microsoft documentation resources)
-- http://bit.ly/2YY0pb1
