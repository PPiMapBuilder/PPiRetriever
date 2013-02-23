package Interaction;    # Nom du package, de notre classe
use warnings;        # Avertissement des messages d'erreurs
use strict;          # Vérification des déclarations
use Carp;            # Utile pour émettre certains avertissements


#constructeur
sub new {
 my ( $classe, $A, $B, $organism, $database, $pubmed, $sys_exp) = @_;    #on passe les données au constructeur
 my $this = {
  "A" => [],
  "B" => [],
  "organism" => $organism,
  "database" => $database,
  "pubmed" => [],
  "sys_exp" => []
 };
 
 @{$this->{A}} = @{$A};
 @{$this->{B}} = @{$B};
 @{$this->{pubmed}} = @{$pubmed}; 
 @{$this->{sys_exp}} = @{$sys_exp};
 
 bless( $this, $classe );      #lie la référence à la classe

 return $this;		   #on retourne la référence consacrée
}

sub afficheA {
	my ($this) = @_;
	foreach my $sub (@{$this->{A}}) {
		print $sub."\t";
	}
	print "\n";
}


sub organism {
	my ( $this ) = @_;
	return $this->{organism};
}

sub toString {
	my ( $this ) = @_;
	print "Interaction A : ".@{$this->{A}}[0]."  ".@{$this->{A}}[1]."\n";
	print "Interaction B : ".@{$this->{B}}[0]."  ".@{$this->{B}}[1]."\n";
	print "Organism : ".$this->{organism}."\n";
	print "Database : ".$this->{database}."\n";
	print "Pubmed : ";
	foreach (sort @{$this->{pubmed}}) {print "$_\t";}
	print "\nExperimental system : ";
	foreach (sort @{$this->{sys_exp}}) {print "$_\t";}
	print "\n";
}
	

1;    #Attention ! Obligatoire lors de la création d'un module !


__END__
Le compilateur ne lira pas les lignes après elle
