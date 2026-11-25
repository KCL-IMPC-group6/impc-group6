# Integrated IMPC database — Group 6

The database combines cleaned IMPC analyses with parameter groups, procedure metadata, disease associations and bespoke homology data. It contains 24 tables (including four staging tables) and three views.

## Files

- `impc_group6_workflow.sql` — database build and checks.
- `impc_group6_collaborator_queries.sql` — phenotype, disease, homology and LacZ queries for a selected allele; `group6_query_genes.csv` lists the five supplied gene symbols.
- `impc_group6_restore_checks.sql` — checks after restoring or rebuilding.
- `inputs/` — prepared parameter, procedure and disease CSVs.
- `../backups/impc_group6_final_backup.sql.gz` — populated backup (25 November 2026).
- `../../docs/data_relationships/IMPC_ER_diagram_final.png` (also PDF) — principal table relationships.
- `VALIDATION.md` — test results, source details and limitations.

## Restore the database

1. Decompress the `.sql.gz` backup.
2. Create and select a new, empty MySQL database (e.g. `impc_group6`). The dump does not create a database and contains `DROP TABLE` statements.
3. Restore the `.sql` file using DBeaver's native MySQL restore function or the MySQL client:

   ```sh
   mysql -u YOUR_USERNAME -p impc_group6 < impc_group6_final_backup.sql
   ```

4. Select the restored database and run `impc_group6_restore_checks.sql`. Row counts should show `PASS` and orphan counts should be zero.

## Rebuild from CSVs

Alternatively, run the workflow section by section in DBeaver on an empty database. If changing the database name, change both occurrences in Section 1. Run each import and INSERT only once.

Paths are relative to the repository root. The three `inputs/` CSVs are included here; the other six must be available in the group repository.

| Import point | Existing target table | CSV path |
|---|---|---|
| After Section 2 | `clean_data_staging` | `data/processed/clean_group6_data/final_clean_data.csv` |
| After Section 23 (1) | `parameter_groups` | `data/processed/parameter_group/parameter_group.csv` |
| After Section 23 (2) | `parameter_group_membership` | `data/processed/parameter_group/parameter_group_member.csv` |
| Section 26, before checks | `parameter_description_staging` | `database/integrated/inputs/parameter_description_import.csv` |
| After Section 32 | `procedure_staging` | `database/integrated/inputs/procedure_import.csv` |
| After Section 37 | `disease_staging` | `database/integrated/inputs/disease_import_ready.csv` |
| Section 44 (1) | `bespoke_species` | `data/processed/bespoke/bespoke_species.csv` |
| Section 44 (2) | `bespoke_gene` | `data/processed/bespoke/bespoke_gene.csv` |
| Section 44 (3) | `bespoke_homology` | `data/processed/bespoke/bespoke_homology.csv` |

Use UTF-8, comma delimiters, double-quote text quoting and the first row as headers. Map columns by name. Set the null-value marker to `NA` for `final_clean_data.csv` so missing values (including numeric p-values) become SQL `NULL`. Preserve empty strings and whitespace in the other imports. Do not import `parameter_table.csv`; the parameters are already created from the cleaned data.

Run the restore checks after rebuilding. Procedure IDs are generated automatically and may differ between builds; use procedure names or the existing relationships rather than hard-coded IDs.

## Notes and limitations

- The database retains 27,983 analyses, including 267 missing p-values and 278 missing parameter IDs (their names are retained). The queries use nominal p < 0.05 without further multiple-testing correction.
- There are 16 parameter groups covering 690 of 1,784 parameters; 733 parameters link to metadata. Unmatched records are retained. Images includes morphology and body-composition measurements as well as imaging.
- MGI–Ensembl links are provisional, based on exact case-sensitive gene symbols. Disease genotype IDs are disease-model associations, not confirmed experimental alleles.
- LacZ counts refer to analysis–tissue records, not individual mice. Procedure descriptions remain in staging.

See `VALIDATION.md` for the recorded database validation results and testing limitations.
