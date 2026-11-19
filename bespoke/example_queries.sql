SELECT
    m.gene_name AS mouse_gene,
    s.species_name AS target_species,
    t.gene_id AS target_gene_id,
    t.gene_name AS target_gene,
    h.ancestor,
    h.homology_type,
    h.target_identity_pct
FROM bespoke_homology h
JOIN bespoke_gene m ON h.mouse_gene_id = m.gene_id
JOIN bespoke_gene t ON h.target_gene_id = t.gene_id
JOIN bespoke_species s ON t.species_id = s.species_id
WHERE m.gene_name = 'Ccnb1'
  AND m.species_id = 1
ORDER BY s.species_id;