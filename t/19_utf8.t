#!perl
use strict;
use warnings;
use utf8;

use Test::More;
use Data::MessagePack;

my $mp = Data::MessagePack->new;

isnt $mp->unpack( $mp->pack('はろー！メッセージパック！') ),
   'はろー！メッセージパック！';

$mp->utf8(1);
is $mp->unpack( $mp->pack('はろー！メッセージパック！') ),
   'はろー！メッセージパック！';

done_testing;

