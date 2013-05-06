package Launch;
use strict;
use HPRD;
use Biogrid;
use Mint;
use Dip;
use Intact;
use Bind;

use HomoloGene;

use DBConnector;

use Data::Dumper;

sub new {
	my ( $classe, $host, $port, $database, $user, $passwd ) =
	  @_;    #Sending arguments to constructor
	my $this =
	  { 'DBconnector' => undef
	
	  };
	$this->{DBconnector} = DBConnector->new( $host, $port, $database, $user, $passwd );
	#print Dumper $this->{DBConnector};
	die "Cannot connect DBI\n" unless ($this->{DBconnector});
	bless( $this, $classe );    #Linking the reference to the class
	return $this;               #Returning the blessed reference
}

sub help {
	my ( $this ) = @_;
	print "Usage: perl main.pl\n\t--host host --parse <biogrid|intact|mint|hprd|bind>\n\t--port 1111\n\t--database <dbname>\n\t--user <username>\n\t--password <pswd>\n\t[-debug 123]\n\t[-v]\n";
	exit;
}

sub execute {
	my ( $this, $db, $taille, $path ) = @_;
	$taille = defined($taille) ? $taille : -1;
	$path   = defined($path)   ? $path   : "";

	my $database;

	if ( $db eq "hprd" ) {
		$database = HPRD->new( $this->{DBconnector} );
		my ( $path, $code ) = $database->download();
		if ( $code == 1 || $code == -1 ) {
			$database->parse( $taille, $path );
		}
	}
	elsif ( $db eq "biogrid" ) {
		$database = Biogrid->new( $this->{DBconnector} );
		my ( $path, $code ) = $database->download();
		if ( $code == 1 || $code == -1 ) {
			$database->parse( $taille, $path );
		}
	}
	elsif ( $db eq "intact" ) {
		$database = Intact->new( $this->{DBconnector} );
		my ( $path, $code ) = $database->download( $this->{DBconnector} );
		if ( $code == 1 || $code == -1 ) {
			$database->parse( $taille, $path );
		}
	}
	elsif ( $db eq "dip" ) {
		$database = Dip->new( "pidupuis", "toto", $this->{DBconnector} );
		my ( $path, $code ) = $database->download();
		if ( $code == 1 || $code == -1 ) {
			$database->parse( $taille, $path );
		}
	}
	elsif ( $db eq "mint" ) {
		$database = Mint->new( $this->{DBconnector} );
		my ( $path, $code ) = $database->download();
		if ( $code == 1 || $code == -1 ) {
			$database->parse( $taille, $path );
		}
	}
	elsif ( $db eq "bind" ) {
		$database =
		  Bind->new( "ppimapbuilder\@gmail.com", "ppimapbuilder",
			$this->{DBconnector} );

		#my ($path, $code) = $database->download();
		my $path = "BIND/Bind.txt";
		my $code = 1;
		if ( $code == 1 || $code == -1 ) {
			$database->parse( $taille, $path );
		}
	}
	elsif ( $db eq "homologene" ) {
		#print Dumper $this->{DBconnector};
		$database = HomoloGene->new( $this->{DBconnector} );
		#my ( $path, $code ) = $database->download( $this->{DBconnector} );
		#if ($code == 1 or $code == -1) {
			$database->parse("homologene.data.txt");
		#}
	}
	else {
		$this->help();
	}
}

1;
