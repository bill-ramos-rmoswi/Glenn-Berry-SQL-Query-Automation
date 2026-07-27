--******************************************************************************
--*   Custom query - not part of Glenn Berry's Diagnostic Information Queries.
--*   Added to this repo because no query in his source scripts enumerates
--*   server-level role membership (e.g. sysadmin).
--******************************************************************************

-- List all members of fixed server roles (Query 100) (Server Role Members)
SELECT r.[name] AS [Server Role],
       sp.[name] AS [LoginName],
       sp.[type_desc] AS [LoginType],
       sp.is_disabled,
       sp.create_date,
       sp.modify_date
FROM sys.server_role_members AS srm
JOIN sys.server_principals AS sp ON srm.member_principal_id = sp.principal_id
JOIN sys.server_principals AS r  ON srm.role_principal_id  = r.principal_id
WHERE r.[name] = 'sysadmin'
ORDER BY sp.[name] OPTION (RECOMPILE);
------

-- Things to look at:
-- How many logins are members of the sysadmin role? Fewer is better - each one is an
-- account that can do anything on the instance, including reading/altering any data.
-- Are any of the members individual named logins rather than a small number of
-- service accounts or an AD admin group? Named-login membership should be justified
-- and periodically reviewed.
-- Are any disabled logins still listed as sysadmin members? They should be removed,
-- not just disabled.

-- sys.server_role_members (Transact-SQL)
-- https://learn.microsoft.com/sql/relational-databases/system-catalog-views/sys-server-role-members-transact-sql
