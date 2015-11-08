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

/// Describes the unit of a mask.
enum MaskKind {Byte, Nibble, Bit}

/**
 * Mask, at compile-time, a byte, a nibble or a bit in the argument.
 *
 * Params:
 * index = the position, 0-based, of the element to mask.
 * kind = the kind of the element to mask.
 * value = the value mask.
 *
 * Returns:
 * The input argument with the element masked.
 */
auto mask(size_t index, MaskKind kind = MaskKind.Byte, T)(const T value) nothrow
if (    (kind == MaskKind.Byte && index <= T.sizeof)
    ||  (kind == MaskKind.Nibble && index <= T.sizeof * 2)
    ||  (kind == MaskKind.Bit && index <= T.sizeof * 8))
{
    import std.typecons;
    T _mask;
    static if (kind == MaskKind.Byte)
    {
        _mask = T.min - 1 - (0xFF << index * 8); 
    }
    else static if (kind == MaskKind.Nibble)
    {
        _mask = T.min - 1 - (0xF << index * 4);                           
    }
    else static if (kind == MaskKind.Bit)
    {
        _mask = T.min - 1 - (0x1 << index);            
    }    
    return value & _mask;
}

/// Compile-time mask() partially specialized for nibble-masking.
auto maskNibble(size_t index, T)(const T value) nothrow
{
    // note: aliasing prevents template parameter type deduction,
    // e.g alias maskNibble(size_t index, T) = mask!(index, MaskKind.Nibble, T);
    return mask!(index, MaskKind.Nibble)(value);
}

/// Compile-time mask() partially specialized for bit-masking.
auto maskBit(size_t index, T)(const T value) nothrow
{
    return mask!(index, MaskKind.Bit)(value);
}

/**
 * Mask, at run-time, a byte, a nibble or a bit in the argument.
 *
 * Params:
 * index = the position, 0-based, of the element to mask.
 * kind = the kind of the element to mask.
 * value = the value mask.
 *
 * Returns:
 * The input argument with the element masked.
 */
auto mask(MaskKind kind = MaskKind.Byte, T)(const T value, size_t index) nothrow
{
    static immutable byteMasker = 
    [
        0xFFFFFFFFFFFFFF00,
        0xFFFFFFFFFFFF00FF,
        0xFFFFFFFFFF00FFFF,
        0xFFFFFFFF00FFFFFF,
        0xFFFFFF00FFFFFFFF,
        0xFFFF00FFFFFFFFFF,
        0xFF00FFFFFFFFFFFF,
        0x00FFFFFFFFFFFFFF 
    ];
    
    static immutable nibbleMasker = 
    [
        0xFFFFFFFFFFFFFFF0,
        0xFFFFFFFFFFFFFF0F,
        0xFFFFFFFFFFFFF0FF,
        0xFFFFFFFFFFFF0FFF,
        0xFFFFFFFFFFF0FFFF,
        0xFFFFFFFFFF0FFFFF,
        0xFFFFFFFFF0FFFFFF,
        0xFFFFFFFF0FFFFFFF,
        0xFFFFFFF0FFFFFFFF,
        0xFFFFFF0FFFFFFFFF,
        0xFFFFF0FFFFFFFFFF,
        0xFFFF0FFFFFFFFFFF,
        0xFFF0FFFFFFFFFFFF,
        0xFF0FFFFFFFFFFFFF,
        0xF0FFFFFFFFFFFFFF,
        0x0FFFFFFFFFFFFFFF 
    ];
    static if (kind == MaskKind.Byte)
        return value & byteMasker[index];
    else static if (kind == MaskKind.Nibble)
        return value & nibbleMasker[index];
    else
        return value & (0xFFFFFFFFFFFFFFFF - (1UL << index));
}

/*
First version: less byte code but more latency do to memory access
This version: no memory access but equivalent latency due to more byte code.
auto mask(MaskKind kind = MaskKind.Byte, T)(const T value, size_t index) nothrow
{
    static immutable T _max = - 1; 
    static if (kind == MaskKind.Byte)
        return value & (_max - (0xFF << index * 8));
    else static if (kind == MaskKind.Nibble)
        return value & (_max - (0xF << index * 4));
    else
        return value & (_max - (0x1 << index));
}
*/

/// Run-time mask() partially specialized for nibble-masking.
auto maskNibble(T)(const T value, size_t index) nothrow
{
    return mask!(MaskKind.Nibble)(value, index);
}

/// Run-time mask() partially specialized for bit-masking.
auto maskBit(T)(const T value, size_t index) nothrow
{
    return mask!(MaskKind.Bit)(value, index);
}

unittest
{
    enum v0 = 0x44332211;
    static assert( mask!0(v0) == 0x44332200);
    static assert( mask!1(v0) == 0x44330011);  
    static assert( mask!2(v0) == 0x44002211);
    static assert( mask!3(v0) == 0x00332211);
    
    assert( mask(v0,0) == 0x44332200);
    assert( mask(v0,1) == 0x44330011);  
    assert( mask(v0,2) == 0x44002211);
    assert( mask(v0,3) == 0x00332211);    
    
    enum v1 = 0x87654321;
    static assert( mask!(0, MaskKind.Nibble)(v1) == 0x87654320);
    static assert( mask!(1, MaskKind.Nibble)(v1) == 0x87654301);
    static assert( mask!(2, MaskKind.Nibble)(v1) == 0x87654021); 
    static assert( mask!(3, MaskKind.Nibble)(v1) == 0x87650321);
    static assert( mask!(7, MaskKind.Nibble)(v1) == 0x07654321);
    
    assert( mask!(MaskKind.Nibble)(v1,0) == 0x87654320);
    assert( mask!(MaskKind.Nibble)(v1,1) == 0x87654301);
    assert( mask!(MaskKind.Nibble)(v1,2) == 0x87654021); 
    assert( mask!(MaskKind.Nibble)(v1,3) == 0x87650321);
    assert( mask!(MaskKind.Nibble)(v1,7) == 0x07654321);     
    
    enum v2 = 0b11111111;
    static assert( mask!(0, MaskKind.Bit)(v2) == 0b11111110);
    static assert( mask!(1, MaskKind.Bit)(v2) == 0b11111101);
    static assert( mask!(7, MaskKind.Bit)(v2) == 0b01111111);  
    
    assert( maskBit(v2,0) == 0b11111110);
    assert( maskBit(v2,1) == 0b11111101);
    assert( mask!(MaskKind.Bit)(v2,7) == 0b01111111);       
}

/**
 * Alternative to std.range primitives for arrays.
 *
 * The source is never consumed. 
 * The range always verifies isInputRange and isForwardRange. When the source
 * array element type if not a character type or if the template parameter 
 * assumeDecoded is set to true then the range also verifies
 * isForwardRange.
 *
 * When the source is an array of character and if assumeDecoded is set to false 
 * then the ArrayRange front type is always dchar because of the UTF decoding.
 */
struct ArrayRange(T, bool assumeDecoded = false)
{
    static if (!isSomeChar!T || assumeDecoded || is(T==dchar))
    {
        private T* _front, _back;    
        ///
        this(ref T[] stuff) 
        {
            _front = stuff.ptr; 
            _back = _front + stuff.length - 1;
        }      
        ///
        @property bool empty()
        {
            return _front > _back;
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
        /// returns a slice of the source, according to front and back.
        T[] array()
        {
            return _front[0 .. _back - _front + 1];
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
    else
    {
    
    private: 
    
        import std.utf: decode;
        size_t _position, _previous, _len;
        dchar _decoded;
        T* _front;
        bool _decode;
        
        void readNext()
        {
            _previous = _position;
            auto str = _front[0 .. _len];
            _decoded = decode(str, _position);
        }
        
    public:
    
        ///
        this(ref T[] stuff) 
        { 
            _front = stuff.ptr;
            _len = stuff.length;
            _decode = true;
        }     
        ///
        @property bool empty()
        {
            return _position >= _len;
        } 
        ///
        dchar front()
        {
            if (_decode)
            {
                _decode = false;
                readNext;
            }
            return _decoded;
        }       
        ///
        void popFront()
        {
            if (_decode) readNext;
            _decode = true;
        }
        /// returns a slice of the source, according to front and back.
        T[] array()
        {
            return _front[_previous .. _len];
        }   
        ///
        typeof(this) save()
        {
            typeof(this) result;
            result._position   = _position;
            result._previous   = _previous;
            result._len        = _len;
            result._decoded    = _decoded; 
            result._front      = _front;
            result._decode     = _decode;  
            return result;
        }              
    }
}

unittest
{
    auto arr = "bla";
    auto rng = ArrayRange!(immutable(char))(arr);
    assert(rng.array == "bla", rng.array);
    assert(rng.front == 'b');
    rng.popFront;
    assert(rng.front == 'l');
    rng.popFront;
    assert(rng.front == 'a');
    rng.popFront;
    assert(rng.empty);   
    assert(arr == "bla");  
    //    
    auto t1 = "é_é";
    auto r1 = ArrayRange!(immutable(char))(t1);
    auto r2 = r1.save;
    foreach(i; 0 .. 3) r1.popFront;
    assert(r1.empty);
    r1 = r2;
    assert(r1.front == 'é');  
    //
    auto r3 = ArrayRange!(immutable(char),true)(t1);
    foreach(i; 0 .. 5) r3.popFront;
    assert(r3.empty);   
}

unittest
{
    ubyte[] src = [1,2,3,4,5];
    ubyte[] arr = src.dup;
    auto rng = ArrayRange!ubyte(arr);
    ubyte cnt = 1;
    while (!rng.empty)
    {
        assert(rng.front == cnt++);
        rng.popFront;
    }
    assert(arr == src);   
}

/**
 * Calls a function according to a probability
 *
 * Params:
 * t = The chance to call, in percentage.
 * fun = The function to call. It must be a void function.
 * a = The variadic argument passed to fun.
 */
void pickAndCall(T, Fun, A...)(T t, Fun fun, auto ref A a) @safe
if (isNumeric!T && isCallable!Fun && is(ReturnType!Fun == void))
in
{
    static immutable string err = "chance to pick must be in the 0..100 range";
    assert(t <= 100, err);
    assert(t >= 0, err);
}
body
{
    import std.random: uniform;
    static immutable T min = 0;
    static immutable T max = 100;
    if (uniform!"[]"(min, max) > max - t)
        fun(a);
}

@safe unittest
{
    uint cnt;
    bool test;
    void foo(uint param0, out bool param1) @safe
    {
        cnt += param0;
        param1 = true;
    }
    foreach(immutable i; 0 .. 100)
        pickAndCall!(double)(75.0, &foo, 1, test);
    assert(cnt > 25);
    assert(test);
    cnt = 0;
    test = false;
    foreach(immutable i; 0 .. 100)
        pickAndCall!(byte)(0, &foo, 1, test);
    assert(cnt == 0);
    assert(!test);    
}

