#!perl
# -*- perl -*-

use strict;
use warnings;

use Test::More tests => 3;

local $TODO = "not yet";

my @orig = (
    ["ZZZ",{"10000050C2400102" => {"1332129147" => ["\x01\x07\x07 \xf7","2.48292"]}}],
    ["ZZZ",{"" => {}}],
    );

use Data::MessagePack;

my $mp = Data::MessagePack->new();

# Just to be sure Data::MessagePack is OK
for (@orig)
{
    is_deeply(Data::MessagePack->unpack(Data::MessagePack->pack($_)), $_);
}

# Now test the stream...
my $buf;
for (@orig)
{
    $buf .= Data::MessagePack->pack($_);
}

my $up = Data::MessagePack::Unpacker->new;

my @res;

my $offset = $up->execute($buf, 0);
if ($up->is_finished)
{
    push(@res, $up->data);

    $up->execute($buf, $offset);
    if ($up->is_finished)
    {
        push(@res, $up->data);

        is_deeply(\@res, \@orig) or diag(explain([\@res, \@orig]));
    }
    else
    {
        fail('Unpack second item');
    }
}
else
{
    fail('Unpack first item');
}
