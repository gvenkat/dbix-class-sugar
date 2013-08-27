{
  package __base;

  use strict;
  use Carp qw/confess/;

  our $AUTOLOAD;

  sub AUTOLOAD {
    my $self = shift;
    my @pieces = split( /::/, $AUTOLOAD );

    my $key = '__' . $pieces[ $#pieces ]; 


    if( exists( $self->{ $key } ) ) { 
      $self->{ $key };
    }

    elsif( exists( $self->{ $pieces[ $#pieces ] } )  ) {
      $self->{ $pieces[ $#pieces ] };
    }

    elsif( exists( $self->{clause} ) && exists( $self->{clause}{ $key } ) ) { 
      $self->{clause}{ $key };
    }

    else {
      confess( "Unknown method $key called on @{[ ref( $self ) ] }" );
    }
  }
}

{ 
  package __asis;

  use strict;
  use Carp qw/confess/;
  use Scalar::Util qw/blessed/;

  our @ISA = qw'__base';

  sub new {
    my ( $class, $value ) = @_;

    bless {
      value => $value
    }, $class;

  }

}



{
  package __select;

  use strict;
  use Carp qw/confess/;
  use Scalar::Util qw/blessed/;
  use Data::Dumper;

  our @ISA = qw'__base';


  sub new {

    my $class     = shift;
    my $select    = shift;

    if( $select ) {
      confess "Select expression needs to be an ARRAYREF or HASHREF"
        unless ref( $select ) =~ /(ARRAY)|(HASH)/;
    }

    bless {
      expression => $select
    }, $class;

  }

  sub process {

    my ( $self, @args ) = @_;

    my %clause = map {
      blessed( $_ ) => $_  
    } grep { 
      blessed( $_ ) =~ /^__/;
    } @args;

    $self->{clause} = \%clause;

    $self;

  }

  sub rs {
    my $self = shift;
    my $rs   = $self->from->rs;

    # apply select expression
    unless( $self->star ) {
      # do something here
    }

    my $has_clause = sub {
      $self->{clause}{ '__' . shift };
    };


    if( $has_clause->( 'where' ) ) { 
      $rs = $rs->search_rs( $self->where->condition );
    }

    # mix order, group, offset, limit clause
    # into the original
    # FIXME: add select
    {
      my $options = { };

      if( $has_clause->( 'order' ) ) {
        $options->{order_by} = $self->order->value;
      }

      if( $has_clause->( 'group' ) ) {
        $options->{group_by} = $self->group->value;
      }

      if( $has_clause->( 'limit' ) ) {

        if( $has_clause->( 'offset' ) ) {
          $options->{offset} = $self->offset->value;
        }

        $options->{limit} = $self->limit->value;
      }

      $rs = $rs->search_rs( undef, $options );
    }

    $rs;

  }

  sub star {
    my $exp = shift->expression;
    ref( $exp ) eq 'ARRAY' && scalar( @$exp ) == 1 && $exp->[0] eq '*';
  }

}



{
  package __from;

  our @ISA = qw'__base';

  use strict;
  use Carp qw/confess/;
  use Data::Dumper;

  sub new {
    my ( $class, $schema, $sugar, $expression ) = @_;

    bless {
      schema      => $schema,
      sugar       => $sugar,
      expression  => $expression
    }, $class;
  }

  sub rs {
    my $self = shift;

    # pretty simple, no joins
    $self->sugar_call( rs => $self->expression )

  }

  sub sugar_call {
    my ( $self, $callable, @arguments ) = @_;
    my $call = $self->sugar . '::' . $callable;

    { 
      no strict 'refs';
      my $c = \&$call;

      return $call->( @arguments );
    }

  }


}


{

  for my $klass ( qw/ order limit offset group where / ) {


    my $code = "
      package __$klass;

      use strict;
      our \@ISA = qw'__asis';

      # hack: must only be used in  where
      # this will be split away soon enough
      sub condition {
        shift->value;
      }

    ";

    eval $code;

  }

}



package DBIx::Class::Sugar;

use strict;

use Carp qw/
  confess
/;

use Scalar::Util qw/blessed/;
use Data::Dumper;

my $schema;
my $info;

sub compute_schema_info;

sub import {

  my $caller  = caller;

  my @methods = qw/
    call
    sources
    all
    schema
    rs
    select
    from
    join
    where
    group
    order
    limit
    offset
  /;

  {
    no strict 'refs';

    for my $method ( @methods ) {
      my $export = $caller . '::' . $method;
      *$export = *$method;
    }
  }

}

sub must_have_schema {
  confess "you must setup schema before you do anything crazy"
    unless schema();
}

sub sources () {
  $info;
}

sub rs ($) {
  my $source = get_source( shift );
  schema()->resultset( $source->{source_name} );
}

sub schema (;$) { 
  my $_schema = shift;

  if( $_schema && $_schema->isa( 'DBIx::Class::Schema' ) ) {
    $schema = $_schema;
    compute_schema_info;
  }

  elsif( $_schema ) {
    confess "\$schema needs to DBIx::Class::Schema";
  }

  $schema;
}

sub from    ($)   { 
  my $spec = shift;

  unless( ref( $spec ) ) {
    __from->new( schema(), __PACKAGE__,  $spec );
  } else {
    confess "Not completely implemented";
  }

}

sub select  ($;@) { 
  my $select_expression = shift;
  my $select; 

  if( ! ref( $select_expression ) ) {
    $select =  __select->new( [ $select_expression ] );
  }

  $select
    ->process( @_ )
    ->rs;

}


{
  no strict 'refs';
  for my $met ( qw/ where group order limit offset / ) {
    *$met = sub ($) {
      my $item = '__' . $met;
      $item->new( shift );
    };
  }
}

sub call    ($) {
  my $item = shift;

  \$item;
}

sub all (@) { 
  DBIx::Class::Sugar::select '*', @_;
}

sub compute_schema_info {

  my @info = ( ); 
  my @source_names = schema->sources;

  for my $source_name ( @source_names ) {
    my $source = schema->source( $source_name );

    # dont do it for views and other stuff
    if( ! $source->isa( 'DBIx::Class::ResultSource::View' ) ) { 
      push @info, {
        source_name => $source->source_name,
        name        => $source->name,
        table       => $source->name,
        source      => $source
      };
    }
  }
    
  $info = \@info;

}

sub get_source {
  my $name = shift;

  must_have_schema;

  my @sources = grep {
    ( $name eq $_->{source_name} )  ||
    ( $name eq $_->{name} )         ||
    ( $name eq $_->{table} )        
  } @{ $info };

  return undef if @sources == 0;

  if( @sources > 1 ) { 
    warn "more than once source found";
  }

  # return first item
  $sources[ 0 ];

}






1;
__END__
