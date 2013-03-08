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
	my ($classe) = @_;                  #Sending arguments to constructor
	my $this = $classe->SUPER::new();
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

	my %hash_uniprot_id; # A hash to store the uniprot id corresponding to a gene name and an organism
	      # This avoid to run the same request several times in the uniprot.org server
	open( gene_name_to_uniprot_file, "gene_name_to_uniprot_database.txt" );    # A file to keep this hash
	while (<gene_name_to_uniprot_file>)
	{      # We initialize the hash with the data contained in the file
		chomp($_);
		my @convertion_data = split( /\t/, $_ );
		$hash_uniprot_id{ $convertion_data[1] } = $convertion_data[0];
	}
	close(gene_name_to_uniprot_file);

	open( data_file, $adresse );    # We open the database file
	my $database = 'Intact';  # We note the corresponding database we are using

	my $i = 0;

	open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" )
	  ; # During this time, we complete the file which contains the uniprot id for a gene name and an organism
	while (<data_file>) {

		chomp($_);

		next if ( $_ =~ m/^#/ig );
		

		last if ( $i == $stop );

		my $intA      = undef;
		my $uniprot_A = undef;
		my $intB      = undef;
		my $uniprot_B = undef;
		my @exp_syst  = undef;
		my @pubmed    = undef;
		my $origin    = undef;

		my $orga_query;

		my @data = split( /\t/, $_ );    # We split the line into an array
		

		
		if ($data[9] =~ /^taxid:(\d+)\(.+\)/) {
			$origin = $1 if (defined($hash_orga_tax{$1}));
		}
		
		if ( !$origin )
		{ # If the origin is null, so if the interaction is not from one of the seven organisms, we do not consider this interaction
			next;
		} else {
			$orga_query = "$hash_orga_tax{$origin} [$origin]";
		}

		$uniprot_A = $1 if ($data[0] =~ /^uniprotkb:(.+)$/);
		next if (!$uniprot_A);
		
		$uniprot_B = $1 if ($data[1] =~ /uniprotkb:(.+)$/);
		next if (!$uniprot_B);
		
		if ( exists( $hash_uniprot_id{$uniprot_A} ) )
		{ # If the uniprot id has already been retrieved (and is now stored in the file)
			$intA = $hash_uniprot_id{$uniprot_A};    # we retrieve it from the file
		}
		else {                    # If we need to retrieve it from the web
			$intA =$this->SUPER::uniprot_id_to_gene_name( $uniprot_A );
			                   # We call the corresponding function
			next if ( $intA eq '0' || $intA eq '1' ); # If the gene was not retrieved, we do not keep the interaction

			$hash_uniprot_id{$uniprot_A} = $intA;    # We store it in the hash
			print gene_name_to_uniprot_file "$intA\t$uniprot_A\t$orga_query\n";    # We store it in the file
			 #$internet .= 'i'; # We indicate that we used an internet connection
		}

		# Same principle as above
		if ( exists( $hash_uniprot_id{$uniprot_B} ) )
		{ # If the uniprot id has already been retrieved (and is now stored in the file)
			$intB = $hash_uniprot_id{$uniprot_B};    # we retrieve it from the file
		}
		else {                    # If we need to retrieve it from the web
			$intB =$this->SUPER::uniprot_id_to_gene_name( $uniprot_B );
			                   # We call the corresponding function
			next if ( $intB eq '0' || $intB eq '1' );

			$hash_uniprot_id{$uniprot_B} = $intB;    # We store it in the hash
			print gene_name_to_uniprot_file "$intB\t$uniprot_B\t$orga_query\n";    # We store it in the file
			 #$internet .= 'i'; # We indicate that we used an internet connection
		}
		
	#	print "$intA\t$uniprot_A\n$intB\t$uniprot_B\n";
		my @sys_exp = ($1) if ($data[11] =~ /\((.+)\)/);
		#print "$sys_exp[0]\n";
	
		@pubmed = ($1) if ($data[8] =~ /pubmed:(\d+)/);

		# Construction of the interaction elements
		my @A = ( $uniprot_A, $intA );
		my @B = ( $uniprot_B, $intB );

		# Construction of the interaction object
		my $interaction =
		  Interaction->new( \@A, \@B, $origin, $database, \@pubmed, \@sys_exp );

		$this->SUPER::addInteraction($interaction);
		
				
		if ($this->SUPER::getLength()>=49) {
			close gene_name_to_uniprot_file;
			open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" );
			$this->SUPER::sendBDD();

		}
		$i++;

	}
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
		#No data recieved from DIP
		return ("", -2);
	}
	
	#Download completed successfully 
	return($fileUncompressed, 1);
}

1;

