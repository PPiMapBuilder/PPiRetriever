package Interaction;

use warnings;
use strict;

#constructeur
sub new {
	my ( $classe, $A, $B, $database, $pubmed, $sys_exp ) = @_;
	my $this = {
		# TODO : creer des objets Protein(unirpto_id, gene_name, organism_tax_id)
		"A"        => $A,
		"B"        => $B,
		"database" => $database,
		"pubmed"   => [],
		"sys_exp"  => []
	};

	@{ $this->{pubmed} }  = @{$pubmed};
	@{ $this->{sys_exp} } = @{$sys_exp};

	bless( $this, $classe );            #Linking the reference to the class
	return $this;                       #Returning the blessed reference
}

sub getUniprotA {
	my ($this) = @_;
	return $this->{A}->{uniprot_id};
}

sub getGeneNameA {
	my ($this) = @_;
	return $this->{A}->{gene_name};	
}

sub getTaxIdA {
	my ($this) = @_;
	return $this->{A}->{orga_tax_id};	
}

sub getUniprotB {
	my ($this) = @_;
	return $this->{B}->{uniprot_id};
}

sub getGeneNameB {
	my ($this) = @_;
	return $this->{B}->{gene_name};	
}

sub getTaxIdB {
	my ($this) = @_;
	return $this->{B}->{orga_tax_id};	
}


sub toString {
	my ($this) = @_;

	print "Interactor A:\n"
	  . " - UniprotID: "
	  . $this->getUniprotA() . "\n"
	  . " - Gene name: "
	  . $this->getGeneNameA() . "\n"
	  . " - TaxID: "
	  . $this->getTaxIdA() . "\n"
	  . "Interactor B:\n"
	  . " - UniprotID: "
	  . $this->getUniprotB() . "\n"
	  . " - Gene name: "
	  . $this->getGeneNameB() . "\n"
  	  . " - TaxID: "
	  . $this->getTaxIdB() . "\n"
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
