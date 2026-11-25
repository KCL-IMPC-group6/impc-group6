-- IMPC Group 6: read-only checks after restoring or rebuilding.
-- Select the restored/rebuilt database first. Expected failures and orphan counts: zero.
SELECT DATABASE() AS active_database;

-- Expected: 24 BASE TABLE objects and 3 VIEW objects.
SELECT TABLE_TYPE, COUNT(*) AS objects
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
GROUP BY TABLE_TYPE;

-- Expected: every row has status PASS.
SELECT table_name, expected_rows, actual_rows,
       CASE WHEN expected_rows = actual_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT 'alleles' AS table_name, 2884 AS expected_rows, COUNT(*) AS actual_rows FROM alleles
UNION ALL
    SELECT 'analyses' AS table_name, 27983 AS expected_rows, COUNT(*) AS actual_rows FROM analyses
UNION ALL
    SELECT 'bespoke_gene' AS table_name, 59101 AS expected_rows, COUNT(*) AS actual_rows FROM bespoke_gene
UNION ALL
    SELECT 'bespoke_homology' AS table_name, 48488 AS expected_rows, COUNT(*) AS actual_rows FROM bespoke_homology
UNION ALL
    SELECT 'bespoke_species' AS table_name, 3 AS expected_rows, COUNT(*) AS actual_rows FROM bespoke_species
UNION ALL
    SELECT 'clean_data_staging' AS table_name, 27983 AS expected_rows, COUNT(*) AS actual_rows FROM clean_data_staging
UNION ALL
    SELECT 'disease_genotypes' AS table_name, 7339 AS expected_rows, COUNT(*) AS actual_rows FROM disease_genotypes
UNION ALL
    SELECT 'disease_staging' AS table_name, 13912 AS expected_rows, COUNT(*) AS actual_rows FROM disease_staging
UNION ALL
    SELECT 'diseases' AS table_name, 5727 AS expected_rows, COUNT(*) AS actual_rows FROM diseases
UNION ALL
    SELECT 'genes' AS table_name, 2845 AS expected_rows, COUNT(*) AS actual_rows FROM genes
UNION ALL
    SELECT 'human_gene_diseases' AS table_name, 13912 AS expected_rows, COUNT(*) AS actual_rows FROM human_gene_diseases
UNION ALL
    SELECT 'human_genes' AS table_name, 4992 AS expected_rows, COUNT(*) AS actual_rows FROM human_genes
UNION ALL
    SELECT 'lacz_results' AS table_name, 307813 AS expected_rows, COUNT(*) AS actual_rows FROM lacz_results
UNION ALL
    SELECT 'mouse_ensembl_links' AS table_name, 2755 AS expected_rows, COUNT(*) AS actual_rows FROM mouse_ensembl_links
UNION ALL
    SELECT 'mouse_human_gene_links' AS table_name, 923 AS expected_rows, COUNT(*) AS actual_rows FROM mouse_human_gene_links
UNION ALL
    SELECT 'parameter_description_staging' AS table_name, 5325 AS expected_rows, COUNT(*) AS actual_rows FROM parameter_description_staging
UNION ALL
    SELECT 'parameter_group_membership' AS table_name, 736 AS expected_rows, COUNT(*) AS actual_rows FROM parameter_group_membership
UNION ALL
    SELECT 'parameter_groups' AS table_name, 16 AS expected_rows, COUNT(*) AS actual_rows FROM parameter_groups
UNION ALL
    SELECT 'parameter_metadata' AS table_name, 5311 AS expected_rows, COUNT(*) AS actual_rows FROM parameter_metadata
UNION ALL
    SELECT 'parameter_metadata_links' AS table_name, 1287 AS expected_rows, COUNT(*) AS actual_rows FROM parameter_metadata_links
UNION ALL
    SELECT 'parameters' AS table_name, 1784 AS expected_rows, COUNT(*) AS actual_rows FROM parameters
UNION ALL
    SELECT 'procedure_staging' AS table_name, 5311 AS expected_rows, COUNT(*) AS actual_rows FROM procedure_staging
UNION ALL
    SELECT 'procedures' AS table_name, 51 AS expected_rows, COUNT(*) AS actual_rows FROM procedures
UNION ALL
    SELECT 'tissues' AS table_name, 11 AS expected_rows, COUNT(*) AS actual_rows FROM tissues
) AS counts;

-- Expected: 21 foreign-key constraints.
SELECT COUNT(*) AS foreign_key_constraints
FROM information_schema.TABLE_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = DATABASE()
  AND CONSTRAINT_TYPE = 'FOREIGN KEY';

-- Expected: one p-value CHECK constraint, enforced.
SELECT t.TABLE_NAME, t.CONSTRAINT_NAME, c.CHECK_CLAUSE, t.ENFORCED
FROM information_schema.CHECK_CONSTRAINTS AS c
JOIN information_schema.TABLE_CONSTRAINTS AS t
  ON c.CONSTRAINT_SCHEMA = t.CONSTRAINT_SCHEMA
 AND c.CONSTRAINT_NAME = t.CONSTRAINT_NAME
WHERE t.TABLE_SCHEMA = DATABASE()
  AND t.TABLE_NAME = 'analyses'
  AND t.CONSTRAINT_NAME = 'chk_p_value_range';

-- Expected: 267 missing p-values, 278 missing parameter IDs, zero invalid p-values.
SELECT SUM(p_value IS NULL) AS missing_p_values,
       SUM(parameter_stable_id IS NULL) AS missing_parameter_ids,
       SUM(p_value < 0 OR p_value > 1) AS invalid_p_values
FROM analyses;

-- Expected: zero lost or altered parameter names.
SELECT COUNT(*) AS parameter_name_mismatches
FROM v_analyses_parameters AS a
JOIN clean_data_staging AS s ON a.analysis_id = s.analysis_id
WHERE NOT (a.parameter_name <=> s.parameter_name);

-- Expected: zero analyses without exactly 11 tissue records.
SELECT COUNT(*) AS incorrect_lacz_counts
FROM (
    SELECT a.analysis_id
    FROM analyses AS a
    LEFT JOIN lacz_results AS l ON a.analysis_id = l.analysis_id
    GROUP BY a.analysis_id
    HAVING COUNT(l.tissue_name) <> 11
) AS checks;

-- Expected: 7,339 unique disease-genotype pairs and 138,055 reconstructed associations.
SELECT (SELECT COUNT(*) FROM disease_genotypes) AS unique_pairs,
       (SELECT COUNT(*) FROM human_gene_diseases AS h
        JOIN disease_genotypes AS d ON h.disease_id = d.disease_id) AS reconstructed_associations;

-- Expected: zero source genotype IDs missing from the normalised table.
SELECT COUNT(*) AS missing_source_genotypes
FROM disease_staging AS d
JOIN JSON_TABLE(
    CONCAT('["', REPLACE(d.mouse_genotype_ids, '|', '","'), '"]'),
    '$[*]' COLUMNS (mouse_genotype_id VARCHAR(20) PATH '$')
) AS jt ON TRUE
LEFT JOIN disease_genotypes AS g
  ON d.disease_id = g.disease_id
 AND TRIM(jt.mouse_genotype_id) = g.mouse_genotype_id
WHERE d.mouse_genotype_ids IS NOT NULL
  AND d.mouse_genotype_ids <> ''
  AND TRIM(jt.mouse_genotype_id) <> ''
  AND g.disease_id IS NULL;

-- Expected: no obsolete table or list-valued column.
SELECT TABLE_NAME FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'human_gene_disease_genotypes';
SELECT COLUMN_NAME FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'human_gene_diseases'
  AND COLUMN_NAME = 'mouse_genotype_ids';

-- A dump temporarily disables foreign-key checks, so verify existing references explicitly.
-- Expected: zero orphan rows for every constraint.
SELECT 'alleles:gene_accession_id' AS relationship, COUNT(*) AS orphan_rows FROM `alleles` AS c LEFT JOIN `genes` AS p ON c.`gene_accession_id` = p.`gene_accession_id` WHERE c.`gene_accession_id` IS NOT NULL AND p.`gene_accession_id` IS NULL
UNION ALL
SELECT 'analyses:parameter_stable_id' AS relationship, COUNT(*) AS orphan_rows FROM `analyses` AS c LEFT JOIN `parameters` AS p ON c.`parameter_stable_id` = p.`parameter_stable_id` WHERE c.`parameter_stable_id` IS NOT NULL AND p.`parameter_stable_id` IS NULL
UNION ALL
SELECT 'analyses:allele_symbol,gene_accession_id' AS relationship, COUNT(*) AS orphan_rows FROM `analyses` AS c LEFT JOIN `alleles` AS p ON c.`allele_symbol` = p.`allele_symbol` AND c.`gene_accession_id` = p.`gene_accession_id` WHERE c.`allele_symbol` IS NOT NULL AND c.`gene_accession_id` IS NOT NULL AND p.`allele_symbol` IS NULL
UNION ALL
SELECT 'analyses:gene_accession_id' AS relationship, COUNT(*) AS orphan_rows FROM `analyses` AS c LEFT JOIN `genes` AS p ON c.`gene_accession_id` = p.`gene_accession_id` WHERE c.`gene_accession_id` IS NOT NULL AND p.`gene_accession_id` IS NULL
UNION ALL
SELECT 'bespoke_gene:species_id' AS relationship, COUNT(*) AS orphan_rows FROM `bespoke_gene` AS c LEFT JOIN `bespoke_species` AS p ON c.`species_id` = p.`species_id` WHERE c.`species_id` IS NOT NULL AND p.`species_id` IS NULL
UNION ALL
SELECT 'bespoke_homology:target_gene_id' AS relationship, COUNT(*) AS orphan_rows FROM `bespoke_homology` AS c LEFT JOIN `bespoke_gene` AS p ON c.`target_gene_id` = p.`gene_id` WHERE c.`target_gene_id` IS NOT NULL AND p.`gene_id` IS NULL
UNION ALL
SELECT 'bespoke_homology:mouse_gene_id' AS relationship, COUNT(*) AS orphan_rows FROM `bespoke_homology` AS c LEFT JOIN `bespoke_gene` AS p ON c.`mouse_gene_id` = p.`gene_id` WHERE c.`mouse_gene_id` IS NOT NULL AND p.`gene_id` IS NULL
UNION ALL
SELECT 'disease_genotypes:disease_id' AS relationship, COUNT(*) AS orphan_rows FROM `disease_genotypes` AS c LEFT JOIN `diseases` AS p ON c.`disease_id` = p.`disease_id` WHERE c.`disease_id` IS NOT NULL AND p.`disease_id` IS NULL
UNION ALL
SELECT 'human_gene_diseases:disease_id' AS relationship, COUNT(*) AS orphan_rows FROM `human_gene_diseases` AS c LEFT JOIN `diseases` AS p ON c.`disease_id` = p.`disease_id` WHERE c.`disease_id` IS NOT NULL AND p.`disease_id` IS NULL
UNION ALL
SELECT 'human_gene_diseases:hgnc_id' AS relationship, COUNT(*) AS orphan_rows FROM `human_gene_diseases` AS c LEFT JOIN `human_genes` AS p ON c.`hgnc_id` = p.`hgnc_id` WHERE c.`hgnc_id` IS NOT NULL AND p.`hgnc_id` IS NULL
UNION ALL
SELECT 'lacz_results:tissue_name' AS relationship, COUNT(*) AS orphan_rows FROM `lacz_results` AS c LEFT JOIN `tissues` AS p ON c.`tissue_name` = p.`tissue_name` WHERE c.`tissue_name` IS NOT NULL AND p.`tissue_name` IS NULL
UNION ALL
SELECT 'lacz_results:analysis_id' AS relationship, COUNT(*) AS orphan_rows FROM `lacz_results` AS c LEFT JOIN `analyses` AS p ON c.`analysis_id` = p.`analysis_id` WHERE c.`analysis_id` IS NOT NULL AND p.`analysis_id` IS NULL
UNION ALL
SELECT 'mouse_ensembl_links:mouse_ensembl_id' AS relationship, COUNT(*) AS orphan_rows FROM `mouse_ensembl_links` AS c LEFT JOIN `bespoke_gene` AS p ON c.`mouse_ensembl_id` = p.`gene_id` WHERE c.`mouse_ensembl_id` IS NOT NULL AND p.`gene_id` IS NULL
UNION ALL
SELECT 'mouse_ensembl_links:gene_accession_id' AS relationship, COUNT(*) AS orphan_rows FROM `mouse_ensembl_links` AS c LEFT JOIN `genes` AS p ON c.`gene_accession_id` = p.`gene_accession_id` WHERE c.`gene_accession_id` IS NOT NULL AND p.`gene_accession_id` IS NULL
UNION ALL
SELECT 'mouse_human_gene_links:hgnc_id' AS relationship, COUNT(*) AS orphan_rows FROM `mouse_human_gene_links` AS c LEFT JOIN `human_genes` AS p ON c.`hgnc_id` = p.`hgnc_id` WHERE c.`hgnc_id` IS NOT NULL AND p.`hgnc_id` IS NULL
UNION ALL
SELECT 'mouse_human_gene_links:gene_accession_id' AS relationship, COUNT(*) AS orphan_rows FROM `mouse_human_gene_links` AS c LEFT JOIN `genes` AS p ON c.`gene_accession_id` = p.`gene_accession_id` WHERE c.`gene_accession_id` IS NOT NULL AND p.`gene_accession_id` IS NULL
UNION ALL
SELECT 'parameter_group_membership:parameter_stable_id' AS relationship, COUNT(*) AS orphan_rows FROM `parameter_group_membership` AS c LEFT JOIN `parameters` AS p ON c.`parameter_stable_id` = p.`parameter_stable_id` WHERE c.`parameter_stable_id` IS NOT NULL AND p.`parameter_stable_id` IS NULL
UNION ALL
SELECT 'parameter_group_membership:group_id' AS relationship, COUNT(*) AS orphan_rows FROM `parameter_group_membership` AS c LEFT JOIN `parameter_groups` AS p ON c.`group_id` = p.`group_id` WHERE c.`group_id` IS NOT NULL AND p.`group_id` IS NULL
UNION ALL
SELECT 'parameter_metadata:procedure_id' AS relationship, COUNT(*) AS orphan_rows FROM `parameter_metadata` AS c LEFT JOIN `procedures` AS p ON c.`procedure_id` = p.`procedure_id` WHERE c.`procedure_id` IS NOT NULL AND p.`procedure_id` IS NULL
UNION ALL
SELECT 'parameter_metadata_links:impcParameterOrigId' AS relationship, COUNT(*) AS orphan_rows FROM `parameter_metadata_links` AS c LEFT JOIN `parameter_metadata` AS p ON c.`impcParameterOrigId` = p.`impcParameterOrigId` WHERE c.`impcParameterOrigId` IS NOT NULL AND p.`impcParameterOrigId` IS NULL
UNION ALL
SELECT 'parameter_metadata_links:parameter_stable_id' AS relationship, COUNT(*) AS orphan_rows FROM `parameter_metadata_links` AS c LEFT JOIN `parameters` AS p ON c.`parameter_stable_id` = p.`parameter_stable_id` WHERE c.`parameter_stable_id` IS NOT NULL AND p.`parameter_stable_id` IS NULL;
