# SQL handover verification — 25 November 2026

## Inputs reviewed

- Supplied current export: `impc_group6_bacup(3).sql`.
- Supplied working history: `-- IMPC Group 6 database.txt`.
- Supplied current diagram: `final diagram(1).png`.
- Prior handover: `Group6_SQL_25Nov_GITHUB_HANDOVER.zip`, including its three metadata CSVs.
- Project cleaned data and the repository prepared inputs at commit `b77eee40ea744c1d04b0492b86db98cd1def9e32` in `KCL-IMPC-group6/impc-group6`.

## Checks completed

| Check | Result |
|---|---|
| All 27,983 cleaned analyses compared with staging | No value differences or missing analysis IDs |
| Analyses, genes and parameter-name reconstruction | No differences from staging |
| LacZ data | 307,813 matching results; 11 tissues per analysis |
| Missing p-values / parameter IDs | 267 / 278, preserved correctly |
| P-value range | No values outside 0–1 |
| Source metadata CSVs compared with current staging | All 5,325 parameter-description, 5,311 procedure and 13,912 disease records match |
| New disease–genotype table | Exactly 7,339 distinct source pairs |
| Reconstruction of previous gene–disease–genotype records | All 138,055 associations reconstructed, with zero missing or additional associations |
| Other 23 base tables compared with the previously reviewed backup | No changes to their records |
| Foreign keys | Zero orphan records across all 21 relationships |
| Primary keys, unique constraints and value CHECKs | Pass on independently loaded records |
| Current ER diagram | Principal tables and relationships agree with the new export |

The previous review also compared all 48,488 distinct bespoke homology pairs directly with the supplied source file. The new backup's bespoke tables are unchanged.

## MySQL execution tests

Both tests used actual MySQL Community Server 8.4.13 (binary update 8.4.13.1) in separate fresh data directories. Network and Unix-domain sockets are unavailable in the checking environment, so SQL was executed through `mysqld --initialize-insecure --init-file`. This is an offline engine execution test, not a DBeaver UI or normal client-session test.

1. **Backup restore:** the packaged SQL was executed with an empty database selected. All 24 base-table row counts and the three-view count passed SQL assertions. Every table was then exported from MySQL and compared with the original uploaded backup's decoded records: zero differences, including multiplicities.
2. **Workflow rebuild:** all 129 workflow statements executed in order. The nine prepared CSVs were inserted at the same checkpoints specified for manual DBeaver imports, preserving whitespace/empty strings and mapping literal `NA` to SQL NULL. The shipped restore-check queries and collaborator-query file also executed without SQL errors. The query file was exercised for each of the five supplied genes' non-missing allele symbols.
3. **Rebuild equivalence:** 22 base tables match the uploaded backup directly. The other two, `procedures` and `parameter_metadata`, differ only in generated procedure IDs. All 51 procedures, their attributes and all 5,311 parameter-metadata records match after resolving those IDs to procedure names. All rebuilt foreign-key references are valid.

The manual DBeaver import interface, local MySQL 9.7.2 runtime, connection permissions and Shiny application were not tested. The published import settings and read-only restore checks support checking those local steps. The workflow still needs the documented CSV imports; the test's automatic CSV inserts are a checking mechanism, not part of the user-facing build script.

## Packaging changes

- Replaced the old backup with the supplied 25 November database state.
- Replaced both diagram formats with the supplied current diagram.
- Consolidated the working SQL into build order. Removed the orphaned foreign-key fragment and superseded intermediate disease-genotype migrations. The workflow directly creates the final `disease_genotypes` table.
- Retained the p-value CHECK in the initial table definition and used invoker security consistently for views.
- Preserved all source records and table constraints while removing server-specific GTID/binary-log commands and original view definers from the portable dump. Split large INSERT statements into smaller batches without changing their values.
- Included the three missing metadata input CSVs, corrected the import paths and updated all counts/table references.
- Fixed the ambiguous constraint-name selection in the old restore-check script and added checks for every table count and every foreign-key relationship.

## Scope

This verifies the SQL handover. It does not select the four final report genotypes, establish authoritative MGI–Ensembl mappings, validate the scientific membership of every parameter group, or complete the individual report/Shiny deliverables. These limitations are described in the README.
