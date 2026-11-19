import csv
from pathlib import Path

output_dir = Path("data/processed/bespoke")

with (output_dir / "homology_clean.csv").open(
    encoding="utf-8", newline=""
) as file:
    unique_pairs = list(csv.DictReader(file))

# Prepare CSV files for the three database tables.
species_ids = {"Mouse": 1, "Human": 2, "Drill": 3}
gene_rows = {}
homology_rows = []

for pair in unique_pairs:
    mouse_id = pair["mouse_gene_id"]
    target_id = pair["target_gene_id"]
    target_species_id = species_ids[pair["target_species"]]

    gene_rows[mouse_id] = [mouse_id, pair["mouse_gene_name"], 1]
    gene_rows[target_id] = [
        target_id, pair["target_gene_name"], target_species_id
    ]

    homology_rows.append([
        mouse_id, target_id, pair["ancestor"],
        pair["homology_type"], pair["target_identity_pct"]
    ])

with (output_dir / "bespoke_species.csv").open(
    "w", encoding="utf-8", newline=""
) as file:
    writer = csv.writer(file)
    writer.writerow(["species_id", "species_name"])
    for name, species_id in species_ids.items():
        writer.writerow([species_id, name])

with (output_dir / "bespoke_gene.csv").open(
    "w", encoding="utf-8", newline=""
) as file:
    writer = csv.writer(file)
    writer.writerow(["gene_id", "gene_name", "species_id"])
    writer.writerows(gene_rows.values())

with (output_dir / "bespoke_homology.csv").open(
    "w", encoding="utf-8", newline=""
) as file:
    writer = csv.writer(file)
    writer.writerow([
        "mouse_gene_id", "target_gene_id", "ancestor",
        "homology_type", "target_identity_pct"
    ])
    writer.writerows(homology_rows)

print("Species:", len(species_ids))
print("Genes:", len(gene_rows))
print("Homology pairs:", len(homology_rows))