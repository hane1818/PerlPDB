package PDB;
use strict;
use warnings;

use Exporter qw(import);

our $VERSION    = 1.0;
our @ISA        = qw(Exporter);
our @EXPORT_OK  = qw(
    make_search_query, search,
    search_protsym, get_pdbid_info,
    get_all_pdbid, get_pdbid_file,
    );

use XML::Simple;
use XML::Parser;
use LWP::UserAgent;
use URI;
use Data::Dumper;
use HTML::TokeParser;

sub make_search_query {
    my ($key, %kwargs)=@_;

    my @querytype = ('HoldingsQuery', 'ExpTypeQuery',
                    'AdvancedKeywordQuery','StructureIdQuery',
                    'ModifiedStructuresQuery', 'AdvancedAuthorQuery', 'MotifQuery',
                    'NoLigandQuery');
    my $querytype = join('|', @querytype);
    $querytype = '^('.$querytype.')$';
    if ( ! $kwargs{type} or $kwargs{type} !~ /$querytype/i ) {
        $kwargs{type}='AdvancedKeywordQuery'; }

    my %query;
    $query{'queryType'}=$kwargs{type};
    if ( $kwargs{type} =~ /^AdvancedKeywordQuery$/i ) {

        $query{'description'} = 'Text Search for: ' . $key;
        $query{'keywords'} = $key;

    }elsif ( $kwargs{type} =~ /^NoLigandQuery$/i ) {

        $query{'haveLigands'} = 'yes';

    }elsif ( $kwargs{type} =~ /^AdvancedAuthorQuery$/i ) {

        $query{'description'} = 'Author Name: ' . $key;
        $query{'searchType'} = 'All Authors';
        $query{'audit_author.name'} = $key;
        $query{'exactMatch'} = 'false';

    }elsif ( $kwargs{type} =~ /^MotifQuery$/i ) {

        $query{'description'} = 'Motif Query For: ' . $key;
        $query{'motif'} = $key;

    }elsif ( $kwargs{type} =~ /^(StructureIdQuery|ModifiedStructuresQuery)$/i ) {

        $query{'structureIdList'} = $key;

    }elsif ( $kwargs{type} =~ /^ExpTypeQuery$/i ) {

        $query{'experimentalMethod'} = $key;
        $query{'description'} = 'Experimental Method Search : Experimental Method=' . $key;
        $query{'mvStructure.expMethod.value'} = $key;
    }

    my %scan_param;
    $scan_param{'orgPdbQuery'} = {%query};

    return {%query};
}

sub search {
    my ($query) = @_;
    my $url = 'http://www.rcsb.org/pdb/rest/search';
    my $xml_root = 'orgPdbQuery';
    my $xml = $query;
    my $queryText = XMLout($xml, NoAttr=>1, RootName=>$xml_root);

    my $request = HTTP::Request->new( POST => $url);
    $request->content_type( 'application/x-www-form-urlencoded' );
    $request->content( $queryText );

    my $response = LWP::UserAgent->new->request( $request );
    my $result = $response->content;
    if( ! $result ) { warn("No result"); }
    my @id_list = split("\n", $result);

    return [@id_list];
}

sub search_protsym {
    # Protein symmetry search of the PDB
    my ($point_group, %kwargs) = @_;
    if( ! $kwargs{min_rmsd} ) { $kwargs{min_rmsd} = 0.0; }
    if( ! $kwargs{max_rmsd} ) { $kwargs{max_rmsd} = 7.0; }

    my %query = (
        'queryType' => 'PointGroupQuery',
        'rMSDComparator' => 'between',
        'pointGroup' => $point_group,
        'rMSDMin' => $kwargs{min_rmsd},
        'rMSDMax' => $kwargs{max_rmsd});

    my $id_list = search({%query});
    return $id_list;
}

sub get_all_pdbid {
    # Get all PDB entries currently in the RCSB Protein Data Bank
    my $url = 'http://www.rcsb.org/pdb/rest/getCurrent';
    my $request = HTTP::Request->new( GET => $url);
    my $response = LWP::UserAgent->new->request( $request );

    my @results = $response->content =~ /structureId=\"(.+)\"/g;
    return [@results];
}

sub get_pdbid_info {
    # Look up all information in RCSB PDB about a given PDB ID
    my ($pdb_id) = @_;
    my $url = URI->new( 'http://www.rcsb.org/pdb/rest/describeMol' );
    $url->query_form( 'structureId' => $pdb_id );

    my $response = LWP::UserAgent->new->get( $url );
    my $result = XMLin( $response->content , KeepRoot => 1);
    my %result = % { $result };

    return $result{'molDescription'}{'structureId'};
}

sub get_pdbid_file {
    # Get the full PDB file associated with a PDB_ID
    my ($pdb_id, %kwargs) = @_;
    if( ! $kwargs{file_type} or $kwargs{file_type} !~ /^(pdb|cif|xml|structfact)$/i ) { $kwargs{file_type} = 'pdb'; }
    if( ! $kwargs{compression} or $kwargs{compression} !~ /^(true|yes|y|t)$/i ) { $kwargs{compression} = 'NO'; }
    else { $kwargs{compression} = 'YES'; }

    my $url = URI->new( 'http://www.rcsb.org/pdb/download/downloadFile.do' );
    $url->query_form( 'fileFormat' => $kwargs{file_type},
                      'compression' => $kwargs{compression},
                      'structureId' => $pdb_id );

    my $response = LWP::UserAgent->new->get( $url );
    my $result = $response->content;

    return $result;
}

sub get_raw_blast {
    # Look up full BLAST page for a given PDB ID
    # get_blast() uses this function internally
    my ($pdb_id, %kwargs) = @_;
    if( ! $kwargs{output_form} or $kwargs{output_form} !~ /^(TXT|HTML|XML)$/i ) { $kwargs{output_form} = 'HTML'; }
    if( ! $kwargs{chain_id} ) { $kwargs{chain_id} = 'A'; }

    my $url = URI->new( 'http://www.rcsb.org/pdb/rest/getBlastPDB2' );
    $url->query_form( 'structureId' => $pdb_id,
                      'chainId' => $kwargs{chain_id},
                      'outputFormat' => $kwargs{output_form} );

    my $response = LWP::UserAgent->new->get( $url );
    my $result = $response->content;

    return $result;
}

sub parse_blast {
    my ($html) = @_;
    my $parser = HTML::TokeParser->new( \$html );

    my @blasts;
    my @blast_ids;
    my @all_pdb_id = @{&get_all_pdbid};
    my $all_pdb_id = join('|', @all_pdb_id);

    while( my $token = $parser->get_token) {
        my $ttype = shift @{ $token };
        my $ttype2;
        if($ttype eq 'S') {
            my($tag, $attr, $attrseq, $rawtxt) = @{ $token };
            if($tag eq 'pre') {
                $parser->get_token;   #remove Text
                my $token2 = $parser->get_token;
                $ttype2 = shift @{ $token2 };
                my($tag2, $attr, $attrseq, $rawtxt) = @{ $token2 };
                if($ttype2 eq 'S' and $tag2 eq 'a')
                {
                    $parser->get_token;
                    my $blast = $parser->get_token->[1];
                    my $blast_id = substr($blast, 0, 4);
                    if( $blast_id =~ /$all_pdb_id/i ) {
                        push (@blasts, $blast);
                        push (@blast_ids, $blast_id);
                    }
                }
            }
        }
    }
    return [[@blast_ids], [@blasts]];
}

sub get_blast {
    # Alternative way to look up BLAST for a given PDB ID.
    my ($pdb_id, %kwargs) = @_;
    if ( ! $kwargs{chain_id} ) { $kwargs{chain_id} = 'A'; }
    if ( ! $kwargs{output_form} ) { $kwargs{output_form} = 'HTML'; }

    my $result = parse_blast( get_raw_blast( $pdb_id, $kwargs{chain_id}, $kwargs{output_form} ) );
    return $result;
}
my $result;
$result = make_search_query('actin');
# $result = search(make_search_query('actin'));
# $result = search_protsym('C9');
# $result = get_pdbid_info('4lza');
# $result = get_pdbid_file('4lza');
# $result = get_raw_blast('4lza', output_form=>'xml', chain_id=>'B');
# $result = get_blast('4lza');
print Dumper $result;

#get_blast('4LZA', chain_id=>'A', output_form=>'html');
#print get_pdbid_info('4LZA');

1;
