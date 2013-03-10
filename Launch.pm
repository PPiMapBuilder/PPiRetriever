package Launch;
use strict; 
use HPRD;
use Biogrid;
use Mint;
use Dip;
use Intact;
use Bind;

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
	my ($this, $db, $taille, $path) = @_;
	$taille = defined($taille) ? $taille : -1;
	$path =defined($path) ? $path : "";

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
					else {
						if ($db eq "bind") {
							$database = Bind->new("ppimapbuilder\@gmail.com", "ppimapbuilder", $this->{DBconnector});
							#my ($path, $code) = $database->download();
							my $path = "BIND/Bind.txt"; my $code = 1;
							if ($code == 1 || $code == -1) {
								$database->parse($taille, $path);
							}
						}
					}
				}
			}
		}
	}
}
1;
