module iz.types;

import
    std.c.stdlib, std.traits, std.meta;
import
    iz.streams;

version(unittest) import std.stdio;

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
    _bool   = 0x01, _byte, _ubyte, _short, _ushort, _int, _uint, _long, _ulong,
    _float  = 0x10, _double, _real,
    _char   = 0x20, _wchar, _dchar,
    _object = 0x30,
    _stream = 0x38,
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
    /// Unqualified type
    RuntimeType type;
    /// As array
    bool array;
}

/**
 * Returns the argument RuntimeTypeInfo.
 */
auto runtimeTypeInfo(T)()
{
    enum array = isArray!T;
    RuntimeType type;
    
    static if (isArray!T) alias TT = Unqual!(typeof(T.init[0]));
    else alias TT = Unqual!T;

    with (RuntimeType)
    {
        static if (is(TT == bool)) type = _bool;
        else static if (is(TT == byte))  type = _byte;
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

        else static if (is(TT : Stream)) type = _stream;

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
    assert(b_rtti == runtimeTypeInfo!byte);
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
    import std.array: split;
    static if (assumeDemangled)
        return (cast(TypeInfo_Class)typeid(o)).name.split('.')[$-1];
    else
    {
        import std.demangle: demangle;
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

/**
 * Indicates if the member of a struct or class is accessible for compile time
 * introspection. The template has to be mixed in the scope where the other
 * __traits() operations are performed.
 * The problem solved by this mixin is that a simple function template that uses
 * __traits(getProtection) does not faithfully represent the member accessibility
 * if the function is declared in another module.
 * Another problem is that __traits(getProtection) does not well represent the
 * accessibility of the private members (own members or friend classes /structs).
 */
mixin template ScopedReachability()
{
    bool isMemberReachable(T, string member)()
    if (is(T==class) || is(T==struct))
    {
        return __traits(compiles, __traits(getMember, T, member));
    }
}

/**
 * Detects whether type $(D T) is a multi dimensional array.
 * Params:
 *      T = type to be tested
 *
 * Returns:
 *      true if T is a multi dimensional array
 */
template isMultiDimensionalArray(T)
{
    static if (!isArray!T)
        enum isMultiDimensionalArray = false;
    else
    {
        import std.range.primitives: hasLength;
        alias DT = typeof(T.init[0]);
        enum isMultiDimensionalArray = hasLength!DT || isNarrowString!DT;
    }
}
///
unittest
{
    static assert(isMultiDimensionalArray!(string[]) );
    static assert(isMultiDimensionalArray!(int[][]) );
    static assert(!isMultiDimensionalArray!(int[]) );
    static assert(!isMultiDimensionalArray!(int) );
    static assert(!isMultiDimensionalArray!(string) );
    static assert(!isMultiDimensionalArray!(int[][] function()) );
    static assert(!isMultiDimensionalArray!void);
}

/**
 * Returns the dimension count of a $(D array).
 */
template dimensionCount(T)
if (isArray!T)
{
    static if (isMultiDimensionalArray!T)
    {
        alias DT = typeof(T.init[0]);
        enum dimensionCount = dimensionCount!DT + 1;
    }
    else enum dimensionCount = 1;
}
///
unittest
{
    static assert(dimensionCount!(int[]) == 1);
    static assert(dimensionCount!(int[][]) == 2);
    static assert(dimensionCount!(int[][][]) == 3);
}

