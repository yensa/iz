module iz.strings;

import std.range, std.traits, std.algorithm.searching;

// Character-related-structs --------------------------------------------------+

/**
 * CharRange is an helper struct that allows to test
 * fastly if a char is within a full range of characters.
 */
struct CharRange
{
    import std.conv: to;
    private immutable dchar _min, _max;
    
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
    bool opIn_r(C)(C c) pure nothrow @safe @nogc const 
    {
        static if (isSomeChar!C || isImplicitlyConvertible!(C, dchar))
        {
            return ((c >= _min) & (c <= _max)); 
        }
        else static assert(0, "invalid argument type for CharRange.opIn_r(): " ~ C.stringof);
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

static immutable CharRange decimalChars = CharRange('0', '9');
static immutable CharRange hexLowerChars = CharRange('a', 'f');
static immutable CharRange hexUpperChars = CharRange('A', 'F');
static immutable CharRange octalChars = CharRange('0', '7');

/**
 * CharMap is an helper struct that allows to test
 * if a char is within a set of characters.
 */
struct CharMap
{
    import iz.memory;
    private bool[] _map;
    private dchar _min, _max = 1;
    
    private void setMinMax(dchar value) nothrow 
    {
        if (value < _min) _min = value;
        else if (value > _max)
        {
            _max = value;
            _map.length = _max + 1;
        }   
    }

    /**
     * Used in the construction process.
     * Example:
     * ---
     * CharMap cm = CharMap['0'..'9'];
     * ---
     */
    static CharRange opSlice(int index)(dchar lo, dchar hi) nothrow @nogc 
    {
        return CharRange(lo, hi);
    }
    
    /**
     * Used in the construction process.
     * Params:
     * a = alist made of character slices, of single character or
     * any value implicitly convertible to dchar.
     * Example:
     * ---
     * CharMap cm = CharMap['0'..'9', '.', 'f', 'd', 38, 39];
     * ---
     */
    static CharMap opIndex(A...)(A a) nothrow 
    {   
        CharMap result;
        
        // bounds
        foreach(elem; a)
        {
            alias T = typeof(elem);
            static if (isSomeChar!T || isImplicitlyConvertible!(T, dchar))
            {
                result.setMinMax(elem);      
            }
            else static if (is(T == CharRange))
            {
                result.setMinMax(elem._min);
                result.setMinMax(elem._max);    
            }
            else static assert(0, "unsupported opIndex argument type: " ~ T.stringof);
        }
        
        result._map[] = false;   
        foreach(elem; a)
        {    
            alias T = typeof(elem);
            static if (isSomeChar!T || isImplicitlyConvertible!(T, dchar))
                result._map[elem - result._min] = true;   
            else static if (is(T == CharRange))
            {
                CharRange cr = cast(CharRange) elem;
                foreach(size_t i; cr._min - result._min .. cr._max - result._min + 1)
                    result._map[i] = true;          
            } 
        }        
        return result;
    }
    
    /**
     * Returns true if a character is within the map.
     *
     * Params:
     * c = A character or any value convertible to a dchar.
     */    
    bool opIn_r(C)(C c) pure nothrow @nogc const 
    {
        static if (isSomeChar!C || isImplicitlyConvertible!(C, dchar))
        {
            if (c < _min || c > _max) return false;
            else return _map[c - _min]; 
        }
        else static assert(0, "invalid argument type for CharMap.opIn_r(): " ~ C.stringof);
    }
}

unittest
{
    CharMap cm = CharMap['a'..'f', '0'..'9' , 'A'..'F', '_'];
    assert('a' in cm);
    assert('b' in cm);
    assert('c' in cm);
    assert('d' in cm);
    assert('e' in cm);
    assert('f' in cm);
    assert('g' !in cm);
    assert('A' in cm);
    assert('B' in cm);
    assert('C' in cm);
    assert('D' in cm);
    assert('E' in cm);
    assert('F' in cm);
    assert('G' !in cm);
    assert('0' in cm);
    assert('4' in cm);
    assert('9' in cm);
    assert('_' in cm);
    assert('%' !in cm);    
}

immutable CharMap hexChars = CharMap['a'..'f', 'A'..'F', '0'..'9'];
immutable CharMap whiteChars = CharMap['\t'..'\r', ' '];
// -----------------------------------------------------------------------------
// Generic Scanning functions -------------------------------------------------+

// test if T issupported in the several scanning utils
// T must either support the 'in' operator or algorithm.searching.canFind
private bool isCharRange(T)()
{
    static if (isArray!T && isSomeChar!(ElementType!T))
        return true;
    else static if (is(Unqual!T == CharRange)) 
        return true;
    else static if (is(Unqual!T == CharMap)) 
        return true;    
    else static if (isAssociativeArray!T && isSomeChar!(KeyType!T)) 
        return true;   
    else 
        return false;
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
    alias CharType = Unqual!(ElementEncodingType!Range);
    alias UCR = Unqual!CR; 
    CharType[] result;
    CharType current; 
               
    static if (is(UCR == CharRange) || is(UCR == CharMap) || isAssociativeArray!CR)
    {
        while (true)
        {
            if (range.empty) break;
            current = cast(CharType) range.front;            
            
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
            current = cast(CharType) range.front;
            
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
    bool[dchar] cs4 = ['\r':true, '\n': true, '\t':true, ' ':true ];
    auto src1 = "az er
    ty";
    auto src2 = "az er
    ty";
    auto src3 = "az er
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
    nextWord(src2, cs4);
    auto w22 = nextWord(src2, cs3); 
    assert(w22 == "er");
    nextWord(src2, cs4);
    auto w33 = nextWord(src2, cs3); 
    assert(w33 == "ty");
    nextWord(src2, cs4);          
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
    sdfghjk".dup;
    auto skp = CharRange("\r\n\t".dup);
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
    alias UCR = Unqual!CR;
    static if (is(UCR == CharRange) || is(UCR == CharMap) || isAssociativeArray!CR)
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

//------------------------------------------------------------------------------
// Text scanning utilities ----------------------------------------------------+

/**
 * Returns the next line within range.
 */
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

/**
 * Returns the next word within range. White characters are always removed
 */
auto nextWord(Range)(ref Range range)
{
    skipWord(range, whiteChars);
    return nextWordUntil(range, whiteChars);
}

unittest
{
    auto text = " lorem ipsum 123456";
    assert(text.nextWord == "lorem");
    assert(text.nextWord == "ipsum");
    assert(text.nextWord == "123456");
}

/**
 * Tries to read a decimal number in range.
 */
auto readDecNumber(Range)(ref Range range)
{
    return range.nextWord(decimalChars);
}

unittest
{
    auto text = "0123456 789";
    assert(text.readDecNumber == "0123456");
    text.popFront;
    assert(text.readDecNumber == "789");   
}

/**
 * Tries to read an hexadecimal number in range.
 */
auto readHexNumber(Range)(ref Range range)
{
    return range.nextWord(hexChars);
}

unittest
{
    auto text1 = "1a2B3C o";
    auto text2 = "A897F2f2Ff2fF3c6C9c9Cc9cC9c123 o";
    assert(text1.readHexNumber == "1a2B3C");
    assert(text1 == " o");
    assert(text2.readHexNumber == "A897F2f2Ff2fF3c6C9c9Cc9cC9c123");
    assert(text2 == " o");   
}

/**
 * Strips the leading white characters.
 */
void stripLeftWhites(Range)(ref Range range)
{
    range.skipWord(whiteChars);
}

unittest
{
    auto text = "  \n\r bla";
    text.stripLeftWhites;
    assert(text == "bla");   
}
//------------------------------------------------------------------------------

