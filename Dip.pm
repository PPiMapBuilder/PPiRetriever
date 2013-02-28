package Dip;

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
	my $database = 'Dip';  # We note the corresponding database we are using

	my $i = 0;

	open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" )
	  ; # During this time, we complete the file which contains the uniprot id for a gene name and an organism
	while (<data_file>) {

		chomp($_);

		next if ( $_ =~ m/^#/ig || $_ !~ /^DIP/ );
		

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

		#foreach my $pop (@data) {print $pop."\t";} exit;
		if ($data[9] =~ /taxid:(\d+)\(.+\)$/) {
			$origin = $1 if (defined($hash_orga_tax{$1}));
		}
		
		if ( !$origin )
		{ # If the origin is null, so if the interaction is not from one of the seven organisms, we do not consider this interaction
			next;
		} else {
			$orga_query = "$hash_orga_tax{$origin} [$origin]";
		}

		#my $internet = undef; # Temporary variable to see the number of request to the uniprot.org server
		
		#print $data[0]."\n";
		$uniprot_A = $1 if ($data[0] =~ /.+\|uniprotkb:(.+)$/);
		next if (!$uniprot_A);
		
		$uniprot_B = $1 if ($data[1] =~ /.+\|uniprotkb:(.+)$/);
		next if (!$uniprot_B);
		
		
		if ( exists( $hash_uniprot_id{$uniprot_A} ) )
		{ # If the uniprot id has already been retrieved (and is now stored in the file)
			$intA = $hash_uniprot_id{$uniprot_A};    # we retrieve it from the file
		}
		else {                    # If we need to retrieve it from the web
			$intA =$this->SUPER::uniprot_id_to_gene_name( $uniprot_A );
			                   # We call the corresponding function
			next if ( $intA eq "" ); # If the gene was not retrieved, we do not keep the interaction

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
			if ( $intB eq "" )
			{ # If the gene was not retrieved, we do not keep the interaction
				next;
			}

			$hash_uniprot_id{$uniprot_B} = $intB;    # We store it in the hash
			print gene_name_to_uniprot_file "$intB\t$uniprot_B\t$orga_query\n";    # We store it in the file
			 #$internet .= 'i'; # We indicate that we used an internet connection
		}
		
		my @sys_exp = undef;
		my @temp_exp_syst = split (/\|/, $data[6]);
		foreach $exp_syst (@temp_exp_syst) {
			if ($exp_syst =~ /MI:\d+\((.+)\)/) {
				push (@sys_exp, $1);
				next;
			}
		} 
		
		my @pubmed = undef;
		my @temp_pubmed = split(/\|/, $data[8]);
		foreach $pubmed (@temp_pubmed) {
			if ($pubmed =~ /pubmed:(\d+)/) {
				push (@pubmed, $1);
				next;
			}
		}

		# Construction of the interaction elements
		my @A = ( $uniprot_A, $intA );
		my @B = ( $uniprot_B, $intB );

		# Construction of the interaction object
		my $interaction =
		  Interaction->new( \@A, \@B, $origin, $database, \@pubmed, \@sys_exp );

		$this->SUPER::addInteraction($interaction);

		#print "$i $internet\t$intA\t$uniprot_A\t$intB\t$uniprot_B\t$exp_syst\t$origin\t$database\t$pubmed\t$pred\n"; # Input for debug
		
		$i++;

	}
}



#Download and uncompress Dip data file
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
	
	my $fileUncompressed = $folder."Dip.txt";
	
	#Preparing the user agent and the cookie storage
	my ($ua, $cookie) = $this->setUserAgent($folder."cookies.txt");

	#Getting the download page (with multiple attempt)
	my $download_page = "";
	my $attempt = 1;
	until ( $download_page =~ /HREF="(.+\.txt\.gz)">HTTP/m ) {
		if ( $attempt == 6 ) { return -2; }

		print("Connecting to ".__PACKAGE__."... ");
		if ( $attempt > 1 ) { print( "(Attempt #" . $attempt . ")" ); }
		print("\n");
		
		#Sending first HTTP request (login)
		my $req = HTTP::Request->new(POST => "http://dip.doe-mbi.ucla.edu/dip/Login.cgi" );
		$req->content("login=pidupuis&pass=toto&Login=Login&lgn=1");#Login informations
		$ua->request($req);

		#Sending second HTTP request (get download page)
		$req = HTTP::Request->new(GET => "http://dip.doe-mbi.ucla.edu/dip/Download.cgi?SM=3" );
		$download_page = ( $ua->request($req) )->content;

		#print($download_page);
		$attempt++;
	}

	#Searching first HTTP link to a .txt.gz file
	if ( $download_page =~ /HREF="(.+\.txt\.gz)">HTTP/m ) {
		my @pathinfo = $this->extractPathInfo($1);
		my $extension = $pathinfo[2];
		my $dataFile = "http://dip.doe-mbi.ucla.edu" . $1;
		print $dataFile. "\n";

		print("Checking release date...\n");

		#Searching the release date in the name of the file
		#Example: /dip/File.cgi?FN=2012/tab25/dip20120818.txt.gz (extracting the "20120818")
		if ( $dataFile =~ /.+dip(\d+).+/ ) {
			# No need for update, No need for download
			return ($fileUncompressed, -1) if $this->checkVersion($folder."version.txt", $1) == -1; 
		}
		
		print("Downloading ".__PACKAGE__." data...\n");
		my $saveFile = __PACKAGE__.$extension;
		my $savePath = $folder . $saveFile;

		#If download file already exists => saving the old one as old.
		my $oldFile = $folder."old-".$saveFile;
		move($savePath, $oldFile) if (-e $savePath);

		#Downloading the latest version in DIP.txt.gz
		$ua->show_progress('true value');
		my $res = $ua->get( $dataFile, ':content_file' => $savePath );
		
		unless($res->is_success) {
			return ("", -2); #Connection failed
		}

		#Clearing cookies
		$cookie->clear();

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
			return ("", -2);    #No data recieved from DIP
		}
	}
	else {
		print("Download failed.\n");
		return ("", -2);    #No data recieved from DIP
	}
}

1;

