module iz.types;

import std.c.stdlib;
import std.traits, std.meta;
    
/// pointer.
alias Ptr = void*;


/** 
 * FixedSizeTypes elements verify isBasicType().
 */
alias BasicTypes = AliasSeq!( 
    bool, byte, ubyte, short, ushort, int, uint, long, ulong, 
    float, double, real, 
    char, wchar, dchar
);

static unittest
{
    foreach(T; BasicTypes)
        assert( isBasicType!T, T.stringof);     
}

    
/**
 * Returns true if T is a fixed-length data.
 */
bool isFixedSize(T)()
{
    return (
        staticIndexOf!(T,BasicTypes) != -1) || 
        (is(T==struct) & (__traits(isPOD, T))
    );
}

unittest
{
    class Foo{}
    struct Bar{byte a,b,c,d,e,f;}
    alias myInt = int;
    assert(isFixedSize!myInt);
    assert(!isFixedSize!Foo);
    assert(isFixedSize!Bar);
}

