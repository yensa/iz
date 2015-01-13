module iz.traits;

import std.stdio;
import std.traits;
import std.typetuple;


/**
 * Checks if the methods of an interface can be found within a structure.
 *
 * The first version, slower, is able to diagnose the incompatibility.
 * The second version *short*, performs a one time check base on the method type.
 *
 * Params:
 * I = the interface used as mmodel.
 * S = the structure which has to be checked.
 * Return: true if I methods are found in S.
 */
public static bool isCompatible(I,S)()
if (is(S==struct) && is(I==interface))
{
    S s;
    static bool[] method_checked;
    method_checked.length = __traits(allMembers, I).length;
    enum msg_p = S.stringof ~ " and " ~ I.stringof ~ " are not compatible: ";
      
    foreach(i,im; __traits(allMembers, I))
    {
        // return type of function
        alias iRType = ReturnType!(__traits(getMember, I, im));
        // attribs of function
        alias iAttrib = functionAttributes!(__traits(getMember, I, im));
        // type of function params
        alias iPTypes = ParameterTypeTuple!(__traits(getMember, I, im));
        // storage class of function params
        alias iPStors = ParameterStorageClassTuple!(__traits(getMember, I, im));
        // default values of function params
        alias iDeflt = ParameterDefaultValueTuple!(__traits(getMember, I, im));
        
        foreach(sm; __traits(allMembers, S)) 
        static if (isCallable!(__traits(getMember, s, sm)) && im == sm) 
        {
            // return type of function
            alias sRType = ReturnType!(__traits(getMember, s, sm));
            // attribs of function
            alias sAttrib = functionAttributes!(__traits(getMember, s, sm));
            // type of function params
            alias sPTypes = ParameterTypeTuple!(__traits(getMember, s, sm));
            // storage class of function params
            alias sPStors = ParameterStorageClassTuple!(__traits(getMember, s, sm));
            // default values of function params
            alias sDeflt = ParameterDefaultValueTuple!(__traits(getMember, s, sm));
            
            static if (is(iPTypes == sPTypes) && iPStors==sPStors && 
                is(iRType == sRType) && iAttrib == sAttrib && is(iDeflt==sDeflt))
            {
                method_checked[i] = true;
                break;
            }
            version(unittest) {} else
            {
            static if (!is(iRType == sRType))
                pragma(msg, msg_p ~ "method '" ~ im ~ "', their return type is different"); 
            static if (iAttrib != sAttrib)
                pragma(msg, msg_p ~ "method '" ~ im ~ "', their attributes are different"); 
            static if (!is(iPTypes == sPTypes))
                pragma(msg, msg_p ~ "method '" ~ im ~ ", their parameters types are different");
            static if (iPStors != sPStors)
                pragma(msg, msg_p ~ "method '" ~ im ~ "', their parameters storage class are different");
            static if (!is(iDeflt == sDeflt))
                pragma(msg, msg_p ~ "method '" ~ im ~ "', their parameters default values are different");
            }
        }
    }    

    foreach(mc;method_checked) if (!mc) return false; 
    return true;
}

/**
 * Confer with isCompatible().
 */
public static bool isCompatible_short(I,S)()
if (is(S==struct) && is(I==interface))
{
    S s;
    static bool[] method_checked;
    method_checked.length = __traits(allMembers, I).length;
      
    foreach(i,im; __traits(allMembers, I))
    {
        // type of function
        alias iDelType = typeof(__traits(getMember, I, im));
        
        foreach(sm; __traits(allMembers, S))
        static if (isCallable!(__traits(getMember, s, sm)) && im == sm) 
        {
            // type of function
            alias sDelType = typeof(__traits(getMember, s, sm));
            static if (is(iDelType == sDelType))
            {
                method_checked[i] = true;
                break;
            }
        }
    }    
    foreach(mc;method_checked) if (!mc) return false; 
    return true;
}

version(unittest)
{
    interface I1{
        void a(uint p);
        void b(uint p);
    }
    struct S1{
        void a(ref uint b){}
        @nogc void b(uint b){}
    }
    
    interface I2{
        @nogc string asText(in uint aValue);
        @nogc string asText(in int aValue);
    }
    struct S2 {
        void nothing1(){}
        @safe void nothing2(){}
        @nogc string asText(in uint aValue){return "0";}
        @nogc string asText(const int aValue){return "0";}    
    }
    unittest
    {
        assert(!isCompatible!(I1,S1));
        assert(!isCompatible_short!(I1,S1));
        //
        assert(isCompatible!(I2,S2));
        assert(isCompatible_short!(I2,S2));
        
        writeln( "isCompatible!(interface,struct) passed the tests");
    }
}


private string getDelegates(I)()
if (is(I==interface))
{
    string result;
    foreach(member; __traits(allMembers, I))
    {
        alias DelegateType = typeof(&__traits(getMember, I, member));
        result ~= DelegateType.stringof ~ " " ~ member ~ "; ";    
    }
    return result;
}
 
struct DelegatedInterface(I)
if (is(I==interface))
{
    void* contextPtr;
    mixin(getDelegates!I);
}

DelegatedInterface!I * getDelegatedInterface(I,S)(S s)
if (isCompatible_short!(I, S))
{
    return null;
}

DelegatedInterface!I * getDelegatedInterface(I,C)(C c)
if (is(C : I))
{
    return null;
}



unittest
{
    import std.stdio;
    interface IZ {void a(int p); void b(byte p);}
    
    assert(getDelegates!IZ == "void function(int p) a; void function(byte p) b; ");
    
    alias IZDelegatedInterface = DelegatedInterface!IZ; 
}
