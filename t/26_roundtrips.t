# -*- perl -*-
use Test::More tests => 3;
use Data::MessagePack;
use JSON;
use Storable;
use Benchmark ':all';
# benchmark small (50b), middle (2-3k) and large hashes (~100k)
use Data::Random::WordList;
my $wl = new Data::Random::WordList( wordlist => '/usr/share/dict/words' );
my @wl = $wl->get_words(2000);

my $d = 123-48;
sub randstr {
  my $len = shift;
  my $s = " " x $len;
  substr($s,$_,1,chr(int(rand($d)) + 48)) for 0 .. $len-1;
  return $s;
}

sub randword {
  my $len = shift;
  my $s = $wl[int(rand(2000))];
  while (length($s)<$len) {
    if (substr($s,-2,2) eq "'s") {
      $s = substr($s,0,-2);
    }
    $s .= "-".$wl[int(rand(2000))];
  }
  return $s;
}

{
  my %h1 = ("test" => 0,
	    "some typical long string for smaz" => 1,
	    "test2" => "2");
  my %h2, %h3;
  my $i = 1;
  $h2{ randword(int(rand(20))+4) }  = $i++ for 1..200;
  $h3{ randword(int(rand(12))) . $i++ } = randstr(rand(int(12)+10)) for 1..2000;
  $h3{ randword(int(rand(12))+10) } = $i++ % 2 ? 0 : 1 for 1..2000;
  my $mp = Data::MessagePack->new();

  my $p1 = $mp->pack( \%h1 );
  my $j1 = JSON::encode_json( \%h1 );
  my $s1 = Storable::freeze( \%h1 );
  my $u1 = $mp->unpack( $p1 );
  is_deeply( \%h1, $u1, "round trip small  hash ".length($p1)."/".length($j1) );

  my $p2 = $mp->pack( \%h2 );
  my $j2 = JSON::encode_json( \%h2 );
  my $s2 = Storable::freeze( \%h2 );
  my $u2 = $mp->unpack( $p2 );
  is_deeply( \%h2, $u2, "round trip medium hash ".length($p2)."/".length($j2) );

  my $p3 = $mp->pack( \%h3 );
  my $j3 = JSON::encode_json( \%h3 );
  my $s3 = Storable::freeze( \%h3 );
  my $u3 = $mp->unpack( $p3 );
  is_deeply( \%h3, $u3, "round trip large  hash ".length($p3)."/".length($j3) );

  diag "$JSON::Backend: ", $JSON::Backend->VERSION, "\n";
  diag "Data::MessagePack: $Data::MessagePack::VERSION\n";
  diag "Storable: $Storable::VERSION\n";
  diag "-- serialize small\n";
  cmpthese timethese(-1 => {
      '#D::MP'    => sub { Data::MessagePack->pack(\%h1) },
      '#JSON::XS' => sub { JSON::encode_json(\%h1) },
      '#Storable' => sub { Storable::freeze(\%h1) },
  });
  diag "-- serialize medium\n";
  cmpthese timethese(-1 => {
      '#JSON::XS' => sub { JSON::encode_json(\%h2) },
      '#D::MP'    => sub { Data::MessagePack->pack(\%h2) },
      '#Storable' => sub { Storable::freeze(\%h2) },
  });
  diag "-- serialize large\n";
  cmpthese timethese(-1 => {
      '#Storable'  => sub { Storable::freeze(\%h3) },
      '#D::MP'     => sub { Data::MessagePack->pack(\%h3) },
      '#JSON::XS'  => sub { JSON::encode_json(\%h3) },
		     });
  diag "-- deserialize small\n";
  cmpthese timethese(-1 => {
      '#Storable'  => sub { Storable::thaw($s1) },
      '#D::MP'     => sub { Data::MessagePack->unpack($p1) },
      '#JSON::XS'  => sub { JSON::decode_json($j1) },
		     });
  diag "-- deserialize medium\n";
  cmpthese timethese(-1 => {
      '#Storable'  => sub { Storable::thaw($s2) },
      '#D::MP'     => sub { Data::MessagePack->unpack($p2) },
      '#JSON::XS'  => sub { JSON::decode_json($j2) },
		     });

  diag "-- deserialize large\n";
  cmpthese timethese(-1 => {
      '#Storable'  => sub { Storable::thaw($s3) },
      '#D::MP'     => sub { Data::MessagePack->unpack($p3) },
      '#JSON::XS'  => sub { JSON::decode_json($j3) },
		     });

  cmpthese timethese(
    -1 => {
      '#json_small' => sub { JSON::decode_json($j1) },
      '#json_medium' => sub { JSON::decode_json($j2) },
      '#json_large' => sub { JSON::decode_json($j3) },
      '#mp_small'  => sub { Data::MessagePack->unpack($p1) },
      '#mp_medium' => sub { Data::MessagePack->unpack($p2) },
      '#mp_large'  => sub { Data::MessagePack->unpack($p3) },
    });
}

__END__

2012-08-02 17:56:48 rurban
ok 1 - round trip small  hash 52/60
ok 2 - round trip medium hash 3887/4690
ok 3 - round trip large  hash 97879/112088
# JSON::XS: 2.32
# Data::MessagePack: 0.46
# Storable: 2.35
# -- serialize small
Benchmark: running #D::MP, #JSON::XS, #Storable for at least 1 CPU seconds...
    #D::MP:  1 wallclock secs ( 1.01 usr +  0.00 sys =  1.01 CPU) @ 567762.38/s (n=573440)
 #JSON::XS:  0 wallclock secs ( 1.08 usr +  0.00 sys =  1.08 CPU) @ 1279826.85/s (n=1382213)
 #Storable:  2 wallclock secs ( 1.05 usr +  0.00 sys =  1.05 CPU) @ 156038.10/s (n=163840)
               Rate #Storable    #D::MP #JSON::XS
#Storable  156038/s        --      -73%      -88%
#D::MP     567762/s      264%        --      -56%
#JSON::XS 1279827/s      720%      125%        --
# -- serialize medium
Benchmark: running #D::MP, #JSON::XS, #Storable for at least 1 CPU seconds...
    #D::MP:  1 wallclock secs ( 1.06 usr +  0.00 sys =  1.06 CPU) @ 9660.38/s (n=10240)
 #JSON::XS:  1 wallclock secs ( 1.06 usr +  0.00 sys =  1.06 CPU) @ 38641.51/s (n=40960)
 #Storable:  1 wallclock secs ( 1.05 usr +  0.00 sys =  1.05 CPU) @ 37236.19/s (n=39098)
             Rate    #D::MP #Storable #JSON::XS
#D::MP     9660/s        --      -74%      -75%
#Storable 37236/s      285%        --       -4%
#JSON::XS 38642/s      300%        4%        --
# -- serialize large
Benchmark: running #D::MP, #JSON::XS, #Storable for at least 1 CPU seconds...
    #D::MP:  1 wallclock secs ( 1.04 usr +  0.00 sys =  1.04 CPU) @ 293.27/s (n=305)
 #JSON::XS:  1 wallclock secs ( 1.04 usr +  0.01 sys =  1.05 CPU) @ 1599.05/s (n=1679)
 #Storable:  1 wallclock secs ( 1.06 usr +  0.00 sys =  1.06 CPU) @ 1583.96/s (n=1679)
            Rate    #D::MP #Storable #JSON::XS
#D::MP     293/s        --      -81%      -82%
#Storable 1584/s      440%        --       -1%
#JSON::XS 1599/s      445%        1%        --
# -- deserialize
Benchmark: running #json_large, #json_medium, #json_small, #mp_large, #mp_medium, #mp_small for at least 1 CPU seconds...
#json_large:  1 wallclock secs ( 1.10 usr +  0.00 sys =  1.10 CPU) @ 718.18/s (n=790)
#json_medium:  1 wallclock secs ( 1.14 usr +  0.00 sys =  1.14 CPU) @ 18862.28/s (n=21503)
#json_small:  1 wallclock secs ( 1.06 usr +  0.00 sys =  1.06 CPU) @ 811470.75/s (n=860159)
 #mp_large:  1 wallclock secs ( 1.11 usr +  0.00 sys =  1.11 CPU) @ 636.94/s (n=707)
#mp_medium:  1 wallclock secs ( 1.09 usr +  0.00 sys =  1.09 CPU) @ 16439.45/s (n=17919)
 #mp_small:  2 wallclock secs ( 1.11 usr +  0.00 sys =  1.11 CPU) @ 688816.22/s (n=764586)
                 Rate #mp_large #json_large #mp_medium #json_medium #mp_small #json_small
#mp_large       637/s        --        -11%       -96%         -97%     -100%       -100%
#json_large     718/s       13%          --       -96%         -96%     -100%       -100%
#mp_medium    16439/s     2481%       2189%         --         -13%      -98%        -98%
#json_medium  18862/s     2861%       2526%        15%           --      -97%        -98%
#mp_small    688816/s   108045%      95811%      4090%        3552%        --        -15%
#json_small  811471/s   127302%     112890%      4836%        4202%       18%          --


ok 1 - round trip small  hash 52/60
ok 2 - round trip medium hash 2790/3560
ok 3 - round trip large  hash 118086/136416
# -- serialize
Benchmark: running json_large, json_medium, json_small, mp_large, mp_medium, mp_small for at least 1 CPU seconds...
json_large:  1 wallclock secs ( 1.12 usr +  0.01 sys =  1.13 CPU) @ 1321.24/s (n=1493)
json_medium:  1 wallclock secs ( 1.03 usr +  0.00 sys =  1.03 CPU) @ 43952.43/s (n=45271)
json_small:  0 wallclock secs ( 1.08 usr +  0.00 sys =  1.08 CPU) @ 1279826.85/s (n=1382213)
  mp_large:  1 wallclock secs ( 1.08 usr +  0.00 sys =  1.08 CPU) @ 259.26/s (n=280)
 mp_medium:  1 wallclock secs ( 1.09 usr +  0.00 sys =  1.09 CPU) @ 10382.57/s (n=11317)
  mp_small:  1 wallclock secs ( 1.13 usr +  0.00 sys =  1.13 CPU) @ 553601.77/s (n=625570)
                 Rate mp_large json_large mp_medium json_medium mp_small json_small
mp_large        259/s       --       -80%      -98%        -99%    -100%      -100%
json_large     1321/s     410%         --      -87%        -97%    -100%      -100%
mp_medium     10383/s    3905%       686%        --        -76%     -98%       -99%
json_medium   43952/s   16853%      3227%      323%          --     -92%       -97%
mp_small     553602/s  213432%     41800%     5232%       1160%       --       -57%
json_small  1279827/s  493548%     96766%    12227%       2812%     131%         --
# -- deserialize
Benchmark: running json_large, json_medium, json_small, mp_large, mp_medium, mp_small for at least 1 CPU seconds...
json_large:  1 wallclock secs ( 1.04 usr +  0.00 sys =  1.04 CPU) @ 537.50/s (n=559)
json_medium:  1 wallclock secs ( 1.09 usr +  0.00 sys =  1.09 CPU) @ 24659.63/s (n=26879)
json_small:  2 wallclock secs ( 1.09 usr +  0.00 sys =  1.09 CPU) @ 789136.70/s (n=860159)
  mp_large:  1 wallclock secs ( 1.10 usr +  0.00 sys =  1.10 CPU) @ 508.18/s (n=559)
 mp_medium:  1 wallclock secs ( 1.10 usr +  0.00 sys =  1.10 CPU) @ 17771.82/s (n=19549)
  mp_small:  1 wallclock secs ( 1.01 usr +  0.00 sys =  1.01 CPU) @ 717173.27/s (n=724345)
                Rate mp_large json_large mp_medium json_medium mp_small json_small
mp_large       508/s       --        -5%      -97%        -98%    -100%      -100%
json_large     537/s       6%         --      -97%        -98%    -100%      -100%
mp_medium    17772/s    3397%      3206%        --        -28%     -98%       -98%
json_medium  24660/s    4753%      4488%       39%          --     -97%       -97%
mp_small    717173/s  141025%    133328%     3935%       2808%       --        -9%
json_small  789137/s  155186%    146716%     4340%       3100%      10%         --

SMAZ:
ok 1 - round trip small  hash 38/60
ok 2 - round trip medium hash 3370/4635
ok 3 - round trip large  hash 96913/111681
# JSON::XS: 2.32
# Data::MessagePack: 0.46_02
# Storable: 2.35
# -- serialize small
Benchmark: running #D::MP, #JSON::XS, #Storable for at least 1 CPU seconds...
    #D::MP:  1 wallclock secs ( 1.06 usr +  0.00 sys =  1.06 CPU) @ 405734.91/s (n=430079)
 #JSON::XS:  1 wallclock secs ( 1.01 usr +  0.00 sys =  1.01 CPU) @ 1238753.47/s (n=1251141)
 #Storable:  1 wallclock secs ( 1.07 usr +  0.00 sys =  1.07 CPU) @ 160776.64/s (n=172031)
               Rate #Storable    #D::MP #JSON::XS
#Storable  160777/s        --      -60%      -87%
#D::MP     405735/s      152%        --      -67%
#JSON::XS 1238753/s      670%      205%        --
# -- serialize medium
Benchmark: running #D::MP, #JSON::XS, #Storable for at least 1 CPU seconds...
    #D::MP:  1 wallclock secs ( 1.10 usr +  0.00 sys =  1.10 CPU) @ 4071.82/s (n=4479)
 #JSON::XS:  1 wallclock secs ( 1.12 usr +  0.00 sys =  1.12 CPU) @ 38399.11/s (n=43007)
 #Storable:  1 wallclock secs ( 1.08 usr +  0.00 sys =  1.08 CPU) @ 37925.00/s (n=40959)
             Rate    #D::MP #Storable #JSON::XS
#D::MP     4072/s        --      -89%      -89%
#Storable 37925/s      831%        --       -1%
#JSON::XS 38399/s      843%        1%        --
# -- serialize large
Benchmark: running #D::MP, #JSON::XS, #Storable for at least 1 CPU seconds...
    #D::MP:  1 wallclock secs ( 1.07 usr +  0.00 sys =  1.07 CPU) @ 142.06/s (n=152)
 #JSON::XS:  1 wallclock secs ( 1.10 usr +  0.00 sys =  1.10 CPU) @ 1628.18/s (n=1791)
 #Storable:  1 wallclock secs ( 1.04 usr +  0.03 sys =  1.07 CPU) @ 1569.16/s (n=1679)
            Rate    #D::MP #Storable #JSON::XS
#D::MP     142/s        --      -91%      -91%
#Storable 1569/s     1005%        --       -4%
#JSON::XS 1628/s     1046%        4%        --
# -- deserialize
Benchmark: running #json_large, #json_medium, #json_small, #mp_large, #mp_medium, #mp_small for at least 1 CPU seconds...
#json_large:  1 wallclock secs ( 1.09 usr +  0.00 sys =  1.09 CPU) @ 724.77/s (n=790)
#json_medium:  1 wallclock secs ( 1.09 usr +  0.00 sys =  1.09 CPU) @ 18788.07/s (n=20479)
#json_small:  0 wallclock secs ( 1.08 usr +  0.00 sys =  1.08 CPU) @ 796443.52/s (n=860159)
 #mp_large:  1 wallclock secs ( 1.06 usr +  0.00 sys =  1.06 CPU) @ 395.28/s (n=419)
#mp_medium:  1 wallclock secs ( 1.12 usr +  0.00 sys =  1.12 CPU) @ 9599.11/s (n=10751)
 #mp_small:  1 wallclock secs ( 1.09 usr +  0.00 sys =  1.09 CPU) @ 526090.83/s (n=573439)
                 Rate #mp_large #json_large #mp_medium #json_medium #mp_small #json_small
#mp_large       395/s        --        -45%       -96%         -98%     -100%       -100%
#json_large     725/s       83%          --       -92%         -96%     -100%       -100%
#mp_medium     9599/s     2328%       1224%         --         -49%      -98%        -99%
#json_medium  18788/s     4653%       2492%        96%           --      -96%        -98%
#mp_small    526091/s   132992%      72487%      5381%        2700%        --        -34%
#json_small  796444/s   201387%     109789%      8197%        4139%       51%          --

