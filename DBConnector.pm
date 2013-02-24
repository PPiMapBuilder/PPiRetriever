package DBConnector;

use strict;
use warnings;
use DBI;

sub new() {
	my ( $class, $host, $port, $dbname, $username, $password ) = @_;

	my $this = {
		'_host'     => $host,
		'_port'     => $port,
		'_dbname'   => $dbname,
		'_username' => $username,
		'_password' => $password,
		'_dbh'      => undef,

		# should make following arguments editable
		'_autoCommit' => 0,
		'_raiseError' => 1,
		'_printError' => 0
	};

	$this->{'_dbh'} = DBI->connect(
		'dbi:Pg:dbname=' . $dbname . ';host=' . $host . ';port=' . $port,
		$username,
		$password,
		{
			AutoCommit => $this->{'_autoCommit'},
			RaiseError => $this->{'_raiseError'},
			PrintError => $this->{'_printError'}
		}
	);

	bless( $this, $class );
	return $this;
}

sub insert() {
	my ( $this, $PPiGrp ) = @_;

	# preparer toutes les requetes pour le groupe de PPi

	foreach my $PPi ( @{$PPiGrp} ) {
		                                 # executer les statements
	}

	# commit le tout
}

sub disconnect () {
	my ($this) = shift;
	eval { $this->{'dbh'}->disconnect() };
}

sub DESTROY {
	my ($this) = shift;
	$this->disconnect();
}

#-------------- DEBUG SUBs -------------#

sub dbg_select() {
	my ($this) = @_;

	my $sth = $this->{'_dbh'}->prepare("select count(*) as id from toto");
	$sth->execute();
	my $hash_ref = $sth->fetchall_hashref('id');

	return $hash_ref;
}

sub dbg_insert_random($) {
	my ( $this, $occ ) = @_;
	$occ = defined($occ) ? $occ : 1;
	my ( $name, $age );

	my $sth =
	  $this->{'_dbh'}->prepare("insert into toto(name, age) values(?,?)");

	for ( 1 .. $occ ) {
		$name = $this->generate_random_string( int( rand(7) ) + 4 );
		$age  = int( rand(33) ) + 15;

		$sth->execute( $name, $age );
	}
	$this->{'_dbh'}->commit();
}

sub generate_random_string {
	my ( $this, $len ) = @_;
	my @chars = ( 'a' .. 'z' );
	my $random_string;

	foreach ( 1 .. $len ) {
		$random_string .= $chars[ rand @chars ];
	}
	return $random_string;
}

1;

__END__

commentaires et documentation
