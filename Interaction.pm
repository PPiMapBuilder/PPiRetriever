package Interaction;    # Nom du package, de notre classe

use warnings;           # Avertissement des messages d'erreurs
use strict;             # Vérification des déclarations
use Carp;               # Utile pour émettre certains avertissements

#constructeur
sub new {
	my ( $classe, $A, $B, $organism, $database, $pubmed, $sys_exp ) =
	  @_;
	my $this = {
		"A"        => [],
		"B"        => [],
		"organism" => $organism,
		"database" => $database,
		"pubmed"   => [],
		"sys_exp"  => []
	};

	@{ $this->{A} }       = @{$A};
	@{ $this->{B} }       = @{$B};
	@{ $this->{pubmed} }  = @{$pubmed};
	@{ $this->{sys_exp} } = @{$sys_exp};

	bless( $this, $classe );    #lie la référence à la classe

	return $this;               #on retourne la référence consacrée
}

sub afficheA {
	my ($this) = @_;
	foreach my $sub ( @{ $this->{A} } ) {
		print $sub. "\t";
	}
	print "\n";
}

sub organism {
	my ($this) = @_;
	return $this->{organism};
}

sub toString {
	my ($this) = @_;
	print "Interactor A:\n"
	  . " - UniprotID: "
	  . @{ $this->{A} }[0] . "\n"
	  . " - Gene name:"
	  . @{ $this->{A} }[1] . "\n"
	  . print "Interactor B:\n"
	  . " - UniprotID: "
	  . @{ $this->{B} }[1] . "\n"
	  . " - Gene name:"
	  . @{ $this->{B} }[1] . "\n"
	  . print "Organism : "
	  . $this->{organism} . "\n";
	print "Database : " . $this->{database} . "\n";
	print "Pubmed : ";
	print " - $_\n" foreach ( @{ $this->{pubmed} } );
	print "\nExperimental system : ";
	print " - $_\n" foreach ( @{ $this->{sys_exp} } );
}

1;

__END__

Format du toString() :
	Interactor A:
	 - UniprotID: uniprot1
	 - Gene name: genename1
	Interactor B:
	 - UniprotID: uniprot2
	 - Gene name: genename2
	Organism: 9606
	Database: biogrid
	Pubmed:
	 - 123456
	 - 654321 
	Experimental system:
	 - two-hybrid 
