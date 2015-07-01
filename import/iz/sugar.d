module iz.sugar;

import std.traits;
import std.typetuple;

static private bool asB(T)()
{
    return (isIntegral!T || is(T==bool) || is(T==void*));
}

/**
 * Bitwise not.
 */
bool not(T)(T t) @safe @nogc nothrow pure
if (asB!T)
{
    return !t;
}

unittest
{
    void * ptr = null;
    assert( not(true) == false);
    assert( not(false) == true);
    assert( not(1) == 0);
    assert( not(0) == 1);
    assert( not(123456) == 0);
    assert( not(ptr) == true);
    assert( 1.not == false);
    assert( ((1+2)/3).not == false);
    assert( 0.not );
    assert( !1.not );
    assert( 0.not.not.not );
    assert( !0.not.not.not.not );
}

/**
 * boolean and.
 */
bool band(T1, T2)(T1 t1 ,T2 t2) @safe @nogc nothrow pure
if (asB!T1 && asB!T2)
{
    return cast(bool)t1 & cast(bool)t2;
}

unittest
{
    assert( true.band(true));
    assert( !false.band(false));
    assert((1).band(2).band(3).band(4));
    assert(!(0).band(1).band(2).band(3));
}

/**
 * boolean or.
 */
bool bor(T1, T2)(T1 t1 ,T2 t2) @safe @nogc nothrow pure
if (asB!T1 && asB!T2)
{
    return cast(bool)t1 | cast(bool)t2;
}

unittest
{
    void * ptr = null;
    assert( true.bor(false));
    assert( !false.bor(false));
    assert((1).bor(2).bor(3).bor(4));
    assert((0).bor(1).bor(2).bor(3));
    assert(!(0).bor(false).bor(ptr));
}

/**
 * Allows forbidden casts
 */
auto bruteCast(OT, IT)(auto ref IT it) @nogc nothrow pure
{
    return * cast(OT*) &it;
}

unittest
{
    size_t i;
    char[] s = "123".dup;
    // expected behaviour
    assert(!__traits(compiles, i = cast(size_t) s));
    // screwed up cast
    assert(__traits(compiles, i = bruteCast!size_t(s)));
    // the expected result is only the .length part of the struct Array{size_t length; void ptr;}
    assert(bruteCast!size_t(s) == 3);
}

enum ProtKind
{
    none = 0,
    againstNull = 1,
    againstNan  = 0x10,
    againstNeg  = 0x100,
    againstPos  = 0x1000,
    againstZero = 0x10000,
}

template protectedCall(alias Fun, ProtKind p)
if (isCallable!Fun && cast(size_t)p > 0)
{
    import std.typecons: Tuple, tuple;
    
    // does the function have a return ?
    alias R = ReturnType!Fun;
    enum hasRet = !(is(R == void));
     
    auto protectedCall(Args...)(Args args)
    {
        // the value returned when a the protection happens
        enum ret = 
        q{
            static if (hasRet)
                return tuple!(bool, R)(false, R.init);
            else
                return false;
        };
           
        // checks the parameters  
        foreach(arg; args)
        {
            alias T = typeof(arg);
            
            static if (isNumeric!T)
            {
                static if ((p & ProtKind.againstZero) >= ProtKind.againstZero)
                    if (arg == 0) 
                        mixin(ret);          
                static if (isSigned!T)
                { 
                    static if ((p & ProtKind.againstNeg) >= ProtKind.againstNeg)
                        if (arg < 0) 
                            mixin(ret);
                    static if ((p & ProtKind.againstPos) >= ProtKind.againstPos)
                        if (arg > 0) 
                            mixin(ret);
                } 
                static if (isFloatingPoint!T)
                {
                    import std.math: isNaN;
                    static if ((p & ProtKind.againstNan) >= ProtKind.againstNan)
                        if (arg.isNaN) 
                            mixin(ret);
                }
            }
            static if (isPointer!T || is(T==class))
                static if ((p & ProtKind.againstNull) >= ProtKind.againstNull)
                    if (arg is null) 
                        mixin(ret);
        }
        // the function call
        static if (hasRet)
            return tuple!(bool, R)(true, Fun(args));
        else 
        {
            Fun(args);
            return true;
        }
    }
} 



unittest
{    
    import std.typecons: tuple;
    
    import std.functional : reverseArgs;

    void foo(Object a, Object b){}
    enum p0 = ProtKind.againstNull;
    
    Object a = null;
    Object b = null;
    assert(protectedCall!(foo, p0)(a, b) == false);
    a = new Object;
    b = new Object;
    assert(protectedCall!(foo, p0)(a, b) == true);

    auto bar(int a, int b){return a /b;}
    enum p1 = ProtKind.againstZero;
    
    assert(protectedCall!(bar, p1)(1, 0)[0] == false);
    assert(protectedCall!(bar, p1)(1, 1) == tuple(true,1));
    
    import std.stdio;
    auto res = protectedCall!(bar, p1)(6, 2);
    if (res[0])
    {
        writeln(res[1]);
    }
}

template BeSafe(alias Fun)
if (isCallable!Fun)
{
    auto BeSafe(A...)(A a) @trusted
    {
        return Fun(a);
    }
}

void baz(){import std.stdio; writeln();}

unittest
{
    

    @safe foo()
    {
        BeSafe!(baz);   
    }
    
    /*
    @safe bar()
    {
        baz();   
    }
    */
    
    
    foo; 
    //bar;

}

