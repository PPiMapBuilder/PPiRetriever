package Launch;
use strict; 
use HPRD;
use Biogrid;
use Mint;
use Dip;
use Intact;

use DBConnector;


sub new {
	my ( $classe, $host, $port, $database, $user, $passwd ) = @_;		#Sending arguments to constructor
	my $this = {
 		"DBconnector" => DBConnector->new($host, $port, $database, $user, $passwd)
	};

	bless( $this, $classe );	#Linking the reference to the class
	return $this;               #Returning the blessed reference
}

sub execute {
	my ($this, $db, $taille) = @_;
	$taille = defined($taille) ? $taille : -1;
	
	my $database;
	
	if ($db eq "hprd") {
		$database = HPRD->new($this->{DBconnector});
		my ($path, $code) = $database->download();
		if ($code == 1 || $code == -1) {
			$database->parse($taille, $path);
		}
		
	}
	else {
		if ($db eq "biogrid") {
			$database = Biogrid->new($this->{DBconnector});
			my ($path, $code) = $database->download();
			if ($code == 1 || $code == -1) {
				$database->parse($taille, $path);
			}
		}
		else {
			if ($db eq "intact") {
				$database = Intact->new();
				my ($path, $code) = $database->download($this->{DBconnector});
				if ($code == 1 || $code == -1) {
					$database->parse($taille, $path);
				}
			}
			else {
				if ($db eq "dip") {
					$database = Dip->new("pidupuis", "toto", $this->{DBconnector});
					my ($path, $code) = $database->download();
					if ($code == 1 || $code == -1) {
						$database->parse($taille, $path);
					}
				}
				else {
					if ($db eq "mint") {
						$database = Mint->new($this->{DBconnector});
						my ($path, $code) = $database->download();
						if ($code == 1 || $code == -1) {
							$database->parse($taille, $path);
						}
					}
				}
			}
		}
	}
}
1;