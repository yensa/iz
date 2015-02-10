module iz.types;

import core.exception, core.memory: GC;
import std.stdio, std.c.stdlib;
import std.traits, std.typetuple;
    
/// iz pointer.
alias izPtr = void*;


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
void reset(T)(ref T t)
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
CT construct(CT, A...)(A a) 
if (is(CT == class))
{
	import std.conv : emplace;
    auto size = __traits(classInstanceSize, CT);
	auto memory = malloc(size)[0 .. size];
	if(!memory) throw new Exception("Out of memory");
	return emplace!(CT, A)(memory, a);
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
 * Destructs or frees a class instance or a struct pointer 
 * previously constructed with construct().
 * Params:
 * T = a class type or a struct pointer type, likely to be infered by the *instance* parameter
 * instance = an instance of type *T*.
 */
static void destruct(T)(ref T instance) 
if (is(T == class) || (isPointer!T && is(PointerTarget!T == struct)))
{
    if (!instance) return;
	destroy(instance);
    instance = null;
}   

/** 
 * Frees and invalidates a list of classes instances or struct pointers. 
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
    
    struct Foo{size_t a,b,c;}
    Foo * foos = construct!Foo(1,2,3);
    Foo * bars = new Foo(4,5,6);
    assert(foos.a == 1);
    assert(foos.b == 2);
    assert(foos.c == 3);
    assert( GC.addrOf(cast(void*)foos) == null );
    assert( GC.addrOf(cast(void*)bars) != null );   
    foos.destruct;
    bars.destruct;   
    assert(!foos);
    foos.destruct;
    assert(!foos);

	writeln("construct/destruct passed the tests");
}
