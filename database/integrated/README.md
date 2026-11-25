# Integrated IMPC database — Group 6

This folder contains the SQL workflow, import inputs, example queries and validation checks for the integrated IMPC database. The backup and diagram reflect the supplied database export from 25 November 2026.

## Files

- `impc_group6_workflow.sql`: ordered build script with manual CSV import checkpoints.
- `impc_group6_collaborator_queries.sql`: allele-specific phenotype, disease, homology and LacZ queries.
- `impc_group6_restore_checks.sql`: read-only record-count, constraint and relationship checks.
- `inputs/`: prepared parameter descriptions, procedures and disease associations.
- `group6_query_genes.csv`: the five supplied gene symbols for query discovery.
- `../backups/impc_group6_final_backup.sql.gz`: compressed populated database backup.
- `../../docs/data_relationships/IMPC_ER_diagram_final.png`: current diagram, also supplied as PDF.
- `VALIDATION.md`: verification results and test limitations.

## Restore the populated database

1. Decompress `database/backups/impc_group6_final_backup.sql.gz` to an `.sql` file.
2. Create an empty MySQL database, for example `impc_group6`, and select it as the restore target. The dump does not create or select a database. Use a separate empty database if that name is already in use.
3. Restore the decompressed file with DBeaver's native MySQL restore function or a MySQL client. A command-line example, run from a terminal, is:

   ```sh
   mysql -u YOUR_USERNAME -p impc_group6 < impc_group6_final_backup.sql
   ```

4. Select the restored database and run `impc_group6_restore_checks.sql`. All row-count results should say `PASS`; all orphan counts should be zero.

The portable backup preserves the supplied export's tables, records and constraints. Server-specific GTID and binary-logging statements were removed. Views use `SQL SECURITY INVOKER`, so they use the caller's permissions instead of requiring the original `root@localhost` definer. Large INSERT statements are divided into smaller batches without changing any values. Restore only into an empty database: the dump contains DROP TABLE statements.

The packaged backup was executed successfully in a fresh MySQL 8.4.13 data directory using offline initialisation. A separate rebuild from the workflow and CSVs also passed. This tests the MySQL SQL execution and resulting data; the DBeaver restore interface and a normal network/client session were not tested. See `VALIDATION.md`.

## Rebuild from prepared CSVs

The workflow is a section-by-section build, with imports performed through DBeaver. It is not a one-click script. Use a new empty database and run each section/import once. Section 1 creates/selects `impc_group6`; change both database-name occurrences if using a different name.

Paths below are relative to the repository root. The three files under `database/integrated/inputs/` are included with this handover; the other six CSVs are already in the group repository.

| After section | Target table | CSV path |
|---|---|---|
| 2 | `clean_data_staging` | `data/processed/clean_group6_data/final_clean_data.csv` |
| 23, first | `parameter_groups` | `data/processed/parameter_group/parameter_group.csv` |
| 23, second | `parameter_group_membership` | `data/processed/parameter_group/parameter_group_member.csv` |
| 26 | `parameter_description_staging` | `database/integrated/inputs/parameter_description_import.csv` |
| 32 | `procedure_staging` | `database/integrated/inputs/procedure_import.csv` |
| 37 | `disease_staging` | `database/integrated/inputs/disease_import_ready.csv` |
| 43, first | `bespoke_species` | `data/processed/bespoke/bespoke_species.csv` |
| 43, second | `bespoke_gene` | `data/processed/bespoke/bespoke_gene.csv` |
| 43, third | `bespoke_homology` | `data/processed/bespoke/bespoke_homology.csv` |

Use UTF-8, comma delimiters, double-quote text quoting and the first row as the header. Map columns by name into the existing tables. For `final_clean_data.csv`, map the literal `NA` marker to SQL `NULL`, including numeric `p_value`. Preserve empty strings and whitespace in the other CSV imports to reproduce the supplied staging/bespoke tables exactly; the SQL trims metadata when populating the principal tables. Do not import `parameter_table.csv`: parameters are derived from the cleaned analysis data.

Procedure IDs use AUTO_INCREMENT, so their numeric values may differ after a fresh rebuild. The verified procedure names, attributes and parameter-to-procedure relationships remain equivalent; do not rely on hard-coded procedure IDs.

The metadata CSVs preserve the records from `IMPC_parameter_description.txt`, `IMPC_procedure.txt` and `Disease_information.txt`, respectively. The supplied disease file describes one-to-one human–mouse gene orthologues and disease-level mouse genotype associations.

## Schema and reference counts

There are 20 principal tables, four staging tables, three views and 21 foreign keys. The diagram displays the principal tables.

| Table | Records |
|---|---:|
| `analyses` | 27,983 |
| `lacz_results` | 307,813 |
| `human_gene_diseases` | 13,912 |
| `disease_genotypes` | 7,339 |
| `bespoke_homology` | 48,488 |

The final schema stores each disease–genotype pair once in `disease_genotypes`. Joining it to `human_gene_diseases` reconstructs the 138,055 previous human-gene–disease–genotype associations exactly. The obsolete `human_gene_disease_genotypes` table and the pipe-separated column in `human_gene_diseases` are absent. Original genotype strings remain in `disease_staging` for traceability.

## Interpretation and remaining group work

- The p-value CHECK constraint accepts 0–1 and permits SQL `NULL`. There are 267 missing p-values. The example queries use a nominal threshold of 0.05 without applying an additional multiple-testing correction.
- All 278 analyses with missing parameter IDs retain their parameter names through the fallback column and view.
- There are 16 parameter groups covering 690 of 1,784 distinct parameters. Metadata links cover 733 distinct parameters. Unmatched records are retained; missing metadata is not evidence that a procedure does not exist.
- Images is an exploratory group based on naming/measurement similarity, including morphology and body-composition measurements. Its members should not be described as exclusively image assays. Group definitions and biological interpretation require the group's justification.
- MGI–Ensembl matches use exact, case-sensitive mouse gene symbols and exclude ambiguous matches. They remain labelled `provisional`, rather than an authoritative identifier crosswalk.
- Procedure descriptions are retained in `procedure_staging`; the principal `procedures` table stores names and mandatory status. Some source procedure names have more than one description.
- LacZ counts refer to analysis–tissue records, not independent animals. Disease genotype IDs are disease-level model associations; they are not demonstrated matches to the selected experimental allele.
- The group still needs to confirm the four report genotypes and present their query results and Shiny plots. Five supplied gene symbols are a discovery list, not four confirmed genotypes.
- The cleaning contributor should retain evidence for manual repairs, including the nearest-SOP strain correction for `an1417460674`.

## Add to the repository

Extract the handover ZIP and merge its `database/` and `docs/` folders into the repository root, replacing the older files at those paths. Upload the extracted files; the repository ignores ZIP archives. This handover does not replace teammates' cleaning, grouping or Shiny work. Update older repository overview text that still describes database integration as pending.
