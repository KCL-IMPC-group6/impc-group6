-- IMPC Group 6 database
-- Fresh database build script
-- Run on a new, empty MySQL database. Import the CSV files at the marked points.
-- For final_clean_data.csv, map the literal NA marker to SQL NULL in DBeaver.
-- Run each INSERT/import once, and do not use an already populated database.
-- See README.md for the CSV paths and import settings.

-- SECTION 1: Select the database

CREATE DATABASE IF NOT EXISTS impc_group6
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE impc_group6;

SELECT DATABASE();
SHOW TABLES;


-- SECTION 2: Create the staging table

-- Load the cleaned data here first so we can check it before splitting it into tables.
-- Column sizes follow the SOP and the cleaned data. 
-- Analysis IDs are 12 characters as stated in the SOP remarks. 
-- Allow 20 characters for lacZ (tissue not available)
-- and 35 for strain names (the longest cleaned strain name has 26 characters).

CREATE TABLE IF NOT EXISTS clean_data_staging (
    gene_accession_id VARCHAR(11),
    gene_symbol VARCHAR(13),
    allele_symbol VARCHAR(35),
    strain_name VARCHAR(35),
    parameter_stable_id VARCHAR(20),
    p_value DOUBLE,
    parameter_name VARCHAR(200),
    mouse_life_stage VARCHAR(17),
    lacz_blood VARCHAR(20),
    lacz_brain VARCHAR(20),
    lacz_colon VARCHAR(20),
    lacz_eye VARCHAR(20),
    lacz_heart VARCHAR(20),
    lacz_kidney VARCHAR(20),
    lacz_liver VARCHAR(20),
    lacz_lung VARCHAR(20),
    lacz_skeletal_muscle VARCHAR(20),
    lacz_skin VARCHAR(20),
    lacz_vascular_system VARCHAR(20),
    analysis_id CHAR(12) PRIMARY KEY
);

-- Import data/processed/clean_group6_data/final_clean_data.csv into clean_data_staging before Section 3.
-- In DBeaver's CSV import settings, set the null-value marker to NA.
-- Verify that numeric p_value values represented by NA become SQL NULL.
-- This keeps missing p-values separate from zero and avoids importing NA as text.
-- Use the existing table, UTF-8, comma delimiter, double quotes and column headers.


-- SECTION 3: Check the imported data

-- Expect 27,983 rows, 267 missing p-values and 278 missing parameter IDs.

SELECT COUNT(*) AS total_rows
FROM clean_data_staging;

SELECT *
FROM clean_data_staging
LIMIT 5;

SELECT
    SUM(gene_accession_id IS NULL) AS missing_gene_ids,
    SUM(allele_symbol IS NULL) AS missing_alleles,
    SUM(parameter_stable_id IS NULL) AS missing_parameter_ids,
    SUM(parameter_name IS NULL) AS missing_parameter_names,
    SUM(p_value IS NULL) AS missing_p_values
FROM clean_data_staging;


-- SECTION 4: Look at the analyses for one gene

SELECT gene_accession_id, gene_symbol, analysis_id, parameter_name
FROM clean_data_staging
WHERE gene_accession_id = 'MGI:1859162'
LIMIT 5;


-- SECTION 5: Check repeated gene and parameter combinations

SELECT gene_accession_id, parameter_name,
       COUNT(*) AS number_of_analyses
FROM clean_data_staging
GROUP BY gene_accession_id, parameter_name
HAVING COUNT(*) > 1
ORDER BY number_of_analyses DESC
LIMIT 10;


-- SECTION 6: Check IDs and names

-- Check that each ID can identify its record before using it as a primary key.

-- Check for gene IDs with more than one symbol
SELECT gene_accession_id,
       COUNT(DISTINCT gene_symbol) AS symbol_count
FROM clean_data_staging
GROUP BY gene_accession_id
HAVING COUNT(DISTINCT gene_symbol) > 1;

-- Check for parameter IDs with more than one name
SELECT parameter_stable_id,
       COUNT(DISTINCT parameter_name) AS name_count
FROM clean_data_staging
WHERE parameter_stable_id IS NOT NULL
GROUP BY parameter_stable_id
HAVING COUNT(DISTINCT parameter_name) > 1;

-- Check whether the same allele is linked to different genes
SELECT allele_symbol,
       COUNT(DISTINCT gene_accession_id) AS gene_count
FROM clean_data_staging
WHERE allele_symbol IS NOT NULL
GROUP BY allele_symbol
HAVING COUNT(DISTINCT gene_accession_id) > 1;


-- SECTION 7: Create the genes table

CREATE TABLE IF NOT EXISTS genes (
    gene_accession_id VARCHAR(11) PRIMARY KEY,
    gene_symbol VARCHAR(13)
);


-- SECTION 8: Populate and check the genes table

-- DISTINCT avoids storing the same gene for every analysis.

INSERT INTO genes (gene_accession_id, gene_symbol)
SELECT DISTINCT gene_accession_id, gene_symbol
FROM clean_data_staging;

SELECT COUNT(*) AS gene_rows
FROM genes;

-- SECTION 9: Create the parameters table

CREATE TABLE IF NOT EXISTS parameters (
    parameter_stable_id VARCHAR(20) PRIMARY KEY,
    parameter_name VARCHAR(200)
);


-- SECTION 10: Populate and check the parameters table

-- Keep the supplied IDs, including M-G-P_ IDs. Do not invent IDs for missing values.

INSERT INTO parameters (parameter_stable_id, parameter_name)
SELECT DISTINCT parameter_stable_id, parameter_name
FROM clean_data_staging
WHERE parameter_stable_id IS NOT NULL;

SELECT COUNT(*) AS parameter_rows
FROM parameters;


-- SECTION 11: Create the alleles table

-- Each allele is linked to its gene using the supplied MGI accession ID.

CREATE TABLE IF NOT EXISTS alleles (
    allele_symbol VARCHAR(35) PRIMARY KEY,
    gene_accession_id VARCHAR(11) NOT NULL,
    UNIQUE (allele_symbol, gene_accession_id),
    FOREIGN KEY (gene_accession_id)
        REFERENCES genes(gene_accession_id)
);


-- SECTION 12: Populate and check the alleles table

INSERT INTO alleles (allele_symbol, gene_accession_id)
SELECT DISTINCT allele_symbol, gene_accession_id
FROM clean_data_staging
WHERE allele_symbol IS NOT NULL;

SELECT COUNT(*) AS total_alleles
FROM alleles;


-- SECTION 13: Check the analysis IDs

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT analysis_id) AS unique_analysis_ids
FROM clean_data_staging;


-- SECTION 14: Create the analyses table

-- Each analysis has its own ID. 
-- The two-column foreign key checks that an allele belongs to the gene in the same analysis. 
-- The p-value check allows NULL but prevents values outside 0 to 1.

CREATE TABLE IF NOT EXISTS analyses (
    analysis_id CHAR(12) PRIMARY KEY,
    gene_accession_id VARCHAR(11) NOT NULL,
    allele_symbol VARCHAR(35),
    parameter_stable_id VARCHAR(20),
    unlinked_parameter_name VARCHAR(200),
    p_value DOUBLE,
    strain_name VARCHAR(35),
    mouse_life_stage VARCHAR(17),
    FOREIGN KEY (gene_accession_id)
        REFERENCES genes(gene_accession_id),
    FOREIGN KEY (allele_symbol, gene_accession_id)
        REFERENCES alleles(allele_symbol, gene_accession_id),
    FOREIGN KEY (parameter_stable_id)
        REFERENCES parameters(parameter_stable_id),
    CONSTRAINT chk_p_value_range CHECK (p_value >= 0 AND p_value <= 1)
);


-- SECTION 15: Populate the analyses table

-- Keep the parameter name in the analysis if its stable ID is missing.
-- This preserves the result without making up a parameter ID.

INSERT INTO analyses (
    analysis_id,
    gene_accession_id,
    allele_symbol,
    parameter_stable_id,
    unlinked_parameter_name,
    p_value,
    strain_name,
    mouse_life_stage
)
SELECT
    analysis_id,
    gene_accession_id,
    allele_symbol,
    parameter_stable_id,
    CASE
        WHEN parameter_stable_id IS NULL THEN parameter_name
        ELSE NULL
    END,
    p_value,
    strain_name,
    mouse_life_stage
FROM clean_data_staging;

SELECT COUNT(*) AS total_analyses
FROM analyses;

-- SECTION 16: Check the missing parameter IDs

SELECT
    COUNT(*) AS total_analyses,
    SUM(parameter_stable_id IS NULL) AS missing_ids,
    SUM(unlinked_parameter_name IS NOT NULL) AS fallback_names,
    SUM(parameter_stable_id IS NOT NULL
        AND unlinked_parameter_name IS NOT NULL) AS unnecessary_fallbacks,
    SUM(parameter_stable_id IS NULL
        AND unlinked_parameter_name IS NULL) AS missing_both
FROM analyses;


-- SECTION 17: Create a view showing parameter names

-- LEFT JOIN keeps analyses without a parameter match. 
-- COALESCE uses the stored fallback name when the name from the parameters table is NULL.

CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_analyses_parameters AS
SELECT a.*,
       COALESCE(p.parameter_name, a.unlinked_parameter_name) AS parameter_name
FROM analyses AS a
LEFT JOIN parameters AS p
    ON a.parameter_stable_id = p.parameter_stable_id;

SELECT analysis_id, parameter_stable_id, parameter_name
FROM v_analyses_parameters
LIMIT 5;


-- SECTION 18: Create the tissues table

CREATE TABLE IF NOT EXISTS tissues (
    tissue_name VARCHAR(32) PRIMARY KEY
);


-- SECTION 19: Add the tissue names

INSERT INTO tissues (tissue_name)
VALUES
    ('blood'),
    ('brain'),
    ('colon'),
    ('eye'),
    ('heart'),
    ('kidney'),
    ('liver'),
    ('lung'),
    ('skeletal_muscle'),
    ('skin'),
    ('vascular_system');


-- SECTION 20: Create the LacZ results table

-- Use the analysis ID and tissue name together so each tissue has one result per analysis.

CREATE TABLE IF NOT EXISTS lacz_results (
    analysis_id CHAR(12) NOT NULL,
    tissue_name VARCHAR(32) NOT NULL,
    expression_status VARCHAR(20),
    PRIMARY KEY (analysis_id, tissue_name),
    FOREIGN KEY (analysis_id)
        REFERENCES analyses(analysis_id),
    FOREIGN KEY (tissue_name)
        REFERENCES tissues(tissue_name)
);


-- SECTION 21: Populate and check the LacZ results

-- Turn the 11 tissue columns into rows to avoid needing a separate column for each tissue. 
-- Keep NULL expression statuses as well as the recorded values.
-- Expect 307,813 rows (11 per analysis).

INSERT INTO lacz_results (analysis_id, tissue_name, expression_status)
SELECT analysis_id, 'blood', lacz_blood FROM clean_data_staging
UNION ALL
SELECT analysis_id, 'brain', lacz_brain FROM clean_data_staging
UNION ALL
SELECT analysis_id, 'colon', lacz_colon FROM clean_data_staging
UNION ALL
SELECT analysis_id, 'eye', lacz_eye FROM clean_data_staging
UNION ALL
SELECT analysis_id, 'heart', lacz_heart FROM clean_data_staging
UNION ALL
SELECT analysis_id, 'kidney', lacz_kidney FROM clean_data_staging
UNION ALL
SELECT analysis_id, 'liver', lacz_liver FROM clean_data_staging
UNION ALL
SELECT analysis_id, 'lung', lacz_lung FROM clean_data_staging
UNION ALL
SELECT analysis_id, 'skeletal_muscle', lacz_skeletal_muscle FROM clean_data_staging
UNION ALL
SELECT analysis_id, 'skin', lacz_skin FROM clean_data_staging
UNION ALL
SELECT analysis_id, 'vascular_system', lacz_vascular_system FROM clean_data_staging;

SELECT COUNT(*) AS total_lacz_results
FROM lacz_results;


-- SECTION 22: Create the parameter groups table

CREATE TABLE IF NOT EXISTS parameter_groups (
    group_id INT PRIMARY KEY,
    group_name VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255)
);


-- SECTION 23: Create the parameter group membership table

-- A parameter can belong to more than one group. 
-- The composite primary key prevents the same parameter being added twice to the same group.

CREATE TABLE IF NOT EXISTS parameter_group_membership (
    group_id INT NOT NULL,
    parameter_stable_id VARCHAR(20) NOT NULL,
    PRIMARY KEY (group_id, parameter_stable_id),
    FOREIGN KEY (group_id)
        REFERENCES parameter_groups(group_id),
    FOREIGN KEY (parameter_stable_id)
        REFERENCES parameters(parameter_stable_id)
);

-- STOP: Import the two CSV files in DBeaver, in this order:
-- 1. data/processed/parameter_group/parameter_group.csv into parameter_groups (16 rows)
-- 2. data/processed/parameter_group/parameter_group_member.csv
--    into parameter_group_membership (736 rows)
-- Match the column names and use the existing tables as import targets.
-- Do not import data/processed/parameter_group/parameter_table.csv. 
-- Our parameters table already contains the same 1,784 parameter IDs and names from clean_data_staging.
-- Continue to Section 24 only after both CSV imports are finished.


-- SECTION 24: Check the tables and group memberships

SELECT 'staging' AS table_name, COUNT(*) AS total_rows FROM clean_data_staging
UNION ALL
SELECT 'genes', COUNT(*) FROM genes
UNION ALL
SELECT 'parameters', COUNT(*) FROM parameters
UNION ALL
SELECT 'alleles', COUNT(*) FROM alleles
UNION ALL
SELECT 'analyses', COUNT(*) FROM analyses
UNION ALL
SELECT 'lacz_results', COUNT(*) FROM lacz_results
UNION ALL
SELECT 'parameter_groups', COUNT(*) FROM parameter_groups
UNION ALL
SELECT 'parameter_group_membership', COUNT(*) FROM parameter_group_membership;

-- Check that every group has its expected memberships
SELECT g.group_name, COUNT(m.parameter_stable_id) AS parameter_count
FROM parameter_groups AS g
LEFT JOIN parameter_group_membership AS m
    ON g.group_id = m.group_id
GROUP BY g.group_id, g.group_name
ORDER BY g.group_id;

-- Check whether an analysis and its allele refer to the same gene
SELECT COUNT(*) AS mismatched_gene_allele_links
FROM analyses AS a
JOIN alleles AS al
    ON a.allele_symbol = al.allele_symbol
WHERE a.gene_accession_id <> al.gene_accession_id;

-- Compare the total joined rows with the number of distinct analyses.
-- An analysis may appear more than once if its parameter is in multiple groups.
SELECT
    COUNT(*) AS analysis_group_rows,
    COUNT(DISTINCT a.analysis_id) AS distinct_analyses
FROM analyses AS a
JOIN parameter_group_membership AS m
    ON a.parameter_stable_id = m.parameter_stable_id;

-- Preview linked analysis records
SELECT a.analysis_id, g.gene_symbol, a.allele_symbol,
       v.parameter_name, a.p_value
FROM analyses AS a
JOIN genes AS g
    ON a.gene_accession_id = g.gene_accession_id
JOIN v_analyses_parameters AS v
    ON a.analysis_id = v.analysis_id
LIMIT 10;


-- SECTION 25: Parameter group review

-- Images includes morphology and body-composition measurements, not just image assays. 
-- Review the group against the IMPC metadata before interpreting it.
-- The cleaned input also contains a nearest-SOP strain correction (an1417460674).
-- The evidence for this correction belongs in the cleaning log.


-- SECTION 26: Create the parameter description staging table

CREATE TABLE IF NOT EXISTS parameter_description_staging (
    impcParameterOrigId VARCHAR(20),
    name VARCHAR(200),
    description TEXT,
    parameterId VARCHAR(20)
);

-- Import database/integrated/inputs/parameter_description_import.csv into parameter_description_staging now (5,325 rows)
-- before running the checks below.
-- For this and the remaining imports, preserve empty strings and whitespace.
-- The SQL trims metadata when moving it into the main tables.

-- Check the imported parameter descriptions

SELECT COUNT(*) AS total_rows
FROM parameter_description_staging;

SELECT *
FROM parameter_description_staging
LIMIT 5;


-- SECTION 27: Check duplicate parameter IDs

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT impcParameterOrigId) AS unique_original_ids,
    COUNT(DISTINCT parameterId) AS unique_stable_ids
FROM parameter_description_staging;


-- Find original parameter IDs that appear more than once

SELECT
    impcParameterOrigId,
    COUNT(*) AS number_of_records
FROM parameter_description_staging
GROUP BY impcParameterOrigId
HAVING COUNT(*) > 1;

-- Check repeated parameter records

SELECT *
FROM parameter_description_staging
WHERE impcParameterOrigId = '17587';

-- Check for identical duplicate records

SELECT
    impcParameterOrigId,
    name,
    description,
    parameterId,
    COUNT(*) AS number_of_copies
FROM parameter_description_staging
GROUP BY
    impcParameterOrigId,
    name,
    description,
    parameterId
HAVING COUNT(*) > 1;


-- SECTION 28: Check matching parameter IDs

SELECT
    COUNT(DISTINCT TRIM(s.parameterId)) AS metadata_parameter_ids,
    COUNT(DISTINCT p.parameter_stable_id) AS matching_parameter_ids
FROM parameter_description_staging AS s
LEFT JOIN parameters AS p
    ON TRIM(s.parameterId) = p.parameter_stable_id;


-- SECTION 29: Check repeated stable parameter IDs

SELECT
    TRIM(parameterId) AS parameter_stable_id,
    COUNT(DISTINCT impcParameterOrigId) AS original_id_count
FROM parameter_description_staging
WHERE parameterId IS NOT NULL
GROUP BY TRIM(parameterId)
HAVING COUNT(DISTINCT impcParameterOrigId) > 1
ORDER BY original_id_count DESC
LIMIT 10;


-- SECTION 30: Check parameter name and description consistency

SELECT
    TRIM(parameterId) AS parameter_stable_id,
    COUNT(DISTINCT TRIM(name)) AS different_names,
    COUNT(DISTINCT TRIM(description)) AS different_descriptions
FROM parameter_description_staging
GROUP BY TRIM(parameterId)
HAVING COUNT(DISTINCT TRIM(name)) > 1
    OR COUNT(DISTINCT TRIM(description)) > 1
ORDER BY different_names DESC, different_descriptions DESC;


-- SECTION 31: Create and populate the parameter metadata table

-- A stable ID can have more than one original parameter ID. Keep the original ID as the primary key. 
-- Trim extra spaces and turn blank or NA descriptions into NULL; 
-- the original text stays in staging.

CREATE TABLE IF NOT EXISTS parameter_metadata (
    impcParameterOrigId VARCHAR(20) PRIMARY KEY,
    parameter_stable_id VARCHAR(20),
    parameter_name VARCHAR(200),
    description TEXT
);

INSERT INTO parameter_metadata (
    impcParameterOrigId,
    parameter_stable_id,
    parameter_name,
    description
)
SELECT DISTINCT
    TRIM(impcParameterOrigId),
    TRIM(parameterId),
    TRIM(name),
    CASE
        WHEN TRIM(description) IN ('', 'NA') THEN NULL
        ELSE TRIM(description)
    END
FROM parameter_description_staging;

SELECT COUNT(*) AS total_metadata_rows
FROM parameter_metadata;


-- SECTION 32: Create the procedure staging table

CREATE TABLE IF NOT EXISTS procedure_staging (
    name VARCHAR(200),
    description TEXT,
    isMandatory VARCHAR(10),
    impcParameterOrigId VARCHAR(20)
);

-- Import database/integrated/inputs/procedure_import.csv into procedure_staging before Section 33 (5,311 rows).


-- SECTION 33: Check procedure and parameter relationships

SELECT
    COUNT(*) AS total_procedures,
    COUNT(DISTINCT p.impcParameterOrigId) AS unique_original_ids,
    COUNT(m.impcParameterOrigId) AS matching_parameters,
    SUM(m.impcParameterOrigId IS NULL) AS unmatched_parameters
FROM procedure_staging AS p
LEFT JOIN parameter_metadata AS m
    ON TRIM(p.impcParameterOrigId) = m.impcParameterOrigId;


-- SECTION 34: Create and populate the procedures table

-- Use an internal numeric key for each procedure name, not a new IMPC identifier.
-- The source descriptions stay in procedure_staging because some names have more than one description. 
-- Generated IDs can differ between builds.

CREATE TABLE IF NOT EXISTS procedures (
    procedure_id INT AUTO_INCREMENT PRIMARY KEY,
    procedure_name VARCHAR(200) NOT NULL UNIQUE,
    isMandatory VARCHAR(5)
);

INSERT INTO procedures (procedure_name, isMandatory)
SELECT DISTINCT
    TRIM(name),
    TRIM(isMandatory)
FROM procedure_staging;

SELECT COUNT(*) AS total_procedures
FROM procedures;


-- SECTION 35: Link procedures to parameter metadata

-- The original parameter ID is shared by the two supplied metadata files.
-- Use it to find the procedure rather than guessing from the parameter name.

ALTER TABLE parameter_metadata
ADD COLUMN procedure_id INT;

UPDATE parameter_metadata AS m
JOIN procedure_staging AS s
    ON m.impcParameterOrigId = TRIM(s.impcParameterOrigId)
JOIN procedures AS p
    ON TRIM(s.name) = p.procedure_name
SET m.procedure_id = p.procedure_id;

ALTER TABLE parameter_metadata
ADD FOREIGN KEY (procedure_id)
REFERENCES procedures(procedure_id);


-- Check the relationships

SELECT
    COUNT(*) AS total_parameters,
    COUNT(procedure_id) AS linked_procedures
FROM parameter_metadata;


-- SECTION 36: Check parameter and procedure relationships

SELECT
    m.impcParameterOrigId,
    m.parameter_name,
    p.procedure_name
FROM parameter_metadata AS m
JOIN procedures AS p
    ON m.procedure_id = p.procedure_id
LIMIT 10;


-- SECTION 37: Create the disease staging table

CREATE TABLE IF NOT EXISTS disease_staging (
    human_gene_symbol VARCHAR(20),
    human_gene_name VARCHAR(200),
    hgnc_id VARCHAR(20),
    disease_name VARCHAR(200),
    disease_id VARCHAR(20),
    mouse_genotype_ids TEXT,
    mouse_gene_symbol VARCHAR(20),
    mouse_gene_id VARCHAR(20)
);

-- Import database/integrated/inputs/disease_import_ready.csv into disease_staging before Section 38 (13,912 rows).

-- SECTION 38: Check disease data

-- Count genes, diseases and records

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT mouse_gene_id) AS total_mouse_genes,
    COUNT(DISTINCT disease_id) AS total_diseases
FROM disease_staging;


-- Check for repeated gene and disease combinations

SELECT
    mouse_gene_id,
    disease_id,
    COUNT(*) AS number_of_records
FROM disease_staging
GROUP BY mouse_gene_id, disease_id
HAVING COUNT(*) > 1;


-- Check which mouse genes match our genes table

SELECT
    COUNT(*) AS matching_disease_records,
    COUNT(DISTINCT d.mouse_gene_id) AS matching_mouse_genes
FROM disease_staging AS d
JOIN genes AS g
    ON d.mouse_gene_id = g.gene_accession_id;


-- SECTION 39: Create the diseases table

CREATE TABLE IF NOT EXISTS diseases (
    disease_id VARCHAR(20) PRIMARY KEY,
    disease_name VARCHAR(200)
);

-- Populate the diseases table

INSERT INTO diseases (disease_id, disease_name)
SELECT DISTINCT disease_id, disease_name
FROM disease_staging;

-- Check the number of diseases

SELECT COUNT(*) AS total_diseases
FROM diseases;


-- SECTION 40: Create the human genes table

CREATE TABLE IF NOT EXISTS human_genes (
    hgnc_id VARCHAR(20) PRIMARY KEY,
    human_gene_symbol VARCHAR(20),
    human_gene_name VARCHAR(200),
    mouse_gene_id VARCHAR(20),
    mouse_gene_symbol VARCHAR(20)
);


-- Populate the human genes table

INSERT INTO human_genes (
    hgnc_id,
    human_gene_symbol,
    human_gene_name,
    mouse_gene_id,
    mouse_gene_symbol
)
SELECT DISTINCT
    hgnc_id,
    human_gene_symbol,
    human_gene_name,
    mouse_gene_id,
    mouse_gene_symbol
FROM disease_staging;


-- Check the number of human genes

SELECT COUNT(*) AS total_human_genes
FROM human_genes;


-- SECTION 41: Link human genes to diseases, and diseases to genotype IDs

-- A human gene can be associated with several diseases and a disease can be associated with several genes. 
-- The linking table keeps each pair once.

CREATE TABLE IF NOT EXISTS human_gene_diseases (
    hgnc_id VARCHAR(20) NOT NULL,
    disease_id VARCHAR(20) NOT NULL,
    PRIMARY KEY (hgnc_id, disease_id),
    FOREIGN KEY (hgnc_id) REFERENCES human_genes(hgnc_id),
    FOREIGN KEY (disease_id) REFERENCES diseases(disease_id)
);

INSERT INTO human_gene_diseases (hgnc_id, disease_id)
SELECT DISTINCT hgnc_id, disease_id
FROM disease_staging;

-- The source repeats the same genotype list for each human gene linked to a disease.
-- Store each disease-genotype pair once. Keep the original strings in staging.
-- These genotype IDs describe disease models, not confirmed matches to IMPC alleles.
CREATE TABLE IF NOT EXISTS disease_genotypes (
    disease_id VARCHAR(20) NOT NULL,
    mouse_genotype_id VARCHAR(20) NOT NULL,
    PRIMARY KEY (disease_id, mouse_genotype_id),
    INDEX idx_mouse_genotype_id (mouse_genotype_id),
    CONSTRAINT fk_disease_genotypes_disease
        FOREIGN KEY (disease_id) REFERENCES diseases(disease_id)
);

-- JSON_TABLE splits the pipe-separated list into one genotype ID per row.
INSERT INTO disease_genotypes (disease_id, mouse_genotype_id)
SELECT DISTINCT d.disease_id, TRIM(jt.mouse_genotype_id)
FROM disease_staging AS d
JOIN JSON_TABLE(
    CONCAT('["', REPLACE(d.mouse_genotype_ids, '|', '","'), '"]'),
    '$[*]' COLUMNS (mouse_genotype_id VARCHAR(20) PATH '$')
) AS jt ON TRUE
WHERE d.mouse_genotype_ids IS NOT NULL
  AND d.mouse_genotype_ids <> ''
  AND TRIM(jt.mouse_genotype_id) <> '';

SELECT COUNT(*) AS total_disease_associations
FROM human_gene_diseases;

SELECT COUNT(*) AS total_disease_genotype_pairs
FROM disease_genotypes;


-- SECTION 42: Check mouse gene and disease relationships

SELECT
    COUNT(*) AS matching_disease_records,
    COUNT(DISTINCT g.gene_accession_id) AS matching_mouse_genes
FROM genes AS g
JOIN human_genes AS h
    ON g.gene_accession_id = h.mouse_gene_id
JOIN human_gene_diseases AS hd
    ON h.hgnc_id = hd.hgnc_id
JOIN diseases AS d
    ON hd.disease_id = d.disease_id;


-- View some matching genes and diseases

SELECT
    g.gene_symbol AS mouse_gene,
    h.human_gene_symbol AS human_gene,
    d.disease_name,
    d.disease_id
FROM genes AS g
JOIN human_genes AS h
    ON g.gene_accession_id = h.mouse_gene_id
JOIN human_gene_diseases AS hd
    ON h.hgnc_id = hd.hgnc_id
JOIN diseases AS d
    ON hd.disease_id = d.disease_id
LIMIT 10;


-- SECTION 43: Create the bespoke homology tables

-- Store species separately so more can be added without new homology columns.
-- Keep the supplied Ensembl genes even if they are not in our main IMPC dataset.

CREATE TABLE IF NOT EXISTS bespoke_species (
    species_id INT PRIMARY KEY,
    species_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS bespoke_gene (
    gene_id VARCHAR(32) PRIMARY KEY,
    gene_name VARCHAR(100),
    species_id INT NOT NULL,
    FOREIGN KEY (species_id)
        REFERENCES bespoke_species(species_id)
);

CREATE TABLE IF NOT EXISTS bespoke_homology (
    mouse_gene_id VARCHAR(32) NOT NULL,
    target_gene_id VARCHAR(32) NOT NULL,
    ancestor VARCHAR(64),
    homology_type VARCHAR(32) NOT NULL,
    target_identity_pct DOUBLE NOT NULL,
    PRIMARY KEY (mouse_gene_id, target_gene_id),
    FOREIGN KEY (mouse_gene_id)
        REFERENCES bespoke_gene(gene_id),
    FOREIGN KEY (target_gene_id)
        REFERENCES bespoke_gene(gene_id),
    CHECK (target_identity_pct BETWEEN 0 AND 100)
);


-- SECTION 44: Import bespoke homology records

-- Import existing GitHub files from data/processed/bespoke/ in order:
-- bespoke_species.csv, bespoke_gene.csv, bespoke_homology.csv.
-- Import into bespoke_species, bespoke_gene and bespoke_homology respectively,
-- before running the counts below. 
-- Then proceed to Section 45.

-- Check how many records were imported

SELECT COUNT(*) AS total_species
FROM bespoke_species;

SELECT COUNT(*) AS total_genes
FROM bespoke_gene;

SELECT COUNT(*) AS total_homology
FROM bespoke_homology;


-- SECTION 45: Validate bespoke homology data

-- Check the total number of homology relationships

SELECT COUNT(*) AS total_homology_pairs
FROM bespoke_homology;


-- Check that mouse genes and target genes
-- belong to the correct species

SELECT COUNT(*) AS incorrect_species
FROM bespoke_homology AS h
JOIN bespoke_gene AS m
    ON h.mouse_gene_id = m.gene_id
JOIN bespoke_gene AS t
    ON h.target_gene_id = t.gene_id
WHERE m.species_id <> 1
   OR t.species_id NOT IN (2, 3);


-- Count homology relationships by target species

SELECT
    s.species_name,
    COUNT(*) AS total_pairs
FROM bespoke_homology AS h
JOIN bespoke_gene AS t
    ON h.target_gene_id = t.gene_id
JOIN bespoke_species AS s
    ON t.species_id = s.species_id
GROUP BY s.species_name;


-- SECTION 46: Check mouse gene matches

-- Count matching genes

SELECT
    COUNT(DISTINCT g.gene_accession_id) AS matching_mgi_genes,
    COUNT(DISTINCT b.gene_id) AS matching_ensembl_genes
FROM genes AS g
JOIN bespoke_gene AS b
    ON BINARY g.gene_symbol = BINARY b.gene_name
WHERE b.species_id = 1;


-- Check for ambiguous gene symbol matches

SELECT
    g.gene_symbol,
    COUNT(DISTINCT g.gene_accession_id) AS mgi_ids,
    COUNT(DISTINCT b.gene_id) AS ensembl_ids
FROM genes AS g
JOIN bespoke_gene AS b
    ON BINARY g.gene_symbol = BINARY b.gene_name
WHERE b.species_id = 1
GROUP BY g.gene_symbol
HAVING mgi_ids > 1 OR ensembl_ids > 1;


-- SECTION 47: Create MGI to Ensembl gene mapping

-- BINARY makes the symbol comparison case-sensitive. 
-- Keep only matches with one distinct Ensembl ID per MGI gene. 
-- These are provisional symbol matches,
-- not confirmed identifier cross-references.

CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_mouse_gene_matches AS
SELECT
    g.gene_accession_id,
    g.gene_symbol,
    MIN(b.gene_id) AS mouse_ensembl_id
FROM genes AS g
JOIN bespoke_gene AS b
    ON BINARY g.gene_symbol = BINARY b.gene_name
WHERE b.species_id = 1
GROUP BY g.gene_accession_id, g.gene_symbol
HAVING COUNT(DISTINCT b.gene_id) = 1;


-- Check the mapping

SELECT COUNT(*) AS matched_genes
FROM v_mouse_gene_matches;


-- SECTION 48: Create the integrated homology view

CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_gene_homology AS
SELECT
    g.gene_accession_id,
    g.gene_symbol AS mouse_gene,
    s.species_name AS target_species,
    t.gene_id AS target_gene_id,
    t.gene_name AS target_gene,
    h.homology_type,
    h.target_identity_pct
FROM v_mouse_gene_matches AS g
JOIN bespoke_homology AS h
    ON g.mouse_ensembl_id = h.mouse_gene_id
JOIN bespoke_gene AS t
    ON h.target_gene_id = t.gene_id
JOIN bespoke_species AS s
    ON t.species_id = s.species_id;


-- Check how many homology relationships we have

SELECT
    COUNT(*) AS total_relationships,
    COUNT(DISTINCT gene_accession_id) AS mouse_genes
FROM v_gene_homology;


-- View 10 examples

SELECT *
FROM v_gene_homology
LIMIT 10;


-- SECTION 49: Validate integrated homology

-- Count relationships for each target species

SELECT
    target_species,
    COUNT(*) AS total_relationships,
    COUNT(DISTINCT gene_accession_id) AS mouse_genes
FROM v_gene_homology
GROUP BY target_species;


-- Check for invalid identity percentages

SELECT COUNT(*) AS invalid_percentages
FROM v_gene_homology
WHERE target_identity_pct IS NULL
   OR target_identity_pct < 0
   OR target_identity_pct > 100;


-- SECTION 50: Check the main database

SELECT
    (SELECT COUNT(*) FROM genes) AS genes,
    (SELECT COUNT(*) FROM analyses) AS analyses,
    (SELECT COUNT(*) FROM parameters) AS parameters,
    (SELECT COUNT(*) FROM diseases) AS diseases,
    (SELECT COUNT(*) FROM lacz_results) AS lacz_results,
    (SELECT COUNT(*) FROM bespoke_homology) AS homology_pairs;


-- SECTION 51: Query gene analyses and parameter groups

SELECT
    g.gene_symbol,
    a.allele_symbol,
    a.analysis_id,
    a.parameter_name,
    a.p_value,
    pg.group_name
FROM v_analyses_parameters AS a
JOIN genes AS g
    ON a.gene_accession_id = g.gene_accession_id
LEFT JOIN parameter_group_membership AS pgm
    ON a.parameter_stable_id = pgm.parameter_stable_id
LEFT JOIN parameter_groups AS pg
    ON pgm.group_id = pg.group_id
ORDER BY g.gene_symbol
LIMIT 20;


-- SECTION 52: Connect parameters to their metadata

-- Link only matching stable IDs. 
-- This allows multiple metadata records for the same parameter and keeps unmatched parameters in the main table.

CREATE TABLE IF NOT EXISTS parameter_metadata_links (
    parameter_stable_id VARCHAR(20) NOT NULL,
    impcParameterOrigId VARCHAR(20) NOT NULL,
    PRIMARY KEY (parameter_stable_id, impcParameterOrigId),
    FOREIGN KEY (parameter_stable_id)
        REFERENCES parameters(parameter_stable_id),
    FOREIGN KEY (impcParameterOrigId)
        REFERENCES parameter_metadata(impcParameterOrigId)
);


-- Populate the linking table

INSERT INTO parameter_metadata_links (
    parameter_stable_id,
    impcParameterOrigId
)
SELECT DISTINCT
    p.parameter_stable_id,
    m.impcParameterOrigId
FROM parameters AS p
JOIN parameter_metadata AS m
    ON p.parameter_stable_id = m.parameter_stable_id;


-- Check the connection

SELECT
    COUNT(*) AS total_links,
    COUNT(DISTINCT parameter_stable_id) AS linked_parameters
FROM parameter_metadata_links;


-- SECTION 53: Connect mouse genes to human disease genes

-- Use the supplied MGI accession ID to connect the disease and IMPC datasets.

CREATE TABLE IF NOT EXISTS mouse_human_gene_links (
    gene_accession_id VARCHAR(20) NOT NULL,
    hgnc_id VARCHAR(20) NOT NULL,
    PRIMARY KEY (gene_accession_id, hgnc_id),
    FOREIGN KEY (gene_accession_id)
        REFERENCES genes(gene_accession_id),
    FOREIGN KEY (hgnc_id)
        REFERENCES human_genes(hgnc_id)
);


-- Populate the linking table

INSERT INTO mouse_human_gene_links (
    gene_accession_id,
    hgnc_id
)
SELECT DISTINCT
    g.gene_accession_id,
    h.hgnc_id
FROM genes AS g
JOIN human_genes AS h
    ON g.gene_accession_id = h.mouse_gene_id;


-- Check the results

SELECT COUNT(*) AS total_links
FROM mouse_human_gene_links;


-- SECTION 54: Connect MGI genes to Ensembl genes

-- Store the symbol-based matches separately and keep their provisional status.

CREATE TABLE IF NOT EXISTS mouse_ensembl_links (
    gene_accession_id VARCHAR(20) PRIMARY KEY,
    mouse_ensembl_id VARCHAR(32) NOT NULL,
    mapping_status VARCHAR(20) NOT NULL,
    FOREIGN KEY (gene_accession_id)
        REFERENCES genes(gene_accession_id),
    FOREIGN KEY (mouse_ensembl_id)
        REFERENCES bespoke_gene(gene_id)
);


-- Populate the linking table

INSERT INTO mouse_ensembl_links (
    gene_accession_id,
    mouse_ensembl_id,
    mapping_status
)
SELECT
    gene_accession_id,
    mouse_ensembl_id,
    'provisional'
FROM v_mouse_gene_matches;


-- Check the connection

SELECT COUNT(*) AS total_links
FROM mouse_ensembl_links;


-- SECTION 55: Update the integrated homology view

-- Use the stored mapping table for the final homology view.

CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_gene_homology AS
SELECT
    g.gene_accession_id,
    g.gene_symbol AS mouse_gene,
    s.species_name AS target_species,
    t.gene_id AS target_gene_id,
    t.gene_name AS target_gene,
    h.homology_type,
    h.target_identity_pct
FROM mouse_ensembl_links AS l
JOIN genes AS g
    ON l.gene_accession_id = g.gene_accession_id
JOIN bespoke_homology AS h
    ON l.mouse_ensembl_id = h.mouse_gene_id
JOIN bespoke_gene AS t
    ON h.target_gene_id = t.gene_id
JOIN bespoke_species AS s
    ON t.species_id = s.species_id;


-- Verify the updated view

SELECT
    COUNT(*) AS total_relationships,
    COUNT(DISTINCT gene_accession_id) AS mouse_genes
FROM v_gene_homology;


-- SECTION 56: Query mouse genes and human diseases

SELECT
    g.gene_symbol AS mouse_gene,
    h.human_gene_symbol AS human_gene,
    d.disease_name,
    d.disease_id
FROM genes AS g
JOIN mouse_human_gene_links AS l
    ON g.gene_accession_id = l.gene_accession_id
JOIN human_genes AS h
    ON l.hgnc_id = h.hgnc_id
JOIN human_gene_diseases AS hd
    ON h.hgnc_id = hd.hgnc_id
JOIN diseases AS d
    ON hd.disease_id = d.disease_id
ORDER BY g.gene_symbol
LIMIT 20;


-- Check the total matched records

SELECT
    COUNT(*) AS disease_associations,
    COUNT(DISTINCT gene_accession_id) AS mouse_genes
FROM mouse_human_gene_links AS l
JOIN human_gene_diseases AS hd
    ON l.hgnc_id = hd.hgnc_id;


-- SECTION 57: Query mouse gene homology

-- View 20 homology relationships

SELECT
    g.gene_symbol AS mouse_gene,
    s.species_name AS target_species,
    t.gene_name AS target_gene,
    h.homology_type,
    h.target_identity_pct,
    l.mapping_status
FROM genes AS g
JOIN mouse_ensembl_links AS l
    ON g.gene_accession_id = l.gene_accession_id
JOIN bespoke_homology AS h
    ON l.mouse_ensembl_id = h.mouse_gene_id
JOIN bespoke_gene AS t
    ON h.target_gene_id = t.gene_id
JOIN bespoke_species AS s
    ON t.species_id = s.species_id
LIMIT 20;


-- Check the total relationships

SELECT
    COUNT(*) AS total_relationships,
    COUNT(DISTINCT gene_accession_id) AS mouse_genes
FROM v_gene_homology;


-- SECTION 58: Final data integrity checks

-- 1. Check that alleles belong to the correct genes

SELECT COUNT(*) AS mismatched_alleles
FROM analyses AS a
JOIN alleles AS al
    ON a.allele_symbol = al.allele_symbol
WHERE a.gene_accession_id <> al.gene_accession_id;


-- 2. Check missing parameter IDs

SELECT COUNT(*) AS missing_parameter_ids
FROM analyses
WHERE parameter_stable_id IS NULL;


-- 3. Check that every analysis has 11 LacZ tissue records

SELECT COUNT(*) AS incorrect_lacz_counts
FROM (
    SELECT a.analysis_id
    FROM analyses AS a
    LEFT JOIN lacz_results AS l
        ON a.analysis_id = l.analysis_id
    GROUP BY a.analysis_id
    HAVING COUNT(l.tissue_name) <> 11
) AS checks;


-- SECTION 59: Validate p-values and parameter groups

-- 1. Check for invalid p-values

SELECT COUNT(*) AS invalid_p_values
FROM analyses
WHERE p_value < 0
   OR p_value > 1;


-- 2. Count missing p-values

SELECT COUNT(*) AS missing_p_values
FROM analyses
WHERE p_value IS NULL;


-- 3. Check for duplicate parameter-group assignments

SELECT
    parameter_stable_id,
    group_id,
    COUNT(*) AS occurrences
FROM parameter_group_membership
GROUP BY parameter_stable_id, group_id
HAVING COUNT(*) > 1;


-- SECTION 60: Check parameter-group coverage

-- Count parameters in each group

SELECT
    pg.group_name,
    COUNT(pgm.parameter_stable_id) AS total_parameters
FROM parameter_groups AS pg
LEFT JOIN parameter_group_membership AS pgm
    ON pg.group_id = pgm.group_id
GROUP BY pg.group_id, pg.group_name
ORDER BY total_parameters DESC;


-- Count grouped and ungrouped parameters

SELECT
    COUNT(DISTINCT p.parameter_stable_id) AS all_parameters,
    COUNT(DISTINCT pgm.parameter_stable_id) AS grouped_parameters,
    COUNT(DISTINCT p.parameter_stable_id)
      - COUNT(DISTINCT pgm.parameter_stable_id) AS ungrouped_parameters
FROM parameters AS p
LEFT JOIN parameter_group_membership AS pgm
    ON p.parameter_stable_id = pgm.parameter_stable_id;

-- SECTION 61: Review parameter classifications

-- Check which parameters are assigned to Images

SELECT
    p.parameter_name,
    pg.group_name
FROM parameter_group_membership AS pgm
JOIN parameters AS p
    ON pgm.parameter_stable_id = p.parameter_stable_id
JOIN parameter_groups AS pg
    ON pgm.group_id = pg.group_id
WHERE pg.group_name = 'Images'
ORDER BY p.parameter_name;


-- View examples of ungrouped parameters

SELECT
    p.parameter_stable_id,
    p.parameter_name
FROM parameters AS p
LEFT JOIN parameter_group_membership AS pgm
    ON p.parameter_stable_id = pgm.parameter_stable_id
WHERE pgm.parameter_stable_id IS NULL
ORDER BY p.parameter_name
LIMIT 20;

-- Final integrity and performance check

-- Confirm the p-value constraint exists. 
-- EXPLAIN shows the query plan for retrieving an allele's phenotype results; 
-- it is not a timing benchmark.

SELECT CONSTRAINT_NAME, CHECK_CLAUSE
FROM information_schema.CHECK_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = DATABASE()
  AND CONSTRAINT_NAME = 'chk_p_value_range';

EXPLAIN
SELECT analysis_id, allele_symbol, p_value
FROM analyses
WHERE allele_symbol = 'Chrm4<tm1b(EUCOMM)Hmgu>'
ORDER BY p_value;
