#!/usr/bin/perl

package main;
use strict; 
use Launch;
use Getopt::Long;

my $help;

my $parse;
my $host;
my $port;
my $database;
my $user;
my $password;
my $debug = undef;
my $path;


our $verbose;

  my $result = GetOptions (
			"parse=s" => \$parse, 
			"host=s" => \$host,
  			"port=i" => \$port,
  			"database=s" => \$database,
  			"user=s" => \$user,
  			"password=s" => \$password,
  			"debug:i" => \$debug,
			"help"   => \$help,
			"verbose"  => \$verbose,
			"path=s" => \$path
			); 

my $launch = Launch->new($host, $port, $database, $user, $password);
print ">> $path\n";

$launch->execute(lc($parse), $debug, $path);
1;


