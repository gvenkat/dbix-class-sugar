# DBIx::Class::Sugar

My attempt at adding sugar layer over querying DBIx::Class, Its at a very alpha stage.
Its just a play project, there's no intention to make it more comprehensive

```perl
  use DBIx::Class::Sugar;

  schema $schema;

  # from can be passed 'table' OR result source name
  my $rs = all from 'employee';

  # call find
  my $row = get 20 
    => from 'employee'

  # same as above
  my $rs = select '*' 
    => from 'employee';

  # select specific columns
  my $rs = select [ qw/id name dob/ ]
    => from 'employee';

  # larger example 
  $rs = select '*'
    => from 'employee' 
    => where $sqlt_clause
    => order 'name' 
    => limit 10
    => offset 15
    => each {
      my $row = shift;
    };

```

