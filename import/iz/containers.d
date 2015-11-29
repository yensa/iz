/**
 * Several implementations of standard containers.
 */
module iz.containers;

import
    core.exception, core.stdc.string;
import
    std.exception, std.string, std.traits, std.conv;
import
    iz.memory, iz.types, iz.streams;

version(unittest) import std.stdio;

version(X86_64) 
    version(linux) version = Nux64;

/**
 * Parameterized, GC-free array.
 *
 * Array(T) implements a single-dimension array of uncollected memory.
 * It internally preallocates the memory to minimize the reallocation fingerprints.
 *
 * Its layout differs from built-in D's dynamic arrays and they cannot be cast as T[]
 * however, most of the slicing operations are possible.
 *
 * TODO:
 * - concatenation.
 * - assign from built-in arrays slices.
 */
struct Array(T)
{
    private
    {
        size_t _length;
        Ptr _elems;
        uint _granularity;
        size_t _blockCount;
        bool initDone;

        final void initLazy() @safe @nogc
        {
            if (initDone)
                return;
            _granularity = 4096;
            _elems = getMem(_granularity);
            initDone = true;
        }

        void setLength(size_t value) @nogc
        {
            debug { assert (_granularity != 0); }

            const size_t newBlockCount = ((value * T.sizeof) / _granularity) + 1;
            if (_blockCount != newBlockCount)
            {
                _blockCount = newBlockCount;
                _elems = cast(T*) reallocMem(_elems, _granularity * _blockCount);
            }
            _length = value;
        }
    }
    protected
    {
        void grow() @nogc
        {
            initLazy;
            setLength(_length + 1);
        }
        void shrink() @nogc
        {
            setLength(_length - 1);
        }
        T* rwPtr(size_t index) @nogc
        {
            return cast(T*) (_elems + index * T.sizeof);
        }
    }
    public
    {
        ///
        this(A...)(A elements) @nogc
        if (elements.length < ptrdiff_t.max-1)
        {
            initLazy;
            setLength(elements.length);
            foreach(i, T elem; elements)
                *rwPtr(i) = elem;
        }
        ///
        this(T[] elements) @nogc
        {
            if (elements.length == 0) return;

            initLazy;
            setLength(elements.length);

            foreach (i, element; elements)
                *rwPtr(i) = element;
        }
        static if (__traits(compiles, to!T(string.init)))
        {
            ///
            this(string representation)
            {
                initLazy;
                setLength(0);

                class RepresentationException: Exception
                {
                    this()
                    {
                        super("invalid array representation");
                    }
                }

                auto fmtRep = strip(representation);

                if (((fmtRep[0] != '[') & (fmtRep[$-1] != ']')) | (fmtRep.length < 2))
                    throw new RepresentationException;

                if (fmtRep == "[]") return;

                size_t i = 1;
                size_t _from = 1;
                while(i != fmtRep.length)
                {
                    if ((fmtRep[i] ==  ']') | (fmtRep[i] ==  ','))
                    {
                        auto valStr = fmtRep[_from..i];
                        if (valStr == "") throw new RepresentationException;
                        try
                        {
                            T _val = to!T(valStr);
                            grow;
                            *rwPtr(_length-1) = _val;
                        }
                        catch
                            throw new RepresentationException;

                        _from = i;
                        _from++;
                    }
                    ++i;
                }
            }
        }
        ~this()
        {
            if (_elems)
                freeMem(_elems);
        }
        /**
         * Indicates the memory allocation block-size.
         */
        uint granurality() @nogc
        {
            return _granularity;
        }
        /**
         * Sets the memory allocation block-size.
         * value should be set to 16 or 4096 (the default).
         */
        void granularity(uint value) @nogc
        {
            if (_granularity == value) return;
            if (value < T.sizeof)
            {
                value = 16 * T.sizeof;
            }
            else if (value < 16)
            {
                value = 16;
            }
            else while (_granularity % 16 != 0)
            {
                value--;
            }
            _granularity = value;
            setLength(_length);
        }
        /**
         * Indicates how many block the array is made of.
         */
        size_t blockCount() @nogc
        {
            return _blockCount;
        }
        /**
         * Element count.
         */
        size_t length() @nogc
        {
            return _length;
        }
        /// ditto
        void length(size_t value) @nogc
        {
            if (value == _length) return;
            initLazy;
            setLength(value);
        }
        /**
         * Pointer to the first element.
         * As it's always assigned It cannot be used to determine if the array is empty.
         */
        Ptr ptr() @nogc
        {
            return _elems;
        }
        /**
         * Returns the string representation of the elements.
         */
        string toString()
        {
            if (_length == 0) return "[]";
            string result =  "[";
            foreach (immutable i; 0 .. _length-1)
            {
                result ~= format("%s, ", *rwPtr(i));
            }
            return result ~= format("%s]",*rwPtr(_length-1));
        }
        /**
         *  Returns a mutable copy of the array.
         */
        Array!T dup() @nogc
        {
            Array!T result;
            result.length = _length;
            moveMem(result._elems, _elems, _length * T.sizeof);
            return result;
        }
        /**
         * Class operators
         */
        bool opEquals(A)(auto ref A array) @nogc
        if ((is(A == Array!T) || is(A == T[])))
        {
            if (_length != array.length) return false;
            if (_length == 0 && array.length == 0) return true;
            foreach(immutable i; 0 .. _length)
            {
                if (opIndex(i) != array[i]) return false;
            }
            return true;
        }
        /// ditto
        T opIndex(size_t i) @nogc
        {
            return *rwPtr(i);
        }
        /// ditto
        void opIndexAssign(T item, size_t i) @nogc
        {
            *rwPtr(i) = item;
        }
        /// ditto
        int opApply(int delegate(ref T) dg)
        {
            int result = 0;
            foreach (immutable i; 0 .. _length)
            {
                result = dg(*rwPtr(i));
                if (result) break;
            }
            return result;
        }
        /// ditto
        int opApplyReverse(int delegate(ref T) dg)
        {
            int result = 0;
            foreach_reverse (immutable i; 0 .. _length)
            {
                result = dg(*rwPtr(i));
                if (result) break;
            }
            return result;
        }
        /// ditto
        size_t opDollar() @nogc
        {
            return _length;
        }
        /// ditto
        void opAssign(T[] elements) @nogc
        {
            initLazy;
            setLength(elements.length);
            foreach (i, element; elements)
                *rwPtr(i) = element;
        }
        /// ditto
        void opOpAssign(string op)(T[] someElements) @nogc
        {
            static if (op == "~")
            {
                initLazy;
                auto old = _length;
                setLength(_length + someElements.length);
                moveMem( rwPtr(old), someElements.ptr , T.sizeof * someElements.length);
            }
            else assert(0, "operator not implemented");
        }    
        /// ditto
        void opOpAssign(string op)(T aElement) @nogc
        {
            static if (op == "~")
            {
                grow;
                opIndexAssign(aElement,_length-1);
            }
            else assert(0, "operator not implemented");
        }      
        /// ditto
        Array!T opSlice() @nogc
        {
            Array!T result;
            result.length = length;
            moveMem( result.ptr, _elems, T.sizeof * _length);
            return result;
        }
        /// ditto
        Array!T opSlice(size_t lo, size_t hi) @nogc
        {
            Array!T result;
            size_t len = hi - lo;
            result.length = len;
            moveMem(result.ptr, _elems + lo * T.sizeof, T.sizeof * len);
            return result;
        }
        /// ditto
        void opSliceAssign(T value) @nogc
        {
            opSliceAssign(value, 0, _length);
        }
        /// ditto
        void opSliceAssign(T value, size_t lo, size_t hi) @nogc
        {
            foreach(immutable i; lo .. hi)
                *rwPtr(i) = value;
        }
    }
}

unittest
{
    // init-index
    Array!size_t a;
    a.length = 2;
    a[0] = 8;
    a[1] = 9;
    assert( a[0] == 8);
    assert( a[1] == 9);

    auto b = Array!int(0,1,2,3,4,5,6);
    assert( b.length == 7);
    assert( b[$-1] == 6);

    auto floatarr = Array!float ([0.0f, 0.1f, 0.2f, 0.3f, 0.4f]);
    assert( floatarr.length == 5);
    assert( floatarr[0] == 0.0f);
    assert( floatarr[1] == 0.1f);
    assert( floatarr[2] == 0.2f);
    assert( floatarr[3] == 0.3f);
    assert( floatarr[4] == 0.4f);

    // copy-cons
    a = Array!size_t("[]");
    assert(a.length == 0);
    assertThrown(a = Array!size_t("["));
    assertThrown(a = Array!size_t("]"));
    assertThrown(a = Array!size_t("[,]"));
    assertThrown(a = Array!size_t("[,"));
    assertThrown(a = Array!size_t("[0,1,]"));
    assertThrown(a = Array!size_t("[,0,1]"));
    assertThrown(a = Array!size_t("[0,1.874f]"));
    a = Array!size_t("[10,11,12,13]");
    assert(a.length == 4);
    assert(a.toString == "[10, 11, 12, 13]");

    // loops
    int i;
    foreach(float aflt; floatarr)
    {
        float v = i * 0.1f;
        assert( aflt == v);
        i++;
    }
    foreach_reverse(float aflt; floatarr)
    {
        i--;
        float v = i * 0.1f;
        assert( aflt == v);
    }

    // opEquals
    auto nativeArr = [111u, 222u, 333u, 444u, 555u];
    auto arrcpy1 = Array!uint(111u, 222u, 333u, 444u, 555u);
    auto arrcpy2 = Array!uint(111u, 222u, 333u, 444u, 555u);
    assert( arrcpy1 == nativeArr );
    assert( arrcpy2 == nativeArr );
    assert( arrcpy1 == arrcpy2 );
    arrcpy2[0] = 0;
    assert( arrcpy1 != arrcpy2 );
    arrcpy1.length = 3;
    assert( nativeArr != arrcpy1 );
    arrcpy1.length = 0;
    arrcpy2.length = 0;
    assert( arrcpy1 == arrcpy2 );

    // opSlice
    Array!float g0 = floatarr[1..4];
    assert( g0[0] ==  floatarr[1]);
    assert( g0[2] ==  floatarr[3]);
    Array!float g1 = floatarr[];
    assert( g1[0] ==  floatarr[0]);
    assert( g1[4] ==  floatarr[4]);

    // opSliceAssign
    g1[] = 0.123456f;
    assert( g1[0] == 0.123456f);
    assert( g1[3] == 0.123456f);
    g1[0..1] = 0.654321f;
    assert( g1[0] == 0.654321f);
    assert( g1[1] == 0.123456f);
    assert( g1[2] == 0.123456f);

/*
    assert( g0[0] ==  floatarr[1]);
    assert( g0[3] ==  floatarr[4]);
    float[] g1 = floatarr[1..4];
    assert( g1[0] ==  floatarr[1]);
    assert( g1[3] ==  floatarr[4]);
    Array!float g2 = floatarr[]; // auto g2: conflict between op.overloads
    assert( g2[0] ==  floatarr[0]);
    assert( g2[4] ==  floatarr[4]);
    float[] g3 = floatarr[];
    assert( g3[0] ==  floatarr[0]);
    assert( g3[4] ==  floatarr[4]);
    assert(g3[$-1] == floatarr[$-1]);
*/

    // concatenation

    // huge
    a.length = 10_000_000;
    a[$-1] = a.length-1;
    assert(a[a.length-1] == a.length-1);
    a.length = 10;
    a.length = 10_000_000;
    a[$-1] = a.length-1;
    assert(a[$-1] == a.length-1);

    writeln("Array(T) passed the tests");
}

/**
 * ContainerChangeKind represents the message kinds a container
 * can emit (either by assignable event or by over-ridable method).
 */
enum ContainerChangeKind {add, change, remove}

/**
 * List interface.
 * It uses the Pascal semantic (add(), remove(), etc)
 * but are usable as range by std.algorithm using opSlice.
 */
interface List(T)
{
    /// support for the array syntax
    T opIndex(ptrdiff_t i);
    
    /// support for the array syntax
    void opIndexAssign(T item, size_t i);
    
    /// support for the foreach operator
    int opApply(int delegate(T) dg);
    
    /// support for the foreach_reverse operator
    int opApplyReverse(int delegate(T) dg);

    /**
     * Allocates, adds to the back, and returns a new item of type T.
     * Items allocated by this function need to be manually freed before the list destruction.
     */
    static if(is (T == class))
    {
        final T addNewItem(A...)(A a)
        {
            T result = construct!T(a);
            add(result);
            return result;
        }
    }
    else static if(is (T == struct))
    {
        final T * addNewItem(A...)(A a)
        {
            T * result = construct!T(a);
            add(result);
            return result;
        }
    }
    else static if(isPointer!T)
    {
        final T addNewItem(A...)(A a)
        {
            T result = newPtr!(PointerTarget!T)(a);
            add(result);
            return result;
        }
    }

    /**
     * Returns the last item.
     * The value returned is never null.
     */
    T last();

    /**
     * Returns the first item.
     * The value returned is never null.
     */
    T first();

    /**
     * Returns the index of anItem if it's found otherwise -1.
     */
    ptrdiff_t find(T item);

    /**
     * Adds an item at the end of list.
     * Returns 0 when the operation is successful otherwise -1.
     */
    ptrdiff_t add(T item);
    
    /**
     * Adds someItems at the end of list.
     * Returns the index of the last item when the operation is successful otherwise -1.
     */    
    ptrdiff_t add(T[] items);

    /**
     * Inserts an item at the beginning of the list.
     * Returns the index of the last item when the operation is successful otherwise -1.
     */
    ptrdiff_t insert(T item);

    /**
     * Inserts anItem before the one standing at aPosition.
     * If aPosition is greater than count than anItem is added to the end of list.
     * Returns the index of the last item when the operation is successful otherwise -1.
     */
    ptrdiff_t insert(size_t position, T item);

    /**
     * Exchanges anItem1 and anItem2 positions.
     */
    void swapItems(T item1, T item2);

    /**
     * Permutes the index1-th item with the index2-th item.
     */
    void swapIndexes(size_t index1, size_t index2);

    /**
     * Tries to removes anItem from the list.
     */
    bool remove(T item);

    /**
     * Tries to extract the anIndex-nth item from the list.
     * Returns the item or null if the removal fails.
     */
    T extract(size_t index);

    /**
     * Removes the items.
     */
    void clear();

    /**
     * Returns the count of linked item.
     * The value returned is always greater than 0.
     */
    size_t count();
}

/**
 * An List implementation, fast to be iterated, slow to be reorganized.
 * Encapsulates an Array!T and interfaces it as a List.
 */
class StaticList(T): List!T
{
    private
    {
        Array!T _items;
    }
    protected
    {
        final Exception listException()
        {
            return new Exception("List exception");
        }
    }
    public
    {
        ///
        this(A...)(A elements)
        {
            _items = Array!T(elements);
        }
        ~this()
        {
            _items.length = 0;
        }

        T opIndex(ptrdiff_t i)
        {
            return _items[i];
        }

        void opIndexAssign(T item, size_t i)
        {
            _items[i] = item;
        }

        int opApply(int delegate(T) dg)
        {
            int result = 0;
            foreach(immutable i; 0 .. _items.length)
            {
                result = dg(_items[i]);
                if (result) break;
            }
            return result;
        }

        int opApplyReverse(int delegate(T) dg)
        {
            int result = 0;
            foreach_reverse(immutable i; 0 .. _items.length)
            {
                result = dg(_items[i]);
                if (result) break;
            }
            return result;
        }

        T last()
        {
            return _items[$-1];
        }

        T first()
        {
            return _items[0];
        }

        ptrdiff_t find(T item)
        {
            ptrdiff_t result = -1;
            foreach(immutable i; 0 .. _items.length)
            {
                if (_items[i] == item)
                {
                    result = i;
                    break;
                }
            }
            return result;
        }

        /**
         * Adds an item at the end of the list.
         * To be preferred in this List implementation.
         */
        ptrdiff_t add(T item)
        {
            _items.grow;
            _items[$-1] = item;
            return _items.length - 1;
        }
        
        ptrdiff_t add(T[] items)
        {
            _items ~= items;
            return _items.length - 1;  
        }

        /**
         * Inserts an item at the beginning of the list.
         * To be avoided in this List implementation.
         */
        ptrdiff_t insert(T item)
        {
            _items.grow;
            scope(failure) throw listException;
            memmove(_items.ptr + T.sizeof, _items.ptr, (_items.length - 1) * T.sizeof);
            _items[0] = item;
            return 0;
        }

        /**
         * Inserts an item at the beginning of the list.
         * To be avoided in this List implementation.
         */
        ptrdiff_t insert(size_t position, T item)
        {
            if (position == 0) return insert(item);
            else if (position >= _items.length) return add(item);
            else
            {
                _items.grow;
                scope(failure) throw listException;
                memmove(    _items.ptr + T.sizeof * position + 1,
                            _items.ptr + T.sizeof * position,
                            (_items.length - 1 - position) * T.sizeof);
                _items[position] = item;
                return position;
            }
        }

        void swapItems(T item1, T item2)
        in
        {
            assert(item1 != item2);
        }
        body
        {
            auto i1 = find(item1);
            auto i2 = find(item2);

            if (i1 != -1 && i2 != -1)
            {
                _items[i1] = _items[i2];
                _items[i2] = item1;
            }
        }

        void swapIndexes(size_t index1, size_t index2)
        {
            if (index1 == index2) return;
            if ((index1 >= _items.length) | (index2 >= _items.length)) return;

            auto old = _items[index1];
            _items[index1] = _items[index2];
            _items[index2] = old;
        }

        bool remove(T item)
        {
            auto i = find(item);
            auto result = (i != -1);
            if (result)
                extract(i);
            return result;
        }

        T extract(size_t index)
        {
            T result = _items[index];
            if (index == _items.length-1)
            {
                _items.shrink;
            }
            else if (index == 0)
            {
                scope(failure) throw listException;
                memmove(_items.ptr, _items.ptr + T.sizeof, (_items.length - 1) * T.sizeof);
                _items.shrink;
            }
            else
            {
                Ptr fromPtr = _items.ptr + T.sizeof * index;
                scope(failure) throw listException;
                memmove(fromPtr, fromPtr + T.sizeof, (_items.length - index) * T.sizeof);
                _items.shrink;
            }
            return result;
        }

        void clear()
        {
            _items.setLength(0);
        }

        @property size_t count()
        {
            return _items.opDollar();
        }
    }
}

/**
 * Payload for the dynamic list.
 */
private template dlistPayload(T)
{
    private static const prevOffs = 0;
    private static const nextOffs = size_t.sizeof;
    private static const dataOffs = size_t.sizeof + size_t.sizeof;

    @trusted @nogc nothrow private:

    void* newPld(void* aPrevious, void* aNext, T aData)
    {
        auto result = getMem( 2 * size_t.sizeof + T.sizeof);

        if (result)
        {
            *cast(size_t*)  (result + prevOffs) = cast(size_t) aPrevious;
            *cast(size_t*)  (result + nextOffs) = cast(size_t) aNext;
            *cast(T*)       (result + dataOffs) = aData;
        }
        return result;
    }
    void freePld(void* aPayload)
    in
    {
        assert(aPayload);
    }
    body
    {
        freeMem(aPayload);
    }

    void setPrev(void* aPayload, void* aPrevious)
    in
    {
        assert(aPayload);
    }
    body
    {
        *cast(void**) (aPayload + prevOffs) = aPrevious;
    }

    void setNext(void* aPayload, void* aNext)
    in
    {
        assert(aPayload);
    }
    body
    {
        *cast(void**) (aPayload + nextOffs) = aNext;
    }

    void setData(void* aPayload, T aData)
    in
    {
        assert(aPayload);
    }
    body
    {
        *cast(T*) (aPayload + dataOffs) = aData;
    }

    void* getPrev(void* aPayload)
    {
        version(X86) asm @nogc nothrow
        {
            naked;
            mov     EAX, [EAX + prevOffs];
            ret;
        }
        else version(Win64) asm @nogc nothrow
        {
            naked;
            mov     RAX, [RCX + prevOffs];
            ret;
        }
        else version(Nux64) asm @nogc nothrow
        {
            naked;
            mov     RAX, [RDI + prevOffs];
            ret;
        }
        else return *cast(void**) (aPayload + prevOffs);
    }

    void* getNext(void* aPayload)
    {
        version(X86) asm @nogc nothrow
        {
            naked;
            mov     EAX, [EAX + nextOffs];
            ret;
        }
        else version(Win64) asm @nogc nothrow
        {
            naked;
            mov     RAX, [RCX + nextOffs];
            ret;
        }
        else version(Nux64) asm @nogc nothrow
        {
            naked;
            mov     RAX, [RDI + nextOffs];
            ret;
        }
        else return *cast(void**) (aPayload + nextOffs);
    }

    T getData(void* aPayload)
    {
        version(X86) asm @nogc nothrow
        {
            naked;
            mov     EAX, [EAX + dataOffs];
            ret;
        }
        else version(Win64) asm @nogc nothrow
        {
            naked;
            mov     RAX, [RCX + dataOffs];
            ret;
        }
        else version(Nux64) asm @nogc nothrow
        {
            naked;
            mov     RAX, [RDI + dataOffs];
            ret;
        }
        else return *cast(T*) (aPayload + dataOffs);
    }
}

/**
 * A List implementation, slow to be iterated, fast to be reorganized.
 * This is a standard doubly linked list, with GC-free heap allocations.
 * 
 * While using the array syntax for looping should be avoided, foreach() 
 * processes with some acceptable performances.
 */
class DynamicList(T): List!T
{
    private
    {
        size_t _count;
        void* _last;
        void* _first;
        alias payload = dlistPayload!T;
    }
    protected
    {
        void* getPayloadFromIx(size_t index) @safe @nogc nothrow
        {
            void* current = _first;
            foreach (immutable i; 0 .. index)
                current = payload.getNext(current);
            return current;
        }

        void* getPayloadFromDt(T item) @trusted
        {
            auto current = _first;
            while(current)
            {
                auto _data = payload.getData(current);
                if (_data == item)
                    break;
                current = payload.getNext(current);
            }
            return current;
        }
    }
    public
    {
        ///
        this(A...)(A elements)
        {
            foreach(elem; elements)
                add(elem);
        }

        ~this()
        {
            clear;
        }

        T opIndex(ptrdiff_t i) @safe @nogc nothrow
        {
            auto _pld = getPayloadFromIx(i);
            return payload.getData(_pld);
        }

        void opIndexAssign(T item, size_t i) @safe @nogc nothrow
        {
            auto _pld = getPayloadFromIx(i);
            payload.setData(_pld, item);
        }

        int opApply(int delegate(T) dg) @trusted
        {
            int result = 0;
            auto current = _first;
            while(current)
            {
                result = dg(payload.getData(current));
                if (result) break;
                current = payload.getNext(current);
            }
            return result;
        }
    
        int opApplyReverse(int delegate(T) dg) @trusted
        {
            int result = 0;
            auto current = _last;
            while(current)
            {
                result = dg(payload.getData(current));
                if (result) break;
                current = payload.getPrev(current);
            }
            return result;
        }
        
        void opSliceAssign(T[] elems) @trusted @nogc
        {
            clear;
            foreach(elem; elems)
                add(elem);
        }

        T last() @safe @nogc nothrow
        {
            return payload.getData(_last);
        }

        T first() @safe @nogc nothrow
        {
            return payload.getData(_first);
        }
 
        ptrdiff_t find(T item) @trusted
        {
            void* current = _first;
            ptrdiff_t result = -1;
            while(current)
            {
                result++;
                auto _data = payload.getData(current);
                if (_data == item) return result++;
                current = payload.getNext(current);
            }
            return -1;
        }
      
        ptrdiff_t add(T item) @trusted @nogc
        {
            if (!_first)
                return insert(item);
            else
            {
                auto _pld = payload.newPld(_last, null, item);
                payload.setNext(_last, _pld);
                _last = _pld;
                return _count++;
            }
        }
        
        ptrdiff_t add(T[] items) @trusted @nogc
        {
            foreach (item; items)
                add(item);
            return _count - 1;   
        }
  
        ptrdiff_t insert(T item) @trusted @nogc
        {
            auto _pld = payload.newPld(null, _first, item);
            if (_first) payload.setPrev(_first, _pld);
            else _last = _pld;
            _first = _pld;
            ++_count;
            return 0;
        }

        ptrdiff_t insert(size_t position, T item) @trusted @nogc
        {
            if (!_first || position == 0)
            {
                return insert(item);
            }
            else if (position >= _count)
            {
                return add(item);
            }
            else
            {
                auto old = getPayloadFromIx(position);
                auto prev = payload.getPrev(old);
                auto _pld = payload.newPld(prev, old, item);
                payload.setPrev(old, _pld);
                payload.setNext(prev, _pld);
                _count++;
                return position;
            }
        }

        void swapItems(T item1, T item2) @trusted
        {
            auto _pld1 = getPayloadFromDt(item1);
            if (_pld1 == null) return;
            auto _pld2 = getPayloadFromDt(item2);
            if (_pld2 == null) return;

            auto _data1 = payload.getData(_pld1);
            auto _data2 = payload.getData(_pld2);

            payload.setData(_pld1, _data2);
            payload.setData(_pld2, _data1);
        }

        void swapIndexes(size_t index1, size_t index2) @trusted 
        {
            auto _pld1 = getPayloadFromIx(index1);
            if (_pld1 == null) return;
            auto _pld2 = getPayloadFromIx(index2);
            if (_pld2 == null) return;

            auto _data1 = payload.getData(_pld1);
            auto _data2 = payload.getData(_pld2);

            payload.setData(_pld1, _data2);
            payload.setData(_pld2, _data1);
        }

        bool remove(T item) @trusted
        {
            auto _pld = getPayloadFromDt(item);
            if (!_pld) return false;

            auto _prev = payload.getPrev(_pld);
            auto _next = payload.getNext(_pld);
            if (_last == _pld && _prev)
            {
                _last = _prev;
                payload.setNext(_last, null);
                _next = null;
            }
            else if (_first == _pld && _next)
            {
                _first = _next;
                payload.setPrev(_first, null);
                _prev = null;
            }
            else if (_prev && _next)
            {
                if (_prev) payload.setNext(_prev, _next);
                if (_next) payload.setPrev(_next, _prev);
            }
            if (_last != _first)
                payload.freePld(_pld);
            _count--;
            return true;
        }

        T extract(size_t index) @trusted
        {
            T result;
            auto _pld = getPayloadFromIx(index);
            if (!_pld) return result;
            result = payload.getData(_pld);

            auto _prev = payload.getPrev(_pld);
            auto _next = payload.getNext(_pld);
            if (_last == _pld && _prev)
            {
                _last = _prev;
                payload.setNext(_prev, null);
                _next = null;
            }
            else if (_first == _pld && _next)
            {
                _first = _next;
                payload.setPrev(_next, null);
                _prev = null;
            }
            else if (_prev && _next)
            {
                payload.setNext(_prev, _next);
                payload.setPrev(_next, _prev);
            }
            //TODO-cbugfix: double free or corruption when trying to delete last remaining item
            // also in remove, in both case only since unittest is refactored without version()
            if (_last != _first)
                payload.freePld(_pld);
            _count--;
            return result;
        }

        void clear() @trusted @nogc 
        {
            auto current = _first;
            while(current)
            {
                auto _old = current;
                current = payload.getNext(current);
                payload.freePld(_old);
            }
            _count = 0;
            _first = null;
            _last = null;
        }

        size_t count() @trusted @property @nogc
        {
            return _count;
        }
        
        Range opSlice()
        {
            return Range(_first, _last);
        }
        
        Range opSlice(size_t lo, size_t hi) @trusted
        {
            return Range(getPayloadFromIx(lo), getPayloadFromIx(hi));
        }
        
        alias length = count;
        
        alias put = add;
        
        struct Range
        {
            private void* _begin;
            private void* _end;
    
            private this(void* b, void* e)
            {
                _begin = b;
                _end = e;
            }
    
            /**
             * Returns $(D true) if the range is _empty
             */
            @property bool empty() const
            {
                return _begin is null;
            }
    
            /**
             * Returns the first element in the range
             */
            @property T front()
            {
                return payload.getData(_begin);
            }
    
            /**
             * Returns the last element in the range
             */
            @property T back()
            {
                return payload.getData(_end);
            }
    
            /**
             * pop the front element from the range
             *
             * complexity: amortized $(BIGOH 1)
             */
            void popFront()
            {
                _begin = payload.getNext(_begin);
            }
    
            /**
             * pop the back element from the range
             *
             * complexity: amortized $(BIGOH 1)
             */
            void popBack()
            {
                _end = payload.getPrev(_end);
            }
    
            /**
             * Trivial _save implementation, needed for $(D isForwardRange).
             */
            @property Range save()
            {
                return this;
            }        
            
            
            @property size_t length()
            {
                size_t result;
                auto cur = _begin;
                while(cur)
                {
                    cur = payload.getNext(cur);
                    ++result;
                } 
                return result;
            }
        }
    }
}

unittest
{
    struct  S{int a,b; int notPod(){return a;}}
    class   C{int a,b; int notPod(){return a;}}

    void test(alias T )()
    {
        // struct as ptr
        alias SList = T!(S*);
        S[200] arrayOfS;
        SList sList = construct!SList;
        scope(exit) sList.destruct;

        for (auto i = 0; i < arrayOfS.length; i++)
        {
            arrayOfS[i].a = i;
            sList.add( &arrayOfS[i] );
            assert( sList[i] == &arrayOfS[i]);
            assert( sList.count == i + 1);
            assert( sList.find( &arrayOfS[i] ) == i);
        }

        sList.swapIndexes(0,1);
        assert( sList.find(&arrayOfS[0]) == 1 );
        assert( sList.find(&arrayOfS[1]) == 0 );
        sList.swapIndexes(0,1);
        assert( sList.find(&arrayOfS[0]) == 0 );
        assert( sList.find(&arrayOfS[1]) == 1 );
        sList.remove(sList.last);
        assert( sList.count == arrayOfS.length -1 );
        sList.clear;
        assert( sList.count == 0 );
        for (auto i = 0; i < arrayOfS.length; i++)
        {
            sList.add( &arrayOfS[i] );
        }
        sList.extract(50);
        assert( sList.find(&arrayOfS[50]) == -1 );
        sList.insert(50,&arrayOfS[50]);
        assert( sList.find(&arrayOfS[50]) == 50 );
        sList.extract(50);
        sList.insert(&arrayOfS[50]);
        assert( sList.find(&arrayOfS[50]) == 0 );
        sList.clear;
        assert( sList.count == 0 );
        for (auto i = 0; i < arrayOfS.length; i++)
        {
            sList.add( &arrayOfS[i] );
        }

        // class as ref
        alias CList = T!C;
        C[200] arrayOfC;
        CList cList = construct!CList;
        scope(exit) cList.destruct;

        for (auto i = 0; i < arrayOfC.length; i++)
        {
            arrayOfC[i] = new C;
            arrayOfC[i].a = i;
            cList.add( arrayOfC[i] );
            assert( cList[i] is arrayOfC[i]);
            assert( cList.count == i + 1);
            assert( cList.find( arrayOfC[i] ) == i);
        }
        cList.swapIndexes(0,1);
        assert( cList.find(arrayOfC[0]) == 1 );
        assert( cList.find(arrayOfC[1]) == 0 );
        cList.swapIndexes(0,1);
        assert( cList.find(arrayOfC[0]) == 0 );
        assert( cList.find(arrayOfC[1]) == 1 );
        cList.remove(cList.last);
        assert( cList.count == arrayOfC.length -1 );
        cList.clear;
        assert( cList.count == 0 );
        for (auto i = 0; i < arrayOfC.length; i++)
        {
            cList.add( arrayOfC[i] );
        }
        cList.extract(50);
        assert( cList.find(arrayOfC[50]) == -1 );
        cList.insert(50,arrayOfC[50]);
        assert( cList.find(arrayOfC[50]) == 50 );
        cList.extract(50);
        cList.insert(arrayOfC[50]);
        assert( cList.find(arrayOfC[50]) == 0 );
        cList.clear;
        assert( cList.count == 0 );
        for (auto i = 0; i < arrayOfC.length; i++)
        {
            cList.add( arrayOfC[i] );
        }

        // cleanup of internally allocated items.
        C itm;
        cList.clear;
        assert(cList.count == 0);
        cList.addNewItem;
        cList.addNewItem;
        assert(cList.count == 2);

        itm = cList.extract(0);
        assert(itm);
        itm.destruct;
        assert(cList.count == 1);
        itm = cList.extract(0);
        assert(itm);
        itm.destruct;
        assert(cList.count == 0);

        writeln(T.stringof ,"(T) passed the tests");
    }

    test!(StaticList);
    test!(DynamicList);
}

/**
 * TreeItem interface turn its implementer into a tree item.
 * Most of the methods are pre-implemented so that an interfacer just needs
 * to override the payload accessors.
 */
interface TreeItem
{
    /**
     * The following methods must be implemented in an TreeItem interfacer.
     * They provide the links between the tree items.
     *
     * Note that the mixin template TreeItemAccessors provides a standard
     * way to achieve the task.
     */
    @safe @nogc TreeItem prevSibling();
    /// ditto
    @safe @nogc TreeItem nextSibling();
    /// ditto
    @safe @nogc TreeItem parent();
    /// ditto
    @safe @nogc TreeItem firstChild();
    /// ditto
    @safe @nogc void prevSibling(TreeItem anItem);
    /// ditto
    @safe @nogc void nextSibling(TreeItem anItem);
    /// ditto
    @safe @nogc void parent(TreeItem anItem);
    /// ditto
    @safe @nogc void firstChild(TreeItem anItem);
    /// ditto
    @safe @nogc TreeItemSiblings siblings();
    /// ditto
    @safe @nogc TreeItemSiblings children();
    /**
     * treeChanged() notifies the implementer about the modification of the list.
     * It's also injected by TreeItemAccessors. This method is necessary because
     * most of the methods of the interface can't be overriden, for example to
     * call a particular updater when a node is added or removed.
     */
    @safe void treeChanged(ContainerChangeKind aChangeKind, TreeItem involvedItem);

    /// Encapsulates the operators for accessing to the siblings/children.
    private struct TreeItemSiblings
    {
        public:
        
            TreeItem item;

        public:
        
            /**
             * Provides the array syntax.
             * WHen all the items must be accessed in a loop 
             * foreach() should be prefered since it's actually a linked list.
             */
            final TreeItem opIndex(ptrdiff_t i) @safe
            {
                if (!item) return null;
                auto old = item.firstSibling;
                ptrdiff_t cnt = 0;
                while(cnt < i)
                {
                    old = old.nextSibling;
                    cnt++;
                }
                return old;
            }
            
            /// Provides the array syntax.
            final void opIndexAssign(TreeItem anItem, size_t i)
            {
                if (!item) return;
                if (anItem is null)
                {
                    if (opIndex(i) != item) item.removeSibling(i);
                    else throw new Exception("cannot remove this from this");
                }
                else
                {
                    auto old = opIndex(i);
                    if (!old) item.addSibling(anItem);
                    else
                    {
                        if (item.findSibling(anItem) > -1) item.exchangeSibling(anItem,old);
                        else
                        {
                            item.removeSibling(old);
                            item.insertSibling(i,anItem);
                        }
                    }
                }
            }
            
            /// Support for the foreach() operator.
            final int opApply(int delegate(ref TreeItem) dg)
            {
                int result = 0;
                if (!item) return result;
                auto old = item.firstSibling;
                while (old)
                {
                    result = dg(old);
                    if (result) break;
                    old = old.nextSibling;
                }
                return result;
            }
            
            /// Support for the foreach_reverse() operator.
            final int opApplyReverse(int delegate(ref TreeItem) dg)
            {
                int result = 0;
                if (!item) return result;
                auto old = item.lastSibling;
                while (old)
                {
                    result = dg(old);
                    if (result) break;
                    old = old.prevSibling;
                }
                return result;
            }

    }

// siblings -------------------------------------------------------------------+
    /**
     * Allocates, adds to the back, and returns a new sibling of type IT.
     * This method should be preferred over addSibling/insertSibling if deleteChildren() is used.
     */
    final IT addNewSibling(IT, A...)(A a) if (is(IT : TreeItem))
    {
        auto result = construct!IT(a);
        addSibling(result);
        return result;
    }

    /**
     * Returns the last item.
     * The value returned is never null.
     */
    final TreeItem lastSibling() @safe
    {
        TreeItem result;
        result = this;
        while(result.nextSibling)
        {
            result = result.nextSibling;
        }
        return result;
    }

    /**
     * Returns the first item.
     * The value returned is never null.
     */
    final TreeItem firstSibling()@safe
    {
        TreeItem result;
        result = this;
        while(result.prevSibling)
        {
            result = result.prevSibling;
        }
        return result;
    }

    /**
     * Returns the index of aSibling if it's found otherwise -1.
     */
    final ptrdiff_t findSibling(TreeItem aSibling) @safe
    {
        assert(aSibling);

        auto current = this;
        while(current)
        {
            if (current is aSibling) break;
            current = current.prevSibling;
        }

        if(!current)
        {
            current = this;
            while(current)
            {
                if (current is aSibling) break;
                current = current.nextSibling;
            }
        }

        if (!current) return -1;
        return current.siblingIndex;
    }

    /**
     * Adds an item at the end of list.
     */
    final void addSibling(TreeItem aSibling) @safe
    in
    {
        assert(aSibling);
    }
    body
    {  
        if (aSibling.hasSibling)
        {
            if (aSibling.prevSibling !is null)
                aSibling.prevSibling.removeSibling(aSibling);
            else
                aSibling.nextSibling.removeSibling(aSibling);
        }

        auto oldlast = lastSibling;
        assert(oldlast);
        oldlast.nextSibling = aSibling;
        aSibling.prevSibling = oldlast;
        aSibling.nextSibling = null;
        aSibling.parent = parent;

        if (parent)
            parent.treeChanged(ContainerChangeKind.add, aSibling);
    }

    /**
     * Inserts an item at the beginning of the list.
     */
    final void insertSibling(TreeItem aSibling) @safe
    in
    {
        assert(aSibling);
    }
    body
    {  
        if (aSibling.hasSibling)
        {
            if (aSibling.prevSibling !is null)
                aSibling.prevSibling.removeSibling(aSibling);
            else
                aSibling.nextSibling.removeSibling(aSibling);
        }

        auto oldfirst = firstSibling;
        assert(oldfirst);
        oldfirst.prevSibling = aSibling;
        aSibling.nextSibling = oldfirst;
        aSibling.parent = parent;

        if (parent)
        {
            parent.firstChild = aSibling;
        }

        treeChanged(ContainerChangeKind.add, aSibling);
    }

    /**
     * Inserts aSibling before aPosition.
     * If aPosition is greater than count than aSibling is added to the end of list.
     */
    final void insertSibling(size_t aPosition, TreeItem aSibling) @safe
    in
    {
        assert(aSibling);
    }
    body
    {  
        if (aSibling.hasSibling)
        {
            if (aSibling.prevSibling !is null)
                aSibling.prevSibling.removeSibling(aSibling);
            else
                aSibling.nextSibling.removeSibling(aSibling);
        }

        size_t cnt = siblingCount;
        if (aPosition == 0) insertSibling(aSibling);
        else if (aPosition >= cnt) addSibling(aSibling);
        else
        {
            size_t result = 1;
            auto old = firstSibling;
            while(old)
            {
                if (result == aPosition)
                {
                    auto item1oldprev = old.prevSibling;
                    auto item1oldnext = old.nextSibling;
                    aSibling.prevSibling = old;
                    aSibling.nextSibling = item1oldnext;
                    old.nextSibling = aSibling;
                    item1oldnext.prevSibling = aSibling;
                    aSibling.parent = parent;
                    assert( aSibling.siblingIndex == aPosition);

                    treeChanged(ContainerChangeKind.add,aSibling);

                    return;
                }
                old = old.nextSibling;
                result++;
            }
        }
    }

    /**
     * Permutes aSibling1 and aSibling2 positions in the list.
     */
    final void exchangeSibling(TreeItem aSibling1, TreeItem aSibling2) @safe
    in
    {
        assert(aSibling1);
        assert(aSibling2);
    }
    body
    {
        auto item1oldprev = aSibling1.prevSibling;
        auto item1oldnext = aSibling1.nextSibling;
        auto item2oldprev = aSibling2.prevSibling;
        auto item2oldnext = aSibling2.nextSibling;
        aSibling1.prevSibling = item2oldprev;
        aSibling1.nextSibling = item2oldnext;
        if (item1oldprev) item1oldprev.nextSibling = aSibling2;
        if (item1oldnext) item1oldnext.prevSibling = aSibling2;
        aSibling2.prevSibling = item1oldprev;
        aSibling2.nextSibling = item1oldnext;
        if (item2oldprev) item2oldprev.nextSibling = aSibling1;
        if (item2oldnext) item2oldnext.prevSibling = aSibling1;

        if (aSibling1.parent && aSibling1.firstChild is aSibling1)
        {
                aSibling1.firstChild = aSibling2;
        }

        treeChanged(ContainerChangeKind.change,null);
    }

    /**
     * Tries to removes aSibling from the list.
     */
    final bool removeSibling(TreeItem aSibling) @safe
    in
    {
        assert(aSibling);
    }
    body
    {
        ptrdiff_t i = findSibling(aSibling);
        if (i != -1) removeSibling(i);
        return i != -1;
    }

    /**
     * Tries to extract the anIndex-nth sibling from this branch.
     */
    final TreeItem removeSibling(size_t anIndex) @safe
    {
        auto result = siblings[anIndex];
        if (result)
        {
            auto oldprev = result.prevSibling;
            auto oldnext = result.nextSibling;
            if (oldprev) oldprev.nextSibling(oldnext);
            if (oldnext) oldnext.prevSibling(oldprev);

            if (result.parent && result.firstChild is result)
            {
                result.firstChild(result.nextSibling);
            }

            result.prevSibling = null;
            result.nextSibling = null;
            result.parent = null;

            treeChanged(ContainerChangeKind.remove, result);
        }
        return result;
    }

    /**
     * Returns the count of sibling in the branch.
     * The value returned is always greater than 0.
     */
    final size_t siblingCount() @safe
    {
        size_t toFront, toBack;
        auto current = this;
        while(current)
        {
            current = current.prevSibling;
            toFront++;
        }
        current = this;
        while(current)
        {
            current = current.nextSibling;
            toBack++;
        }
        return toFront + toBack -1;
    }

    /**
     * Returns the item position in the list.
     */
    final ptrdiff_t siblingIndex() @safe
    {
        size_t result = size_t.max; // -1
        auto current = this;
        while(current)
        {
            current = current.prevSibling;
            result++;
        }
        return result;
    }

    /**
     * Sets the item position in the list.
     * The new position of the previous item is undetermined.
     */
    final void siblingIndex(size_t aPosition) @safe
    {
        auto old = siblings[aPosition];
        version(none) exchangeSibling(old,this);
        version(all)
        {
            removeSibling(this);
            old.insertSibling(aPosition,this);
        }
    }
    
    /**
     * Indicates if the item has any neighboor.
     */
    final bool hasSibling() @safe
    {
        return ((prevSibling !is null) | (nextSibling !is null));
    }

// -----------------------------------------------------------------------------    
// children -------------------------------------------------------------------+

    /**
     * Allocates, adds to the back and returns a new children of type IT.
     * This method should be preferred over addChildren/insertChildren if deleteChildren() is used.
     */
    final IT addNewChildren(IT,A...)(A a)
    if (is(IT : TreeItem))
    {
        auto result = construct!IT(a);
        addChild(result);
        return result;
    }

    /**
     * Returns the distance to the root.
     */
    final size_t level() @safe
    {
        size_t result;
        auto current = this;
        while(current.parent)
        {
            current = current.parent;
            result++;
        }
        return result;
    }
    
    /**
     * Returns the root.
     */
    final typeof(this) root() @safe
    {
        auto current = this;
        while(current.parent)
            current = current.parent;
        return current;
    }    

    /**
     * Returns the children count.
     */
    final size_t childrenCount() @safe
    {
        auto _first = firstChild;
        if ( _first is null) return 0;
        else return _first.siblingCount;
    }

    /**
     * Adds aChild to the back and returns its position.
     */
    final void addChild(TreeItem aChild) @safe
    {
        if (aChild.parent)
        {
            if (aChild.parent !is this)
                aChild.parent.removeChild(aChild);
            else
                return;
        }
        if (!firstChild)
        {
            firstChild = aChild;
            aChild.parent = this;

            treeChanged(ContainerChangeKind.add, aChild);

            return;
        }
        else firstChild.addSibling(aChild);
    }

    /**
     * Tries to insert aChild to the front and returns its position.
     */
    final void insertChild(TreeItem aChild) @safe
    {
        if (!firstChild)
        {
            firstChild = aChild;
            aChild.parent = this;

            treeChanged(ContainerChangeKind.change,  aChild);

            return;
        }
        else firstChild.insertSibling(aChild);
    }

    /**
     * Inserts aChild at aPosition and returns its position.
     */
    final void insertChild(size_t aPosition, TreeItem aChild) @safe
    in
    {
        assert(aChild);
    }
    body
    {
        if (!firstChild)
        {
            firstChild = aChild;
            aChild.parent = this;

            treeChanged(ContainerChangeKind.change,aChild);

            return;
        }
        else firstChild.insertSibling(aPosition, aChild);
    }

    /**
     * Removes aChild from the list.
     */
    final bool removeChild(TreeItem aChild) @safe
    in
    {
        assert(aChild);
    }
    body
    {
        auto i = firstChild.findSibling(aChild);
        if (i != -1) removeChild(i);
        return i != -1;
    }

    /**
     * Extracts the child located at anIndex from this branch.
     */
    final TreeItem removeChild(size_t anIndex) @safe
    {
        auto result = children[anIndex];
        if (result)
        {
            if (anIndex > 0)
                result.prevSibling.removeSibling(anIndex);
            else
            {
                if (result.siblingCount == 1)
                {
                    result.parent = null;
                    treeChanged(ContainerChangeKind.remove, result);
                }
                else result.nextSibling.removeSibling(anIndex);
            }
        }
        return result;
    }

    /**
     * Removes the children.
     * Params:
     * unlinkSiblings = when true, the previous links to the sibling are cleaned.
     */
    @safe final void clearChildren(bool unlinkSiblings = false)
    {
        auto current = firstChild;
        while(current)
        {
            current.clearChildren(unlinkSiblings);

            auto _next = current.nextSibling;
            current.parent = null;
            if (unlinkSiblings)
            {
                current.prevSibling = null;
                current.nextSibling = null;

                treeChanged(ContainerChangeKind.remove, current);
            }
            current = _next;

            treeChanged(ContainerChangeKind.change, current);
        }
        firstChild = null;
    }

    /**
     * Removes and deletes the children.
     * If add/insert has been used to fill the list then initial references
     * will be dangling.
     */
    final void deleteChildren() @safe
    {
        auto current = firstChild;
        while(current)
        {
            current.deleteChildren;

            auto _next = current.nextSibling;
            current.parent = null;
            
            // TODO-cbugfix: to use destruct crash the test runners
            delete current;
            //destruct(current);

            // o.k but outside ptr is dangling.
            assert(current is null);

            current = _next;

            treeChanged(ContainerChangeKind.change, null);
        }
        firstChild = null;
    }
// -----------------------------------------------------------------------------
// other ----------------------------------------------------------------------+

    final char[] nodeToTextNative()
    {
        char[] result;
        foreach(immutable i; 0 .. level) result ~= '\t';
        result ~= format( "Index: %.4d - NodeType: %s", siblingIndex, typeof(this).stringof);
        return result;
    }

    final void saveToStream(Stream stream)
    {
        import std.stdio ;
        auto txt = nodeToTextNative ~ "\r\n";
        writeArray!false(stream, txt);
        foreach(c; children)
            c.saveToStream(stream);
    }
// -----------------------------------------------------------------------------    

}

/**
 * Default implementation for the TreeItem accessors.
 */
mixin template TreeItemAccessors()
{
    private:
        TreeItem fPrevSibling, fNextSibling, fFirstChild, fParent;
        TreeItemSiblings fSiblings, fChild;
    
    public:
        /**
         * Called by a TreeItem to set the link to the previous TreeItem.
         */
        void prevSibling(TreeItem aSibling) @safe @nogc
        {
            fPrevSibling = aSibling;
        }
        /**
         * Called by a TreeItem to set the link to the next TreeItem.
         */
        void nextSibling(TreeItem aSibling) @safe @nogc
        {
            fNextSibling = aSibling;
        }
        /**
         * Called by a TreeItem to set the link to the its parent.
         */
        void parent(TreeItem aParent) @safe @nogc
        {
            fParent = aParent;
        }
        /**
         * Called by a TreeItem to set the link to the its first child.
         */
        void firstChild(TreeItem aChild) @safe @nogc
        {
            fFirstChild = aChild;
            fChild.item = aChild;
        }
        /**
         * Called by a TreeItem to get the link to the previous TreeItem.
         */
        TreeItem prevSibling() @safe @nogc
        {
            return fPrevSibling;
        }
        /**
         * Called by a TreeItem to get the link to the next TreeItem.
         */
        TreeItem nextSibling() @safe @nogc
        {
            return fNextSibling;
        }
        /**
         * Called by a TreeItem to get the link to the its parent.
         */
        TreeItem parent() @safe @nogc
        {
            return fParent;
        }
        /**
         * Called by a TreeItem to set the link to the its first child.
         */
        TreeItem firstChild() @safe @nogc
        {
            return fFirstChild;
        }
        /**
         * Provides the array syntax for the siblings.
         */
        TreeItemSiblings siblings() @safe @nogc
        {
            fSiblings.item = this;
            return fSiblings;
        }
        /**
         * Provides the array syntax for the children.
         */
        TreeItemSiblings children() @safe @nogc
        {
            return fChild;
        }
        /**
         * Called by an TreeItem to notify about the changes.
         * When aChangeKind == ContainerChangeKind.add, data is a pointer to the new item.
         * When aChangeKind == ContainerChangeKind.remove, data is a pointer to the old item.
         * When aChangeKind == ContainerChangeKind.change, data is null.
         */
        void treeChanged(ContainerChangeKind aChangeKind, TreeItem involvedItem) @safe
        {
        }
}

/**
 * Helper template designed to make a C sub class of C heriting of TreeItem.
 * The class C must have a default ctor and only this default ctor is generated.
 */
class MakeTreeItem(C): C, TreeItem
if (is(C==class))
{
    mixin TreeItemAccessors;
}


unittest
{
    /*class Bar{int a,b,c;}
    alias BarItem = MakeTreeItem!Bar;

    auto a = construct!BarItem;
    scope(exit) destruct(a);
    assert(cast(TreeItem)a);

    foreach(item; a.children){}

    writeln("MakeTreeItem passed the tests");*/
}


private class Foo: TreeItem
{
    int member;
    mixin TreeItemAccessors;

    bool changeMonitor,getMonitor;

    @safe final void treeChanged(ContainerChangeKind aChangeKind, TreeItem involvedItem)
    {
        changeMonitor = true;
    }
    @safe final override TreeItem nextSibling()
    {
        getMonitor = true;
        return fNextSibling;
    }

    unittest
    {

        Foo[20] foos;
        Foo Driver;

        foos[0] = new Foo;
        Driver = foos[0];
        for (auto i =1; i < foos.length; i++)
        {
            foos[i] = new Foo;
            if (i>0) Driver.addSibling( foos[i] );
            assert( foos[i].siblingIndex == i );
            assert( Driver.siblings[i].siblingIndex == i );
            assert( Driver.siblings[i] == foos[i] );
            if (i>0) assert( foos[i].prevSibling.siblingIndex == i-1 );
            assert(Driver.lastSibling.siblingIndex == i);
        }
        assert(Driver.siblingCount == foos.length);

        assert(foos[1].nextSibling.siblingIndex == 2);
        assert(foos[1].prevSibling.siblingIndex == 0);

        Driver.exchangeSibling(foos[10],foos[16]);
        assert(Driver.siblingCount == foos.length);
        assert( foos[10].siblingIndex == 16);
        assert( foos[16].siblingIndex == 10);

        Driver.exchangeSibling(foos[10],foos[16]);
        assert(Driver.siblingCount == foos.length);
        assert( foos[10].siblingIndex == 10);
        assert( foos[16].siblingIndex == 16);


        foos[8].siblingIndex = 4;
        assert( foos[8].siblingIndex == 4);
        //assert( foos[4].siblingIndex == 5); // when siblingIndex() calls remove/insert
        //assert( foos[4].siblingIndex == 8); // when siblingIndex() calls exchangeSibling.

        assert( Driver.siblings[16] == foos[16]);
        assert( Driver.siblings[10] == foos[10]);
        Driver.siblings[16] = foos[10]; // exchg
        assert(Driver.siblingCount == foos.length);
        Driver.siblings[16] = foos[16]; // exchg
        assert(Driver.siblingCount == foos.length);
        assert( foos[16].siblingIndex == 16);
        assert( foos[10].siblingIndex == 10);


        auto C = new Foo;
        Driver.siblings[10] = C;
        Driver.siblings[16] = foos[10];
        assert( foos[16].siblingIndex == 0);
        assert( foos[10].siblingIndex == 16);
        assert( C.siblingIndex == 10);

        assert(Driver.findSibling(foos[18]) > -1);
        assert(Driver.findSibling(foos[0]) > -1);

        // remember that "item" type is the interface not its implementer.
        foreach(TreeItem item; Driver.siblings)
        {
            assert(Driver.findSibling(item) == item.siblingIndex);
            assert( cast(Foo) item);
        }
        foreach_reverse(item; Driver.siblings)
        {
            assert(Driver.findSibling(item) == item.siblingIndex);
        }

        Driver.removeSibling(19);
        assert(Driver.siblingCount == foos.length -1);
        Driver.removeSibling(18);
        assert(Driver.siblingCount == foos.length -2);
        Driver.removeSibling(foos[13]);
        assert(Driver.siblingCount == foos.length -3);
        //Driver[0] = null; // exception because Driver[0] = Driver
        assert(Driver.siblingCount == foos.length -3);
        Driver.siblings[1] = null;
        assert(Driver.siblingCount == foos.length -4);

        assert(Driver.changeMonitor);
        assert(Driver.getMonitor);

        //

        Foo[20] Items1;
        Foo[4][20] Items2;

        assert( Items1[12] is null);
        assert( Items2[12][0] is null);
        assert( Items2[18][3] is null);

        Foo Root;
        Root = new Foo;
        assert(Root.level == 0);
        for (auto i=0; i < Items1.length; i++)
        {
            Items1[i] = new Foo;
            Root.addChild(Items1[i]);
            assert(Root.childrenCount == 1 + i);
            assert(Items1[i].parent is Root);
            assert(Items1[i].siblingCount == 1 + i);
            assert(Items1[i].level == 1);
        }
        Root.clearChildren(true);
        assert(Root.childrenCount == 0);
        for (auto i=0; i < Items1.length; i++)
        {
            Root.addChild(Items1[i]);
        }

        for( auto i = 0; i < Items2.length; i++)
            for( auto j = 0; j < Items2[i].length; j++)
            {
                Items2[i][j] = new Foo;
                Items1[i].addChild(Items2[i][j]);
                assert(Items2[i][j].level == 2);
                assert(Items1[i].childrenCount == 1 + j);
                assert(Items2[i][j].siblingCount == 1 + j);
            }

        Root.deleteChildren;
    /*
        // this is an expected behavior:

        // original refs are dangling
        assert( Items1[12] is null);
        assert( Items2[12][0] is null);
        assert( Items2[18][3] is null);
        // A.V: 'cause the items are destroyed
        writeln( Items1[12].level );
    */

        // the clean-way:
        Root.addNewChildren!Foo();
            Root.children[0].addNewChildren!Foo();
            Root.children[0].addNewChildren!Foo();
            Root.children[0].addNewChildren!Foo();
        Root.addNewChildren!Foo();
            Root.children[1].addNewChildren!Foo();
            Root.children[1].addNewChildren!Foo();
            Root.children[1].addNewChildren!Foo();
            Root.children[1].addNewChildren!Foo();
                Root.children[1].children[3].addNewChildren!Foo();
                Root.children[1].children[3].addNewChildren!Foo();
                Root.children[1].children[3].addNewChildren!Foo();

        assert(Root.childrenCount == 2);
        assert(Root.children[0].childrenCount == 3);
        assert(Root.children[1].childrenCount == 4);
        assert(Root.children[1].children[3].childrenCount == 3);
        assert(Root.children[1].children[3].children[0].level == 3);
        
        assert(Root.children[1].children[3].children[0].root is Root);
        assert(Root.children[1].children[3].root is Root);

        auto str = construct!MemoryStream;
        Root.saveToStream(str);
        //str.saveToFile("izTreeNodes.txt");
        str.destruct;

        Root.deleteChildren;

        writeln("TreeItem passed the tests");
    }
}

