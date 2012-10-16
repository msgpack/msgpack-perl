# -*- perl -*-
use JSON;
# benchmark small (50b), middle (2-3k) and large hashes (~100k)
do 'benchmark/wordlist.pl';

my $j3 = JSON::encode_json( \%h3 ) for (1 .. 10_000);
