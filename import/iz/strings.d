module iz.strings;

import std.range, std.traits, std.algorithm.searching;

/**
 * CharRange is an helper struct that allows to test
 * fastly if a char is within a full range of characters.
 */
struct CharRange
{
    import std.conv: to;
    private dchar _min, _max;
    
    /**
     * Constructs the char range using a string that contains
     * the range bounds.
     *
     * Params:
     * s = a string. It neither has to be sorted nor to contain the full range.
     */
    this(S)(S s) pure @safe
    if (isSomeString!S)
    {
        import std.algorithm.sorting: sort;        
        auto sorted = sort(to!(dchar[])(s));
        _min = sorted[0];
        _max = sorted[$-1];
    }
    
    /**
     * Constructs the char range using the two chars passed as argument.
     *
     * Params:
     * cmin: The lower character in the range.
     * cmax: The upper (inclusive) character in the range.
     */
    this(C)(C cmin, C cmax) pure @safe
    if (isSomeChar!C || isImplicitlyConvertible!(C, dchar))
    {
        auto const maybeMin = to!dchar(cmin);
        auto const maybeMax = to!dchar(cmax);
        if (maybeMin <= maybeMax)
        {
            _min = maybeMin;
            _max = maybeMax;
        }
        else
        {
            _min = maybeMax;
            _max = maybeMin;
        }     
    }
    
    /// returns the lower char in the range.
    dchar min() pure nothrow @safe @nogc
    {return _min;}
    
    /// returns the upper char in the range.
    dchar max() pure nothrow @safe @nogc
    {return _max;}

    /**
     * Returns true if a character is within the range.
     *
     * Params:
     * c = A character or any value convertible to a dchar.
     */
    bool opIn_r(C)(C c) pure nothrow @safe @nogc 
    {
        static if (isSomeChar!C || isImplicitlyConvertible!(C, dchar))
        {
            return ((c >= _min) & (c <= _max)); 
        }
        else static assert(0, "invalid argument type for CharRange.opIn()");
    }
    
    /**
     * Returns the range representation, as a string.
     * This function will fail if the range is not within the 0x0 .. 0x80 range.
     */
    string toString() const pure @safe
    {
        auto r = iota(_min, _max+1);
        string result;
        while (!r.empty)
        {
            result ~= to!char(r.front);
            r.popFront;
        }
        return result;
    }
}

pure @safe unittest
{
    auto cs1 = CharRange("ajslkdfjlz");
    assert(cs1.min == 'a');
    assert(cs1.max == 'z');
    assert('b' in cs1);
    
    auto cs2 = CharRange('f', 'a');
    assert(cs2.min == 'a');
    assert(cs2.max == 'f'); 
    assert('b' in cs2);
    assert('g' !in cs2);   
    assert(cs2.toString == "abcdef", cs2.toString);
    
    auto cs3 = CharRange(65, 70);
    assert(cs3.min == 65);
    assert(cs3.max == 70); 
    assert(66 in cs3);
    assert(71 !in cs3);  
}

// test if CS issupported in the several scanning utils
private bool isCharRange(CS)()
{
    static if (is(CS == char[])) return true;
    else static if (is(CS == char[])) return true;
    else static if (is(CS == wchar[])) return true;
    else static if (is(CS == dchar[])) return true;
    else static if (is(CS == string)) return true;
    else static if (is(CS == wstring)) return true;
    else static if (is(CS == dstring)) return true;  
    else static if (is(CS == CharRange)) return true;   
    else return false;
}

/**
 * Returns the next word in the range passed as argument.
 *
 * Params: 
 * range = A character input range. The range is consumed for each word.
 * charRange = Defines the valid characters to make a word.
 *
 * Return:
 * A dstring containing the word. If the result length is null then the
 * range parameter has not been consumed.
 */
auto nextWord(Range, CR, bool until = false)(ref Range range, CR charRange)
if (isInputRange!Range && isSomeChar!(ElementType!Range) && isCharRange!CR)
{
    alias CharType = ElementType!Range;
    CharType[] result;
    CharType current; 
               
    static if (is(CR == CharRange))
    {
        while (true)
        {
            if (range.empty) break;
            current = range.front;            
            
            static if (until)
            {
                if (current !in charRange)
                {
                    result ~= current;
                    range.popFront;
                }
                else break;
            }
            else
            {                
                if (current in charRange)
                {
                    result ~= current;
                    range.popFront;
                }
                else break;
            }            
        }
    }
    else static if (isInputRange!CR)
    {
        while (true)
        {
            if (range.empty) break;
            current = range.front;
            
            static if (until)
            {
                if (!canFind(charRange, current))
                {
                    result ~= current;
                    range.popFront;
                }
                else break;            
            }
            else
            {                        
                if (canFind(charRange, current))
                {
                    result ~= current;
                    range.popFront;
                }
                else break;
            }
        }  
    }
    else static assert(0, "unsupported charRange argument in nextWord()");
    
    return result;    
}

unittest
{
    auto cs1 = "azertyuiopqsdfghjklmwxcvbn";
    auto cs2 = " \r\n\t";
    auto cs3 = CharRange('a','z');
    auto src1 = "az er
    ty";
    auto src2 = "az er
    ty";
    
    auto w1 = nextWord(src1, cs1); 
    assert(w1 == "az");
    nextWord(src1, cs2);
    auto w2 = nextWord(src1, cs1); 
    assert(w2 == "er");
    nextWord(src1, cs2);
    auto w3 = nextWord(src1, cs1); 
    assert(w3 == "ty");
    nextWord(src1, cs2);   
    
    auto w11 = nextWord(src2, cs3); 
    assert(w11 == "az");
    nextWord(src2, cs2);
    auto w22 = nextWord(src2, cs3); 
    assert(w22 == "er");
    nextWord(src2, cs2);
    auto w33 = nextWord(src2, cs3); 
    assert(w33 == "ty");
    nextWord(src2, cs2);          
}

/**
 * Returns the next word in the range passed as argument.
 *
 * Params: 
 * range = A character input range. The range is consumed for each word.
 * charRange = Defines the opposite of the valid characters to make a word. 
 *
 * Return:
 * A dstring containing the word. If the result length is null then the
 * range parameter has not been consumed.
 */
auto nextWordUntil(Range, CR)(ref Range range, CR charRange)
{
    return nextWord!(Range, CR, true)(range, charRange);
}

unittest
{
    auto src = "azertyuiop
    sdfghjk";
    auto skp = CharRange("\r\n\t");
    auto w = nextWordUntil(src, skp);
    assert(w == "azertyuiop");
}


/**
 * Skips the next word in the range passed as argument.
 *
 * Params:
 * range = A character input range. The range is consumed for each word.
 * charRange = Defines the valid characters to make a word.
 */
void skipWord(Range, CR, bool until = false)(ref Range range, CR charRange)
if (isInputRange!Range && isSomeChar!(ElementType!Range) && isCharRange!CR)
{         
    static if (is(CR == CharRange))
    {
        while (true)
        {
            if (range.empty) break;
            static if (until)
            {
                if (range.front !in charRange)
                    range.popFront;
                else break;
            }     
            else
            {
                if (range.front in charRange)
                    range.popFront;
                else break;            
            }       
        }
    }
    else static if (isInputRange!CR)
    {
        while (true)
        {
            if (range.empty) break;
            static if (until)
            {
                if (!canFind(charRange, range.front))
                    range.popFront;
                else break;            
            }
            else
            {
                if (canFind(charRange, range.front))
                    range.popFront;
                else break;
            }
        }  
    }
    else static assert(0, "unsupported charRange argument in skipWord()");
}

unittest
{
    auto src = "\t\t\r\ndd";
    auto skp = CharRange("\r\n\t");
    skipWord(src, skp);
    assert(src == "dd");
}

/**
 * Skips the next word in the range passed as argument.
 *
 * Params:
 * range = A character input range. The range is consumed for each word.
 * charRange = Defines the opposite of the valid characters to make a word.
 */
auto skipWordUntil(Range, CR)(ref Range range, CR charRange)
{
    return skipWord!(Range, CR, true)(range, charRange);
}

unittest
{
    auto src = "dd\r";
    auto skp = CharRange("\r\n\t");
    skipWordUntil(src, skp);
    assert(src == "\r");
}

auto nextLine(bool keepTerminator = false, Range)(ref Range range)
{
    auto result = nextWordUntil(range, "\r\n");
    static if (!keepTerminator) skipWord(range, "\r\n");
    return result; 
}

unittest
{
    auto text = "123456\r\n12345\n1234\r\n123\r\n12\r\n1";
    assert(nextLine!false(text) == "123456");
    assert(nextLine!false(text) == "12345");
    assert(nextLine!false(text) == "1234");
    assert(nextLine!false(text) == "123");
    assert(nextLine!false(text) == "12");
    assert(nextLine!false(text) == "1");
    assert(nextLine!false(text) == "");   
}

