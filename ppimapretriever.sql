create table Protein (
	id serial primary key,
	uniprot_id varchar(8) not null unique,
	gene_name varchar(250) not null
);

create table SourceDatabase (
	name varchar(250) primary key
);

create table ExperimentalSystem (
	name varchar(250) primary key
);

create table Organism (
	tax_id numeric primary key,
	name varchar(250) unique not null
);

create table Publication (
	pubmedId serial primary key,
	firstAuthor varchar(250) not null,
	pubDate date not null
);

create table Homology (
	proteinA integer references Protein(id),
	proteinB integer references Protein(id),
	unique(proteinA, proteinB)
);

