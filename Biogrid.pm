package Biogrid;

use warnings;    # Avertissement des messages d'erreurs
use strict;      # Vérification des déclarations
use Carp;        # Utile pour émettre certains avertissements

use DBpublic;
use Interaction;
use LWP::Simple;

$SIG{INT} = \&catch_ctrlc;

our @ISA = ("DBpublic");

sub new {
	my ($classe) = @_;                  #on passe les données au constructeur
	my $this = $classe->SUPER::new();
	bless( $this, $classe );            #lie la référence à la classe
	return $this;                       #on retourne la référence consacrée

}

sub parse {

	my ($this) = @_;

	my %hash_orga_tax = ( # Hash to easily retrieve the correspondance between the taxonomy id and the seven reference organisms
		'3702'  => 'Arabidopsis thaliana',
		'6239'  => 'Caenorhabditis elegans',
		'7227'  => 'Drosophilia Melanogaster',
		'9606'  => 'Homo sapiens',
		'10090' => 'Mus musculus',
		'4932'  => 'Saccharomyces cerevisiae',
		'4896'  => 'Schizosaccharomyces pombe'
	);

	my $hash_orga_tax = {}; # A hash to store the uniprot id corresponding to a gene name and an organism
				# This avoid to run the same request several times in the uniprot.org server
	open( gene_name_to_uniprot_file, "gene_name_to_uniprot_database.txt" );  # A file to keep this hash
	while (<gene_name_to_uniprot_file>) { # We initialize the hash with the data contained in the file
		chomp($_);
		my @convertion_data = split( /\t/, $_ );
		$hash_orga_tax->{ $convertion_data[0] }->{ $convertion_data[2] } =
		  $convertion_data[1];
	}
	close(gene_name_to_uniprot_file);

	open( data_file, "BIOGRID.txt" ); # We open the database file
	my $database = 'Biogrid'; # We note the corresponding database we are using

	my $i = 1;

	open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" ); # During this time, we complete the file which contains the uniprot id for a gene name and an organism
	while (<data_file>) {

		chomp($_);

		if ( $_ =~ m/^#/ig ) {
			next;
		}

		if ($i == 10) {
			last;
		}

		my $intA      = undef;
		my $uniprot_A = undef;
		my $intB      = undef;
		my $uniprot_B = undef;
		my $exp_syst  = undef;
		my $pubmed    = undef;
		my $origin    = undef;
		my $pred      = undef;

		my $orga_query;

		my @data = split( /\t/, $_ ); # We split the line into an array

		foreach my $tax_id ( keys %hash_orga_tax ) {
			if ( $data[16] eq $tax_id ) { # If the taxonomy id is present
				$origin = $hash_orga_tax{$tax_id}; # We put the organism name into the "origin" variable
				$orga_query = "$hash_orga_tax{$tax_id} [$tax_id]";
				if ( $tax_id eq '9606' ) { #  If the organism is Homo sapiens, the "predictive from" will be "Human"
					$pred = 'Human';
				}
				else { # Else it will be "Interolog"
					$pred = 'Interolog';
				}
				last;
			}

		}

		if ( !$origin ) { # If the origin is null, so if the interaction is not from one of the seven organisms, we do not consider this interaction
			next;
		}

		#my $internet = undef; # Temporary variable to see the number of request to the uniprot.org server

		$intA = $data[7]; # We retrieve the first interactor
		if ( exists( $hash_orga_tax->{$intA}->{$orga_query} ) ) { # If the uniprot id has already been retrieved (and is now stored in the file)
			$uniprot_A = $hash_orga_tax->{$intA}->{$orga_query}; # we retrieve it from the file
		}
		else { # If we need to retrieve it from the web
			$uniprot_A = gene_name_to_uniprot_id( $intA, $orga_query ); # We call the corresponding function
			$hash_orga_tax->{$intA}->{$orga_query} = $uniprot_A; # We store it in the hash
			print gene_name_to_uniprot_file "$intA\t$uniprot_A\t$orga_query\n"; # We store it in the file
			#$internet .= 'i'; # We indicate that we used an internet connection
		}

		# Same principle as above
		$intB = $data[8];
		if ( exists( $hash_orga_tax->{$intB}->{$orga_query} ) ) {
			$uniprot_B = $hash_orga_tax->{$intB}->{$orga_query};
		}
		else {
			$uniprot_B = gene_name_to_uniprot_id( $intB, $orga_query );
			$hash_orga_tax->{$intB}->{$orga_query} = $uniprot_B;
			print gene_name_to_uniprot_file "$intB\t$uniprot_B\t$orga_query\n";
			# $internet .= 'i';
		}

		if ( !defined($uniprot_A) || !defined($uniprot_B) ) { # If the uniprot id was not retrieved, we do not keep the interaction
			next;
		}

		$exp_syst = $data[11]; # We retrieve the experimental system
		$pubmed   = $data[14] . "[uid]"; # We retrieve the pubmed id

		# Construction of the interaction elements
		my @A = ( $uniprot_A, $intA );
		my @B = ( $uniprot_B, $intB );
		my @pubmed  = ($pubmed);
		my @sys_exp = ($exp_syst);

		# Construction of the interaction object
		my $interaction = Interaction->new( \@A, \@B, $origin, $database, \@pubmed, \@sys_exp );

		$this->SUPER::addInteraction($interaction);

		#print "$i $internet\t$intA\t$uniprot_A\t$intB\t$uniprot_B\t$exp_syst\t$origin\t$database\t$pubmed\t$pred\n"; # Input for debug

		$i++;

	}
}


sub download {
	my ($this) = @_;
	
	my $saveFile = "BIOGRID-ALL-LATEST.tab2.zip";
	my $url = "http://thebiogrid.org/downloads/archives/Latest%20Release/".$saveFile;
	
	#working folder (with the name of current DB)
	my $folder = $this->setDownloadFolder(uc(__PACKAGE__));

	#if unable to create folder
	no warnings 'numeric';
	return -3 if(int($folder) == -1); #Error code -3: unable to get/create folder
	use warnings 'numeric';
	
	#Preparing the user agent for downloading
	my $ua = LWP::UserAgent->new;
	$ua->agent('Mozilla/5.5 (compatible; MSIE 5.5; Windows NT 5.1)');
	
	#Downloading database
	print("Downloading ".__PACKAGE__." data...\n");
	my $savePath = $folder . $saveFile;

	#If download file already exists => saving the old one as old.
	my $oldFile = $folder."old-".$saveFile;
	move($savePath, $oldFile) if (-e $savePath);

	#Downloading the date file in DIP.txt.gz
	$ua->show_progress('true value');
	$ua->get($url, ':content_file' => $savePath );
	print("Done!\n");
	
	#Compare new and old file (if exists)
	if(-e $oldFile) {
		if($this->md5CheckFile($savePath, $oldFile)) {
			return -1; # No need for update old and new are the same
		}
	}
	
	#Uncompressing file
	my $fileUncompressed = $this->fileUncompressing($savePath);
		
	#Uncompressing failed
	no warnings 'numeric';
	return -4 if ($fileUncompressed == -1);
	use warnings 'numeric';
	
	#Make sure the file was correctly downloaded
	if ( -e $fileUncompressed ) {
		return $fileUncompressed;
	} else {
		print("Download failed.\n");
		return -2;    #No data recieved from DIP
	}
}

1;

