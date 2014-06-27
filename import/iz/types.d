module iz.types;

import 
	core.exception, core.memory: GC;

import 
	std.stdio, std.c.stdlib,
	std.traits, std.typetuple, std.typecons;

/// iz pointer.
alias void* izPtr;

/// iz notification
alias void delegate(izObject aNotifier) izEvent;

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
	alias int myInt;
	assert( isConstantSize!myInt ); // OK
	//assert( isConstantSize!myClass ); // FAIL
}		


/**
 * This class allocator/deallocator is implemented in each super class.
 * Meaning that most of the IZ classes must be freed manually.
 */
mixin template setClassGcFree()
{
	new(size_t sz)
	{
		auto p = malloc(sz);
		if (!p) throw new OutOfMemoryError();
		return p;
	}
	delete(izPtr p)
	{
		if (p) free(p);
	}
}
///
unittest
{
	// myClass is GC-free
	class myClass{
		mixin setClassGcFree;
		// however some members may not.
		int[] someInts;
	}
}


/**
 * The most simple IZ object.
 * It should always be used as ancestor for a new class to match the IZ principles.
 */
class izObject
{
	mixin setClassGcFree;
	// note: this is meaningless in console-unit tests but verified in a real program
	// (the test also pass without injecting setClassGcFree because it seems dmd can allocate on the stack in UT mode ?).
	unittest
	{
		auto foo = new izObject;
		scope(exit) delete foo;
		assert( GC.addrOf(&foo) == null );
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

