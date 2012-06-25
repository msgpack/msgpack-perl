#!perl

use strict;
use warnings;

use Test::More tests => 1;
use Data::MessagePack;

my $mp = Data::MessagePack->new();
is( $mp->unpack($mp->pack($$)), $$, 'pack then unpack of $$ returns same number' );

done_testing();
