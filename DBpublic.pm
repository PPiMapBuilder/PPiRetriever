package DBpublic;    # Nom du package, de notre classe
use warnings;        # Avertissement des messages d'erreurs
use strict;          # Vérification des déclarations
use Carp;            # Utile pour émettre certains avertissements

use File::Copy;
use Data::Dumper;
use Digest::MD5;
use IO::Uncompress::AnyUncompress qw(anyuncompress $AnyUncompressError) ;
use HTTP::Cookies;
use LWP::UserAgent;

use Interaction;

#Va donc contenir un tableau de 10 objets d'interaction
#Fonction de remplissage lors du parsing
#parse(), rempliTab(), envoiKeuv() et reset()


sub new {
my ( $classe ) = @_;    #on passe les données au constructeur
 my $this = {
  "ArrayInteraction" => []
 };

 bless( $this, $classe );      #lie la référence à la classe
 return $this;		   #on retourne la référence consacrée
}


sub addInteraction {
	my ($this, $objet) = @_;
	push (@{$this->{ArrayInteraction}}, $objet);
}


sub getInteraction {
	my($this, $x) = @_;
	return @{$this->{ArrayInteraction}}[$x-1];
}


sub afficheTest {
	my ($this) = @_;
	print @{$this->{ArrayInteraction}}[0]->toString();
}


#Check if to file are the same (with MD5)
sub md5CheckFile ($$) {
	my ($md5a, $md5b);
	if(open( FILE1, $_[1] ) && open( FILE2, $_[2] )) {	
		$md5a = Digest::MD5->new->addfile(*FILE1)->clone->hexdigest;
		$md5b = Digest::MD5->new->addfile(*FILE2)->clone->hexdigest;
	}
	else {
		print "File not found in md5 comparison!\n";
		return 0;
	}
	return (($md5a cmp $md5b) == 0);
}


#Uncompressing file given in parameter
#@return	=> 	 1	if succeded
#				-1	if failed
sub fileUncompressing ($$) {
	my ($this) = @_;
	no warnings 'numeric';
	
	#Function arguments
	my $pathCompressedFile = $_[1];
	my $pathUncompressedFile = $_[2];
	
	#Extracting folder path from $pathCompressedFile
	my @pathInfo = $this->extractPathInfo($pathCompressedFile);
	my $folder = $pathInfo[0];
	return -1 if($folder == -1);
	
	#Uncompressing $pathCompressedFile in $folder
	my $ae = Archive::Extract->new(archive => $pathCompressedFile);
	my $ok = $ae->extract(to => $folder);
	
	#Uncompressing failed
	return -1 if(!$ok);
	
	#Getting the .txt file extracted
	my @files = @{($ae->files)};
	my $uncompressedFile;
	foreach (@files) {
		if(/.*\.txt$/) {
			$uncompressedFile = $folder.$_;
		} else {
			unlink($folder.$_);
		}
	}
	
	#Renaming the uncompressed file as $pathUncompressedFile
	move $uncompressedFile, $pathUncompressedFile or return -1;
	
	return 1;
}


#Setting the working folder
#returns -1 if folder can't be created
#returns the relative path to folder if succeeded
sub setDownloadFolder($) {
	my $folder = $_[1]."/";
	unless ( -e $folder or mkdir $folder ) {
		print( "Unable to find/create " . $folder . "\n" );
		return -1;
	}
	return $folder;
}


#Function checking if the $newVersion is different from the one stored in $filename
#	If $file doesn't exists or if version in $file != $newVersion 
#		=> $newVersion is really new
#   Else if version in $file == $newVersion 
#		=> $newVersion is same as before (no need for update)
sub checkVersion ($$) {
	my $file = $_[1];
	my $newVersion = $_[2];
	
	#Creating file if doesn't exists
	unless(-e $file) {
		unless(open F, ">".$file) {
			print "Cannot open version file";
			return -1
		};  
		print F "";
		close(F)
	}
	
	#Opening version file
	open( VERSION, '+<', $file ) || die "Cannot open version file";
	
	my $current = do { local $/; <VERSION> };
	
	no warnings 'numeric';
	if ( int($newVersion) == int($current) && $current != "" ) {
		print("No need for update.\n");
		return -1;    # No update needed
	} else {
		seek(VERSION, 0, 0);
		print VERSION $newVersion;    #Saving the new date to version.txt
	}
	
	close(VERSION);
}


#Extract folder, file name (without extension) and the extension of a file path
sub extractPathInfo ($) {
	my $path = $_[1];
	
	if($path =~ /^\/?(.+\/)*([0-9a-zA-Z_-]+)((\.\w+)*)$/) { 
		return ($1, $2, $3);
	} else {
		print "Invalid file name. "; 
		return -1;
	}
}

#Create and setup the user agent
sub setUserAgent {
	my $cookieFile = $_[1];
	
	my $ua = LWP::UserAgent->new;
	$ua->agent('Mozilla/5.5 (compatible; MSIE 5.5; Windows NT 5.1)');
	
	if($cookieFile) {
		my $cookie = HTTP::Cookies->new( file => $cookieFile, autosave => 1 );
		$ua->cookie_jar($cookie);
		return $ua, $cookie;
	}
	return $ua;
}

1;

	
