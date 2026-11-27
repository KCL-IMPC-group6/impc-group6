CREATE DATABASE group6_impc_phenotype;

USE group6_impc_phenotype;

CREATE TABLE parameter_table (
    parameter_stable_id VARCHAR(20) NOT NULL,
    parameter_name VARCHAR(200),
    PRIMARY KEY (parameter_stable_id)
);

CREATE TABLE parameter_group (
    group_id INT NOT NULL,
    group_name VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    PRIMARY KEY (group_id),
    UNIQUE (group_name)
);

CREATE TABLE parameter_group_member (
    group_id INT NOT NULL,
    parameter_stable_id VARCHAR(20) NOT NULL,
    PRIMARY KEY (group_id, parameter_stable_id),
    FOREIGN KEY (group_id) 
        REFERENCES parameter_group (group_id),
    FOREIGN KEY (parameter_stable_id)
        REFERENCES parameter_table (parameter_stable_id)
);