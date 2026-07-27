-- GlennBerrySQLDiag staging database: one row per imported Results\<timestamp>\ folder.
-- stg.* tables (auto-created by Import-DiagnosticResultsFolder / Write-SqlTableData) and
-- dbo.Findings both key off RunId to know which import a row/finding came from.

IF SCHEMA_ID('stg') IS NULL
    EXEC('CREATE SCHEMA stg');
GO

IF OBJECT_ID('dbo.Runs') IS NULL
BEGIN
    CREATE TABLE dbo.Runs
    (
        RunId          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Runs PRIMARY KEY,
        RunTimestamp   DATETIME2(0)       NOT NULL,
        RunFolderName  NVARCHAR(64)       NOT NULL,
        ImportedAtUtc  DATETIME2(3)       NOT NULL CONSTRAINT DF_Runs_ImportedAtUtc DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_Runs_RunFolderName UNIQUE (RunFolderName)
    );
END
GO
