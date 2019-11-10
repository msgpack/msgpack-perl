package Data::MessagePack::PP;
use 5.008001;
use strict;
use warnings;
no warnings 'recursion';
use Data::MessagePack::Ext;

use Carp ();
use B ();
use Config;

# See also
# http://redmine.msgpack.org/projects/msgpack/wiki/FormatSpec
# http://cpansearch.perl.org/src/YAPPO/Data-Model-0.00006/lib/Data/Model/Driver/Memcached.pm
# http://frox25.no-ip.org/~mtve/wiki/MessagePack.html : reference to using CORE::pack, CORE::unpack

BEGIN {
    my $unpack_int64_slow;
    my $unpack_uint64_slow;

    if(!eval { pack 'Q', 1 }) { # don't have quad types
        # emulates quad types with Math::BigInt.
        # very slow but works well.
        $unpack_int64_slow = sub {
            require Math::BigInt;
            my $high = unpack_uint32( $_[0], $_[1] );
            my $low  = unpack_uint32( $_[0], $_[1] + 4);

            if($high < 0xF0000000) { # positive
                $high = Math::BigInt->new( $high );
                $low  = Math::BigInt->new( $low  );
                return +($high << 32 | $low)->bstr;
            }
            else { # negative
                $high = Math::BigInt->new( ~$high );
                $low  = Math::BigInt->new( ~$low  );
                return +( -($high << 32 | $low + 1) )->bstr;
            }
        };
        $unpack_uint64_slow = sub {
            require Math::BigInt;
            my $high = Math::BigInt->new( unpack_uint32( $_[0], $_[1]) );
            my $low  = Math::BigInt->new( unpack_uint32( $_[0], $_[1] + 4) );
            return +($high << 32 | $low)->bstr;
        };
    }

    *unpack_uint16 = sub { return unpack 'n', substr( $_[0], $_[1], 2 ) };
    *unpack_uint32 = sub { return unpack 'N', substr( $_[0], $_[1], 4 ) };

    # For ARM OABI
    my $bo_is_me = unpack ( 'd', "\x00\x00\xf0\x3f\x00\x00\x00\x00") == 1;
    my $pack_double_oabi;
    my $unpack_double_oabi;

    # for pack and unpack compatibility
    if ( $] < 5.010 ) {
        my $bo_is_le = ( $Config{byteorder} =~ /^1234/ );

        if ($bo_is_me) {
            $pack_double_oabi = sub {
                my @v = unpack( 'V2', pack( 'd', $_[0] ) );
                return pack 'CN2', 0xcb, @v[0,1];
            };
            $unpack_double_oabi = sub {
                my @v = unpack( 'V2', substr( $_[0], $_[1], 8 ) );
                return unpack( 'd', pack( 'N2', @v[0,1] ) );
            };
        }

        *unpack_int16  = sub {
            my $v = unpack 'n', substr( $_[0], $_[1], 2 );
            return $v ? $v - 0x10000 : 0;
        };
        *unpack_int32  = sub {
            no warnings; # avoid for warning about Hexadecimal number
            my $v = unpack 'N', substr( $_[0], $_[1], 4 );
            return $v ? $v - 0x100000000 : 0;
        };

        # In reality, since 5.9.2 '>' is introduced. but 'n!' and 'N!'?
        if($bo_is_le) {
            *pack_uint64 = sub {
                my @v = unpack( 'V2', pack( 'Q', $_[0] ) );
                return pack 'CN2', 0xcf, @v[1,0];
            };
            *pack_int64 = sub {
                my @v = unpack( 'V2', pack( 'q', $_[0] ) );
                return pack 'CN2', 0xd3, @v[1,0];
            };
            *pack_double = $pack_double_oabi || sub {
                my @v = unpack( 'V2', pack( 'd', $_[0] ) );
                return pack 'CN2', 0xcb, @v[1,0];
            };

            *unpack_float = sub {
                my @v = unpack( 'v2', substr( $_[0], $_[1], 4 ) );
                return unpack( 'f', pack( 'n2', @v[1,0] ) );
            };
            *unpack_double = $unpack_double_oabi || sub {
                my @v = unpack( 'V2', substr( $_[0], $_[1], 8 ) );
                return unpack( 'd', pack( 'N2', @v[1,0] ) );
            };

            *unpack_int64 = $unpack_int64_slow || sub {
                my @v = unpack( 'V*', substr( $_[0], $_[1], 8 ) );
                return unpack( 'q', pack( 'N2', @v[1,0] ) );
            };
            *unpack_uint64 = $unpack_uint64_slow || sub {
                my @v = unpack( 'V*', substr( $_[0], $_[1], 8 ) );
                return unpack( 'Q', pack( 'N2', @v[1,0] ) );
            };
        }
        else { # big endian
            *pack_uint64   = sub { return pack 'CQ', 0xcf, $_[0]; };
            *pack_int64    = sub { return pack 'Cq', 0xd3, $_[0]; };
            *pack_double   = $pack_double_oabi || sub { return pack 'Cd', 0xcb, $_[0]; };

            *unpack_float  = sub { return unpack( 'f', substr( $_[0], $_[1], 4 ) ); };
            *unpack_double = $unpack_double_oabi || sub { return unpack( 'd', substr( $_[0], $_[1], 8 ) ); };
            *unpack_int64  = $unpack_int64_slow  || sub { unpack 'q', substr( $_[0], $_[1], 8 ); };
            *unpack_uint64 = $unpack_uint64_slow || sub { unpack 'Q', substr( $_[0], $_[1], 8 ); };
        }
    }
    else { # 5.10.0 or later
        if ($bo_is_me) {
            $pack_double_oabi = sub {
                my @v = unpack('V2' , pack('d', $_[0]));
                my $d = unpack('d', pack('V2', @v[1,0]));
                return pack 'Cd>', 0xcb, $d;
            };
            $unpack_double_oabi = sub {
                my $first_word  = substr($_[0], $_[1], 4);
                my $second_word = substr($_[0], $_[1] + 4, 4);
                my $d_bin = $second_word . $first_word;
                return unpack( 'd>', $d_bin );
            };
        }

        # pack_int64/uint64 are used only when the perl support quad types
        *pack_uint64   = sub { return pack 'CQ>', 0xcf, $_[0]; };
        *pack_int64    = sub { return pack 'Cq>', 0xd3, $_[0]; };
        *pack_double   = $pack_double_oabi || sub { return pack 'Cd>', 0xcb, $_[0]; };

        *unpack_float  = sub { return unpack( 'f>', substr( $_[0], $_[1], 4 ) ); };
        *unpack_double = $unpack_double_oabi || sub { return unpack( 'd>', substr( $_[0], $_[1], 8 ) ); };
        *unpack_int16  = sub { return unpack( 'n!', substr( $_[0], $_[1], 2 ) ); };
        *unpack_int32  = sub { return unpack( 'N!', substr( $_[0], $_[1], 4 ) ); };

        *unpack_int64  = $unpack_int64_slow  || sub { return unpack( 'q>', substr( $_[0], $_[1], 8 ) ); };
        *unpack_uint64 = $unpack_uint64_slow || sub { return unpack( 'Q>', substr( $_[0], $_[1], 8 ) ); };
    }

    # fixin package symbols
    no warnings 'once';
    @Data::MessagePack::ISA           = qw(Data::MessagePack::PP);
    @Data::MessagePack::Unpacker::ISA = qw(Data::MessagePack::PP::Unpacker);

    *true  = \&Data::MessagePack::true;
    *false = \&Data::MessagePack::false;
}

sub _unexpected {
    Carp::confess("Unexpected " . sprintf(shift, @_) . " found");
}


#
# PACK
#

our $_max_depth;

sub pack :method {
    my($self, $data, $max_depth) = @_;
    Carp::croak('Usage: Data::MessagePack->pack($dat [,$max_depth])') if @_ < 2;
    $_max_depth = defined $max_depth ? $max_depth : 512; # init

    if(not ref $self) {
        $self = $self->new(
            prefer_integer => $Data::MessagePack::PreferInteger || 0,
            canonical      => $Data::MessagePack::Canonical     || 0,
        );
    }
    return $self->_pack( $data );
}


sub _pack {
    my ( $self, $value ) = @_;

    local $_max_depth = $_max_depth - 1;

    if ( $_max_depth < 0 ) {
        Carp::croak("perl structure exceeds maximum nesting level (max_depth set too low?)");
    }

    return CORE::pack( 'C', 0xc0 ) if ( not defined $value );

    if ( ref($value) eq 'ARRAY' ) {
        my $num = @$value;
        my $header =
              $num < 16          ? CORE::pack( 'C',  0x90 + $num )
            : $num < 2 ** 16 - 1 ? CORE::pack( 'Cn', 0xdc,  $num )
            : $num < 2 ** 32 - 1 ? CORE::pack( 'CN', 0xdd,  $num )
            : _unexpected("number %d", $num)
        ;
        return join( '', $header, map { $self->_pack( $_ ) } @$value );
    }

    elsif ( ref($value) eq 'HASH' ) {
        my $num = keys %$value;
        my $header =
              $num < 16          ? CORE::pack( 'C',  0x80 + $num )
            : $num < 2 ** 16 - 1 ? CORE::pack( 'Cn', 0xde,  $num )
            : $num < 2 ** 32 - 1 ? CORE::pack( 'CN', 0xdf,  $num )
            : _unexpected("number %d", $num)
        ;

        if ($self->{canonical}) {
            return join( '', $header, map { $self->_pack( $_ ), $self->_pack($value->{$_}) } sort { $a cmp $b } keys %$value );
        } else {
            return join( '', $header, map { $self->_pack( $_ ) } %$value );
        }
    }

    elsif ( ref( $value ) eq 'Data::MessagePack::Boolean' ) {
        return  CORE::pack( 'C', ${$value} ? 0xc3 : 0xc2 );
    }

    elsif ( ref( $value ) eq 'Data::MessagePack::Ext' ) {
        my $num = length $value->{data};
        my $header =
              $num == 1 ? CORE::pack( 'C',  0xd4)
              : $num == 2 ? CORE::pack( 'C',  0xd5)
              : $num == 4 ? CORE::pack( 'C',  0xd6)
              : $num == 8 ? CORE::pack( 'C',  0xd7)
              : $num == 16 ? CORE::pack( 'C',  0xd8)
              : $num <= 2 ** 8 - 1 ? CORE::pack( 'CC',  0xc7, $num )
              : $num <= 2 ** 16 - 1 ? CORE::pack( 'Cn', 0xc8, $num )
              : $num <= 2 ** 32 - 1 ? CORE::pack( 'CN', 0xc9, $num )
              : _unexpected('number %d', $num);
        _unexpected('no type') if (!exists ($value->{type}));
        _unexpected('no data') if (!exists ($value->{data}));
        _unexpected('type %d', $value->{type}) if ($value->{type} < 0 || $value->{type} > 127);
        return  join ('', $header, CORE::pack( 'c', $value->{type}), $value->{data});
    }

    my $b_obj = B::svref_2object( \$value );
    my $flags = $b_obj->FLAGS;

    if ( $flags & B::SVp_POK ) { # raw / check needs before double

        if ( $self->{prefer_integer} ) {
            if ( $value =~ /^-?[0-9]+$/ ) { # ok?
                # checks whether $value is in (u)int32
                my $ivalue = 0 + $value;
                if (!(
                       $ivalue > 0xFFFFFFFF
                    or $ivalue < ('-' . 0x80000000) # for XS compat
                    or $ivalue != B::svref_2object(\$ivalue)->int_value
                )) {
                    return $self->_pack( $ivalue );
                }
                # fallthrough
            }
            # fallthrough
        }

        utf8::encode( $value ) if utf8::is_utf8( $value );

        my $num = length $value;
        my $header;
        if ($self->{utf8}) { # Str
            $header =
                $num < 32          ? CORE::pack( 'C',  0xa0 + $num )
                : $num < 2 ** 8  - 1 ? CORE::pack( 'CC', 0xd9, $num)
                : $num < 2 ** 16 - 1 ? CORE::pack( 'Cn', 0xda, $num )
                : $num < 2 ** 32 - 1 ? CORE::pack( 'CN', 0xdb, $num )
                : _unexpected('number %d', $num);
        } else { # Bin
            $header =
                $num < 2 ** 8 - 1 ? CORE::pack( 'CC',  0xc4, $num)
                : $num < 2 ** 16 - 1 ? CORE::pack( 'Cn', 0xc5, $num )
                : $num < 2 ** 32 - 1 ? CORE::pack( 'CN', 0xc6, $num )
                : _unexpected('number %d', $num);
        }

        return $header . $value;

    }
    elsif( $flags & B::SVp_NOK ) { # double only
        return pack_double( $value );
    }
    elsif ( $flags & B::SVp_IOK ) {
        if ($value >= 0) { # UV
            return    $value <= 127 ?    CORE::pack 'C',        $value
                    : $value < 2 **  8 ? CORE::pack 'CC', 0xcc, $value
                    : $value < 2 ** 16 ? CORE::pack 'Cn', 0xcd, $value
                    : $value < 2 ** 32 ? CORE::pack 'CN', 0xce, $value
                    : pack_uint64( $value );
        }
        else { # IV
            return    -$value <= 32 ?      CORE::pack 'C', ($value & 255)
                    : -$value <= 2 **  7 ? CORE::pack 'Cc', 0xd0, $value
                    : -$value <= 2 ** 15 ? CORE::pack 'Cn', 0xd1, $value
                    : -$value <= 2 ** 31 ? CORE::pack 'CN', 0xd2, $value
                    : pack_int64( $value );
        }
    }
    else {
        _unexpected("data type %s", $b_obj);
    }

}

#
# UNPACK
#

our $_utf8 = 0;
my $p; # position variables for speed.

sub _insufficient {
    Carp::confess("Insufficient bytes (pos=$p, type=@_)");
}

sub unpack :method {
    $p = 0; # init
    $_utf8 = (ref($_[0]) && $_[0]->{utf8}) || $_utf8;
    my $data = _unpack( $_[1] );
    if($p < length($_[1])) {
        Carp::croak("Data::MessagePack->unpack: extra bytes");
    }
    return $data;
}

my $T_STR             = 0x01;
my $T_ARRAY           = 0x02;
my $T_MAP             = 0x04;
my $T_BIN             = 0x08;
my $T_EXT             = 0x09;
my $T_DIRECT          = 0x10; # direct mapping (e.g. 0xc0 <-> nil)

my @typemap = ( (0x00) x 256 );

$typemap[$_] |= $T_ARRAY for
    0x90 .. 0x9f, # fix array
    0xdc,         # array16
    0xdd,         # array32
;
$typemap[$_] |= $T_MAP for
    0x80 .. 0x8f, # fix map
    0xde,         # map16
    0xdf,         # map32
;
$typemap[$_] |= $T_STR for
    0xa0 .. 0xbf, # fix str
    0xd9,         # str8
    0xda,         # str16
    0xdb,         # str32
;
$typemap[$_] |= $T_BIN for
    0xc4,         # bin 8
    0xc5,         # bin 16
    0xc6,         # bin 32
;

$typemap[$_] |= $T_EXT for
    0xd4 .. 0xd8, # fix ext
    0xc7,         # ext 8
    0xc8,         # ext 16
    0xc9,         # ext 32
;

my @byte2value;
foreach my $pair(
    [0xc3, true],
    [0xc2, false],
    [0xc0, undef],

    (map { [ $_, $_ ] }         0x00 .. 0x7f), # positive fixnum
    (map { [ $_, $_ - 0x100 ] } 0xe0 .. 0xff), # negative fixnum
) {
    $typemap[    $pair->[0] ] |= $T_DIRECT;
    $byte2value[ $pair->[0] ]  = $pair->[1];
}

sub _fetch_size {
    my($value_ref, $byte, $x8, $x16, $x32, $x_fixbits) = @_;
    if ( defined($x8) && $byte == $x8 ) {
        $p += 1;
        $p <= length(${$value_ref}) or _insufficient('x/8');
        return unpack 'C', substr( ${$value_ref}, $p - 1, 1);
    }
    elsif ( $byte == $x16 ) {
        $p += 2;
        $p <= length(${$value_ref}) or _insufficient('x/16');
        return unpack 'n', substr( ${$value_ref}, $p - 2, 2 );
    }
    elsif ( $byte == $x32 ) {
        $p += 4;
        $p <= length(${$value_ref}) or _insufficient('x/32');
        return unpack 'N', substr( ${$value_ref}, $p - 4, 4 );
    }
    else { # fix raw
        return $byte & ~$x_fixbits;
    }
}

sub _unpack {
    my ( $value ) = @_;
    $p < length($value) or _insufficient('header byte');
    # get a header byte
    my $byte = ord( substr $value, $p, 1 );
    $p++;

    # +/- fixnum, nil, true, false
    return $byte2value[$byte] if $typemap[$byte] & $T_DIRECT;

    if ( $typemap[$byte] == $T_STR ) {
        my $size = _fetch_size(\$value, $byte, 0xd9, 0xda, 0xdb, 0xa0);
        my $s    = substr( $value, $p, $size );
        length($s) == $size or _insufficient('raw');
        $p      += $size;
        utf8::decode($s);
        return $s;
    }
    elsif ( $typemap[$byte] == $T_ARRAY ) {
        my $size = _fetch_size(\$value, $byte, undef, 0xdc, 0xdd, 0x90);
        my @array;
        push @array, _unpack( $value ) while --$size >= 0;
        return \@array;
    }
    elsif ( $typemap[$byte] == $T_MAP ) {
        my $size = _fetch_size(\$value, $byte, undef, 0xde, 0xdf, 0x80);
        my %map;
        while(--$size >= 0) {
            no warnings; # for undef key case
            my $key = _unpack( $value );
            my $val = _unpack( $value );
            $map{ $key } = $val;
        }
        return \%map;
    }
    elsif ($typemap[$byte] == $T_BIN) {
        my $size = _fetch_size(\$value, $byte, 0xc4, 0xc5, 0xc6, 0x80);
        my $s    = substr( $value, $p, $size );
        length($s) == $size or _insufficient('bin');
        $p      += $size;
        utf8::decode($s) if $_utf8;
        return $s;
    }
    elsif ($typemap[$byte] == $T_EXT) {
        my $size = _fetch_size(\$value, $byte, 0xc7, 0xc8, 0xc9, 0xd4);
        my $type = substr( $value, $p, 1 );
        length($type) == 1 or _insufficient('ext');
        $p      += 1;
        if ($byte >= 0xd4) {
            $size = 2 ** ($byte-0xd4);
        }

        my $data = substr( $value, $p, $size );
        $p      += $size;
        length($data) == $size or _insufficient('ext');
        return Data::MessagePack::Ext->new(ord($type), $data);
    }
    elsif ( $byte == 0xcc ) { # uint8
        $p++;
        $p <= length($value) or _insufficient('uint8');
        return CORE::unpack( 'C', substr( $value, $p - 1, 1 ) );
    }
    elsif ( $byte == 0xcd ) { # uint16
        $p += 2;
        $p <= length($value) or _insufficient('uint16');
        return unpack_uint16( $value, $p - 2 );
    }
    elsif ( $byte == 0xce ) { # unit32
        $p += 4;
        $p <= length($value) or _insufficient('uint32');
        return unpack_uint32( $value, $p - 4 );
    }
    elsif ( $byte == 0xcf ) { # unit64
        $p += 8;
        $p <= length($value) or _insufficient('uint64');
        return unpack_uint64( $value, $p - 8 );
    }
    elsif ( $byte == 0xd3 ) { # int64
        $p += 8;
        $p <= length($value) or _insufficient('int64');
        return unpack_int64( $value, $p - 8 );
    }
    elsif ( $byte == 0xd2 ) { # int32
        $p += 4;
        $p <= length($value) or _insufficient('int32');
        return unpack_int32( $value, $p - 4 );
    }
    elsif ( $byte == 0xd1 ) { # int16
        $p += 2;
        $p <= length($value) or _insufficient('int16');
        return unpack_int16( $value, $p - 2 );
    }
    elsif ( $byte == 0xd0 ) { # int8
        $p++;
        $p <= length($value) or _insufficient('int8');
        return CORE::unpack 'c',  substr( $value, $p - 1, 1 );
    }
    elsif ( $byte == 0xcb ) { # double
        $p += 8;
        $p <= length($value) or _insufficient('double');
        return unpack_double( $value, $p - 8 );
    }
    elsif ( $byte == 0xca ) { # float
        $p += 4;
        $p <= length($value) or _insufficient('float');
        return unpack_float( $value, $p - 4 );
    }
    else {
        _unexpected("byte 0x%02x", $byte);
    }
}


#
# Data::MessagePack::Unpacker
#

package
    Data::MessagePack::PP::Unpacker;

sub new {
    bless {
        pos  => 0,
        utf8 => 0,
        buff => '',
    }, shift;
}

sub utf8 {
    my $self = shift;
    $self->{utf8} = (@_ ? shift : 1);
    return $self;
}

sub get_utf8 {
    my($self) = @_;
    return $self->{utf8};
}

sub execute_limit {
    execute( @_ );
}

sub execute {
    my ( $self, $data, $offset, $limit ) = @_;
    $offset ||= 0;
    my $value = substr( $data, $offset, $limit ? $limit : length $data );
    my $len   = length $value;

    $self->{buff} .= $value;
    local $self->{stack} = [];

    #$p = 0;
    #eval { Data::MessagePack::PP::_unpack($self->{buff}) };
    #warn "[$p][$@]";
    $p = 0;

    while ( length($self->{buff}) > $p ) {
        _count( $self, $self->{buff} ) or last;

        while ( @{ $self->{stack} } > 0 && --$self->{stack}->[-1] == 0) {
            pop @{ $self->{stack} };
        }

        if (@{$self->{stack}} == 0) {
            $self->{is_finished}++;
            last;
        }
    }
    $self->{pos} = $p;

    return $p + $offset;
}


sub _count {
    my ( $self, $value ) = @_;
    no warnings; # FIXME
    my $byte = unpack( 'C', substr( $value, $p++, 1 ) ); # get header

    Carp::croak('invalid data') unless defined $byte;

    # +/- fixnum, nil, true, false
    return 1 if $typemap[$byte] & $T_DIRECT;

    if ( $typemap[$byte] == $T_STR ) {
        my $num;
        if ( $byte == 0xd9 ) {
            $num = unpack 'C', substr( $value, $p, 1 );
            $p += 1;
        }
        elsif ( $byte == 0xda ) {
            $num = unpack 'n', substr( $value, $p, 2 );
            $p += 2;
        }
        elsif ( $byte == 0xdb ) {
            $num = unpack 'N', substr( $value, $p, 4 );
            $p += 4;
        }
        else { # fix raw
            $num = $byte & ~0xa0;
        }
        $p += $num;
        return 1;
    }
    elsif ( $typemap[$byte] == $T_ARRAY ) {
        my $num;
        if ( $byte == 0xdc ) { # array 16
            $num = unpack 'n', substr( $value, $p, 2 );
            $p += 2;
        }
        elsif ( $byte == 0xdd ) { # array 32
            $num = unpack 'N', substr( $value, $p, 4 );
            $p += 4;
        }
        else { # fix array
            $num = $byte & ~0x90;
        }

        if ( $num ) {
            push @{ $self->{stack} }, $num + 1;
        }

        return 1;
    }
    elsif ( $typemap[$byte] == $T_MAP ) {
        my $num;
        if ( $byte == 0xde ) { # map 16
            $num = unpack 'n', substr( $value, $p, 2 );
            $p += 2;
        }
        elsif ( $byte == 0xdf ) { # map 32
            $num = unpack 'N', substr( $value, $p, 4 );
            $p += 4;
        }
        else { # fix map
            $num = $byte & ~0x80;
        }

        if ( $num ) {
            push @{ $self->{stack} }, $num * 2 + 1; # a pair
        }

        return 1;
    }
    elsif ( $typemap[$byte] == $T_BIN ) {
        my $num;
        if ( $byte == 0xc4 ) { # bin 8
            $num = unpack 'C', substr( $value, $p, 1 );
            $p += 1;
        }
        elsif ( $byte == 0xc5 ) { # bin 16
            $num = unpack 'n', substr( $value, $p, 2 );
            $p += 2;
        }
        elsif ( $byte == 0xc6 ) { # bin 32
            $num = unpack 'N', substr( $value, $p, 4 );
            $p += 4;
        }

        $p += $num;
        return 1;
    }
    elsif ( $typemap[$byte] == $T_EXT ) {
        my $num = 0;
        if ( $byte == 0xc7 ) { # ext 8
            $num = unpack 'C', substr( $value, $p, 1 );
            $p += 1;
        }
        elsif ( $byte == 0xc8 ) { # ext 16
            $num = unpack 'n', substr( $value, $p, 2 );
            $p += 2;
        }
        elsif ( $byte == 0xc9 ) { # ext 32
            $num = unpack 'N', substr( $value, $p, 4 );
            $p += 4;
        }
        elsif ( $byte >= 0xd4 ) { # fixext
            $num = 2 ** ($byte-0xd4);
        }

        $p += $num+1;
        return 1;
    }
    elsif ( $byte >= 0xcc and $byte <= 0xcf ) { # uint
        $p += $byte == 0xcc ? 1
            : $byte == 0xcd ? 2
            : $byte == 0xce ? 4
            : $byte == 0xcf ? 8
            : Data::MessagePack::PP::_unexpected("byte 0x%02x", $byte);
        return 1;
    }

    elsif ( $byte >= 0xd0 and $byte <= 0xd3 ) { # int
        $p += $byte == 0xd0 ? 1
            : $byte == 0xd1 ? 2
            : $byte == 0xd2 ? 4
            : $byte == 0xd3 ? 8
            : Data::MessagePack::PP::_unexpected("byte 0x%02x", $byte);
        return 1;
    }
    elsif ( $byte == 0xca or $byte == 0xcb ) { # float, double
        $p += $byte == 0xca ? 4 : 8;
        return 1;
    }
    else {
        Data::MessagePack::PP::_unexpected("byte 0x%02x", $byte);
    }

    return 0;
}


sub data {
    my($self) = @_;
    local $Data::MessagePack::PP::_utf8 = $self->{utf8};
    return Data::MessagePack->unpack( substr($self->{buff}, 0, $self->{pos}) );
}


sub is_finished {
    my ( $self ) = @_;
    return $self->{is_finished};
}

sub reset :method {
    $_[0]->{buff}        = '';
    $_[0]->{pos}         = 0;
    $_[0]->{is_finished} = 0;
}

1;
__END__

=pod

=head1 NAME

Data::MessagePack::PP - Pure Perl implementation of Data::MessagePack

=head1 DESCRIPTION

This module is used by L<Data::MessagePack> internally.

=head1 SEE ALSO

L<http://msgpack.sourceforge.jp/>,
L<Data::MessagePack>,
L<http://frox25.no-ip.org/~mtve/wiki/MessagePack.html>,

=head1 AUTHOR

makamaka

=head1 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
