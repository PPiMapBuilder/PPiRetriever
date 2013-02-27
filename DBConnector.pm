package DBConnector;

use strict;
use warnings;
use Interaction;
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

sub _commit() {
	my ($this) = @_;
	$this->{'_dbh'}->commit();
}

sub _rollback() {
	my ($this) = @_;
	$this->{'_dbh'}->rollback();
}

sub disconnect () {
	my ($this) = shift;
	eval { $this->{'dbh'}->disconnect() };
}

sub insert() {
# Insère une liste de PPI dans la base de données
#
# TODO : définir ce qui doit être retourné
#
#
# DESCRIPTION
# On insère les données "dures" dans un premier temps, à savoir:
# notation:	- <table> (<champ1>, <champ2>, <etc>)
#
#	- protein (uniprot_id, gene_name)
#	- source_database (name)
#	- publication (pubmed_id)
# On récupère alors les identifiants des données nouvellement insérées, ou les ID existants le cas échéant.
#
# On récupère ensuite les données "fixes", à savoir
# 	- organism (tax_id)
# 	- experimental_system (name)
#
# Il nous reste à remplir DANS CET ORDRE (!) les tables de relations avec les données, à savoir
#	- interaction_data (db_source_name, pubmed_id, organism_tax_id,experimental_system)
#	- interaction (protein_id1, protein_id2, interaction_data_id)
#  (- homogolgy) -> pour plus tard


# Petit rappel sur l'organisation des requêtes
# 	- on prépare une requete, avec "?" pour symboliser les variables
#	- on execute autant qu'on veut la requete, avec les variables en paramètre
#	- on commit le tout quand ça nous arrange

	my ( $this, $PPiGrp ) = @_;
	

#	print "[INFO] preparing statements\n";
#--- preparer toutes les requetes (statements) pour le groupe de PPi ---#
	# INSERT statements
	my $sth_insert_protein = $this->{'_dbh'}->prepare("INSERT INTO protein(uniprot_id, gene_name) VALUES (?, ?) RETURNING id");
	my $sth_insert_publication = $this->{'_dbh'}->prepare("INSERT INTO publication(pubmed_id) VALUES (?) RETURNING pubmed_id");
	my $sth_insert_exp_system = $this->{'_dbh'}->prepare("INSERT INTO experimental_system(name) VALUES (?) RETURNING name");
	my $sth_insert_src_db = $this->{'_dbh'}->prepare("INSERT INTO source_database(name) VALUES (?) RETURNING name");
	my $sth_insert_organism = $this->{'_dbh'}->prepare("INSERT INTO organism(tax_id) VALUES (?) RETURNING tax_id");
	my $sth_insert_interaction_data = $this->{'_dbh'}->prepare("INSERT INTO interaction_data(db_source_name, pubmed_id, organism_tax_id,experimental_system) VALUES (?,?,?,?) RETURNING id");
	my $sth_insert_interaction = $this->{'_dbh'}->prepare("INSERT INTO interaction(protein_id1, protein_id2) VALUES (?,?) RETURNING id");
#	my $sth_insert_homology = $this->{'_dbh'}->prepare("INSERT INTO homology(protein_a, protein_b) VALUES (?, ?)");
	my $sth_insert_link_data_interaction = $this->{'_dbh'}->prepare("INSERT INTO link_data_interaction(interaction_id, interaction_data_id) VALUES (?,?)");


	# SELECT statements
	my $sth_select_protein = $this->{'_dbh'}->prepare("SELECT id FROM protein WHERE uniprot_id = ? AND gene_name = ?");
	my $sth_select_src_db = $this->{'_dbh'}->prepare("SELECT name FROM source_database WHERE name = ?");
	my $sth_select_publication = $this->{'_dbh'}->prepare("SELECT pubmed_id FROM publication WHERE pubmed_id = ?");
	my $sth_select_organism_from_tax_id = $this->{'_dbh'}->prepare("SELECT tax_id FROM organism WHERE tax_id = ?");
	my $sth_select_organism_from_name = $this->{'_dbh'}->prepare("SELECT tax_id FROM organism WHERE name = ?");
	my $sth_select_exp_sys = $this->{'_dbh'}->prepare("SELECT name FROM experimental_system WHERE name = ?");
	my $sth_select_interaction_data = $this->{'_dbh'}->prepare("SELECT id FROM interaction_data WHERE db_source_name = ? AND pubmed_id = ? AND organism_tax_id = ? AND experimental_system = ?");
	my $sth_select_interaction = $this->{'_dbh'}->prepare("SELECT id FROM interaction WHERE protein_id1 = ? AND protein_id2 = ?");
	
	# no update statement needed

#	print "[INFO] Start reading PPi\n";


	# parcours de la liste de PPi
	foreach my $PPi ( @{$PPiGrp} ) {

		# les différents ID nécessaires pour peupler les tables de relations
		# /!\ pubmed et sysExp sont des listes d'ID, il faudra mettre toutes les combinaisons dans interaction_data (et donc plusieurs insertions)
		my $idInteractorA     = undef;
		my $idInteractorB     = undef;
		my $idInteraction     = undef;
		my $db_source		  = $PPi->{database};
		my $tax_id			  = $PPi->{organism};
		my @idInteractionData = ();
		my @idPublications	  = @{ $PPi->{pubmed} };
		my @idSysExp		  = @{ $PPi->{sys_exp} };
	
	
		# execution des statements
#		print "[INFO] insertion interacteur A\n";
	
		#--- insertion de l'interacteur A et récupération de son ID ---#
		eval {
			$sth_insert_protein->execute( $PPi->getUniprotA(), $PPi->getGeneNameA() );
			$this->_commit();
			$idInteractorA = (keys $sth_insert_protein->fetchall_hashref('id'))[0];
#			print "[INTERACTOR A]\t",$PPi->getUniprotA(), ":", $PPi->getGeneNameA(),"\n";
			1;
		} or do {
			$this->_rollback();
			$sth_select_protein->execute( $PPi->getUniprotA(), $PPi->getGeneNameA() );
			($idInteractorA) = $sth_select_protein->fetchrow_array();
		};
	
	
		#--- insertion de l'interacteur B puis récupération de son ID ---#
#		print "[INFO] insertion interacteur B\n";

		eval {
			$sth_insert_protein->execute( $PPi->getUniprotB(), $PPi->getGeneNameB() );
			$this->_commit();
			($idInteractorB) = (keys $sth_insert_protein->fetchall_hashref('id'))[0];
#			print "[INTERACTOR B]\t",$PPi->getUniprotB(), ":", $PPi->getGeneNameB(),"\n";
			1;
		} or do {
			$this->_rollback();
			$sth_select_protein->execute( $PPi->getUniprotB(), $PPi->getGeneNameB() );
			($idInteractorB) = $sth_select_protein->fetchrow_array();
		};
	
	
#		print "[INFO] insertion publications\n";	
		#--- Insertion de la liste des pubmedIDs ---#
		foreach my $pubmedid ( @{ $PPi->{pubmed} } ) {
			eval {
				$sth_insert_publication->execute($pubmedid);		
				$this->_commit();
#				print "[PUBMED ID]\t", $pubmedid,"\n";
				1;
			} or do {
				$this->_rollback();
			};
		}
	
	
#		print "[INFO] insertion experimental systems\n";
		#--- Insertion de la liste des systemes experimentaux ---#
		foreach my $sysexp ( @{ $PPi->{sys_exp} } ) {
			eval {
				$sth_insert_exp_system->execute($sysexp);
				$this->_commit();
#				print "[EXP SYSTEM]\t", $sysexp,"\n";		
				1;
			} or do {
				$this->_rollback();
			};
		}
	
#		print "----------------------------------------------------------\n\n";
#	  	print "Interactor A under ID: ", $idInteractorA, "\n";
#		print "Interactor B under ID: ", $idInteractorB, "\n";
#		print "Pubmed IDs : @idPublications \n";
#		print "ExpSystems : @idSysExp \n";
#		print "----------------------------------------------------------\n\n";
	
		#--- Insertion des interaction_data ---#
		foreach my $pubmed_id (@idPublications) {
			foreach my $sys_exp (@idSysExp) {
				eval {
					$sth_insert_interaction_data->execute(
						$PPi->{database},
						$pubmed_id,
						$PPi->{organism},
						$sys_exp					
					);
					$this->_commit();	
					push (@idInteractionData , (keys $sth_insert_protein->fetchall_hashref('id'))[0]);
					1;
				} or do {
					$this->_rollback();
					$sth_select_interaction_data->execute(
						$PPi->{database},
						$pubmed_id,
						$PPi->{organism},
						$sys_exp
					);
					push (@idInteractionData , $sth_select_interaction_data->fetchrow_array());
				};
			}
		}

		
		#--- next PPi if we cannot properly add an interaction ---#
		# thus we store in the database all information about the interaction (which can be reused)
		next unless (@idInteractionData && defined($idInteractorA) && defined($idInteractorB));
		
		
		#--- Insertion de l'interaction ---#
		eval {
			$sth_insert_interaction->execute( $idInteractorA, $idInteractorB );
			$this->_commit();
			($idInteraction) = (keys $sth_insert_interaction->fetchall_hashref('id'))[0];
			1;
		} or do {
			$this->_rollback();
			$sth_select_interaction->execute( $idInteractorA, $idInteractorB );
			($idInteraction) = $sth_select_interaction->fetchrow_array();
		};
		
		
		
		#--- Insertion dans link_data_interaction ---#
		foreach my $idInteractionData (@idInteractionData) {
#			print ">>$idInteraction :: $idInteractionData\n";
			eval {
				$sth_insert_link_data_interaction->execute( $idInteraction, $idInteractionData );
				$this->_commit();
				1;
			} or do {
				$this->_rollback();
			};
		}
	}
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

1;

__END__

commentaires et documentation
