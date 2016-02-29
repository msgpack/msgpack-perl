use t::Util;
use Test::More;
use Data::MessagePack;
use Data::Dumper;
no warnings; # shut up "Integer overflow in hexadecimal number"

sub packit {
    local $_ = unpack("H*", Data::MessagePack->pack($_[0]));
    s/(..)/$1 /g;
    s/ $//;
    $_;
}

sub packit_utf8 {
    local $_ = unpack("H*", Data::MessagePack->new->utf8->prefer_integer($_[1])->pack($_[0]));
    s/(..)/$1 /g;
    s/ $//;
    $_;
}

sub pis ($$) {
    if (ref $_[1]) {
        like packit($_[0]), $_[1], 'dump ' . $_[1];
    } else {
        is packit($_[0]), $_[1], 'dump ' . $_[1];
    }
    # is(Dumper(Data::MessagePack->unpack(Data::MessagePack->pack($_[0]))), Dumper($_[0]));
}

sub pis_utf8 ($$$) {
    if (ref $_[1]) {
        like packit_utf8($_[0], $_[2]), $_[1], 'dump ' . $_[1];
    } else {
        is packit_utf8($_[0], $_[2]), $_[1], 'dump ' . $_[1];
    }
    # is(Dumper(Data::MessagePack->unpack(Data::MessagePack->pack($_[0]))), Dumper($_[0]));
}

my $is_win = $^O eq 'MSWin32';
my @dat = (
    '',      'c4 00',
    '0',     '00',
    '1',     '01',
    '10',    '0a',
    '-1',    'ff',
    '-10',   'f6',
    '-',     'c4 01 2d',
    ''.0xEFFF => 'cd ef ff',
    ''.0xFFFF => 'cd ff ff',
    ''.0xFFFFFF => 'ce 00 ff ff ff',
    ''.0xFFFFFFFF => 'ce ff ff ff ff',
    ''.0xFFFFFFFFF => 'c4 0b 36 38 37 31 39 34 37 36 37 33 35',
    ''.0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFF => $is_win ?
                                            qr{^(c4 15 38 2e 33 30 37 36 37 34 39 37 33 36 35 35 37 32 65 2b 30 33 34|c4 18 38 2e 33 30 37 36 37 34 39 37 33 36 35 35 37 32 34 32 31 65 2b 30 33 34)$}
                                          : qr{^(c4 14 38 2e 33 30 37 36 37 34 39 37 33 36 35 35 37 32 65 2b 33 34|c4 17 38 2e 33 30 37 36 37 34 39 37 33 36 35 35 37 32 34 32 31 65 2b 33 34)$},
    '-'.0x8000000 => 'd2 f8 00 00 00',
    '-'.0x80000000 => 'd2 80 00 00 00',
    '-'.0x800000000 => 'c4 0c 2d 33 34 33 35 39 37 33 38 33 36 38',
    '-'.0x8000000000 => 'c4 0d 2d 35 34 39 37 35 35 38 31 33 38 38 38',
    '-'.0x800000000000000000000000000000 => $is_win ?
                                              qr{^(c4 16 2d 36 2e 36 34 36 31 33 39 39 37 38 39 32 34 35 38 65 2b 30 33 35|c4 19 2d 36 2e 36 34 36 31 33 39 39 37 38 39 32 34 35 37 39 33 36 65 2b 30 33 35)}
                                            : qr{^(c4 15 2d 36 2e 36 34 36 31 33 39 39 37 38 39 32 34 35 38 65 2b 33 35|c4 18 2d 36 2e 36 34 36 31 33 39 39 37 38 39 32 34 35 37 39 33 36 65 2b 33 35)},
    {'0' => '1'}, '81 00 01',
    {'abc' => '1'}, '81 c4 03 61 62 63 01',
);

my @dat_utf8 = (
    '-',     'a1 2d',
    ''.0xFFFFFFFFF => 'ab 36 38 37 31 39 34 37 36 37 33 35',
    ''.0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFF => $is_win ?
                                            qr{^(b5 38 2e 33 30 37 36 37 34 39 37 33 36 35 35 37 32 65 2b 30 33 34|b8 38 2e 33 30 37 36 37 34 39 37 33 36 35 35 37 32 34 32 31 65 2b 30 33 34)$}
                                          : qr{^(b4 38 2e 33 30 37 36 37 34 39 37 33 36 35 35 37 32 65 2b 33 34|b7 38 2e 33 30 37 36 37 34 39 37 33 36 35 35 37 32 34 32 31 65 2b 33 34)$},
    '-'.0x800000000 => 'ac 2d 33 34 33 35 39 37 33 38 33 36 38',
    '-'.0x8000000000 => 'ad 2d 35 34 39 37 35 35 38 31 33 38 38 38',
    '-'.0x800000000000000000000000000000 => $is_win ?
                                              qr{^(b6 2d 36 2e 36 34 36 31 33 39 39 37 38 39 32 34 35 38 65 2b 30 33 35|b9 2d 36 2e 36 34 36 31 33 39 39 37 38 39 32 34 35 37 39 33 36 65 2b 30 33 35)}
                                            : qr{^(b5 2d 36 2e 36 34 36 31 33 39 39 37 38 39 32 34 35 38 65 2b 33 35|b8 2d 36 2e 36 34 36 31 33 39 39 37 38 39 32 34 35 37 39 33 36 65 2b 33 35)},
    {'abc' => '1'}, '81 a3 61 62 63 01',
);

plan tests => 1*(scalar(@dat)/2) + 1*(scalar(@dat_utf8)/2) + 3;

for (my $i=0; $i<scalar(@dat); ) {
    local $Data::MessagePack::PreferInteger = 1;
    my($x, $y) = ($i++, $i++);
    pis $dat[$x], $dat[$y];
}

for (my $i=0; $i<scalar(@dat_utf8); ) {
    my($x, $y) = ($i++, $i++);
    pis_utf8 $dat_utf8[$x], $dat_utf8[$y], 1;
}

# flags working?
{
    local $Data::MessagePack::PreferInteger;
    $Data::MessagePack::PreferInteger = 1;
    pis '0',     '00';
    $Data::MessagePack::PreferInteger = 0;
    pis '0',     'c4 01 30';

    pis_utf8 '0', 'a1 30', 0;
}
