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
            writeln("izBitSet passes the tests(operators)");
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
            writeln("izBitSet passes the tests(isIncluded)");
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
            writeln("izBitSet passes the tests(misc.)");
    }
}
