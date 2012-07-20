use strict;
use warnings;
use Data::MessagePack;
use JSON;
use Storable;
use Benchmark ':all';

#$Data::MessagePack::PreferInteger = 1;

my $a = do 'benchmark/data.pl';

my $j = JSON::encode_json($a);
my $m = Data::MessagePack->pack($a);
my $m_crc = Data::MessagePack->pack($a); Data::MessagePack->add_crc($m_crc);
my $s = Storable::freeze($a);

print "-- deserialize\n";
print "$JSON::Backend: ", $JSON::Backend->VERSION, "\n";
print "Data::MessagePack: $Data::MessagePack::VERSION\n";
print "Storable: $Storable::VERSION\n";
cmpthese timethese(
    -1 => {
        json     => sub { JSON::decode_json($j)     },
        mp       => sub { Data::MessagePack->unpack($m) },
        mp_crc   => sub { Data::MessagePack->unpack($m_crc) },
        storable => sub { Storable::thaw($s) },
    }
);

