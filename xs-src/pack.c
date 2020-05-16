/*
 * code is written by tokuhirom.
 * buffer alocation technique is taken from JSON::XS. thanks to mlehmann.
 */
#include "xshelper.h"

#include "msgpack/pack_define.h"

#define msgpack_pack_inline_func(name) \
    static inline void msgpack_pack ## name

#define msgpack_pack_inline_func_cint(name) \
    static inline void msgpack_pack ## name

// serialization context
typedef struct {
    char *cur;       /* SvPVX (sv) + current output position */
    const char *end; /* SvEND (sv) */
    SV *sv;          /* result scalar */

    bool prefer_int;
    bool canonical;
} enc_t;

STATIC_INLINE void
dmp_append_buf(enc_t* const enc, const void* const buf, STRLEN const len)
{
    if (enc->cur + len >= enc->end) {
        dTHX;
        STRLEN const cur = enc->cur - SvPVX_const(enc->sv);
        sv_grow (enc->sv, cur + (len < (cur >> 2) ? cur >> 2 : len) + 1);
        enc->cur = SvPVX_mutable(enc->sv) + cur;
        enc->end = SvPVX_const(enc->sv) + SvLEN (enc->sv) - 1;
    }

    memcpy(enc->cur, buf, len);
    enc->cur += len;
}

#define msgpack_pack_user enc_t*

#define msgpack_pack_append_buffer(enc, buf, len) \
            dmp_append_buf(enc, buf, len)

#include "msgpack/pack_template.h"

#define INIT_SIZE   32 /* initial scalar size to be allocated */

#if   IVSIZE == 8
#  define PACK_IV msgpack_pack_int64
#  define PACK_UV msgpack_pack_uint64
#elif IVSIZE == 4
#  define PACK_IV msgpack_pack_int32
#  define PACK_UV msgpack_pack_uint32
#elif IVSIZE == 2
#  define PACK_IV msgpack_pack_int16
#  define PACK_UV msgpack_pack_uint16
#else
#  error  "msgpack only supports IVSIZE = 8,4,2 environment."
#endif

#define ERR_NESTING_EXCEEDED "perl structure exceeds maximum nesting level (max_depth set too low?)"

#define DMP_PREF_INT  "PreferInteger"

/* interpreter global variables */
#define MY_CXT_KEY "Data::MessagePack::_pack_guts" XS_VERSION
typedef struct {
    bool prefer_int;
    bool canonical;
} my_cxt_t;
START_MY_CXT


static int dmp_config_set(pTHX_ SV* sv, MAGIC* mg) {
    dMY_CXT;
    assert(mg->mg_ptr);
    if(strEQ(mg->mg_ptr, DMP_PREF_INT)) {
        MY_CXT.prefer_int = SvTRUE(sv) ? true : false;
    }
    else {
        assert(0);
    }
    return 0;
}

MGVTBL dmp_config_vtbl = {
    NULL,
    dmp_config_set,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
#ifdef MGf_LOCAL
    NULL,
#endif
};

void init_Data__MessagePack_pack(pTHX_ bool const cloning) {
    if(!cloning) {
        MY_CXT_INIT;
        MY_CXT.prefer_int = false;
        MY_CXT.canonical  = false;
    }
    else {
        MY_CXT_CLONE;
    }

    SV* var = get_sv("Data::MessagePack::" DMP_PREF_INT, GV_ADDMULTI);
    sv_magicext(var, NULL, PERL_MAGIC_ext, &dmp_config_vtbl,
            DMP_PREF_INT, 0);
    SvSETMAGIC(var);
}


STATIC_INLINE int try_int(enc_t* enc, const char *p, size_t len) {
    int negative = 0;
    const char* pe = p + len;
    uint64_t num = 0;

    if (len == 0) { return 0; }

    if (*p == '-') {
        /* length(-0x80000000) == 11 */
        if (len <= 1 || len > 11) { return 0; }
        negative = 1;
        ++p;
    } else {
        /* length(0xFFFFFFFF) == 10 */
        if (len > 10) { return 0; }
    }

#if '9'=='8'+1 && '8'=='7'+1 && '7'=='6'+1 && '6'=='5'+1 && '5'=='4'+1 \
               && '4'=='3'+1 && '3'=='2'+1 && '2'=='1'+1 && '1'=='0'+1
    do {
        unsigned int c = ((int)*(p++)) - '0';
        if (c > 9) { return 0; }
        num = num * 10 + c;
    } while(p < pe);
#else
    do {
        switch (*(p++)) {
        case '0': num = num * 10 + 0; break;
        case '1': num = num * 10 + 1; break;
        case '2': num = num * 10 + 2; break;
        case '3': num = num * 10 + 3; break;
        case '4': num = num * 10 + 4; break;
        case '5': num = num * 10 + 5; break;
        case '6': num = num * 10 + 6; break;
        case '7': num = num * 10 + 7; break;
        case '8': num = num * 10 + 8; break;
        case '9': num = num * 10 + 9; break;
        default: return 0;
        }
    } while(p < pe);
#endif

    if (negative) {
        if (num > 0x80000000) { return 0; }
        msgpack_pack_int32(enc, ((int32_t)-num));
    } else {
        if (num > 0xFFFFFFFF) { return 0; }
        msgpack_pack_uint32(enc, (uint32_t)num);
    }

    return 1;
}


STATIC_INLINE void _msgpack_pack_rv(pTHX_ enc_t *enc, SV* sv, int depth, bool utf8);

STATIC_INLINE void _msgpack_pack_sv(pTHX_ enc_t* const enc, SV* const sv, int const depth, bool utf8) {
    assert(sv);
    if (UNLIKELY(depth <= 0)) Perl_croak(aTHX_ ERR_NESTING_EXCEEDED);
    SvGETMAGIC(sv);

    if (SvPOKp(sv)) {
        STRLEN const len     = SvCUR(sv);
        const char* const pv = SvPVX_const(sv);

        if (enc->prefer_int && try_int(enc, pv, len)) {
            return;
        } else {
            if (utf8) {
                msgpack_pack_str(enc, len);
                msgpack_pack_str_body(enc, pv, len);
            } else {
                msgpack_pack_bin(enc, len);
                msgpack_pack_bin_body(enc, pv, len);
            }
        }
    } else if (SvNOKp(sv)) {
        msgpack_pack_double(enc, (double)SvNVX(sv));
    } else if (SvIOKp(sv)) {
        if(SvUOK(sv)) {
            PACK_UV(enc, SvUVX(sv));
        } else {
            PACK_IV(enc, SvIVX(sv));
        }
    } else if (SvROK(sv)) {
        _msgpack_pack_rv(aTHX_ enc, SvRV(sv), depth-1, utf8);
    } else if (!SvOK(sv)) {
        msgpack_pack_nil(enc);
    } else if (isGV(sv)) {
        Perl_croak(aTHX_ "msgpack cannot pack the GV\n");
    } else {
        sv_dump(sv);
        Perl_croak(aTHX_ "msgpack for perl doesn't supported this type: %d\n", SvTYPE(sv));
    }
}

STATIC_INLINE
void _msgpack_pack_he(pTHX_ enc_t* enc, HV* hv, HE* he, int depth, bool utf8) {
    _msgpack_pack_sv(aTHX_ enc, hv_iterkeysv(he),   depth, utf8);
    _msgpack_pack_sv(aTHX_ enc, hv_iterval(hv, he), depth, utf8);
}

STATIC_INLINE void _msgpack_pack_rv(pTHX_ enc_t *enc, SV* sv, int depth, bool utf8) {
    svtype svt;
    assert(sv);
    SvGETMAGIC(sv);
    svt = SvTYPE(sv);

    if (SvOBJECT (sv)) {
        HV *stash = gv_stashpv ("Data::MessagePack::Boolean", 1); // TODO: cache?
        if (SvSTASH (sv) == stash) {
            if (SvIV(sv)) {
                msgpack_pack_true(enc);
            } else {
                msgpack_pack_false(enc);
            }
        } else {
            HV *stash = gv_stashpv ("Types::Serialiser::Boolean", 1); // TODO: cache?
            if (stash && (SvSTASH (sv) == stash)) {
                if (SvIV(sv)) {
                    msgpack_pack_true(enc);
                } else {
                    msgpack_pack_false(enc);
                }
            } else {
                croak ("encountered object '%s', Data::MessagePack doesn't allow the object",
                            SvPV_nolen(sv_2mortal(newRV_inc(sv))));
            }
        }
    } else if (svt == SVt_PVHV) {
        HV* hval = (HV*)sv;
        int count = hv_iterinit(hval);
        HE* he;

	if (SvTIED_mg(sv,PERL_MAGIC_tied)) {
          count = 0;
          while (hv_iternext (hval))
            ++count;
          hv_iterinit (hval);
        }
        msgpack_pack_map(enc, count);

        if (enc->canonical) {
            AV* const keys = newAV();
            sv_2mortal((SV*)keys);
            av_extend(keys, count);

            while ((he = hv_iternext(hval))) {
                av_push(keys, SvREFCNT_inc(hv_iterkeysv(he)));
            }

            int const len = av_len(keys) + 1;
            sortsv(AvARRAY(keys), len, Perl_sv_cmp);

            int i;
            for (i=0; i<len; i++) {
                SV* sv = *av_fetch(keys, i, TRUE);
                he = hv_fetch_ent(hval, sv, FALSE, 0U);
                _msgpack_pack_he(aTHX_ enc, hval, he, depth, utf8);
            }
        } else {
            while ((he = hv_iternext(hval))) {
                _msgpack_pack_he(aTHX_ enc, hval, he, depth, utf8);
            }
        }
    } else if (svt == SVt_PVAV) {
        AV* ary = (AV*)sv;
        int len = av_len(ary) + 1;
        int i;
        msgpack_pack_array(enc, len);
        for (i=0; i<len; i++) {
            SV** svp = av_fetch(ary, i, 0);
            if (svp) {
                _msgpack_pack_sv(aTHX_ enc, *svp, depth, utf8);
            } else {
                msgpack_pack_nil(enc);
            }
        }
    } else if (svt < SVt_PVAV) {
        STRLEN len = 0;
        char *pv = svt ? SvPV (sv, len) : 0;

        if (len == 1 && *pv == '1')
            msgpack_pack_true(enc);
        else if (len == 1 && *pv == '0')
            msgpack_pack_false(enc);
        else {
            //sv_dump(sv);
            croak("cannot encode reference to scalar '%s' unless the scalar is 0 or 1",
                    SvPV_nolen (sv_2mortal (newRV_inc (sv))));
        }
    } else {
        croak ("encountered %s, but msgpack can only represent references to arrays or hashes",
                   SvPV_nolen (sv_2mortal (newRV_inc (sv))));
    }
}

XS(xs_pack) {
    dXSARGS;
    if (items < 2) {
        Perl_croak(aTHX_ "Usage: Data::MessagePack->pack($dat [,$max_depth])");
    }

    SV* self  = ST(0);
    SV* val   = ST(1);
    int depth = 512;
    bool utf8 = false;
    if (items >= 3) depth = SvIVx(ST(2));

    enc_t enc;
    enc.sv        = sv_2mortal(newSV(INIT_SIZE));
    enc.cur       = SvPVX(enc.sv);
    enc.end       = SvEND(enc.sv);
    SvPOK_only(enc.sv);

    // setup configuration
    dMY_CXT;
    enc.prefer_int = MY_CXT.prefer_int; // back compat
    if(SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV) {
        HV* const hv = (HV*)SvRV(self);
        SV** svp;

        svp = hv_fetchs(hv, "prefer_integer", FALSE);
        if(svp) {
            enc.prefer_int = SvTRUE(*svp) ? true : false;
        }

        svp = hv_fetchs(hv, "canonical", FALSE);
        if(svp) {
            enc.canonical = SvTRUE(*svp) ? true : false;
        }

        svp = hv_fetchs(hv, "utf8", FALSE);
        if (svp) {
            utf8 = SvTRUE(*svp) ? true : false;
        }
    }

    _msgpack_pack_sv(aTHX_ &enc, val, depth, utf8);

    SvCUR_set(enc.sv, enc.cur - SvPVX (enc.sv));
    *SvEND (enc.sv) = 0; /* many xs functions expect a trailing 0 for text strings */

    ST(0) = enc.sv;
    XSRETURN(1);
}
