package Biogrid;

use warnings;    # Avertissement des messages d'erreurs
use strict;      # Vérification des déclarations
use Carp;        # Utile pour émettre certains avertissements

use DBpublic;
use Interaction;
use LWP::Simple;

$SIG{INT} = \&catch_ctrlc;

our @ISA = ("DBpublic");

sub new {
	my ($classe) = @_;                  #on passe les données au constructeur
	my $this = $classe->SUPER::new();
	bless( $this, $classe );            #lie la référence à la classe
	return $this;                       #on retourne la référence consacrée

}

sub parse {

	my ($this) = @_;

	my %hash_orga_tax = (
		'3702'  => 'Arabidopsis thaliana',
		'6239'  => 'Caenorhabditis elegans',
		'7227'  => 'Drosophilia Melanogaster',
		'9606'  => 'Homo sapiens',
		'10090' => 'Mus musculus',
		'4932'  => 'Saccharomyces cerevisiae',
		'4896'  => 'Schizosaccharomyces pombe'
	);

	my $hash_orga_tax = {};
	open( gene_name_to_uniprot_file, "gene_name_to_uniprot_database.txt" );
	while (<gene_name_to_uniprot_file>) {
		chomp($_);
		my @convertion_data = split( /\t/, $_ );
		$hash_orga_tax->{ $convertion_data[0] }->{ $convertion_data[2] } =
		  $convertion_data[1];
	}
	close(gene_name_to_uniprot_file);

	open( data_file, "BIOGRID.txt" );
	my $database = 'Biogrid';

	my $i = 1;

	open( gene_name_to_uniprot_file, ">>gene_name_to_uniprot_database.txt" );
	while (<data_file>) {

		chomp($_);

		if ( $_ =~ m/^#/ig ) {
			next;
		}

		#if ($i == 10) {
		#	exit;
		#}

		my $intA      = undef;
		my $uniprot_A = undef;
		my $intB      = undef;
		my $uniprot_B = undef;
		my $exp_syst  = undef;
		my $pubmed    = undef;
		my $origin    = undef;
		my $pred      = undef;

		my $orga_query;

		my @data = split( /\t/, $_ );

		foreach my $tax_id ( keys %hash_orga_tax ) {
			if ( $data[16] eq $tax_id ) {    # If the taxonomy id is present
				$origin =
				  $hash_orga_tax{$tax_id};    # We retrieve the organism name
				$orga_query = "$hash_orga_tax{$tax_id} [$tax_id]";
				if ( $tax_id eq '9606' ) {
					$pred = 'Human';
				}
				else {
					$pred = 'Interolog';
				}
				last;
			}

		}

		if ( !$origin ) {
			next;
		}

		my $internet = undef;

		$intA = $data[7];
		if ( exists( $hash_orga_tax->{$intA}->{$orga_query} ) ) {
			$uniprot_A = $hash_orga_tax->{$intA}->{$orga_query};
		}
		else {
			$uniprot_A = gene_name_to_uniprot_id( $intA, $orga_query );
			$hash_orga_tax->{$intA}->{$orga_query} = $uniprot_A;
			print gene_name_to_uniprot_file "$intA\t$uniprot_A\t$orga_query\n";
			$internet .= 'i';
		}

		$intB = $data[8];
		if ( exists( $hash_orga_tax->{$intB}->{$orga_query} ) ) {
			$uniprot_B = $hash_orga_tax->{$intB}->{$orga_query};
		}
		else {
			$uniprot_B = gene_name_to_uniprot_id( $intB, $orga_query );
			$hash_orga_tax->{$intB}->{$orga_query} = $uniprot_B;
			print gene_name_to_uniprot_file "$intB\t$uniprot_B\t$orga_query\n";
			$internet .= 'i';
		}

		if ( !defined($uniprot_A) || !defined($uniprot_B) ) {
			next;
		}

		$exp_syst = $data[11];
		$pubmed   = $data[14] . "[uid]";

		my @A = ( $uniprot_A, $intA );
		my @B = ( $uniprot_B, $intB );
		my @pubmed  = ($pubmed);
		my @sys_exp = ($exp_syst);

		my $interaction =
		  Interaction->new( \@A, \@B, $origin, $database, \@pubmed, \@sys_exp );

		$this->SUPER::addInteraction($interaction);

#print "$i $internet\t$intA\t$uniprot_A\t$intB\t$uniprot_B\t$exp_syst\t$origin\t$database\t$pubmed\t$pred\n";

		$i++;

	}
}
1;

