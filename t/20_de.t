#!perl
# from Data::Encoder's msgpack driver tests
use strict;
use warnings;
use Test::More;
use Data::MessagePack;

my $dm = Data::MessagePack->new(
    utf8           => 1,
    prefer_integer => 1,
    canonical      => 1,
);

my $d = { a => 0.11, b => "\x{3042}" };

is_deeply $dm->decode( $dm->encode($d) ), $d;

is $dm->decode( $dm->encode(0.1) ), 0.1;
is $dm->decode( $dm->encode(0.11) ), 0.11;
is $dm->decode( $dm->encode(0.111) ), 0.111;

done_testing;

