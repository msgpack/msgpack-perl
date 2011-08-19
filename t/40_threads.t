#!perl
use strict;
use warnings;
use constant HAS_THREADS => eval { require threads };
use if !HAS_THREADS, 'Test::More', skip_all => 'no threads';
use Test::More;

use Data::MessagePack;

my $true  = Data::MessagePack->unpack("\xc3");
my $false = Data::MessagePack->unpack("\xc2");

ok $true;
ok !$false;

threads->create(sub {
    my $T = Data::MessagePack->unpack("\xc3");
    my $F = Data::MessagePack->unpack("\xc2");

    ok $T;
    ok !$F;

    is_deeply $T, $true;
    is_deeply $F, $false;

})->join();

$Data::MessagePack::PreferInteger = 0;

threads->create(sub{
    $Data::MessagePack::PreferInteger = 1;
})->join();

is $Data::MessagePack::PreferInteger, 0, '$PreferInteger is a thread-local variable';

done_testing;

