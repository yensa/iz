/**
 * High-level iz classes.
 */
module iz.classes;

import std.traits;
import iz.types, iz.containers, iz.streams, iz.properties, iz.serializer;

/**
 * The SerializableList is a serializable object list.
 * The life-time of the objects is automatically handled
 * by the internal container.
 * The serialization is only possible in sequential mode (objectToStream/streamToObject) 
 * because internally the items are described using a single property descriptor.
 */
class SerializableList(ItemClass): izSerializable 
if(isImplicitlyConvertible!(ItemClass, izSerializable))
{
    private
    {
        izPropDescriptor!Object fItmDescr;
        izDynamicList!ItemClass fItems;
        izPropDescriptor!uint fCntDescr;

        final uint getCount()
        {
            return fItems.count;
        }
        final void setCount(uint aValue)
        {
            if (fItems.count > aValue)
                while (fItems.count != aValue) fItems.remove(fItems.last);
            else
                while (fItems.count != aValue) addItem;                 
        }
    }  
    protected
    {
        /**
         * serialization handling.
         */
        void declareProperties(izSerializer aSerializer)
        {
            if (aSerializer.state == izSerState.store && aSerializer.storeMode == izStoreMode.bulk)
            {
                assert(0, "SerializableList cant be stored in bulk mode");
            }
            else if (aSerializer.state == izSerState.restore && aSerializer.restoreMode == izRestoreMode.random)
            {
                assert(0, "SerializableList cant be restored in random mode");
            }
            // ina first time, always re/stores the count.
            aSerializer.addProperty(&fCntDescr);
            // items
            for(auto i= 0; i < fItems.count; i++)
            {
                auto itm = cast(Object)fItems[i];
                fItmDescr.define(&itm, format("item<%d>",i));
                aSerializer.addProperty(&fItmDescr);
            }
        }
    }

    public
    {
        this()
        {
            fItems = construct!(izDynamicList!ItemClass);
            fCntDescr.define(&setCount, &getCount, "Count");
        }

        ~this()
        {
            clear;
            fItems.destruct;
        }

        /**
         * Instanciates and returns a new item.
         * Params:
         * a = the variadic list of argument passed to the item __ctor.
         */
        ItemClass addItem(A...)(A a)
        {
            return fItems.addNewItem(a);
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
                auto i = fItems.find(item);
                if (i == -1) return;
                fItems.remove(item);
                destruct(item);
            }   
            else
            {
                if (fItems.count == 0 || item > fItems.count-1 || item < 0) 
                    return;
                auto itm = fItems[item];
                fItems.remove(itm);
                destruct(itm);
            }
        }      
        
        /**
         * Provides an access to the inernal container.
         * The access is mostly granted to reorganize or read the items.
         */
        izDynamicList!ItemClass items(){return fItems;}
        
        /**
         * Clears the internal container and destroys the items.
         */
        void clear()
        {
            foreach_reverse(i; 0 .. fItems.count)
            {
                auto itm = fItems[i];
                if(itm) destruct(itm);
            }
            fItems.clear;
        }
    }
}

version(unittest)
{
    class itmtest: izSerializable
    {
        private
        {
            int field1, field2, field3;
            izPropDescriptor!int descr1, descr2, descr3;
        }
        public
        {
            this()
            {
                descr1.define(&field1, "prop1");
                descr2.define(&field2, "prop2");
                descr3.define(&field3, "prop3");
            }
            override void declareProperties(izSerializer aSerializer)
            {
                aSerializer.addProperty!int(&descr1);
                aSerializer.addProperty!int(&descr2);
                aSerializer.addProperty!int(&descr3);
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
        auto col = construct!(SerializableList!itmtest);
    
        itmtest itm = col.addItem();
        itm.setProps(0u,1u,2u);
        itm = col.addItem;
        itm.setProps(3u,4u,5u);
        itm = col.addItem;
        itm.setProps(6u,7u,8u);
    
        auto str = construct!izMemoryStream;
        auto ser = construct!izSerializer;
        scope(exit) destruct(col, ser, str);
        
        ser.objectToStream(col, str, izSerFormat.iztxt);
        str.position = 0;
        
        col.clear;
        assert(col.items.count == 0);
        ser.streamToObject(str, col, izSerFormat.iztxt);
        
        assert(col.items.count == 3);
        assert(col.items[1].field3 == 5u);
        assert(col.items[2].field3 == 8u);
        
        auto todelete = col.items[0];
        col.deleteItem(todelete);
        assert(col.items.count == 2);
        col.deleteItem(1);
        assert(col.items.count == 1);    
    }
}
