use Test::More;

use strict;
use warnings;

BEGIN { $ENV{PERL_ONLY} = 1 }

use Data::MessagePack;

if ( eval { require Types::Serialiser } ) {
    plan tests => 1;

    my $mp = Data::MessagePack->new();

    $mp->prefer_types_serialiser(1);

    my $src = [ Types::Serialiser::false(), Types::Serialiser::true() ];

    my $enc = $mp->pack($src);
    my $dec = $mp->unpack($enc);

    is_deeply( $dec, $src, 'round-trip' ) or diag explain $dec;
}
else {
    plan skip_all => $@;
};
