package main;
use strict; 
use Launch;

our $verbose = $ARGV[0];

my $launch = Launch->new("$ARGV[1]");

$launch->execute();


1;


