use strict;
use warnings;
use Data::MessagePack;
use Test::More;
use t::Util;

my @data = (
    ["\xdd\xff\x00\x00\x00", "large array"],
    ["\xdf\xff\x00\x00\x00", "large map"],
);

foreach my $d (@data) {
    eval { Data::MessagePack->unpack(@{$d}[0]); };
    like $@, qr/insufficient bytes/i, @{$d}[1];
}

done_testing;
