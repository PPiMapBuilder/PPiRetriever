package Mint;

use warnings;    # Avertissement des messages d'erreurs
use strict;      # Vérification des déclarations
use Carp;        # Utile pour émettre certains avertissements

use DBpublic;
use Interaction;

use LWP::UserAgent;
use LWP::Simple;
use File::Copy;
use Net::FTP;

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

