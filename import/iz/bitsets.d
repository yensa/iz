module iz.bitsets;

import std.stdio;
import std.traits;
import std.conv;

/// container for a izBitSet based on an enum which has up to 8 members.
alias ubyte set8;
/// container for a izBitSet based on an enum which has up to 16 members.
alias ushort set16;
/// container for a izBitSet based on an enum which has up to 32 members.
alias uint set32;
/// container for a izBitSet based on an enum which has up to 64 members.
alias ulong set64;

/**
 * Returns true if S is suitable for being used as a izBitSet container.
 */
private static bool isSetSuitable(S)()
{
    if (isSigned!S) return false;
    else if (is(S==set8)) return true;
    else if (is(S==set16)) return true;
    else if (is(S==set32)) return true;
    else if (is(S==set64)) return true;
    else return false;
}

/**
 * returns E member count.
 * E: an enum
 */
private ulong enumMemberCount(E)() if (is(E==enum))
{
    ulong result;
    foreach(member; EnumMembers!E) result++;
    return result;
}


/**
 * Returns true if S has enough room for being used as a izBitSet for enum E.
 */
private static bool enumFitsInSet(E,S)() if (isSetSuitable!S && is(E==enum))
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
private alias enumFitsInSet setConstrain;

/**
 * The parameterized struct izBitSet allows to manipulate set of bits
 * based on the members of an enum.</br>
 * It allows two syntaxes kind:
 * <li> symbolic, C-ish, using the operators and the array noation (+/-/==/!=/[])</li>
 * <li> natural, Pascal-ish, using the primitive functions (include(), exclude(), isIncluded() for 'in')</li>
 * Parameters:
 * S: a set8, set16, set32 or set64. It must be wide enough to contain all the E members.
 * E: an enum.
 */
public struct izBitSet(S,E) if (setConstrain!(E,S))
{
    private:

        S fSet;
        static S fMax;
        static immutable S[E] fRankLUT;
        static immutable S _1 = cast(S) 1;

    public:

        alias setType = S;

// constructors ----------------------------------------------------------------

        /// static constructor.
        nothrow @safe static this()
        {
            foreach(i, member; EnumMembers!E)
            {
                fMax +=  _1 << i;
                fRankLUT[member] = i;
            }
        }

        /// initializes the set with aSet.
        nothrow @safe this(S aSet)
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

        /**
         * initializes the set with someMembers.
         * someMembers: an array of E members.
         */
        nothrow @safe this(E someMembers[])
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
        this(string aSetString)
        {
            fromString(aSetString);
        }

// string representation -------------------------------------------------------

        /**
         * returns the string representation of the set as a binary litteral.
         * (as defined in D syntax)
         */
        nothrow @safe string asBitString()
        {
            char[bool] bitsCh = [false:'0', true:'1'];
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
        void fromString(string aSetString)
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

// operators -------------------------------------------------------------------

        /**
         * support for the assignment operator.
         * rhs: a setXX, an array of E members or a izBitSet of same type.
         */
        nothrow @safe opAssign(S rhs)
        {
            (rhs <= fMax) ? (fSet = rhs) : (fSet = fMax);
            return this;
        }

        /// ditto
        nothrow @safe void opAssign(E[] rhs)
        {
            fSet = 0;
            foreach(elem; rhs) include(elem);
        }

        /// ditto
        nothrow @safe void opAssign(izBitSet!(S,E) rhs)
        {
            fSet = rhs.fSet;
        }

        /// support for the array syntax.
        bool opIndex(S index)
        {
            return (fSet == (fSet | _1 << index));
        }

        /// ditto
        bool opIndex(E member)
        {
            return isIncluded(member);
        }

        /// support for "+" and "-" operators.
        nothrow @safe izBitSet!(S,E) opBinary(string op)(E rhs)
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

        /// support for "+" and "-" operators.
        nothrow @safe izBitSet!(S,E) opBinary(string op)(E[] rhs)
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

        /// support for comparison "=" and "!=" operators.
        nothrow @safe bool opEquals(S rhs)
        {
            return (fSet == rhs);
        }

        /// ditto
        nothrow @safe bool opEquals(izBitSet!(S,E) rhs)
        {
            return (fSet == rhs.fSet);
        }

        /// ditto
        nothrow @safe  bool opEquals(E[] rhs)
        {
            auto rhsset = izBitSet!(S,E)(rhs);
            return (rhsset.fSet == fSet);
        }

// Pascal-ish primitives -------------------------------------------------------

        /**
         * includes someMembers in the set.
         * someMembers: a list of E members or an array of E members.
         * this is the primitive used for to the operator "+".
         */
        nothrow @safe void include(E...)(E someMembers)
        {
            static if (someMembers.length == 1)
                fSet += _1 << fRankLUT[someMembers];
            else foreach(member; someMembers)
                fSet += _1 << fRankLUT[member];
        }

        /// ditto
        nothrow @safe void include(E[] someMembers)
        {
            foreach(member; someMembers)
                fSet += _1 << fRankLUT[member];
        }

        /**
         * excludes someMembers from the set.
         * someMembers: a list of E members or an array of E members.
         * this is the primitive used for to the operator "-".
         */
        nothrow @safe void exclude(E...)(E someMembers)
        {
            static if (someMembers.length == 1)
                fSet ^= _1 << fRankLUT[someMembers];
            else foreach(member; someMembers)
                fSet ^= _1 << fRankLUT[member];
        }

        /// ditto
        nothrow @safe void exclude(E[] someMembers)
        {
            foreach(member; someMembers)
                fSet ^= _1 << fRankLUT[member];
        }

        /**
         * returns true if aMember is in the set.
         * aMember: a  E member.
         */
        nothrow @safe bool isIncluded(E aMember)
        {
            return (fSet == (fSet | _1 << fRankLUT[aMember]));
        }

// misc helpers ----------------------------------------------------------------

        /// returns true if the set is empty.
        nothrow @safe bool none()
        {
            return fSet == 0;
        }

        /// returns true if at least one member is included.
        nothrow @safe bool any()
        {
            return fSet != 0;
        }

        /// returns true if all the members are included.
        nothrow @safe bool all()
        {
            return fSet == fMax;
        }

        /// returns the maximal value the set can have.
        nothrow @safe static const(S) max()
        {
            return fMax;
        }

        /// returns a lookup table which can be used to retrieve the rank of a member.
        nothrow @safe static ref const(S[E]) rankLookup()
        {
            return fRankLUT;
        }

        /// returns the enum count
        nothrow @safe static const(S) memberCount()
        {
            return cast(S) enumMemberCount!E;
        }
}


/// returns true if T and E are suitable for constructing an izEnumProcs
private static bool isCallableFromEnum(T, E)()
{
    return ((is(E==enum)) & (isCallable!T));
}

/**
 * CallTable based on an enum. It can be compared to an associative array of type E[T].
 * Additionally a bitset can be used to fire a burst of call.
 * E: an enum.
 * T: a callable type.
 */
public struct izEnumProcs(E,T) if (isCallableFromEnum!(T,E))
{
    private
    {
        static immutable uint[E] fRankLUT;
        static immutable uint _1 = 1U;
        alias ReturnType!T retT;
        T[] procs;

        void initLength()
        {
            procs.length = fRankLUT.length;
        }
    }
    public
    {

// constructors ----------------------------------------------------------------

        /// static constructor
        nothrow @safe static this()
        {
            static assert( enumMemberCount!E < uint.max );
            foreach(i, member; EnumMembers!E)
                fRankLUT[member] = i;
        }

        /**
         * constructs an enumCallee with a set of T.
         * a: a list of T.
         */
        nothrow this(A...)(A a)
        {
            static assert(a.length == enumMemberCount!E);
            initLength;
            foreach(i, item; a)
            {
                procs[i] = a[i];
            }
        }

        /**
         * constructs an enumCallee with an array of T.
         * someItems: an array of T.
         */
        nothrow this(T[] someItems)
        {
            assert(someItems.length == enumMemberCount!E);
            initLength;
            foreach(i, item; someItems)
            {
                procs[i] = someItems[i];
            }
        }

// call ------------------------------------------------------------------------

        /**
         * calls the function matching to selector rank.
         * selector: an E member.
         * prms: arguments for calling the function.
         */
        retT opCall(CallParams...)(E selector, CallParams prms)
        {
            return procs[fRankLUT[selector]](prms);
        }

        /**
         * calls the functions matching to a set of selectors.
         * selectors: a set of E.
         * prms: common or selector-sepcific arguments for calling the functions.
         * return: an array representing the result of each selector, by rank.
         */
        retT[] opCall(BS,CallParams...)(BS selectors, CallParams prms)
        if  (   (is(BS == izBitSet!(set8,E)))
            ||  (is(BS == izBitSet!(set16,E)))
            ||  (is(BS == izBitSet!(set32,E)))
            ||  (is(BS == izBitSet!(set64,E)))
            )
        {
            retT[] result;
            result.length = cast(size_t) enumMemberCount!E;

            static if(!isArray!(CallParams[0]))
            {
                for(selectors.setType i = 0; i < selectors.memberCount; i++)
                {
                    if (selectors[i])
                        result[i] = procs[i](prms);
                }
                return result;
            }
            else
            {
                for(selectors.setType i = 0; i < selectors.memberCount; i++)
                {
                    if (selectors[i])
                        result[i] = procs[i](prms[0][i]);
                }
                return result;
            }
        }
    }
}

version(unittest)
{
    enum a4     {a0,a1,a2,a3}
    enum a8     {a0,a1,a2,a3,a4,a5,a6,a7}
    enum a9     {a0,a1,a2,a3,a4,a5,a6,a7,a8}
    enum a16    {a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15}
    enum a17    {a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16}

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
        static assert( enumFitsInSet!(a8,set8));
        static assert( !enumFitsInSet!(a9,set8));
        static assert( enumFitsInSet!(a16,set16));
        static assert( !enumFitsInSet!(a17,set16));
    }

    /// operator operations
    unittest
    {
        alias izBitSet!(set8,a8) bs8;
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
        version(coeditmessages)
            writeln("izBitSet passed the tests(operators)");
    }

    unittest
    {
        izBitSet!(set32,a17) set;
        set.include(a17.a8,a17.a9);
        assert(!set.isIncluded(a17.a7));
        assert(set.isIncluded(a17.a8));
        assert(set.isIncluded(a17.a9));
        assert(!set.isIncluded(a17.a10));
        version(coeditmessages)
            writeln("izBitSet passed the tests(isIncluded)");
    }

    unittest
    {
        auto bs = izBitSet!(set32,a17)(a17.a0,a17.a1,a17.a16);
        assert(bs[0]);
        assert(bs[1]);
        assert(bs[16]);
        assert(bs[a17.a0]);
        assert(bs[a17.a1]);
        assert(bs[a17.a16]);
        assert(!bs[8]);
        assert(!bs[a17.a8]);
        version(coeditmessages)
            writeln("izBitSet passed the tests(array operators)");
    }

    unittest
    {
        auto set = izBitSet!(set8,a8)(a8.a3, a8.a5);
        assert(set == 0b0010_1000);
        auto rep = set.toString;
        set = 0;
        assert(set == 0);
        set = izBitSet!(set8,a8)(rep);
        assert(set == 0b0010_1000);
        // test asBitString
        auto brep = set.asBitString;
        assert( brep == "0b00101000", brep );
        set = 0b1111_0000;
        brep = set.asBitString;
        assert( brep == "0b11110000", brep );

        //set = 0;
        //set = to!set8(brep);
        //assert(set == 0b1111_0000);
        version(coeditmessages)
            writeln("izBitSet passes the tests(toString)");
    }

    unittest
    {
        auto set = izBitSet!(set32,a17)(a17.a0);
        assert( set.rankLookup[a17.a16] == 16);
        assert( set.rankLookup[a17.a15] == 15);
        version(coeditmessages)
            writeln("izBitSet passed the tests(misc.)");
    }

    /// callprocs
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
        assert( BCaller(A.t1, 1) == 11);
        assert( BCaller(A.t2, 2) == 22);
        assert( BCaller(A.t3, 3) == 33);

        auto bs = izBitSet!(set8,A)();
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

        int Ct1(int p[2]){return p[0] + p[1];}
        int Ct2(int p[2]){return p[0] * p[1];}
        int Ct3(int p[2]){return p[0] - p[1];}
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

        version(coeditmessages)
            writeln("izEnumProcs passed the tests");
    }
}
