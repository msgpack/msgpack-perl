[![Build Status](https://travis-ci.org/msgpack/msgpack-perl.svg?branch=master)](https://travis-ci.org/msgpack/msgpack-perl)
# NAME

Data::MessagePack - MessagePack serializing/deserializing

# SYNOPSIS

    use Data::MessagePack;

    my $mp = Data::MessagePack->new();
    $mp->canonical->utf8->prefer_integer if $needed;

    my $packed   = $mp->pack($dat);
    my $unpacked = $mp->unpack($dat);

# DESCRIPTION

This module converts Perl data structures to MessagePack and vice versa.

# ABOUT MESSAGEPACK FORMAT

MessagePack is a binary-based efficient object serialization format.
It enables to exchange structured objects between many languages like
JSON.  But unlike JSON, it is very fast and small.

## ADVANTAGES

- PORTABLE

    The MessagePack format does not depend on language nor byte order.

- SMALL IN SIZE

        say length(JSON::XS::encode_json({a=>1, b=>2}));   # => 13
        say length(Storable::nfreeze({a=>1, b=>2}));       # => 21
        say length(Data::MessagePack->pack({a=>1, b=>2})); # => 7

    The MessagePack format saves memory than JSON and Storable format.

- STREAMING DESERIALIZER

    MessagePack supports streaming deserializer. It is useful for
    networking such as RPC.  See [Data::MessagePack::Unpacker](https://metacpan.org/pod/Data%3A%3AMessagePack%3A%3AUnpacker) for
    details.

If you want to get more information about the MessagePack format,
please visit to [http://msgpack.org/](http://msgpack.org/).

# METHODS

- `my $packed = Data::MessagePack->pack($data[, $max_depth]);`

    Pack the $data to messagepack format string.

    This method throws an exception when the perl structure is nested more
    than $max\_depth levels(default: 512) in order to detect circular
    references.

    Data::MessagePack->pack() throws an exception when encountering a
    blessed perl object, because MessagePack is a language-independent
    format.

- `my $unpacked = Data::MessagePack->unpack($msgpackstr);`

    unpack the $msgpackstr to a MessagePack format string.

- `my $mp = Data::MesssagePack->new()`

    Creates a new MessagePack instance.

- `$mp = $mp->prefer_integer([ $enable ])`
- `$enabled = $mp->get_prefer_integer()`

    If _$enable_ is true (or missing), then the `pack` method tries a
    string as an integer if the string looks like an integer.

- `$mp = $mp->canonical([ $enable ])`
- `$enabled = $mp->get_canonical()`

    If _$enable_ is true (or missing), then the `pack` method will output
    packed data by sorting their keys. This is adding a comparatively high
    overhead.

- `$mp = $mp->utf8([ $enable ])`
- `$enabled = $mp->get_utf8()`

    If _$enable_ is true (or missing), then the `pack` method will
    apply `utf8::encode()` to all the string values.

    In other words, this property tell `$mp` to deal with **text strings**.
    See [perlunifaq](https://metacpan.org/pod/perlunifaq) for the meaning of **text string**.

- `$packed = $mp->pack($data)`
- `$packed = $mp->encode($data)`

    Same as `Data::MessagePack->pack()`, but properties are respected.

- `$data = $mp->unpack($data)`
- `$data = $mp->decode($data)`

    Same as `Data::MessagePack->unpack()`, but properties are respected.

# Configuration Variables (DEPRECATED)

- $Data::MessagePack::PreferInteger

    Packs a string as an integer, when it looks like an integer.

    This variable is **deprecated**.
    Use `$msgpack->prefer_integer` property instead.

# SPEED

This is a result of `benchmark/serialize.pl` and `benchmark/deserialize.pl`
on my SC440(Linux 2.6.32-23-server #37-Ubuntu SMP).
(You should benchmark them with **your** data if the speed matters, of course.)

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

# CAVEAT

## Unpacking 64 bit integers

This module can unpack 64 bit integers even if your perl does not support them
(i.e. where `perl -V:ivsize` is 4), but you cannot calculate these values
unless you use `Math::BigInt`.

# TODO

- Error handling

    MessagePack cannot deal with complex scalars such as object references,
    filehandles, and code references. We should report the errors more kindly.

- Streaming deserializer

    The current implementation of the streaming deserializer does not have internal
    buffers while some other bindings (such as Ruby binding) does. This limitation
    will astonish those who try to unpack byte streams with an arbitrary buffer size
    (e.g. `while(read($socket, $buffer, $arbitrary_buffer_size)) { ... }`).
    We should implement the internal buffer for the unpacker.

# FAQ

- Why does Data::MessagePack have pure perl implementations?

    msgpack C library uses C99 feature, VC++6 does not support C99. So pure perl version is needed for VC++ users.

# AUTHORS

Tokuhiro Matsuno

Makamaka Hannyaharamitu

gfx

# THANKS TO

Jun Kuriyama

Dan Kogai

FURUHASHI Sadayuki

hanekomu

Kazuho Oku

syohex

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

[http://msgpack.org/](http://msgpack.org/) is the official web site for the  MessagePack format.

[Data::MessagePack::Unpacker](https://metacpan.org/pod/Data%3A%3AMessagePack%3A%3AUnpacker)

[AnyEvent::MPRPC](https://metacpan.org/pod/AnyEvent%3A%3AMPRPC)
