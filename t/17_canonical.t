
use strict;
use warnings;
use Test::More;
use Data::MessagePack;

my $mp = Data::MessagePack->new(canonical => 1);

my $data = {
	'foo' => {
		'a' => '',
		'b' => '',
		'c' => '',
		'd' => '',
		'e' => '',
		'f' => '',
		'g' => '',
	}
};

my $packed1 = $mp->pack($data);
my $packed2 = $mp->pack($mp->unpack($packed1));
my $packed3 = $mp->pack($mp->unpack($packed2));
my $packed4 = $mp->pack($mp->unpack($packed3));
my $packed5 = $mp->pack($mp->unpack($packed4));

is $packed1, $packed2;
is $packed1, $packed3;
is $packed1, $packed4;
is $packed1, $packed5;

done_testing;
