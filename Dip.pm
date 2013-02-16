package Dip;

use warnings;    # Avertissement des messages d'erreurs
use strict;      # Vérification des déclarations
use Carp;        # Utile pour émettre certains avertissements

use DBpublic;
use Interaction;

use LWP::Simple;
use LWP::UserAgent;
use LWP::Simple;
use File::Copy;
use HTTP::Cookies;

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

sub download {
	my ($this) = @_;
	
	sub LoggingAndDownloadPage {
		my $ua = shift;    # First function paramter: a user agent

		#Sending first HTTP request (login)
		my $req = HTTP::Request->new(POST => "http://dip.doe-mbi.ucla.edu/dip/Login.cgi" );
		$req->content("login=pidupuis&pass=toto&Login=Login&lgn=1");#Login informations
		$ua->request($req);

		#Little sleep making HTTP request more natural
		sleep(2);

		#Sending second HTTP request (get download page)
		$req = HTTP::Request->new(GET => "http://dip.doe-mbi.ucla.edu/dip/Download.cgi?SM=3" );
		return ( $ua->request($req) )->content;
	}
	
	
	#working folder (with the name of current DB)
	my $folder = $this->setDownloadFolder(uc(__PACKAGE__));

	#if unable to create folder
	no warnings 'numeric';
	return -3 if(int($folder) == -1);
	use warnings 'numeric';
		
	#Preparing the user agent and the cookie storage
	my $ua = LWP::UserAgent->new;
	my $cookie = HTTP::Cookies->new( file => $folder . "cookies.txt", autosave => 1 );
	$ua->cookie_jar($cookie);
	$ua->agent('Mozilla/5.5 (compatible; MSIE 5.5; Windows NT 5.1)');

	#Getting the download page (with multiple attempt)
	my $download_page = "";
	my $attempt = 1;
	until ( $download_page =~ /HREF="(.+\.txt\.gz)">HTTP/m ) {
		if ( $attempt == 6 ) { return -2; }

		print("Connecting to ".__PACKAGE__."... ");
		if ( $attempt > 1 ) { print( "(Attempt #" . $attempt . ")" ); }
		print("\n");

		sleep(1);
		$download_page = LoggingAndDownloadPage($ua);

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
			no warnings;
			return -1 if $this->checkVersion($folder."version.txt", $1) == -1; # No need for update, No need for download
			use warnings;
		}
		
		print("Downloading ".__PACKAGE__." data...\n");
		my $saveFile = __PACKAGE__.$extension;
		my $savePath = $folder . $saveFile;

		#If download file already exists => saving the old one as old.
		my $oldFile = $folder."old-".$saveFile;
		move($savePath, $oldFile) if (-e $savePath);

		#Downloading the date file in DIP.txt.gz
		$ua->show_progress('true value');
		$ua->get( $dataFile, ':content_file' => $savePath );
		print("Done!\n");

		#Clearing cookies
		$cookie->clear();

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
		}
		else {
			print("Download failed.\n");
			return -2;    #No data recieved from DIP
		}
	}
	else {
		print("Download failed.\n");
		return -2;        #No data recieved from DIP
	}
}
1;

