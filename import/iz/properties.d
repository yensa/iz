module iz.properties;

import std.traits;
import iz.memory, iz.types, iz.containers;

/**
 * Describes the accessibility of a property.
 */
enum PropAccess
{
    /// denotes an error.
    none,
    /// read-only.
    ro,
    /// write-only.
    wo,
    /// read & write.
    rw
}   

/**
 * Describes the property of type T of an Object. Its members includes:
 * <li> a setter: either as an PropSetter method or as pointer to the field.</li>
 * <li> a getter: either as an PropGetter method or as pointer to the field.</li>
 * <li> a name: optionally used, according to the context.</li>
 * <li> a declarator: the Object declaring the props. the declarator is automatically set
 *      when the descriptor uses at least one accessor method.</li>
 */
struct PropDescriptor(T)
{
    public
    {
        /// setter proptotype
        alias PropSetter = void delegate(T value);
        /// getter prototype
        alias PropGetter = T delegate();
        /// alternative setter prototype.
        alias PropSetterConst = void delegate(const T value);
    }
    private
    {
        PropSetter _setter;
        PropGetter _getter;
        Object fDeclarator;
        RuntimeTypeInfo _rtti;

        string _referenceID;

        T* _setPtr;
        T* _getPtr;

        PropAccess _access;

        string fName;

        void cleanup()
        {
            _setPtr = null;
            _getPtr = null; 
            _setter = null;
            _getter = null;
            fDeclarator = null;
            _access = PropAccess.none;
            fName = fName.init;
        }

        void updateAccess()
        {
            if ((_setter is null) && (_getter !is null))
                _access = PropAccess.ro;
            else if ((_setter !is null) && (_getter is null))
                _access = PropAccess.wo;
            else if ((_setter !is null) && (_getter !is null))
                _access = PropAccess.rw;
            else _access = PropAccess.none;
        }

        /// pseudo setter internally used when a T is directly written.
        void internalSetter(T value)
        {
            alias TT = Unqual!T;
            const T current = getter()();
            if (value != current) *(cast(TT*)_setPtr) = value;
        }

        /// pseudo getter internally used when a T is directly read
        T internalGetter()
        {
            return *_getPtr;
        }
    }
    public
    {
        /// version number that can be used in case of breaking change.
        static immutable ubyte descriptorFormat = 0;

// constructors ---------------------------------------------------------------+
        /**
         * Constructs a property descriptor from an PropSetter and an PropGetter method.
         */  
        this(PropSetter aSetter, PropGetter aGetter, string aName = "")
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
         * Constructs a property descriptor from an PropSetterConst and an PropGetter method.
         */  
        this(PropSetterConst aSetter, PropGetter aGetter, string aName = "")
        in
        {
            assert(aSetter);
            assert(aGetter);
        }
        body
        {
            define(cast(PropSetter)aSetter, aGetter,aName);
        }

        /**
         * Constructs a property descriptor from an PropSetter method and a direct variable.
         */
        this(PropSetter aSetter, T* aSourceData, string aName = "")
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
        this(T* aData, string aName = "")
        in
        {
            assert(aData); 
        }
        body
        {
            define(aData, aName);
        }
// ---- 
// define all the members -----------------------------------------------------+

        /**
         * Defines a property descriptor from an PropSetter and an PropGetter.
         */
        void define(PropSetter aSetter, PropGetter aGetter, string aName = "")
        {
            cleanup;
            _rtti = runtimeTypeInfo!T;
            setter(aSetter);
            getter(aGetter);
            if (aName != "") {name(aName);}
            fDeclarator = cast(Object) aSetter.ptr;
        }

        /**
         * Defines a property descriptor from an PropSetter method and a direct variable.
         */
        void define(PropSetter aSetter, T* aSourceData, string aName = "")
        {
            cleanup;
            _rtti = runtimeTypeInfo!T; 
            setter(aSetter);
            setDirectSource(aSourceData);
            if (aName != "") {name(aName);}
            fDeclarator = cast(Object) aSetter.ptr;
        }
        /**
         * Defines a property descriptor from a single variable used as source/target
         */
        void define(T* aData, string aName = "", Object aDeclarator = null)
        {
            cleanup;
            _rtti = runtimeTypeInfo!T;
            setDirectSource(aData);
            setDirectTarget(aData);
            if (aName != "") {name(aName);}
            fDeclarator = aDeclarator;
        }
// ----
// setter ---------------------------------------------------------------------+

        /**
         * Sets the property setter using a standard method.
         */
        @property void setter(PropSetter aSetter)
        {
            _setter = aSetter;
            fDeclarator = cast(Object) aSetter.ptr;
            updateAccess;
        }
        /// ditto
        @property PropSetter setter(){return _setter;}
        /**
         * Sets the property setter using a pointer to a variable
         */
        void setDirectTarget(T* aLoc)
        {
            _setPtr = aLoc;
            _setter = &internalSetter;
            updateAccess;
        }
        /**
         * Sets the property value
         */
        void set(T aValue) {_setter(aValue);}

// ---- 
// getter ---------------------------------------------------------------------+

        /** 
         * Sets the property getter using a standard method.
         */
        @property void getter(PropGetter aGetter)
        {
            _getter = aGetter;
            fDeclarator = cast(Object) aGetter.ptr;
            updateAccess;
        }
        /// ditto
        @property PropGetter getter(){return _getter;}
        /** 
         * Sets the property getter using a pointer to a variable
         */
        void setDirectSource(T* aLoc)
        {
            _getPtr = aLoc;
            _getter = &internalGetter;
            updateAccess;
        }
        /**
         * Gets the property value
         */
        T get(){return _getter();}

// ----     
// misc -----------------------------------------------------------------------+

        /** 
         * Information about the prop accessibility
         */
        @property const(PropAccess) access()
        {
            return _access;
        }
        /** 
         * Defines a string used to identify the prop
         */
        @property void name(string aName)
        {
            fName = aName;
        }
        /// ditto
        @property string name()
        {
            return fName;
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
        /**
         * Returns the RuntimeTypeInfo struct for the property type.
         */
        @property const(RuntimeTypeInfo*) rtti(){return &_rtti;}
        /**
         * Defines the reference matching to the property value.
         * This is only used as a helper when the property value is
         * a fat pointer (e.g a delegate) and to serialiaze.
         */
        @property string referenceID(){return _referenceID;}
        /// ditto
        @property referenceID(string value){_referenceID = value;}
// ----        

    }
}

version(unittest)
{
    import std.stdio;
    class A
    {
        private int fi;
        @property int i(){return fi;}
        @property void i(in int aValue){fi = aValue;}
    }
    struct Si{uint f,r,e;}
    class B
    {
        private Si fi;
        @property Si i(){return fi;}
        @property void i(const Si aValue){fi = aValue;}
    }
    class propdescrtest
    {
        unittest
        {
            auto a = construct!A;
            auto descrAi = PropDescriptor!int(&a.i,&a.i,"I");
            descrAi.setter()(5);
            assert(a.i == 5);
            assert(a.i == descrAi.getter()());
            assert(descrAi.declarator is a);

            auto refval = Si(1,2,333);
            auto b = construct!B;
            auto descrBi = PropDescriptor!Si(&b.i,&b.i,"I");
            descrBi.setter()(refval);
            assert(b.i.e == 333);
            assert(b.i.e == descrBi.getter()().e);

            destruct(a,b);
            writeln("PropDescriptor(T) passed the tests");
        }
    }
}

/// designed to annotate a detectable property setter.
struct Set;
/// designed to annotate a detectable property getter. 
struct Get;
/// designed to annotate a detectable "direct" field.
struct SetGet;
/// ditto
alias GetSet = SetGet;
/// designed to make undetectable a property collected in a ancestor.
struct HideSet;
/// ditto
struct HideGet;

/**
 * When mixed in an agregate this generates a property. 
 * This property is detectable by a PropDescriptorCollector.
 * Params:
 * T = the type of the property.
 * propName = the name of the property.
 * propField = the identifier of the existing field of type T.
 */
string genPropFromField(T, string propName, string propField)()
{
    return
    "@Set void " ~ propName ~ "(" ~ T.stringof ~ " aValue)" ~
    "{ " ~ propField ~ " = aValue;} " ~
    "@Get " ~ T.stringof ~ " " ~ propName ~
    "(){ return " ~ propField ~ ";}" ;
}

private string genStandardPropDescriptors()
{
    string result;
    foreach(T; BasicTypes)
    {
        result ~= ("public alias " ~ T.stringof ~ "Prop = PropDescriptor!(" ~
            T.stringof ~ ")" ~ "; ");
    }
    return result;
}

/// Property descriptors for the types defined in the izConstantSizeTypes tuple.
mixin(genStandardPropDescriptors);


/**
 * Interfaces the PropDescriptorCollector methods.
 * The methods don't have to be implemented by hand as it's automatically done 
 * when the PropDescriptorCollector template is mixed in a class.
 */
interface PropDescriptorCollection
{
    /**
     * Returns the count of descriptor the analyzers have created.
     */
    size_t propCollectorCount();
    /**
     * Returns a pointer to a descriptor according to its name.
     * Similar to the propCollectorGet() function template excepted that the
     * result type has not to be specified.
     */
    void* propCollectorGetPtrByName(string name);
    /**
     * Returns a pointer an indexed descriptor.
     * index must be with the 0 .. propCollectorCount range.
     */
    void* propCollectorGetPtrByIndex(size_t index);
    /**
     * Returns a pointer to the RTTI for the nth descriptor.
     * index must be with the 0 .. propCollectorCount range.
     * This allows to cast properly the result of propCollectorGetPtr.
     */
    const(RuntimeTypeInfo*) propCollectorGetType(size_t index);
}

/**
 * When mixed in a class or a struct, two analyzers can be used to create
 * automatically the PropDescriptors for the properties setter and getter pairs
 * anotated with @Set and @Get or the fields annotated with @SetGet.
 *
 * The analyzers are usually called in this(). The template has to be mixed in
 * each class generation that introduces new annotated properties.
 * The analyzers, propCollectorGetPairs and propCollectorGetFields are
 * function templates so they must be instantiated with the type they have
 * to scan (usually typeof(this)). The two analyzers can be called with a
 * third function template: propCollectorAll().
 */
mixin template PropDescriptorCollector()
{
    /**
     * Contains the list of izPropDesrcriptors created by the analyzers.
     * propCollectorGet() can be used to correctly cast an item.
     */
    static if (!__traits(hasMember, typeof(this), "_collectedDescriptors"))
    protected void*[] _collectedDescriptors;

// virtual methods or PropDescriptorCollection methods
//
// static if: the template injects some virtual methods that don't need
// to be overriden
// oror Base: because it looks like the interface makes the members
// detectable even if not yet implemented.

    import std.traits: BaseClassesTuple;
    alias ToT = typeof(this);
    // descendant already implements the interface
    enum BaseHas = is(BaseClassesTuple!ToT[0] : PropDescriptorCollection);
    enum HasItf = is(ToT : PropDescriptorCollection);
    // interface must be implemented from this generation, even if methods detected
    enum Base = HasItf & (!BaseHas);

    /// see PropDescriptorCollection
    static if (!__traits(hasMember, ToT, "propCollectorCount") || Base)
    public size_t propCollectorCount() {return _collectedDescriptors.length;}

    /// see PropDescriptorCollection
    static if (!__traits(hasMember, ToT, "propCollectorGetPtrByName") || Base)
    protected void* propCollectorGetPtrByName(string name)
    {return propCollectorGet!size_t(name);}

    /// see PropDescriptorCollection
    static if (!__traits(hasMember, ToT, "propCollectorGetPtrByIndex") || Base)
    protected void* propCollectorGetPtrByIndex(size_t index)
    {return _collectedDescriptors[index];}

    /// see PropDescriptorCollection
    static if (!__traits(hasMember, ToT, "propCollectorGetType") || Base)
    protected const(RuntimeTypeInfo*) propCollectorGetType(size_t index)
    {return (cast(PropDescriptor!int*) _collectedDescriptors[index]).rtti;}

// templates: no problem with overrides, instantiated according to class This or That

    /**
     * Returns a pointer to a descriptor according to its name.
     * Params:
     *      T = T type of the property.
     *      name = the identifier used for the setter and the getter.
     *      createIfMissing = when set to true, the result is never null.
     * Returns:
     *      null if the operation fails otherwise a pointer to a PropDescriptor!T.
     */
    protected PropDescriptor!T * propCollectorGet(T)(string name, bool createIfMissing = false)
    {
        PropDescriptor!T * descr;

        for(auto i = 0; i < _collectedDescriptors.length; i++)
        {
            auto maybe = cast(PropDescriptor!T *) _collectedDescriptors[i];
            if (maybe.name != name) continue;
            descr = maybe; break;
        }

        if (createIfMissing && !descr)
        {
            descr = new PropDescriptor!T;
            descr.name = name;
            _collectedDescriptors ~= descr;
        }
        return descr;
    }

    /**
     * Performs all the possible analysis.
     */
    protected void propCollectorAll(T)()
    {
        propCollectorGetFields!T;
        propCollectorGetPairs!T;
    }

    /**
     * Creates the properties descriptors for each field annotated with @SetGet
     * and whose identifier starts with one of these prefixes: underscore, f, F.
     * The .name property of the descriptors don't include the prefix.
     */
    protected void propCollectorGetFields(T)()
    {
        import iz.types: ScopedReachability;
        import std.traits: isCallable, isDelegate, isFunctionPointer;

        bool isFieldPrefix(char c)
        {return c == '_' || c == 'f' || c == 'F';}
        enum getStuff = q{__traits(getMember, T, member)};

        // here 'cast(T)this' work without remixing in sub classes

        mixin ScopedReachability;
        foreach(member; __traits(allMembers, T))
        static if (isMemberReachable!(T, member))
        static if (!isCallable!(mixin(getStuff)) || isDelegate!(mixin(getStuff))
            || isFunctionPointer!(mixin(getStuff)))
        {
            foreach(attribute; __traits(getAttributes, __traits(getMember, this, member)))
            static if (is(attribute == SetGet)) 
            {
                alias propType = typeof(__traits(getMember, this, member));
                auto propPtr = &__traits(getMember, this, member);
                static if (isFieldPrefix(member[0]))
                auto propName = member[1..$];
                else auto propName = member;
                auto descriptor = propCollectorGet!propType(propName, true);
                descriptor.define(propPtr, propName);
                //
                version(none) writeln(attribute.stringof, " : ", member);
                break;
            }
        }
    }
    
    /**
     * Creates the property descriptors for the setter/getter pairs 
     * annotated with @Set/@Get.
     *
     * In a class hierarchy, an overriden accessor replaces the ancestor's one.
     * If a setter is annoted with @HideSet or a getter with @HideGet then
     * the descriptor created by analysing an ancestor is removed from the
     * collection.
     */
    protected void propCollectorGetPairs(T)()
    {
        import iz.types: ScopedReachability, runtimeTypeInfo;
        import std.traits: isCallable, Parameters, ReturnType;
        import std.meta: AliasSeq, staticIndexOf;
        import std.algorithm.mutation: remove;
        import std.algorithm.searching: countUntil;

        // here 'cast(T)this' does not work without remixing in sub classes
        // because of the '&overload'

        mixin ScopedReachability;
        foreach(member; __traits(allMembers, T))
        static if (isMemberReachable!(T, member))
        foreach(overload; __traits(getOverloads, T, member))
        {
            alias Attributes = AliasSeq!(__traits(getAttributes, overload));
            enum getterAttrib = staticIndexOf!(Get, Attributes) != -1;
            enum setterAttrib = staticIndexOf!(Set, Attributes) != -1;
            enum ungetAttrib = staticIndexOf!(HideGet, Attributes) != -1;
            enum unsetAttrib = staticIndexOf!(HideSet, Attributes) != -1;

            static if (getterAttrib && !ungetAttrib && isCallable!overload)
            {
                alias Type = ReturnType!overload;
                alias DescriptorType = PropDescriptor!Type;
                auto descriptor = propCollectorGet!(Type)(member, true);
                auto dg = &overload;
                version(assert) if (descriptor.setter) assert (
                    // note: rtti unqalifies the type
                    runtimeTypeInfo!Type == *descriptor.rtti,
                    "setter and getter types mismatch");
                descriptor.define(descriptor.setter, dg, member);
                //   
                version(none) writeln(attribute.stringof, " < ", member);
            }
            else static if (setterAttrib && !unsetAttrib && isCallable!overload)
            {
                alias Type = Parameters!overload;
                version(assert) static assert(Type.length == 1,
                    "setter must only have one parameter");
                alias DescriptorType = PropDescriptor!Type;
                auto descriptor = propCollectorGet!(Parameters!overload)(member, true);
                auto dg = &overload;
                version(assert) if (descriptor.getter) assert (
                    runtimeTypeInfo!Type == *descriptor.rtti,
                    "setter and getter type mismatch");
                descriptor.define(dg, descriptor.getter, member);
                //
                version(none) writeln(attribute.stringof, " > ", member);
            }
            else static if ((ungetAttrib | unsetAttrib) && isCallable!overload)
            {
                auto descr = propCollectorGet!size_t(member, false);
                if (descr)
                {
                    auto index = countUntil(_collectedDescriptors, descr);
                    assert(index != -1);
                    _collectedDescriptors = remove(_collectedDescriptors, index);
                }
            }
        }
    }
}

version(unittest)
{
    unittest
    {
        mixin ScopedReachability;
        assert(isMemberReachable!(Foo, "_anUint"));
    }

    class Foo
    {
        mixin PropDescriptorCollector;
        this(A...)(A a)
        {
            propCollectorGetPairs!Foo;
            propCollectorGetFields!Foo;
        }

        @SetGet private uint _anUint;
        @SetGet private static char[] _manyChars;
        private uint _a, _b;
        private char[] _c;

        @Get uint propA(){return _a;}
        @Set void propA(uint aValue){_a = aValue;}

        @Get uint propB(){return _b;} 
        @Set void propB(uint aValue){_b = aValue;}
        
        @Get char[] propC(){return _c;} 
        @Set void propC(char[] aValue){_c = aValue;}

        void use()
        {
            assert(propA == 0);
            auto aDescriptor = propCollectorGet!uint("propA");
            aDescriptor.setter()(123456789);
            assert(propA == 123456789);

            assert(propB == 0);
            auto bDescriptor = propCollectorGet!uint("propB");
            bDescriptor.setter()(987654321);
            assert(propB == 987654321);

            assert(!propC.length);
            auto cDescriptor = propCollectorGet!(char[])("propC");
            cDescriptor.setter()("Too Strange To Be Good".dup);
            assert(propC == "Too Strange To Be Good");
            propC = "Too Good To Be Strange".dup;
            assert( propCollectorGet!(char[])("propC").getter()() == "Too Good To Be Strange");

            assert(_anUint == 0);
            auto anUintDescriptor = propCollectorGet!uint("anUint");
            anUintDescriptor.setter()(123456789);
            assert(_anUint == 123456789);

            assert(_manyChars == null);
            auto manyCharsDescriptor = propCollectorGet!(char[])("manyChars");
            manyCharsDescriptor.setter()("BimBamBom".dup);
            assert(_manyChars == "BimBamBom");
            _manyChars = "BomBamBim".dup;  
            assert(manyCharsDescriptor.getter()() == "BomBamBim");
        }
    }

    class Bar
    {
        size_t _field;
        string info;
        mixin PropDescriptorCollector;
        this()
        {
            propCollectorGetPairs!Bar;
        }
        @Set void field(size_t aValue)
        {
            info ~= "Bar";
        }
        @Get size_t field()
        {
            info = "less derived";
            return _field;
        }
    }

    class Baz : Bar
    {
        @Set override void field(size_t aValue)
        {
            super.field(aValue);
            info ~= "Baz";
        }
        @Get override size_t field()
        {
            info = "most derived";
            return _field;
        }
    }

    class Dog
    {
        mixin PropDescriptorCollector;
        @SetGet Object _o;
        this()
        {
            _o = new Object;
            propCollectorGetFields!Dog;
        }
    }

}

unittest
{
    auto foo = construct!Foo;
    foo.use;
    foo.destruct;

    auto baz = construct!Baz;
    auto prop = baz.propCollectorGet!size_t("field");
    prop.set(0);
    assert(baz.info == "BarBaz");
    assert(baz.propCollectorCount == 1);
    auto a = prop.get;
    assert(baz.info == "most derived");
    baz.destruct;

    writeln("PropDescriptorCollector passed the tests");
}

unittest
{
    alias Delegate = void delegate(uint a);
    class Cat
    {
        mixin PropDescriptorCollector;
        @SetGet Delegate _meaow;
        this(){propCollectorGetFields!Cat;}
    }

    class Fly
    {
        mixin PropDescriptorCollector;
        @GetSet string _bzzz(){return "bzzz";}
        this(){propCollectorGetFields!Fly;}
    }

    // test that a delegate is detected as a field
    Cat cat = new Cat;
    assert(cat.propCollectorCount == 1);
    auto descr = cast(PropDescriptor!uint*) cat.propCollectorGetPtrByIndex(0);
    assert(descr);
    assert(descr.rtti.type == RuntimeType._delegate);
    // test that a plain function is not detected as field
    Fly fly = new Fly;
    assert(fly.propCollectorCount == 0);
}

unittest
{
    class Bee
    {
        mixin PropDescriptorCollector;
        this(){propCollectorGetPairs!Bee;}
        @Set void delegate(uint) setter;
        @Get int delegate() getter;
    }
    // test that delegates as fields are not detected as set/get pairs
    Bee bee = new Bee;
    assert(bee.propCollectorCount == 0);
}

unittest
{
    class B0
    {
        mixin PropDescriptorCollector;
        this(){propCollectorAll!B0;}
        @SetGet int _a;
    }
    class B1: B0
    {
        mixin PropDescriptorCollector;
        this(){propCollectorAll!B1;}
        @Set void b(int value){}
        @Get int b(){return 0;}
        @SetGet int _c;
    }
    // test that all props are detected in the inheritence list
    auto b1 = new B1;
    assert(b1.propCollectorCount == 3);
}

unittest
{
    class B0
    {
        mixin PropDescriptorCollector;
        this(){propCollectorAll!B0;}
        @Set void b(int value){}
        @Get int b(){return 0;}
    }
    class B1: B0
    {
        mixin PropDescriptorCollector;
        this(){propCollectorAll!B1;}
        @HideGet override int b(){return super.b();}
    }
    // test that a prop marked with @HideSet/Get are not published anymore
    auto b0 = new B0;
    assert(b0.propCollectorCount == 1);
    auto b1 = new B1;
    assert(b1.propCollectorCount == 0);
}

unittest
{
    struct Bug
    {
        mixin PropDescriptorCollector;
        this(uint value){propCollectorAll!Bug;}
        @SetGet uint _a;
    }
    // test that the 'static if things' related to 'interface inheritence'
    // dont interfere when mixed in struct
    Bug bug = Bug(0);
    assert(bug.propCollectorCount == 1);
}

unittest
{
    // test safety, multiple setter types
    enum decl = q{
        class Bug
        {
            mixin PropDescriptorCollector;
            this(){propCollectorAll!Bug;}
            @Set void b(int value, uint ouch){}
            @Get int b(){return 0;}
        }
    };
    static assert( !__traits(compiles, mixin(decl)));
}

unittest
{
    // test safety, setter & getter types mismatch
    version(assert)
    {
        bool test;
        class Bug
        {
            mixin PropDescriptorCollector;
            this(){propCollectorAll!Bug;}
            @Set void b(string value){}
            @Get int b(){return 0;}
        }
        try auto b = new Bug;
        catch(Error e) test = true;
        assert(test);
    }
}


//TODO-cfeature: A PropBinder version based on iz.types.RuntimeTypeInfo

/**
 * A PropertyBinder synchronizes the value of several variables between themselves.
 *
 * The access to the variables is done via the PropDescriptor format, hence
 * a PropertyBinder stores a list of PropDescriptor with the same types.
 *
 * Params:
 * T = the common type of the properties.
 */
class PropertyBinder(T)
{

private:

    DynamicList!(PropDescriptor!T*) _itemsToDestruct;
    DynamicList!(PropDescriptor!T*) _items;
    PropDescriptor!T *_source;

public:

    ///
    this()
    {
        _items = construct!(DynamicList!(PropDescriptor!T*));
        _itemsToDestruct = construct!(DynamicList!(PropDescriptor!T*));
    }

    ~this()
    {
        for(auto i = 0; i < _itemsToDestruct.count; i++)
        {
            auto descr = _itemsToDestruct[i];
            if (descr) destruct(descr);
        }
        _items.destruct;
        _itemsToDestruct.destruct;
    }

    /**
     * Adds a property to the list.
     * If the binder is not local then aProp should neither be a local descriptor,
     * otherwise the descritpor reference will become invalid.
     *
     * Params:
     * aProp = an PropDescriptor of type T.
     * isSource = optional boolean indicating if the descriptor is used as the master property.
     */
    ptrdiff_t addBinding(ref PropDescriptor!T aProp, bool isSource = false)
    {
        if (isSource) _source = &aProp;
        return _items.add(&aProp);
    }

    /**
     * Adds a new property to the list.
     * The life-time of the new descriptor is handled internally.
     *
     * Returns:
     * an new PropDescriptor of type T.
     */
    PropDescriptor!T * newBinding()
    {
        auto result = construct!(PropDescriptor!T);
        _items.add(result);
        _itemsToDestruct.add(result);
        return result;
    }

    /**
     * Removes the aIndex-nth property from the list.
     * The item is freed if it has been allocated by newBinding.
     * source might be invalidated if it matches the item.
     *
     * Params:
     * anIndex = the index of the descriptor to remove.
     */
    void removeBinding(size_t anIndex)
    {
        auto itm = _items.extract(anIndex);
        if (_source && itm == _source) _source = null;
        if (_itemsToDestruct.remove(itm)) destruct(itm);
    }

    /**
     * Triggers the setter of each property.
     * This method is usually called at the end of a setter method
     * (in the master/source setter).
     *
     * Params:
     * aValue = a value of type T to send to each slave of the list.
     */
    void change(T aValue)
    {
        foreach(item; _items)
        {
            if (item.access == PropAccess.none) continue;
            if (item.access == PropAccess.ro) continue;
            item.setter()(aValue);
        }
    }

    /**
     * Calls change() using the value of source.
     */
    void updateFromSource()
    {
        if (!_source) return;
        change(_source.getter()());
    }

    /**
     * Sets the property used as source in updateFromSource().
     * Params:
     * aSource = the property to be used as source.
     */
    @property void source(ref PropDescriptor!T aSource)
    {_source = &aSource;}

    /**
     * Returns the property used as source in _updateFromSource().
     */
    @property PropDescriptor!T * source()
    {return _source;}

    /**
     * Provides an access to the property descriptors for additional List operations.
     * Note that the items whose life-time is managed should not be modified.
     */
    @property List!(PropDescriptor!T *) items()
    {return _items;}
}

version(unittest)
private class PropertyBinderTester
{
    unittest
    {
        alias intprops = PropertyBinder!int;
        alias floatprops = PropertyBinder!float;

        class Foo
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
                    fASlaves = construct!intprops;
                    fBSlaves = construct!floatprops;
                }
                ~this()
                {
                    fASlaves.destruct;
                    fBSlaves.destruct;
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

                void addABinding(ref intProp aProp)
                {
                    fASlaves.addBinding(aProp);
                }

                void addBBinding(ref floatProp aProp)
                {
                    fBSlaves.addBinding(aProp);
                }
            }
        }

        class FooSync
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

        class Bar
        {
            public int A;
            public float B;
        }

        // 1 master, 2 slaves
        auto a0 = construct!Foo;
        auto a1 = construct!FooSync;
        auto a2 = construct!FooSync;
        auto a3 = construct!Bar;

        auto prp1 = intProp(&a1.A,&a1.A);
        a0.addABinding(prp1);

        auto prp2 = intProp(&a2.A,&a2.A);
        a0.addABinding(prp2);

        intProp prp3 = intProp(&a3.A);
        a0.addABinding(prp3);

        auto prpf1 = floatProp(&a1.B,&a1.B);
        auto prpf2 = floatProp(&a2.B,&a2.B);
        auto prpf3 = floatProp(&a3.B);
        a0.addBBinding(prpf1);
        a0.addBBinding(prpf2);
        a0.addBBinding(prpf3);

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
        auto m0 = construct!Foo;
        auto m1 = construct!Foo;
        auto m2 = construct!Foo;

        intProp mprp0 = intProp(&m0.A, &m0.A);
        intProp mprp1 = intProp(&m1.A, &m1.A);
        intProp mprp2 = intProp(&m2.A, &m2.A);

        m0.addABinding(mprp1);
        m0.addABinding(mprp2);

        m1.addABinding(mprp0);
        m1.addABinding(mprp2);

        m2.addABinding(mprp0);
        m2.addABinding(mprp1);

        m0.A = 2;
        assert( m1.A == m0.A);
        assert( m2.A == m0.A);
        m1.A = 3;
        assert( m0.A == m1.A);
        assert( m2.A == m1.A);
        m2.A = 4;
        assert( m1.A == m2.A);
        assert( m0.A == m2.A);

        a0.destruct;
        a1.destruct;
        a2.destruct;
        a3.destruct;
        m0.destruct;
        m1.destruct;
        m2.destruct;

        writeln("PropertyBinder(T) passed the tests");
    }
}

unittest
{
    auto strSync = construct!(PropertyBinder!int);

    class A
    {
        private int fStr;
        public @property str(int aValue){fStr = aValue;}
        public @property int str(){return fStr;}
    }

    auto a0 = construct!A;
    auto a1 = construct!A;
    auto a2 = construct!A;

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

    a0.destruct;
    a1.destruct;
    a2.destruct;
    strSync.destruct;

    writeln("PropertyBinder(T) passed the newBinding() test");
}

