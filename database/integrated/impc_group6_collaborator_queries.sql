-- IMPC Group 6: allele-specific collaborator queries
-- Select the integrated database in DBeaver before running these queries.

-- 1. Find the allele symbols for the supplied genes

SELECT g.gene_symbol, a.allele_symbol, COUNT(*) AS analyses
FROM analyses AS a
JOIN genes AS g
    ON a.gene_accession_id = g.gene_accession_id
WHERE g.gene_symbol IN ('Chrm4', 'Ddx41', 'Spata31d1c', 'Supv3l1', 'Eaf1')
GROUP BY g.gene_symbol, a.allele_symbol
ORDER BY g.gene_symbol, a.allele_symbol;


-- Choose an exact allele symbol from the results above.
-- Change the value and rerun queries 2-5 for each selected allele.
-- The group's four report genotypes should be selected separately; the five
-- gene symbols above are a discovery list, not four confirmed genotypes.

SET @allele_symbol = 'Chrm4<tm1b(EUCOMM)Hmgu>';


-- 2. Phenotypes, p-values, parameter groups and procedures
-- This flags p < 0.05 at a nominal threshold; no additional multiple-testing
-- adjustment is performed by this query.

SELECT
    a.allele_symbol,
    g.gene_symbol,
    a.analysis_id,
    a.parameter_stable_id,
    a.parameter_name,
    GROUP_CONCAT(DISTINCT pg.group_name ORDER BY pg.group_name SEPARATOR ', ') AS parameter_groups,
    GROUP_CONCAT(DISTINCT pr.procedure_name ORDER BY pr.procedure_name SEPARATOR ', ') AS procedures,
    a.p_value,
    CASE
        WHEN a.p_value IS NULL THEN 'missing p-value'
        WHEN a.p_value < 0.05 THEN 'significant'
        ELSE 'not significant'
    END AS significance
FROM v_analyses_parameters AS a
JOIN genes AS g
    ON a.gene_accession_id = g.gene_accession_id
LEFT JOIN parameter_group_membership AS pgm
    ON a.parameter_stable_id = pgm.parameter_stable_id
LEFT JOIN parameter_groups AS pg
    ON pgm.group_id = pg.group_id
LEFT JOIN parameter_metadata_links AS pml
    ON a.parameter_stable_id = pml.parameter_stable_id
LEFT JOIN parameter_metadata AS pm
    ON pml.impcParameterOrigId = pm.impcParameterOrigId
LEFT JOIN procedures AS pr
    ON pm.procedure_id = pr.procedure_id
WHERE a.allele_symbol = @allele_symbol
GROUP BY
    a.allele_symbol, g.gene_symbol, a.analysis_id,
    a.parameter_stable_id, a.parameter_name, a.p_value
ORDER BY a.p_value IS NULL, a.p_value, a.analysis_id;


-- 3. Associated human genes and diseases
-- These links are at mouse-gene level, not allele level.

SELECT DISTINCT
    al.allele_symbol,
    g.gene_symbol,
    hg.human_gene_symbol,
    d.disease_id,
    d.disease_name
FROM alleles AS al
JOIN genes AS g
    ON al.gene_accession_id = g.gene_accession_id
LEFT JOIN mouse_human_gene_links AS mhl
    ON g.gene_accession_id = mhl.gene_accession_id
LEFT JOIN human_genes AS hg
    ON mhl.hgnc_id = hg.hgnc_id
LEFT JOIN human_gene_diseases AS hgd
    ON hg.hgnc_id = hgd.hgnc_id
LEFT JOIN diseases AS d
    ON hgd.disease_id = d.disease_id
WHERE al.allele_symbol = @allele_symbol
ORDER BY d.disease_name;


-- 4. Homology links for the selected gene
-- MGI-to-Ensembl mappings are provisional.

SELECT
    al.allele_symbol,
    g.gene_symbol,
    l.mapping_status,
    s.species_name AS target_species,
    t.gene_name AS homologous_gene,
    h.homology_type,
    h.target_identity_pct
FROM alleles AS al
JOIN genes AS g
    ON al.gene_accession_id = g.gene_accession_id
LEFT JOIN mouse_ensembl_links AS l
    ON g.gene_accession_id = l.gene_accession_id
LEFT JOIN bespoke_homology AS h
    ON l.mouse_ensembl_id = h.mouse_gene_id
LEFT JOIN bespoke_gene AS t
    ON h.target_gene_id = t.gene_id
LEFT JOIN bespoke_species AS s
    ON t.species_id = s.species_id
WHERE al.allele_symbol = @allele_symbol
ORDER BY s.species_name, t.gene_name;


-- 5. LacZ analysis counts by tissue (not counts of individual mice)

SELECT
    a.allele_symbol,
    l.tissue_name,
    l.expression_status,
    COUNT(*) AS analyses
FROM analyses AS a
JOIN lacz_results AS l
    ON a.analysis_id = l.analysis_id
WHERE a.allele_symbol = @allele_symbol
GROUP BY a.allele_symbol, l.tissue_name, l.expression_status
ORDER BY l.tissue_name, l.expression_status;
