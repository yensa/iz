module iz.types;

import std.c.stdlib;
import std.traits, std.meta;
    
/// pointer.
alias Ptr = void*;


/** 
 * BasicTypes elements verify isBasicType().
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

/// Common type for all the delagate kinds, when seen as a struct (ptr & funcptr).
alias GenericDelegate = void delegate();

/// Common type for all the function kinds.
alias GenericFunction = void function();

/// Enumerates the values a RuntimeTypeInfo.type can have.
enum RuntimeType : ubyte
{
    _void   = 0,
    _byte   = 0x01, _ubyte, _short, _ushort, _int, _uint, _long, _ulong,
    _float  = 0x10, _double, _real,
    _char   = 0x20, _wchar, _dchar,
    _object = 0x30,
    _struct = 0x40,
    _delegate = 0x50, _function,
}

/**
 * A variable can be associated to its RuntimeTypeInfo
 * to get its type information at runtime.
 *
 * A pointer to an instance should always be private
 * and exposed as const(RuntimeTypeInfo*) */
 /* because A particular requirement in PropDescriptor prevents to set the members as
 * immutable (no default this in struct + declaration without ctor + later call to define) = ouch
 */
struct RuntimeTypeInfo
{
    RuntimeType type;
    bool array;
}

/**
 * Returns the argument RuntimeTypeInfo.
 */
auto runtimeTypeInfo(T)()
{
    bool array = isArray!T;
    RuntimeType type;
    
    static if (isArray!T) alias TT = typeof(T.init[0]);
    else alias TT = T;
    
    with (RuntimeType)
    {
        static if (is(TT == byte)) type = _byte;
        else static if (is(TT == ubyte)) type = _ubyte; 
        else static if (is(TT == short)) type = _short;
        else static if (is(TT == ushort))type = _ushort;
        else static if (is(TT == int))   type = _int;
        else static if (is(TT == uint))  type = _uint;
        else static if (is(TT == long))  type = _long;
        else static if (is(TT == ulong)) type = _ulong;
        
        else static if (is(TT == float)) type = _float;
        else static if (is(TT == double))type = _double;
        else static if (is(TT == real))  type = _real;
        
        else static if (is(TT == char))  type = _char;
        else static if (is(TT == wchar)) type = _wchar;
        else static if (is(TT == dchar)) type = _dchar;
        
        else static if (is(TT == class)) type = _object;
        else static if (is(TT == struct))type = _struct;

        else static if (is(TT == delegate))type = _delegate;
        else static if (is(TT == function))type = _function;
    }     
    return RuntimeTypeInfo(type, array);   
}

///ditto
auto runtimeTypeInfo(T)(T t)
{
    return runtimeTypeInfo!T;
}

unittest
{
    byte b;
    RuntimeTypeInfo b_rtti = runtimeTypeInfo(b);
    assert(!b_rtti.array);
    assert(b_rtti.type == RuntimeType._byte);
    char[] c;
    RuntimeTypeInfo c_rtti = runtimeTypeInfo(c);
    assert(c_rtti.array);
    assert(c_rtti.type == RuntimeType._char);
}

/**
 * Returns the dynamic class name of an Object or an interface.
 * Params:
 * assumeDemangled = must only be set to false if the class is declared in a unittest.
 * t = either an interface or a class instance.
 */
string className(bool assumeDemangled = true, T)(T t)
if (is(T == class) || is(T == interface))
{
    static if (is(T == class)) Object o = t;
    else Object o = cast(Object) t;
    import std.array;
    static if (assumeDemangled)
        return (cast(TypeInfo_Class)typeid(o)).name.split('.')[$-1];
    else
    {
        import std.demangle;
        return (cast(TypeInfo_Class)typeid(o)).name.demangle.split('.')[$-1];       
    }    
}

version(unittest)
{
    interface I {}
    class A{}
    class B: I{}
    unittest
    {
        class C{}
        assert(className(new A) == "A");
        assert(className(new B) == "B");
        assert(className(cast(Object)new A) == "A");
        assert(className(cast(Object)new B) == "B");
        assert(className(cast(I) new B) == "B");
        assert(className!(false)(new C) == "C");
    }
}
