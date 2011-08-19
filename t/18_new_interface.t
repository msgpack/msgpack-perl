#!perl
use strict;
use warnings;

use Test::More;

use Data::MessagePack;

my $mp = Data::MessagePack->new();

is_deeply $mp->decode( $mp->encode([1, 2, 3]) ), [1, 2, 3];

my $mpc = Data::MessagePack->new->prefer_integer->canonical;

ok !$mp->get_prefer_integer;
ok $mpc->get_prefer_integer;

ok !$mp->get_canonical;
ok $mpc->get_canonical;

isnt $mp->pack("42"), $mp->pack(42);
is $mpc->pack("42"), $mpc->pack(42);

done_testing;

