use strict;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use DBICTest;
use Data::Dumper;

use DBIx::Class::Sugar;

schema( DBICTest->init_schema );

my $rs = all from 'employee';
isa_ok( $rs, 'DBIx::Class::ResultSet' );
ok( schema->resultset( 'Employee' )->count == $rs->count );

$rs = select '*' 
  => from 'employee';

ok( schema->resultset( 'Employee' )->count == $rs->count );




done_testing;
