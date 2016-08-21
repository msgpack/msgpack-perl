#!perl -w
# Testing standard dataset in msgpack/test/*.{json,mpac}.
# Don't edit msgpack/perl/t/std/*, which are just copies.
use strict;
use Test::More;
use t::Util;

use Data::MessagePack;

sub slurp {
    open my $fh, '<:raw', $_[0] or die "failed to open '$_[0]': $!";
    local $/;
    return scalar <$fh>;
}

my $mpac  = slurp("t/std/cases.mpac");
my $mpac_compat  = slurp("t/std/cases_compact.mpac");

my $mps = Data::MessagePack::Unpacker->new();
my $mps_compat = Data::MessagePack::Unpacker->new();;

my $offset = 0;
my $offset_compat = 0;
my $t = 1;
while ($offset < length($mpac)) {
    note "mpac", $t++;

    $offset = $mps->execute($mpac, $offset);
    $offset_compat = $mps_compat->execute($mpac_compat, $offset_compat);
    ok $mps->is_finished;
    is_deeply $mps->data, $mps_compat->data;
    $mps->reset;
    $mps_compat->reset;
}

done_testing;
