# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

This repository automates the execution and analysis of Glenn Berry's SQL Server Diagnostic Information Queries (see https://glennsqlperformance.com/resources/). It is in an early stage: the `Scripts/` directory (intended to hold the automation code) is currently empty, and the repo so far only contains the unmodified upstream diagnostic query source files.

## Repository Structure

- `SQL-Diag-Source-Files/` — Unmodified, version-specific `.sql` source files from Glenn Berry, one per SQL Server version (e.g. `SQL Server 2016 SP2 Diagnostic Information Queries.sql`, `SQL Server 2022 Diagnostic Information Queries.sql`). Treat these as vendored/third-party reference material — do not edit them; if a newer version is released upstream, add it as a new file rather than modifying an existing one.
- `Scripts/` — Intended home for the automation code that will execute these diagnostic queries and process results. Currently empty.

## Structure of the Diagnostic Query Files

Each source file follows a consistent convention worth knowing before writing automation against it:

- A version-check guard near the top compares `SERVERPROPERTY('ProductMajorVersion')` against the expected value for that file and raises an error if the script is run against the wrong SQL Server version.
- Individual diagnostic queries are delimited by a trailing comment on the query's own header line in the form `-- <description> (Query N) (<Short Name>)`, e.g. `-- Get selected server properties (Query 3) (Server Properties)`. Some queries also have an explicit `-- End of Query N ...` marker.
- Queries are grouped into two major sections, marked by comment banners:
  - `-- Instance level queries *******************************` — server/instance-scoped diagnostics.
  - `-- Database specific queries *****************************************************************` — requires switching to a user database (`USE <database>`) before running; queries after this marker are scoped per-database rather than per-instance.
- Any automation that parses or drives these files (e.g. splitting into individually executable queries, mapping results to names) should key off the `(Query N) (<Short Name>)` comment convention and the instance-vs-database section boundary, since both are consistent across the version-specific files.

## Prior Art

The README notes that [dbatools](https://dbatools.io/)'s `Invoke-DbaDiagnosticQuery` cmdlet is an existing community solution for running these queries in an automated fashion — useful reference when designing this repo's own automation approach.
