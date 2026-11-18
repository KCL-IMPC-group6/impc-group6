import csv
from pathlib import Path
import re
import json

#import data
input_path = Path("../data/bespokeTask_hml.txt")

#saperate the header and the rows
with input_path.open(encoding="utf-8" , newline="") as file:
    reader = csv.reader(file, delimiter="\t")
    header = next(reader)
    rows =list(reader)

#summary the dimensions of the data
print(f"Header length: {len(header)}")
print(f"Rows length: {len(rows)}")

#test
for row in rows:
    if row[6] == "Ccnb1":
        example = row
        break

print("\nCcnb1 example:")
for column_name, value in zip(header,example):
    print(f"{column_name}: {value or '[empty]'}")

#check the data quality
#here we need summarize how many record can be inserted in the database.
#so we keep rows with a mouse ensembl gene id and a human ensembl id and at least one human or drill gene id.

unexpected_columns = 0
missing_mouse_id = 0 
no_homology_match = 0
eligible_rows = 0


for row in rows:
    if len(row) != 12:
        unexpected_columns += 1
        continue

    mouse_id = row[0].strip()
    human_id = row[1].strip()
    drill_id = row[7].strip()
    if mouse_id == "":
        missing_mouse_id += 1
    elif human_id == "" and drill_id == "":
        no_homology_match += 1
    else:
        eligible_rows += 1

print("\nEligibility check:")
print("Unexpected column count:", unexpected_columns)
print("Missing mouse ID:", missing_mouse_id)
print("No homology match:", no_homology_match)
print("Eligible rows:", eligible_rows)

# Count the target species represented in each eligible row.
human_only = 0
drill_only = 0
both_species = 0

for row in rows:
    if len(row) != 12:
        continue

    mouse_id = row[0].strip()
    human_id = row[1].strip()
    drill_id = row[7].strip()

    if mouse_id == "":
        continue

    if human_id != "" and drill_id != "":
        both_species += 1
    elif human_id != "":
        human_only += 1
    elif drill_id != "":
        drill_only += 1

total_pairs = human_only + drill_only + both_species * 2

print("\nTarget species check:")
print("Human only:", human_only)
print("Drill only:", drill_only)
print("Both species:", both_species)
print("Pairs before deduplication:", total_pairs)

# Split human and drill matches into separate records.
pairs = []

for row in rows:
    if len(row) != 12:
        continue

    mouse_id = row[0].strip()
    mouse_name = row[6].strip()

    if mouse_id == "":
        continue

    # Add the human match, if present.
    if row[1].strip() != "":
        pairs.append({
            "mouse_gene_id": mouse_id,
            "mouse_gene_name": mouse_name,
            "target_species": "Human",
            "target_gene_id": row[1].strip(),
            "target_gene_name": row[2].strip(),
            "ancestor": row[3].strip(),
            "homology_type": row[4].strip(),
            "target_identity_pct": row[5].strip(),
        })

    # Add the drill match, if present.
    if row[7].strip() != "":
        pairs.append({
            "mouse_gene_id": mouse_id,
            "mouse_gene_name": mouse_name,
            "target_species": "Drill",
            "target_gene_id": row[7].strip(),
            "target_gene_name": row[8].strip(),
            "ancestor": row[9].strip(),
            "homology_type": row[10].strip(),
            "target_identity_pct": row[11].strip(),
        })

print("\nSplit pair count:", len(pairs))

for pair in pairs:
    if pair["mouse_gene_name"] == "Ccnb1":
        print(pair)

# Identify repeated pairs and check for conflicting information.
seen_pairs = {}
unique_pairs = []
duplicate_count = 0
conflicting_pairs = []

for pair in pairs:
    pair_key = (
        pair["mouse_gene_id"],
        pair["target_species"],
        pair["target_gene_id"],
    )

    if pair_key not in seen_pairs:
        seen_pairs[pair_key] = pair
        unique_pairs.append(pair)

    elif pair == seen_pairs[pair_key]:
        duplicate_count += 1

    else:
        conflicting_pairs.append(pair)

print("\nDuplicate check:")
print("Pairs before deduplication:", len(pairs))
print("Unique pairs:", len(unique_pairs))
print("Repeated identical records:", duplicate_count)
print("Conflicting records:", len(conflicting_pairs))

# Check fields before exporting.
if unexpected_columns > 0 or conflicting_pairs:
    raise ValueError("Review the column errors or conflicting pairs first.")

valid_types = {
    "ortholog_one2one",
    "ortholog_one2many",
    "ortholog_many2many",
}

target_patterns = {
    "Human": r"ENSG\d{11}",
    "Drill": r"ENSMLEG\d{11}",
}

for pair in unique_pairs:
    if not re.fullmatch(r"ENSMUSG\d{11}", pair["mouse_gene_id"]):
        raise ValueError(f"Invalid mouse ID: {pair['mouse_gene_id']}")

    pattern = target_patterns[pair["target_species"]]
    if not re.fullmatch(pattern, pair["target_gene_id"]):
        raise ValueError(f"Invalid target ID: {pair['target_gene_id']}")

    if pair["homology_type"] not in valid_types:
        raise ValueError(f"Unknown homology type: {pair['homology_type']}")

    identity = float(pair["target_identity_pct"])
    if not 0 <= identity <= 100:
        raise ValueError(f"Invalid identity percentage: {identity}")

    pair["target_identity_pct"] = identity

# Save the cleaned pairs. Blank gene names are preserved.
output_dir = Path("data/processed/bespoke")
output_dir.mkdir(parents=True, exist_ok=True)

with (output_dir / "homology_clean.csv").open(
    "w", encoding="utf-8", newline=""
) as file:
    writer = csv.DictWriter(file, fieldnames=list(unique_pairs[0]))
    writer.writeheader()
    writer.writerows(unique_pairs)

# Save a short cleaning summary.
summary = {
    "source_rows": len(rows),
    "eligible_rows": eligible_rows,
    "pairs_before_deduplication": len(pairs),
    "duplicates_removed": duplicate_count,
    "clean_pairs": len(unique_pairs),
    "missing_mouse_names": sum(p["mouse_gene_name"] == "" for p in unique_pairs),
    "missing_target_names": sum(p["target_gene_name"] == "" for p in unique_pairs),
    "field_checks": "passed",
}

with (output_dir / "cleaning_summary.json").open("w", encoding="utf-8") as file:
    json.dump(summary, file, indent=2)

print("\nField checks passed.")
print("Clean pairs saved:", len(unique_pairs))
print("Output folder:", output_dir)