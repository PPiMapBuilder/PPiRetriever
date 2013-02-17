-- database clean up
drop table protein cascade;
drop table experimental_system cascade;
drop table homology cascade;
drop table interaction cascade;
drop table organism cascade;
drop table interaction_data cascade;
drop table source_database cascade;
drop table publication cascade;


-- database creation
create table if not exists protein (
	id serial primary key,
	uniprot_id varchar(8) not null unique,
	gene_name varchar(250) not null
);

create table if not exists source_database (
	name varchar(250) primary key
);

create table if not exists experimental_system (
	name varchar(250) primary key
);

create table if not exists organism (
	tax_id numeric primary key,
	name varchar(250) unique not null
);

create table if not exists publication (
	pubmed_id serial primary key,
	first_author varchar(250) not null,
	pub_date date not null
);

create table if not exists homology (
	protein_A integer references protein(id) not null,
	protein_B integer references protein(id) not null,
	unique(protein_a, protein_b)
);

create table if not exists interaction_data (
	id serial primary key,
	bd_source_name varchar(250) references source_database(name) not null,
	pubmed_id integer references publication(pubmed_id) not null,
	organism_tax_id integer references organism(tax_id) not null,
	experimental_system varchar(250) references experimental_system(name) not null
);

create table if not exists interaction (
	id serial primary key,
	protein_id1 integer references protein(id) not null,
	protein_id2 integer references protein(id) not null,
	interaction_data_id integer references interaction_data(id) not null
);


-- some known or default values
insert into source_database(name) values
('hprd'),
('biogrid'),
('intact'),
('dip'),
('bind'),
('mint');

insert into organism(tax_id, name) values 
(3702,'Arabidopsis thaliana'),
(6239,'Caenorhabditis elegans'),
(7227,'Drosophilia melanogaster'),
(9606,'Homo sapiens'),
(10090,'Mus musculus'),
(4932,'Saccharomyces cerevisiae'),
(4896,'Schizosaccharomyces pombe');

