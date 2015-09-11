module iz.containers;

import core.exception, std.exception;
import std.stdio;
import core.stdc.string;
import std.string: format, strip;
import std.traits, std.conv: to;
import iz.memory, iz.types, iz.streams;


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
        size_t fLength;
        Ptr fElems;
        uint fGranularity;
        size_t fBlockCount;
        bool initDone;

        @safe @nogc final void initLazy()
        {
            if (initDone)
                return;
            fGranularity = 4096;
            fElems = getMem(fGranularity);
            initDone = true;
        }

        @nogc void setLength(size_t aLength)
        {
            debug { assert (fGranularity != 0); }

            size_t newBlockCount = ((aLength * T.sizeof) / fGranularity) + 1;
            if (fBlockCount != newBlockCount)
            {
                fBlockCount = newBlockCount;
                fElems = cast(T*) reallocMem(fElems, fGranularity * fBlockCount);
            }
            fLength = aLength;
        }
    }
    protected
    {
        @nogc void grow()
        {
            initLazy;
            setLength(fLength + 1);
        }
        @nogc void shrink()
        {
            setLength(fLength - 1);
        }
        @nogc final T* rwPtr(size_t index)
        {
            return cast(T*) (fElems + index * T.sizeof);
        }
    }
    public
    {
        
        @nogc this(A...)(A someElement) if (someElement.length < ptrdiff_t.max-1)
        {
            initLazy;
            static if (someElement.length == 0) return;

            setLength(someElement.length);
            ptrdiff_t i = -1;
            foreach(T elem; someElement)
            {
                *rwPtr(++i) = elem;
            }
        }
        @nogc this(T[] someElements)
        {

            if (someElements.length == 0) return;

            initLazy;
            setLength(someElements.length);

            for (auto i = 0; i<fLength; i++)
            {
                *rwPtr(i) = someElements[i];
            }
        }
        static if (__traits(compiles, to!T(string.init)))
        {
            this(string aRepresentation)
            {
                initLazy;
                setLength(0);

                Exception representationError()
                {
                    return new Exception("invalid array representation");
                }

                auto fmtRep = strip(aRepresentation);

                if (((fmtRep[0] != '[') & (fmtRep[$-1] != ']')) | (fmtRep.length < 2))
                    throw representationError;

                if (fmtRep == "[]") return;

                size_t i = 1;
                size_t _from = 1;
                while(i != fmtRep.length)
                {
                    if ((fmtRep[i] ==  ']') | (fmtRep[i] ==  ','))
                    {
                        auto valStr = fmtRep[_from..i];
                        if (valStr == "") throw representationError;
                        try
                        {
                            T _val = to!T(valStr);
                            grow;
                            *rwPtr(fLength-1) = _val;
                        }
                        catch
                            throw representationError;

                        _from = i;
                        _from++;
                    }
                    ++i;
                }
            }
        }
        ~this()
        {
            if (fElems)
                freeMem(fElems);
        }
        /**
         * Indicates the memory allocation block-size.
         */
        @property @nogc uint granurality()
        {
            return fGranularity;
        }
        /**
         * Sets the memory allocation block-size.
         * aValue should be set to 16 or 4096 (the default).
         */
        @property @nogc void granularity(uint aValue)
        {
            if (fGranularity == aValue) return;
            if (aValue < T.sizeof)
            {
                aValue = 16 * T.sizeof;
            }
            else if (aValue < 16)
            {
                aValue = 16;
            }
            else while (fGranularity % 16 != 0)
            {
                aValue--;
            }
            fGranularity = aValue;
            setLength(fLength);
        }
        /**
         * Indicates how many block the array is made of.
         */
        @property @nogc size_t blockCount()
        {
            return fBlockCount;
        }
        /**
         * Element count.
         */
        @property @nogc size_t length()
        {
            return fLength;
        }
        /// ditto
        @property @nogc void length(size_t aLength)
        {
            if (aLength == fLength) return;
            initLazy;
            setLength(aLength);
        }
        /**
         * Pointer to the first element.
         * As it's always assigned It cannot be used to determine if the array is empty.
         */
        @property @nogc Ptr ptr()
        {
            return fElems;
        }
        /**
         * Returns the string representation of the elements.
         */
        @property string toString()
        {
            if (fLength == 0) return "[]";
            string result =  "[";
            for (auto i=0; i<fLength-1; i++)
            {
                result ~= format("%s, ", *rwPtr(i));
            }
            return result ~= format("%s]",*rwPtr(fLength-1));
        }
        /**
         *  Returns a mutable copy of the array.
         */
        @property @nogc Array!T dup()
        {
            Array!T result;
            result.length = fLength;
            moveMem(result.fElems, fElems, fLength * T.sizeof);
            return result;
        }
        /**
         * Class operators
         */
        @nogc bool opEquals(AT)(auto ref AT anArray) if ( (is(AT == Array!T)) | (is(AT == T[])) )
        {
            if (fLength != anArray.length) return false;
            if (fLength == 0 && anArray.length == 0) return true;
            for (auto i = 0; i<fLength; i++)
            {
                if (opIndex(i) != anArray[i]) return false;

            }
            return true;
        }
        /// ditto
        @nogc T opIndex(size_t i)
        {
            return *rwPtr(i);
        }
        /// ditto
        @nogc void opIndexAssign(T anItem, size_t i)
        {
            *rwPtr(i) = anItem;
        }
        /// ditto
        int opApply(int delegate(ref T) dg)
        {
            int result = 0;
            for (auto i = 0; i < fLength; i++)
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
            for (ptrdiff_t i = fLength-1; i >= 0; i--)
            {
                result = dg(*rwPtr(i));
                if (result) break;
            }
            return result;
        }
        /// ditto
        @nogc size_t opDollar()
        {
            return fLength;
        }
        /// ditto
        @nogc void opAssign(T[] someElements)
        {
            initLazy;
            setLength(someElements.length);
            for (auto i = 0; i < someElements.length; i++)
            {
                *rwPtr(i) = someElements[i];
            }
        }
        /// ditto
        @nogc void opOpAssign(string op)(T[] someElements)
        {
            static if (op == "~")
            {
                initLazy;
                auto old = fLength;
                setLength(fLength + someElements.length);
                moveMem( rwPtr(old), someElements.ptr , T.sizeof * someElements.length);
            }
            else assert(0, "operator not implemented");
        }    
        /// ditto
        @nogc void opOpAssign(string op)(T aElement)
        {
            static if (op == "~")
            {
                grow;
                opIndexAssign(aElement,fLength-1);
            }
            else assert(0, "operator not implemented");
        }      
        /// ditto
        @nogc Array!T opSlice()
        {
            Array!T result;
            result.length = length;
            moveMem( result.ptr, fElems, T.sizeof * fLength);
            return result;
        }
        /// ditto
        @nogc Array!T opSlice(size_t aFrom, size_t aTo)
        {
            Array!T result;
            size_t resLen = 1 + (aTo-aFrom);
            result.length = resLen;
            moveMem( result.ptr, fElems + aFrom * T.sizeof, T.sizeof * resLen);
            return result;
        }
        /// ditto
        @nogc T opSliceAssign(T aValue)
        {
            for (auto i = 0; i<fLength; i++)
            {
                *rwPtr(i) = aValue;
            }
            return aValue;
        }
        /// ditto
        @nogc T opSliceAssign(T aValue, size_t aFrom, size_t aTo)
        {
            for (auto i = aFrom; i<aTo+1; i++)
            {
                *rwPtr(i) = aValue;
            }
            return aValue;
        }
    }
}

private class ArrayTester
{
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
        assert( g0[3] ==  floatarr[4]);
        Array!float g1 = floatarr[];
        assert( g1[0] ==  floatarr[0]);
        assert( g1[4] ==  floatarr[4]);

        // opSliceAssign
        g1[] = 0.123456f;
        assert( g1[0] == 0.123456f);
        assert( g1[3] == 0.123456f);
        g1[0..1] = 0.654321f;
        assert( g1[0] == 0.654321f);
        assert( g1[1] == 0.654321f);
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
    void opIndexAssign(T anItem, size_t i);
    
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
            T * result = new T(a);
            add(result);
            return result;
        }
    }
    else static if(isPointer!T)
    {
        final T addNewItem(A...)(A a)
        {
            T result = new PointerTarget!T(a);
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
    ptrdiff_t find(T anItem);

    /**
     * Adds an item at the end of list.
     * Returns 0 when the operation is successful otherwise -1.
     */
    ptrdiff_t add(T anItem);
    
    /**
     * Adds someItems at the end of list.
     * Returns the index of the last item when the operation is successful otherwise -1.
     */    
    ptrdiff_t add(T[] someItems);

    /**
     * Inserts an item at the beginning of the list.
     * Returns the index of the last item when the operation is successful otherwise -1.
     */
    ptrdiff_t insert(T anItem);

    /**
     * Inserts anItem before the one standing at aPosition.
     * If aPosition is greater than count than anItem is added to the end of list.
     * Returns the index of the last item when the operation is successful otherwise -1.
     */
    ptrdiff_t insert(size_t aPosition, T anItem);

    /**
     * Exchanges anItem1 and anItem2 positions.
     */
    void swapItems(T anItem1, T anItem2);

    /**
     * Permutes the index1-th item with the index2-th item.
     */
    void swapIndexes(size_t index1, size_t index2);

    /**
     * Tries to removes anItem from the list.
     */
    bool remove(T anItem);

    /**
     * Tries to extract the anIndex-nth item from the list.
     * Returns the item or null if the removal fails.
     */
    T extract(size_t anIndex);

    /**
     * Removes the items.
     */
    void clear();

    /**
     * Returns the count of linked item.
     * The value returned is always greater than 0.
     */
    @property size_t count();
}

/**
 * An List implementation, fast to be iterated, slow to be reorganized.
 * Encapsulates an Array!T and interfaces it as a List.
 */
class StaticList(T): List!T
{
    private
    {
        Array!T fItems;
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
        this(A...)(A someElements)
        {
            fItems = Array!T(someElements);
        }
        ~this()
        {
            fItems.length = 0;
        }

        T opIndex(ptrdiff_t i)
        {
            return fItems[i];
        }

        void opIndexAssign(T anItem, size_t i)
        {
            fItems[i] = anItem;
        }

        int opApply(int delegate(T) dg)
        {
            int result = 0;
            for (auto i = 0; i < fItems.length; i++)
            {
                result = dg(fItems[i]);
                if (result) break;
            }
            return result;
        }

        int opApplyReverse(int delegate(T) dg)
        {
            int result = 0;
            for (ptrdiff_t i = fItems.length-1; i >= 0; i--)
            {
                result = dg(fItems[i]);
                if (result) break;
            }
            return result;
        }

        T last()
        {
            return fItems[$-1];
        }

        T first()
        {
            return fItems[0];
        }

        ptrdiff_t find(T anItem)
        {
            ptrdiff_t result = -1;
            for (ptrdiff_t i = 0; i < fItems.length; i++)
            {
                if (fItems[i] == anItem)
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
        ptrdiff_t add(T anItem)
        {
            fItems.grow;
            fItems[$-1] = anItem;
            return fItems.length - 1;
        }
        
        ptrdiff_t add(T[] someItems)
        {
            fItems ~= someItems;  
            return fItems.length - 1;  
        }

        /**
         * Inserts an item at the beginning of the list.
         * To be avoided in this List implementation.
         */
        ptrdiff_t insert(T anItem)
        {
            fItems.grow;
            scope(failure) throw listException;
            memmove(fItems.ptr + T.sizeof, fItems.ptr, (fItems.length - 1) * T.sizeof);
            fItems[0] = anItem;
            return 0;
        }

        /**
         * Inserts an item at the beginning of the list.
         * To be avoided in this List implementation.
         */
        ptrdiff_t insert(size_t aPosition, T anItem)
        {
            if (aPosition == 0) return insert(anItem);
            else if (aPosition >= fItems.length) return add(anItem);
            else
            {
                fItems.grow;
                scope(failure) throw listException;
                memmove(    fItems.ptr + T.sizeof * aPosition + 1,
                            fItems.ptr + T.sizeof * aPosition,
                            (fItems.length - 1 - aPosition) * T.sizeof);
                fItems[aPosition] = anItem;
                return aPosition;
            }
        }

        void swapItems(T anItem1, T anItem2)
        {
            debug assert(anItem1 != anItem2);

            auto i1 = find(anItem1);
            auto i2 = find(anItem2);

            if (i1 != -1 && i2 != -1)
            {
                fItems[i1] = fItems[i2];
                fItems[i2] = anItem1;
            }
        }

        void swapIndexes(size_t index1, size_t index2)
        {
            if (index1 == index2) return;
            if ((index1 >= fItems.length) | (index2 >= fItems.length)) return;

            auto old = fItems[index1];
            fItems[index1] = fItems[index2];
            fItems[index2] = old;
        }

        bool remove(T anItem)
        {
            auto i = find(anItem);
            auto result = (i != -1);
            if (result)
                extract(i);
            return result;
        }

        T extract(size_t anIndex)
        {
            T result = fItems[anIndex];
            if (anIndex == fItems.length-1)
            {
                fItems.shrink;
            }
            else if (anIndex == 0)
            {
                scope(failure) throw listException;
                memmove(fItems.ptr, fItems.ptr + T.sizeof, (fItems.length - 1) * T.sizeof);
                fItems.shrink;
            }
            else
            {
                Ptr fromPtr = fItems.ptr + T.sizeof * anIndex;
                scope(failure) throw listException;
                memmove(fromPtr, fromPtr + T.sizeof, (fItems.length - anIndex) * T.sizeof);
                fItems.shrink;
            }
            return result;
        }

        void clear()
        {
            fItems.setLength(0);
        }

        @property size_t count()
        {
            return fItems.opDollar();
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
    {
        freeMem(aPayload);
    }

    void setPrev(void* aPayload, void* aPrevious)
    {
        *cast(void**) (aPayload + prevOffs) = aPrevious;
    }

    void setNext(void* aPayload, void* aNext)
    {
        *cast(void**) (aPayload + nextOffs) = aNext;
    }

    void setData(void* aPayload, T aData)
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
        size_t fCount;
        void* fLast;
        void* fFirst;
        alias payload = dlistPayload!T;
        size_t fInputRangeIndex;
        void* fRangeFront;
    }
    protected
    {
        void* getPayloadFromIx(size_t anIndex) @safe @nogc nothrow
        {
            auto current = fFirst;
            for (size_t i = 0; i < anIndex; i++)
            {
                current = payload.getNext(current);
            }
            return current;
        }

        void* getPayloadFromDt(T anItem) @trusted 
        {
            auto current = fFirst;
            while(current)
            {
                auto _data = payload.getData(current);
                if (_data == anItem) break;
                current = payload.getNext(current);
            }
            return current;
        }
    }
    public
    {
        this(A...)(A someElements)
        {
            foreach(T elem; someElements)
            {
                add(elem);
            }
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

        void opIndexAssign(T anItem, size_t i) @safe @nogc nothrow
        {
            auto _pld = getPayloadFromIx(i);
            payload.setData(_pld, anItem);
        }

        int opApply(int delegate(T) dg) @trusted
        {
            int result = 0;
            auto current = fFirst;
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
            auto current = fLast;
            while(current)
            {
                result = dg(payload.getData(current));
                if (result) break;
                current = payload.getPrev(current);
            }
            return result;
        }  
        
        /*T[] opSlice() @trusted
        {
            T[] result;
            foreach(t; this)
                result ~= t;
            return result;
        }*/
               
        /*T[] opSlice(size_t lo, size_t hi) @trusted
        {
            T[] result;
            result.length = hi - lo;
            for(auto i = lo; i < hi; i++)
                result ~= opIndex(i);
            return result;
        }*/
        
        void opSliceAssign(T[] elems) @trusted @nogc
        {
            clear;
            foreach(elem; elems)
                add(elem);
        }

        T last() @safe @nogc nothrow
        {
            return payload.getData(fLast);
        }

        T first() @safe @nogc nothrow
        {
            return payload.getData(fFirst);
        }
 
        ptrdiff_t find(T anItem) @trusted
        {
            void* current = fFirst;
            ptrdiff_t result = -1;
            while(current)
            {
                result++;
                auto _data = payload.getData(current);
                if (_data == anItem) return result++;
                current = payload.getNext(current);
            }
            return -1;
        }
      
        ptrdiff_t add(T anItem) @trusted @nogc
        {
            if (fFirst == null)
            {
                return insert(anItem);
            }
            else
            {
                auto _pld = payload.newPld(fLast, null, anItem);
                payload.setNext(fLast, _pld);
                fLast = _pld;
                return fCount++;
            }
        }
        
        ptrdiff_t add(T[] someItems) @trusted @nogc
        {
            for (auto i = 0; i < someItems.length; i++)
                add(someItems[i]);
            return fCount - 1;   
        }
  
        ptrdiff_t insert(T anItem) @trusted @nogc
        {
            auto _pld = payload.newPld(null, fFirst, anItem);
            if (fFirst) payload.setPrev(fFirst, _pld);
            else fLast = _pld;
            fFirst = _pld;
            fRangeFront = fFirst;
            ++fCount;
            return 0;
        }

        ptrdiff_t insert(size_t aPosition, T anItem) @trusted @nogc 
        {
            if (fFirst == null || aPosition == 0)
            {
                return insert(anItem);
            }
            else if (aPosition >= fCount)
            {
                return add(anItem);
            }
            else
            {
                auto old = getPayloadFromIx(aPosition);
                auto prev = payload.getPrev(old);
                auto _pld = payload.newPld(prev, old, anItem);
                payload.setPrev(old, _pld);
                payload.setNext(prev, _pld);
                fCount++;
                return aPosition;
            }
        }

        void swapItems(T anItem1, T anItem2) @trusted 
        {
            auto _pld1 = getPayloadFromDt(anItem1);
            if (_pld1 == null) return;
            auto _pld2 = getPayloadFromDt(anItem2);
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

        bool remove(T anItem) @trusted 
        {
            auto _pld = getPayloadFromDt(anItem);
            if (!_pld) return false;

            auto _prev = payload.getPrev(_pld);
            auto _next = payload.getNext(_pld);
            if (fLast == _pld)
            {
                fLast = _prev;
                payload.setNext(fLast, null);
            }
            else if (fFirst == _pld)
            {
                fFirst = _next;
                payload.setPrev(fFirst, null);
            }
            else
            {
                payload.setNext(_prev, _next);
                payload.setPrev(_next, _prev);
            }
            payload.freePld(_pld);
            fCount--;
            return true;
        }

        T extract(size_t anIndex) @trusted 
        {
            T result;
            auto _pld = getPayloadFromIx(anIndex);
            if (!_pld) return result;
            result = payload.getData(_pld);

            auto _prev = payload.getPrev(_pld);
            auto _next = payload.getNext(_pld);
            if (fLast == _pld)
            {
                fLast = _prev;
                payload.setNext(fLast,null);
            }
            else if (fFirst == _pld)
            {
                fFirst = _next;
                payload.setPrev(fFirst,null);
            }

            if (_prev)  payload.setNext(_prev, _next);
            if (_next)  payload.setPrev(_next, _prev);

            payload.setNext(_pld, null);
            payload.setPrev(_pld, null);
            payload.freePld(_pld);
            fCount--;

            return result;
        }

        void clear() @trusted @nogc 
        {
            auto current = fFirst;
            while(current)
            {
                auto _old = current;
                current = payload.getNext(current);
                payload.freePld(_old);
            }
            fCount = 0;
            fFirst = null;
            fLast = null;
        }

        size_t count() @trusted @property 
        {
            return fCount;
        }
        
        Range opSlice()
        {
            return Range(fFirst, fLast);
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

version(unittest)
{
    struct s{int a,b; int notPod(){return a;}}
    class c{int a,b; int notPod(){return a;}}

    private class izStaticListTester
    {
        unittest
        {
            // struct as ptr
            alias sList = StaticList!(s*);

            s[200] someS;
            sList SList = construct!sList;
            scope(exit) SList.destruct;

            for (auto i = 0; i < someS.length; i++)
            {
                someS[i].a = i;
                SList.add( &someS[i] );
                assert( SList[i] == &someS[i]);
                assert( SList.count == i + 1);
                assert( SList.find( &someS[i] ) == i);
            }
            SList.swapIndexes(0,1);
            assert( SList.find(&someS[0]) == 1 );
            assert( SList.find(&someS[1]) == 0 );
            SList.swapIndexes(0,1);
            assert( SList.find(&someS[0]) == 0 );
            assert( SList.find(&someS[1]) == 1 );
            SList.remove(SList.last);
            assert( SList.count == someS.length -1 );
            SList.clear;
            assert( SList.count == 0 );
            for (auto i = 0; i < someS.length; i++)
            {
                SList.add( &someS[i] );
            }
            SList.extract(50);
            assert( SList.find(&someS[50]) == -1 );
            SList.insert(50,&someS[50]);
            assert( SList.find(&someS[50]) == 50 );
            SList.extract(50);
            SList.insert(&someS[50]);
            assert( SList.find(&someS[50]) == 0 );
            SList.clear;
            assert( SList.count == 0 );
            for (auto i = 0; i < someS.length; i++)
            {
                SList.add( &someS[i] );
            }

            // class as ref
            alias cList = StaticList!c;

            c[200] someC;
            cList CList = construct!cList;
            scope(exit) CList.destruct;
            for (auto i = 0; i < someC.length; i++)
            {
                someC[i] = new c;
                someC[i].a = i;
                CList.add( someC[i] );
                assert( CList[i] is someC[i]);
                assert( CList.count == i + 1);
                assert( CList.find( someC[i] ) == i);
            }
            CList.swapIndexes(0,1);
            assert( CList.find(someC[0]) == 1 );
            assert( CList.find(someC[1]) == 0 );
            CList.swapIndexes(0,1);
            assert( CList.find(someC[0]) == 0 );
            assert( CList.find(someC[1]) == 1 );
            CList.remove(CList.last);
            assert( CList.count == someC.length -1 );
            CList.clear;
            assert( CList.count == 0 );
            for (auto i = 0; i < someC.length; i++)
            {
                CList.add( someC[i] );
            }
            CList.extract(50);
            assert( CList.find(someC[50]) == -1 );
            CList.insert(50,someC[50]);
            assert( CList.find(someC[50]) == 50 );
            CList.extract(50);
            CList.insert(someC[50]);
            assert( CList.find(someC[50]) == 0 );
            CList.clear;
            assert( CList.count == 0 );
            for (auto i = 0; i < someC.length; i++)
            {
                CList.add( someC[i] );
            }
            
            // cleanup of internally allocated items.
            c itm;
            CList.clear;
            CList.addNewItem;
            CList.addNewItem;
            while (CList.count > 0)
            {
                itm  = CList.extract(0);
                itm.destruct;
            }
            assert(CList.count == 0);

            writeln("StaticList(T) passed the tests");
        }

        unittest
        {
            // struct as ptr
            alias sList = DynamicList!(s*);

            s[200] someS;
            sList SList = construct!sList;
            scope(exit) SList.destruct;
            for (auto i = 0; i < someS.length; i++)
            {
                someS[i].a = i;
                SList.add( &someS[i] );
                assert( SList[i] == &someS[i]);
                assert( SList.count == i + 1);
                assert( SList.find( &someS[i] ) == i);
            }
            SList.swapIndexes(0,1);
            assert( SList.find(&someS[0]) == 1 );
            assert( SList.find(&someS[1]) == 0 );
            SList.swapIndexes(0,1);
            assert( SList.find(&someS[0]) == 0 );
            assert( SList.find(&someS[1]) == 1 );
            SList.remove(SList.last);
            assert( SList.count == someS.length -1 );
            SList.clear;
            assert( SList.count == 0 );
            for (auto i = 0; i < someS.length; i++)
            {
                SList.add( &someS[i] );
            }
            SList.extract(50);
            assert( SList.find(&someS[50]) == -1 );
            SList.insert(50,&someS[50]);
            assert( SList.find(&someS[50]) == 50 );
            SList.extract(50);
            SList.insert(&someS[50]);
            assert( SList.find(&someS[50]) == 0 );
            SList.clear;
            assert( SList.count == 0 );
            for (auto i = 0; i < someS.length; i++)
            {
                SList.add( &someS[i] );
            }

            // class as ref
            alias cList = StaticList!c;

            c[200] someC;
            cList CList = construct!cList;
            scope(exit) CList.destruct;
            for (auto i = 0; i < someC.length; i++)
            {
                someC[i] = new c;
                someC[i].a = i;
                CList.add( someC[i] );
                assert( CList[i] is someC[i]);
                assert( CList.count == i + 1);
                assert( CList.find( someC[i] ) == i);
            }
            CList.swapIndexes(0,1);
            assert( CList.find(someC[0]) == 1 );
            assert( CList.find(someC[1]) == 0 );
            CList.swapIndexes(0,1);
            assert( CList.find(someC[0]) == 0 );
            assert( CList.find(someC[1]) == 1 );
            CList.remove(CList.last);
            assert( CList.count == someC.length -1 );
            CList.clear;
            assert( CList.count == 0 );
            for (auto i = 0; i < someC.length; i++)
            {
                CList.add( someC[i] );
            }
            CList.extract(50);
            assert( CList.find(someC[50]) == -1 );
            CList.insert(50,someC[50]);
            assert( CList.find(someC[50]) == 50 );
            CList.extract(50);
            CList.insert(someC[50]);
            assert( CList.find(someC[50]) == 0 );
            CList.clear;
            assert( CList.count == 0 );
            for (auto i = 0; i < someC.length; i++)
            {
                CList.add( someC[i] );
            }
            
            // cleanup of internally allocated items.
            c itm;
            CList.clear;
            CList.addNewItem;
            CList.addNewItem;
            while (CList.count > 0)
            {
                itm  = CList.extract(0);
                itm.destruct;
            }
            assert(CList.count == 0);

            writeln("DynamicList(T) passed the tests");
        }
    }
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
    @safe @property TreeItem prevSibling();
    /// ditto
    @safe @property TreeItem nextSibling();
    /// ditto
    @safe @property TreeItem parent();
    /// ditto
    @safe @property TreeItem firstChild();
    /// ditto
    @safe @property void prevSibling(TreeItem anItem);
    /// ditto
    @safe @property void nextSibling(TreeItem anItem);
    /// ditto
    @safe @property void parent(TreeItem anItem);
    /// ditto
    @safe @property void firstChild(TreeItem anItem);
    /// ditto
    @safe @property izTreeItemSiblings siblings();
    /// ditto
    @safe @property izTreeItemSiblings children();
    /**
     * treeChanged() notifies the implementer about the modification of the list.
     * It's also injected by TreeItemAccessors. This method is necessary because
     * most of the methods of the interface can't be overriden, for example to
     * call a particular updater when a node is added or removed.
     */
    @safe void treeChanged(ContainerChangeKind aChangeKind, TreeItem involvedItem);

    /// Encapsulates the operators for accessing to the siblings/children.
    private struct izTreeItemSiblings
    {
        public:
        
            TreeItem item;

        public:
        
            /**
             * Provides the array syntax.
             * WHen all the items must be accessed in a loop 
             * foreach() should be prefered since it's actually a linked list.
             */
            @safe final TreeItem opIndex(ptrdiff_t i)
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
    @safe final TreeItem lastSibling()
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
    @safe final TreeItem firstSibling()
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
    @safe final ptrdiff_t findSibling(TreeItem aSibling)
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
    @safe final void addSibling(TreeItem aSibling)
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
    @safe final void insertSibling(TreeItem aSibling)
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
    @safe final void insertSibling(size_t aPosition, TreeItem aSibling)
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
    @safe final void exchangeSibling(TreeItem aSibling1, TreeItem aSibling2)
    {
        assert(aSibling1);
        assert(aSibling2);

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
    @safe final bool removeSibling(TreeItem aSibling)
    {
        assert(aSibling);

        auto result = findSibling(aSibling);
        if (result != -1)
        {
            removeSibling(result);
            return true;
        }
        else
            return false;
    }

    /**
     * Tries to extract the anIndex-nth sibling from this branch.
     */
    @safe final TreeItem removeSibling(size_t anIndex)
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
    @safe @property final size_t siblingCount()
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
    @safe @property final ptrdiff_t siblingIndex()
    {
        size_t result = size_t.max; // -1
        auto current = this;
        debug assert(current);
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
    @safe @property final void siblingIndex(size_t aPosition)
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
    @safe @property final bool hasSibling()
    {
        return ((prevSibling !is null) | (nextSibling !is null));
    }

// -----------------------------------------------------------------------------    
// children -------------------------------------------------------------------+

    /**
     * Allocates, adds to the back and returns a new children of type IT.
     * This method should be preferred over addChildren/insertChildren if deleteChildren() is used.
     */
    final IT addNewChildren(IT,A...)(A a) if (is(IT : TreeItem))
    {
        auto result = construct!IT(a);
        addChild(result);
        return result;
    }

    /**
     * Returns the distance to the root.
     */
    @safe @property final size_t level()
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
    @safe @property final typeof(this) root()
    {
        auto current = this;
        while(current.parent)
            current = current.parent;
        return current;
    }    

    /**
     * Returns the children count.
     */
    @safe @property final size_t childrenCount()
    {
        auto _first = firstChild;
        if ( _first is null) return 0;
        else return _first.siblingCount;
    }

    /**
     * Adds aChild to the back and returns its position.
     */
    @safe final void addChild(TreeItem aChild)
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
    @safe final void insertChild(TreeItem aChild)
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
    @safe final void insertChild(size_t aPosition, TreeItem aChild)
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
    @safe final bool removeChild(TreeItem aChild)
    {
        assert(aChild);

        auto result = firstChild.findSibling(aChild);
        if (result != -1)
        {
            removeChild(result);
            return true;
        }
        else
            return false;
    }

    /**
     * Extracts the child located at anIndex from this branch.
     */
    @safe final TreeItem removeChild(size_t anIndex)
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
    @safe final void deleteChildren()
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
        for (auto i = 0; i < level; i++) result ~= '\t';
        result ~= format( "Index: %.4d - NodeType: %s", siblingIndex, typeof(this).stringof);
        return result;
    }

    final void saveToStream(Stream aStream)
    {
        auto rn = "\r\n".dup;
        auto txt = nodeToTextNative;
        aStream.write( txt.ptr, txt.length );
        aStream.write( rn.ptr, rn.length );
        for (auto i = 0; i < childrenCount; i++)
            children[i].saveToStream(aStream);
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
        izTreeItemSiblings fSiblings, fChild;
    
    public:
        /**
         * Called by an TreeItem to set the link to the previous TreeItem.
         */
        @safe @property void prevSibling(TreeItem aSibling)
        {
            fPrevSibling = aSibling;
        }
        /**
         * Called by an TreeItem to set the link to the next TreeItem.
         */
        @safe @property void nextSibling(TreeItem aSibling)
        {
            fNextSibling = aSibling;
        }
        /**
         * Called by an TreeItem to set the link to the its parent.
         */
        @safe @property void parent(TreeItem aParent)
        {
            fParent = aParent;
        }
        /**
         * Called by an TreeItem to set the link to the its first child.
         */
        @safe @property void firstChild(TreeItem aChild)
        {
            fFirstChild = aChild;
            fChild.item = aChild;
        }
        /**
         * Called by an TreeItem to get the link to the previous TreeItem.
         */
        @safe @property TreeItem prevSibling()
        {
            return fPrevSibling;
        }
        /**
         * Called by an TreeItem to get the link to the next TreeItem.
         */
        @safe @property TreeItem nextSibling()
        {
            return fNextSibling;
        }
        /**
         * Called by an TreeItem to get the link to the its parent.
         */
        @safe @property TreeItem parent()
        {
            return fParent;
        }
        /**
         * Called by an TreeItem to set the link to the its first child.
         */
        @safe @property TreeItem firstChild()
        {
            return fFirstChild;
        }
        /**
         * Provides the array syntax for the siblings.
         */
        @safe @property izTreeItemSiblings siblings()
        {
            fSiblings.item = this;
            return fSiblings;
        }
        /**
         * Provides the array syntax for the children.
         */
        @safe @property izTreeItemSiblings children()
        {
            return fChild;
        }
        /**
         * Called by an TreeItem to notify about the changes.
         * When aChangeKind == ContainerChangeKind.add, data is a pointer to the new item.
         * When aChangeKind == ContainerChangeKind.remove, data is a pointer to the old item.
         * When aChangeKind == ContainerChangeKind.change, data is null.
         */
        @safe void treeChanged(ContainerChangeKind aChangeKind, TreeItem involvedItem)
        {
        }
}

/**
 * Helper template designed to make a C sub class of C heriting of TreeItem.
 * The class C must have a default ctor and only this default ctor is generated.
 */
class MakeTreeItem(C): C, TreeItem
if ((is(C==class)))
{
    mixin TreeItemAccessors;
}

version(unittest)
{
    private class bar{int a,b,c;}
    alias linkedBar = MakeTreeItem!bar;
    private class linkedBarTest: linkedBar
    {
        unittest
        {
            auto a = construct!linkedBarTest;
            scope(exit) destruct(a);
            assert(cast(TreeItem)a);
            
            foreach(item; a.children){}
            
            writeln("MakeTreeItem passed the tests");
        }
    }
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
    @safe @property final TreeItem nextSibling()
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

