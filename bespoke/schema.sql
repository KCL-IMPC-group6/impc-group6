create database if not exists bespoke_dev
character set utf8mb4
collate utf8mb4_bin;

use bespoke_dev;

select database();

create table if not exists bespoke_species (
    species_id int primary key,
    species_name varchar(50) not null unique 
) engine = InnoDB;

create table if not exists bespoke_gene (
    gene_id varchar(32) primary key,
    gene_name varchar(100),
    species_id int not null,
    index(gene_name),
    foreign key (species_id)
        references bespoke_species(species_id)
) engine = InnoDB;

CREATE TABLE if not exists bespoke_homology (
    mouse_gene_id VARCHAR(32) not null,
    target_gene_id VARCHAR(32) not null,
    ancestor VARCHAR(64),
    homology_type VARCHAR(32) not null,
    target_identity_pct DOUBLE not null,
    primary key (mouse_gene_id, target_gene_id),
    foreign key (mouse_gene_id)
        references bespoke_gene(gene_id),
    foreign key (target_gene_id)
        references bespoke_gene(gene_id),
    CHECK (target_identity_pct BETWEEN 0 AND 100)
) engine = InnoDB;


SHOW TABLES FROM bespoke_dev;





