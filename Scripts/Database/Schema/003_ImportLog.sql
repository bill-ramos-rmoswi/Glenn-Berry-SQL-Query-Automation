-- Per-file import audit trail. Lets Import-DiagnosticResultsFolder resume a Results\<timestamp>\
-- import without re-processing files already durably staged: before importing a file, check for
-- a Status='Success' row here for (RunId, RelativeFilePath) and skip if found. A retry's outcome
-- overwrites any prior row for the same key (see UQ_ImportLog_Run_File).

IF OBJECT_ID('dbo.ImportLog') IS NULL
BEGIN
    CREATE TABLE dbo.ImportLog
    (
        ImportLogId      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ImportLog PRIMARY KEY,
        RunId            INT                NOT NULL CONSTRAINT FK_ImportLog_Run REFERENCES dbo.Runs(RunId),
        RelativeFilePath NVARCHAR(400)       NOT NULL,
        TableName        NVARCHAR(128)       NOT NULL,
        [RowCount]       INT                 NULL,
        Status           NVARCHAR(16)        NOT NULL,
        ErrorMessage     NVARCHAR(4000)      NULL,
        ImportedAtUtc    DATETIME2(3)        NOT NULL CONSTRAINT DF_ImportLog_ImportedAtUtc DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_ImportLog_Run_File UNIQUE (RunId, RelativeFilePath)
    );
END
GO
