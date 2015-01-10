module iz.types;

import 
	core.exception, core.memory: GC;

import 
	std.stdio, std.c.stdlib,
	std.traits, std.typetuple, std.typecons;
    
/// iz pointer.
alias izPtr = void*;

/// iz notification
alias izEvent = void delegate(izObject aNotifier);

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
		(staticIndexOf!(T,izConstantSizeTypes) != -1) | 
		( is(T==struct) && (__traits(isPOD, T)))
	);
}
///
unittest
{
	class myClass{}
	alias myInt = int;
	assert( isConstantSize!myInt ); // OK
	//assert( isConstantSize!myClass ); // FAIL
}


/// void version of the init type property.
@property void reset(T)(out T t)
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

T heapAllocate(T, Args...) (Args args)
if (is(T == class))
{
	import std.conv : emplace;
	auto size = __traits(classInstanceSize, T);
	auto memory = malloc(size)[0..size];
	if(!memory) throw new Exception("Out of memory");
	return emplace!(T, Args)(memory, args);
}

void heapDeallocate(T)(ref T obj)
if (is(T == class))
{
	destroy(obj);
	free(cast(void*)obj);
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
    version(none)
    {
        CT result = cast(CT) malloc(__traits(classInstanceSize, CT));
        if (!result) throw new Exception("Out of memory");
        
        static if (__traits(hasMember, CT, "__ctor"))
            return result.__ctor(a);
        else return result;
    }
    else return heapAllocate!CT(a);
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
    version(none)
    {
        static if (__traits(hasMember, CT, "__dtor"))
            instance.__dtor();
        free(cast(void*)instance);
        instance = null;
    }
    else heapDeallocate(instance);
    instance = null;
}   

/** 
 * Frees and invalidate a list of Object. 
 * *destruct()* is called for each item.
 * Params:
 * Objs = variadic list of Object instances.
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
}


/**
 * The most simple IZ object.
 * It should always be used as ancestor for a new class to match the IZ principles.
 */
class izObject
{
    /// default, forwarded, constructor.
    //this(){}
    
    /// ditto
    //this(A...)(A a){}
    
    /// default, forwarded, destructor.
    //~this(){}

    /// Example: creates an izObject, verifies that it's not managed and destructs it.
	unittest
	{
		izObject foo = construct!izObject;
        assert( GC.addrOf(cast(void*)foo) == null );
		scope(exit) foo.destruct;
		assert( GC.addrOf(cast(void*)foo) == null );

		writeln("izObject passed the tests");
	}
}

/**
 * Allocates some heap memory and creates a new T. 
 * Internally used to avoid stack-allocated objects.
 */
T izAllocObject(T,A...)(A a) if (is(T==class))
{
	T* p = cast(T*) malloc(T.sizeof);
	if (!p) throw new OutOfMemoryError();
	*p  = new T(a);
	return *p;
}

class OO: izObject
{
	int fa,fb;
	this(int a, int b){fa = a; fb = b;}
}
class OOTester
{
	unittest
	{
		auto o1 = izAllocObject!OO(1,2);
		auto o2 = izAllocObject!OO(3,4);
		
		assert(o1);
		assert(o2);
		
		delete o1;
		delete o2;
		
		writeln("izAllocObject passed the tests");
	}
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

