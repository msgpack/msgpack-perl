#!perl -w
use strict;
use Test::Requires { 'JSON::PP' => 0 };
use Test::More;
use Data::MessagePack;

# Test compatibility of JSON and MessagePack booleans

my $JSON = 'JSON::PP';

is( $JSON->true,  Data::MessagePack::true,  'true' );
is( $JSON->false, Data::MessagePack::false, 'false' );

my @TESTS = (
    { json => '[true]' },
    { json => '{"f":false}' },
    { json => '{"x":{"a":null,"b":"xyz"},"y":[]}' },
    { mp   => "\x81\xc4\x01\x32\xc0" },
    { mp   => "\x92\x90\xc0" },
    { mp   => "\x93\xc0\xc2\xc3" },
);

my $mp = Data::MessagePack->new->utf8;
my $j  = $JSON->new->utf8;

for my $t (@TESTS) {
    my ( $fmt, $input ) = each %$t;
    my ( $out1, $out2, $test );
    if ( $fmt eq 'json' ) {
        $out1 = $j->decode($input);
        $out2 = $mp->unpack( $mp->pack($out1) );
        $test = "From JSON through MP: $input";
    }
    elsif ( $fmt eq 'mp' ) {
        $out1 = $mp->unpack($input);
        $out2 = $j->decode( $j->encode($out1) );
        $test = "From MP through JSON: " . $JSON->can('encode_json')->($out1);
    }
    is_deeply( $out1, $out2, $test );
}

done_testing;
