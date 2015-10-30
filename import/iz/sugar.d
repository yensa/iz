module iz.sugar;

import std.traits;
import std.typetuple;

/// void version of the init() type function.
@trusted void reset(T)(ref T t) 
{
    t = T.init;
}

unittest
{
    uint a = 159;
    string b = "bla";
    a.reset;
    assert(a == typeof(a).init);
    b.reset;
    assert(b == typeof(b).init);
}

private bool asB(T)()
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

/**
 * Alternative to std.range primitives for arrays.
 * The source is never consumed.
 */
struct ArrayRange(T)
{
    private T* _front, _back;

    ///
    this(ref T[] stuff) 
    {
        _front = stuff.ptr; 
        _back = _front + stuff.length;
    } 
    
    ///
    this(ref typeof(this) rng)
    {
        _front = rng._front; 
        _back = rng._back;        
    }
    
    ///
    @property bool empty()
    {
        return _front >= _back;
    }  
    
    ///
    T front()
    {
        return *_front;
    }  
    
    ///
    T back()
    {
        return *_back;
    }    
    
    ///
    void popFront()
    { 
        ++_front;
    }
    
    ///
    void popBack()
    {
        --_back;
    }
    
    /// returns a slice of th source, according to front and back.
    T[] array()
    {
        return _front[0 .. _back - _front];
    }
    
    ///
    typeof(this) save() 
    {
        typeof(this) result;
        result._front = _front;
        result._back = _back;
        return result; 
    }  
}

unittest
{
    auto arr = "bla";
    auto rng = ArrayRange!(immutable(char))(arr);
    assert(rng.front == 'b');
    rng.popFront;
    assert(rng.front == 'l');
    rng.popFront;
    assert(rng.front == 'a');
    rng.popFront;
    assert(rng.empty);   
    assert(arr == "bla");     
}

