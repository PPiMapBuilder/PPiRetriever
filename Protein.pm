package Protein;

use warnings;
use strict;

sub new {
	my ( $class, $uniprot_id, $gene_name, $org_tax_id ) = @_;
	
	my $this = {

	   # TODO : creer des objets Protein(unirpto_id, gene_name, organism_tax_id)
		"uniprot_id"  => $uniprot_id,
		"gene_name"   => $gene_name,
		"orga_tax_id" => $org_tax_id
	};

	bless( $this, $class );
	return $this;
}

sub toString {
	my ($this) = @_;
	
	print "Uniprot ID : ".$this->{uniprot_id}."\n";
	print "Gene Name : ".$this->{gene_name}."\n";
	print "Tax ID : ".$this->{orga_tax_id}."\n";
}

1;

__END__
