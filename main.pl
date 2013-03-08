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

our $verbose;

  my $result = GetOptions ("parse=s" => \$parse, 
  						"host=s" => \$host,
  						"port=i" => \$port,
  						"database=s" => \$database,
  						"user=s" => \$user,
  						"password=s" => \$password,
  						"debug:i" => \$debug,
                        "help"   => \$help,    
						"verbose"  => \$verbose); 

my $launch = Launch->new($host, $port, $database, $user, $password);

$launch->execute(lc($parse), $debug);


1;


