# Bespoke homology task

This part links mouse genes to their human and drill orthologs.
It includes data cleaning, CSV exports and a MySQL database schema.

## Cleaning rules

- Remove leading and trailing whitespace.
- Keep records with a mouse Ensembl ID and at least one human or drill gene ID.
- Keep eligible records even when gene names are missing.
- Split human and drill matches into separate records.
- Remove identical repeated mouse–target gene pairs.
- Check column counts, Ensembl ID formats, homology types and identity percentages.
- Stop the export if conflicting records or invalid fields are found.

### Cleaning results

| Stage | Records |
| --- | ---: |
| Original rows | 115,100 |
| Eligible rows | 57,661 |
| Pairs after splitting by target species | 112,371 |
| Repeated identical pairs removed | 63,883 |
| Final unique pairs | 48,488 |

The detailed summary is saved in
`data/processed/bespoke/cleaning_summary.json`.

## Execution order

Run the Python commands from the repository root.
Both scripts use Python's standard library.

### 1. Clean the original data

The input file is `bespokeTask_hml.txt`.
The current script expects it at `../data/bespokeTask_hml.txt`,
relative to the repository root. Update `input_path` if needed.

```bash
python3 bespoke/inspect_homology.py
```

This creates `homology_clean.csv` and `cleaning_summary.json`
in `data/processed/bespoke/`.

### 2. Export the database tables

```bash
python3 bespoke/export_tables.py
```

This creates three CSV files in the same output folder:

| File | Contents | Rows |
| --- | --- | ---: |
| bespoke_species.csv | Species IDs and names | 3 |
| bespoke_gene.csv | Ensembl gene IDs, gene names and species IDs | 59,101 |
| bespoke_homology.csv | Mouse–target gene pairs, ancestors, homology types and identity percentages | 48,488 |

### 3. Create the database tables

Open `bespoke/schema.sql` in DBeaver and execute the script.
The current script creates and selects the local database `bespoke_dev`.

The three tables are connected through foreign keys:
- `bespoke_gene.species_id` references `bespoke_species.species_id`.
- Both gene IDs in `bespoke_homology` reference `bespoke_gene.gene_id`.
- Each mouse–target gene pair forms the primary key of `bespoke_homology`.

### 4. Import the CSV files

The exported CSV files are already included in the repository.
They can be used to rebuild the database without rerunning the cleaning.

Import each CSV into its matching table in this order:

1. bespoke_species
2. bespoke_gene
3. bespoke_homology

In DBeaver, use UTF-8 encoding, a comma delimiter and the first row as
the header. Enable "Set empty strings to NULL" to preserve missing names.

### 5. Query the data

Select `bespoke_dev` and run `bespoke/example_queries.sql`.
The example returns the human and drill orthologs of the mouse gene `Ccnb1`.

## Connection to the main database

Integration with the main database is still pending.
Mouse gene symbols can be used for matching after checking for missing
or ambiguous mappings. Ensembl IDs remain the primary gene identifiers
within this module.