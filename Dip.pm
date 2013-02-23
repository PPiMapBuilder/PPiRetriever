package Dip;

use warnings;    # Avertissement des messages d'erreurs
use strict;      # Vérification des déclarations
use Carp;        # Utile pour émettre certains avertissements

use DBpublic;
use Interaction;

use LWP::UserAgent;
use LWP::Simple;
use File::Copy;

$SIG{INT} = \&catch_ctrlc;

our @ISA = ("DBpublic");

sub new {
	my ($classe) = @_;                  #on passe les données au constructeur
	my $this = $classe->SUPER::new();
	bless( $this, $classe );            #lie la référence à la classe
	return $this;                       #on retourne la référence consacrée

}

sub parse {
	
}


#Download and uncompress Dip data file
#	@return => the file path to .txt file
#			=> the sucess/failure code
#				 1  Sucess: New version found and downloaded			
#				-1  Sucess: No new version, no need for update
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

		#Downloading the date file in DIP.txt.gz
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

