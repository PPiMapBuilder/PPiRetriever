package Mint;

use strict;      #Variable declaration control

use DBpublic;
use Interaction;

use LWP::UserAgent;
use LWP::Simple;
use File::Copy;
use Net::FTP;

$SIG{INT} = \&catch_ctrlc;

our @ISA = ("DBpublic");


sub new {
	my ($classe, $connector) = @_;                  #Sending arguments to constructor
	my $this = $classe->SUPER::new($connector);
	bless( $this, $classe );            #Linking the reference to the class
	return $this;                       #Returning the blessed reference
}


sub parse {

	my ( $this, $stop, $adresse ) = @_;

	$stop = defined($stop) ? $stop : -1;
	$adresse ||=1;

	my %hash_orga_tax =
	  ( # Hash to easily retrieve the correspondance between the taxonomy id and the seven reference organisms
		'3702'  => 'Arabidopsis thaliana',
		'6239'  => 'Caenorhabditis elegans',
		'7227'  => 'Drosophilia Melanogaster',
		'9606'  => 'Homo sapiens',
		'10090' => 'Mus musculus',
		'4932'  => 'Saccharomyces cerevisiae',
		'4896'  => 'Schizosaccharomyces pombe'
	  );

my %hash_error; #hash of error, retrieve of uniprot or gene name from internet; 
	my %hash_uniprot_id; # A hash to store the uniprot id corresponding to a gene name and an organism
	      # This avoid to run the same request several times in the uniprot.org server
	 if (-f "gene_name_to_uniprot_database.txt")   {
	 	open( gene_name_to_uniprot_file, "gene_name_to_uniprot_database.txt" );
	 	while (<gene_name_to_uniprot_file>) {      # We initialize the hash with the data contained in the file
			chomp($_);
			my @convertion_data = split( /\t/, $_ );
			$hash_uniprot_id{ $convertion_data[0] }->{ $convertion_data[2] } =
		  	$convertion_data[1];
		}
		close(gene_name_to_uniprot_file);
	 }   
	 print "[DEBUG : MINT] list of uniprot/gene has been load\n" if ($main::verbose);

	my %hash_locusGene;
	if (-f "locus_to_gene_name.txt") {
		open ( locus_to_gene_name, "locus_to_gene_name.txt");
		while ( <locus_to_gene_name> ) {
			if (/^(\S+)\s(\S+)$/) {
				$hash_locusGene{$1} = $2;
			}
		}
		close locus_to_gene_name;
	}

	open( data_file, $adresse );    # We open the database file
	my $database = 'mint';  # We note the corresponding database we are using

	my $i = 0;

	open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" )
	  ; # During this time, we complete the file which contains the uniprot id for a gene name and an organism
	open (locus, ">>locus_to_gene_name.txt");
	while (<data_file>) {
		print "\n---------------------------------------------------\n" if ($main::verbose);
		chomp($_);

		next if ( $_ =~ m/^#/ig);
		

		last if ( $i == $stop );

		my $intA      = undef;
		my $uniprot_A = undef;
		my $intB      = undef;
		my $uniprot_B = undef;
		my $exp_syst  = undef;
		my $pubmed    = undef;
		my $origin    = undef;
		my $pred      = undef;


		my $orga_query;

		my @data = split( /\t/, $_ );    # We split the line into an array

		if ($data[10] =~ /taxid:(\d+)/) {
			$origin = $1 if (defined($hash_orga_tax{$1}));
		}
		
		if ( !$origin )
		{ # If the origin is null, so if the interaction is not from one of the seven organisms, we do not consider this interaction
			next;
		} else {
			$orga_query = "$hash_orga_tax{$origin} [$origin]";
			print "[DEBUG : MINT] Origin : $origin\n" if ($main::verbose);
		}


		if ($data[0] =~ /entrezgene\/locuslink:(\d+)/) {
			$intA = $1; # We retrieve the first interactor
			next if (!defined($intA));
			
			print "[DEBUG : MINT] locus link A : $intA\n" if ($main::verbose);
		
			if ( exists( $hash_uniprot_id{$intA}->{$orga_query} ) ) { # If the uniprot id has already been retrieved (and is now stored in the file)
				$uniprot_A = $hash_uniprot_id{$intA}->{$orga_query}; # we retrieve it from the file
				print "[DEBUG : MINT] uniprot A : $uniprot_A retrieve from file\n" if ($main::verbose);
			}
			else { # If we need to retrieve it from the web
				$uniprot_A = $this->gene_name_to_uniprot_id( $intA, $orga_query ); # We call the corresponding function
				if ($uniprot_A eq "1" || $uniprot_A eq "0") {
					$hash_error{$intA} = $uniprot_A;
					print "[DEBUG : MINT] uniprot A : error retrieving uniprot from internet\n" if ($main::verbose);		
					next; 
				} 
				print "[DEBUG : MINT] uniprot A : $uniprot_A retrieve from internet\n" if ($main::verbose);		
				
				$hash_uniprot_id{$intA}->{$orga_query} = $uniprot_A; # We store it in the hash
				print gene_name_to_uniprot_file "$intA\t$uniprot_A\t$orga_query\n"; # We store it in the file
			}
			
			if ( exists ( $hash_locusGene{$intA} ) ) {
				$intA = $hash_locusGene{$intA};
				print "[DEBUG MINT] gene name A : $intA retrieve from file\n" if ($main::verbose);
			}
			else {
				if ( exists( $hash_uniprot_id{$uniprot_A} ) )
				{ # If the uniprot id has already been retrieved (and is now stored in the file)
					$intA = $hash_uniprot_id{$uniprot_A};    # we retrieve it from the file
					print "[DEBUG : MINT] gene name A : $intA retrieve from file\n" if ($main::verbose);
				}
				else {                    # If we need to retrieve it from the web
					my $loc = $intA;
					$intA =$this->SUPER::uniprot_id_to_gene_name( $uniprot_A );
					if ($intA eq "1" || $intA eq "0") {
						$hash_error{$uniprot_A} = $intA;
						print "[DEBUG : MINT] gene name A : error retrieving uniprot from internet\n" if ($main::verbose);		
						next; 
					} 
					print "[DEBUG : MINT] gene name A : $intA retrieve from internet\n" if ($main::verbose);		
				
					$hash_uniprot_id{$uniprot_A} = $intA;    # We store it in the hash
					$hash_locusGene{$loc} = $intA;
					print locus "$loc\t$intA\n";
					print gene_name_to_uniprot_file "$intA\t$uniprot_A\t$orga_query\n";    # We store it in the file
				}
			}		
		}
		elsif ($data[0] =~ /uniprotkb:(.+?);?/) {
			$uniprot_A = $1;
			next if (!$uniprot_A);
			print "[DEBUG : MINT] uniprot A : $uniprot_A\n" if ($main::verbose);
			
			if ( exists( $hash_uniprot_id{$uniprot_A} ) )
			{ # If the uniprot id has already been retrieved (and is now stored in the file)
				$intA = $hash_uniprot_id{$uniprot_A};    # we retrieve it from the file
				print "[DEBUG : DIP] gene name A : $intA retrieve from file\n" if ($main::verbose);
			}
			else {                    # If we need to retrieve it from the web
				$intA =$this->SUPER::uniprot_id_to_gene_name( $uniprot_A );
				if ($intA eq "1" || $intA eq "0") {
					$hash_error{$uniprot_A} = $intA;
					print "[DEBUG : MINT] gene name A : error retrieving uniprot from internet\n" if ($main::verbose);		
					next; 
				} 
				print "[DEBUG : MINT] gene name A : $intA retrieve from internet\n" if ($main::verbose);		
				
				$hash_uniprot_id{$uniprot_A} = $intA;    # We store it in the hash
				print gene_name_to_uniprot_file "$intA\t$uniprot_A\t$orga_query\n";    # We store it in the file
			}
			
		}
		
		
		if ($data[1] =~ /entrezgene\/locuslink:(\d+)/) {
			$intB = $1 if ($data[1] =~ /entrezgene\/locuslink:(\d+)/);
			next if (!defined($intB));
			
			print "[DEBUG : MINT] gene name B : $intB\n" if ($main::verbose);
			if ( exists( $hash_uniprot_id{$intB}->{$orga_query} ) ) {
				$uniprot_B = $hash_uniprot_id{$intB}->{$orga_query};
				print "[DEBUG : MINT] uniprot B : $uniprot_B retrieve from file\n" if ($main::verbose);		
				
			}
			else {
				$uniprot_B = $this->gene_name_to_uniprot_id( $intB, $orga_query );
				if ($uniprot_B eq "1" || $uniprot_B eq "0") {
					print "[DEBUG : MINT] uniprot B : error retrieving uniprot from internet\n" if ($main::verbose);		
					$hash_error{$intB} = $uniprot_B;
					next;
				}
				print "[DEBUG : MINT] uniprot B : $uniprot_B retrieve from internet\n" if ($main::verbose);
				$hash_uniprot_id{$intB}->{$orga_query} = $uniprot_B;
				print gene_name_to_uniprot_file "$intB\t$uniprot_B\t$orga_query\n";
			}
			
			if ( exists ( $hash_locusGene{$intB} ) ) {
				$intA = $hash_locusGene{$intB};
				print "[DEBUG MINT] gene name B : $intB retrieve from file\n" if ($main::verbose);
			}
			else {
				if ( exists( $hash_uniprot_id{$uniprot_B} ) )
				{ # If the uniprot id has already been retrieved (and is now stored in the file)
					$intA = $hash_uniprot_id{$uniprot_B};    # we retrieve it from the file
					print "[DEBUG : MINT] gene name B : $intB retrieve from file\n" if ($main::verbose);
				}
				else {                    # If we need to retrieve it from the web
					my $loc = $intB;
					$intB =$this->SUPER::uniprot_id_to_gene_name( $uniprot_B );
					if ($intB eq "1" || $intB eq "0") {
						$hash_error{$uniprot_B} = $intB;
						print "[DEBUG : MINT] gene name B : error retrieving uniprot from internet\n" if ($main::verbose);		
						next; 
					} 
					print "[DEBUG : MINT] gene name B : $intB retrieve from internet\n" if ($main::verbose);		
				
					$hash_uniprot_id{$uniprot_B} = $intB;    # We store it in the hash
					$hash_locusGene{$loc} = $intB;
					print locus "$loc\t$intB\n";
					print gene_name_to_uniprot_file "$intB\t$uniprot_B\t$orga_query\n";    # We store it in the file
				}
			}		
		}
		elsif ($data[1] =~ /uniprotkb:(.+?);?/) {
			$uniprot_B = $1;
			next if (!$uniprot_B);
			print "[DEBUG : MINT] uniprot B : $uniprot_B\n" if ($main::verbose);
			
			if ( exists( $hash_uniprot_id{$uniprot_B} ) )
			{ # If the uniprot id has already been retrieved (and is now stored in the file)
				$intA = $hash_uniprot_id{$uniprot_A};    # we retrieve it from the file
				print "[DEBUG : DIP] gene name B : $intB retrieve from file\n" if ($main::verbose);
			}
			else {                    # If we need to retrieve it from the web
				$intB =$this->SUPER::uniprot_id_to_gene_name( $uniprot_B );
				if ($intB eq "1" || $intB eq "0") {
					$hash_error{$uniprot_B} = $intB;
					print "[DEBUG : MINT] gene name B : error retrieving uniprot from internet\n" if ($main::verbose);		
					next; 
				} 
				print "[DEBUG : MINT] gene name B : $intB retrieve from internet\n" if ($main::verbose);		
				
				$hash_uniprot_id{$uniprot_B} = $intB;    # We store it in the hash
				print gene_name_to_uniprot_file "$intB\t$uniprot_B\t$orga_query\n";    # We store it in the file
			}
			
		}
		
		
		$exp_syst = $this->SUPER::normalizeString($1) if($data[6]=~ /MI:\d+\((.+)\)$/);
		print "[DEBUG : MINT] sys_exp retrieved\n" if ($main::verbose);
		
		$pubmed   = $1 if ($data[8] =~ /pubmed:(\d+)/); # We retrieve the pubmed id
		print "[DEBUG : MINT] pubmed retrieved\n" if ($main::verbose);

		# Construction of the interaction elements
		my @A = ( $uniprot_A, $intA );
		my @B = ( $uniprot_B, $intB );
		my @pubmed  = ($pubmed);
		my @sys_exp = ($exp_syst);

		# Construction of the interaction object
		my $interaction = Interaction->new( \@A, \@B, $origin, $database, \@pubmed, \@sys_exp );

		$this->SUPER::addInteraction($interaction);
		
		$i++;
		print "[MINT] $i : uniprot A : $uniprot_A - gene name A :$intA\tuniprot B : $uniprot_B - gene name B :$intB\n" if (! $main::verbose);
		print "[DEBUG : MINT] Done : $i\n" if ($main::verbose); 
		 
		if ($this->SUPER::getLength()>=49) {
			$this->SUPER::sendBDD();
			close gene_name_to_uniprot_file;
			close locus;
			open (locus, ">>locus_to_gene_name.txt");
			open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" );
			$this->SUPER::error_internet(\%hash_error);
			%hash_error = ();
			

		}


	}
	$this->SUPER::sendBDD();
	close gene_name_to_uniprot_file;
	$this->SUPER::error_internet(\%hash_error);
	close data_file;
	close locus;
	print "EOF\n";

}


#Download and uncompress Mint data file
#	@return => the file path to .txt file
#			=> the sucess/failure code
#				 1  Sucess: New version found and downloaded			
#				-1  Sucess: No new version, no need for update (but you still have the path to current version as first return value)
#				-2  Failure: Connexion to server failed
#				-3	Failure: Can't create/find download folder
sub download {
	my ($this) = @_;
	no warnings 'numeric';
	
	#working folder (with the name of current DB)
	my $folder = $this->setDownloadFolder(uc(__PACKAGE__));

	#Setting folder failed
	return ("", -3) if(int($folder) == -1);
	
	#Path to the Mint txt save
	my $savePath = $folder."Mint.txt";
	
	#Preparing the user agent and the cookie storage
	my $ua = $this->setUserAgent();
	
	print("Connecting to ".__PACKAGE__."...\n");
	#Connecting to Mint and searching for the correct file to download
	my $ftp = Net::FTP->new("mint.bio.uniroma2.it", Debug => 0) 
		or return ("", -2);
	$ftp->login("anonymous","anonymous")
    	or return ("", -2);
	$ftp->cwd("/pub/release/txt/current/")
    	or return ("", -2);
	my @downloadFile = grep{/mint-full/} $ftp->dir();
	
	#Extracting file name and version date
	if ($downloadFile[0] =~ /^.+\s((\d{4})-(\d{2})-(\d{2})\S+\.txt)$/) {
		my $latestVersion = $2.$3.$4;
		
		my $fileName = "ftp://mint.bio.uniroma2.it/pub/release/txt/current/".$1;
		
		print("Checking release date...\n");
		#Check the current available version on Mint server and stop program if current version stored in version.txt correspond to latest version
		return ($savePath, -1) if($this->checkVersion($folder."version.txt", $latestVersion) == -1);
		
		#If download file already exists => saving the old one as old.
		my $oldFile = $folder."old-Mint.txt";
		move($savePath, $oldFile) if (-e $savePath);
		
		print("Downloading ".__PACKAGE__." data...\n");
		#Downloading the latest Mint full txt
		$ua->show_progress('true value');
		my $res = $ua->get($fileName, ':content_file' => $savePath);
		
		#Checking downloaded file
		unless($res->is_success or -f $savePath) {
			return ("", -2); #Connection failed
		}
		
		#Compare new and old file (if exists)
		if(-e $oldFile) {
			if($this->md5CheckFile($savePath, $oldFile)) {
				unlink($oldFile);		#Deleting old file since old and new are the same
				return ($savePath, -1); # No need for update old and new are the same
			}
		}
		
		#Download completed successfully 
		return($savePath, 1);
	}
	else {
		return ("", -2);
	}
}

1;

