# Database validation — Group 6

The database was checked against the cleaned analysis data, the supplied parameter, procedure, disease and homology files, and the previous database export. The results below are recorded from the database validation work.

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

The earlier source-data checks also compared all 48,488 distinct bespoke homology pairs directly with the supplied source file. The new backup's bespoke tables are unchanged.

## Restore and rebuild tests

- The populated backup was restored to an empty MySQL database. The recorded checks passed for all 24 base-table row counts and three views. Table records were compared with the original export, with no differences.
- The workflow was run in order with the nine CSV imports at the documented checkpoints, including conversion of `NA` to SQL `NULL` for the cleaned analysis data. The restore checks and collaborator queries ran without SQL errors. The collaborator queries were tested for the available alleles of the five supplied genes.
- The rebuilt database matched 22 tables directly. The other two (`procedures` and `parameter_metadata`) matched after resolving automatically generated procedure IDs to procedure names. This accounted for all 51 procedures and 5,311 parameter-metadata records. The rebuilt foreign-key relationships were valid.

These are the previously recorded MySQL execution results, not a new test of the documentation revision. The exact server version and execution setup are not independently verified here. The DBeaver import interface, local MySQL runtime, connection permissions and Shiny application were not covered by those engine tests.

## Repeating the checks

Restore the backup or rebuild the database using the README, then run `impc_group6_restore_checks.sql`. The table-count checks should return `PASS` and all orphan counts should be zero. The workflow also contains checks for missing values, the p-value range, LacZ tissue records and parameter-group memberships.

## Notes on the final database

- The database contains 20 principal tables, four staging tables, three views and 21 foreign keys. It includes 13,912 human gene–disease associations and 7,339 disease–genotype pairs.
- The portable backup preserves the data and constraints. Server-specific GTID and binary-log commands were removed, views use `SQL SECURITY INVOKER`, and large INSERT statements were split into smaller batches without changing their values.
- The final workflow creates `disease_genotypes` directly instead of using the superseded intermediate table. Original genotype strings remain in `disease_staging`. The three prepared metadata CSVs retain the source records.
- The database checks do not establish the biological accuracy of every parameter group or provide an authoritative MGI–Ensembl cross-reference. Some procedure descriptions are retained in staging. See the README for interpretation limitations.
- The five supplied gene symbols are a discovery list; the four report genotypes and Shiny plots are separate group tasks. The cleaning log should retain evidence for manual repairs, including the strain correction for `an1417460674`.

The executable workflow, backup, input CSVs, collaborator queries and restore checks are unchanged from the preceding handover. The ER diagram uses the original DBeaver image in PNG and PDF format.
