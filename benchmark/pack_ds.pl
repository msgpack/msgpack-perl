# -*- perl -*-
use Data::MessagePack;
# benchmark small (50b), middle (2-3k) and large hashes (~100k)
do 'benchmark/wordlist.pl';

my $p1 = Data::MessagePack->pack( \%h1 ) for (1...10_000);
