use t::Util;
use Test::More tests => 4;
use Data::MessagePack;

package MyTieHash;
use Tie::Hash;
our @ISA = ('Tie::StdHash');

package main;

my %data;
tie( %data, 'Tie::StdHash' );
%data = (
	 'module'     => 'DiskUsage',
	 'func'       => 'fetchdiskusagewithextras',
	 'apiversion' => '2',
	);

{
    my $mp = Data::MessagePack->new();
    my $packed = eval { $mp->pack( \%data ); };
    ok(unpack("C", substr($packed,0,1)) == 131, "pack did a map with 3 elems");
    #diag unpack("CC", substr($packed,0,2)),$packed;
    my $unpacked = eval { $mp->unpack( $packed ); };
    if ($@) {
      ok( 0, "unpack tied" );
    } else {
      ok( $unpacked, "round trip tied" );
    }
}

{
    local $ENV{PERL_DATA_MESSAGEPACK} = 'pp';
    my $mp = Data::MessagePack->new();
    my $packed = eval { $mp->pack( \%data ); };
    ok(unpack("C", substr($packed,0,1)) == 131, "PP pack did a map with 3 elems");
    #diag unpack("CC", substr($packed,0,2)),$packed;
    my $unpacked = eval { $mp->unpack( $packed ); };
    if ($@) {
      ok( 0, "PP unpack tied" );
    } else {
      ok( $unpacked, "PP round trip tied" );
    }
}
