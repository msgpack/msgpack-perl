package Data::MessagePack;
use strict;
use warnings;
use 5.008001;

our $VERSION = '1.02';

sub true () {
    require Data::MessagePack::Boolean;
    no warnings 'once';
    return $Data::MessagePack::Boolean::true;
}

sub false () {
    require Data::MessagePack::Boolean;
    no warnings 'once';
    return $Data::MessagePack::Boolean::false;
}

if ( !__PACKAGE__->can('pack') ) { # this idea comes from Text::Xslate
    my $backend = $ENV{PERL_DATA_MESSAGEPACK} || ($ENV{PERL_ONLY} ? 'pp' : '');
    if ( $backend !~ /\b pp \b/xms ) {
        eval {
            require XSLoader;
            XSLoader::load(__PACKAGE__, $VERSION);
        };
        die $@ if $@ && $backend =~ /\b xs \b/xms; # force XS
    }
    if ( !__PACKAGE__->can('pack') ) {
        require 'Data/MessagePack/PP.pm';
    }
}

sub new {
    my($class, %args) = @_;
    return bless \%args, $class;
}

foreach my $name(qw(canonical prefer_integer utf8)) {
    my $setter = sub {
        my($self, $value) = @_;
        $self->{$name} = defined($value) ? $value : 1;
        return $self;
    };
    my $getter = sub {
        my($self) = @_;
        return $self->{$name};
    };
    no strict 'refs';
    *{$name}          = $setter;
    *{'get_' . $name} = $getter;
}


sub encode; *encode = __PACKAGE__->can('pack');
sub decode; *decode = __PACKAGE__->can('unpack');

1;
__END__

=head1 NAME

Data::MessagePack - MessagePack serializing/deserializing

=head1 SYNOPSIS

    use Data::MessagePack;

    my $mp = Data::MessagePack->new();
    $mp->canonical->utf8->prefer_integer if $needed;

    my $packed   = $mp->pack($dat);
    my $unpacked = $mp->unpack($dat);

=head1 DESCRIPTION

This module converts Perl data structures to MessagePack and vice versa.

=head1 ABOUT MESSAGEPACK FORMAT

MessagePack is a binary-based efficient object serialization format.
It enables to exchange structured objects between many languages like
JSON.  But unlike JSON, it is very fast and small.

=head2 ADVANTAGES

=over 4

=item PORTABLE

The MessagePack format does not depend on language nor byte order.

=item SMALL IN SIZE

    say length(JSON::XS::encode_json({a=>1, b=>2}));   # => 13
    say length(Storable::nfreeze({a=>1, b=>2}));       # => 21
    say length(Data::MessagePack->pack({a=>1, b=>2})); # => 7

The MessagePack format saves memory than JSON and Storable format.

=item STREAMING DESERIALIZER

MessagePack supports streaming deserializer. It is useful for
networking such as RPC.  See L<Data::MessagePack::Unpacker> for
details.

=back

If you want to get more information about the MessagePack format,
please visit to L<http://msgpack.org/>.

=head1 METHODS

=over

=item C<< my $packed = Data::MessagePack->pack($data[, $max_depth]); >>

Pack the $data to messagepack format string.

This method throws an exception when the perl structure is nested more
than $max_depth levels(default: 512) in order to detect circular
references.

Data::MessagePack->pack() throws an exception when encountering a
blessed perl object, because MessagePack is a language-independent
format.

=item C<< my $unpacked = Data::MessagePack->unpack($msgpackstr); >>

unpack the $msgpackstr to a MessagePack format string.

=item C<< my $mp = Data::MesssagePack->new() >>

Creates a new MessagePack instance.

=item C<< $mp = $mp->prefer_integer([ $enable ]) >>

=item C<< $enabled = $mp->get_prefer_integer() >>

If I<$enable> is true (or missing), then the C<pack> method tries a
string as an integer if the string looks like an integer.

=item C<< $mp = $mp->canonical([ $enable ]) >>

=item C<< $enabled = $mp->get_canonical() >>

If I<$enable> is true (or missing), then the C<pack> method will output
packed data by sorting their keys. This is adding a comparatively high
overhead.

=item C<< $mp = $mp->utf8([ $enable ]) >>

=item C<< $enabled = $mp->get_utf8() >>

If I<$enable> is true (or missing), then the C<pack> method will
apply C<utf8::encode()> to all the string values.

In other words, this property tell C<$mp> to deal with B<text strings>.
See L<perlunifaq> for the meaning of B<text string>.

=item C<< $packed = $mp->pack($data) >>

=item C<< $packed = $mp->encode($data) >>

Same as C<< Data::MessagePack->pack() >>, but properties are respected.

=item C<< $data = $mp->unpack($data) >>

=item C<< $data = $mp->decode($data) >>

Same as C<< Data::MessagePack->unpack() >>, but properties are respected.

=back

=head1 Configuration Variables (DEPRECATED)

=over 4

=item $Data::MessagePack::PreferInteger

Packs a string as an integer, when it looks like an integer.

This variable is B<deprecated>.
Use C<< $msgpack->prefer_integer >> property instead.

=back

=head1 SPEED

This is a result of F<benchmark/serialize.pl> and F<benchmark/deserialize.pl>
on my SC440(Linux 2.6.32-23-server #37-Ubuntu SMP).
(You should benchmark them with B<your> data if the speed matters, of course.)

    -- serialize
    JSON::XS: 2.3
    Data::MessagePack: 0.24
    Storable: 2.21
    Benchmark: running json, mp, storable for at least 1 CPU seconds...
          json:  1 wallclock secs ( 1.00 usr +  0.01 sys =  1.01 CPU) @ 141939.60/s (n=143359)
            mp:  1 wallclock secs ( 1.06 usr +  0.00 sys =  1.06 CPU) @ 355500.94/s (n=376831)
      storable:  1 wallclock secs ( 1.12 usr +  0.00 sys =  1.12 CPU) @ 38399.11/s (n=43007)
                 Rate storable     json       mp
    storable  38399/s       --     -73%     -89%
    json     141940/s     270%       --     -60%
    mp       355501/s     826%     150%       --

    -- deserialize
    JSON::XS: 2.3
    Data::MessagePack: 0.24
    Storable: 2.21
    Benchmark: running json, mp, storable for at least 1 CPU seconds...
          json:  0 wallclock secs ( 1.05 usr +  0.00 sys =  1.05 CPU) @ 179442.86/s (n=188415)
            mp:  0 wallclock secs ( 1.01 usr +  0.00 sys =  1.01 CPU) @ 212909.90/s (n=215039)
      storable:  2 wallclock secs ( 1.14 usr +  0.00 sys =  1.14 CPU) @ 114974.56/s (n=131071)
                 Rate storable     json       mp
    storable 114975/s       --     -36%     -46%
    json     179443/s      56%       --     -16%
    mp       212910/s      85%      19%       --

=head1 CAVEAT

=head2 Unpacking 64 bit integers

This module can unpack 64 bit integers even if your perl does not support them
(i.e. where C<< perl -V:ivsize >> is 4), but you cannot calculate these values
unless you use C<Math::BigInt>.

=head1 TODO

=over

=item Error handling

MessagePack cannot deal with complex scalars such as object references,
filehandles, and code references. We should report the errors more kindly.

=item Streaming deserializer

The current implementation of the streaming deserializer does not have internal
buffers while some other bindings (such as Ruby binding) does. This limitation
will astonish those who try to unpack byte streams with an arbitrary buffer size
(e.g. C<< while(read($socket, $buffer, $arbitrary_buffer_size)) { ... } >>).
We should implement the internal buffer for the unpacker.

=back

=head1 FAQ

=over 4

=item Why does Data::MessagePack have pure perl implementations?

msgpack C library uses C99 feature, VC++6 does not support C99. So pure perl version is needed for VC++ users.

=back

=head1 AUTHORS

Tokuhiro Matsuno

Makamaka Hannyaharamitu

gfx

=head1 THANKS TO

Jun Kuriyama

Dan Kogai

FURUHASHI Sadayuki

hanekomu

Kazuho Oku

syohex

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<http://msgpack.org/> is the official web site for the  MessagePack format.

L<Data::MessagePack::Unpacker>

L<AnyEvent::MPRPC>

=cut
