module iz.strings;

import std.range, std.traits, std.algorithm.searching;
import iz.sugar;

// Character-related-structs --------------------------------------------------+

/**
 * CharRange is an helper struct that allows to test
 * fast if a char is within a full range of characters.
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
    private dchar _min, _max;
    
    private void setMinMax(dchar value) nothrow 
    {
        if (value <= _min) _min = value;
        else if (value >= _max) _max = value;
        _map.length = _max + 1 - _min; 
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
                foreach(size_t i; elem._min - result._min .. elem._max - result._min + 1)
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
    CharMap cm = CharMap['a'..'f', '0'..'9' , 'A'..'F', '_', 9];
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
    assert('\t' in cm);      
}

/// A CharMap that includes the hexadecimal characters.
immutable CharMap hexChars = CharMap['a'..'f', 'A'..'F', '0'..'9'];
/// A CharMap that includes the white characters.
immutable CharMap whiteChars = CharMap['\t'..'\r', ' '];

/**
 * Returns a input range to process directly a C-style null terminated string 
 * without converting it to a D string.
 * Params:
 * c = a pointer to a character.
 * Returns:
 * A InputRange whose elements type matches c target type.
 */
auto nullTerminated(C)(C c)
if (isPointer!C && isSomeChar!(PointerTarget!(C)))
{
    struct NullTerminated(C)   
    {
        private C _front;
        ///
        this(C c)
        {
            _front = c;
        }
        ///
        @property bool empty()
        {
            return *_front == 0;
        }
        ///
        auto front()
        {
            return *_front;
        }
        ///
        void popFront()
        {
            ++_front;
        }
        ///
        C save()
        {
            return _front;
        }
    }
    return NullTerminated!C(c);
}

unittest
{
    auto text = "ab cd\0";
    auto cString = nullTerminated(text.ptr);
    assert(nextWord(cString) == "ab");
    assert(nextWord(cString) == "cd");
    assert(cString.empty);
    auto wtext = "ab cd\0"w;
    auto cWideString = nullTerminated(wtext.ptr);
    assert(nextWord(cWideString) == "ab"w);
    assert(nextWord(cWideString) == "cd"w);
    assert(cWideString.empty);    
}


// -----------------------------------------------------------------------------
// Generic Scanning functions -------------------------------------------------+
private template CharType(T)
{
    alias CharType = Unqual!(ElementEncodingType!T);
}

// test if T is supported in the several scanning utils
// T must either supports the 'in' operator, supports 'algorithm.searching.canFind'
// or be a 'bool(dchar)' callable.
private bool isCharTester(T)()
{
    static if (isInputRange!T && isSomeChar!(ElementType!T))
        return true;
    else static if (is(Unqual!T == CharRange)) 
        return true;
    else static if (is(Unqual!T == CharMap)) 
        return true;    
    else static if (isAssociativeArray!T && isSomeChar!(KeyType!T)) 
        return true; 
    else static if (isSomeFunction!T && is(ReturnType!T == bool) && 
        Parameters!T.length == 1 && is(Parameters!T[0] == dchar))
        return true;
    else 
        return false;
}

/**
 * Returns the next word in the range passed as argument.
 *
 * Params: 
 * range = A character input range. The range is consumed for each word.
 * charTester = Defines the valid characters to make a word.
 *
 * Returns:
 * A dstring containing the word. If the result length is null then the
 * range parameter has not been consumed.
 */
auto nextWord(Range, T, bool until = false)(ref Range range, T charTester)
if (isInputRange!Range && isSomeChar!(ElementType!Range) && isCharTester!T)
{
    alias UT = Unqual!T; 
    CharType!Range[] result;
    CharType!Range current; 
               
    static if (is(UT == CharRange) || is(UT == CharMap) || isAssociativeArray!T)
    {
        while (true)
        {
            if (range.empty) break;
            current = cast(CharType!Range) range.front;            
            
            static if (until)
            {
                if (current !in charTester)
                {
                    result ~= current;
                    range.popFront;
                }
                else break;
            }
            else
            {                
                if (current in charTester)
                {
                    result ~= current;
                    range.popFront;
                }
                else break;
            }            
        }
    }
    else static if (isInputRange!T)
    {
        while (true)
        {
            if (range.empty) break;
            current = cast(CharType!Range) range.front;
            
            static if (until)
            {
                if (!canFind(charTester, current))
                {
                    result ~= current;
                    range.popFront;
                }
                else break;            
            }
            else
            {                        
                if (canFind(charTester, current))
                {
                    result ~= current;
                    range.popFront;
                }
                else break;
            }
        }  
    }
    else static if (isSomeFunction!UT)
    {
        while (true)
        {
            if (range.empty) break;
            current = cast(CharType!Range) range.front;
            
            static if (until)
            {
                if (!charTester(current))
                {
                    result ~= current;
                    range.popFront;
                }
                else break;            
            }
            else
            {                        
                if (charTester(current))
                {
                    result ~= current;
                    range.popFront;
                }
                else break;
            }
        }    
    }
    else static assert(0, "unsupported charTester argument type in nextWord(): " ~ T.stringof);
    
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
    import std.ascii: isAlpha;
    auto w33 = nextWord(src2, &isAlpha); 
    assert(w33 == "ty");             
}

/**
 * Returns the next word in the range passed as argument.
 *
 * Params: 
 * range = A character input range. The range is consumed for each word.
 * charTester = Defines the opposite of the valid characters to make a word. 
 *
 * Returns:
 * A string containing the word. If the result length is null then the
 * range parameter has not been consumed.
 */
auto nextWordUntil(Range, T)(ref Range range, T charTester)
{
    return nextWord!(Range, T, true)(range, charTester);
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
 * charTester = Defines the valid characters to make a word.
 */
void skipWord(Range, T, bool until = false)(ref Range range, T charTester)
if (isInputRange!Range && isSomeChar!(ElementType!Range) && isCharTester!T)
{         
    alias UT = Unqual!T;
    static if (is(UT == CharRange) || is(UT == CharMap) || isAssociativeArray!T)
    {
        while (true)
        {
            if (range.empty) break;
            static if (until)
            {
                if (range.front !in charTester)
                    range.popFront;
                else break;
            }     
            else
            {
                if (range.front in charTester)
                    range.popFront;
                else break;            
            }       
        }
    }
    else static if (isInputRange!T)
    {
        while (true)
        {
            if (range.empty) break;
            static if (until)
            {
                if (!canFind(charTester, range.front))
                    range.popFront;
                else break;            
            }
            else
            {
                if (canFind(charTester, range.front))
                    range.popFront;
                else break;
            }
        }  
    }
    else static if (isSomeFunction!UT)
    {
        while (true)
        {
            if (range.empty) break;
            static if (until)
            {
                if (!charTester(range.front))
                    range.popFront;
                else break;            
            }
            else
            {                        
                if (charTester(range.front))
                    range.popFront;
                else break;
            }
        }    
    }    
    else static assert(0, "unsupported charTester argument type in skipWord(): " ~ T.stringof);
}

unittest
{
    auto src1 = "\t\t\r\ndd";
    auto skp1 = CharRange("\r\n\t");
    skipWord(src1, skp1);
    assert(src1 == "dd");
    import std.ascii: isWhite;
    auto src2 = "\t\t\r\nee";
    skipWord(src2, &isWhite);
    assert(src2 == "ee");    
}

/**
 * Skips the next word in the range passed as argument.
 *
 * Params:
 * range = A character input range. The range is consumed for each word.
 * charTester = Defines the opposite of the valid characters to make a word.
 */
void skipWordUntil(Range, T)(ref Range range, T charTester)
{
    return skipWord!(Range, T, true)(range, charTester);
}

unittest
{
    auto src = "dd\r";
    auto skp = CharRange("\r\n\t");
    skipWordUntil(src, skp);
    assert(src == "\r");
}

/**
 * Tries to make a fixed length slice by consuming range.
 */
auto nextSlice(Range, T)(ref Range range, T len)
if (isInputRange!Range && isSomeChar!(ElementType!Range) && isIntegral!T)
{
    CharType!Range[] result;
    
    while (true)
    {
        if (result.length == len || range.empty)
            break;
        result ~= range.front;
        range.popFront;   
    }   
    
    return result;       
}

unittest
{
    auto text0 = "012"; 
    assert(text0.nextSlice(2) == "01");
    auto text1 = "3";
    assert(text1.nextSlice(8) == "3");
    auto text2 = "45";
    assert(text2.nextSlice(0) == "");
    assert(text1.nextSlice(123456) == "");
}

/**
 * Returns true of str starts with stuff.
 */
bool canRead(String, Stuff)(ref String str, Stuff stuff)
if (isSomeString!String && (isSomeChar!Stuff || isSomeString!Stuff))
{
    if (str.empty)
        return false;
    else
    {
        static if (isSomeChar!Stuff)
            return str.front == stuff;
        else
        {
            auto reader = ArrayRange!(ElementEncodingType!String)(str);
            auto slice = reader.nextSlice(stuff.length);
            return (slice.length != stuff.length) ? false : stuff == slice;
        }  
    }  
}

unittest
{
    auto text0 = "{0}".dup;
    assert(text0.canRead('{'));
    auto text1 = "(* bla *)".dup;
    assert(text1.canRead("(*"));
    assert(text1 == "(* bla *)");
    string text2 = "0x123456";
    assert(!text2.canRead("0b"));
}
//------------------------------------------------------------------------------
// Text scanning utilities ----------------------------------------------------+

/**
 * Returns an input range consisting of the input argument sliced by group of 
 * length len.
 */
auto bySlice(Range)(ref Range range, size_t len)
if (isInputRange!Range && isSomeChar!(ElementType!Range))
{ 
    struct BySlice
    {
        private Range _range;
        private bool _emptyLine;
        private CharType!Range[] _front;
        ///
        this(Range range)
        {
            _range = range;
            popFront;
        }
        ///
        void popFront()
        {
            _front = nextSlice(_range, len);
        }
        ///
        auto front()
        {
            return _front;
        }
        ///
        @property bool empty()
        {
            return _front.length == 0;
        }
    }
    return BySlice(range);
}

unittest
{
    auto text = "AABBCCDD";
    assert(text.bySlice(2).array == ["AA","BB","CC","DD"]);
    auto str = "AAE";
    assert(str.bySlice(2).array == ["AA","E"]);
}


/**
 * Returns the next line within range.
 */
auto nextLine(bool keepTerminator = false, Range)(ref Range range)
{
    auto result = nextWordUntil(range, "\r\n");
    static if (keepTerminator)
    {
        if (range.canRead("\r\n")) result ~= range.nextSlice(2);
        else if (range.canRead('\n')) result ~= range.nextSlice(1);
    }
    else
    {
        if (range.canRead("\r\n")) range.nextSlice(2);
        else if (range.canRead('\n')) range.nextSlice(1);    
    }       
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
    assert(nextLine!false(text) == "");   
}

/**
 * Returns an input range consisting of each line in the input argument
 */
auto byLine(Range)(ref Range range)
if (isInputRange!Range && isSomeChar!(ElementType!Range))
{ 
    struct ByLine
    {
        private Range _range;
        private bool _emptyLine;
        private CharType!Range[] _front, _strippedfront;
        ///
        this(Range range)
        {
            _range = range;
            popFront;
        }
        ///
        void popFront()
        {
            _front = nextLine!true(_range);
            import std.string;
            _strippedfront = stripRight(_front);
        }
        ///
        auto front()
        {
            return _strippedfront;
        }
        ///
        @property bool empty()
        {
            return _front.length == 0;
        }
    }
    return ByLine(range);
}

unittest
{
    import std.stdio;
    auto text = "aw\r\nyess";
    auto range = text.byLine;
    assert(range.front == "aw");
    range.popFront;
    assert(range.front == "yess");
    auto nums = "0\n1\n2\n3\n4\n5\n6\n7\n8\n9";
    import std.algorithm.iteration: reduce;
    assert(nums.byLine.reduce!((a,b) => a ~ b) == "0123456789");
}

/**
 * Returns the lines count within the input range.
 * The input range is not consumed.
 */
size_t lineCount(Range)(Range range)
{
    return range.byLine.array.length;    
}

unittest
{
    auto text1= "";
    assert(text1.lineCount == 0);
    auto text2 = "\n\r\n";
    assert(text2.lineCount == 2);
    auto text3 = "0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n\n\n";
    assert(text3.lineCount == 12);
}

/**
 * Returns the next word within range. 
 * Words are spliited using the White characters, which are never included.
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
 * Returns an input range consisting of each non-blank word in the input argument.
 */
auto byWord(Range)(ref Range range)
if (isInputRange!Range && isSomeChar!(ElementType!Range))
{ 
    struct ByWord
    {
        private Range _range;
        private CharType!Range[] _front;
        ///
        this(Range range)
        {
            _range = range;
            popFront;
        }
        ///
        void popFront()
        {
            _front = nextWord(_range); 
        }
        ///
        auto front()
        {
            return _front;
        }
        ///
        @property bool empty()
        {
            return _front.length == 0;
        }
    }
    return ByWord(range);
}

unittest
{
    auto text = "aw yess, this is so cool";
    auto range = text.byWord;
    assert(range.front == "aw");
    range.popFront;
    assert(range.front == "yess,");
    range.popFront;
    assert(range.front == "this");
    auto nums = "0 1 2 3 4 5 6 7 8 9";
    import std.algorithm.iteration: reduce;
    assert(nums.byWord.reduce!((a,b) => a ~ b) == "0123456789");
}

/**
 * Returns the word count within the input range.
 * Words are separatedd by ascii whites. input range is not consumed.
 */
size_t wordCount(Range)(Range range)
{
    return range.byWord.array.length;    
}

unittest
{
    auto text = "1 2 3 4 5 6 7 8 9 \n 10";
    assert(text.wordCount == 10);
    assert(text == "1 2 3 4 5 6 7 8 9 \n 10");
}


/**
 * Returns the next separated word.
 * Separators are always removed, white characters optionally.
 */
auto nextSeparated(Range, Separators, bool strip = true)(ref Range range, Separators sep)
{
    auto result = nextWordUntil(range, sep);
    if (!range.empty) range.popFront;
    static if (strip)
    {
        skipWord(result, whiteChars);
        result = nextWordUntil(result, whiteChars);
    }
    return result;   
}

unittest
{
    import std.stdio;
    auto seps = CharMap[',', '\n'];
    auto text = "name, age \n Douglas, 27 \n Sophia 26";
    assert(text.nextSeparated(seps) == "name");
    assert(text.nextSeparated(seps) == "age");
    assert(text.nextSeparated(seps) == "Douglas");
    assert(text.nextSeparated(seps) == "27");
}

/**
 * Returns an input range consisting of each separated word in the input argument
 */
auto bySeparated(Range, Separators, bool strip = true)(ref Range range, Separators sep)    
if (isInputRange!Range && isSomeChar!(ElementType!Range))
{ 
    struct BySep
    {
        private Range _range;
        private CharType!Range[] _front;
        ///
        this(Range range)
        {
            _range = range;
            popFront;
        }
        ///
        void popFront()
        {
            _front = nextSeparated!(Range, Separators, strip)(_range, sep); 
        }
        ///
        auto front()
        {
            return _front;
        }
        ///
        @property bool empty()
        {
            return _front.length == 0;
        }
    }
    return BySep(range);        
}

unittest
{
    auto text = "name = Douglas \n age =27 \n";
    auto range = text.bySeparated(CharMap['=', '\n']);
    assert(range.front == "name");
    range.popFront;
    assert(range.front == "Douglas");
    range.popFront;
    assert(range.front == "age");
    range.popFront;
    assert(range.front == "27");
    range.popFront;
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
    
    string t = "456";
    if (auto num = readDecNumber(t))
        assert (num == "456");
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
    auto text = "  \n\r\v bla".dup;
    auto rng = ArrayRange!char(text); 
    rng.stripLeftWhites;
    assert(rng.array == "bla");  
}
//------------------------------------------------------------------------------

