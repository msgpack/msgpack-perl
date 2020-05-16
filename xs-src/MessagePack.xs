#include "xshelper.h"

#ifndef __cplusplus
#include <stdbool.h>
#endif

XS(xs_pack);
XS(xs_unpack);
XS(xs_unpacker_new);
XS(xs_unpacker_utf8);
XS(xs_unpacker_get_utf8);
XS(xs_unpacker_prefer_types_serialiser);
XS(xs_unpacker_get_prefer_types_serialiser);
XS(xs_unpacker_execute);
XS(xs_unpacker_execute_limit);
XS(xs_unpacker_is_finished);
XS(xs_unpacker_data);
XS(xs_unpacker_reset);
XS(xs_unpacker_destroy);

void init_Data__MessagePack_pack(pTHX_ bool const cloning);
void init_Data__MessagePack_unpack(pTHX_ bool const cloning);

MODULE = Data::MessagePack PACKAGE = Data::MessagePack

BOOT:
{
    init_Data__MessagePack_pack(aTHX_   false);
    init_Data__MessagePack_unpack(aTHX_ false);

    newXS("Data::MessagePack::pack",   xs_pack,   __FILE__);
    newXS("Data::MessagePack::unpack", xs_unpack, __FILE__);

    newXS("Data::MessagePack::Unpacker::new",           xs_unpacker_new, __FILE__);
    newXS("Data::MessagePack::Unpacker::utf8",          xs_unpacker_utf8, __FILE__);
    newXS("Data::MessagePack::Unpacker::get_utf8",      xs_unpacker_get_utf8, __FILE__);
    newXS("Data::MessagePack::Unpacker::execute",       xs_unpacker_execute, __FILE__);
    newXS("Data::MessagePack::Unpacker::execute_limit", xs_unpacker_execute_limit, __FILE__);
    newXS("Data::MessagePack::Unpacker::is_finished",   xs_unpacker_is_finished, __FILE__);
    newXS("Data::MessagePack::Unpacker::data",          xs_unpacker_data, __FILE__);
    newXS("Data::MessagePack::Unpacker::reset",         xs_unpacker_reset, __FILE__);
    newXS("Data::MessagePack::Unpacker::DESTROY",       xs_unpacker_destroy, __FILE__);

    newXS("Data::MessagePack::Unpacker::prefer_types_serialiser",          xs_unpacker_prefer_types_serialiser, __FILE__);
    newXS("Data::MessagePack::Unpacker::get_prefer_types_serialiser",      xs_unpacker_get_prefer_types_serialiser, __FILE__);
}

#ifdef USE_ITHREADS

void
CLONE(...)
CODE:
{
    PERL_UNUSED_VAR(items);
    init_Data__MessagePack_pack(aTHX_ true);
    init_Data__MessagePack_unpack(aTHX_ true);
}

#endif // USE_ITHREADS

