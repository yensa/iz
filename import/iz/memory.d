module iz.memory;

import std.traits, std.c.stdlib, std.c.string;
import iz.types;

/**
 * Like malloc() but for @safe context.
 */
@trusted @nogc Ptr getMem(size_t size) nothrow
{
    auto result = malloc(size);
    assert(result, "Out of memory");
    return result;
}

/**
 * Like realloc() but for @safe context.
 */
@trusted @nogc Ptr reallocMem(ref Ptr src, size_t newSize) nothrow
{
    auto result = realloc(src, newSize);
    assert(result, "Out of memory");
    return result;
}

/**
 * Like memmove() but for @safe context.
 * dst and src can overlap.
 * Params:
 * dst = the data source.
 * src = the data destination.
 * count = the count of byte to move from src to dst. 
 */
@trusted @nogc void moveMem(ref Ptr dst, ref Ptr src, size_t count) nothrow
{
    import std.c.string : memmove;
    dst = memmove(dst, src, count);
}

/**
 * Like memmove() but for @safe context.
 * dst and src can overlap.
 * Params:
 * dst = the data source.
 * src = the data destination.
 * count = the count of byte to meove from src to dst.
 * Returns:
 * the pointer to the destination, (same as dst). 
 */
@trusted @nogc Ptr moveMem(Ptr dst, Ptr src, size_t count) nothrow
{
    import std.c.string : memmove;
    return memmove(dst, src, count);
}

/**
 * Frees a manually allocated pointer to a basic type. 
 * Like free() but for @safe context.
 * Params:
 * src = the pointer to free.
 */
@trusted @nogc void freeMem(T)(ref T* src) nothrow
if (isPointer!(T*) && isBasicType!T)
{
    if (src) free(cast(void*)src);
    src = null;
}

/**  
 * The static function construct returns a new, GC-free, class instance.
 * Params:
 * CT = a class type.
 * a = variadic parameters passed to the constructor.
 */
@trusted CT construct(CT, A...)(A a) 
if (is(CT == class))
{
    version(none) {
        // based on D wiki
        import std.conv : emplace;
        auto size = __traits(classInstanceSize, CT);
        auto memory = getMem(size)[0 .. size];
        return emplace!(CT, A)(memory, a);
    } else {
        // based on D-Runtime - lifetime.d 
        auto memory = getMem(typeid(CT).init.length);
        memory[0 .. typeid(CT).init.length] = typeid(CT).init[];
        static if (__traits(hasMember, CT, "__ctor"))
            (cast(CT) (memory)).__ctor(a);    
        return cast(CT) memory;
    }
}

/**  
 * The static function construct returns a new, GC-free, pointer to a struct.
 * Params:
 * ST = a struct type.
 * a = variadic parameters passed to the constructor.
 */
@trusted ST * construct(ST, A...)(A a)
if(is(ST==struct) || is(ST==union))
{
    version(all) {
        import std.conv : emplace;
        auto size = ST.sizeof;
        auto memory = getMem(size)[0 .. size];
        return emplace!(ST, A)(memory, a);
    } else {
        assert(0, "this does not work");
        auto memory = getMem(ST.sizeof);
        memory[0 .. ST.sizeof] = typeid(ST).init[];
        static if (A.length &&  __traits(hasMember, ST, "__ctor"))
            (cast(ST*) (memory)).__ctor(a);    
        return cast(ST*) memory;
    }
}
       
/** 
 * Destructs or frees a class instance or a struct pointer 
 * previously constructed with construct().
 * Params:
 * T = a class type or a struct pointer type, likely to be infered by the *instance* parameter
 * instance = an instance of type *T*.
 */
void destruct(T)(ref T instance) 
if (is(T == class) || (isPointer!T && is(PointerTarget!T == struct))
    || (isPointer!T && is(PointerTarget!T == union)))
{
    if (!instance) return;
    destroy(instance);
    instance = null;
}   

/**
 * Returns a pointer to a new, GC-free, basic variable.
 * Any variable allocated using this function must be manually freed with freeMem.
 * Params:
 * T = the type of the pointer to return.
 * preFill = optional boolean indicating if the result has to be initialized.
 */
@trusted @nogc T * newPtr(T, bool preFill = false)() if (isBasicType!T)
{
    static if(!preFill)
        return cast(T*) getMem(T.sizeof);
    else
    {
        auto result = cast(T*) getMem(T.sizeof);
        *result = T.init;
        return result; 
    }
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
    import std.stdio, core.memory: GC;

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
    
    union Uni{bool b; ulong ul;}
    Uni * uni0 = construct!Uni();
    Uni * uni1 = new Uni();
    assert( GC.addrOf(cast(void*)uni0) == null );
    assert( GC.addrOf(cast(void*)uni1) != null );   
    uni0.destruct;
    uni1.destruct;   
    assert(!uni0);
    uni0.destruct;
    assert(!uni0);    

    writeln("construct/destruct passed the tests");
}

unittest
{
    import core.memory: GC;
    import std.stdio, std.math;
    
    auto f = newPtr!(float,true);
    assert(isNaN(*f));
    auto ui = newPtr!int;
    auto i = newPtr!uint;
    auto l = new ulong;
    
    assert(ui);
    assert(i);
    assert(f);
    
    assert(GC.addrOf(f) == null);
    assert(GC.addrOf(i) == null);
    assert(GC.addrOf(ui) == null);
    assert(GC.addrOf(l) != null);
    
    *i = 8u;
    assert(*i == 8u);
    
    freeMem(ui);
    freeMem(i);
    freeMem(f);
    
    assert(ui == null);
    assert(i == null);
    assert(f == null);
    
    auto ptr = getMem(16);
    assert(ptr);
    assert(GC.addrOf(ptr) == null);
    ptr.freeMem;
    assert(!ptr);
    
    
    writeln("newPtr passed the tests");  
}

