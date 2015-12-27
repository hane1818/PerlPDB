package PDB;
use strict;
use warnings;

use Exporter qw(import);

our $VERSION    = 1.0;
our @ISA        = qw(Exporter);
our @EXPORT_OK  = qw(
    make_search_query
    );

use XML::Simple;
use LWP::UserAgent;

sub make_search_query {
    my ($key, $type)=@_;

    my @querytype = ('HoldingsQuery', 'ExpTypeQuery',
                    'AdvancedKeywordQuery','StructureIdQuery',
                    'ModifiedStructuresQuery', 'AdvancedAuthorQuery', 'MotifQuery',
                    'NoLigandQuery');
    my $querytype = join('|', @querytype);
    $querytype = '^('.$querytype.')$';
    if ( ! $type or $type !~ /$querytype/ ) {
        $type='AdvancedKeywordQuery'; }

    my %query;
    $query{'queryType'}=$type;
    if ( $type =~ /^AdvancedKeywordQuery$/ ) {

        $query{'description'} = 'Text Search for: ' . $key;
        $query{'keywords'} = $key;

    }elsif ( $type =~ /^NoLigandQuery$/ ) {

        $query{'haveLigands'} = 'yes';

    }elsif ( $type =~ /^AdvancedAuthorQuery$/ ) {

        $query{'description'} = 'Author Name: ' . $key;
        $query{'searchType'} = 'All Authors';
        $query{'audit_author.name'} = $key;
        $query{'exactMatch'} = 'false';

    }elsif ( $type =~ /^MotifQuery$/ ) {

        $query{'description'} = 'Motif Query For: ' . $key;
        $query{'motif'} = $key;

    }elsif ( $type =~ /^(StructureIdQuery|ModifiedStructuresQuery)$/ ) {

        $query{'structureIdList'} = $key;

    }elsif ( $type =~ /^ExpTypeQuery$/ ) {

        $query{'experimentalMethod'} = $key;
        $query{'description'} = 'Experimental Method Search : Experimental Method=' . $key;
        $query{'mvStructure.expMethod.value'} = $key;
    }

    my %scan_param;
    $scan_param{'orgPdbQuery'} = {%query};

    return %query;
}

sub search {
    my %query = @_;
    my $url = 'http://www.rcsb.org/pdb/rest/search';
    my $xml_root = 'orgPdbQuery';
    my $xml = {%query};
    my $queryText = XMLout($xml, NoAttr=>1, RootName=>$xml_root);

    my $request = HTTP::Request->new( POST => $url);
    $request->content_type( 'application/x-www-form-urlencoded' );
    $request->content( $queryText );

    my $response = LWP::UserAgent->new->request( $request );
    my $result = $response->content;
    if( ! $result ) { warn("No result"); }
    my @id_list = split("\n", $result);

    return @id_list;
}

search(make_search_query('actin'));

1;
