package Biogrid;

use warnings;    #Activate all warnings 
use strict;      #Variable declaration control
use Carp;        #Additionnal user warnings

use DBpublic;
use Interaction;
use File::Copy;
use LWP::Simple;

use Data::Dumper;

$SIG{INT} = \&catch_ctrlc;

our @ISA = ("DBpublic");

sub new {
	my ($classe, $connector) = @_;                  #Sending arguments to constructor
	my $this = $classe->SUPER::new($connector);
	bless( $this, $classe );            #Linking the reference to the class
	return $this;                       #Returning the blessed reference
}

sub parse_all {
	my ($this, $path, $stop) = @_;
	$this->parse($stop, $_) foreach (glob($path."/biogrid*"));	
}

sub parse {

	my ( $this, $stop, $adresse ) = @_;

	$stop = defined($stop) ? $stop : -1;
	$adresse ||=1;
	
	print "[DEBUG : Biogrid] Start parsing\n" if ($main::verbose);
	
	my %hash_orga_tax = ( # Hash to easily retrieve the correspondance between the taxonomy id and the seven reference organisms
		'3702'  => 'Arabidopsis thaliana',
		'6239'  => 'Caenorhabditis elegans',
		'7227'  => 'Drosophilia melanogaster',
		'9606'  => 'Homo sapiens',
		'10090' => 'Mus musculus',
		'4932'  => 'Saccharomyces cerevisiae',
		'4896'  => 'Schizosaccharomyces pombe'
	);

	my $hash_uniprot_id; # A hash to store the uniprot id corresponding to a gene name and an organism
				# This avoid to run the same request several times in the uniprot.org server
		
	print "[DEBUG : Biogrid] loading gene name/uniprot file\n" if ($main::verbose);		
	
	open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" );
	while (<gene_name_to_uniprot_file>) { # We initialize the hash with the data contained in the file
		chomp($_);
		my @convertion_data = split( /\t/, $_ );
		$hash_uniprot_id->{ $convertion_data[0] }->{ $convertion_data[2] } =
		  $convertion_data[1];
	}
	close(gene_name_to_uniprot_file);
	print "[DEBUG : Biogrid] loaded.\n" if ($main::verbose);
	print "--> will open $adresse \n";
	open( data_file, $adresse ); # We open the database file
	my $database = 'biogrid'; # We note the corresponding database we are using

	my $i = 0;

	print "[DEBUG : Biogrid] reading biogrid file\n" if ($main::verbose);
	open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" ); # During this time, we complete the file which contains the uniprot id for a gene name and an organism
	while (<data_file>) {

		chomp($_);

		if ( $_ =~ m/^#/ig ) {
			next;
		}
		last if ($i == $stop);

		my $intA      = undef;
		my $uniprot_A = undef;
		my $intB      = undef;
		my $uniprot_B = undef;
		my $exp_syst  = undef;
		my $pubmed    = undef;
		my $origin    = undef;

		my $orga_query;

print "-------------------------------------\n" if ($main::verbose);
print "[DEBUG : Biogrid] line: ",$. ,"\n" if ($main::verbose);


		my @data = split( /\t/, $_ ); # We split the line into an array

		$origin = $data[16] if (defined($hash_orga_tax{$data[16]}));


		if ( !$origin ) { # If the origin is null, so if the interaction is not from one of the seven organisms, we do not consider this interaction
print "[DEBUG : Biogrid] origin not defined, next\n" if ($main::verbose);
			next;
		} else {
				print "[DEBUG : Biogrid] origin: $origin\n" if ($main::verbose);	
		}

		$orga_query = "$hash_orga_tax{$origin} [$origin]";
print "[DEBUG : Biogrid] orga_query: $orga_query\n" if ($main::verbose);
		#my $internet = undef; # Temporary variable to see the number of request to the uniprot.org server

		$intA = $data[7]; # We retrieve the first interactor
print "[DEBUG : Biogrid] intA: $intA\n" if ($main::verbose);
		if (exists( $hash_uniprot_id->{$intA}->{$orga_query} ) ) { # If the uniprot id has already been retrieved (and is now stored in the file)
			$uniprot_A = $hash_uniprot_id->{$intA}->{$orga_query}; # we retrieve it from the file
print "[DEBUG : Biogrid] uniprotA: $uniprot_A\n";
			
		}
		else { # If we need to retrieve it from the web
print "[DEBUG : Biogrid] looking for uniprotA on web... ";
		
			$uniprot_A = $this->SUPER::gene_name_to_uniprot_id( $intA, $orga_query ); # We call the corresponding function
print "get $uniprot_A\n";
			
			if ($uniprot_A eq "1" || $uniprot_A eq "0") {
				#$hash_uniprot_id->{$intA}->{$orga_query} = undef;
				next;
			}
			$hash_uniprot_id->{$intA}->{$orga_query} = $uniprot_A; # We store it in the hash
			print gene_name_to_uniprot_file "$intA\t$uniprot_A\t$orga_query\n"; # We store it in the file
			#$internet .= 'i'; # We indicate that we used an internet connection
		}


		# Same principle as above
		$intB = $data[8];
print "[DEBUG : Biogrid] intB: $intB\n";
		if ( exists( $hash_uniprot_id->{$intB}->{$orga_query} ) ) {
			$uniprot_B = $hash_uniprot_id->{$intB}->{$orga_query};
print "[DEBUG : Biogrid] uniprotB: $uniprot_B\n";
			
		}
		else {
print "[DEBUG : Biogrid] looking for uniprotB on web... ";
			
			$uniprot_B = $this->SUPER::gene_name_to_uniprot_id( $intB, $orga_query );
print "get $uniprot_B\n";
			
			next if ($uniprot_B eq "1" || $uniprot_B eq "0");
			$hash_uniprot_id->{$intB}->{$orga_query} = $uniprot_B;
			print gene_name_to_uniprot_file "$intB\t$uniprot_B\t$orga_query\n";
			# $internet .= 'i';
		}
		

		if ( !defined($uniprot_A) || !defined($uniprot_B) ) { # If the uniprot id was not retrieved, we do not keep the interaction
			next;
print "[DEBUG : Biogrid] A or B not defined, not defined\n";
		}

		$exp_syst = $data[11]; # We retrieve the experimental system
		$pubmed   = $data[14]; # We retrieve the pubmed id

		# Construction of the interaction elements
		my @A = ( $uniprot_A, $intA );
		my @B = ( $uniprot_B, $intB );
		my @pubmed  = ($pubmed);
		my @sys_exp = ($exp_syst);

		# Construction of the interaction object
		my $interaction = Interaction->new( \@A, \@B, $origin, $database, \@pubmed, \@sys_exp );
		

		$this->SUPER::addInteraction($interaction);
		
				
		if ($this->SUPER::getLength()>=49) {
			close gene_name_to_uniprot_file;
			open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" );
			$this->SUPER::sendBDD();

		}
		
		#print $#{$this->{ArrayInteraction}}."\n";
		$i++;
		print "[INFO] $i\t$intA:$uniprot_A\t$intB:$uniprot_B\n"; # Input for debug


	}
}


#Download and uncompress Biogrid data file
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
	return ("", -3) if(int($folder) == -1); #Error code -3: unable to get/create folder
	
	my $saveFile = "BIOGRID-ALL-LATEST.tab2.zip";
	my $url = "http://thebiogrid.org/downloads/archives/Latest%20Release/".$saveFile;
	my $fileUncompressed = $folder."BIOGRID.txt";
	
	#Preparing the user agent for downloading
	my $ua = $this->setUserAgent();
	
	#Downloading database
	print("Downloading ".__PACKAGE__." data...\n");
	my $savePath = $folder . $saveFile;

	#If download file already exists => saving the old one as old.
	my $oldFile = $folder."old-".$saveFile;
	move($savePath, $oldFile) if (-e $savePath);

	#Downloading the biogrid data (with progress shown)
	$ua->show_progress('true value');
	my $res = $ua->get($url, ':content_file' => $savePath );
	
	unless($res->is_success) {
		return ("", -2); #Connection failed
	}
	
	#Compare new and old file (if exists)
	if(-e $oldFile) {
		if($this->md5CheckFile($savePath, $oldFile)) {
			#Deleting old file since old and new are the same
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
	} else {
		print("Download failed.\n");
		#No data recieved from DIP
		return ("", -2);
	}
}

1;

