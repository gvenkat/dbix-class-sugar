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
  => from 'tags';

ok( schema->resultset( 'Tag' )->count == $rs->count );

my $clause = { tag => 'Blue' };

$rs = select '*'
  => from 'tags'
  => where $clause;

my $t = schema->resultset( 'Tag' );

ok( $t->search_rs( $clause )->count == $rs->count );

$rs = select '*'
  => from 'tags'
  => order 'tag';

ok( $t->search_rs( undef, { order_by => 'tag' } )->first->tag eq $rs->first->tag ); 

$rs = select '*'
  => from 'tags'
  => order 'tag'
  => limit 1 
  => offset 5;

$rs = all from 'tags'
  => where $clause
  => group 'tag'
  => limit 1;


done_testing;
