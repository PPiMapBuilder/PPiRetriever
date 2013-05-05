package Intact;

use warnings;    #Activate all warnings 
use strict;      #Variable declaration control
use Carp;        #Additionnal user warnings

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
			$hash_uniprot_id{ $convertion_data[1] } = $convertion_data[0];
		}
		close(gene_name_to_uniprot_file);
	 }   
	 print "[DEBUG : MINT] list of uniprot/gene has been load\n" if ($main::verbose);


	open( data_file, $adresse );    # We open the database file
	my $database = 'intact';  # We note the corresponding database we are using

	my $i = 0;

	open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" )
	  ; # During this time, we complete the file which contains the uniprot id for a gene name and an organism
	while (<data_file>) {
		print "\n---------------------------------------------------\n" if ($main::verbose);		

		chomp($_);

		next if ( $_ =~ m/^#/ig );
		

		last if ( $i == $stop );

		my $intA      = undef;
		my $uniprot_A = undef;
		my $intB      = undef;
		my $uniprot_B = undef;
		my @exp_syst  = undef;
		my @pubmed    = undef;
		my $taxA = undef;
		my $taxB = undef;

		my $orga_queryA = undef;
		my $orga_queryB = undef;

		my @data = split( /\t/, $_ );    # We split the line into an array
		

		
		if ($data[9] =~ /^taxid:(\d+)\(.+\)/) {
			$taxA = $1 if (defined($hash_orga_tax{$1}));
		}
		
		if ($data[10] =~ /^taxid:(\d+)\(.+\)/) {
			$taxB = $1 if (defined($hash_orga_tax{$1}));
		}
		
		
		if ( !$taxA or !$taxB )
		{ # If the origin is null, so if the interaction is not from one of the seven organisms, we do not consider this interaction
			print "[DEBUG : INTACT] origin not defined, next\n" if ($main::verbose);
			next;
		} else {
			print "[DEBUG : INTACT] originA: $taxA\n\toriginB = $taxB" if ($main::verbose);	
			$orga_queryA = "$hash_orga_tax{$taxA} [$taxA]";
			$orga_queryB = "$hash_orga_tax{$taxB} [$taxB]";
			print "[DEBUG : INTACT] orga_queryA: $orga_queryA\n\torga_queryB = $orga_queryB" if ($main::verbose);
		}

		$uniprot_A = $1 if ($data[0] =~ /^uniprotkb:(.+)$/);
		next if (!$uniprot_A);
		print "[DEBUG : INTACT] uniprot A : $uniprot_A\n" if ($main::verbose);
				
		
		$uniprot_B = $1 if ($data[1] =~ /uniprotkb:(.+)$/);
		next if (!$uniprot_B);
		print "[DEBUG : INTACT] uniprot B : $uniprot_B\n" if ($main::verbose);
		
		
		if ( exists( $hash_uniprot_id{$uniprot_A} ) )
		{ # If the uniprot id has already been retrieved (and is now stored in the file)
			if ($hash_uniprot_id{$uniprot_A} eq "undef") {
				print "[DEBUG : INTACT] gene name A : gene name is unknown for $uniprot_A and $orga_queryA\n" if ($main::verbose);
				next;
			}
			$intA = $hash_uniprot_id{$uniprot_A};    # we retrieve it from the file
			print "[DEBUG : INTACT] gene name A : $intA retrieve from file\n" if ($main::verbose);
		}
		else {                    # If we need to retrieve it from the web
			$intA =$this->SUPER::uniprot_id_to_gene_name( $uniprot_A );
			if ($intA eq "1" || $intA eq "0") {
				$hash_error{$uniprot_A} = $intA;
				$hash_uniprot_id{$uniprot_A} = "undef";
				print "[DEBUG : INTACT] gene name A : error gene name uniprot from internet\n" if ($main::verbose);		
				next; 
			} 
			print "[DEBUG : INTACT] gene name A : $intA retrieve from internet\n" if ($main::verbose);		
			
			$hash_uniprot_id{$uniprot_A} = $intA;    # We store it in the hash
			print gene_name_to_uniprot_file "$intA\t$uniprot_A\t$orga_queryA\n";    # We store it in the file
			 #$internet .= 'i'; # We indicate that we used an internet connection
		}

		# Same principle as above
		if ( exists( $hash_uniprot_id{$uniprot_B} ) )
		{ # If the uniprot id has already been retrieved (and is now stored in the file)
			if ($hash_uniprot_id{$uniprot_B} eq "undef") {
				print "[DEBUG : INTACT] gene name B : gene name is unknown for $uniprot_B and $orga_queryB\n" if ($main::verbose);
				next;
			}
		
			$intB = $hash_uniprot_id{$uniprot_B};    # we retrieve it from the file
			print "[DEBUG : INTACT] gene name B : $intB retrieve from file\n" if ($main::verbose);
		}
		else {                    # If we need to retrieve it from the web
			$intB =$this->SUPER::uniprot_id_to_gene_name( $uniprot_B );
			if ($intB eq "1" || $intB eq "0") {
				$hash_error{$uniprot_B} = $intB;
				$hash_uniprot_id{$uniprot_B} = "undef";
				print "[DEBUG : INTACT] gene name B : error retrieving gene name from internet\n" if ($main::verbose);		
				next; 
			} 
			print "[DEBUG : INTACT] gene name B : $intB retrieve from internet\n" if ($main::verbose);		
		
			$hash_uniprot_id{$uniprot_B} = $intB;    # We store it in the hash
			print gene_name_to_uniprot_file "$intB\t$uniprot_B\t$orga_queryB\n";    # We store it in the file
		}
		
		my @sys_exp = ($this->SUPER::normalizeString($1)) if ($data[6] =~ /\((.+)\)/);
		print "[DEBUG : INTACT] sys_exp retrieved\n" if ($main::verbose);
		
		@pubmed = ($1) if ($data[8] =~ /pubmed:(\d+)/);
		print "[DEBUG : INTACT] pubmed retrieved\n" if ($main::verbose);
		
		# Construction of the interaction elements
		#my @A = ( $uniprot_A, $intA );
		#my @B = ( $uniprot_B, $intB );

		my $protA = Protein->new($uniprot_A, $intA, $taxA);
		my $protB = Protein->new($uniprot_B, $intB, $taxB);

		# Construction of the interaction object
		my $interaction = Interaction->new( $protA, $protB, $database, \@pubmed, \@sys_exp );

		$this->SUPER::addInteraction($interaction);
		
		$i++;
		print "[INTACT] $i : uniprot A : $uniprot_A - gene name A :$intA\tuniprot B : $uniprot_B - gene name B :$intB\n" if (! $main::verbose);
		print "[DEBUG : INTACT] Done : $i\n" if ($main::verbose); 
		 
		if ($this->SUPER::getLength()>=49) {
			close gene_name_to_uniprot_file;
			open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" );
			$this->SUPER::sendBDD();
			$this->SUPER::error_internet(\%hash_error);
			%hash_error = ();
			

		}


	}
	$this->SUPER::sendBDD();
	close gene_name_to_uniprot_file;
	$this->SUPER::error_internet(\%hash_error);
	close data_file;
	print "\nEOF\n";
}


#Download and uncompress Intact data file
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
	my $savePath = $folder."Intact.zip";
	my $fileUncompressed = $folder."Intact.txt";
	
	#Preparing the user agent and the cookie storage
	my $ua = $this->setUserAgent();
	
	print("Connecting to ".__PACKAGE__."...\n");
	#Connecting to Intact and searching for the latest version
	my $ftp = Net::FTP->new("ftp.ebi.ac.uk", Debug => 0, Passive=> 1) or return ("", -2);
	$ftp->login("anonymous","anonymous") or return ("", -2);
	$ftp->cwd("/pub/databases/intact/") or return ("", -2);
	
	my @latest = grep{/current/} $ftp->dir();
	
	my $latestVersion; #Number of latest version ex: 20130130
	#Extracting version date
	if($latest[0] =~ /->\s(\d{4})-(\d{2})-(\d{2})/) {
		$latestVersion = $1.$2.$3;
		
		print("Checking release date...\n");
		#Check the current available version on Mint server and stop program if current version stored in version.txt correspond to latest version
		return ($fileUncompressed, -1) if($this->checkVersion($folder."version.txt", $latestVersion) == -1);
	} else {
		return ("", -2); #Can't get the current version => connexion error
	}
	
	#Go in current version folder and set file to download
	$ftp->cwd("current/psimitab/");
	
	#If download file already exists => saving the old one as old.
	my $oldFile = $folder."old-Intact.zip";
	move($savePath, $oldFile) if (-e $savePath);
		
	print("Downloading ".__PACKAGE__." data...\n");
	#Downloading the latest Mint full txt
	#$ua->show_progress('true value');
	#my $res = $ua->get($url, ':content_file' => $savePath);
	$ftp->hash(\*STDERR, 5120*200);
	print("0%------------------------------------------------------------------------------------100%\n");
	my $ok = $ftp->get("intact.zip", $savePath);
	
	#Checking downloaded file
	unless($ok or -f $savePath) {
		return ("", -2); #Connection failed
	}
		
	#Compare new and old file (if exists)
	if(-e $oldFile) {
		if($this->md5CheckFile($savePath, $oldFile)) {
			unlink($oldFile);					#Deleting old file since old and new are the same
			return ($fileUncompressed, -1); 	# No need for update old and new are the same
		}
	}
	
	print("Uncompressing...\n");
	#Uncompressing file
	my $uncompressingResult = $this->fileUncompressing($savePath, $fileUncompressed);
		
	#Uncompressing failed
	return ("", -4) if ($uncompressingResult == -1);
	
	print("Done! File downloaded and uncompressed!\n");
	
	#Make sure the file was correctly downloaded
	if ( -e $fileUncompressed ) {
		return ($fileUncompressed, 1);
	} else {
		print("Download failed.\n");
		#No data recieved from INTACT
		return ("", -2);
	}
	
	#Download completed successfully 
	return($fileUncompressed, 1);
}

1;

