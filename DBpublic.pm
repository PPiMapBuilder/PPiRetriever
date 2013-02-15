package DBpublic;    # Nom du package, de notre classe
use warnings;        # Avertissement des messages d'erreurs
use strict;          # Vérification des déclarations
use Carp;            # Utile pour émettre certains avertissements
use digest::MD5;
use IO::Uncompress::AnyUncompress qw(anyuncompress $AnyUncompressError) ;

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
	print @{$this->{ArrayInteraction}}[0]->Interaction::toString();
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
sub fileUncompressing ($) {
	my ($this) = @_;
	my $pathCompressedFile = $_[1];
	my $pathUncompressedFile = "./";
	
	#Getting file name, folder and extension of file path
	my @pathInfo = $this->extractPathInfo($pathCompressedFile);
	
	#File path format unrecognized
	no warnings 'numeric';
	if($pathInfo[0]  == -1) {
		print "Can't uncompress file!\n";
		return -1;
	}
	
	#Setting the folder and filename for uncompressing
	my $file = $pathInfo[0].$pathInfo[1];
	my $extension = $pathInfo[2];
	$extension =~ s/(\.tar|\.gz|\.zip)//g;
	$pathUncompressedFile = $file.$extension;
	
	#Uncompressing file	
	if(anyuncompress $pathCompressedFile => $pathUncompressedFile) {
		return $pathUncompressedFile;
	} else {
		print "Uncompressing failed: $AnyUncompressError\n";
		return -1;
	}
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
		print VERSION $1;    #Saving the new date to version.txt
	}
	
	close(VERSION);
}


#Extract folder, file name (without extension) and the extension of a file path
sub extractPathInfo ($) {
	my $path = $_[1];
	
	if($path =~ /^\/?(.+\/)*(\w+|)((\.\w+)*)$/) { 
		return ($1, $2, $3);
	} else {
		print "Invalid file name. "; 
		return -1;
	}
}

1;

	
