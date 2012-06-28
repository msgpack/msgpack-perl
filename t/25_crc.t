use Test::More tests => 6;
use Data::MessagePack;

{
  my %hash = ("test" => 0,
	      "test2" => "2");

  my $mp = Data::MessagePack->new();
  my $packed = $mp->pack( \%hash );
  is(length $packed, 15, "len 15");

  my $crc = $mp->add_crc( $packed );
  is(unpack("C", substr($packed,0,1)), 0x82, "packed a FixMap with 2 elems");
  is(length $crc, 20, "add_crc len 20");
  $packed = substr($packed, 0, 15); # create a copy. add_crc() modifies the argument
  is(substr($crc, 0, 15), $packed, "crc really at the end");

  my $unpacked = $mp->unpack( $crc );
  is_deeply( \%hash, $unpacked, "round trip crc hash" );

  # corrupt the data
  substr($crc, 2, 2, "no");
  $unpacked = eval { $mp->unpack( $crc ) };
  ok $@, "caught crc corruption";
}
