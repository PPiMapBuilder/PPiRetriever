package DBpublic;   #Name for the package and for the class
use warnings;    	#Activate all warnings 
use strict;      	#Variable declaration control
use Carp;        	#Additionnal user warnings

use File::Copy;
use Data::Dumper;
use Digest::MD5;
use IO::Uncompress::AnyUncompress qw(anyuncompress $AnyUncompressError) ;
use HTTP::Cookies;
use LWP::UserAgent;
use LWP::Simple;
use Archive::Extract;

use Interaction;

#Will contain an array of 10 interaction objects
#Filling funcitons during data parsing
#parse(), fillTab(), sendKeuv() and reset()


sub new {
	my ( $classe ) = @_;		#Sending arguments to constructor
	my $this = {
 		"ArrayInteraction" => []
	};

	bless( $this, $classe );	#Linking the reference to the class
	return $this;               #Returning the blessed reference
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


sub gene_name_to_uniprot_id () {
	my ($first, $organism) = @_;

	my $query = $first.' AND organism:"'.$organism.'" AND reviewed:yes';
	my $file = get("http://www.uniprot.org/uniprot/?query=".$query."&sort=score&format=xml"); die "Couldn't get it!" unless defined $file;

	if ($file =~ /<accession>(\S+)<\/accession>/s) {
		return $1;
	}
}

sub uniprot_id_to_gene_name() {
	my ($uniprot_id) = @_;
	my $file = get("http://www.uniprot.org/uniprot/".$uniprot_id.".xml");
	die "Couldn't get it!" unless defined $file;
	
	if ($file =~ /<gene>\n<name\stype=\"primary\">(\S+)<\/name>\n.+<\/gene>/s) {
		return $1;
	}
	else {
		return "";
	}
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
	my @uncompressedFiles;
	foreach (@files) {
		if(/.*\.txt$/) {
			push(@uncompressedFiles, $folder.$_);
		} else {
			unlink($folder.$_); # deleting other files
		}
	}
	
	my $uncompressedFile = "";
	if(scalar(@uncompressedFiles) > 1) {
		foreach(@uncompressedFiles) {
			print $_."\n";
			if(/$pathUncompressedFile/i) { 		#If this file has the same name as the one in $pathUncompressedFile (case insentitive)
				$uncompressedFile = $_; 		#Saving this file
			} else {
				unlink($_);						#Deleting others...
			}
		}
		
		#Failed to select correct txt file from the one extracted
		return -1 if($uncompressedFile == "");
	} else {
		$uncompressedFile = $uncompressedFiles[0];
	}
	
	#Renaming the uncompressed file as $pathUncompressedFile
	move $uncompressedFile, $pathUncompressedFile or return -1;
	
	#Ok if $pathUncompressedFile does exists
	return (-e $pathUncompressedFile) ? $pathUncompressedFile : -1;
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
#returns	=>	The folder path
#			=>	The file name (if there is any)
#			=>	The extension of the file (if there is any)
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

	
