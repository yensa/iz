module iz.types;

import std.c.stdlib;
import std.traits, std.meta;
    
/// pointer.
alias Ptr = void*;


/** 
 * FixedSizeTypes represents all the value types.
 */
alias FixedSizeTypes = AliasSeq!( 
    bool, byte, ubyte, short, ushort, int, uint, long, ulong, 
    char, wchar, dchar, float, double
);

    
/**
 * Returns true if T is a fixed-length data.
 */
bool isFixedSize(T)()
{
    return (
        staticIndexOf!(T,FixedSizeTypes) != -1) || 
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

/**
 * Aliases the element type of an array
 * Params:
 * T = an array type
 */
template ArrayElementType(T)
if (isArray!T)
{
    alias ArrayElementType = typeof(T.init[0]); 
}

unittest
{
    alias A = uint[8];
    alias B = string[];
    assert(is(ArrayElementType!A == uint));
    assert(is(ArrayElementType!B == string)); 
    static assert(is(ArrayElementType!A == uint));
    static assert(is(ArrayElementType!B == string));        
}

