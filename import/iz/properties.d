module iz.properties;

import 
	core.exception,
	std.stdio, std.traits, std.conv, std.typetuple, std.typecons,
	iz.types, iz.containers;
		
/**
 * Flags used to describe the accessors combination.
 */
enum izPropAccess 
{
	none, /// denotes an error, no accessors.
	ro,	  /// read-only, has only a getter.
	wo,	  /// write-only, has only a dSetter.
	rw	  /// read & write, has both accessors.
};	
	
/**
 * Describes the property of type T of an Object. Its members includes:
 * <li> a setter: either as an izPropSetter method or as pointer to the field.</li>
 * <li> a getter: either as an izPropGetter method or as pointer to the field.</li>
 * <li> a name: optionally used, according to the context.</li>
 * <li> a declarator: the Object declaring the props. the declarator is automatically set
 *		when the descriptor uses at least one accessor method.</li>
 */
struct izPropDescriptor(T)
{
	public
	{
		/// standard setter proptotype
		alias izPropSetter = void delegate (T value);
		/// standard getter prototype
		alias izPropGetter = T delegate();
		
		/// alternative setter kind. Internally casted as a izPropSetter.
		alias izPropSetterConst = void delegate (const T value);
	}
	private
	{
		izPropSetter fSetter;
		izPropGetter fGetter;
		Object fDeclarator;

		T* fSetPtr;
		T* fGetPtr;

		izPropAccess fAccess;

		char[] fName;

		void updateAccess()
		{
			if ((fSetter is null) && (fGetter !is null))
				fAccess = izPropAccess.ro;
			else if ((fSetter !is null) && (fGetter is null))
				fAccess = izPropAccess.wo;
			else if ((fSetter !is null) && (fGetter !is null))
				fAccess = izPropAccess.rw;
			else fAccess = izPropAccess.none;	
			
			if (fAccess == izPropAccess.none) 
				throw new Exception("property descriptor has no accessors");
		}
		
		/// pseudo setter internally used when a T is directly written.
		void internalSetter(T value)
		{
			T current = getter()();
			if (value != current) *fSetPtr = value;
		}
		
		/// pseudo getter internally used when a T is directly read
		T internalGetter()
		{
			return *fGetPtr;
		}
	}
	public
	{
		static immutable ubyte DescriptorFormat = 0;
		
		this(in char[] aName = "")
		{
			if (aName != "") {name(aName);}
		}
		
		/**
		 * Constructs a property descriptor from an izPropSetter and an izPropGetter method.
		 */	 
		this(izPropSetter aSetter, izPropGetter aGetter, in char[] aName = "")
		in
		{
			assert(aSetter);
			assert(aGetter);
		}
		body
		{
			define(aSetter, aGetter, aName);
		}
		
		/**
		 * Constructs a property descriptor from an izPropSetterConst and an izPropGetter method.
		 */	 
		this(izPropSetterConst aSetter, izPropGetter aGetter, in char[] aName = "")
		in
		{
			assert(aSetter);
			assert(aGetter);
		}
		body
		{
			define(cast(izPropSetter)aSetter, aGetter,aName);
		}
		
		/**
		 * Constructs a property descriptor from an izPropSetter method and a direct variable.
		 */
		this(izPropSetter aSetter, T* aSourceData, in char[] aName = "")
		in
		{
			assert(aSetter);
			assert(aSourceData);
		}
		body
		{
			define(aSetter, aSourceData, aName);
		}
		
		/**
		 * Constructs a property descriptor from a single variable used as source/target
		 */
		this(T* aData, in char[] aName = "")
		in
		{
			assert(aData);
		}
		body
		{
			define(aData, aName);
		}
	
// define all props ---------------
	
		/**
		 * Defines a property descriptor from an izPropSetter and an izPropGetter.
		 */
		void define(izPropSetter aSetter, izPropGetter aGetter, in char[] aName = "")
		{
			setter(aSetter);
			getter(aGetter);
			if (aName != "") {name(aName);}
			fDeclarator = cast(Object) aSetter.ptr;
		}
		
		/**
		 * Defines a property descriptor from an izPropSetter method and a direct variable.
		 */
		void define(izPropSetter aSetter, T* aSourceData, in char[] aName = "")
		{
			setter(aSetter);
			setDirectSource(aSourceData);
			if (aName != "") {name(aName);}
			fDeclarator = cast(Object) aSetter.ptr;
		}		
		/**
		 * Defines a property descriptor from a single data used as source/target
		 */
		void define(T* aData, in char[] aName = "", Object aDeclarator = null)
		{
			setDirectSource(aData);
			setPropTarget(aData);
			if (aName != "") {name(aName);}
			fDeclarator = aDeclarator;
		}
		
// setter ---------------
		
		/**
		 * Sets the property setter using a standard method.
		 */
		@property void setter(izPropSetter aSetter)
		{
			fSetter = aSetter;
			fDeclarator = cast(Object) aSetter.ptr;
			updateAccess;
		}
		/// ditto
		@property izPropSetter setter(){return fSetter;}	
		/**
		 * Sets the property setter using a pointer to a direct data
		 */
		void setPropTarget(T* aLoc)
		{
			fSetPtr = aLoc;
			fSetter = &internalSetter;
			updateAccess;
		}
	
// getter ---------------
	
		/** 
		 * Sets the property getter using a standard method.
		 */
		@property void getter(izPropGetter aGetter)
		{
			fGetter = aGetter;
			fDeclarator = cast(Object) aGetter.ptr;
			updateAccess;
		}
		/// ditto
		@property izPropGetter getter(){return fGetter;}	
		/** 
		 * Sets the property getter using a pointer to a direct data
		 */
		void setDirectSource(T* aLoc)
		{
			fGetPtr = aLoc;
			fGetter = &internalGetter;
			updateAccess;
		}
		
// misc ---------------		
		
		/** 
		 * Informs about the prop accessibility
		 */
		@property const(izPropAccess) access()
		{
			return fAccess;
		}	
		/** 
		 * Defines a string used to identify the prop
		 */
		@property void name(in char[] aName)
		{
			fName = aName.dup;
		}
		/// ditto
		@property string name()
		{
			return fName.idup;
		}
		/**
		 * Defines the object declaring the property.
		 */
		@property void declarator(Object aDeclarator)
		{
			fDeclarator = aDeclarator;
		}
		/// ditto
		@property Object declarator(){return fDeclarator;}
	}	
}

version(unittest) 
{
	class A
	{
		private int fi;
		@property int i(){return fi;}
		@property void i(in int aValue){fi = aValue;}
	}
	struct si{uint f,r,e;}
	class B
	{		
		private si fi;
		@property si i(){return fi;}
		@property void i(const si aValue){fi = aValue;}
	}
	class propdescrtest
	{
		unittest
		{	
			auto a = new A;
			auto descrAi = izPropDescriptor!int(&a.i,&a.i,"I");
			descrAi.setter()(5);
			assert(a.i == 5);
			assert(a.i == descrAi.getter()());
			assert(descrAi.declarator is a);
			
			auto refval = si(1,2,333);
			auto b = new B;
			auto descrBi = izPropDescriptor!si(&b.i,&b.i,"I");
			descrBi.setter()(refval);
			assert(b.i.e == 333);
			assert(b.i.e == descrBi.getter()().e);
		
			writeln("izPropDescriptor(T) passed the tests");
		}	
	}
}


template genPropFromField(propType, string propName, string propField)
{
	string genPropFromField()
	{
		return
			"@property void "~ propName ~ "(" ~ propType.stringof ~ " aValue)" ~
			"{ " ~ propField ~ " = aValue;} " ~
			"@property " ~ propType.stringof ~ " " ~ propName ~
			"(){ return " ~ propField ~ ";}" ;
	}
}


template genStandardPropDescriptors()
{
	char[] genStandardPropDescriptors()
	{
		char[] result;
		foreach(T; izConstantSizeTypes)
		{
			//result ~= ("/// Describes an " ~ T.stringof ~ ".\r\n").dup; // https://issues.dlang.org/show_bug.cgi?id=648
			result ~= ("alias " ~ T.stringof ~ "prop =	izPropDescriptor!(" ~ T.stringof ~ ")" ~ ";\r\n").dup;
		}
		return result;
	}
}

/// Property descriptors for the built-in types defined in izConstantSizeTypes.
mixin(genStandardPropDescriptors);


/**
 * Property synchronizer.
 *
 * This binder can be used to implement
 * some Master/Slave links but also some
 * interdependent links. In the last case
 * it's mandatory for a setter to filter any duplicated value.
 *
 * Properties to add must be described according to the the izPropDescriptor format.
 * The izPropDescriptor name field can be omitted.
 */
class izPropertyBinder(T): izObject
{
	private
	{
		izDynamicList!(izPropDescriptor!T *) fToFree;
		izDynamicList!(izPropDescriptor!T *) fItems;
		izPropDescriptor!T *fSource;
	}
	public
	{
		this()
		{
			fItems = new izDynamicList!(izPropDescriptor!T *);
			fToFree = new izDynamicList!(izPropDescriptor!T *);
		}
		~this()
		{
			for(auto i = 0; i < fToFree.count; i++)
			{
				auto descr = fToFree[i];
				if (descr) delete(descr);
			}
			delete fItems;
			delete fToFree;
		}
		/**
		 * Add a property to the list.
		 * If the binder is not local then aProp should neither be a stack allocated descriptor.
		 */
		ptrdiff_t addBinding(ref izPropDescriptor!T aProp, bool isSource = false)
		{
			if (isSource) fSource = &aProp;
			return fItems.add(&aProp);
		}

		/**
		 * Add a new property to the list.
		 * The binder handles its life-time.
		 */
		izPropDescriptor!T * newBinding()
		{
			auto result = new izPropDescriptor!T;
			fItems.add(result);
			fToFree.add(result);
			return result;
		}

		/**
		 * Remove the aIndex-nth property from the list.
		 */
		void removeBinding(size_t anIndex)
		{
			auto itm = fItems.extract(anIndex);
			fToFree.remove(*itm);
		}
		/**
		 * Triggers the setter of each property.
		 * This method is usually called at the end of
		 * a setter method (the "master/source" prop).
		 * When some interdependent bindings are used
		 * change() must be called for each property
		 * setter of the list.
		 */
		void change(T aValue)
		{
			foreach(item; fItems)
			{
				if (item.access == izPropAccess.none) continue;
				if (item.access == izPropAccess.ro) continue;
				item.setter()(aValue);
			}
		}
		/**
		 * Call change() using the value of source.
		 */
		void UpdateFromSource()
		{
			if (!fSource) return;
			change(fSource.getter()());
		}
		/**
		 * Sets the property used as source in UpdateFromSource().
		 */
		@property void source(ref izPropDescriptor!T aSource){fSource = &aSource;}
		/**
		 * access to the items for additional izList operations.
		 */
		@property izList!(izPropDescriptor!T *) items()
		{
			return fItems;
		}	
	}
}	

private class izPropertyBinderTester
{
	unittest
	{
		alias intprops = izPropertyBinder!int;
		alias floatprops = izPropertyBinder!float;

		class foo
		{
			private
			{
				int fA;
				float fB;
				intprops fASlaves;
				floatprops fBSlaves;
			}
			public
			{
				this()
				{
					fASlaves = new intprops;
					fBSlaves = new floatprops;
				}
				~this()
				{
					delete fASlaves;
					delete fBSlaves;
				}
				void A(int value)
				{
					if (fA == value) return;
					fA = value;
					fASlaves.change(fA);
				}
				int A(){return fA;}

				void B(float value)
				{
					if (fB == value) return;
					fB = value;
					fBSlaves.change(fB);
				}
				float B(){return fB;}

				void AddABinding(ref intprop aProp)
				{
					fASlaves.addBinding(aProp);
				}

				void AddBBinding(ref floatprop aProp)
				{
					fBSlaves.addBinding(aProp);
				}
			}
		}

		class foosync
		{
			private
			{
				int fA;
				float fB;
			}
			public
			{
				void A(int value){fA = value;}
				int A(){return fA;}
				void B(float value){fB = value;}
				float B(){return fB;}
			}
		}

		class bar: Object
		{
			public int A;
			public float B;
		}

		// 1 master, 2 slaves
		auto a0 = new foo;
		auto a1 = new foosync;
		auto a2 = new foosync;
		auto a3 = new bar;

		auto prp1 = intprop(&a1.A,&a1.A);
		a0.AddABinding(prp1);

		auto prp2 = intprop(&a2.A,&a2.A);
		a0.AddABinding(prp2);

		intprop prp3 = intprop(&a3.A);
		a0.AddABinding(prp3);

		auto prpf1 = floatprop(&a1.B,&a1.B);
		auto prpf2 = floatprop(&a2.B,&a2.B);
		auto prpf3 = floatprop(&a3.B);
		a0.AddBBinding(prpf1);
		a0.AddBBinding(prpf2);
		a0.AddBBinding(prpf3);

		a0.A = 2;
		assert( a1.A == a0.A);
		a1.A = 3;
		assert( a1.A != a0.A);
		a0.A = 4;
		assert( a2.A == a0.A);
		a0.A = 5;
		assert( a3.A == a0.A);

		a0.B = 2.5;
		assert( a1.B == a0.B);
		a1.B = 3.5;
		assert( a1.B != a0.B);
		a0.B = 4.5;
		assert( a2.B == a0.B);
		a0.B = 5.5;
		assert( a3.B == a0.B);

		// interdependent bindings
		auto m0 = new foo;
		auto m1 = new foo;
		auto m2 = new foo;

		intprop mprp0 = intprop(&m0.A, &m0.A);
		intprop mprp1 = intprop(&m1.A, &m1.A);
		intprop mprp2 = intprop(&m2.A, &m2.A);


		m0.AddABinding(mprp1);
		m0.AddABinding(mprp2);

		m1.AddABinding(mprp0);
		m1.AddABinding(mprp2);

		m2.AddABinding(mprp0);
		m2.AddABinding(mprp1);

		m0.A = 2;
		assert( m1.A == m0.A);
		assert( m2.A == m0.A);
		m1.A = 3;
		assert( m0.A == m1.A);
		assert( m2.A == m1.A);
		m2.A = 4;
		assert( m1.A == m2.A);
		assert( m0.A == m2.A);

		delete a0;
		delete a1;
		delete a2;
		delete a3;
		delete m0;
		delete m1;
		delete m2;

		writeln("izPropertyBinder(T) passed the tests");
	}
}

unittest
{
	auto strSync = new izPropertyBinder!int;

	class a
	{
		private int fStr;
		public @property str(int aValue){fStr = aValue;}
		public @property int str(){return fStr;}
	}

	auto a0 = new a;
	auto a1 = new a;
	auto a2 = new a;

	auto propa0str = strSync.newBinding;
	propa0str.define(&a0.str,&a0.str);
	auto propa1str = strSync.newBinding;
	propa1str.define(&a1.str,&a1.str);
	auto propa2str = strSync.newBinding;
	propa2str.define(&a2.str,&a2.str);

	strSync.change(8);

	assert(a0.str == 8);
	assert(a1.str == 8);
	assert(a2.str == 8);

	delete a0;
	delete a1;
	delete a2;
	delete strSync;

	writeln("izPropertyBinder(T) passed the newBinding() test");
}
