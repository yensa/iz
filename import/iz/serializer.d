module iz.serializer;

import std.stdio, std.typetuple, std.conv, std.traits;
import iz.types, iz.properties, iz.containers, iz.streams, iz.referencable;

// Serializable types ---------------------------------------------------------+

//TODO-cfeature: izSerializableReference can be replaced with a struct serialized as string. 

/**
 * Allows an implementer to be serialized by an izSerializer.
 */
public interface izSerializable
{
    /**
     * Indicates the type of the implementer. This information may be used
     * during the deserialization phase for type-safety or to create an
     * new class instance.
     */
    final string className()
    {
        import std.conv, std.array;
        return to!string(this)
            .split('.')[1..$]
            .join;
    }
    /**
     * Called by an izSerializer during the de/serialization phase.
     * In the implementation, the izSerializable declares its properties to the serializer.
     * Params:
     * aSerializer = the serializer. The implementer calls aSerializer.addProperty()
     * to declare arbitrarily some izPropDescriptors (run-time decision).
     */
    void declareProperties(izSerializer aSerializer);
}

/**
 * Makes a reference serializable.
 * The reference must be stored in the izReferenceMan.
 * A "referenced variable" is typically something that is assigned
 * at the run-time, such as the source of a delegate, a pointer to an Object, etc.
 */
public class izSerializableReference: izSerializable
{
    private
    {
        char[] _tp;
        ulong  _id;
        mixin izPropertiesAnalyzer;
    }
    public
    {
        this() {analyzeVirtualSetGet;}

        /**
         * Sets the internal fields according to a referenced.
         * Usually called before the serialization.
         */
        void storeReference(RT)(RT* aReferenced)
        {
            _tp = (typeString!RT).dup;
            _id = izReferenceMan.referenceID!RT(aReferenced);
        }

        /**
         * Returns the reference according to the internal fields.
         * Usually called after the deserialization.
         */
        RT* restoreReference(RT)()
        {
            return izReferenceMan.reference!RT(_id);
        }

        mixin(genPropFromField!(char[], "type", "_tp"));
        mixin(genPropFromField!(ulong,  "id",   "_id"));
        void declareProperties(izSerializer aSerializer)
        {
            aSerializer.addProperty(getDescriptor!(char[])("type"));
            aSerializer.addProperty(getDescriptor!(ulong)("id"));
        }
    }
}

/**
 * Enumerates the types automatically handled by an izSerializer.
 */
public enum izSerType
{
    _invalid = 0,
    _byte = 0x01, _ubyte, _short, _ushort, _int, _uint, _long, _ulong,
    _float= 0x10, _double,
    _char = 0x20, _wchar, _dchar,
    _izSerializable = 0x30, _Object
} 

private struct InvalidSerType{}

private alias izSerTypeTuple = TypeTuple!(
    InvalidSerType, 
    byte, ubyte, short, ushort, int, uint, long, ulong,
    float, double,
    char, wchar, dchar,
    izSerializable, Object 
);

private static string[izSerType] type2text;
private static izSerType[string] text2type;
private static size_t[izSerType] type2size;

static this()
{
    foreach(i, t; EnumMembers!izSerType)
    {
        type2text[t] = izSerTypeTuple[i].stringof;
        text2type[izSerTypeTuple[i].stringof] = t;
        type2size[t] = izSerTypeTuple[i].sizeof;
    }       
}

private static bool isSerObjectType(T)()
{
    static if (is(T : izSerializable)) return true;
    else static if (is(T == Object)) return true;
    else return false;
}

private static bool isSerObjectType(izSerType type)
{
    return (type == izSerType._izSerializable) | (type == izSerType._Object);
}

private static bool isSerSimpleType(T)()
{
    static if (isArray!T) return false;
    else static if (isSerObjectType!T) return false;
    else static if (staticIndexOf!(T, izSerTypeTuple) == -1) return false;
    else return true;
}

private static bool isSerStructType(T)()
{
    static if (!is(T==struct)) return false; 
    else
    { 
        foreach(TT; izSerTypeTuple)
            static if (isAssignable!(T,TT))
                return true;
        return false;
    }   
    assert(0, T.stringof ~ " is not tested by " ~ __FUNCTION__);
}

private bool isSerArrayType(T)()
{
    static if (!isArray!T) return false;
    else static if (is(T : izSerializable)) return false;
    else static if (isSerObjectType!(typeof(T.init[0]))) return false;    
    else static if (staticIndexOf!(typeof(T.init[0]), izSerTypeTuple) == -1) return false;
    else return true;
}

private bool isSerArrayStructType(T)()
{
    static if (!is(T==struct)) return false;
    else
    { 
        foreach(TT; izSerTypeTuple)
            static if (isAssignable!(T,TT[]))
                return true;
        return false;
    } 
}

public bool isSerializable(T)()
{
    static if (isSerSimpleType!T) return true;
    else static if (isSerStructType!T) return true;   
    else static if (isSerArrayType!T) return true; 
    else static if (isSerArrayStructType!T) return true;  
    else static if (isSerObjectType!T) return true;
    else return false;
}

unittest
{
    struct S{}
    struct V{uint _value; alias _value this;}
    struct VS{V _value; alias _value this;}
    static assert( isSerializable!ubyte );
    static assert( isSerializable!double );
    static assert( isSerializable!(ushort[]) );
    static assert( isSerializable!Object );
    static assert( !(isSerializable!(Object[])) );
    static assert( !(isSerializable!S) );
    static assert( (isSerializable!V) );
    static assert( (isSerializable!VS) );
}

private static string getElemStringOf(T)() if (isArray!T)
{
    return typeof(T.init[0]).stringof;
}

unittest
{
    static assert( getElemStringOf!(int[]) == int.stringof );
    static assert( getElemStringOf!(int[1]) == int.stringof );
    static assert( getElemStringOf!(int[0]) != "azertyui" );
}
// -----------------------------------------------------------------------------

// Tree representation --------------------------------------------------------

/// Represents a serializable property without genericity.
public struct izSerNodeInfo
{
    izSerType type;
    izPtr   descriptor;
    ubyte[] value;
    string  name;
    uint    level;
    bool    isArray;
    bool    isDamaged;
    bool    isLastChild;
}

/** 
 * Event triggered when a serializer needs a particular property descriptor.
 * Params:
 * nodeInfo = the information the callee can use to determine the descriptor 
 * to return.
 * matchingDescriptor = the callee can set a pointer to the izPropertyDescriptor 
 * matching to the info.
 * stop = the callee can set this value to true in order to stop the restoration 
 * process. According to the serialization context, this value can be noop.
 */
alias WantDescriptorEvent = void delegate(izIstNode node, out void * matchingDescriptor, out bool stop);

// add double quotes escape 
char[] add_dqe(char[] input)
{
    char[] result;
    foreach(i; 0 .. input.length) {
        if (input[i] != '"') result ~= input[i];
        else result ~= "\\\"";                         
    }
    return result;
}

// remove double quotes escape
char[] del_dqe(char[] input)
{
    if (input.length < 2) return input;
    char[] result;
    size_t i;
    while(i <= input.length){
        if (input[i .. i+2] == "\\\"")
        {
            result ~= input[i+1];
            i += 2;
        }
        else result ~= input[i++];
    }
    result ~= input[i++];
    return result;
}    

/// Restores the raw value contained in a izSerNodeInfo using the associated setter.
void nodeInfo2Declarator(const izSerNodeInfo * nodeInfo)
{
    void toDecl1(T)()  {
        auto descr = cast(izPropDescriptor!T *) nodeInfo.descriptor;
        descr.setter()( *cast(T*) nodeInfo.value.ptr );
    }
    void toDecl2(T)() {
        auto descr = cast(izPropDescriptor!(T[]) *) nodeInfo.descriptor;
        descr.setter()(cast(T[]) nodeInfo.value[]);
    } 
    void toDecl(T)() {
        (!nodeInfo.isArray) ? toDecl1!T : toDecl2!T;
    }
    //
    final switch(nodeInfo.type)
    {
        case izSerType._invalid,izSerType._izSerializable,izSerType._Object: break;
        case izSerType._byte: toDecl!byte; break;
        case izSerType._ubyte: toDecl!ubyte; break;
        case izSerType._short: toDecl!short; break;
        case izSerType._ushort: toDecl!ushort; break;
        case izSerType._int: toDecl!int; break;
        case izSerType._uint: toDecl!uint; break;
        case izSerType._long: toDecl!long; break;
        case izSerType._ulong: toDecl!ulong; break;    
        case izSerType._float: toDecl!float; break;
        case izSerType._double: toDecl!double; break;
        case izSerType._char: toDecl!char; break;   
        case izSerType._wchar: toDecl!wchar; break;   
        case izSerType._dchar: toDecl!dchar; break;                                                                                                                                   
    }
}

/// Converts the raw data contained in a izSerNodeInfo to its string representation.
char[] value2text(const izSerNodeInfo * nodeInfo)
{
    char[] v2t_1(T)(){return to!string(*cast(T*)nodeInfo.value.ptr).dup;}
    char[] v2t_2(T)(){return to!string(cast(T[])nodeInfo.value[]).dup;}
    char[] v2t(T)(){if (!nodeInfo.isArray) return v2t_1!T; else return v2t_2!T;}
    //
    final switch(nodeInfo.type)
    {
        case izSerType._invalid: return "invalid".dup;
        case izSerType._izSerializable, izSerType._Object: return cast(char[])(nodeInfo.value);
        case izSerType._ubyte: return v2t!ubyte;
        case izSerType._byte: return v2t!byte;
        case izSerType._ushort: return v2t!ushort;
        case izSerType._short: return v2t!short;
        case izSerType._uint: return v2t!uint;
        case izSerType._int: return v2t!int;
        case izSerType._ulong: return v2t!ulong;
        case izSerType._long: return v2t!long;
        case izSerType._float: return v2t!float;
        case izSerType._double: return v2t!double;
        case izSerType._char: return v2t!char;
        case izSerType._wchar: return v2t!wchar;
        case izSerType._dchar: return v2t!dchar;
    }
}

/// Converts the literal representation to a ubyte array according to type.
ubyte[] text2value(char[] text, const izSerNodeInfo * nodeInfo)
{
    ubyte[] t2v_1(T)(){
        auto res = new ubyte[](type2size[nodeInfo.type]);  
        *cast(T*) res.ptr = to!T(text);
        return res; 
    }
    ubyte[] t2v_2(T)(){
        auto v = to!(T[])(text);
        auto res = new ubyte[](v.length * type2size[nodeInfo.type]);
        memmove(res.ptr, v.ptr, res.length);
        return res;
    }
    ubyte[] t2v(T)(){
        if (!nodeInfo.isArray) return t2v_1!T; else return t2v_2!T;
    }
    //    
    final switch(nodeInfo.type)
    {
        case izSerType._invalid:
            return cast(ubyte[])"invalid".dup;
        case izSerType._izSerializable, izSerType._Object: 
            return cast(ubyte[])(text);
        case izSerType._ubyte: return t2v!ubyte;
        case izSerType._byte: return t2v!byte;
        case izSerType._ushort: return t2v!ushort;
        case izSerType._short: return t2v!short;
        case izSerType._uint: return t2v!uint;
        case izSerType._int: return t2v!int;
        case izSerType._ulong: return t2v!ulong;
        case izSerType._long: return t2v!long;
        case izSerType._float: return t2v!float;
        case izSerType._double: return t2v!double;
        case izSerType._char: return t2v!char;
        case izSerType._wchar: return t2v_2!wchar;
        case izSerType._dchar: return t2v!dchar;
    }
}

/// Fills an izSerNodeInfo according to an izPropDescriptor
void setNodeInfo(T)(izSerNodeInfo * nodeInfo, izPropDescriptor!T * descriptor)
{
    scope(failure) nodeInfo.isDamaged = true;
    
    // TODO: nodeInfo.value, try to use an union instead of an array 
    
    // simple, fixed-length (or convertible to), types
    static if (isSerSimpleType!T || isSerStructType!T)
    {
        static if (isSerStructType!T)
        {
            foreach(TT;izSerTypeTuple)
                static if (isAssignable!(T,TT))
                {
                    nodeInfo.type = text2type[TT.stringof];
                    break;
                }          
        }
        else nodeInfo.type = text2type[T.stringof];
        //
        nodeInfo.isArray = false;
        nodeInfo.value.length = type2size[nodeInfo.type];
        nodeInfo.descriptor = cast(izPtr) descriptor;
        nodeInfo.name = descriptor.name.dup;
        * cast(T*) nodeInfo.value.ptr = descriptor.getter()();
        //
        return;
    }
    
    // arrays types
    else static if (isSerArrayType!T || isSerArrayStructType!T)
    {
        static if (isSerArrayStructType!T)
        {
            foreach(TT;izSerTypeTuple)
                static if (isAssignable!(T,TT[]))
                {
                    nodeInfo.type = text2type[TT.stringof];
                    TT[] value = to!(TT[])(descriptor.getter()());
                    nodeInfo.value.length = value.length * type2size[nodeInfo.type];
                    memmove(nodeInfo.value.ptr, cast(void*) value.ptr, nodeInfo.value.length);
                    break;
                }          
        }
        else
        { 
            nodeInfo.type = text2type[getElemStringOf!T];
            T value = descriptor.getter()();
            nodeInfo.value.length = value.length * type2size[nodeInfo.type];
            memmove(nodeInfo.value.ptr, cast(void*) value.ptr, nodeInfo.value.length);
        }
        //
        nodeInfo.isArray = true;
        nodeInfo.descriptor = cast(izPtr) descriptor;
        nodeInfo.name = descriptor.name.dup;
        //
        return;
    }
   
    // izSerializable or Object
    else static if (isSerObjectType!T)
    {
        izSerializable ser;
        static if (is(T == Object))
            ser =  cast(izSerializable) descriptor.getter()();       
        else
            ser = descriptor.getter()();
            
        char[] value = ser.className.dup;
        //
        nodeInfo.type = text2type[typeof(ser).stringof];
        nodeInfo.isArray = false;
        nodeInfo.descriptor = cast(izPtr) descriptor;
        nodeInfo.name = descriptor.name.dup;
        nodeInfo.value.length = value.length;
        memmove(nodeInfo.value.ptr, cast(void*) value.ptr, nodeInfo.value.length);      
        //
        return;   
    }    
}

/// IST node
public class izIstNode : izTreeItem
{
    mixin izTreeItemAccessors;
    private izSerNodeInfo fNodeInfo;
    public
    {
        /**
         * Sets the infomations describing the property associated
         * to this IST node.
         */
        void setDescriptor(T)(izPropDescriptor!T * descriptor)
        {
            if(descriptor)
                setNodeInfo!T(&fNodeInfo, descriptor);
        }
        /** 
         * Returns a pointer to the information describing the property
         * associated to this IST node.
         */
        izSerNodeInfo * nodeInfo()
        {
            return &fNodeInfo;
        }   
        /**
         * Returns the identifier chain of the parents.
         */
        string parentIdentifiers()
        {
            if (!level) return "";
            //   
            import std.array;
            string[] items;
            items.length = level * 2;
            auto cnt = items.length - 1;
            izIstNode curr = cast(izIstNode) parent;
            while (curr)
            {
                items[cnt--] = ".";
                items[cnt--] = curr.nodeInfo.name;
                curr = cast(izIstNode) curr.parent;
            }
            return items.join[0..$-1];    
        }
    }
}

/// Propotype of a function which writes the representation of an izIstNode in an izStream.
alias izSerWriter = void function(izIstNode istNode, izStream stream);

/// Propotype of a function which reads the representation of an izIstNode from an izStream.
alias izSerReader = void function(izStream stream, izIstNode istNode);

// JSON format ----------------------------------------------------------------+
void writeJSON(izIstNode istNode, izStream stream)
{
    import std.json;
    //    
    auto level  = JSONValue(istNode.level);
    auto type   = JSONValue(istNode.nodeInfo.type);
    auto name   = JSONValue(istNode.nodeInfo.name.idup);
    auto isarray= JSONValue(cast(ubyte)istNode.nodeInfo.isArray);
    auto value  = JSONValue(value2text(istNode.nodeInfo).idup);
    auto prop   = JSONValue(["level":level,"type":type,"name":name,"isarray":isarray,"value":value]);
    auto txt    = toJSON(&prop, false).dup;
    auto len    = txt.length;
    //
    stream.write(txt.ptr, txt.length);   
}

void readJSON(izStream stream, izIstNode istNode)
{
    import std.json;
    //
    // cache property
    size_t cnt, len;
    char c;
    bool skip;
    auto stored = stream.position;
    while (true)
    {
        if (stream.position == stream.size)
            break;
        ++len;
        stream.read(&c, 1);
        if (c == '\\')
            continue;
        if (c == '"') 
            skip = !skip;
        if (!skip)
        {
            cnt += (c == '{');
            cnt -= (c == '}');
        }
        if (cnt == 0)
            break;   
    }
    stream.position = stored;
    char[] cache;
    cache.length = len;
    stream.read(cache.ptr, cache.length);
    //writeln("cache:");
    //writeln(cache);
    //
    auto prop = parseJSON(cache);
    
    JSONValue level = prop["level"];
    if (level.type == JSON_TYPE.INTEGER) 
        istNode.nodeInfo.level = cast(uint) level.integer;
    else 
        istNode.nodeInfo.isDamaged = true;
        
    JSONValue type = prop["type"];
    if (type.type == JSON_TYPE.INTEGER) 
        istNode.nodeInfo.type = cast(izSerType) type.integer;
    else 
        istNode.nodeInfo.isDamaged = true;       
        
    JSONValue name = prop["name"];
    if (name.type == JSON_TYPE.STRING) 
        istNode.nodeInfo.name = name.str.dup;
    else 
        istNode.nodeInfo.isDamaged = true;   
        
    JSONValue isarray = prop["isarray"];
    if (isarray.type == JSON_TYPE.INTEGER) 
        istNode.nodeInfo.isArray = cast(bool) isarray.integer;
    else 
        istNode.nodeInfo.isDamaged = true;                    
        
    JSONValue value = prop["value"];
    if (value.type == JSON_TYPE.STRING) 
        istNode.nodeInfo.value = text2value(value.str.dup, istNode.nodeInfo);
    else 
        istNode.nodeInfo.isDamaged = true;                   
    
}
// ----

// Text format ----------------------------------------------------------------+
void writeText(izIstNode istNode, izStream stream)
{
    char separator = ' ';
    // indentation
    char tabulation = '\t';
    foreach(i; 0 .. istNode.level)
        stream.write(&tabulation, tabulation.sizeof);
    // type
    char[] type = type2text[istNode.nodeInfo.type].dup;
    stream.write(type.ptr, type.length);
    // array
    char[2] arr = "[]";
    if (istNode.nodeInfo.isArray) stream.write(arr.ptr, arr.length); 
    stream.write(&separator, separator.sizeof);
    // name
    char[] name = istNode.nodeInfo.name.dup;
    stream.write(name.ptr, name.length);
    stream.write(&separator, separator.sizeof);
    // name value separators
    char[] name_value = " = \"".dup;
    stream.write(name_value.ptr, name_value.length);
    // value
    char[] value = value2text(istNode.nodeInfo); // add_dqe
    stream.write(value.ptr, value.length);
    char[] eol = "\"\n".dup;
    stream.write(eol.ptr, eol.length);
}  

void readText(izStream stream, izIstNode istNode)
{
    size_t i;
    char[] identifier;
    char reader;   
    // cache the property
    char[] propText;
    char[2] eop;
    auto initPos = stream.position;
    while((eop != "\"\n") & (stream.position != stream.size)) 
    {
        stream.read(eop.ptr, 2);
        stream.position = stream.position -1;
    }
    auto endPos = stream.position;
    propText.length = cast(ptrdiff_t)(endPos - initPos);
    stream.position = initPos;
    stream.read(propText.ptr, propText.length);
    stream.position = endPos + 1;
        
    // level
    i = 0;
    while (propText[i] == '\t') i++;
    istNode.nodeInfo.level = cast(uint) i;
    
    // type
    identifier = identifier.init;
    while(propText[i] != ' ') 
        identifier ~= propText[i++];
    char[2] arr;
    if (identifier.length > 2) 
    {
        arr = identifier[$-2 .. $];
        istNode.nodeInfo.isArray = (arr == "[]");
    }
    if (istNode.nodeInfo.isArray) 
        identifier = identifier[0 .. $-2];
    if (identifier in text2type) 
        istNode.nodeInfo.type = text2type[identifier];
         
    // name
    i++;
    identifier = identifier.init;
    while(propText[i] != ' ') 
        identifier ~= propText[i++];
    istNode.nodeInfo.name = identifier.idup; 
    
    // name value separators
    i++;
    while(propText[i] != ' ') i++; 
    i++;
    //std.stdio.writeln(propText[i]); 
    i++; 
    while(propText[i] != ' ') i++;
    
    // value     
    i++;
    identifier = propText[i..$];
    identifier = identifier[1..$-1];
    istNode.nodeInfo.value = text2value(identifier, istNode.nodeInfo);
}  
//----

// Binary format --------------------------------------------------------------+
version(BigEndian) private ubyte[] swapBE(const ref ubyte[] input, size_t div)
{
    if (div == 1) return input.dup;    
    auto result = new ubyte[](input.length);
    switch(div) {
        default: break;
        case 2: foreach(immutable i; 0 .. input.length / div) {
            result[i*2+0] = input[i*2+1];
            result[i*2+1] = input[i*2+0];
        } break;
        case 4: foreach(immutable i; 0 .. input.length / div) {
            result[i*4+0] = input[i*4+3];
            result[i*4+1] = input[i*4+2];
            result[i*4+2] = input[i*4+1];
            result[i*4+3] = input[i*4+0];
        } break;           
        case 8: foreach(immutable i; 0 .. input.length / div) {
            result[i*8+0] = input[i*8+7];
            result[i*8+1] = input[i*8+6];
            result[i*8+2] = input[i*8+5];
            result[i*8+3] = input[i*8+4];
            result[i*8+4] = input[i*8+3];
            result[i*8+5] = input[i*8+2];
            result[i*8+6] = input[i*8+1];
            result[i*8+7] = input[i*8+0];
        } break;                           
    }
    return result;   
}

void writeBin(izIstNode istNode, izStream stream)
{
    ubyte bin;
    ubyte[] data;
    uint datalength;
    //header
    bin = 0x99;
    stream.write(&bin, bin.sizeof);
    // level
    datalength = cast(uint) istNode.level;
    stream.write(&datalength, datalength.sizeof);
    // type
    bin = cast(ubyte) istNode.nodeInfo.type; 
    stream.write(&bin, bin.sizeof);
    // as array
    bin = istNode.nodeInfo.isArray; 
    stream.write(&bin, bin.sizeof);  
    // name length then name
    data = cast(ubyte[]) istNode.nodeInfo.name;
    datalength = cast(uint) data.length;
    stream.write(&datalength, datalength.sizeof);
    stream.write(data.ptr, datalength);
    // value length then value
    version(LittleEndian)
    {
        datalength = cast(uint) istNode.nodeInfo.value.length;
        stream.write(&datalength, datalength.sizeof);
        stream.write(istNode.nodeInfo.value.ptr, datalength);        
    }
    else
    {
        data = swapBE(istNode.nodeInfo.value, type2size[istNode.nodeInfo.type]);
        datalength = cast(uint) data.length;
        stream.write(&datalength, datalength.sizeof);
        stream.write(data.ptr, datalength); 
    }
    //footer
    bin = 0xA0;
    stream.write(&bin, bin.sizeof); 
}  

void readBin(izStream stream, izIstNode istNode)
{
    ubyte bin;
    ubyte[] prop;
    ubyte[] data;
    uint datalength;
    uint beg, end;
    // cache property
    do stream.read(&bin, bin.sizeof);
        while (bin != 0x99 && stream.position != stream.size);
    beg = cast(uint) stream.position;
    do stream.read(&bin, bin.sizeof);
        while (bin != 0xA0 && stream.position != stream.size);
    end = cast(uint) stream.position;
    if (end <= beg) return;
    stream.position = beg;
    data.length = end - beg;
    stream.read(data.ptr, data.length);
    // level
    datalength = *cast(uint*) data.ptr;
    istNode.nodeInfo.level = datalength;                
    // type and array
    istNode.nodeInfo.type = cast(izSerType) data[4];
    istNode.nodeInfo.isArray = cast(bool) data[5];      
    // name length then name;
    datalength = *cast(uint*) (data.ptr + 6);
    istNode.nodeInfo.name = cast(string) data[10.. 10 + datalength].idup; 
    beg =  10 +  datalength;      
    // value length then value
    version(LittleEndian)
    {
        datalength = *cast(uint*) (data.ptr + beg);
        istNode.nodeInfo.value = data[beg + 4 .. beg + 4 + datalength];    
    }
    else
    {
        datalength = *cast(uint*) (data.ptr + beg);
        data = data[beg + 4 .. beg + 4 + datalength];
        istNode.nodeInfo.value = swapBE(data, type2size[istNode.nodeInfo.type]);
    } 
}  
//----

// High end serializer --------------------------------------------------------+

/// Enumerates the possible state of an izSerializer.
public enum izSerState : ubyte
{
    /// the serializer is idle
    none,
    /// the serializer is storing (from declarator to serializer)
    store,  
    /// the serializer is restoring (from serializer to declarator)
    restore     
}

/// Enumerates the possible storing mode.
public enum izStoreMode : ubyte
{
    /// stores directly after declaration. order is granted. a single property descriptor can be used for several properties.
    sequential,
    /// stores when eveything is declared. a single property descriptor cannot be used for several properties.  
    bulk        
}

/// Enumerates the possible restoring mode.
public enum izRestoreMode : ubyte
{
    /// restore following declaration. order is granted.
    sequential, 
    /// restore without declaration, or according to a custom query.
    random      
}

/// Enumerates the possible serialization format
public enum izSerFormat : ubyte
{
    /// native binary format
    izbin,
    /// native readable text format 
    iztxt,
    /// JSON chunks
    json
}

private izSerWriter writeFormat(izSerFormat format)
{
    with(izSerFormat) final switch(format) {
        case izbin: return &writeBin;
        case iztxt: return &writeText;   
        case json:  return &writeJSON;
    }
}

private izSerReader readFormat(izSerFormat format)
{
    with(izSerFormat) final switch(format) {
        case izbin: return &readBin;
        case iztxt: return &readText;
        case json:  return &readJSON;   
    }
}


//TODO-cfeature: izSerializer error handling.

/**
 * Native iz Serializer.
 * An izSerializer is specialized to store and restore from any class heriting
 * from the interface izSerializable. An izSerializable arbitrarily exposes some
 * properties to serialize using the izPropDescriptor format.
 *
 * The serializer uses an intermediate serialization tree (IST) which grants a 
 * certain flexibilty. 
 * As expected for a serializer, some objects trees can be stored or restored by 
 * a simple and single call ( *objectToStream()* and *streamToObject()* ) but the 
 * IST also allows to convert a data stream, to randomly find and restores 
 * some properties and to handle compatibility errors.
 * Even the IST can be build manually, without using the automatic mechanism.
 */
public class izSerializer
{
    private
    {
        // the IST root
        izIstNode fRootNode;
        // the current node, representing an izSerializable or not
        izIstNode fCurrNode;
        // the current parent node, always representing an izSerializable
        izIstNode fParentNode;
        // the last created node 
        izIstNode fPreviousNode;
        
        // the izSerializable linked to fRootNode
        izSerializable fRootSerializable;
        // the izSerializable linked to fParentNode
        izSerializable fCurrSerializable;
        
        WantDescriptorEvent fOnWantDescriptor;
        
        izSerState fSerState;
        izStoreMode fStoreMode;
        izRestoreMode fRestoreMode;
        izSerFormat fFormat;
        
        izStream fStream;
        izPropDescriptor!izSerializable fRootDescr;
        
        bool fMustWrite;
        bool fMustRead;
        
        // prepares the first IST node
        void setRoot(izSerializable root)
        {
            fRootSerializable = root;
            fCurrNode = fRootNode;
            fRootDescr.define(&fRootSerializable, "Root");
            fRootNode.setDescriptor(&fRootDescr);
        }
        
        bool restoreFromEvent(izIstNode node, out bool stop)
        {
            if (!fOnWantDescriptor) 
                return false;
            void * descr;
            bool done;
            fOnWantDescriptor(node, descr, stop);
            done = (descr != null);
            if (done) 
            {
                node.nodeInfo.descriptor = descr;
                    nodeInfo2Declarator(node.nodeInfo);
                return true;
            }
            else if (isSerObjectType(node.nodeInfo.type))
                return true;
            return false;
        }
    }
    
    public 
    {  
        this()
        {
            fRootNode = construct!izIstNode;
        }
        ~this()
        {
            fRootNode.deleteChildren;
            destruct(fRootNode);
        }         
              
//---- serialization ----------------------------------------------------------+
        
        /** 
         * Builds the IST from an izSerializable.
         * The process starts by a call to .declareProperties() in the root then
         * the process is lead by the the subsequent declarations.
         * Params:
         * root = the izSerializable from where the declarations start.
         */
        void objectToIst(izSerializable root)
        {
            fStoreMode = izStoreMode.bulk;
            fSerState = izSerState.store;
            fMustWrite = false;
            //
            fRootNode.deleteChildren;
            fPreviousNode = null;
            setRoot(root);
            fCurrSerializable = fRootSerializable;
            fCurrNode = fRootNode;
            //
            fParentNode = fRootNode;
            fCurrSerializable.declareProperties(this);
            fSerState = izSerState.none;
        }
        
        /** 
         * Builds the IST from an izSerializable and stores sequentially in a stream.
         * The process starts by a call to .declaraPropties() in the root then
         * the process is lead by the the subsequent declarations.
         * The data are written right after a descriptor declaration.
         * Params:
         * root = the izSerializable from where the declarations starts.
         * outputStream = the stream where te data are written.
         * format = the format of the serialized data.
         */
        void objectToStream(izSerializable root, izStream outputStream, izSerFormat format)
        {
            fFormat = format;
            fStream = outputStream;
            fStoreMode = izStoreMode.sequential;
            fSerState = izSerState.store;
            fMustWrite = true;
            //
            fRootNode.deleteChildren;
            fPreviousNode = null;
            setRoot(root);
            fCurrSerializable = fRootSerializable;
            fCurrNode = fRootNode;
            writeFormat(fFormat)(fCurrNode, fStream);
            //
            fParentNode = fRootNode;
            fCurrSerializable.declareProperties(this);
            //
            fMustWrite = false;
            fSerState = izSerState.none;
            fStream = null;
        }
        
        /** 
         * Saves the IST to a stream. 
         * The data are grabbed in bulk therefore the descriptor linked to each
         * tree node cannot be re-used.
         * Params:
         * outputStream = the stream where te data are written.
         * format = the format of the serialized data.
         */
        void istToStream(izStream outputStream, izSerFormat format)
        {
            fFormat = format;
            fStream = outputStream;
            fStoreMode = izStoreMode.bulk;
            fMustWrite = true;
            //
            void writeNodesFrom(izIstNode parent)
            {
                writeFormat(fFormat)(parent, fStream); 
                foreach(node; parent.children)
                {
                    auto child = cast(izIstNode) node;           
                    if (isSerObjectType(child.nodeInfo.type))
                        writeNodesFrom(child);
                    else writeFormat(fFormat)(child, fStream); 
                }
            }
            writeNodesFrom(fRootNode);
            //
            fMustWrite = false;
            fStream = null;
        }
 
//------------------------------------------------------------------------------
//---- deserialization --------------------------------------------------------+
            
        /**
         * Builds the IST from a stream.
         * After the call the properties can only be restored manually 
         * by using findNode() and restoreProperty(). 
         * This function is also usefull to convert from a format to another.
         * Params:
         * inputStream = a stream containing the serialized data.
         * format = the format of the serialized data.
         */
        void streamToIst(izStream inputStream, izSerFormat format)
        {
            izIstNode[] unorderNodes;
            izIstNode oldParent;
            izIstNode[] parents;
            fRootNode.deleteChildren;
            fCurrNode = fRootNode;
            fMustRead = false;
            fStream = inputStream;
            
            while(inputStream.position < inputStream.size)
            {
                unorderNodes ~= fCurrNode;      
                readFormat(fFormat)(fStream, fCurrNode);
                fCurrNode = construct!izIstNode;
            }
            destruct(fCurrNode);
            
            if (unorderNodes.length > 1)
            foreach(i; 1 .. unorderNodes.length)
            {
                unorderNodes[i-1].nodeInfo.isLastChild = 
                  unorderNodes[i].nodeInfo.level < unorderNodes[i-1].nodeInfo.level;       
            }
            
            parents ~= fRootNode;
            foreach(i; 1 .. unorderNodes.length)
            {
                auto node = unorderNodes[i];
                parents[$-1].addChild(node);
                
                if (node.nodeInfo.isLastChild)
                    parents.length -= 1;
                 
                if (isSerObjectType(node.nodeInfo.type))
                    parents ~= node;
            }  
            //
            fStream = null;  
        }
        
        /** 
         * Builds the IST from a stream and restores sequentially to a root.
         * The process starts by a call to .declaraPropties() in the root.
         * Params:
         * inputStream = the stream containing the serialized data.
         * root = the izSerializable from where the declarations and the restoration starts.
         * format = the format of the serialized data.
         */
        void streamToObject(izStream inputStream, izSerializable root, izSerFormat format)
        {
            fSerState = izSerState.restore;
            fRestoreMode = izRestoreMode.sequential;
            fMustRead = true;
            fStream = inputStream;
            //
            fRootNode.deleteChildren;
            fPreviousNode = null;
            setRoot(root);
            fCurrSerializable = fRootSerializable;
            fCurrNode = fRootNode;
            readFormat(fFormat)(fStream, fCurrNode);
            //
            fParentNode = fRootNode;
            fCurrSerializable = fRootSerializable;
            fCurrSerializable.declareProperties(this);   
            //   
            fMustRead = false;
            fSerState = izSerState.none;
            fStream = null;  
        }   
        
        /**
         * Fully Restores the IST. Can be called after *streamToIst()*.
         * For each ISTnode and if assigned, the onWantDesscriptor event is called.
         */
        void istToObject() {istToObject(fRootNode, true);}    
        
        /**
         * Finds the tree node matching to a property names chain.
         * Params:
         * descriptorName = the property names chain which identifies the interesting node.
         * Returns:
         * A reference to the node which matches to the property if the call succeeds otherwise nulll.
         */ 
        izIstNode findNode(in char[] descriptorName)
        {
        
            //TODO-cfeature : optimize random access by caching in an AA, "à la JSON"
            
            if (fRootNode.nodeInfo.name == descriptorName)
                return fRootNode;
            
            izIstNode scanNode(izIstNode parent, in char[] namePipe)
            {
                izIstNode result;
                foreach(node; parent.children)
                {
                    auto child = cast(izIstNode) node;//parent.children[i]; 
                    if ( namePipe ~ "." ~ child.nodeInfo.name == descriptorName)
                        return child;
                    if (child.childrenCount)
                        result = scanNode(child, namePipe ~ "." ~ child.nodeInfo.name);
                    if (result)
                        return result;
                }
                return result;
            }
            return scanNode(fRootNode, fRootNode.nodeInfo.name);
        }
        
        /**
         * Restores the IST from an arbitrary tree node. 
         * The process is lead by the nodeInfo associated to the node.
         * If the descriptor is not defined then wantDescriptorEvent is called.
         * It means that this method can be used to deserialize to an arbitrary descriptor,
         * for example after a call to streamToIst().
         * Params:
         * node = the IST node from where the restoration begins. It can be determined by a call to findNode().
         * recursive = when set to true the restoration is recursive.
         */  
        void istToObject(izIstNode node, bool recursive = false)
        {
            bool restore(izIstNode current)
            {
                bool result = true;
                if (current.nodeInfo.descriptor)
                    nodeInfo2Declarator(current.nodeInfo);
                else
                {
                    bool stop;
                    result = restoreFromEvent(current, stop);
                    result &= !stop;
                }
                return result;    
            }
            
            bool restoreLoop(izIstNode current)
            {
                if (!restore(current)) return false;
                foreach(child; current.children)
                {
                    auto childNode = cast(izIstNode) child;
                    if (!restore(childNode)) return false;
                    if (isSerObjectType(childNode.nodeInfo.type) & recursive)
                        if (!restoreLoop(childNode)) return false;
                }
                return true;
            }
            
            restoreLoop(node);
        }
        
        /**
         * Restores a single property from a tree node using the setter of a descriptor.
         * Params:
         * node = an izIstNode. Can be determined by a call to findNode()
         * aDescriptor = the izPropDescriptor whose setter is used to restore the node data.
         * If not specified then the onWantDescriptor event may be called.
         */
        void restoreProperty(T)(izIstNode node, izPropDescriptor!T * aDescriptor = null)
        {
            fSerState = izSerState.restore;
            fRestoreMode = izRestoreMode.random;
            if (aDescriptor)
            {
                node.nodeInfo.descriptor = aDescriptor;
                nodeInfo2Declarator(node.nodeInfo);
            }
            else 
            {
                bool noop;
                restoreFromEvent(node, noop);
            }   
        }        

//------------------------------------------------------------------------------
//---- declaration from an izSerializable -------------------------------------+
    
        /*( the following methods are designed to be only used by an izSerializable !)*/
    
        mixin(genAllAdders);
        
        /**
         * Designed to be called by an izSerializable when it needs to declare 
         * a property in its declarePropeties() method.
         *
         * Allowed properties:
         * - all the basic types: int, uint, char, ...
         * - all the basic types as array: int[], uin[], char[], ...
         * - the structs assignable from/to a basic type (if they include a public alias this but not only)
         * - the structs assignable from/to an array of basic type (this(char[]), opAssign(char[]), toString())
         * - the izSerializable (used to build the structure).
         * - any class, if it implements izSerializable. It's safer to pass some izPropDescriptor!izSerializable but izPropDescriptor!Object is easyer.
         *
         * Some aliases exist for each basic type (addintProperty(), addcharProperty(), ...).
         * the structs are represented as the type they convert to and are not used to build the IST.
         */
        void addProperty(T)(izPropDescriptor!T * aDescriptor)
        if (isSerializable!T)
        {    
            if (!aDescriptor) return;
            if (!aDescriptor.name.length) return;
            
            fCurrNode = fParentNode.addNewChildren!izIstNode;
            fCurrNode.setDescriptor(aDescriptor);
            
            if (fMustWrite && fStoreMode == izStoreMode.sequential)
                writeFormat(fFormat)(fCurrNode, fStream); 
                
            if (fMustRead) {
                readFormat(fFormat)(fStream, fCurrNode);
                if (fCurrNode.nodeInfo.descriptor)
                    nodeInfo2Declarator(fCurrNode.nodeInfo);
                else 
                {
                    bool noop;
                    restoreFromEvent(fCurrNode, noop);
                }
            }
            
            static if (isSerObjectType!T)
            {
                if (fPreviousNode)
                    fPreviousNode.nodeInfo.isLastChild = true;
            
                auto oldSerializable = fCurrSerializable;
                auto oldParentNode = fParentNode;
                fParentNode = fCurrNode;
                static if (is(T : izSerializable))
                    fCurrSerializable = aDescriptor.getter()();
                else
                   fCurrSerializable = cast(izSerializable) aDescriptor.getter()(); 
                fCurrSerializable.declareProperties(this);
                fParentNode = oldParentNode;
                fCurrSerializable = oldSerializable;
            }    
            
            fPreviousNode = fCurrNode;      
        }
        
        /// state is set visible to an izSerializable to let it know how the properties will be used (store: getter, restore: setter)
        @property izSerState state() {return fSerState;}
        
        /// storeMode is set visible to an izSerializable to let it adjust the way to declare the properties. 
        @property izStoreMode storeMode() {return fStoreMode;}
        
        /// restoreMode is set visible to an izSerializable to let it adjust the way to declare the properties. 
        @property izRestoreMode restoreMode() {return fRestoreMode;}
         
        /// serializationFormat is set visible to an izSerializable to let it adjust the way to declare the properties. 
        @property izSerFormat serializationFormat() {return fFormat;} 
        
        /// The IST can be modified, build, cleaned from the root node
        @property izIstNode serializationTree(){return fRootNode;}
        
        /// Event triggered when the serializer needs a particulat property descriptor.
        @property WantDescriptorEvent onWantDescriptor(){return fOnWantDescriptor;}
        
        /// ditto
        @property void onWantDescriptor(WantDescriptorEvent aValue){fOnWantDescriptor = aValue;}
//------------------------------------------------------------------------------
    } 
}

//----

private static string genAllAdders()
{
    string result;
    foreach(t; izSerTypeTuple) if (!(is(t == struct)))
        result ~= "alias add" ~ t.stringof ~ "Property =" ~ "addProperty!" ~ t.stringof ~";"; 
    return result;
}

version(unittest)
{
    unittest
    {
        char[] text;
        ubyte[] value;
        izSerNodeInfo inf;
        //
        value = [13];
        text = "13".dup;
        inf.type = izSerType._byte ;
        inf.value = value ;
        inf.isArray = false;
        assert(value2text(&inf) == text);
        assert(text2value(text, &inf) == value);
        //
        value = [13,14];
        text = "[13, 14]".dup;
        inf.type = izSerType._byte ;
        inf.value = value ;
        inf.isArray = true;
        assert(value2text(&inf) == text);
        assert(text2value(text, &inf) == value); 
        //  
        void testType(T)(T t)
        {
            char[] asText;
            T value = t;
            izSerNodeInfo inf;
            izPropDescriptor!T descr;
            //
            descr.define(&value, "property");
            setNodeInfo!T(&inf, &descr);
            //
            asText = to!string(value).dup;
            assert(value2text(&inf) == asText, T.stringof);
            static if (!isArray!T) 
                assert( * cast(T*)(text2value(asText, &inf)).ptr == value, T.stringof);
            static if (isArray!T) 
                assert( cast(ubyte[])text2value(asText, &inf) == cast(ubyte[])value, T.stringof);
        }
        
        struct ImpConv{uint _field; alias _field this;}
        auto ic = ImpConv(8);
        
        testType('c');
        testType("azertyuiop".dup);
        testType!uint(ic); 
        testType(cast(byte)8);      testType(cast(byte[])[8,8]);
        testType(cast(ubyte)8);     testType(cast(ubyte[])[8,8]);
        testType(cast(short)8);     testType(cast(short[])[8,8]); 
        testType(cast(ushort)8);    testType(cast(ushort[])[8,8]);
        testType(cast(int)8);       testType(cast(int[])[8,8]);     
        testType(cast(uint)8);      testType(cast(uint[])[8,8]);    
        testType(cast(long)8);      testType(cast(long[])[8,8]);    
        testType(cast(ulong)8);     testType(cast(ulong[])[8,8]);
        testType(cast(float).8f);   testType(cast(float[])[.8f,.8f]); 
        testType(cast(double).8);   testType(cast(double[])[.8,.8]);
        
        writeln("izSerializer passed the text-value conversions test");     
    }

    unittest 
    {
        foreach(fmt;EnumMembers!izSerFormat)
            testByFormat!fmt();
        //testByFormat!(izSerFormat.iztxt)();
        //testByFormat!(izSerFormat.izbin)();
        //testByFormat!(izSerFormat.json)();
    }
    
    class Referenced1 {}
    
    class ReferencedUser : izSerializable
    {
        izPropDescriptor!Object fRefDescr;
        izSerializableReference fSerRef;
        Referenced1 * fRef;
    
        this() {
            fSerRef = construct!izSerializableReference;
            fRefDescr.define(cast(Object*)&fSerRef, "theReference");
        }
        
        ~this() {destruct(fSerRef);}
        
        void declareProperties(izSerializer aSerializer)
        {
            if (aSerializer.state == izSerState.store)
                fSerRef.storeReference!Referenced1(fRef);
                
            aSerializer.addProperty(&fRefDescr);
            
            if (aSerializer.state == izSerState.restore)
                fRef = fSerRef.restoreReference!Referenced1;
        }
    }
    
    class ClassA: ClassB
    {
        private:
            ClassB _aB1, _aB2;
            izPropDescriptor!Object aB1descr, aB2descr;
        public:
            this() {
                _aB1 = construct!ClassB;
                _aB2 = construct!ClassB;
                aB1descr.define(cast(Object*)&_aB1, "aB1");
                aB2descr.define(cast(Object*)&_aB2, "aB2");
            }
            ~this() {
                destruct(_aB1, _aB2);
            }
            override void reset() {
                super.reset;
                _aB1.reset;
                _aB2.reset;
            }
            override void declareProperties(izSerializer aSerializer) {
                super.declareProperties(aSerializer);
                aSerializer.addProperty(&aB1descr);
                aSerializer.addProperty(&aB2descr);
            }
    }
    
    class ClassB : izSerializable
    {
        mixin izPropertiesAnalyzer;
        private:
            int[]  _anIntArray;
            float  _aFloat;
            char[] _someChars;
        public:
            this() {
                analyzeAll;
                _anIntArray = [0, 1, 2, 3];
                _aFloat = 0.123456f;
                _someChars = "azertyuiop".dup;
            }
            void reset() {
                iz.types.reset(_anIntArray);
                _aFloat = 0.0f;
                iz.types.reset(_someChars);
            }
            
            mixin(genPropFromField!(typeof(_anIntArray), "anIntArray", "_anIntArray"));
            mixin(genPropFromField!(typeof(_aFloat), "aFloat", "_aFloat"));
            mixin(genPropFromField!(typeof(_someChars), "someChars", "_someChars")); 
            
            void declareProperties(izSerializer aSerializer) {
                aSerializer.addProperty(getDescriptor!(typeof(_anIntArray))("anIntArray"));
                aSerializer.addProperty(getDescriptor!(typeof(_aFloat))("aFloat"));
                aSerializer.addProperty(getDescriptor!(typeof(_someChars))("someChars"));
            }
    }
    
    void testByFormat(izSerFormat format)()
    {
        izMemoryStream str  = construct!izMemoryStream;
        izSerializer ser    = construct!izSerializer;
        ClassB b = construct!ClassB;
        ClassA a = construct!ClassA;
        scope(exit) destruct(str, ser, b, a);
        
        // basic sequential store/restore ---+
        ser.objectToStream(b,str,format);
        b.reset;
        assert(b.anIntArray == []);
        assert(b.aFloat == 0.0f);
        assert(b.someChars == "");
        str.position = 0;
        ser.streamToObject(str,b,format);
        assert(b.anIntArray == [0, 1, 2, 3]);
        assert(b.aFloat == 0.123456f);
        assert(b.someChars == "azertyuiop");
        //----
        
        // arbitrarily find a prop ---+
        assert(ser.findNode("Root.anIntArray"));
        assert(ser.findNode("Root.aFloat"));
        assert(ser.findNode("Root.someChars"));
        assert(!ser.findNode("Root."));
        assert(!ser.findNode("aFloat"));
        assert(!ser.findNode("Root.someChar"));
        assert(!ser.findNode(""));
        //----
        
        // restore elsewhere than in the declarator ---+
        float outside;
        auto node = ser.findNode("Root.aFloat");
        auto aFloatDescr = izPropDescriptor!float(&outside, "namedoesnotmatter");
        ser.restoreProperty(node, &aFloatDescr);
        assert(outside == 0.123456f);
        //----
        
        // nested declarations with super.declarations ---+
        str.clear;
        ser.objectToStream(a,str,format);
        a.reset;
        assert(a.anIntArray == []);
        assert(a.aFloat == 0.0f);
        assert(a.someChars == "");
        assert(a._aB1.anIntArray == []);
        assert(a._aB1.aFloat == 0.0f);
        assert(a._aB1.someChars == "");
        assert(a._aB2.anIntArray == []);
        assert(a._aB2.aFloat == 0.0f);
        assert(a._aB2.someChars == "");
        str.position = 0;
        ser.streamToObject(str,a,format);
        assert(a.anIntArray == [0, 1, 2, 3]);
        assert(a.aFloat ==  0.123456f);
        assert(a.someChars == "azertyuiop");
        assert(a._aB1.anIntArray == [0, 1, 2, 3]);
        assert(a._aB1.aFloat ==  0.123456f);
        assert(a._aB1.someChars == "azertyuiop");
        assert(a._aB2.anIntArray == [0, 1, 2, 3]);
        assert(a._aB2.aFloat ==  0.123456f);
        assert(a._aB2.someChars == "azertyuiop"); 
        //----
        
        // store & restore a serializable reference ---+
        auto ref1 = construct!Referenced1;
        auto ref2 = construct!Referenced1;
        auto usrr = construct!ReferencedUser;
        scope(exit) destruct(ref1, ref2, usrr);
        
        assert( izReferenceMan.storeReference!Referenced1(&ref1, 0x11223344));
        assert( izReferenceMan.storeReference!Referenced1(&ref2, 0x55667788));
        assert( izReferenceMan.referenceID!Referenced1(&ref1) == 0x11223344);
        assert( izReferenceMan.referenceID!Referenced1(&ref2) == 0x55667788);
        
        str.clear;
        usrr.fRef = &ref1;
        ser.objectToStream(usrr, str, format);
        usrr.fRef = &ref2;
        assert(*usrr.fRef is ref2);
        str.position = 0;
        ser.streamToObject(str, usrr, format);
        assert(*usrr.fRef is ref1);
        
        usrr.fRef = null;
        assert(usrr.fRef is null);
        str.position = 0;
        ser.streamToObject(str, usrr, format);
        assert(*usrr.fRef is ref1);
        
        str.clear;
        usrr.fRef = null;
        ser.objectToStream(usrr, str, format);
        usrr.fRef = &ref2;
        assert(*usrr.fRef is ref2);
        str.position = 0;
        ser.streamToObject(str, usrr, format);
        assert(usrr.fRef is null);         
        //----
          
        // auto store, stream to ist, restores manually ---+
        str.clear;  
        ser.objectToStream(b,str,format);
        b.reset;
        assert(b.anIntArray == []);
        assert(b.aFloat == 0.0f);
        assert(b.someChars == "");
        str.position = 0;
        ser.streamToIst(str,format);
        
        auto node_anIntArray = ser.findNode("Root.anIntArray");
        if(node_anIntArray) ser.restoreProperty(node_anIntArray, b.getDescriptor!(int[])("anIntArray"));
        else assert(0);        
        auto node_aFloat = ser.findNode("Root.aFloat");
        if(node_aFloat) ser.restoreProperty(node_aFloat, b.getDescriptor!float("aFloat"));
        else assert(0);  
        auto node_someChars = ser.findNode("Root.someChars");
        if(node_someChars) ser.restoreProperty(node_someChars, b.getDescriptor!(char[])("someChars"));
        else assert(0);                  
        assert(b.anIntArray == [0, 1, 2, 3]);
        assert(b.aFloat == 0.123456f);
        assert(b.someChars == "azertyuiop");      
        //----
            
        // decomposed de/serialization phases with event ---+ 
        void wantDescr(izIstNode node, out void * matchingDescriptor, out bool stop)
        {
            string chain = node.parentIdentifiers;
            if (chain == "Root")
                matchingDescriptor = a.getUntypedDescriptor(node.nodeInfo.name);
            else if (chain == "Root.aB1")
                matchingDescriptor = a._aB1.getUntypedDescriptor(node.nodeInfo.name);
            else if (chain == "Root.aB2")
                matchingDescriptor = a._aB2.getUntypedDescriptor(node.nodeInfo.name);                      
        }
          
        str.clear;
        ser.objectToIst(a);
        ser.istToStream(str,format);
        a.reset;    
        assert(a.anIntArray == []);
        assert(a.aFloat == 0.0f);
        assert(a.someChars == "");
        assert(a._aB1.anIntArray == []);
        assert(a._aB1.aFloat == 0.0f);
        assert(a._aB1.someChars == "");
        assert(a._aB2.anIntArray == []);
        assert(a._aB2.aFloat == 0.0f);
        assert(a._aB2.someChars == "");
        str.position = 0;
        ser.onWantDescriptor = &wantDescr;
        ser.streamToIst(str,format);
        ser.istToObject;
        assert(a.anIntArray == [0, 1, 2, 3]);
        assert(a.aFloat ==  0.123456f);
        assert(a.someChars == "azertyuiop");
        assert(a._aB1.anIntArray == [0, 1, 2, 3]);
        assert(a._aB1.aFloat ==  0.123456f);
        assert(a._aB1.someChars == "azertyuiop");
        assert(a._aB2.anIntArray == [0, 1, 2, 3]);
        assert(a._aB2.aFloat ==  0.123456f);
        assert(a._aB2.someChars == "azertyuiop");
        ser.onWantDescriptor = null;
        // ----
        
        // struct serialized as basicType or basicType[] ---+
        
        /*
         to be serializable as an array, a struct must
         - implement a copy constructor with T[] as param.
         - implement opAssign with T[] as param.
         - must be convertible by std.conv.to() to a T[].
        */
        struct SerStruct
        {
            private char[] _field;
            public this()(char[] param){_field = param;}
            public void opAssign(char[] param){_field = param;}
            public string toString(){return _field.idup;}
        }
        
        import iz.enumset;
        enum A {a0,a1,a2}
        alias SetofA = izEnumSet!(A,Set8);
        
        static assert(isSerArrayStructType!SerStruct);
        
        class Bar: izSerializable
        {    
            private: 
                SetofA set;
                SerStruct str;
                izPropDescriptor!SetofA setDescr;
                izPropDescriptor!SerStruct strDescr;
            public:
                this()
                {
                    setDescr.define(&set,"set");
                    with(A) set = SetofA(a1,a2);
                    strDescr.define(&str,"aStruct");
                    str = "azertyuiop".dup;
                }
                void declareProperties(izSerializer aSerializer)
                {
                    aSerializer.addProperty(&setDescr);
                    aSerializer.addProperty(&strDescr);
                }  
        }
        
        str.clear;
        auto bar = construct!Bar;
        scope(exit) bar.destruct;
        
        static assert(isSerStructType!SetofA);
        
        ser.objectToStream(bar, str, format);
        bar.set = [];
        bar.str = "".dup;
        str.position = 0;
        ser.streamToObject(str, bar, format);
        assert( bar.set == SetofA(A.a1,A.a2), to!string(bar.set));
        //TODO-cinvestigation: struct as simple array fails on linux X86_64.
        //assert( bar.str._field == "azertyuiop", bar.str._field );
        // ----
    
        writeln("izSerializer passed the ", to!string(format), " format test");
    }
}
