module iz.types;

import 
	core.exception, core.memory: GC;

import 
	std.stdio, std.c.stdlib,
	std.traits, std.typetuple, std.typecons;
    
/// iz pointer.
alias izPtr = void*;

/// iz notification
alias izEvent = void delegate(Object aNotifier);

/** 
 * izfixedLenTypes represents all the fixed-length types, directly representing a data.
 */
alias izConstantSizeTypes = TypeTuple!(	
	bool, byte, ubyte, short, ushort, int, uint, long, ulong, 
	char, wchar, dchar, float, double);

	
/**
 * Returns true if T is a fixed-length data.
 */
static bool isConstantSize(T)()
{
	return (
	    staticIndexOf!(T,izConstantSizeTypes) != -1) || 
		(is(T==struct) & (__traits(isPOD, T))
	);
}
///
unittest
{
	class Foo{}
    struct Bar{byte a,b,c,d,e,f;}
	alias myInt = int;
	assert(isConstantSize!myInt);
	assert(!isConstantSize!Foo);
    assert(isConstantSize!Bar);
}


/// void version of the init type property.
@property void reset(T)(ref T t)
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

/**  
 * The static function construct returns a new, GC-free, class instance.
 * Params:
 * CT = a class type.
 * a = variadic parameters passed to the constructor.
 */
static CT construct(CT, A...)(A a) 
if (is(CT == class))
{
	import std.conv : emplace;
    auto size = __traits(classInstanceSize, CT);
	auto memory = malloc(size)[0 .. size];
	if(!memory) throw new Exception("Out of memory");
	return emplace!(CT, A)(memory, a);
}
       
/** 
 * The static function destruct frees and invalidate a class instance.
 * Params:
 * CT = a class type, likely to be infered by the *instance* parameter
 * instance = an instance of type *CT*.
 */
static void destruct(CT)(ref CT instance) 
if (is(CT == class))
{
    if (!instance) return;
	destroy(instance);
	free(cast(void*)instance);
    instance = null;
}   

/** 
 * Frees and invalidates a list of Object. 
 * *destruct()* is called for each item.
 * Params:
 * objs = variadic list of Object instances.
 */
static void destruct(Objs...)(ref Objs objs)
{
    foreach(ref obj; objs)
        obj.destruct;
} 

unittest
{
    auto a = construct!Object;
    a.destruct;
    assert(!a);
    a.destruct;
    assert(!a);
    a.destruct;

    auto b = construct!Object;
    auto c = construct!Object;
    destruct(a,b,c);
    assert(!a);
    assert(!b);
    assert(!c);
    destruct(a,b,c);
    assert(!a);
    assert(!b);
    assert(!c);

	Object foo = construct!Object;
    Object bar = new Object;
    assert( GC.addrOf(cast(void*)foo) == null );
    assert( GC.addrOf(cast(void*)bar) != null );
	foo.destruct;
    bar.destruct;

	writeln("izObject passed the tests");    
    
}

/**  
 * The static function construct returns a new, GC-free, pointer to a struct.
 * Params:
 * ST = a struct type.
 * a = variadic parameters passed to the constructor.
 */
ST * construct(ST, A...)(A a)
if(is(ST==struct))
{
	import std.conv : emplace;
    auto size = ST.sizeof;
	auto memory = malloc(size)[0 .. size];
	if(!memory) throw new Exception("Out of memory");
	return emplace!(ST, A)(memory, a);
}

/** 
 * The static function destruct frees the memory allocated for a struct.
 * Params:
 * ST = a struct type, likely to be infered by the *instance* parameter
 * instance = an instance of type *CT*.
 */
static void destruct(ST)(ref ST * instance) 
if (is(ST == struct))
{
    if (!instance) return;
	free(instance);
    instance = null;
}   

/** 
 * Frees a list of struct. 
 * _destruct()_ is called for each item.
 * Params:
 * structs = variadic list of struct pointers.
 */
static void deallocate(Structs...)(ref Structs structs)
{
    foreach(ref s; structs)
        s.destruct;
} 

unittest
{
    struct Foo{size_t a,b,c;}
    Foo * foo = construct!Foo(1,2,3);
    Foo * bar = new Foo(4,5,6);
    assert(foo.a == 1);
    assert(foo.b == 2);
    assert(foo.c == 3);
    assert( GC.addrOf(cast(void*)foo) == null );
    assert( GC.addrOf(cast(void*)bar) != null );   
    foo.destruct;
    bar.destruct;   
}

/**
 * Helper struct for reading data as ubyte array.
 */
struct ubyteArray
{
    private
    {
        izPtr fMemory;
        size_t fSize;
    }
    public
    {
        @disable this();

        this(izPtr someData, size_t aSize)
        {
            fMemory = someData;
            fSize = aSize;
        }

        const(ubyte) opIndex(size_t index)
        {
            return *cast(ubyte*) (fMemory + index);
        }

        void opIndexAssign(ubyte aValue, size_t index)
        {
            *cast(ubyte*) (fMemory + index) = aValue;
        }

        int opApply(int delegate(ubyte aValue) dg)
        {
            int result = 0;
			for (auto i = 0; i < fSize; i++)
			{
				result = dg(*cast(ubyte*)(fMemory + i));
				if (result) break;
			}
			return result;
        }

        int opApplyReverse(int delegate(ubyte aValue) dg)
        {
            int result = 0;
			for (ptrdiff_t i = fSize-1; i >= 0; i--)
			{
				result = dg(*cast(ubyte*)(fMemory + i));
				if (result) break;
			}
			return result;
        }

        const(size_t) opDollar()
        {
            return fSize;
        }

        @property const kength()
        {
            return fSize;
        }
    }
    unittest
    {
        auto a = "Sundy's rock".dup;

        auto r0 = ubyteArray( a.ptr, a.length);

        assert(r0[0] == 'S');
        assert(r0[$-1] == 'k');
        auto r1 = getubyteArray(a);
        assert(r1[0] == 'S');
        assert(r1[$-1] == 'k');

        writeln("ubyteArray passed the tests");
    }
}

ubyteArray getubyteArray(T)(T t) if (isArray!T)
{
    return ubyteArray(cast(izPtr) t.ptr, t.length);
}

