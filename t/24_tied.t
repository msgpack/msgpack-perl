use t::Util;
use Test::More tests => 8;
use Data::MessagePack;

require Tie::Hash;
require Tie::Array;

my (%hash, @array);
tie( %hash, 'Tie::StdHash' );
%hash = (
	 'module'     => 'DiskUsage',
	 'func'       => 'fetchdiskusagewithextras',
	 'apiversion' => '2',
	);

{
    my $mp = Data::MessagePack->new();
    my $packed = eval { $mp->pack( \%hash ); };
    ok(unpack("C", substr($packed,0,1)) == 0x83, "pack a tied FixMap with 3 elems");
    #diag unpack("CC", substr($packed,0,2)),$packed;
    my $unpacked = eval { $mp->unpack( $packed ); };
    if ($@) {
      ok( 0, "unpack tied hash" );
    } else {
      is_deeply( \%hash, $unpacked, "round trip tied hash" );
    }
}

{
    local $ENV{PERL_DATA_MESSAGEPACK} = 'pp';
    my $mp = Data::MessagePack->new();
    my $packed = eval { $mp->pack( \%hash ); };
    ok(unpack("C", substr($packed,0,1)) == 0x83, "PP pack a tied FixMap with 3 elems");
    #diag unpack("CC", substr($packed,0,2)),$packed;
    my $unpacked = eval { $mp->unpack( $packed ); };
    if ($@) {
      ok( 0, "PP unpack tied hash" );
    } else {
      is_deeply( \%hash, $unpacked, "PP round trip tied hash" );
    }
}

tie( @array, 'Tie::StdArray' );
@array = (0..9);
{
    my $mp = Data::MessagePack->new();
    my $packed = eval { $mp->pack( \@array ); };
    ok(unpack("C", substr($packed,0,1)) == 0x9a, "pack a tied FixArray with 10 elems");
    #diag unpack("C", substr($packed,0,2)),$packed;
    my $unpacked = eval { $mp->unpack( $packed ); };
    if ($@) {
      ok( 0, "unpack tied array" );
    } else {
      is_deeply( \@array, $unpacked, "round trip tied array" );
    }
}

{
    local $ENV{PERL_DATA_MESSAGEPACK} = 'pp';
    my $mp = Data::MessagePack->new();
    my $packed = eval { $mp->pack( \@array ); };
    ok(unpack("C", substr($packed,0,1)) == 0x9a, "PP pack a tied FixArray with 10 elems");
    #diag unpack("C", substr($packed,0,2)),$packed;
    my $unpacked = eval { $mp->unpack( $packed ); };
    if ($@) {
      ok( 0, "PP unpack tied array" );
    } else {
      is_deeply( \@array, $unpacked, "PP round trip tied array" );
    }
}
