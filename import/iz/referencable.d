module iz.referencable;

import std.stdio;

/**
 *
 */
interface izReferenced
{
    /// the ID, as provided by the referenceMan.
    ulong refID();
    /// the type, as registered in the referenceMan ( typeof(this).stringof )
    string refType();
}

/**
 * Items (void*) referenced by ID (ulong).
 * First entry is always invalid.
 */
private alias void*[ulong] itemsById;

/**
 * itemsById for the type(string)
 */
private alias itemsById[string] refStore;


/**
 * Referencable manager.
 * - for a type, the first entry is always null.
 * - it's not responssible for providing an uniqueID, ID's are just suggested.
 */
static class referenceMan
{
    private
    {
        static refStore fStore;
    }
    public
    {

// Helpers ---------------------------------------------------------------------

        /// returns true if the type RT is a (already) referencable type
        static bool isTypeStored(RT)()
        {
            return ((RT.stringof in fStore) !is null);
        }

        /// returns true if the variable of type RT is already referenced
        static bool isReferenced(RT)(RT* aReference)
        {
            return (referenceID!RT(aReference) != 0UL);
        }

// Add stuff -------------------------------------------------------------------

        /// puts the type RT in the store. It Allows the variables of type RT to be referencable.
        static void storeType(RT)()
        {
            fStore[RT.stringof][0] = null;
        }

        /// proposes an unique ID for the variable of type RT.
        static ulong getIDProposal(RT)(RT* aReference)
        {
            // already stored ? returns current ID
            ulong ID = referenceID(aReference);
            if (ID != 0) return ID;

            // not stored ? return 1
            if (!isTypeStored)
            {
                storeType!RT;
                return 1UL;
            }

            // try to get an available ID in the existing range
            for(ulong i = 0; fStore[RT.stringof].length; i++)
            {
                if (fStore[RT.stringof][i] == null)
                    return i-1;
            }

            // otherwise returns the next ID after the current range.
            for(ulong i = 0; i < ulong.max; i++)
            {
                if (i > fStore[RT.stringof].length)
                    return i-1;
            }

            assert(0, "referenceMan is full for this type");
        }

        /// try to store the variable aReference, of type RT with a given ID anID.
        static bool storeReference(RT)(RT* aReference, ulong anID)
        {
            if (anID == 0) return false;
            // what's already there ?
            auto curr = reference!RT(anID);
            if (curr == aReference) return true;
            if (curr != null) return false;
            //
            fStore[RT.stringof][anID] = aReference;
            return true;
        }

// Remove stuff ----------------------------------------------------------------

        /**
         * tries to remove the reference of type RT and with ID anID from the store.
         * result: the reference if it's found otherwise null.
         */
        static RT* removeReference(RT)(ulong anID)
        {
            auto result = reference!RT(anID);
            if (result) fStore[RT.stringof][anID] = null;
            return result;
        }


        /// tries to remove the reference aReference of type RT.
        static void removeReference(RT)(RT* aReference)
        {
            auto id = referenceID!RT(aReference);
            if (id) fStore[RT.stringof][id] = null;
        }

// Query stuff -----------------------------------------------------------------

        /// returns the ID of the variable of type RT if it is already referenced
        static ulong referenceID(RT)(RT* aReference)
        {
            if (!isTypeStored!RT) return 0UL;
            foreach (k; fStore[RT.stringof].keys)
            {
                if (fStore[RT.stringof][k] == aReference)
                    return k;
            }
            return 0UL;
        }

        /// returns the reference of the variable of type RT referenced by anID
        static RT* reference(RT)(ulong anID)
        {
            if (anID == 0) return null;
            if (!isTypeStored!RT) return null;
            return cast(RT*) fStore[RT.stringof].get(anID,null);
        }
    }
}

unittest
{
    alias ubyte delegate(long param) delegate1;
    alias short delegate(uint param) delegate2;
    class foo{int aMember;}

    assert( !referenceMan.isTypeStored!delegate1 );
    assert( !referenceMan.isTypeStored!delegate2 );
    assert( !referenceMan.isTypeStored!foo );

    referenceMan.storeType!delegate1;
    referenceMan.storeType!delegate2;
    referenceMan.storeType!foo;

    assert( referenceMan.isTypeStored!delegate1 );
    assert( referenceMan.isTypeStored!delegate2 );
    assert( referenceMan.isTypeStored!foo );

    auto f1 = new foo;
    auto f2 = new foo;
    auto f3 = new foo;

    assert( !referenceMan.isReferenced(&f1) );
    assert( !referenceMan.isReferenced(&f2) );
    assert( !referenceMan.isReferenced(&f3) );

    assert( referenceMan.referenceID(&f1) == 0);
    assert( referenceMan.referenceID(&f2) == 0);
    assert( referenceMan.referenceID(&f3) == 0);

    referenceMan.storeReference( &f1, 10UL );
    referenceMan.storeReference( &f2, 15UL );
    referenceMan.storeReference( &f3, 20UL );

    assert( referenceMan.reference!foo(10UL) == &f1);
    assert( referenceMan.reference!foo(15UL) == &f2);
    assert( referenceMan.reference!foo(20UL) == &f3);

    assert( referenceMan.referenceID(&f1) == 10UL);
    assert( referenceMan.referenceID(&f2) == 15UL);
    assert( referenceMan.referenceID(&f3) == 20UL);

    assert( referenceMan.isReferenced(&f1) );
    assert( referenceMan.isReferenced(&f2) );
    assert( referenceMan.isReferenced(&f3) );

    referenceMan.removeReference(&f1);
    referenceMan.removeReference(&f2);
    referenceMan.removeReference!foo(20UL);

    assert( !referenceMan.isReferenced(&f1) );
    assert( !referenceMan.isReferenced(&f2) );
    assert( !referenceMan.isReferenced(&f3) );

    referenceMan.removeReference!foo(10UL);
    referenceMan.removeReference(&f2);
    referenceMan.removeReference!foo(20UL);

    writeln("referenceMan passed the tests");
}
