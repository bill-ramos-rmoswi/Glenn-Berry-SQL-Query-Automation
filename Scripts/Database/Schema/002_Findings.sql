-- Drift-tracking table: one row per distinct (ServerName, DatabaseName, FindingType, ObjectName)
-- issue ever detected. A finding is "open" while ResolvedRunId IS NULL. Each import run's
-- Update-DiagnosticFindings (Scripts/Modules/DiagnosticFindings.psm1) re-runs every
-- Scripts/Analysis/*.sql rule and reconciles: new issues insert, still-present issues bump
-- LastDetectedRunId, previously-open issues no longer detected get ResolvedRunId set.
--
-- DatabaseName is NULL for instance-scope findings. SQL Server's default unique-index handling
-- treats every NULL as distinct, which would break de-duplication of instance-level findings, so
-- the natural key is a persisted computed column with DatabaseName coalesced to '' instead of a
-- multi-column unique constraint directly on the nullable column.

IF OBJECT_ID('dbo.Findings') IS NULL
BEGIN
    CREATE TABLE dbo.Findings
    (
        FindingId        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Findings PRIMARY KEY,
        ServerName        NVARCHAR(128)      NOT NULL,
        DatabaseName       NVARCHAR(128)      NULL,
        FindingType        NVARCHAR(64)       NOT NULL,
        ObjectName         NVARCHAR(256)      NOT NULL,
        Severity           NVARCHAR(16)       NOT NULL,
        Detail             NVARCHAR(4000)     NULL,
        FirstDetectedRunId INT                NOT NULL CONSTRAINT FK_Findings_FirstDetectedRun REFERENCES dbo.Runs(RunId),
        LastDetectedRunId  INT                NOT NULL CONSTRAINT FK_Findings_LastDetectedRun REFERENCES dbo.Runs(RunId),
        ResolvedRunId      INT                NULL     CONSTRAINT FK_Findings_ResolvedRun REFERENCES dbo.Runs(RunId),
        NaturalKey AS (ServerName + N'|' + ISNULL(DatabaseName, N'') + N'|' + FindingType + N'|' + ObjectName) PERSISTED
    );

    CREATE UNIQUE INDEX UQ_Findings_NaturalKey ON dbo.Findings(NaturalKey);
    CREATE INDEX IX_Findings_Open ON dbo.Findings(ServerName, Severity) WHERE ResolvedRunId IS NULL;
END
GO
