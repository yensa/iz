module iz.containers;

import core.exception, std.exception;
import std.stdio, std.c.stdlib: malloc, free, realloc;
import core.stdc.string: memcpy, memmove;
import std.string: format, strip;
import std.traits, std.conv: to;
import iz.types, iz.streams;

/**
 * Parameterized, GC-free array.
 *
 * izArray(T) implements a single-dimension array of uncollected memory.
 * It internally preallocates the memory to minimize the reallocation fingerprints.
 *
 * Its layout differs from built-in D's dynamic arrays and they cannot be cast as T[]
 * however, most of the slicing operations are possible.
 *
 * TODO:
 * - concatenation.
 * - assign from built-in arrays slices.
 */
struct izArray(T)
{
	private
	{
		size_t fLength;
		izPtr fElems;
		uint fGranularity;
		size_t fBlockCount;
		bool initDone;

		final void initLazy()
		{
			if(initDone) return;
			fGranularity = 4096;
			fElems = malloc(fGranularity);
			if (!fElems) throw new OutOfMemoryError();
			initDone = true;
		}

		void setLength(size_t aLength)
		{
			debug { assert (fGranularity != 0); }

			size_t newBlockCount = ((aLength * T.sizeof) / fGranularity) + 1;
			if (fBlockCount != newBlockCount)
			{
				fBlockCount = newBlockCount;
				fElems = cast(T*) realloc(cast(izPtr) fElems, fGranularity * fBlockCount);
				if (!fElems) throw new OutOfMemoryError();
			}
			fLength = aLength;
		}
	}
	protected
	{
		void grow()
		{
            initLazy;
			setLength(fLength + 1);
		}
		void shrink()
		{
			setLength(fLength - 1);
		}
		final T* rwPtr(size_t index)
		{
			return cast(T*) (fElems + index * T.sizeof);
		}
	}
	public
	{
		this(A...)(A someElement) if (someElement.length < ptrdiff_t.max-1)
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
		this(T[] someElements)
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
				std.c.stdlib.free(fElems);
		}
		/**
		 * Indicates the memory allocation block-size.
		 */
		@property uint granurality()
		{
			return fGranularity;
		}
		/**
		 * Sets the memory allocation block-size.
		 * aValue should be set to 16 or 4096 (the default).
		 */
		@property void granularity(uint aValue)
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
		@property size_t blockCount()
		{
			return fBlockCount;
		}
		/**
		 * Element count.
		 */
		@property size_t length()
		{
			return fLength;
		}
		/// ditto
		@property void length(size_t aLength)
		{
			if (aLength == fLength) return;
			initLazy;
			setLength(aLength);
		}
		/**
		 * Pointer to the first element.
		 * As it's always assigned It cannot be used to determine if the array is empty.
		 */
		@property izPtr ptr()
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
		 *	Returns a mutable copy of the array.
		 */
		@property izArray!T dup()
		{
			izArray!T result;
			result.length = fLength;
			memmove(result.fElems, fElems, fLength * T.sizeof);
			return result;
		}
		/**
		 * Class operators
		 */
		bool opEquals(AT)(auto ref AT anArray) if ( (is(AT == izArray!T)) | (is(AT == T[])) )
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
		T opIndex(size_t i)
		{
			return *rwPtr(i);
		}
		/// ditto
		void opIndexAssign(T anItem, size_t i)
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
		size_t opDollar()
		{
			return fLength;
		}
		/// ditto
		void opAssign(T[] someElements)
		{
			initLazy;
			setLength(someElements.length);
			for (auto i = 0; i < someElements.length; i++)
			{
				*rwPtr(i) = someElements[i];
			}
		}
		/// ditto
		izArray!T opSlice()
		{
			izArray!T result;
			result.length = length;
			memmove( result.ptr, fElems , T.sizeof * fLength);
			return result;
		}
		/// ditto
		izArray!T opSlice(size_t aFrom, size_t aTo)
		{
			izArray!T result;
			size_t resLen = 1 + (aTo-aFrom);
			result.length = resLen;
			memmove( result.ptr, fElems + aFrom * T.sizeof, T.sizeof * resLen);
			return result;
		}
		/// ditto
		T opSliceAssign(T aValue)
		{
			for (auto i = 0; i<fLength; i++)
			{
				*rwPtr(i) = aValue;
			}
			return aValue;
		}
		/// ditto
		T opSliceAssign(T aValue, size_t aFrom, size_t aTo)
		{
			for (auto i = aFrom; i<aTo+1; i++)
			{
				*rwPtr(i) = aValue;
			}
			return aValue;
		}
	}
}

private class izArrayTester
{
	unittest
	{
		// init-index
		izArray!size_t a;
		a.length = 2;
		a[0] = 8;
		a[1] = 9;
		assert( a[0] == 8);
		assert( a[1] == 9);

		auto b = izArray!int(0,1,2,3,4,5,6);
		assert( b.length == 7);
		assert( b[$-1] == 6);

		auto floatarr = izArray!float ([0.0f, 0.1f, 0.2f, 0.3f, 0.4f]);
		assert( floatarr.length == 5);
		assert( floatarr[0] == 0.0f);
		assert( floatarr[1] == 0.1f);
		assert( floatarr[2] == 0.2f);
		assert( floatarr[3] == 0.3f);
		assert( floatarr[4] == 0.4f);

		// copy-cons
		a = izArray!size_t("[]");
		assert(a.length == 0);
		assertThrown(a = izArray!size_t("["));
		assertThrown(a = izArray!size_t("]"));
		assertThrown(a = izArray!size_t("[,]"));
		assertThrown(a = izArray!size_t("[,"));
		assertThrown(a = izArray!size_t("[0,1,]"));
		assertThrown(a = izArray!size_t("[,0,1]"));
		assertThrown(a = izArray!size_t("[0,1.874f]"));
		a = izArray!size_t("[10,11,12,13]");
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
		auto arrcpy1 = izArray!uint(111u, 222u, 333u, 444u, 555u);
		auto arrcpy2 = izArray!uint(111u, 222u, 333u, 444u, 555u);
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
		izArray!float g0 = floatarr[1..4];
		assert( g0[0] ==  floatarr[1]);
		assert( g0[3] ==  floatarr[4]);
		izArray!float g1 = floatarr[];
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
		izArray!float g2 = floatarr[]; // auto g2: conflict between op.overloads
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

		writeln("izArray(T) passed the tests");
	}
}

/**
 * izContainerChangeKind represents the message kinds a container
 * can emit (either by assignable event or by over-ridable method).
 */
enum izContainerChangeKind {add,change,remove};

/**
 * TODO:
 * - opApply ref or not according to T (to store structs w/o using a ptr).
 */
interface izList(T)
{
	alias void delegate(Object aList, izContainerChangeKind aChangeKind) izListNotification;

	/**
	 * hasChanged() notify the implementer about the modification of the list.
	 * It's designed to be overridden to ease the internal communication.
	 */
	void hasChanged(izContainerChangeKind aChangeKind, T* involvedItem);

	/**
	 * Operators
	 */
	T opIndex(ptrdiff_t i);
	/// ditto
	void opIndexAssign(T anItem, size_t i);
	/// ditto
	int opApply(int delegate(T) dg);
	/// ditto
	int opApplyReverse(int delegate(T) dg);

	/**
	 * If T is a class then allocates, adds to the back, and returns a new item of type T.
	 * Items allocated by this function need to be manually freed before the holder gets destroyed.
	 */
	static if( is (T : Object))
	{
		final T addNewItem(T, A...)(A a)
		{
			T result = izAllocObject!T(a);
			add(result);
			return result;
		}
	}
	static if( is (T == struct))
	{
		final T * addNewItem(T, A...)(A a)
		{
			T * result = new T(a);
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
	 * Inserts an item at the beginning of the list.
	 * Returns 0 when the operation is successful otherwise -1.
	 */
	ptrdiff_t insert(T anItem);

	/**
	 * Inserts anItem before the one standing at aPosition.
	 * If aPosition is greater than count than anItem is added to the end of list.
	 * Returns the item position when the operation is successful otherwise -1.
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
	T* extract(size_t anIndex);

    /**
     * Removes the items.
     */
    void clear();

	/**
	 * Returns the count of linked item.
	 * The value returned is always greater than 0.
	 */
	@property size_t count();

	/**
	 * the onChange event can be assigned to inform the outside-world
	 * about the modifications. Inside a descendant, rather override
	 * hasChanged() which is designed for this purpose.
	 */
	@property void onChange(izListNotification aNotification);
	/// ditto
	@property izListNotification onChange();
}

/**
 * An izList implementation, fast to be iterated, slow to be reorganized.
 * Encapsulates an izArray!T and interfaces it with izList methods.
 *
 * TODO:
 * - removeFirst/removeLast.
 * - extract return value.
 */
class izStaticList(T): izObject, izList!T
{
	private
	{
		izArray!T fItems;
		izListNotification fOnChange;
	}
	protected
	{
		final Exception listException()
		{
			return new Exception("izList exception");
		}
	}
	public
	{
		this(A...)(A someElements)
		{
			fItems = izArray!T(someElements);
		}
		~this()
		{
			fItems.length = 0;
		}

		void hasChanged(izContainerChangeKind aChangeKind, T* involvedItem)
		{
			if (fOnChange) fOnChange(this, aChangeKind);
		}

		T opIndex(ptrdiff_t i)
		{
			return fItems[i];
		}

		void opIndexAssign(T anItem, size_t i)
		{
			fItems[i] = anItem;
            hasChanged(izContainerChangeKind.add, &anItem);
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
		 * To be preferred in this izList implementation.
		 */
		ptrdiff_t add(T anItem)
		{
			fItems.grow;
			fItems[$-1] = anItem;
            hasChanged(izContainerChangeKind.add, &anItem);
			return fItems.length - 1;
		}

		/**
		 * Inserts an item at the beginning of the list.
		 * To be avoided in this izList implementation.
		 */
		ptrdiff_t insert(T anItem)
		{
			fItems.grow;
			scope(failure) throw listException;
			memmove(fItems.ptr + T.sizeof, fItems.ptr, (fItems.length - 1) * T.sizeof);
			fItems[0] = anItem;
            hasChanged(izContainerChangeKind.add, &anItem);
            return 0;
		}

		/**
		 * Inserts an item at the beginning of the list.
		 * To be avoided in this izList implementation.
		 */
		ptrdiff_t insert(size_t aPosition, T anItem)
		{
			if (aPosition == 0) return insert(anItem);
			else if (aPosition >= fItems.length) return add(anItem);
			else
			{
				fItems.grow;
				scope(failure) throw listException;
				memmove(	fItems.ptr + T.sizeof * aPosition + 1,
							fItems.ptr + T.sizeof * aPosition,
							(fItems.length - 1 - aPosition) * T.sizeof);
				fItems[aPosition] = anItem;
                hasChanged(izContainerChangeKind.add, &anItem);
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
                hasChanged(izContainerChangeKind.change, null);
			}
		}

		void swapIndexes(size_t index1, size_t index2)
		{
			if (index1 == index2) return;
			if ((index1 >= fItems.length) | (index2 >= fItems.length)) return;

			auto old = fItems[index1];
			fItems[index1] = fItems[index2];
			fItems[index2] = old;
            hasChanged(izContainerChangeKind.change, null);
		}

		bool remove(T anItem)
		{
			auto i = find(anItem);
			auto result = (i != -1);
			if (result)
            {
                extract(i);
                hasChanged(izContainerChangeKind.remove, &anItem);
            }
			return result;
		}

		T* extract(size_t anIndex)
		{
            T* result = null;
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
				izPtr fromPtr = fItems.ptr + T.sizeof * anIndex;
				scope(failure) throw listException;
				memmove(fromPtr, fromPtr + T.sizeof, (fItems.length - anIndex) * T.sizeof);
				fItems.shrink;
			}
            hasChanged(izContainerChangeKind.remove,result);
            return result; // ! result is undefined.
		}

        void clear()
        {
            fItems.setLength(0);
            hasChanged(izContainerChangeKind.change, null);
        }

		@property size_t count()
		{
			return fItems.opDollar();
		}

		@property void onChange(izListNotification aNotification)
		{
			fOnChange = aNotification;
		}

		@property izListNotification onChange()
		{
			return fOnChange;
		}
	}

}

/**
 * Payload for the dynamic list.
 */
template dlistPayload(T)
{
	const prevOffs = 0;
	const nextOffs = size_t.sizeof;
	const dataOffs = size_t.sizeof + size_t.sizeof;
	void* newPld(void* aPrevious, void* aNext, T aData)
	{
		auto result = std.c.stdlib.malloc( 2 * size_t.sizeof + T.sizeof);
		if (!result) throw new OutOfMemoryError();
		*cast(size_t*)	(result + prevOffs) = cast(size_t) aPrevious;
		*cast(size_t*)	(result + nextOffs) = cast(size_t) aNext;
		*cast(T*) 		(result + dataOffs) = aData;

		return result;
	}
	void freePld(void* aPayload)
	{
		std.c.stdlib.free(aPayload);
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
		return *cast(void**) (aPayload + prevOffs);
	}

	void* getNext(void* aPayload)
	{
		return *cast(void**) (aPayload + nextOffs);
	}

	T getData(void* aPayload)
	{
		return *cast(T*) (aPayload + dataOffs);
	}
}

/**
 * An izList implementation, slow to be iterated, fast to be reorganized.
 * This is a standard linked list, with GC-free heap allocations.
 *
 * TODO:
 * - extract return value.
 * - removeFirst/removeLast.
 */
class izDynamicList(T): izObject, izList!T
{
	private
	{
		size_t fCount;
		void* fLast;
		void* fFirst;
		izListNotification fOnChange;
		alias dlistPayload!T payload;
	}
	protected
	{
		void* getPayloadFromIx(size_t anIndex)
		{
			auto current = fFirst;
			for (size_t i = 0; i < anIndex; i++)
			{
				current = payload.getNext(current);
			}
			return current;
		}

		void* getPayloadFromDt(T anItem)
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

        void hasChanged(izContainerChangeKind aChangeKind, T* involvedItem)
        {
			if (fOnChange) fOnChange(this, aChangeKind);
        }

        T opIndex(ptrdiff_t i)
        {
            auto _pld = getPayloadFromIx(i);
            return payload.getData(_pld);
        }

        void opIndexAssign(T anItem, size_t i)
        {
            auto _pld = getPayloadFromIx(i);
            payload.setData(_pld, anItem);
        }

        int opApply(int delegate(T) dg)
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

        int opApplyReverse(int delegate(T) dg)
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

        T last()
        {
            return payload.getData(fLast);
        }

        T first()
        {
            return payload.getData(fFirst);
        }

        ptrdiff_t find(T anItem)
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

        ptrdiff_t add(T anItem)
        {
            if (fFirst == null)
            {
                insert(anItem);
                return 0;
            }
            else
            {
                auto _pld = payload.newPld(fLast, null, anItem);
                payload.setNext(fLast, _pld);
				fLast = _pld;

				hasChanged(izContainerChangeKind.add, &anItem);

				return fCount++;
            }
        }

		ptrdiff_t insert(T anItem)
		{
			auto _pld = payload.newPld(null, fFirst, anItem);
			if (fFirst) payload.setPrev(fFirst, _pld);
			else fLast = _pld;
			fFirst = _pld;

			hasChanged(izContainerChangeKind.add, &anItem);

			return fCount++;
		}

		ptrdiff_t insert(size_t aPosition, T anItem)
		{
			if (fFirst == null)
            {
                insert(anItem);
                return 0;
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

				hasChanged(izContainerChangeKind.add, &anItem);

				return aPosition;
			}
		}

		void swapItems(T anItem1, T anItem2)
		{
			auto _pld1 = getPayloadFromDt(anItem1);
			if (_pld1 == null) return;
			auto _pld2 = getPayloadFromDt(anItem2);
			if (_pld2 == null) return;

			auto _data1 = payload.getData(_pld1);
			auto _data2 = payload.getData(_pld2);

			payload.setData(_pld1, _data2);
			payload.setData(_pld2, _data1);

			hasChanged(izContainerChangeKind.change, null);
		}

		void swapIndexes(size_t index1, size_t index2)
		{
			auto _pld1 = getPayloadFromIx(index1);
			if (_pld1 == null) return;
			auto _pld2 = getPayloadFromIx(index2);
			if (_pld2 == null) return;

			auto _data1 = payload.getData(_pld1);
			auto _data2 = payload.getData(_pld2);

			payload.setData(_pld1, _data2);
			payload.setData(_pld2, _data1);

			hasChanged(izContainerChangeKind.change, null);
		}

		bool remove(T anItem)
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

			hasChanged(izContainerChangeKind.remove, &anItem);

			return true;
		}

		T* extract(size_t anIndex)
		{
			T* result = null;
			auto _pld = getPayloadFromIx(anIndex);
			if (!_pld) return result;

			auto g = payload.getData(_pld);
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

			if (_prev)	payload.setNext(_prev, _next);
			if (_next)	payload.setPrev(_next, _prev);

			payload.setNext(_pld, null);
			payload.setPrev(_pld, null);
			payload.freePld(_pld);
			fCount--;

			hasChanged(izContainerChangeKind.remove, result);

			return result;	 // ! result is undefined
		}

		void clear()
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

		@property size_t count()
		{
			return fCount;
		}

		@property void onChange(izListNotification aNotification)
		{
			fOnChange = aNotification;
		}

		@property izListNotification onChange()
		{
			return fOnChange;
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
			bool changeMonitor;

			// struct as ptr
			alias izStaticList!(s*) sList;

			void listChangedProc(Object aList, izContainerChangeKind aChangeKind)
			{
				changeMonitor = true;
			}

			s someS[200];
			sList SList = new sList;
			scope(exit) SList.demolish;
			SList.onChange = &listChangedProc;
			changeMonitor = false;
			for (auto i = 0; i < someS.length; i++)
			{
				someS[i].a = i;
				SList.add( &someS[i] );
				assert( SList[i] == &someS[i]);
				assert( SList.count == i + 1);
				assert( SList.find( &someS[i] ) == i);
			}
			assert(changeMonitor);
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
			alias izStaticList!c cList;

			c someC[200];
			cList CList = new cList;
			scope(exit) CList.demolish;
			CList.onChange = &listChangedProc;
			changeMonitor = false;
			for (auto i = 0; i < someC.length; i++)
			{
				someC[i] = new c;
				someC[i].a = i;
				CList.add( someC[i] );
				assert( CList[i] is someC[i]);
				assert( CList.count == i + 1);
				assert( CList.find( someC[i] ) == i);
			}
			assert(changeMonitor);
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
			/*
			// cleanup of internally allocated items.
			CList.clear;
			CList.addNewItem!c;
			CList.addNewItem!c;
			while (CList.count > 0)
			{
				c* cpt;
				// extract return value is not yet defined.
				cpt = CList.extract(0);
				//delete *cpt;
			}*/

			writeln("izStaticList(T) passed the tests");
		}

		unittest
		{
			bool changeMonitor;

			// struct as ptr
			alias izDynamicList!(s*) sList;

			void listChangedProc(Object aList, izContainerChangeKind aChangeKind)
			{
				changeMonitor = true;
			}

			s someS[200];
			sList SList = new sList;
			scope(exit) SList.demolish;
			SList.onChange = &listChangedProc;
			changeMonitor = false;
			for (auto i = 0; i < someS.length; i++)
			{
				someS[i].a = i;
				SList.add( &someS[i] );
				assert( SList[i] == &someS[i]);
				assert( SList.count == i + 1);
				assert( SList.find( &someS[i] ) == i);
			}
			assert(changeMonitor);
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
			alias izStaticList!c cList;

			c someC[200];
			cList CList = new cList;
			scope(exit) CList.demolish;
			CList.onChange = &listChangedProc;
			changeMonitor = false;
			for (auto i = 0; i < someC.length; i++)
			{
				someC[i] = new c;
				someC[i].a = i;
				CList.add( someC[i] );
				assert( CList[i] is someC[i]);
				assert( CList.count == i + 1);
				assert( CList.find( someC[i] ) == i);
			}
			assert(changeMonitor);
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
			/*
			// cleanup of internally allocated items.
			CList.clear;
			CList.addNewItem!c;
			CList.addNewItem!c;
			while (CList.count > 0)
			{
				c* cpt;
				// extract return value is not yet defined.
				cpt = CList.extract(0);
				//delete *cpt;
			}*/

			writeln("izDynamicList(T) passed the tests");
		}
	}
}

/**
 * izTreeItem interface allows to turn its implementer into a tree item.
 * Most of the methods are pre-implemented so that an interfacer just needs
 * to override the payload accessors.
 */
interface izTreeItem
{
	/**
	 * The following methods must be implemented in an izTreeItem interfacer.
	 * They provide the access to the links between the list items.
	 *
	 * Note that the mixin template izTreeItemAccessors provides a standard
	 * way to achieve the task.
	 */
	@safe @property izTreeItem prevSibling();
	/// ditto
	@safe @property izTreeItem nextSibling();
	/// ditto
	@safe @property izTreeItem parent();
	/// ditto
	@safe @property izTreeItem firstChild();
	/// ditto
	@safe @property void prevSibling(izTreeItem anItem);
	/// ditto
	@safe @property void nextSibling(izTreeItem anItem);
	/// ditto
	@safe @property void parent(izTreeItem anItem);
	/// ditto
	@safe @property void firstChild(izTreeItem anItem);
	/// ditto
	@safe @property izTreeItemSiblings siblings();
	/// ditto
	@safe @property izTreeItemSiblings children();
	/**
	 * hasChanged() notify the implementers about the modification of the list.
	 * It's also injected by izTreeItemAccessors.
	 */
	@safe void hasChanged(izContainerChangeKind aChangeKind, izTreeItem involvedItem);

	/// Encapsulates the operators for accessing to the siblings/children.
	struct izTreeItemSiblings
	{
		public:
			izTreeItem item;

		public:
			@safe final izTreeItem opIndex(ptrdiff_t i)
			{
				auto old = item.firstSibling;
				ptrdiff_t cnt = 0;
				while(cnt < i)
				{
					old = old.nextSibling;
					cnt++;
				}
				return old;
			}
			/// ditto
			final void opIndexAssign(izTreeItem anItem, size_t i)
			{
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
			/// ditto
			final int opApply(int delegate(ref izTreeItem) dg)
			{
				int result = 0;
				auto old = item.firstSibling;
				while (old)
				{
					result = dg(old);
					if (result) break;
					old = old.nextSibling;
				}
				return result;
			}
			/// ditto
			final int opApplyReverse(int delegate(ref izTreeItem) dg)
			{
				int result = 0;
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

// siblings --------------------------
	/**
	 * Allocates, adds to the back, and returns a new sibling of type IT.
	 * This method should be preferred over addSibling/insertSibling if deleteChildren() is used.
	 */
	final IT addNewSibling(IT, A...)(A a) if (is(IT : izTreeItem))
	{
		IT result = izAllocObject!IT(a);
		addSibling(result);
		return result;
	}

	/**
	 * Returns the last item.
	 * The value returned is never null.
	 */
	@safe final izTreeItem lastSibling()
	{
		izTreeItem result;
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
	@safe final izTreeItem firstSibling()
	{
		izTreeItem result;
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
	@safe final ptrdiff_t findSibling(izTreeItem aSibling)
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
	 * Returns 0 when the operation is successful otherwise -1.
	 */
	@safe final ptrdiff_t addSibling(izTreeItem aSibling)
	{
		assert(aSibling);

		// duplicated items would break the chain.
		if (findSibling(aSibling) > -1) return -1;

		auto oldlast = lastSibling;
		assert(oldlast);
		oldlast.nextSibling = aSibling;
		aSibling.prevSibling = oldlast;
		aSibling.nextSibling = null;
		aSibling.parent = parent;

		hasChanged(izContainerChangeKind.add,aSibling);

		return 0;
	}

	/**
	 * Inserts an item at the beginning of the list.
	 * Returns 0 when the operation is successful otherwise -1.
	 */
	@safe final ptrdiff_t insertSibling(izTreeItem aSibling)
	{
		assert(aSibling);

		if (findSibling(aSibling) > -1) return -1;

		auto oldfirst = firstSibling;
		assert(oldfirst);
		oldfirst.prevSibling = aSibling;
		aSibling.nextSibling = oldfirst;
		aSibling.parent = parent;

		if (parent)
		{
			parent.firstChild = aSibling;
		}

		hasChanged(izContainerChangeKind.add,aSibling);

		return 0;
	}

	/**
	 * Inserts aSibling before the one standing at aPosition.
	 * If aPosition is greater than count than aSibling is added to the end of list.
	 * Returns the sibling position when the operation is successful otherwise -1.
	 */
	@safe final ptrdiff_t insertSibling(size_t aPosition, izTreeItem aSibling)
	{
		assert(aSibling);

		if (findSibling(aSibling) > -1) return -1;

		size_t cnt = siblingCount;
		if (aPosition == 0)
		{
			insertSibling(aSibling);
			return 0;
		}
		else if (aPosition >= cnt)
		{
			addSibling(aSibling);

			assert( aSibling.siblingIndex == cnt);
			return cnt;
		}
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

					hasChanged(izContainerChangeKind.add,aSibling);

					return aPosition;
				}
				old = old.nextSibling;
				result++;
			}
		}
		return -1;
	}

	/**
	 * Permutes aSibling1 and aSibling2 positions in the list.
	 */
	@safe final void exchangeSibling(izTreeItem aSibling1, izTreeItem aSibling2)
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

		hasChanged(izContainerChangeKind.change,null);
	}

	/**
	 * Tries to removes aSibling from the list.
	 */
	@safe final bool removeSibling(izTreeItem aSibling)
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
	@safe final izTreeItem removeSibling(size_t anIndex)
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

			hasChanged(izContainerChangeKind.remove, result);
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

// children --------------------------

	/**
	 * Allocates, adds to the back and returns a new children of type IT.
	 * This method should be preferred over addChildren/insertChildren if deleteChildren() is used.
	 */
	final IT addNewChildren(IT,A...)(A a) if (is(IT : izTreeItem))
	{
		IT result = izAllocObject!IT(a);
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
	 * Returns the children count.
	 */
	@safe @property final size_t childrenCount()
	{
		auto _first = firstChild;
		if ( _first is null) return 0;
		else return _first.siblingCount;
	}

	/**
	 * Tries to add aChild to the back and returns its position.
	 */
	@safe final ptrdiff_t addChild(izTreeItem aChild)
	{
		if (!firstChild)
		{
			firstChild = aChild;
			aChild.parent = this;

			hasChanged(izContainerChangeKind.change,aChild);

			return 0;
		}
		else return firstChild.addSibling(aChild);
	}

	/**
	 * Tries to insert aChild to the front and returns its position.
	 */
	@safe final ptrdiff_t insertChild(izTreeItem aChild)
	{
		if (!firstChild)
		{
			firstChild = aChild;
			aChild.parent = this;

			hasChanged(izContainerChangeKind.change,aChild);

			return 0;
		}
		else return firstChild.insertSibling(aChild);
	}

	/**
	 * Tries to insert aChild at aPosition and returns its position.
	 */
	@safe final ptrdiff_t insertChild(size_t aPosition, izTreeItem aChild)
	{
		if (!firstChild)
		{
			firstChild = aChild;
			aChild.parent = this;

			hasChanged(izContainerChangeKind.change,aChild);

			return 0;
		}
		else return firstChild.insertSibling(aPosition, aChild);
	}

	/**
	 * Tries to removes aChild from the list.
	 */
	@safe final bool removeChild(izTreeItem aChild)
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
	 * Tries to extract the anIndex-nth child from this branch.
	 */
	@safe final izTreeItem removeChild(size_t anIndex)
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
					hasChanged(izContainerChangeKind.remove, result);
				}
				else result.nextSibling.removeSibling(anIndex);
			}
		}
		return result;
	}

	/**
	 * Removes the children.
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

				hasChanged(izContainerChangeKind.remove,current);
			}
			current = _next;

			hasChanged(izContainerChangeKind.change,current);
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
			delete current;

			// o.k but outside ptr is dangling.
			assert(current is null);

			current = _next;

			hasChanged(izContainerChangeKind.change,null);
		}
		firstChild = null;
	}

// other --------------------------

    final char[] nodeToTextNative()
    {
        char[] result;
        for (auto i = 0; i < level; i++) result ~= '\t';
        result ~= format( "Index: %.4d - NodeType: %s", siblingIndex, typeof(this).stringof);
        return result;
    }

    final void saveToStream(izStream aStream)
    {
        auto rn = "\r\n".dup;
        auto txt = nodeToTextNative;
        aStream.write( txt.ptr, txt.length );
        aStream.write( rn.ptr, rn.length );
        for (auto i = 0; i < childrenCount; i++)
            children[i].saveToStream(aStream);
    }

}

/**
 * Default implementation for the izTreeItem accessors.
 */
mixin template izTreeItemAccessors()
{
	private:
		izTreeItem fPrevSibling, fNextSibling, fFirstChild, fParent;
	
	public:
		izTreeItemSiblings fSiblings,fChild;

	public:
		/**
		 * Called by an izTreeItem to set the link to the previous izTreeItem.
		 */
		@safe @property void prevSibling(izTreeItem aSibling)
		{
			fPrevSibling = aSibling;
		}
		/**
		 * Called by an izTreeItem to set the link to the next izTreeItem.
		 */
		@safe @property void nextSibling(izTreeItem aSibling)
		{
			fNextSibling = aSibling;
		}
		/**
		 * Called by an izTreeItem to set the link to the its parent.
		 */
		@safe @property void parent(izTreeItem aParent)
		{
			fParent = aParent;
		}
		/**
		 * Called by an izTreeItem to set the link to the its first child.
		 */
		@safe @property void firstChild(izTreeItem aChild)
		{
			fFirstChild = aChild;
			fChild.item = aChild;
		}
		/**
		 * Called by an izTreeItem to get the link to the previous izTreeItem.
		 */
		@safe @property izTreeItem prevSibling()
		{
			return fPrevSibling;
		}
		/**
		 * Called by an izTreeItem to get the link to the next izTreeItem.
		 */
		@safe @property izTreeItem nextSibling()
		{
			return fNextSibling;
		}
		/**
		 * Called by an izTreeItem to get the link to the its parent.
		 */
		@safe @property izTreeItem parent()
		{
			return fParent;
		}
		/**
		 * Called by an izTreeItem to set the link to the its first child.
		 */
		@safe @property izTreeItem firstChild()
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
		 * Called by an izTreeItem to notify about the changes.
		 * When aChangeKind == izContainerChangeKind.add, data is a pointer to the new item.
		 * When aChangeKind == izContainerChangeKind.remove, data is a pointer to the old item.
		 * When aChangeKind == izContainerChangeKind.change, data is null.
		 */
		@safe void hasChanged(izContainerChangeKind aChangeKind, izTreeItem involvedItem)
		{
		}
}

/**
 * Helper template designed to make a sub class C inherit from izTreeItem.
 * The class C must have a default ctor and only this default ctor is generated.
 */
class izMakeTreeItem(C): C, izTreeItem
if ((is(C==class)))
{
	mixin izTreeItemAccessors;
}

version(unittest)
{
	private class bar{int a,b,c;}
	alias izMakeTreeItem!bar linkedBar;
	private class linkedBarTest: linkedBar
	{
		unittest
		{
			auto a = new linkedBarTest;
			assert(cast(izTreeItem)a);
			writeln("izMakeLinkedClass passed the tests");
		}
	}
}

private class foo: izObject, izTreeItem
{
	int member;
	mixin izTreeItemAccessors;

	bool changeMonitor,getMonitor;

	@safe final void hasChanged(izContainerChangeKind aChangeKind, izTreeItem involvedItem)
	{
		changeMonitor = true;
	}
	@safe @property final izTreeItem nextSibling()
	{
		getMonitor = true;
		return fNextSibling;
	}

	unittest
	{

		foo Foos[20];
		foo Driver;

		Foos[0] = new foo;
		Driver = Foos[0];
		for (auto i =1; i < Foos.length; i++)
		{
			Foos[i] = new foo;
			if (i>0) Driver.addSibling( Foos[i] );
			assert( Foos[i].siblingIndex == i );
			assert( Driver.siblings[i].siblingIndex == i );
			assert( Driver.siblings[i] == Foos[i] );
			if (i>0) assert( Foos[i].prevSibling.siblingIndex == i-1 );
			assert(Driver.lastSibling.siblingIndex == i);
		}
		assert(Driver.siblingCount == Foos.length);

		assert(Foos[1].nextSibling.siblingIndex == 2);
		assert(Foos[1].prevSibling.siblingIndex == 0);

		Driver.exchangeSibling(Foos[10],Foos[16]);
		assert(Driver.siblingCount == Foos.length);
		assert( Foos[10].siblingIndex == 16);
		assert( Foos[16].siblingIndex == 10);

		Driver.exchangeSibling(Foos[10],Foos[16]);
		assert(Driver.siblingCount == Foos.length);
		assert( Foos[10].siblingIndex == 10);
		assert( Foos[16].siblingIndex == 16);


		Foos[8].siblingIndex = 4;
		assert( Foos[8].siblingIndex == 4);
		//assert( Foos[4].siblingIndex == 5); // when siblingIndex() calls remove/insert
		//assert( Foos[4].siblingIndex == 8); // when siblingIndex() calls exchangeSibling.

		assert( Driver.siblings[16] == Foos[16]);
		assert( Driver.siblings[10] == Foos[10]);
		Driver.siblings[16] = Foos[10]; // exchg
		assert(Driver.siblingCount == Foos.length);
		Driver.siblings[16] = Foos[16]; // exchg
		assert(Driver.siblingCount == Foos.length);
		assert( Foos[16].siblingIndex == 16);
		assert( Foos[10].siblingIndex == 10);


		auto C = new foo;
		Driver.siblings[10] = C;
		Driver.siblings[16] = Foos[10];
		assert( Foos[16].siblingIndex == 0);
		assert( Foos[10].siblingIndex == 16);
		assert( C.siblingIndex == 10);

		assert(Driver.findSibling(Foos[18]) > -1);
		assert(Driver.findSibling(Foos[0]) > -1);

		// remember that "item" type is the interface not its implementer.
		foreach(izTreeItem item; Driver.siblings)
		{
			assert(Driver.findSibling(item) == item.siblingIndex);
			assert( cast(foo) item);
		}
		foreach_reverse(item; Driver.siblings)
		{
			assert(Driver.findSibling(item) == item.siblingIndex);
		}

		Driver.removeSibling(19);
		assert(Driver.siblingCount == Foos.length -1);
		Driver.removeSibling(18);
		assert(Driver.siblingCount == Foos.length -2);
		Driver.removeSibling(Foos[13]);
		assert(Driver.siblingCount == Foos.length -3);
		//Driver[0] = null; // exception because Driver[0] = Driver
		assert(Driver.siblingCount == Foos.length -3);
		Driver.siblings[1] = null;
		assert(Driver.siblingCount == Foos.length -4);

		assert(Driver.changeMonitor);
		assert(Driver.getMonitor);

		//

		foo Items1[20];
		foo Items2[20][4];

		assert( Items1[12] is null);
		assert( Items2[12][0] is null);
		assert( Items2[18][3] is null);

		foo Root;
		Root = new foo;
		assert(Root.level == 0);
		for (auto i=0; i < Items1.length; i++)
		{
			Items1[i] = new foo;
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
				Items2[i][j] = new foo;
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
		Root.addNewChildren!foo();
			Root.children[0].addNewChildren!foo();
			Root.children[0].addNewChildren!foo();
			Root.children[0].addNewChildren!foo();
		Root.addNewChildren!foo();
			Root.children[1].addNewChildren!foo();
			Root.children[1].addNewChildren!foo();
			Root.children[1].addNewChildren!foo();
			Root.children[1].addNewChildren!foo();
				Root.children[1].children[3].addNewChildren!foo();
				Root.children[1].children[3].addNewChildren!foo();
				Root.children[1].children[3].addNewChildren!foo();

		assert(Root.childrenCount == 2);
		assert(Root.children[0].childrenCount == 3);
		assert(Root.children[1].childrenCount == 4);
		assert(Root.children[1].children[3].childrenCount == 3);
		assert(Root.children[1].children[3].children[0].level == 3);

        auto str = new izMemoryStream;
        Root.saveToStream(str);
        //str.saveToFile(r"C:\izTreeNodes.txt");
        str.demolish;

		Root.deleteChildren;

		writeln("izTreeItem passed the tests");
	}
}
