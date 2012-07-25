use Test::More tests => 6;
use Data::MessagePack;

{
  my %hash = ("test" => 0,
	      "test2" => "2");

  my $mp = Data::MessagePack->new();
  my $packed = $mp->pack( \%hash );
  my $len = length($packed);
  ok($len, "len>5");

  my $crc = $mp->add_crc( $packed );
  is(unpack("C", substr($packed,0,1)), 0x82, "packed a FixMap with 2 elems");
  ok(length($crc) > $len, "add_crc len");
  $packed = substr($packed, 0, 15); # create a copy. add_crc() modifies the argument
  is(substr($crc, 0, 15), $packed, "crc really at the end");

  my $unpacked = $mp->unpack( $crc );
  is_deeply( \%hash, $unpacked, "round trip crc hash" );

  # corrupt the data
  substr($crc, 2, 2, "no");
  $unpacked = eval { $mp->unpack( $crc ) };
  ok $@, "caught crc corruption";
}
