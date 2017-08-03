
use Types::Serialiser ();

BEGIN {
    *Data::MessagePack::Boolean:: = *Types::Serialiser::Boolean::;
}

package
  Data::MessagePack;

BEGIN {
    *true    = \&Types::Serialiser::true;
    *false   = \&Types::Serialiser::false;
    *is_bool = \&Types::Serialiser::is_bool;
}

1;
