#!perl
use strict;
use Test::More;
use Data::MessagePack;

my $mp = Data::MessagePack->new();

foreach my $float(0.123, 3.14) {
    is $mp->unpack($mp->pack($float)), $float;

    scalar( $float > 0 );
    is $mp->unpack($mp->pack($float)), $float;
}
done_testing;

