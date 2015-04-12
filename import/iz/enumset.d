module iz.enumset;

import core.exception;
import std.stdio;
import std.traits;
import std.conv;

/// container for a izEnumSet based on an enum which has up to 8 members.
alias Set8 = ubyte;
/// container for a izEnumSet based on an enum which has up to 16 members.
alias Set16 = ushort;
/// container for a izEnumSet based on an enum which has up to 32 members.
alias Set32 = uint;
/// container for a izEnumSet based on an enum which has up to 64 members.
alias Set64 = ulong;

/**
 * Returns true if the parameter is suitable for being used as a izEnumSet container.
 * Params:
 * S = a izEnumSet container type.
 */
private static bool isSetSuitable(S)()
{
    static if (isSigned!S) return false;
    else static if (is(S==Set8)) return true;
    else static if (is(S==Set16)) return true;
    else static if (is(S==Set32)) return true;
    else static if (is(S==Set64)) return true;
    else return false;
}

/**
 * Returns the member count of an enum.
 * Params:
 * E = an enum.
 */
private ulong enumMemberCount(E)() if (is(E==enum))
{
    ulong result;
    foreach(member; EnumMembers!E) result++;
    return result;
}

/**
 * Provides the information about the rank of the members of an enum.
 * The properties are all static and can be retrieved from a template alias.
 * Params:
 * E = an enum.
 */
public struct izEnumRankInfo(E) if (is(E==enum))
{
    private:

        static immutable size_t[E] fRankLUT;
        static immutable E[size_t] fMembLUT;
        static immutable size_t fCount;

    public:

        nothrow @safe static this()
        {
            foreach(member; EnumMembers!E)
            {
                fRankLUT[member] = fCount;
                fMembLUT[fCount] = member;
                fCount++;
            }
        }

        /// returns the rank of the last member.
        nothrow @safe @nogc static @property size_t max()
        {
            return fCount-1;
        }

        /// returns the member count.
        nothrow @safe @nogc static @property size_t count()
        {
            return fCount;
        }

        /// always returns 0.
        nothrow @safe @nogc static @property size_t min()
        {
            return 0;
        }

        /// returns the rank of aMember.
        nothrow @safe static size_t opIndex(E aMember)
        {
            return fRankLUT[aMember];
        }

        /// returns the member at aRank.
        nothrow @safe static E opIndex(size_t aRank)
        {
            return fMembLUT[aRank];
        }
}

/**
 * Indicates if the members of an enum fit in a container.
 * Params:
 * E = an enumeration.
 * S = a container, either a Set8, Set16, Set32 or Set64.
 */
private static bool enumFitsInSet(E, S)() if (is(E==enum) && isSetSuitable!S)
{
    S top = S.max;
    ulong max;
    foreach(i, member; EnumMembers!E)
    {
        max +=  cast(S) 1 << i;
    }
    return (max <= top);
}

// setConstrain may include more test in the future.
private alias setConstraint = enumFitsInSet ;

/**
 * An izEnumSet allows to create a bit field using the members of an enum. 
 * It's designed in a very similar way to the 'Set Of' types from the Pascal languages.
 *
 * It's optimized for function calls since actually the size of an izEnumSet is 
 * equal to the size of its container (so from 1 to 8 bytes). Since manipulating
 * an enum set is mostly all about making bitwise operations an izEnumSet is completly
 * safe.
 *
 * It blends two syntaxes kind:
 * * symbolic, C-ish, using the operators and the array noation (+/-/==/!=/[])
 * * natural, Pascal-ish, using the primitive functions (include(), exclude()) and the 'in' operator.
 *
 * Params:
 * S = a Set8, Set16, Set32 or Set64. It must be wide enough to contain all the enum members.
 * E = an enum.
 *
 * Example:
 * ---
 * enum TreeOption {smallIcons, autoExpand, singleClickExpand, useKayboard, autoRefresh} 
 * alias TreeOptions = izEnumSet!(TreeOption, Set8);
 * auto treeOptions = TreeOptions(autoExpand, singleClickExpand);
 * assert(TreeOption.autoExpand in treeOptions); 
 * ---
 */
public struct izEnumSet(E, S) if (setConstraint!(E, S))
{
    private:

        S fSet;
        static S fMax;
        static immutable izEnumRankInfo!E fRankInfs;
        static immutable S _1 = cast(S) 1;

    public:

        alias setType = S;

// constructors ---------------------------------------------------------------+

        /// static constructor.
        nothrow @safe @nogc static this()
        {
            foreach(i, member; EnumMembers!E)
                fMax +=  _1 << i;
        }

        /// initializes the set with aSet.
        nothrow @safe @nogc this(S aSet)
        {
            fSet = aSet;
        }

        /**
         * initializes the set with someMembers.
         * someMembers: a list of E members.
         */
        nothrow @safe this(E...)(E someMembers)
        {
            fSet = 0;
            include(someMembers);
        }
        /// ditto
        nothrow @safe this(E aMember)
        {
            fSet = 0;
            include(aMember);
        }

        /**
         * initializes the set with someMembers.
         * someMembers: an array of E members.
         */
        nothrow @safe this(E[] someMembers)
        {
            fSet = 0;
            foreach(member; someMembers)
                include(member);
        }

        /**
         * initializes the set with a string representation.
         * aSetString: a string representing one or several E members.
         * cf with fromString() for more detailed informations.
         */
        @safe this(string aSetString)
        {
            fromString(aSetString);
        }
// -----------------------------------------------------------------------------
// string representation ------------------------------------------------------+

        /**
         * returns the string representation of the set as a binary litteral.
         * (as defined in D syntax)
         */
        nothrow @safe string asBitString()
        {
            static char[2] bitsCh = ['0', '1'];
            string result = "";
            foreach_reverse(member; EnumMembers!E)
                result ~= bitsCh[isIncluded(member)];

            return "0b" ~ result;
        }

        /**
         * returns the string representation of the set.
         * The format is the same as the one used in this() and fromString().
         */
        @safe string toString()
        {
            scope(failure){}
            string result = "[";
            bool first;
            foreach(i, member; EnumMembers!E)
            {
                if ((!first) & (isIncluded(member)))
                {
                    result ~= to!string(member);
                    first = true;
                }
                else if (isIncluded(member))
                    result ~= ", " ~ to!string(member);
            }
            return result ~ "]";
        }

        /**
         * defines the set with a string representation.
         * aSetString: a string representing one or several E members.
         * aSetString uses the std array representation: <i>"[a, b, c]"</i>.
         * the function doesn't throw if an invalid representation is found.
         */
        @trusted void fromString(string aSetString)
        {
            if (aSetString.length < 2) return;

            fSet = 0;
            if (aSetString == "[]") return;

            auto representation = aSetString.dup;

            char[] identifier;
            char* reader = representation.ptr;
            while(true)
            {
                if ((*reader != ',') & (*reader != '[') & (*reader != ']')
                    & (*reader != ' ')) identifier ~= *reader;

                if ((*reader == ',') | (*reader == ']') )
                {
                    scope(failure){break;}
                    auto member = to!E(identifier);
                    include(member);
                    identifier = identifier.init;
                }

                if (reader == representation.ptr + representation.length)
                    break;

                ++reader;
            }
        }
// -----------------------------------------------------------------------------
// operators ------------------------------------------------------------------+

        /**
         * support for the assignment operator.
         * rhs: a setXX, an array of E members or a izEnumSet of same type.
         */
        nothrow @safe @nogc void opAssign(S rhs)
        {
            fSet = (rhs <= fMax) ? rhs : fMax;
        }

        /// ditto
        nothrow @safe void opAssign(E[] rhs)
        {
            fSet = 0;
            foreach(elem; rhs) include(elem);
        }

        /// ditto
        nothrow @safe @nogc void opAssign(typeof(this) rhs)
        {
            fSet = rhs.fSet;
        }

        /// support for the array syntax.
        nothrow @safe @nogc bool opIndex(S index)
        {
            return (fSet == (fSet | _1 << index));
        }

        /// ditto
        nothrow @safe bool opIndex(E member)
        {
            return isIncluded(member);
        }

        /// support for "+" and "-" operators.
        nothrow @safe izEnumSet!(E, S) opBinary(string op)(E rhs)
        {
            static if (op == "+")
            {
                include(rhs);
                return this;
            }
            else static if (op == "-")
            {
                exclude(rhs);
                return this;
            }
            else static assert(0, "Operator "~op~" not implemented");
        }

        /// ditto
        nothrow @safe izEnumSet!(E, S) opBinary(string op)(E[] rhs)
        {
            static if (op == "+")
            {
                include(rhs);
                return this;
            }
            else static if (op == "-")
            {
                exclude(rhs);
                return this;
            }
            else static assert(0, "Operator "~op~" not implemented");
        }

        /// ditto
        nothrow @safe @nogc typeof(this) opBinary(string op)(typeof(this) rhs)
        {
            static if (op == "+")
            {
                fSet | rhs.fSet;
                return this;
            }
            else static if (op == "-")
            {
                fSet ^= rhs.fSet;
                return this;
            }
            else static assert(0, "Operator "~op~" not implemented");
        }

        /// support for the "-=" and "+=" operators
        nothrow @safe void opOpAssign(string op)(E[] rhs)
        {
            static if (op == "+") include(rhs);
            else static if (op == "-") exclude(rhs);
            else static assert(0, "Operator "~op~" not implemented");
        }

        /// ditto
        nothrow @safe void opOpAssign(string op, E...)(E rhs)
        {
            static if (op == "+") include(rhs);
            else static if (op == "-") exclude(rhs);
            else static assert(0, "Operator "~op~" not implemented");
        }

        /// ditto
        nothrow @safe @nogc void opOpAssign(string op)(typeof(this) rhs)
        {
            static if (op == "+") fSet |= rhs.fSet;
            else static if (op == "-") fSet ^= rhs.fSet;
            else static assert(0, "Operator "~op~" not implemented");
        }

        /// support for comparison "=" and "!=" operators.
        nothrow @safe bool opEquals(T)(T rhs)
        {
            static if (is(T == S))
                return (fSet == rhs);
            else static if (isIntegral!T && T.max >= S.max)
                return (fSet == rhs);
            else static if (is(T == typeof(this)))
                return (fSet == rhs.fSet);
            else static if (is(T == E[])){
                auto rhsset = typeof(this)(rhs);
                return (rhsset.fSet == fSet);
            }
            else
                static assert(0, "opEquals not implemented when rhs is " ~ T.stringof);
        }


        /// support for the in operator.
        nothrow @safe bool opIn_r(T)(T rhs)
        {
            static if (is(T == E))
                return isIncluded(rhs);
            else static if (is(T == typeof(this)))
                return (fSet & rhs.fSet) >= rhs.fSet;
            else static if (is(T == S))
                return (fSet & rhs) >= rhs;
            else
                static assert(0, "opIn not implemented when rhs is " ~ T.stringof);
        }
// -----------------------------------------------------------------------------
// Pascal-ish primitives ------------------------------------------------------+

        /**
         * includes someMembers in the set.
         * someMembers: a list of E members or an array of E members.
         * this is the primitive used for to the operator "+".
         */
        nothrow @safe void include(E...)(E someMembers)
        {
            static if (someMembers.length == 1)
                fSet += _1 << fRankInfs[someMembers];
            else foreach(member; someMembers)
                fSet += _1 << fRankInfs[member];
        }

        /// ditto
        nothrow @safe void include(E[] someMembers)
        {
            foreach(member; someMembers)
                fSet += _1 << fRankInfs[member];
        }

        /**
         * excludes someMembers from the set.
         * someMembers: a list of E members or an array of E members.
         * this is the primitive used for to the operator "-".
         */
        nothrow @safe void exclude(E...)(E someMembers)
        {
            static if (someMembers.length == 1)
                fSet &= fSet ^ (_1 << fRankInfs[someMembers]);
            else foreach(member; someMembers)
                fSet &= fSet ^ (_1 << fRankInfs[member]);
        }

        /// ditto
        nothrow @safe void exclude(E[] someMembers)
        {
            foreach(member; someMembers)
                fSet &= fSet ^ (_1 << fRankInfs[member]);
        }

        /**
         * returns true if aMember is in the set.
         * aMember: a  E member.
         */
        nothrow @safe bool isIncluded(E aMember)
        {
            return (fSet == (fSet | _1 << fRankInfs[aMember]));
        }
//------------------------------------------------------------------------------
// misc helpers ---------------------------------------------------------------+
      
        /// returns true if the set is empty.
        nothrow @safe @nogc bool none()
        {
            return fSet == 0;
        }

        /// returns true if at least one member is included.
        nothrow @safe @nogc bool any()
        {
            return fSet != 0;
        }

        /// returns true if all the members are included.
        nothrow @safe @nogc bool all()
        {
            return fSet == fMax;
        }

        /// returns the maximal value the set can have.
        nothrow @safe @nogc static const(S) max()
        {
            return fMax;
        }

        /// returns a lookup table which can be used to retrieve the rank of a member.
        nothrow @safe @nogc static ref const(izEnumRankInfo!E) rankInfo()
        {
            return fRankInfs;
        }

        /// returns the enum count
        nothrow @safe @nogc static const(S) memberCount()
        {
            return cast(S) rankInfo.count;
        }
       
//------------------------------------------------------------------------------

}

/**
 * Returns a pointer to an EnumSet using the smallest container possible.
 * The result must be manually deallocated with iz.types.destruct().
 * Params:
 * E = an enum
 * a = the parameters passed to the set constructor.
 */
static auto enumSet(E, A...)(A a) @property @safe
if (enumFitsInSet!(E, Set64))
{    
    import iz.types;
    static if (enumFitsInSet!(E, Set8))    
        return construct!(izEnumSet!(E, Set8))(a);
    else static if (enumFitsInSet!(E, Set16))    
        return construct!(izEnumSet!(E, Set16))(a); 
    else static if (enumFitsInSet!(E, Set32))    
        return construct!(izEnumSet!(E, Set32))(a);
    else return construct!(izEnumSet!(E, Set64))(a);
}


/// returns true if T and E are suitable for constructing an izEnumProcs
private static bool isCallableFromEnum(T, E)()
{
    return ((is(E==enum)) & (isCallable!T));
}

/**
 * CallTable based on an enum. It can be compared to an associative array of type E[T].
 * Additionally an izEnumSet can be used to fire a burst of call.
 * E: an enum.
 * T: a callable type.
 */
public struct izEnumProcs(E,T) if (isCallableFromEnum!(T,E))
{
    private:
        static izEnumRankInfo!E fRankInfs;
        alias retT = ReturnType!T;
        T[] fProcs;

        void initLength()
        {
            fProcs.length = fRankInfs.count;
        }
    
    public:

// constructors ---------------------------------------------------------------+

        /**
         * constructs an izEnumProcs with a set of T.
         * a: a list of T.
         */
        nothrow this(A...)(A a)
        {
            static assert(a.length == enumMemberCount!E);
            initLength;
            foreach(i, item; a)
            {
                fProcs[i] = a[i];
            }
        }

        /**
         * constructs an izEnumProcs with an array of T.
         * someItems: an array of T.
         */
        nothrow this(T[] someItems)
        {
            assert(someItems.length == fRankInfs.count);
            initLength;
            foreach(i, item; someItems)
            {
                fProcs[i] = someItems[i];
            }
        }
//------------------------------------------------------------------------------
// operators ------------------------------------------------------------------+

        /**
         * opIndex allow a more explicit call syntax than opCall.
         * myStuffs[E.member](params).
         */
        nothrow const(T) opIndex(E aMember)
        {
            return fProcs[fRankInfs[aMember]];
        }

//------------------------------------------------------------------------------
// call -----------------------------------------------------------------------+

        /**
         * calls the function matching to selector rank.
         * selector: an E member.
         * prms: arguments for calling the function.
         * return: a value of type ReturnType!T.
         */
        retT opCall(CallParams...)(E selector, CallParams prms)
        {
            return fProcs[fRankInfs[selector]](prms);
        }

        /**
         * calls the functions matching to a set of selectors.
         * selectors: a set of E.
         * prms: common or selector-sepcific arguments for calling the functions.
         * return: an array representing the result of each selector, by rank.
         */
        retT[] opCall(BS,CallParams...)(BS selectors, CallParams prms)
        if  (   (is(BS == izEnumSet!(E, Set8)))
            ||  (is(BS == izEnumSet!(E, Set16)))
            ||  (is(BS == izEnumSet!(E, Set32)))
            ||  (is(BS == izEnumSet!(E, Set64)))
            )
        {
            retT[] result;
            result.length = cast(size_t) enumMemberCount!E;

            static if(!isArray!(CallParams[0]))
            {
                for(selectors.setType i = 0; i < selectors.memberCount; i++)
                {
                    if (selectors[i])
                        result[i] = fProcs[i](prms);
                }
                return result;
            }
            else
            {
                for(selectors.setType i = 0; i < selectors.memberCount; i++)
                {
                    if (selectors[i])
                        result[i] = fProcs[i](prms[0][i]); // Hard to believe it works ! A unittest HAS to show it can fail.
                }
                return result;
            }
        }
//------------------------------------------------------------------------------
// misc. ----------------------------------------------------------------------+

        /// returns the array of callable for additional containers operations.
        ref T[] procs()
        {
            return fProcs;
        }
//------------------------------------------------------------------------------

}

/**
 * Encapsulates an array of T and uses the rank of the enum members
 * E to perform the actions usually done with integer indexes.
 */
public struct izEnumIndexedArray(E,T) if (is(E==enum))
{
    private:

        T[] fArray;
        izEnumRankInfo!E fRankInfs;

    public:

        nothrow @safe size_t opDollar()
        {
            return length;
        }

        nothrow @safe @property size_t length()
        {
            return fArray.length;
        }

        /**
         * sets the array length using a standard integer value.
         * aValue is checked according to E highest rank.
         */
        @safe @property length(size_t aValue)
        {
            version(D_NoBoundsChecks)
                fArray.length = aValue;
            else
                if (aValue > fRankInfs.count)
                    throw new Exception("izEnumIndexedArray upper bound error");
                else
                    fArray.length = aValue;
        }

        /**
         * sets the array length according to the value following
         * aMember rank.
         */
        nothrow @safe @property length(E aMember)
        {
            fArray.length = fRankInfs[aMember] + 1;
        }

        /**
         * returns the value of the slot indexed by the rank of aMember.
         */
        nothrow @safe T opIndex(E aMember)
        {
            return fArray[fRankInfs[aMember]];
        }

        /**
         * sets the slot indexed by the rank of aMember to aValue.
         */
        nothrow @safe void opIndexAssign(T aValue,E aMember)
        {
            fArray[fRankInfs[aMember]] = aValue;
        }

        /**
         * returns a slice of T using the rank of
         * loMember and hiMember to define the range.
         */
        nothrow @safe T[] opSlice(E loMember, E hiMember)
        in
        {
            assert(fRankInfs[loMember] <= fRankInfs[hiMember]);
        }
        body
        {
            return fArray[fRankInfs[loMember]..fRankInfs[hiMember]];
        }

        nothrow @safe @property ref const(T[]) array()
        {
            return fArray;
        }
}

version(unittest)
{
    enum a4     {a0,a1,a2,a3}
    enum a8     {a0,a1,a2,a3,a4,a5,a6,a7}
    enum a9     {a0,a1,a2,a3,a4,a5,a6,a7,a8}
    enum a16    {a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15}
    enum a17    {a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16}

    /// Constraints
    static unittest
    {
        static assert( isSetSuitable!ubyte );
        static assert( isSetSuitable!ushort );
        static assert( isSetSuitable!uint );
        static assert( isSetSuitable!ulong );
        static assert( !isSetSuitable!byte );
    }

    static unittest
    {
        static assert( enumFitsInSet!(a8, Set8));
        static assert( !enumFitsInSet!(a9, Set8));
        static assert( enumFitsInSet!(a16, Set16));
        static assert( !enumFitsInSet!(a17, Set16));
    }

    /// izEnumSet
    unittest
    {
        alias bs8 = izEnumSet!(a8, Set8);
        bs8 set = bs8(a8.a0,a8.a1,a8.a2,a8.a3,a8.a4,a8.a5,a8.a6,a8.a7);
        assert(set == 0b1111_1111);
        assert(set.all);
        set = set - a8.a0;
        assert(set == 0b1111_1110);
        set = set - a8.a1;
        assert(set == 0b1111_1100);
        set = set - a8.a7;
        assert(set == 0b0111_1100);
        set = 0;
        assert(set.none);
        assert(set == 0b0000_0000);
        set = set + a8.a4;
        assert(set == 0b0001_0000);
        set = set + a8.a5;
        assert(set != 0b0001_0000);
        set = 0;
        assert(set == 0b0000_0000);
        set = set + [a8.a0, a8.a1, a8.a3];
        assert(set == 0b0000_1011);
        set = set - [a8.a1, a8.a3];
        assert(set == 0b0000_001);
        set = set.max;
        set = set - [a8.a5,a8.a6,a8.a7];
        assert(set == [a8.a0,a8.a1,a8.a2,a8.a3,a8.a4]);
        set = [a8.a0,a8.a2,a8.a4];
        assert(set == 0b0001_0101);
        set = [a8.a0,a8.a1];
        assert(set == 0b0000_0011);
        set += [a8.a2,a8.a3];
        assert(set == 0b0000_1111);
        set -= [a8.a0,a8.a1];
        assert(set == 0b0000_1100);
        set = 0;
        set.exclude([a8.a0,a8.a1,a8.a2,a8.a3,a8.a4]);
        assert( set == 0);
        set -= a8.a0;
        assert( set == 0);        

        writeln("izEnumSet passed the tests(operators)");
    }

    unittest
    {
        izEnumSet!(a17, Set32) set;
        set.include(a17.a8,a17.a9);
        assert(!set.isIncluded(a17.a7));
        assert(set.isIncluded(a17.a8));
        assert(set.isIncluded(a17.a9));
        assert(!set.isIncluded(a17.a10));
        assert(!(a17.a7 in set));
        assert(a17.a8 in set);
        assert(a17.a9 in set);
        assert(!(a17.a10 in set));
        set = 0;
        set += [a17.a5, a17.a6, a17.a7];
        izEnumSet!(a17, Set32) set2;
        set2 += [a17.a5,a17.a6];
        assert(set2 in set);
        set -= [a17.a5];
        assert(!(set2 in set));
        set2 -= [a17.a5];
        assert(set2 in set);

        writeln("izEnumSet passed the tests(inclusion)");
    }

    unittest
    {
        auto bs = izEnumSet!(a17, Set32)(a17.a0, a17.a1, a17.a16);
        assert(bs[0]);
        assert(bs[1]);
        assert(bs[16]);
        assert(bs[a17.a0]);
        assert(bs[a17.a1]);
        assert(bs[a17.a16]);
        assert(!bs[8]);
        assert(!bs[a17.a8]);

        writeln("izEnumSet passed the tests(array operators)");
    }

    unittest
    {
        auto set = izEnumSet!(a8, Set8)(a8.a3, a8.a5);
        assert(set == 0b0010_1000);
        auto rep = set.toString;
        set = 0;
        assert(set == 0);
        set = izEnumSet!(a8, Set8)(rep);
        assert(set == 0b0010_1000);
        // test asBitString
        auto brep = set.asBitString;
        assert( brep == "0b00101000", brep );
        set = 0b1111_0000;
        brep = set.asBitString;
        assert( brep == "0b11110000", brep );

        //set = 0;
        //set = to!Set8(brep);
        //assert(set == 0b1111_0000);

        writeln("izEnumSet passes the tests(toString)");
    }

    unittest
    {
        auto set = izEnumSet!(a17, Set32)(a17.a0);
        assert( set.rankInfo[a17.a16] == 16);
        assert( set.rankInfo[a17.a15] == 15);

        writeln("izEnumSet passed the tests(misc.)");
    }

    unittest
    {
        enum E {e1, e2}
        alias ESet = izEnumSet!(E, Set8);
        ESet eSet1 = ESet(E.e1);
        ESet eSet2 = ESet(E.e1, E.e2);
        assert(eSet1 != eSet2);
        eSet2 -= E.e2;
        assert(eSet1 == eSet2);
    }
    
    /// enumSet
    unittest
    {
        assert( is(typeof(enumSet!a4) == izEnumSet!(a4,Set8)*) );
        assert( is(typeof(enumSet!a8) == izEnumSet!(a8,Set8)*) );
        assert( is(typeof(enumSet!a9) == izEnumSet!(a9,Set16)*)) ;
        assert( is(typeof(enumSet!a16) == izEnumSet!(a16,Set16)*) );
        assert( is(typeof(enumSet!a17) == izEnumSet!(a17,Set32)*) );  
    }    

    /// izEnumProcs
    unittest
    {
        enum A {t1=8,t2,t3}
        void At1(){}
        void At2(){}
        void At3(){}

        auto ACaller = izEnumProcs!(A, typeof(&At1))(&At1,&At2,&At3);

        int Bt1(int p){return 10 + p;}
        int Bt2(int p){return 20 + p;}
        int Bt3(int p){return 30 + p;}
        auto BCaller = izEnumProcs!(A, typeof(&Bt1))(&Bt1,&Bt2,&Bt3);
        assert( BCaller.procs[0]== &Bt1);
        assert( BCaller.procs[1]== &Bt2);
        assert( BCaller.procs[2]== &Bt3);
        assert( BCaller(A.t1, 1) == 11);
        assert( BCaller(A.t2, 2) == 22);
        assert( BCaller(A.t3, 3) == 33);
        assert( BCaller[A.t1](2) == 12);
        assert( BCaller[A.t2](3) == 23);
        assert( BCaller[A.t3](4) == 34);

        auto bs = izEnumSet!(A, Set8)();
        bs.include(A.t1,A.t3);

        auto arr0 = BCaller(bs,8);
        assert(arr0[0] == 18);
        assert(arr0[1] == 0);
        assert(arr0[2] == 38);

        bs.include(A.t2);
        auto arr1 = BCaller(bs,[4,5,6]);
        assert(arr1[0] == 14);
        assert(arr1[1] == 25);
        assert(arr1[2] == 36);

        int Ct1(int[2] p){return p[0] + p[1];}
        int Ct2(int[2] p){return p[0] * p[1];}
        int Ct3(int[2] p){return p[0] - p[1];}
        auto CCaller = izEnumProcs!(A, typeof(&Ct1))(&Ct1,&Ct2,&Ct3);
        assert(bs.all);
        auto arr2 = CCaller(bs,[cast(int[2])[2,2],cast(int[2])[3,3],cast(int[2])[9,8]]);
        assert(arr2[0] == 4);
        assert(arr2[1] == 9);
        assert(arr2[2] == 1);

        int Dt1(int p, int c, int m){return 1 + p + c + m;}
        int Dt2(int p, int c, int m){return 2 + p + c + m;}
        int Dt3(int p, int c, int m){return 3 + p + c + m;}
        auto DCaller = izEnumProcs!(A, typeof(&Dt1))(&Dt1,&Dt2,&Dt3);
        assert(bs.all);
        auto arr3 = DCaller(bs,1,2,3);
        assert(arr3[0] == 7);
        assert(arr3[1] == 8);
        assert(arr3[2] == 9);


        writeln("izEnumProcs passed the tests");
    }

    /// izEnumRankInfo
    unittest
    {
        enum E
        {
            e1 = 0.15468,
            e2 = 1256UL,
            e3 = 'A'
        }

        alias infs = izEnumRankInfo!E;
        assert(infs.min == 0);
        assert(infs.max == 2);
        assert(infs.count == 3);
        assert(infs[2] == 'A');
        assert(infs[E.e3] == 2);

        writeln("izEnumRankInfo passed the tests");
    }

    /// izEnumIndexedArray
    unittest
    {
        enum E {e0 = 1.8,e1,e2,e3 = 888.459,e4,e5,e6,e7}
        alias E_Fp_Indexed = izEnumIndexedArray!(E,float);
        E_Fp_Indexed arr;
        arr.length = izEnumRankInfo!E.count;

        foreach(i,memb; EnumMembers!E)
            arr[memb] = 1.0 + 0.1 * i;

        assert(arr[E.e1] == 1.1f);
        assert(arr[E.e0] == 1.0f);

        auto slice = arr[E.e2..E.e4];
        assert(slice == [1.2f,1.3f]);


        writeln("izEnumIndexedArray passed the tests");
    }
}
