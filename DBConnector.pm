package DBConnector;

use strict;
use warnings;
use DBI;

use Data::Dumper;


sub new() {
	my ( $class, $host, $port, $dbname, $username, $password ) = @_;

	my $this = {
		'_host'     => $host,
		'_port'     => $port,
		'_dbname'   => $dbname,
		'_username' => $username,
		'_password' => $password,
		'_dbh'      => undef,

		# should make following arguments editable
		'_autoCommit' => 0,
		'_raiseError' => 1,
		'_printError' => 0
	};

	$this->{'_dbh'} = DBI->connect(
		'dbi:Pg:dbname=' . $dbname . ';host=' . $host . ';port=' . $port,
		$username,
		$password,
		{
			AutoCommit => $this->{'_autoCommit'},
			RaiseError => $this->{'_raiseError'},
			PrintError => $this->{'_printError'}
		}
	);

	bless( $this, $class );
	return $this;
}





sub insert() {
	
# Insère une liste de PPI dans la base de données
# VERSION 1
#
# TODO : gerer les exceptions avec des blocs eval
# TODO : récuperer les ID si deja existants (POSTGRESQL : INSERT ... RETURNING id)
# TODO : inserer dans les tables de relations SI tout à été inséré ou récupéré correctement
#
#
# DESCRIPTION
# On insère les données "dures" dans un premier temps, à savoir:
#	- protein (uniprot_id, gene_name)
#	- source_database (name)
#	- publication (pubmed_id)
# On récupère alors les identifiants des données nouvellement insérées, ou les id existants le cas échéant.
#
# On récupère ensuite les données "fixes", à savoir
# 	- organism(tax_id)
# 	- experimental_system(name)
#
# Il nous reste à remplir DANS CET ORDRE (!) les tables de relations avec les données, à savoir
#	- interaction_data
#	- interaction
#	( - homogolgy ) -> pour plus tard
#

# Petit rappel sur l'organisation des requêtes
# 	- on prépare une requete, avec "?" pour symboliser les variables
#	- on execute autant qu'on veut la requete, avec les variables en paramètre
#	- on commit le tout quand ça nous arrange

	my ( $this, $PPiGrp ) = @_;

	# preparer toutes les requetes (statements) pour le groupe de PPi

# INSERT statements
	my $sth_insert_protein = $this->{'_dbh'}->prepare("INSERT INTO protein(uniprot_id, gene_name) VALUES (?, ?)");
	my $sth_insert_publication = $this->{'_dbh'}->prepare("INSERT INTO publication(pubmed_id) VALUES (?)");
	my $sth_insert_exp_system = $this->{'_dbh'}->prepare("INSERT INTO experimental_system(name) VALUES (?)");
	my $sth_insert_src_db = $this->{'_dbh'}->prepare("INSERT INTO source_database(name) VALUES (?)");
	my $sth_insert_organism = $this->{'_dbh'}->prepare("INSERT INTO organism(tax_id) VALUES (?)");
#	my $sth_insert_homology = $this->{'_dbh'}->prepare("INSERT INTO homology(protein_a, protein_b) VALUES (?, ?)");
	my $sth_insert_interaction_data = $this->{'_dbh'}->prepare("INSERT INTO interaction_data(db_source_name, pubmed_id, organism_tax_id,experimental_system ) VALUES (?,?,?,?)");
	my $sth_insert_interaction = $this->{'_dbh'}->prepare("INSERT INTO interaction(protein_id1, protein_id2, interaction_data_id) VALUES (?,?,?)");


# SELECT statements
	my $sth_select_protein = $this->{'_dbh'}->prepare("SELECT id FROM protein WHERE uniprot_id = ? AND gene_name = ?");
	my $sth_select_src_db = $this->{'_dbh'}->prepare("SELECT name FROM source_database WHERE name = ?");
	my $sth_select_publication = $this->{'_dbh'}->prepare("SELECT pubmed_id FROM publication WHERE pubmed_id = ?");
	my $sth_select_organism_from_tax_id = $this->{'_dbh'}->prepare("SELECT tax_id FROM organism WHERE tax_id = ?");
	my $sth_select_organism_from_name = $this->{'_dbh'}->prepare("SELECT tax_id FROM organism WHERE name = ?");
	my $sth_select_exp_sys = $this->{'_dbh'}->prepare("SELECT name FROM experimental_system WHERE name = ?");
	
# no update needed	

	# parcours de la liste de PPi
	foreach my $PPi ( @{$PPiGrp} ) {

		# les différents ID nécessaires pour peupler les tables de relations
		# /!\ pubmed et sysExp sont des listes d'ID, il faudra mettre toutes les combinaisons dans interaction_data (et donc plusieurs insertions)
		my $idInteractorA		= -1;
		my $idInteractorB		= -1;
		my $idInteractionData	= -1;
		my @idPublications		= undef;
		my @idSysExp			= undef;


		# execution des statements
		
#--- insertion de l'interacteur A puis récupération de son ID ---#
		# trying to insert the interactorA
		eval {			
			$sth_insert_protein->execute( $PPi->getUniprotA(), $PPi->getGeneNameA());
			1;
		} or do {
			warn "INSERT FAIL A", $PPi->getUniprotA(), " ", $PPi->getGeneNameA() , "\n";
		};
			
		# trying to find the ID for interactor A
		eval {
			$sth_select_protein->execute($PPi->getUniprotA(), $PPi->getGeneNameA());
			($idInteractorA) = $sth_select_protein->fetchrow_array();
			1;
		} or do {
			# if the interactor wasnt inserted and it doesnt exists, there is a big problem!
			die ("Cannot get any data for ", $PPi->getUniprotA(),"/", $PPi->getGeneNameA());
		};

		print "Interactor A under ID: ", $idInteractorA, "\n";


#--- insertion de l'interacteur B puis récupération de son ID ---#
		# trying to insert the interactorB
		eval {
			$idInteractorB = $sth_insert_protein->execute( $PPi->getUniprotB(), $PPi->getGeneNameB());
			1;
		} or do {
			warn "FAIL INSERT B : ", $PPi->getUniprotB(), " ", $PPi->getGeneNameB() , "\n";			
		};
		
		# trying to find the ID for interactorB		
		eval {
			$sth_select_protein->execute($PPi->getUniprotB(), $PPi->getGeneNameB());
			($idInteractorB) = $sth_select_protein->fetchrow_array();
			1;
		} or do {
			warn "non, tjrs pas envie pour B!\n";
		};
		print "Interactor B under ID: ", $idInteractorB, "\n";
		
#--- Here we normally have IDs for interactors A & B ---#


# TODO récupérer la liste des ID correspondant aux publications concernées
# Possible de le faire en passant une liste à ->execute() me semble-t-il
#
#   		foreach my $pubmedid ( @{ $PPi->{pubmed} } ) {
#				$sth_insert_publication->execute($pubmedid) ;
#   		}
		

# TODO récupérer la liste des ID correspondant aux systemes expérimentaux concernés
# 
#			foreach ( @{ $PPi->{sys_exp} } ) {	
#				$sth_insert_exp_system->execute($_) ;
#			}

# TODO peupler la table interaction_data puis récuperer l'ID associé
# TODO peupler la table interaction
	

# TODO : Commit pour chaque PPi (comme maintenant) ou pour le pool de PPi entier ??
		$this->{'_dbh'}->commit();
	}

}

sub disconnect () {
	my ($this) = shift;
	eval { $this->{'dbh'}->disconnect() };
}

sub DESTROY {
	my ($this) = shift;
	$this->disconnect();
}

#-------------- DEBUG SUBs -------------#

sub dbg_select() {
	my ($this) = @_;

	my $sth = $this->{'_dbh'}->prepare("select * from organism");
	$sth->execute();
	my $hash_ref = $sth->fetchall_hashref('tax_id');

	return $hash_ref;
}

sub p($) {
	print Dumper @_;
}

1;

__END__

commentaires et documentation
