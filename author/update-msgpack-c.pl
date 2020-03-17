#!/usr/bin/env perl
use strict;
use warnings;

use HTTP::Tiny;
use IO::Socket::SSL;
use Path::Tiny;

use FindBin;
chdir "$FindBin::Bin/..";

my $version = shift or die "Usage: $0 VERSION\n";
my $url = "https://github.com/msgpack/msgpack-c/releases/download/cpp-$version/msgpack-$version.tar.gz";

my $tempdir = Path::Tiny->tempdir;

warn "Downloading $url\n";
my $res = HTTP::Tiny->new(veriry_SSL => 1)->mirror($url => "$tempdir/msgpack-$version.tar.gz");
die "$res->{status} $res->{reason}, $url\n" if !$res->{success};

warn "Unpacking msgpack-$version.tar.gz\n";
!system "tar", "xf", "$tempdir/msgpack-$version.tar.gz", "-C", "$tempdir" or die;

path($_)->remove_tree for grep -d, 'include', 't/std';

warn "Copying include/*.h\n";
path("$tempdir/msgpack-$version/include/msgpack")->visit(
    sub {
        my $path = shift;
        return if !$path->is_file;
        return if $path->stringify !~ /\.h$/;
        my $relative = $path->relative("$tempdir/msgpack-$version");
        $relative->parent->mkpath if !$relative->parent->exists;
        $path->copy($relative);
    },
    { recurse => 1 },
);

warn "Copying test/*.mapc\n";
path("t/std")->mkpath;
path("$tempdir/msgpack-$version/test")->visit(
    sub {
        my $path = shift;
        return if !$path->is_file;
        return if $path->stringify !~ /\.mpac$/;
        my $relative = $path->relative("$tempdir/msgpack-$version/test");
        $path->copy("t/std/$relative");
    },
);

warn "Writing include/msgpack-c-version\n";
path("include/msgpack-c-version")->spew("$version\n");
