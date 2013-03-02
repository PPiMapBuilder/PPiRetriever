package DBpublic;   #Name for the package and for the class
use warnings;    	#Activate all warnings 
use strict;      	#Variable declaration control
use Carp;        	#Additionnal user warnings

use File::Copy;
use Digest::MD5;
use HTTP::Cookies;
use LWP::UserAgent;
use Archive::Extract;

use LWP::Simple; #Needed to use the function get

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
	my ($this, $first, $organism) = @_;

	my $query = $first.' AND organism:"'.$organism.'" AND reviewed:yes';
	my $file = get("http://www.uniprot.org/uniprot/?query=".$query."&sort=score&format=xml"); die "Couldn't get it!" unless defined $file;

	if ($file =~ /<accession>(\S+)<\/accession>/s) {
		return $1;
	}
}


sub uniprot_id_to_gene_name() {
	my ($this, $uniprot) = @_;
	
	my $file = get("http://www.uniprot.org/uniprot/".$uniprot.".xml");
	die "Couldn't get it!" unless defined $file;
	
	if ($file =~ /<gene>\n<name\stype=\"primary\">(\S+)<\/name>\n.+<\/gene>/s) {
		return $1;
	}
	else {
		return "";
	}
}


#Check if two files are identical (with MD5)
#	@param	$file1	=>	Path to first file you want to test
#	@param	$file2	=>	Path to second file you want to test
#	@return	=> -1 If an error occured
#			=>  1 If the two files are identical
#			=>  0 If the two files are different	
sub md5CheckFile ($$) {
	my ($this, $file1, $file2) = @_;
	my ($md5a, $md5b);
	if(open( FILE1, $file1) && open( FILE2, $file2)) {	
		$md5a = Digest::MD5->new->addfile(*FILE1)->clone->hexdigest;
		$md5b = Digest::MD5->new->addfile(*FILE2)->clone->hexdigest;
	}
	else {
		print "File not found in md5 comparison!\n";
		return -1;
	}
	return (($md5a cmp $md5b) == 0)?1:0;
}


#Uncompressing file given in parameter
#	@return	=> 	 1	if succeded
#			=>	-1	if failed
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
			#print $_."\n";
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


#Setting the working folder (check if the folder exist or create it)
#	@param	$folder	=>	Path to the folder
#	@return =>	-1 If the folder can't be created
#			=>	 The relative path to folder if succeeded
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
#
#	@param	$file		=> path to file storing the current version
#			$newVersion	=> version to test against the oen stored in $file
#
#	@return	=>	-1 Version in $file and $newVersion are the same
#			=>	-2 Can't find/create the version file
#			=>	 1 Version in $file and $newVersion are different
sub checkVersion ($$) {
	my ($this, $file, $newVersion) = @_;
	
	#Creating file if doesn't exists
	unless(-e $file) {
		unless(open F, ">".$file) {
			print "Cannot open version file";
			return -2
		}
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
	return 1;
}


#Extract folder, file name (without extension) and the extension of a file path
#	@return	=>	The folder path
#	@return	=>	The file name (if there is any)
#	@return	=>	The extension of the file (if there is any)
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
#	@return	=>	The new LWP::UserAgent
#	@return	=>	HTTP::Cookie used to store cookie during browsing
sub setUserAgent {
	my $ua = LWP::UserAgent->new;
	$ua->agent('Mozilla/5.5 (compatible; MSIE 5.5; Windows NT 5.1)');
	$ua->cookie_jar( HTTP::Cookies->new());
	return $ua;
}

1;

	
