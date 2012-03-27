#!perl
# from Data::Encoder's msgpack driver tests
use strict;
use warnings;
use Config;
use if $Config{nvsize} > 8,
    'Test::More', skip_all => 'long double is not supported';
use Test::More;
use Data::MessagePack;

sub d {
    my($dm, $value) = @_;
    my $binary = $dm->encode($value);
    diag('binary: ', join ' ',
        map { sprintf '%02X', ord $_ } split //, $binary);
}

my $dm = Data::MessagePack->new(
    utf8           => 1,
    prefer_integer => 1,
    canonical      => 1,
);

my $d = { a => 0.11, b => "\x{3042}" };

is_deeply $dm->decode( $dm->encode($d) ), $d;

is $dm->decode( $dm->encode(0.1) ),   0.1   or d($dm, 0.1);
is $dm->decode( $dm->encode(0.11) ),  0.11  or d($dm, 0.11);
is $dm->decode( $dm->encode(0.111) ), 0.111 or d($dm, 0.111);

done_testing;

