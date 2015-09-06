/**
 * High-level iz classes.
 */
module iz.classes;

import std.traits;
import iz.types, iz.memory, iz.containers, iz.streams, iz.properties, iz.serializer;

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

