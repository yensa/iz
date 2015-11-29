/**
 * High-level iz classes.
 */
module iz.classes;

import
    std.traits, std.string, std.algorithm, std.array, std.range;
import
    iz.types, iz.memory, iz.containers, iz.streams, iz.properties,
    iz.serializer, iz.referencable, iz.observer;

version(unittest) import std.stdio;

/**
 * The PublishedObjectArray class template allows to serialize an array of
 * PropertyPublisher.
 *
 * A Serializer is not able to directly handle object arrays but this class
 * does the task automatically by managing the internal list of publications.
 *
 * The life-time of the objects is automatically handled by the internal container.
 */
class PublishedObjectArray(ItemClass): PropertyPublisher
if(is(ItemClass : PropertyPublisher))
{

    mixin PropertyPublisherImpl;

private:

    PropDescriptor!Object _itmDescr;
    PropDescriptor!uint _countDescr;
    ItemClass[] _items;

    @Get final uint count()
    {
        return cast(uint) _items.length;
    }
    @Set final void count(uint aValue)
    {
        if (_items.length > aValue)
            while (_items.length != aValue) deleteItem(_items.length-1);
        else if (_items.length < aValue)
            while (_items.length != aValue) addItem;
    }

public:

    ///
    this()
    {
        collectPublications!(PublishedObjectArray!ItemClass);
    }

    ~this()
    {
        clear;
    }

    /**
     * Instanciates and returns a new item.
     * Params:
     *      a = the variadic list of argument passed to the item __ctor.
     */
    ItemClass addItem(A...)(A a)
    {
        _items ~= construct!ItemClass(a);

        PropDescriptor!Object* descr = construct!(PropDescriptor!Object);
        descr.define(cast(Object*)&_items[$-1], format("item<%d>",_items.length-1), this);
        _items[$-1].declarator = this;
        _publishedDescriptors ~= descr;

        return _items[$-1];
    }

    /**
     * Removes and destroys an item from the internal container.
     * Params:
     *      t = either the item to delete or its index.
     */
    final void deleteItem(T)(T t)
    if (isIntegral!T || is(Unqual!T == ItemClass))
    {
        long index;
        static if(is(Unqual!T == ItemClass))
            index = _items.countUntil(t);
        else index = t;

        if (_items.count == 0 || index > _items.count-1 || index < 0)
            return;

        auto itm = _items[index];
        _items = remove(_items, index);

        if (auto descr = publication!uint(format("item<%d>",index)))
        {
            destruct(descr);
            // +1: first descriptor matches the count descriptor
            _publishedDescriptors = _publishedDescriptors.remove(index + 1);
        }
    }

    /**
     * Provides a read only access to the internal container.
     */
    final ItemClass[] items()
    {
        // should be const: the publications must be in sync with the items
        // but as usual, const transitivity sucks
        return _items;
    }

    /**
     * Clears the internal container and destroys the items.
     */
    void clear()
    {
        foreach_reverse(i; 0 .. _items.count)
            deleteItem(i);
    }
}

unittest
{
    class Item : PropertyPublisher
    {
        mixin PropertyPublisherImpl;
        @SetGet uint _a, _b, _c;
        this(){collectPublications!Item;}
        void setProps(uint a, uint b, uint c)
        {_a = a; _b = b; _c = c;}
    }

    alias ItemCollection = PublishedObjectArray!Item;

    auto col = construct!ItemCollection;
    auto str = construct!MemoryStream;
    auto ser = construct!Serializer;
    scope(exit) destruct(col, ser, str);

    Item itm = col.addItem();
    itm.setProps(0u,1u,2u);
    itm = col.addItem;
    itm.setProps(3u,4u,5u);
    itm = col.addItem;
    itm.setProps(6u,7u,8u);

    ser.publisherToStream(col, str, SerializationFormat.iztxt);
    str.position = 0;
    col.clear;
    assert(col.items.count == 0);

    ser.streamToPublisher(str, col, SerializationFormat.iztxt);
    assert(col._publishedDescriptors.count == 4); // 3 + count descr
    col.deleteItem(0);
    assert(col._publishedDescriptors.count == 3); // 2 + count descr
    assert(col.items.count == 2);
    assert(col.items[0]._c == 5u);
    assert(col.items[1]._c == 8u);
    col.items[1]._c = 7u;

    auto todelete = col.items[0];
    col.deleteItem(todelete);
    assert(col.items.count == 1);
    col.deleteItem(0);
    assert(col.items.count == 0);

    writeln("SerializableList passed the tests");

}

/// Enumerates the possible notifications sent to a ComponentObserver
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
     * after what anyof its reference that's been escaped will be danling.
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
 * managment model based on ownership. It also verify the requirements that
 * make an instance referencable and serializable.
 *
 * Ownership:
 * A Component can be created with iz.memory.construct. As constructor parameter
 * another Component can be specified. It's responsible for freeing this "owned"
 * instance. Components that's not owned have to be freed manually. A reference
 * to an owned object can be escaped. To be notified of its destruction, it's
 * possible to observe the component or its owner by adding an observer to the
 * componentSubject.
 *
 * Referencable:
 * Each Component instance that's properly named is automatically registered
 * in the ReferenceMan, as a void reference. This allow some powerfull features
 * such as the Object property editor or the Serializer to inspect, store, retrieve
 * a Component between two sessions.
 *
 * Serializable:
 * A Component implements the PropDescriptorCollection interface. Each field annotated
 * by @SetGet and each setter/getter pair annotated with @Set and @Get is automatically
 * collected and is usable directly by a PropertyBinder, by a Serializer or
 * by any other system based on the PropDescriptor system.
 */
class Component: PropertyPublisher
{

    mixin PropertyPublisherImpl;

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

    char[] _name;

public:

    ///
    this()
    {
        collectPublications!Component;
        _compSubj = construct!ComponentSubject;
        _owned = construct!(DynamicList!Component);
    }

    /**
     * Constructs a new instance whose life-time will be managed.
     * by its owner.
     */
    static C create(C = typeof(this))(Component owner)
    if (is(C : Component))
    {
        C c = construct!C;
        c._owner = owner;
        if (owner) owner.addOwned(c);
        return c;
    }

    /**
     * Destructs this and all the owned instances.
     */
    ~this()
    {
        ReferenceMan.removeReference(cast(Component*)this);
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
    final const(Component) owner() {return _owner;}

    /// Returns the subject allowing some ComponentObserver to observe this instance.
    final ComponentSubject componentSubject() {return _compSubj;}

    // name things ------------------------------------------------------------+

    /// Returns true if value is available as an unique Component name.
    final bool nameAvailable(in char[] value)
    {
        if (_owner !is null && _owner._owned.first)
        {
            foreach(o; _owner._owned)
                if (o.name == value) return false;
        }
        return true;
    }

    /// Suggests an unique Component name according to base.
    final char[] getUniqueName(in char[] base)
    {
        import std.conv: to;
        size_t i;
        char[] result = base.dup;
        while (!nameAvailable(result))
        {
            result = base ~ '_' ~ to!(char[])(i++);
            if (i == size_t.max)
                return result.init;
        }
        return result;
    }

    /**
     * Defines the name of this Component.
     *
     * The name must be an unique value in the Component tree owned by the owner.
     * This value is a collected property.
     * This value is stored as an ID in the ReferenceMan with the void type.
     */
    final @Set name(const(char)[] value)
    {
        if (_name == value) return;
        ReferenceMan.removeReference(cast(Component*)this);
        if (nameAvailable(value)) _name = value.dup;
        else _name = getUniqueName(value);
        ReferenceMan.storeReference(cast(Component*)this, qualifiedName);
    }
    /// ditto
    final @Get char[] name() {return _name;}

    /**
     * Returns the fully qualified name of this component within the owner
     * Component tree.
     */
    final char[] qualifiedName()
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

    auto root = Component.create(null);
    root.name = "root";
    assert(root.owner is null);
    assert(root.name == "root");
    assert(root.qualifiedName == "root");

    auto owned1 = Component.create!Component(root);
    owned1.name = "component1".dup;
    assert(owned1.owner is root);
    assert(owned1.name == "component1");
    assert(owned1.qualifiedName == "root.component1");

    auto owned11 = Component.create!Component(owned1);
    owned11.name = "component1";
    assert(owned11.owner is owned1);
    assert(owned11.name == "component1");
    assert(owned11.qualifiedName == "root.component1.component1");

    auto owned12 = Component.create!Component(owned1);
    owned12.name = "component1";
    assert(owned12.name == "component1_0");
    assert(owned12.qualifiedName == "root.component1.component1_0");

    root.destruct;
    // owned1, owned11 & owned12 are dangling but that's expected.
    // Component instances are designed to be created and declared inside
    // other Components. Escaped refs can be set to null using the Observer system.
}

unittest
{
    auto c = Component.create!Component(null);
    c.name = "a";
    assert(ReferenceMan.referenceID(cast(Component*)c) == "a");
}


class PublisherCollection(T): PropertyPublisher
if (is( T : PropertyPublisher))
{

    mixin PropertyPublisherImpl;

protected:

    DynamicList!T _items;

public:

    this()
    {
    }

}
