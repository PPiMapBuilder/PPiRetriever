package HPRD;

use warnings;    #Activate all warnings 
use strict;      #Variable declaration control
use Carp;        #Additionnal user warnings

use DBpublic;
use Interaction;

use LWP::UserAgent;
use LWP::Simple;
use File::Copy;

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
	print "[DEBUG : HPRD] list of uniprot/gene has been load\n" if ($main::verbose);		
	close(gene_name_to_uniprot_file);

	open( data_file, $adresse );    # We open the database file
	my $database = 'hprd';  # We note the corresponding database we are using

	my $i = 0;

	open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" )
	  ; # During this time, we complete the file which contains the uniprot id for a gene name and an organism
	while (<data_file>) {
		print "\n---------------------------------------------------\n" if ($main::verbose);		
		
		chomp($_);

		next if ( $_ =~ m/^#/ig || $_ =~ /^ID/);
		

		last if ( $i == $stop );

		my $intA      = undef;
		my $uniprot_A = undef;
		my $intB      = undef;
		my $uniprot_B = undef;
		my $exp_syst  = undef;
		my $pubmed    = undef;
		my $origin    = undef;

		my $orga_query;

		my @data = split( /\t/, $_ );    # We split the line into an array
		#foreach my $plop (@data) {print $plop."\t";}exit;
		
		$origin = "9606";
		$orga_query = "$hash_orga_tax{$origin} [$origin]";

		$intA = $data[0]; # We retrieve the first interactor
		print "[DEBUG : HPRD] gene name A : $intA\n" if ($main::verbose);		

		if ( exists( $hash_uniprot_id{$intA}->{$orga_query} ) ) { # If the uniprot id has already been retrieved (and is now stored in the file)
			$uniprot_A = $hash_uniprot_id{$intA}->{$orga_query}; # we retrieve it from the file
			print "[DEBUG : HPRD] uniprot A : $uniprot_A retrieve from file\n" if ($main::verbose);		
			
		}
		else { # If we need to retrieve it from the web
			$uniprot_A = $this->gene_name_to_uniprot_id( $intA, $orga_query ); # We call the corresponding function
			if ($uniprot_A eq "1" || $uniprot_A eq "0") {
				$hash_error{$intA} = $uniprot_A;
				print "[DEBUG : HPRD] uniprot A : error retrieving uniprot from internet\n" if ($main::verbose);		
				next; 
			} 
			print "[DEBUG : HPRD] uniprot A : $uniprot_A retrieve from internet\n" if ($main::verbose);		
			
			$hash_uniprot_id{$intA}->{$orga_query} = $uniprot_A; # We store it in the hash
			print gene_name_to_uniprot_file "$intA\t$uniprot_A\t$orga_query\n"; # We store it in the file
		}

		# Same principle as above
		$intB = $data[3];
		print "[DEBUG : HPRD] gene name B : $intB\n" if ($main::verbose);
		if ( exists( $hash_uniprot_id{$intB}->{$orga_query} ) ) {
			$uniprot_B = $hash_uniprot_id{$intB}->{$orga_query};
			print "[DEBUG : HPRD] uniprot B : $uniprot_B retrieve from file\n" if ($main::verbose);		
			
		}
		else {
			$uniprot_B = $this->gene_name_to_uniprot_id( $intB, $orga_query );
			if ($uniprot_B eq "1" || $uniprot_B eq "0") {
				print "[DEBUG : HPRD] uniprot B : error retrieving uniprot from internet\n" if ($main::verbose);		
				$hash_error{$intB} = $uniprot_B;
				next;
			}
			print "[DEBUG : HPRD] uniprot B : $uniprot_B retrieve from internet\n" if ($main::verbose);
			$hash_uniprot_id{$intB}->{$orga_query} = $uniprot_B;
			print gene_name_to_uniprot_file "$intB\t$uniprot_B\t$orga_query\n";
		}
		
		my @sys_exp = split( /;/,$data[6]);
		print "[DEBUG : HPRD] sys_exp retrieved\n" if ($main::verbose);
		
		my @pubmed  = split ( /,/, $data[7]);
		print "[DEBUG : HPRD] pubmed retrieved\n" if ($main::verbose);
		
		# Construction of the interaction elements
		my @A = ( $uniprot_A, $intA );
		my @B = ( $uniprot_B, $intB );


		# Construction of the interaction object
		my $interaction = Interaction->new( \@A, \@B, $origin, $database, \@pubmed, \@sys_exp );

		$this->SUPER::addInteraction($interaction);

		if ($this->SUPER::getLength()>=49) {
			$this->SUPER::sendBDD();
			close gene_name_to_uniprot_file;
			open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" );
			$this->SUPER::error_internet(\%hash_error);
			%hash_error = ();
			

		}
		$i++;
		print "[HPRD] $i : uniprot A : $uniprot_A - gene name A :$intA\tuniprot B : $uniprot_B - gene name B :$intB\n" if (! $main::verbose);
		print "[DEBUG : HPRD] Done : $i\n" if ($main::verbose); 

	}
	$this->SUPER::sendBDD();
	close gene_name_to_uniprot_file;
	$this->SUPER::error_internet(\%hash_error);
	close data_file;
	
}


#Download and uncompress HPRD data file
#	@return => the file path to .txt file
#			=> the sucess/failure code
#				 1  Sucess: New version found and downloaded			
#				-1  Sucess: No new version, no need for update (but you still have the path to current version as first return value)
#				-2  Failure: Connexion to server failed
#				-3	Failure: Can't create/find download folder
#				-4	Failure: Uncompressing failed
sub download {
	my ($this) = @_;
	no warnings 'numeric';
	
	#working folder (with the name of current DB)
	my $folder = $this->setDownloadFolder(uc(__PACKAGE__));

	#Setting folder failed
	return ("", -3) if(int($folder) == -1);
	
	my $fileUncompressed = $folder."HPRD.txt";
	
	#Preparing the user agent and the cookie storage
	my $ua = $this->setUserAgent();

	#Getting the download page (with multiple attempt)
	my $download_page = "";
	my $attempt = 1;
	until ( $download_page =~ /.*(HPRD_Release\d+_(\d+))\.tar\.gz.*/m ) {
		#No more attempt left
		return ("", -2) if ($attempt > 3);

		print("Connecting to ".__PACKAGE__."... ");
		if ( $attempt > 1 ) { print( "(Attempt #" . $attempt . ")" ); }
		print("\n");
		 
		#Getting download page
		$download_page =  ($ua->get("http://www.hprd.org/download"))->content;

		#print($download_page);
		$attempt++;
	}

	#Searching first HTTP link to a .txt.gz file
	if ( $download_page =~ /.*(HPRD_Release\d+_(\d+))\.tar\.gz.*/m ) {
		my $dataFile = "http://www.hprd.org/edownload/" . $1;
		my $lastestVersion = $2;
		
		print("Checking release date...\n");
		#Example: HPRD_Release9_041310.tar.gz (extracting the "041310")
		return ($fileUncompressed, -1) if $this->checkVersion($folder."version.txt", $lastestVersion) == -1;  # No need for update, No need for download
		
		print("Downloading ".__PACKAGE__." data...\n");
		my $saveFile = __PACKAGE__.".tar.gz";
		my $savePath = $folder . $saveFile;

		#If download file already exists => saving the old one as old.
		my $oldFile = $folder."old-".$saveFile;
		move($savePath, $oldFile) if (-e $savePath);

		#Downloading the latest version in HPRD
		$ua->show_progress('true value');
		my $res = $ua->get( $dataFile, ':content_file' => $savePath );
		
		unless($res->is_success) {
			return ("", -2); #Connection failed
		}
		
		#Compare new and old file (if exists)
		if(-e $oldFile) {
			if($this->md5CheckFile($savePath, $oldFile)) {
				unlink($oldFile);
				return ($fileUncompressed, -1); # No need for update old and new are the same
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
		}
		else {
			print("Download failed.\n");
			return ("", -2);    #No data recieved from HPRD
		}
	}
	else {
		print("Download failed.\n");
		return ("", -2);    #No data recieved from HPRD
	}
}

1;

