package Interaction;

use warnings;
use strict;

#constructeur
sub new {
	my ( $classe, $A, $B, $organism, $database, $pubmed, $sys_exp ) = @_;
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

	bless( $this, $classe );            #Linking the reference to the class
	return $this;                       #Returning the blessed reference
}

sub getUniprotA {
	my ($this) = @_;
	return @{ $this->{A} }[0];
}

sub getGeneNameA {
	my ($this) = @_;
	return @{ $this->{A} }[1];
}

sub getUniprotB {
	my ($this) = @_;
	return @{ $this->{B} }[0];
}

sub getGeneNameB {
	my ($this) = @_;
	return @{ $this->{B} }[1];
}

sub toString {
	my ($this) = @_;

	print "Interactor A:\n"
	  . " - UniprotID: "
	  . $this->getUniprotA() . "\n"
	  . " - Gene name: "
	  . $this->getGeneNameA() . "\n"
	  . "Interactor B:\n"
	  . " - UniprotID: "
	  . $this->getUniprotB() . "\n"
	  . " - Gene name: "
	  . $this->getGeneNameB() . "\n"
	  . "Organism : "
	  . $this->{organism} . "\n"
	  . "Database : "
	  . $this->{database}
	  . "\n";

	print "Pubmed :\n";
	foreach ( @{ $this->{pubmed} } ) {print "- $_\n" if (defined ($_));};
	print "Experimental system :\n";
	foreach ( @{ $this->{sys_exp} } ) {print "- $_\n" if (defined ($_));};
#	print "-------------------------\n";

}

1;

__END__

toString() format :
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
