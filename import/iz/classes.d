/**
 * High-level iz classes.
 */
module iz.classes;

import
    std.traits, std.string, std.range, std.algorithm;
import
    iz.types, iz.memory, iz.containers, iz.streams, iz.properties,
    iz.serializer, iz.referencable, iz.observer;

/**
 * The SerializableList is a serializable object list.
 *
 * The life-time of the objects is automatically handled by the internal container.
 *
 * The serialization is only possible in sequential mode (objectToStream/streamToObject) 
 * because internally the items are described using a single property descriptor.
 */
class SerializableList(ItemClass): Serializable 
if(isImplicitlyConvertible!(ItemClass, Serializable))
{
    private
    {
        PropDescriptor!Object _itmDescr;
        PropDescriptor!uint _countDescr;
        DynamicList!ItemClass _items;

        final uint getCount()
        {
            return cast(uint) _items.count;
        }
        final void setCount(uint aValue)
        {
            if (_items.count > aValue)
                while (_items.count != aValue) _items.remove(_items.last);
            else
                while (_items.count != aValue) addItem;                 
        }
    }  
    protected
    {
        /**
         * Serialization handling.
         */
        void declareProperties(Serializer serializer)
        {
            if (serializer.state == SerializationState.store && serializer.storeMode == StoreMode.bulk)
            {
                assert(0, "SerializableList cant be stored in bulk mode");
            }
            else if (serializer.state == SerializationState.restore && serializer.restoreMode == RestoreMode.random)
            {
                assert(0, "SerializableList cant be restored in random mode");
            }
            // in a first time, always re/stores the count.
            serializer.addProperty(&_countDescr);
            // items
            for(auto i= 0; i < _items.count; i++)
            {
                auto itm = cast(Object)_items[i];
                _itmDescr.define(&itm, format("item<%d>",i));
                serializer.addProperty(&_itmDescr);
            }
        }
    }

    public
    {
        /// Constructs a new instance
        this()
        {
            _items = construct!(DynamicList!ItemClass);
            _countDescr.define(&setCount, &getCount, "Count");
        }

        ~this()
        {
            clear;
            _items.destruct;
        }

        /**
         * Instanciates and returns a new item.
         * Params:
         * a = the variadic list of argument passed to the item __ctor.
         */
        ItemClass addItem(A...)(A a)
        {
            return _items.addNewItem(a);
        }
        
        /**
         * Removes and destroys an item from the inernal container.
         * Params:
         * item = either the item to delete or its index.
         */
        void deleteItem(T)(T item)
        if (isIntegral!T || is(T == ItemClass))
        {
            static if(is(T == ItemClass))
            {
                auto immutable i = _items.find(item);
                if (i == -1) return;
                _items.remove(item);
                destruct(item);
            }   
            else
            {
                if (_items.count == 0 || item > _items.count-1 || item < 0) 
                    return;
                auto itm = _items[item];
                _items.remove(itm);
                destruct(itm);
            }
        }      
        
        /**
         * Provides an access to the internal container.
         * The access is mostly provided to reorganize or read the items.
         */
        DynamicList!ItemClass items(){return _items;}
        
        /**
         * Clears the internal container and destroys the items.
         */
        void clear()
        {
            foreach_reverse(i; 0 .. _items.count)
            {
                auto itm = _items[i];
                if(itm) destruct(itm);
            }
            _items.clear;
        }
    }
}

version(unittest)
{
    private class ItmTest: Serializable
    {
        private
        {
            int field1, field2, field3;
            PropDescriptor!int descr1, descr2, descr3;
        }
        public
        {
            this()
            {
                descr1.define(&field1, "prop1");
                descr2.define(&field2, "prop2");
                descr3.define(&field3, "prop3");
            }
            override void declareProperties(Serializer serializer)
            {
                serializer.addProperty!int(&descr1);
                serializer.addProperty!int(&descr2);
                serializer.addProperty!int(&descr3);
            }
            void setProps(uint f1, uint f2, uint f3)
            {
                field1 = f1;
                field2 = f2;
                field3 = f3;
            }
        }
    }
    unittest
    {    
        auto col = construct!(SerializableList!ItmTest);
        auto str = construct!MemoryStream;
        auto ser = construct!Serializer;
        scope(exit) destruct(col, ser, str);

        ItmTest itm = col.addItem();
        itm.setProps(0u,1u,2u);
        itm = col.addItem;
        itm.setProps(3u,4u,5u);
        itm = col.addItem;
        itm.setProps(6u,7u,8u);

        ser.objectToStream(col, str, SerializationFormat.iztxt);
        str.position = 0;
        col.clear;
        assert(col.items.count == 0);

        ser.streamToObject(str, col, SerializationFormat.iztxt);
        assert(col.items.count == 3);
        assert(col.items[1].field3 == 5u);
        assert(col.items[2].field3 == 8u);

        auto todelete = col.items[0];
        col.deleteItem(todelete);
        assert(col.items.count == 2);
        col.deleteItem(1);
        assert(col.items.count == 1);  
        
        std.stdio.writeln("SerializableList passed the tests");
    }
}


enum ComponentNotification
{
    /**
     * The Component parameter of the notifySubject() is now owned.
     * The owner that also matches to the caller can be retieved using
     * the .owner() property on the parameter.
     */
    added,
    /**
     * The Component parameter of the notifySubject() is about to be destroyed,
     * after what any reference to the it that's been escaped is will be danling.
     * The parameter may match the emitter itself or one of its owned Component.
     */
    free,
    /**
     * The Component parameter of the notifySubject() is about to be serialized.
     */
    serialize,
    /**
     * The Component parameter of the notifySubject() is about to be deserialized.
     */
    deserialize,
}

/**
 * Defines the interface a class that wants to observe a Component has to implement.
 * There is a single method: subjectNotification(ComponentNotification n, Component c)
 */
alias ComponentObserver = EnumBasedObserver!(ComponentNotification, Component);
// matching emitter
private alias ComponentSubject = CustomSubject!(ComponentNotification, Component);

/**
 * Component is a high-level class that proposes an automatic memory
 * managment model based on ownership. It also implements the facilities to
 * turn an instance as a referencable and as a serializable class.
 *
 * Ownership:
 *
 *
 * Referencable:
 *
 *
 * Serializable:
 *
 *
 */
class Component: PropDescriptorCollection
{

private:

    Component _owner;
    DynamicList!Component _owned;
    ComponentSubject _compSubj;

    final void addOwned(Component o)
    {
        if (!o) return;
        _owned.add(o);
        foreach(obs; _compSubj.observers)
            obs.subjectNotification(ComponentNotification.added, this);
    }

protected:

    mixin PropDescriptorCollector;
    char[] _name;

public:

    @disable this();

    /**
     * Constructs a new instance whose life-time will be managed.
     * by owner.
     */
    this(Component owner)
    {
        propCollectorAll;
        _compSubj = construct!ComponentSubject;
        _owned = construct!(DynamicList!Component);
        _owner = cast(Component) owner;
        if (_owner) owner.addOwned(this);
    }

    /**
     * Destructs this and all the owned instances.
     */
    ~this()
    {
        foreach_reverse(o; _owned)
        {
            // observers can invalidate any escaped reference to a owned
            foreach(obs; _compSubj.observers)
                obs.subjectNotification(ComponentNotification.free, o);
            destruct(o);
        }
        // observers can invalidate any escaped reference to this instance
        foreach(obs; _compSubj.observers)
            obs.subjectNotification(ComponentNotification.free, this);
        //
        destruct(_compSubj);
        destruct(_owned);
    }

    /// Returns this instance onwer.
    const(Component) owner() {return _owner;}

    /// Returns the subject allowing some ComponentObserver to observe this instance.
    ComponentSubject componentSubject() {return _compSubj;}

    // name things ------------------------------------------------------------+

    /// Returns true if value is available as an unique Component name.
    bool nameAvailable(in char[] value)
    {
        //TODO-cComponent: nameAvailable()
        return true;
    }

    /// Returns a suggestion for an unique Component name according to base.
    char[] getUniqueName(in char[] base)
    {
        //TODO-cComponent: getUniqueName()
        return null;
    }

    /**
     * Defines the name of this Component.
     *
     * The name must be an unique value in the Component tree owned by the owner.
     * This value is a collected property.
     * This value is stored as an ID in the ReferenceMan with the void type.
     */
    @Set name(char[] value)
    {
        if (_name == value) return;
        ReferenceMan.removeReference!void(cast(void*)this);
        if (nameAvailable(value)) _name = value.dup;
        else _name = getUniqueName(value);
        ReferenceMan.storeReference!void(cast(void*)this, qualifiedName);
    }
    /// ditto
    @Get char[] name() {return _name;}

    /**
     * Returns the fully qualified name of this component within the owner
     * Component tree.
     */
    char[] qualifiedName()
    {
        char[][] result;
        result ~= _name;
        Component c = _owner;
        while (c)
        {
            result ~= c.name;
            c = c._owner;
        }
        return result.retro.join(".");
    }
    // ----
}

unittest
{

    Component root = null;
    root = construct!Component(root);
    root.name = "root".dup;
    assert(root.owner is null);
    assert(root.name == "root");
    assert(root.qualifiedName == "root");

    Component owned1 = construct!Component(root);
    owned1.name = "component1".dup;
    assert(owned1.owner is root);
    assert(owned1.name == "component1");
    assert(owned1.qualifiedName == "root.component1");

    root.destruct;
    // owned1 is dangling but that's expected.
    // Component instances are designed to be created and declared inside
    // other Component. Escaped refs can be set to null using Observer
    // system.
}

