#!/usr/bin/env perl

use SWISH::API;
use IO::File;

my $index = '/data/swish-e.idx';

my $swish = SWISH::API->new( $index );

my $query = $ARGV[0];

$swish->abort_last_error if $swish->Error;

my $search = $swish->new_search_object;

my $results = $search->execute( $query );

$swish->abort_last_error if $swish->Error;

my $hits = $results->hits;
if ( !$hits ) {
    print "No Results\n";
    exit;
}

print "Found ", $results->hits, " hits\n";

my @words = $results->parsed_words( $index );
print "@words\n";

while ( my $result = $results->next_result ) {
    my $filepath = $result->property( "swishdocpath" );
    printf("Path: %s\n  Rank: %lu\n  Size: %lu\n  Title: %s\n  Index: %s\n  Modified: %s\n  Record #: %lu\n  File   #: %lu\n\n",
        $result->property( "swishdocpath" ),
        $result->property( "swishrank" ),
        $result->property( "swishdocsize" ),
        $result->property( "swishtitle" ),
        $result->property( "swishdbfile" ),
        $result->result_property_str( "swishlastmodified" ),
        $result->property( "swishreccount" ),
        $result->property( "swishfilenum" )
    );
    my $fh = IO::File->new();
    $fh->open( $filepath );
    $fh->close;
}

# display properties and metanames

for my $index_name ( $swish->index_names ) {
    my @metas = $swish->meta_list( $index_name );
    my @props = $swish->property_list( $index_name );

    for my $m ( @metas ) {
        my $name = $m->name;
        my $id = $m->id;
        my $type = $m->type;
    }
}
