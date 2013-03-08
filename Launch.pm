package Launch;
use strict; 
use HPRD;



sub new {
	my ( $classe, $database ) = @_;		#Sending arguments to constructor
	my $this = {
 		"db" => $database
	};

	bless( $this, $classe );	#Linking the reference to the class
	return $this;               #Returning the blessed reference
}

sub execute {
	my ($this) = @_;
	
	if ($this->{db} eq "hprd") {
		my $hprd = HPRD->new();
		my ($path, $code) = $hprd->download();
		if ($code == 1 || $code == -1) {
			$hprd->parse();
			print $main::verbose."\n";
		}
		
	}
	else {print "patate\n";}
	
	
	
}
1;