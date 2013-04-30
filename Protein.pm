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

1;

__END__
