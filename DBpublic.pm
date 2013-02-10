package DBpublic;    # Nom du package, de notre classe
use warnings;        # Avertissement des messages d'erreurs
use strict;          # Vérification des déclarations
use Carp;            # Utile pour émettre certains avertissements

use Interaction;

#Va donc contenir un tableau de 10 objets d'interaction
#Fonction de remplissage lors du parsing
#parse(), rempliTab(), envoiKeuv() et reset()


sub new {
my ( $classe ) = @_;    #on passe les données au constructeur
 my $this = {
  "ArrayInteraction" => []
 };

 bless( $this, $classe );      #lie la référence à la classe
 return $this;		   #on retourne la référence consacrée
}

sub addInteraction {
	my ($this, $objet) = @_;
	push (@{$this->{ArrayInteraction}}, $objet);
}

sub getInteraction {
	my($this, $x) = @_;
	return @{$this->{ArrayInteraction}}[$x-1];
}

sub afficheTest {
	my ($this) = @_;
	print @{$this->{ArrayInteraction}}[0]->Interaction::toString();
}




1;

	
