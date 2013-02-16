use warnings;
use DBConnector;
use Data::Dumper;

$dbc = DBConnector->new('localhost', '5432', 'keuv', 'keuv', 'sugar*');

$dbc->dbg_insert_random(3);

$result = $dbc->dbg_select();

print Dumper($result);

$dbc->disconnect();

#----------------------------- SUB -----------------------------#
sub p($) {
	print Dumper @_;
}
