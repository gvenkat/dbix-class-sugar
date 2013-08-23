use strict;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use DBICTest;
use Data::Dumper;

use DBIx::Class::Sugar;

my $schema = DBICTest->init_schema;

ok( $schema );

schema $schema;

ok( schema );

eval {
  schema 'moo';
};

like( $@, qr/DBIx::Class::Schema/, 'throws exception' );

can_ok( 'DBIx::Class::Sugar', 'get_source' );
ok( @{ +sources }, 'has registered sources' );

my $rs = rs 'Employee'; 
isa_ok( $rs, 'DBIx::Class::ResultSet' );

done_testing;

