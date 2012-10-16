# -*- perl -*-
use Storable;
# benchmark small (50b), middle (2-3k) and large hashes (~100k)
do 'benchmark/wordlist.pl';

my $s2 = Storable::freeze( \%h2 ) for (1 .. 10_000);
