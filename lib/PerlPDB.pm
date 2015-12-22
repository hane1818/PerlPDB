package PDB;
use strict;
use warnings;

use Exporter qw(import);

our $VERSION    = 1.0;
our @ISA        = qw(Exporter);
our @EXPORT_OK  = qw(
    make_search_query
    );

sub make_search_query{
    my (%query) = @_;
    print "make_search_query\n";
}

1;
