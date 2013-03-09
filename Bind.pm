package Bind;

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

#Bind retriever constructor (Connecting to BOND: http://bond.unleashedinformatics.com/)
#	@param  $email 		=> Valid email identifier for BOND database connexion
#	@param	$password   => Valid password for BOND database connexion
sub new() {
	my ( $classe, $email, $password, $connector ) = @_;    #Sending arguments to constructor
	my $this = $classe->SUPER::new($connector);
	$this->{"email"}    = $email;
	$this->{"password"} = $password;
	bless( $this, $classe );    #Linking the reference to the class
	return $this;               #Returning the blessed reference
}

sub parse {
	my ( $this, $stop, $adresse ) = @_;

	$stop = defined($stop) ? $stop : -1;
	$adresse ||= 1;

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

	%hash_orga_tax = reverse(%hash_orga_tax);
	my %hash_error
	  ;    #hash of error, retrieve of uniprot or gene name from internet;

	my %hash_uniprot_id
	  ; # A hash to store the uniprot id corresponding to a gene name and an organism
	    # This avoid to run the same request several times in the uniprot.org server
	open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" )
	  ;    # A file to keep this hash
	while (<gene_name_to_uniprot_file>)
	{      # We initialize the hash with the data contained in the file
		chomp($_);
		my @convertion_data = split( /\t/, $_ );
		$hash_uniprot_id{ $convertion_data[0] }->{ $convertion_data[2] } =
		  $convertion_data[1];
	}
	print "[DEBUG : BIND] list of uniprot/gene has been load\n" if ($main::verbose);
	close(gene_name_to_uniprot_file);

	my $database = 'bind';    # We note the corresponding database we are using

	my $i = 0;

	open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" )
	  ; # During this time, we complete the file which contains the uniprot id for a gene name and an organism

	my $orgaA;
	my $orgaB;
	my $prot;
	my $gene;
	my $intA;
	my $intB;
	my $uniprot_A;
	my $uniprot_B;
	my %hash_sysExp;
	my %hash_pubmed;

	my @pubmed;
	my @sys_exp;
	my @A;
	my @B;

	my $good;

	my $orga_query;

	open( data_file, $adresse );    # We open the database file
	while (<data_file>) {
		if (/^BINDID/) {
			if ( $i > 0 ) {
				@pubmed  = keys(%hash_pubmed);
				@sys_exp = keys(%hash_sysExp);
				$good    = 0 if ( $#pubmed == -1 || $#sys_exp == -1 );

				if ( $good == 1 ) {
					@A = ( $uniprot_A, $intA );
					@B = ( $uniprot_B, $intB );
					my $interaction =
					  Interaction->new( \@A, \@B, $orgaA, $database, \@pubmed,
						\@sys_exp );
					$this->SUPER::addInteraction($interaction);
					print
"[BIND] $i : uniprot A : $uniprot_A - gene name A :$intA\tuniprot B : $uniprot_B - gene name B :$intB\n"
					  if ( !$main::verbose );
					  print "[DEBUG : BIND] Done : $i\n--------------------------------------------\n" if ($main::verbose);

				}

				if ( $this->SUPER::getLength() >= 49 ) {
					$this->SUPER::sendBDD();
					close gene_name_to_uniprot_file;
					open( gene_name_to_uniprot_file,
						">>gene_name_to_uniprot_database.txt" );
					$this->SUPER::error_internet( \%hash_error );
					%hash_error = ();
				}
			}
			$i++;

			

			last if ( $i == $stop );
			$orgaA      = undef;
			$orgaB      = undef;
			$intA       = undef;
			$intB       = undef;
			$uniprot_A  = undef;
			$uniprot_B  = undef;
			$orga_query = undef;

			@pubmed  = undef;
			@sys_exp = undef;

			%hash_sysExp = ();
			%hash_pubmed = ();

			$good = 1;    #0 if bad, 1 for good

		}
		else {

			if ( $_ =~ /^MOLECULE(.)/ && $good == 1 ) {
				$prot = $1;
				next;
			}

			if ( $_ =~ /^.SHLABEL\s(.+)$/ && $good == 1 ) {
				$intA = $1 if ( $prot eq "A" );
				$intB = $1 if ( $prot eq "B" );
				next;
			}

			if ( $_ =~ /\s+ORGANISM\s(.+)$/ && $good == 1 ) {
				my $orga = $1;
				if ( $prot eq "A" ) {
					$orgaA = $hash_orga_tax{$orga}
					  if ( defined( $hash_orga_tax{$orga} ) );
					$good = 0 if ( !defined($orgaA) );

				}
				elsif ( $prot eq "B" ) {
					$orgaB = $hash_orga_tax{$orga}
					  if ( defined( $hash_orga_tax{$orga} ) );
					$good = 0 if ( !defined($orgaB) );
				}

				if ( defined($orgaA) && defined($orgaB) ) {
					if ( $orgaA ne $orgaB ) { $good = 0; next; }
					$orga_query = "$hash_orga_tax{$orga} [$orgaA]";

					if ( exists( $hash_uniprot_id{$intA}->{$orga_query} ) )
					{ # If the uniprot id has already been retrieved (and is now stored in the file)
						$uniprot_A =
						  $hash_uniprot_id{$intA}
						  ->{$orga_query};    # we retrieve it from the file
						print
"[DEBUG : BIND] uniprot A : $uniprot_A retrieve from file\n"
						  if ($main::verbose);

					}
					else {    # If we need to retrieve it from the web
						$uniprot_A =
						  $this->gene_name_to_uniprot_id( $intA, $orga_query )
						  ;    # We call the corresponding function

						if ( $uniprot_A eq "1" || $uniprot_A eq "0" ) {
							$hash_error{$intA} = $uniprot_A;
							print
"[DEBUG : BIND] uniprot A : error retrieving uniprot from internet\n"
							  if ($main::verbose);
							$good = 0;
							next;
						}
						else {
							$hash_uniprot_id{$intA}->{$orga_query} = $uniprot_A; # We store it in the hash
							print gene_name_to_uniprot_file "$intA\t$uniprot_A\t$orga_query\n"; # We store it in the file
						}

					}

					if ( exists( $hash_uniprot_id{$intB}->{$orga_query} ) )
					{ # If the uniprot id has already been retrieved (and is now stored in the file)
						$uniprot_B =
						  $hash_uniprot_id{$intB}
						  ->{$orga_query};    # we retrieve it from the file
						print
"[DEBUG : BIND] uniprot A : $uniprot_A retrieve from file\n"
						  if ($main::verbose);

					}
					else {    # If we need to retrieve it from the web
						$uniprot_B =
						  $this->gene_name_to_uniprot_id( $intB, $orga_query )
						  ;    # We call the corresponding function
						if ( $uniprot_B eq "1" || $uniprot_B eq "0" ) {
							$hash_error{$intB} = $uniprot_B;
							print
"[DEBUG : BIND] uniprot A : error retrieving uniprot from internet\n"
							  if ($main::verbose);
							$good = 0;
							next;
						}
						else {
							$hash_uniprot_id{$intB}->{$orga_query} = $uniprot_B; # We store it in the hash
							print gene_name_to_uniprot_file "$intA\t$uniprot_A\t$orga_query\n"; # We store it in the file
						}

					}
				}
				next;
			}
			if ( /^\sEXPSYSTEM\s(.*)$/ && $good == 1 ) {
				next if ( $1 eq "" );
				$hash_sysExp{$1} = 1 if ( !defined( $hash_sysExp{$1} ) );
				print "[DEBUG : BIND] sys_exp retrieved\n" if ($main::verbose);

			}
			if ( /^\sEXPCONDREFPMID\s(\d*)$/ && $good == 1 ) {
				next if ( $1 eq "" );
				$hash_pubmed{$1} = $1 if ( !defined( $hash_pubmed{$1} ) );
				print "[DEBUG : BIND] pubmed retrieved\n" if ($main::verbose);
			}
		}
	}


	$this->SUPER::sendBDD();
	close gene_name_to_uniprot_file;
	$this->SUPER::error_internet( \%hash_error );
	close data_file;

}

#Download Bind data file from BOND database
#	@param  @taxids		=> (Optional) an array of taxonomy identifier. The program will download interaction only from thoses organism
#	@return => the file path to .txt file
#			=> the sucess/failure code
#				 1  Sucess: New version found and downloaded
#				-1  Sucess: No new version, no need for update (but you still have the path to current version as first return value)
#				-2  Failure: Connexion or login failed
#				-3	Failure: Can't create/find download folder
#				-4	Failure: Uncompressing failed
#				-5	Failure: Missing email or password
sub download {
	my ( $this, @taxids ) = @_;
	unless (@taxids) {
		@taxids = ( "3702", "6239", "7227", "9606", "10090", "4932", "4896" );
	}
	no warnings 'numeric';
	use URI::Escape;

	#checking if we have a email and password used to connect to BOND
	if ( not $this->{email} or not $this->{password} ) {
		print("Error: Missing email or passowrd for Login!");
		return ( "", -5 );
	}

	#working folder (with the name of current DB)
	my $folder = $this->setDownloadFolder( uc(__PACKAGE__) );

	#Setting folder failed
	return ( "", -3 ) if ( int($folder) == -1 );

	my $fileUncompressed = $folder . "Bind.txt";

	#Preparing the user agent and the cookie storage
	my $ua = $this->setUserAgent();

	#Login to BOND
	my $result = "";
	my $res;
	my $attempt = 1;
	until ( $result =~ /.*>Logout<.*/ ) {
		return ( "", -2 ) if ( $attempt > 5 );    #Login failed

		print( "Connecting to " . __PACKAGE__ . "... " );
		if ( $attempt > 1 ) { print( "(Attempt #" . $attempt . ")" ); }
		print("\n");

		$res = $ua->post(
			"http://bond.unleashedinformatics.com/Action?pg=50000",
			[
				"email"    => $this->{email},
				"password" => $this->{password},
				"url"      => ""
			]
		);
		$result = $res->content;

		#print Dumper($res);

		$attempt++;
	}

   #Query searching all protein-protein interaction for all organisms in @taxids
	my $query = '
	RecordType: (interaction) 
	AND
	(
		(
			+(
				+RecordType:(interaction) 
				+(
					+interaction.object.type:"protein" 
					+taxid:(' . join( " ", @taxids ) . ' )
				)
			)
		)
		-(
			(+BINDInteraction.a.type:"not specified" +BINDInteraction.a.shortlabel:"Unknown")
			(+BINDInteraction.b.type:"not specified" +BINDInteraction.b.shortlabel:"Unknown")
		)
	)';
	$query =~ s/\n//g;
	$query =~ s/\t//g;
	$query =~ s/\s{2}//g;
	$query = uri_escape($query);    #Encoding for post transaction

	#print $query; exit();

	#Downloading Bind interactions
	use HTTP::Request::Common qw( POST );
	my $req = POST(
		"http://bond.unleashedinformatics.com/Action",
		Content_Type => 'application/x-www-form-urlencoded',

		#Connection => "keep-alive",
		Content => "pg=3105"
		  . "&butval=change"
		  . "&type=6"
		  .                    #File type: flat file
		  "&query=" . $query   #Query for BOND database extractingg informations
	);

	#If download file already exists => saving the old one as old.
	my $oldFile = $folder . "old-Bind.txt";
	move( $fileUncompressed, $oldFile ) if ( -e $fileUncompressed );

	#Downloading BIND with multiple attempt
	my $downloadOk = 0;
	$attempt = 1;

	$ua->show_progress('true value');
	until ($downloadOk) {
		return ( "", -2 ) if ( $attempt > 5 );  #Download failed after 5 attempt

		print( "Downloading " . __PACKAGE__ . " data... (Can be very long)" );
		if ( $attempt > 1 ) {
			sleep(1);
			print( " (Attempt #" . $attempt . ")" );
		}
		print("\n");

		#use Data::Dumper;print Dumper($req);
		$res = $ua->request( $req, $fileUncompressed );

		$downloadOk = $res->is_success;
		$attempt++;
	}

	#Connexion failed unless the response is successful
	return ( "", -2 ) unless ( $res->is_success );

	#Checking that the file is not a dummy html file
	return ( "", -2 ) unless ( -e $fileUncompressed );

	my $i = 0;
	open F, $fileUncompressed;
	while (<F>) {
		last if ( $i > 30 );    #Checking only the first 30 lines
		if (/.*<html>.*/) {
			unlink($fileUncompressed);
			return ( "", -2 );    #File contains html :(
		}
		$i++;
	}
	close F;

	#Compare new and old file (if exists)
	if ( -e $oldFile ) {
		if ( $this->md5CheckFile( $fileUncompressed, $oldFile ) ) {
			unlink($oldFile);
			return ( $fileUncompressed, -1 )
			  ;                   # No need for update old and new are the same
		}
	}

	#Fully successful
	return ( $fileUncompressed, 1 );
}

1;

