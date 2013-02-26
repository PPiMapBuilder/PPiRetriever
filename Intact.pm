package Intact;

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
	my $ftp = Net::FTP->new("ftp.ebi.ac.uk", Debug => 0) 
		or return ("", -2);
	$ftp->login("anonymous","anonymous")
    	or return ("", -2);
	$ftp->cwd("/pub/databases/intact/")
    	or return ("", -2);
	my @latest = grep{/current/} $ftp->dir();
	
	my $latestVersion; #Number of latest version ex: 20130130
	my $versionFolder; #Folder of the latest version ex: 2013-01-30/
	#Extracting version date
	if($latest[0] =~ /(\d{4})-(\d{2})-(\d{2})$/) {
		$latestVersion = $1.$2.$3;
		$versionFolder = $1."-".$2."-".$3;
		
		print("Checking release date...\n");
		#Check the current available version on Mint server and stop program if current version stored in version.txt correspond to latest version
		return ($fileUncompressed, -1) if($this->checkVersion($folder."version.txt", $latestVersion) == -1);
	}
	
	#Go in current veriosn folder and set file to download
	$ftp->cwd($versionFolder."/psimitab/");
	my $url = "ftp://ftp.ebi.ac.uk".$ftp->pwd()."/intact.zip";
	
	#If download file already exists => saving the old one as old.
	my $oldFile = $folder."old-Intact.zip";
	move($savePath, $oldFile) if (-e $savePath);
		
	print("Downloading ".__PACKAGE__." data...\n");
	#Downloading the latest Mint full txt
	$ua->show_progress('true value');
	my $res = $ua->get($url, ':content_file' => $savePath);
		
	#Checking downloaded file
	unless($res->is_success or -f $savePath) {
		return ("", -2); #Connection failed
	}
		
	#Compare new and old file (if exists)
	if(-e $oldFile) {
		if($this->md5CheckFile($savePath, $oldFile)) {
			unlink($oldFile);		#Deleting old file since old and new are the same
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
	
	#Download completed successfully 
	return($fileUncompressed, 1);
}
1;

