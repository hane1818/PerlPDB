package PDB;
use strict;
use warnings;

use Exporter qw(import);

our $VERSION    = 1.0;
our @ISA        = qw(Exporter);
our @EXPORT_OK  = qw(
    make_search_query
    );

sub make_search_query {
    my ($key, $type)=@_;
    my @querytype = ('HoldingsQuery', 'ExpTypeQuery',
                    'AdvancedKeywordQuery','StructureIdQuery',
                    'ModifiedStructuresQuery', 'AdvancedAuthorQuery', 'MotifQuery',
                    'NoLigandQuery');
    if ( ! grep { $_ eq $type } @querytype) {
        $type='AdvancedKeywordQuery'; }
    my %query;
    $query{'queryType'}=$type;
}

make_search_query('Hello', 'ohno');
1;
