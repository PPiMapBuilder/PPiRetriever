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
sub new($$) {
	my ($classe, $email, $password) = @_;		#Sending arguments to constructor
	my $this = $classe->SUPER::new();
	$this->{"email"} = $email;
	$this->{"password"} = $password;
	bless( $this, $classe );					#Linking the reference to the class
	return $this;                       		#Returning the blessed reference
}


sub parse {
	
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
	my ($this, @taxids) = @_;
	unless(@taxids) {
		@taxids = ("3702", "6239", "7227", "9606", "10090", "4932", "4896");
	}
	no warnings 'numeric';
	use URI::Escape;
	
	#checking if we have a email and password used to connect to BOND
	if(not $this->{email} or not $this->{password}) {
		print ("Error: Missing email or passowrd for Login!");
		return ("", -5);
	}
	
	#working folder (with the name of current DB)
	my $folder = $this->setDownloadFolder(uc(__PACKAGE__));

	#Setting folder failed
	return ("", -3) if(int($folder) == -1);
	
	my $fileUncompressed = $folder."Bind.txt";
	
	#Preparing the user agent and the cookie storage
	my ($ua, $cookie) = $this->setUserAgent();

	#Login to BOND
	my $result = "";
	my $res;
	my $attempt = 1;
	until($result =~ /.*>Logout<.*/) {
		return ("", -2) if($attempt > 3); #Login failed
		
		print("Connecting to ".__PACKAGE__."... ");
		if ( $attempt > 1 ) { print( "(Attempt #" . $attempt . ")" ); }
		print("\n");
		
		$res = $ua->post(
			"http://bond.unleashedinformatics.com/Action?pg=50000", 
			[
				"email"		=> $this->{email},
				"password"	=> $this->{password},
				"url"		=> ""
			]
		);
		$result = $res->content;
		#print Dumper($res);
		
		$attempt++;
	}
	
	#Query searching all protein-protein interaction for all organisms in @taxids
	my $query =  '
	RecordType: (interaction) 
	AND
	(
		(
			+(
				+RecordType:(interaction) 
				+(
					+interaction.object.type:"protein" 
					+taxid:('.join(" ", @taxids).' )
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
	$query = uri_escape($query); #Encoding for post transaction
	
	#print $query; exit();

	#Downloading Bind interactions
	use HTTP::Request::Common qw( POST );
	my $req = POST("http://bond.unleashedinformatics.com/Action",
		Content_Type => 'application/x-www-form-urlencoded',
		#Connection => "keep-alive",
		Content => "pg=3105".
			"&butval=change".
			"&type=6".	 		#File type: flat file
			"&query=".$query	#Query for BOND database extractingg informations
	);
	
	#If download file already exists => saving the old one as old.
	my $oldFile = $folder."old-Bind.txt";
	move($fileUncompressed, $oldFile) if (-e $fileUncompressed);
	
	print("Downloading ".__PACKAGE__." data... (Can be very long)\n");
	$ua->show_progress('true value');
	$res = $ua->request($req, $fileUncompressed);
	
	#Connexion failed unless the response is successful
	return ("", -2) unless($res->is_success);
	
	#Checking that the file is not a dummy html file
	unless(-e $fileUncompressed or open F, ">".$fileUncompressed ) {
		unlink($fileUncompressed);
		return ("", -2);
	}
	my $i = 0;
	while(<F>) {
		last if ($i == 30); 			#Checking only the first 30 lines
		if(/.*<html>.*/) {
			unlink ($fileUncompressed);
			return ("", -2);			 #File contains html :(
		}
		$i++;
	}
	close F;
	
	#Compare new and old file (if exists)
	if(-e $oldFile) {
		if($this->md5CheckFile($fileUncompressed, $oldFile)) {
			unlink($oldFile);
			return ($fileUncompressed, -1); # No need for update old and new are the same
		}
	}
	
	#Fully successful
	return ($fileUncompressed, 1);
}

1;

