#!perl
use Test::More;
use Data::MessagePack::Ext;

ok (Data::MessagePack::Ext->new(1, 'data') ==
	Data::MessagePack::Ext->new(1, 'data'));
ok (Data::MessagePack::Ext->new(2, 'data') !=
	Data::MessagePack::Ext->new(1, 'data'));
ok (Data::MessagePack::Ext->new(1, 'data1') !=
	Data::MessagePack::Ext->new(1, 'data2'));

done_testing;
