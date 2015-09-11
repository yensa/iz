module iz.serializer;

import std.range: ElementType;
import std.stdio, std.typetuple, std.conv, std.traits;
import iz.types, iz.memory, iz.properties, iz.containers, iz.streams, iz.referencable;

// Serializable types ---------------------------------------------------------+

//TODO-cfeature: SerializableReference can be replaced with a struct serialized as string. 

/**
 * Allows an implementer to be serialized by an Serializer.
 */
interface Serializable
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
     * Called by an Serializer during the de/serialization phase.
     * In the implementation, the Serializable declares its properties to the serializer.
     * Params:
     * serializer = the serializer. The implementer calls serializer.addProperty()
     * to declare arbitrarily some PropDescriptors (run-time decision).
     */
    void declareProperties(Serializer serializer);
}


/**
 * Makes a reference serializable.
 * The reference must be stored in the izReferenceMan.
 * A "referenced variable" is typically something that is assigned
 * at the run-time, such as the source of a delegate, a pointer to an Object, etc.
 */
class SerializableReference: Serializable
{
    private
    {
        char[] _tp;
        ulong  _id;
        mixin PropertiesAnalyzer;
    }
    public
    {
        ///
        this() {analyzeVirtualSetGet;}

        /**
         * Sets the internal fields according to a referenced.
         * Usually called before the serialization.
         */
        void storeReference(RT)(RT* aReferenced)
        {
            _tp = (typeString!RT).dup;
            _id = ReferenceMan.referenceID!RT(aReferenced);
        }

        /**
         * Returns the reference according to the internal fields.
         * Usually called after the deserialization.
         */
        RT* restoreReference(RT)()
        {
            return ReferenceMan.reference!RT(_id);
        }

        mixin(genPropFromField!(char[], "type", "_tp"));
        mixin(genPropFromField!(ulong,  "id",   "_id"));
        
        /// declares the data needed to retrieve the reference associated to this class
        void declareProperties(Serializer serializer)
        {
            serializer.addProperty(getDescriptor!(char[])("type"));
            serializer.addProperty(getDescriptor!(ulong)("id"));
        }
    }
}

/**
 * Enumerates the types automatically handled by a Serializer.
 */
enum SerializableType
{
    _invalid = 0,
    _byte = 0x01, _ubyte, _short, _ushort, _int, _uint, _long, _ulong,
    _float= 0x10, _double,
    _char = 0x20, _wchar, _dchar,
    _izSerializable = 0x30, _Object,
    _stream = 0x40,
} 

private struct InvalidSerType{}

private alias SerializableTypes = TypeTuple!(
    InvalidSerType, 
    byte, ubyte, short, ushort, int, uint, long, ulong,
    float, double,
    char, wchar, dchar,
    Serializable, Object,
    Stream 
);

private static immutable string[SerializableType] type2text;
private static immutable SerializableType[string] text2type;
private static immutable size_t[SerializableType] type2size;

static this()
{
    foreach(i, t; EnumMembers!SerializableType)
    {
        type2text[t] = SerializableTypes[i].stringof;
        text2type[SerializableTypes[i].stringof] = t;
        type2size[t] = SerializableTypes[i].sizeof;
    }       
}

private bool isSerObjectType(T)()
{
    static if (is(T : Serializable)) return true;
    else static if (is(T : Stream)) return false;
    else static if (is(T == Object)) return true;
    else return false;
}

private bool isSerObjectType(SerializableType type)
{
    return (type == SerializableType._izSerializable) | (type == SerializableType._Object);
}

private bool isSerSimpleType(T)()
{
    static if (isArray!T) return false;
    else static if (isSerObjectType!T) return false;
    else static if (staticIndexOf!(T, SerializableTypes) == -1) return false;
    else static if (is(T : Stream)) return false;
    else return true;
}

private static bool isSerStructType(T)()
{
    static if (!is(T==struct)) return false; 
    else
    { 
        foreach(TT; SerializableTypes)
            static if (isAssignable!(T,TT))
                return true;
        return false;
    }   
    assert(0, T.stringof ~ " is not tested by " ~ __FUNCTION__);
}

private bool isSerArrayType(T)()
{
    static if (!isArray!T) return false;
    else static if (is(T : Serializable)) return false;
    else static if (isSerObjectType!(typeof(T.init[0]))) return false;    
    else static if (staticIndexOf!(typeof(T.init[0]), SerializableTypes) == -1) return false;
    else return true;
}

/// Returns true if the template parameter is a serializable type.
bool isSerializable(T)()
{
    static if (isSerSimpleType!T) return true;
    else static if (isSerStructType!T) return true;   
    else static if (isSerArrayType!T) return true; 
    else static if (is(T : Stream)) return true;
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
    static assert( isSerializable!MemoryStream);
}

private string getElemStringOf(T)() if (isArray!T)
{
    return typeof(T.init[0]).stringof;
    // BUG with string litterals
    //return (ElementType!T).stringof;
}

unittest
{
    static assert( getElemStringOf!(int[]) == int.stringof );
    static assert( getElemStringOf!(int[1]) == int.stringof );
    static assert( getElemStringOf!(int[0]) != "azertyui" );
}

private string getSerializableTypeString(T)()
{
    static if (isArray!T) return getElemStringOf!T;
    else static if (isSerSimpleType!T) return T.stringof;
    else static if (is(T:Serializable)) return Serializable.stringof;
    else static if (is(T:Object)) return Serializable.stringof;
    else static if (isSerStructType!T)
        foreach(TT; SerializableTypes)
            static if (isAssignable!(T,TT))
                return TT.stringof;
    assert(0, "failed to get the string for a serializable type");
}
// -----------------------------------------------------------------------------

// Tree representation --------------------------------------------------------

/// Represents a serializable property without genericity.
struct SerNodeInfo
{
    /// the type pf the property
    SerializableType type;
    /// a pointer to a PropDescriptor
    Ptr   descriptor;
    /// the value
    ubyte[] value;
    /// the name of the property
    string  name;
    /// the property level in the IST
    uint    level;
    /// indicates if the property is an array
    bool    isArray;
    /// indicates if any error occured during processing
    bool    isDamaged;
    /// hint to rebuild the IST
    bool    isLastChild;
}

/** 
 * Event triggered when a serializer needs a particular property descriptor.
 * Params:
 * node = The information the callee uses to determine the descriptor to return.
 * matchingDescriptor = The callee can set or modify a pointer to the PropDescriptor 
 * matching to the info. It can be set to null to prevent restoration.
 * stop = the callee can set this value to true in order to stop the restoration 
 * process. According to the serialization context, this value can be noop.
 */
alias WantDescriptorEvent = void delegate(IstNode node, ref Ptr matchingDescriptor, out bool stop);

/**
 * Event triggered when a serializer failed to get an object to deserialize.
 * Params:
 * node = The information the callee uses to instantiate a Serializable.
 * serializable = the Object the callee has to instantiate. 
 */
alias WantObjectEvent = void delegate(IstNode node, ref Serializable serializable);

// add double quotes escape 
private char[] add_dqe(char[] input)
{
    char[] result;
    foreach(i; 0 .. input.length) {
        if (input[i] != '"') result ~= input[i];
        else result ~= "\\\"";                         
    }
    return result;
}

// remove double quotes escape
private char[] del_dqe(char[] input)
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

/// Restores the raw value contained in a SerNodeInfo using the associated setter.
void nodeInfo2Declarator(const SerNodeInfo * nodeInfo)
{
    void toDecl1(T)()  {
        auto descr = cast(PropDescriptor!T *) nodeInfo.descriptor;
        descr.set( *cast(T*) nodeInfo.value.ptr );
    }
    void toDecl2(T)() {
        auto descr = cast(PropDescriptor!(T[]) *) nodeInfo.descriptor;
        descr.set(cast(T[]) nodeInfo.value[]);
    } 
    void toDecl(T)() {
        (!nodeInfo.isArray) ? toDecl1!T : toDecl2!T;
    }
    //
    final switch(nodeInfo.type)
    {
        case SerializableType._invalid,SerializableType._izSerializable,SerializableType._Object: break;
        case SerializableType._byte: toDecl!byte; break;
        case SerializableType._ubyte: toDecl!ubyte; break;
        case SerializableType._short: toDecl!short; break;
        case SerializableType._ushort: toDecl!ushort; break;
        case SerializableType._int: toDecl!int; break;
        case SerializableType._uint: toDecl!uint; break;
        case SerializableType._long: toDecl!long; break;
        case SerializableType._ulong: toDecl!ulong; break;    
        case SerializableType._float: toDecl!float; break;
        case SerializableType._double: toDecl!double; break;
        case SerializableType._char: toDecl!char; break;   
        case SerializableType._wchar: toDecl!wchar; break;   
        case SerializableType._dchar: toDecl!dchar; break;  
        case SerializableType._stream:
            MemoryStream str = construct!MemoryStream;
            str.write(cast(ubyte*)nodeInfo.value.ptr, nodeInfo.value.length);
            str.position = 0;
            auto descr = cast(PropDescriptor!Stream *) nodeInfo.descriptor;
            descr.set(str);
            destruct(str); 
            break;                                                                                                                                  
    }
}

/// Converts the raw data contained in a SerNodeInfo to its string representation.
char[] value2text(const SerNodeInfo * nodeInfo)
{
    char[] v2t_1(T)(){return to!string(*cast(T*)nodeInfo.value.ptr).dup;}
    char[] v2t_2(T)(){return to!string(cast(T[])nodeInfo.value[]).dup;}
    char[] v2t(T)(){if (!nodeInfo.isArray) return v2t_1!T; else return v2t_2!T;}
    //
    final switch(nodeInfo.type)
    {
        case SerializableType._invalid: return "invalid".dup;
        case SerializableType._izSerializable, SerializableType._Object: return cast(char[])(nodeInfo.value);
        case SerializableType._ubyte: return v2t!ubyte;
        case SerializableType._byte: return v2t!byte;
        case SerializableType._ushort: return v2t!ushort;
        case SerializableType._short: return v2t!short;
        case SerializableType._uint: return v2t!uint;
        case SerializableType._int: return v2t!int;
        case SerializableType._ulong: return v2t!ulong;
        case SerializableType._long: return v2t!long;
        case SerializableType._float: return v2t!float;
        case SerializableType._double: return v2t!double;
        case SerializableType._char: return v2t!char;
        case SerializableType._wchar: return v2t!wchar;
        case SerializableType._dchar: return v2t!dchar;
        case SerializableType._stream: return to!(char[])(nodeInfo.value[]);
    }
}

/// Converts the literal representation to a ubyte array according to type.
ubyte[] text2value(char[] text, const SerNodeInfo * nodeInfo)
{
    ubyte[] t2v_1(T)(){
        auto res = new ubyte[](type2size[nodeInfo.type]);  
        *cast(T*) res.ptr = to!T(text);
        return res; 
    }
    ubyte[] t2v_2(T)(){
        auto v = to!(T[])(text);
        auto res = new ubyte[](v.length * type2size[nodeInfo.type]);
        moveMem(res.ptr, v.ptr, res.length);
        return res;
    }
    ubyte[] t2v(T)(){
        if (!nodeInfo.isArray) return t2v_1!T; else return t2v_2!T;
    }
    //    
    final switch(nodeInfo.type)
    {
        case SerializableType._invalid:
            return cast(ubyte[])"invalid".dup;
        case SerializableType._izSerializable, SerializableType._Object: 
            return cast(ubyte[])(text);
        case SerializableType._ubyte: return t2v!ubyte;
        case SerializableType._byte: return t2v!byte;
        case SerializableType._ushort: return t2v!ushort;
        case SerializableType._short: return t2v!short;
        case SerializableType._uint: return t2v!uint;
        case SerializableType._int: return t2v!int;
        case SerializableType._ulong: return t2v!ulong;
        case SerializableType._long: return t2v!long;
        case SerializableType._float: return t2v!float;
        case SerializableType._double: return t2v!double;
        case SerializableType._char: return t2v!char;
        case SerializableType._wchar: return t2v_2!wchar;
        case SerializableType._dchar: return t2v!dchar;
        case SerializableType._stream: return to!(ubyte[])(text);
    }
}

/// Fills an SerNodeInfo according to an PropDescriptor
void setNodeInfo(T)(SerNodeInfo * nodeInfo, PropDescriptor!T * descriptor)
{
    scope(failure) nodeInfo.isDamaged = true;
    
    // TODO: nodeInfo.value, try to use an union instead of an array 
    
    // simple, fixed-length (or convertible to), types
    static if (isSerSimpleType!T || isSerStructType!T)
    {
        static if (isSerStructType!T)
        {
            foreach(TT;SerializableTypes)
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
        nodeInfo.descriptor = cast(Ptr) descriptor;
        nodeInfo.name = descriptor.name.dup;
        * cast(T*) nodeInfo.value.ptr = descriptor.get();
        //
        return;
    }
    
    // arrays types
    else static if (isSerArrayType!T /*|| isSerArrayStructType!T*/)
    {
        /*static if (isSerArrayStructType!T)
        {
            foreach(TT;SerializableTypes)
                static if (isAssignable!(T,TT[]))
                {
                    nodeInfo.type = text2type[TT.stringof];
                    TT[] value = to!(TT[])(descriptor.get());
                    nodeInfo.value.length = value.length * type2size[nodeInfo.type];
                    memmove(nodeInfo.value.ptr, cast(void*) value.ptr, nodeInfo.value.length);
                    break;
                }          
        }
        else*/
        { 
            nodeInfo.type = text2type[getElemStringOf!T];
            T value = descriptor.get();
            nodeInfo.value.length = value.length * type2size[nodeInfo.type];
            moveMem (nodeInfo.value.ptr, cast(void*) value.ptr, nodeInfo.value.length);
        }
        //
        nodeInfo.isArray = true;
        nodeInfo.descriptor = cast(Ptr) descriptor;
        nodeInfo.name = descriptor.name.dup;
        //
        return;
    }
   
    // Serializable or Object
    else static if (isSerObjectType!T)
    {
        Serializable ser;
        static if (is(T == Object))
            ser =  cast(Serializable) descriptor.get();       
        else
            ser = descriptor.get();
            
        char[] value = ser.className.dup;
        //
        nodeInfo.type = text2type[typeof(ser).stringof];
        nodeInfo.isArray = false;
        nodeInfo.descriptor = cast(Ptr) descriptor;
        nodeInfo.name = descriptor.name.dup;
        nodeInfo.value.length = value.length;
        moveMem(nodeInfo.value.ptr, value.ptr, nodeInfo.value.length);      
        //
        return;   
    }   
    
    // stream
    else static if (is(T : Stream))
    {
        nodeInfo.type = text2type[T.stringof];
        nodeInfo.isArray = false;
        nodeInfo.descriptor = cast(Ptr) descriptor;
        nodeInfo.name = descriptor.name.dup;
        //
        Stream value = descriptor.get();
        value.position = 0;
        nodeInfo.value.length = cast(uint) value.size;
        value.read(nodeInfo.value.ptr, cast(uint) value.size); 
        destroy(value);  
        //
        return;   
    } 
}

/// IST node
class IstNode : TreeItem
{
    mixin TreeItemAccessors;
    private SerNodeInfo _info;
    public
    {
        /**
         * Sets the infomations describing the property associated
         * to this IST node.
         */
        void setDescriptor(T)(PropDescriptor!T * descriptor)
        {
            if (descriptor)
                setNodeInfo!T(&_info, descriptor);
        }
        /** 
         * Returns a pointer to the information describing the property
         * associated to this IST node.
         */
        SerNodeInfo * info()
        {
            return &_info;
        }   
        /**
         * Returns the identifier chain of the parents.
         */
        string parentIdentifiers()
        {
            if (!level) return "";
            //   
            import std.array: join;
            string[] items;
            items.length = level * 2;
            auto cnt = items.length;
            IstNode curr = cast(IstNode) parent;
            while (curr)
            {
                cnt--;
                items[cnt--] = ".";
                items[cnt] = curr.info.name;
                curr = cast(IstNode) curr.parent;
            }
            return items.join[0..$-1];    
        }
    }
}

/// Propotype of a function which writes the representation of an IstNode in an izStream.
alias SerializationWriter = void function(IstNode istNode, Stream stream);

/// Propotype of a function which reads the representation of an IstNode from an izStream.
alias SerializationReader = void function(Stream stream, IstNode istNode);

// JSON format ----------------------------------------------------------------+
private void writeJSON(IstNode istNode, Stream stream)
{
    import std.json;
    //    
    auto level  = JSONValue(istNode.level);
    auto type   = JSONValue(istNode.info.type);
    auto name   = JSONValue(istNode.info.name.idup);
    auto isarray= JSONValue(cast(ubyte)istNode.info.isArray);
    auto value  = JSONValue(value2text(istNode.info).idup);
    auto prop   = JSONValue(["level":level,"type":type,"name":name,"isarray":isarray,"value":value]);
    auto txt    = toJSON(&prop, false).dup;
    //
    stream.write(txt.ptr, txt.length);   
}

private void readJSON(Stream stream, IstNode istNode)
{
    import std.json;
    //
    // cache property
    size_t cnt, len;
    char c;
    bool skip;
    auto immutable stored = stream.position;
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
        istNode.info.level = cast(uint) level.integer;
    else 
        istNode.info.isDamaged = true;
        
    JSONValue type = prop["type"];
    if (type.type == JSON_TYPE.INTEGER) 
        istNode.info.type = cast(SerializableType) type.integer;
    else 
        istNode.info.isDamaged = true;       
        
    JSONValue name = prop["name"];
    if (name.type == JSON_TYPE.STRING) 
        istNode.info.name = name.str.dup;
    else 
        istNode.info.isDamaged = true;   
        
    immutable JSONValue isarray = prop["isarray"];
    if (isarray.type == JSON_TYPE.INTEGER) 
        istNode.info.isArray = cast(bool) isarray.integer;
    else 
        istNode.info.isDamaged = true;                    
        
    JSONValue value = prop["value"];
    if (value.type == JSON_TYPE.STRING) 
        istNode.info.value = text2value(value.str.dup, istNode.info);
    else 
        istNode.info.isDamaged = true;                   
    
}
// ----

// Text format ----------------------------------------------------------------+
private void writeText(IstNode istNode, Stream stream)
{
    char separator = ' ';
    // indentation
    char tabulation = '\t';
    foreach(i; 0 .. istNode.level)
        stream.write(&tabulation, tabulation.sizeof);
    // type
    char[] type = type2text[istNode.info.type].dup;
    stream.write(type.ptr, type.length);
    // array
    char[2] arr = "[]";
    if (istNode.info.isArray) stream.write(arr.ptr, arr.length); 
    stream.write(&separator, separator.sizeof);
    // name
    char[] name = istNode.info.name.dup;
    stream.write(name.ptr, name.length);
    stream.write(&separator, separator.sizeof);
    // name value separators
    char[] name_value = " = \"".dup;
    stream.write(name_value.ptr, name_value.length);
    // value
    char[] value = value2text(istNode.info); // add_dqe
    stream.write(value.ptr, value.length);
    char[] eol = "\"\n".dup;
    stream.write(eol.ptr, eol.length);
}  

private void readText(Stream stream, IstNode istNode)
{
    size_t i;
    char[] identifier;  
    // cache the property
    char[] propText;
    char[2] eop;
    auto immutable initPos = stream.position;
    while((eop != "\"\n") & (stream.position != stream.size)) 
    {
        stream.read(eop.ptr, 2);
        stream.position = stream.position -1;
    }
    auto immutable endPos = stream.position;
    propText.length = cast(ptrdiff_t)(endPos - initPos);
    stream.position = initPos;
    stream.read(propText.ptr, propText.length);
    stream.position = endPos + 1;
        
    // level
    i = 0;
    while (propText[i] == '\t') i++;
    istNode.info.level = cast(uint) i;
    
    // type
    identifier = identifier.init;
    while(propText[i] != ' ') 
        identifier ~= propText[i++];
    char[2] arr;
    if (identifier.length > 2) 
    {
        arr = identifier[$-2 .. $];
        istNode.info.isArray = (arr == "[]");
    }
    if (istNode.info.isArray) 
        identifier = identifier[0 .. $-2];
    if (identifier in text2type) 
        istNode.info.type = text2type[identifier];
         
    // name
    i++;
    identifier = identifier.init;
    while(propText[i] != ' ') 
        identifier ~= propText[i++];
    istNode.info.name = identifier.idup; 
    
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
    istNode.info.value = text2value(identifier, istNode.info);
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

private void writeBin(IstNode istNode, Stream stream)
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
    bin = cast(ubyte) istNode.info.type; 
    stream.write(&bin, bin.sizeof);
    // as array
    bin = istNode.info.isArray; 
    stream.write(&bin, bin.sizeof);  
    // name length then name
    data = cast(ubyte[]) istNode.info.name;
    datalength = cast(uint) data.length;
    stream.write(&datalength, datalength.sizeof);
    stream.write(data.ptr, datalength);
    // value length then value
    version(LittleEndian)
    {
        datalength = cast(uint) istNode.info.value.length;
        stream.write(&datalength, datalength.sizeof);
        stream.write(istNode.info.value.ptr, datalength);        
    }
    else
    {
        data = swapBE(istNode.info.value, type2size[istNode.info.type]);
        datalength = cast(uint) data.length;
        stream.write(&datalength, datalength.sizeof);
        stream.write(data.ptr, datalength); 
    }
    //footer
    bin = 0xA0;
    stream.write(&bin, bin.sizeof); 
}  

private void readBin(Stream stream, IstNode istNode)
{
    ubyte bin;
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
    istNode.info.level = datalength;                
    // type and array
    istNode.info.type = cast(SerializableType) data[4];
    istNode.info.isArray = cast(bool) data[5];      
    // name length then name;
    datalength = *cast(uint*) (data.ptr + 6);
    istNode.info.name = cast(string) data[10.. 10 + datalength].idup; 
    beg =  10 +  datalength;      
    // value length then value
    version(LittleEndian)
    {
        datalength = *cast(uint*) (data.ptr + beg);
        istNode.info.value = data[beg + 4 .. beg + 4 + datalength];    
    }
    else
    {
        datalength = *cast(uint*) (data.ptr + beg);
        data = data[beg + 4 .. beg + 4 + datalength];
        istNode.info.value = swapBE(data, type2size[istNode.info.type]);
    } 
}  
//----

// High end serializer --------------------------------------------------------+

/// Enumerates the possible state of an Serializer.
enum SerializationState : ubyte
{
    /// the serializer is idle.
    none,
    /// the serializer is storing (from declarator to serializer).
    store,  
    /// the serializer is restoring (from serializer to declarator).
    restore     
}

/// Enumerates the possible storage mode.
enum StoreMode : ubyte
{
    /// stores directly after declaration. order is granted. a single property descriptor can be used for several properties.
    sequential,
    /// stores when eveything is declared. a single property descriptor cannot be used for several properties.  
    bulk        
}

/// Enumerates the possible restoration mode.
enum RestoreMode : ubyte
{
    /// restores following declaration. order is granted.
    sequential, 
    /// restores without declaration or according to a custom query.
    random      
}

/// Enumerates the possible serialization format
enum SerializationFormat : ubyte
{
    /// native binary format
    izbin,
    /// native readable text format 
    iztxt,
    /// JSON chunks
    json
}

private SerializationWriter writeFormat(SerializationFormat format)
{
    with(SerializationFormat) final switch(format) {
        case izbin: return &writeBin;
        case iztxt: return &writeText;   
        case json:  return &writeJSON;
    }
}

private SerializationReader readFormat(SerializationFormat format)
{
    with(SerializationFormat) final switch(format) {
        case izbin: return &readBin;
        case iztxt: return &readText;
        case json:  return &readJSON;   
    }
}

//TODO-cfeature: Serializer error handling.

/**
 * Native serializer.
 * A Serializer is specialized to store and restore from any class heriting
 * from the interface Serializable. A Serializable arbitrarily exposes some
 * properties to serialize using the PropDescriptor format.
 *
 * The serializer uses an intermediate serialization tree (IST) which grants a 
 * certain flexibilty. 
 * As expected for a serializer, some objects trees can be stored or restored by 
 * a simple and single call ( *objectToStream()* and *streamToObject()* ) but the 
 * IST also allows to convert a data stream, to randomly find and restores 
 * some properties and to handle compatibility errors.
 * Even the IST can be build manually, without using the automatic mechanism.
 */
class Serializer
{
    private
    {
        // the IST root
        IstNode _rootNode;
        // the current node, representing an Serializable or not
        IstNode _currNode;
        // the current parent node, always representing an Serializable
        IstNode _parentNode;
        // the last created node 
        IstNode _previousNode;
        
        // the Serializable linked to _rootNode
        Serializable _rootSerializable;
        // the Serializable linked to _parentNode
        Serializable _currSerializable;
        
        WantDescriptorEvent _onWantDescriptor;
        WantObjectEvent _onWantObject;
        
        SerializationState _serState;
        StoreMode _storeMode;
        RestoreMode _restoreMode;
        SerializationFormat _format;
        
        Stream _stream;
        PropDescriptor!Serializable _rootDescr;
        
        bool _mustWrite;
        bool _mustRead;
        
        // prepares the first IST node
        void setRoot(Serializable root)
        {
            _rootSerializable = root;
            _currNode = _rootNode;
            _rootDescr.define(&_rootSerializable, "Root");
            _rootNode.setDescriptor(&_rootDescr);
        }
        
        bool restoreFromEvent(IstNode node, out bool stop)
        {
            if (!_onWantDescriptor) 
                return false;
            bool done;
            _onWantDescriptor(node, node.info.descriptor, stop);
            done = (node.info.descriptor != null);
            if (done) 
            {
                nodeInfo2Declarator(node.info);
                return true;
            }
            else if (isSerObjectType(node.info.type))
                return true;
            return false;
        }
        
        bool descriptorMatchesNode(T)(PropDescriptor!T* descr, IstNode node)
        if (isSerializable!T)
        {   
            if (!descr) return false;
            if (!node.info.name.length) return false;
            if (descr.name != node.info.name) return false;
            static if (isArray!T) if (!node.info.isArray) return false;
            if (getSerializableTypeString!T != type2text[node.info.type]) return false;
            return true;
        }
    }
    
    public 
    {  
        ///
        this()
        {
            _rootNode = construct!IstNode;
        }
        ~this()
        {
            _rootNode.deleteChildren;
            destruct(_rootNode);
        }         
              
//---- serialization ----------------------------------------------------------+
        
        /** 
         * Builds the IST from an Serializable.
         * The process starts by a call to .declareProperties() in the root then
         * the process is lead by the the subsequent declarations.
         * Params:
         * root = the Serializable from where the declarations start.
         */
        void objectToIst(Serializable root)
        {
            _storeMode = StoreMode.bulk;
            _serState = SerializationState.store;
            _mustWrite = false;
            //
            _rootNode.deleteChildren;
            _previousNode = null;
            setRoot(root);
            _currSerializable = _rootSerializable;
            _currNode = _rootNode;
            //
            _parentNode = _rootNode;
            _currSerializable.declareProperties(this);
            _serState = SerializationState.none;
        }
        
        /** 
         * Builds the IST from an Serializable and stores sequentially in a stream.
         * The process starts by a call to .declaraPropties() in the root then
         * the process is lead by the the subsequent declarations.
         * The data are written right after a descriptor declaration.
         * Params:
         * root = the Serializable from where the declarations starts.
         * outputStream = the stream where te data are written.
         * format = the format of the serialized data.
         */
        void objectToStream(Serializable root, Stream outputStream, 
            SerializationFormat format = SerializationFormat.iztxt)
        {
            _format = format;
            _stream = outputStream;
            _storeMode = StoreMode.sequential;
            _serState = SerializationState.store;
            _mustWrite = true;
            //
            _rootNode.deleteChildren;
            _previousNode = null;
            setRoot(root);
            _currSerializable = _rootSerializable;
            _currNode = _rootNode;
            writeFormat(_format)(_currNode, _stream);
            //
            _parentNode = _rootNode;
            _currSerializable.declareProperties(this);
            //
            _mustWrite = false;
            _serState = SerializationState.none;
            _stream = null;
        }
        
        /** 
         * Saves the IST to a stream. 
         * The data are grabbed in bulk therefore the descriptor linked to each
         * tree node cannot be re-used.
         * Params:
         * outputStream = the stream where te data are written.
         * format = the format of the serialized data.
         */
        void istToStream(Stream outputStream, SerializationFormat format = SerializationFormat.iztxt)
        {
            _format = format;
            _stream = outputStream;
            _storeMode = StoreMode.bulk;
            _mustWrite = true;
            //
            void writeNodesFrom(IstNode parent)
            {
                writeFormat(_format)(parent, _stream); 
                foreach(node; parent.children)
                {
                    auto child = cast(IstNode) node;           
                    if (isSerObjectType(child.info.type))
                        writeNodesFrom(child);
                    else writeFormat(_format)(child, _stream); 
                }
            }
            writeNodesFrom(_rootNode);
            //
            _mustWrite = false;
            _stream = null;
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
        void streamToIst(Stream inputStream, SerializationFormat format = SerializationFormat.iztxt)
        {
            IstNode[] unorderNodes;
            IstNode[] parents;
            _rootNode.deleteChildren;
            _currNode = _rootNode;
            _mustRead = false;
            _stream = inputStream;
            _format = format;
            
            while(inputStream.position < inputStream.size)
            {
                unorderNodes ~= _currNode;      
                readFormat(_format)(_stream, _currNode);
                _currNode = construct!IstNode;
            }
            destruct(_currNode);
            
            if (unorderNodes.length > 1)
            foreach(i; 1 .. unorderNodes.length)
            {
                unorderNodes[i-1].info.isLastChild = 
                  unorderNodes[i].info.level < unorderNodes[i-1].info.level;       
            }
            
            parents ~= _rootNode;
            foreach(i; 1 .. unorderNodes.length)
            {
                auto node = unorderNodes[i];
                parents[$-1].addChild(node);
                
                if (node.info.isLastChild)
                    parents.length -= 1;
                 
                if (isSerObjectType(node.info.type))
                    parents ~= node;
            }  
            //
            _stream = null;  
        }
        
        /** 
         * Builds the IST from a stream and restores sequentially to a root.
         * The process starts by a call to .declaraPropties() in the root.
         * Params:
         * inputStream = the stream containing the serialized data.
         * root = the Serializable from where the declarations and the restoration starts.
         * format = the format of the serialized data.
         */
        void streamToObject(Stream inputStream, Serializable root, SerializationFormat format = SerializationFormat.iztxt)
        {
            _serState = SerializationState.restore;
            _restoreMode = RestoreMode.sequential;
            _mustRead = true;
            _stream = inputStream;
            _format = format;
            //
            _rootNode.deleteChildren;
            _previousNode = null;
            setRoot(root);
            _currSerializable = _rootSerializable;
            _currNode = _rootNode;
            readFormat(_format)(_stream, _currNode);
            //
            _parentNode = _rootNode;
            _currSerializable = _rootSerializable;
            _currSerializable.declareProperties(this);   
            //   
            _mustRead = false;
            _serState = SerializationState.none;
            _stream = null;  
        }   
        
        /**
         * Fully Restores the IST. Can be called after *streamToIst()*.
         * For each ISTnode and if assigned, the onWantDesscriptor event is called.
         */
        void istToObject() {istToObject(_rootNode, true);}    
        
        /**
         * Finds the tree node matching to a property names chain.
         * Params:
         * descriptorName = the property names chain which identifies the interesting node.
         * Returns:
         * A reference to the node which matches to the property if the call succeeds otherwise nulll.
         */ 
        IstNode findNode(in char[] descriptorName)
        {
        
            //TODO-cfeature : optimize random access by caching in an AA, "à la JSON"
            
            if (_rootNode.info.name == descriptorName)
                return _rootNode;
            
            IstNode scanNode(IstNode parent, in char[] namePipe)
            {
                IstNode result;
                foreach(node; parent.children)
                {
                    auto child = cast(IstNode) node; 
                    if (namePipe ~ "." ~ child.info.name == descriptorName)
                        return child;
                    if (child.childrenCount)
                        result = scanNode(child, namePipe ~ "." ~ child.info.name);
                    if (result)
                        return result;
                }
                return result;
            }
            return scanNode(_rootNode, _rootNode.info.name);
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
        void istToObject(IstNode node, bool recursive = false)
        {
            bool restore(IstNode current)
            {
                bool result = true;
                if (current.info.descriptor && 
                    current.info.name ==  (cast(PropDescriptor!byte *)current.info.descriptor).name)
                    nodeInfo2Declarator(current.info);
                else
                {
                    bool stop;
                    result = restoreFromEvent(current, stop);
                    result &= !stop;
                }
                return result;    
            }
            
            bool restoreLoop(IstNode current)
            {
                if (!restore(current)) return false;
                foreach(child; current.children)
                {
                    auto childNode = cast(IstNode) child;
                    if (!restore(childNode)) return false;
                    if (isSerObjectType(childNode.info.type) & recursive)
                        if (!restoreLoop(childNode)) return false;
                }
                return true;
            }
            
            restoreLoop(node);
        }
        
        /**
         * Restores a single property from a tree node using the setter of a descriptor.
         * Params:
         * node = an IstNode. Can be determined by a call to findNode()
         * aDescriptor = the PropDescriptor whose setter is used to restore the node data.
         * If not specified then the onWantDescriptor event may be called.
         */
        void restoreProperty(T)(IstNode node, PropDescriptor!T * descriptor = null)
        {
            _serState = SerializationState.restore;
            _restoreMode = RestoreMode.random;
            
            if (descriptorMatchesNode!T(descriptor, node))
            {
                node.info.descriptor = descriptor;
                nodeInfo2Declarator(node.info);
            }
            else 
            {
                bool noop;
                restoreFromEvent(node, noop);
            }   
        }        

//------------------------------------------------------------------------------
//---- declaration from an Serializable ---------------------------------------+
    
        /*( the following methods are designed to be only used by an Serializable !)*/
    
        //mixin(genAllAdders);
        
        /**
         * Designed to be called by an Serializable when it needs to declare 
         * a property in its declarePropeties() method.
         *
         * Allowed properties:
         * - all the basic types: int, uint, char, ...
         * - all the basic types as array: int[], uin[], char[], ...
         * - the structs assignable from/to a basic type (if they include a public alias this but not only)
         * - the structs assignable from/to an array of basic type (this(char[]), opAssign(char[]), toString())
         * - the Serializable (used to build the structure).
         * - any class, if it implements Serializable. It's safer to pass some PropDescriptor!Serializable but PropDescriptor!Object is easyer.
         *
         * Some aliases exist for each basic type (addintProperty(), addcharProperty(), ...).
         * the structs are represented as the type they convert to and are not used to build the IST.
         */
        void addProperty(T)(PropDescriptor!T * descriptor)
        if (isSerializable!T)
        {    
            if (!descriptor) return;
            if (!descriptor.name.length) return;
            
            _currNode = _parentNode.addNewChildren!IstNode;
            _currNode.setDescriptor(descriptor);
            
            if (_mustWrite && _storeMode == StoreMode.sequential)
                writeFormat(_format)(_currNode, _stream); 
                
            if (_mustRead) {
                readFormat(_format)(_stream, _currNode);
                if (descriptorMatchesNode!T(descriptor, _currNode)) 
                    nodeInfo2Declarator(_currNode.info);
                else 
                {
                    bool noop;
                    restoreFromEvent(_currNode, noop);
                }
            }
            
            static if (isSerObjectType!T)
            {
                if (_previousNode)
                    _previousNode.info.isLastChild = true;
            
                auto oldSerializable = _currSerializable;
                auto oldParentNode = _parentNode;
                _parentNode = _currNode;
                
                
                if (!descriptorMatchesNode!T(descriptor, _currNode) && _onWantDescriptor)
                {
                    bool stop = false;
                    Ptr descr = &descriptor;
                    _onWantDescriptor(_currNode, descr, stop);
                    if (stop) return;
                }
                
                
                static if (is(T : Serializable))
                    _currSerializable = descriptor.get();
                else
                {
                    auto obj = descriptor.get();
                    if (obj) _currSerializable = cast(Serializable) obj;
                }
                   
                if (!_currSerializable && _onWantObject)
                {
                    _onWantObject(_currNode, _currSerializable);
                    if (!_currSerializable) return;
                }   
                   
                    
                _currSerializable.declareProperties(this);
                _parentNode = oldParentNode;
                _currSerializable = oldSerializable;
            }    
            
            _previousNode = _currNode;      
        }
        
        /// state is set visible to an Serializable to let it know how the properties will be used (store: getter, restore: setter)
        @property SerializationState state() {return _serState;}
        
        /// storeMode is set visible to an Serializable to let it adjust the way to declare the properties. 
        @property StoreMode storeMode() {return _storeMode;}
        
        /// restoreMode is set visible to an Serializable to let it adjust the way to declare the properties. 
        @property RestoreMode restoreMode() {return _restoreMode;}
         
        /// serializationFormat is set visible to an Serializable to let it adjust the way to declare the properties. 
        @property SerializationFormat serializationFormat() {return _format;} 
        
        /// The IST can be modified, build, cleaned from the root node
        @property IstNode serializationTree(){return _rootNode;}
        
        /// Event triggered when the serializer needs a particulat property descriptor.
        @property WantDescriptorEvent onWantDescriptor(){return _onWantDescriptor;}
        
        /// ditto
        @property void onWantDescriptor(WantDescriptorEvent value){_onWantDescriptor = value;}
        
        /// Event triggered when the serializer needs a particulat property descriptor.
        @property WantObjectEvent onWantObject(){return _onWantObject;}
        
        /// ditto
        @property void onWantObject(WantObjectEvent value){_onWantObject = value;}        
//------------------------------------------------------------------------------
    } 
}

//----

private static string genAllAdders()
{
    string result;
    foreach(t; SerializableTypes) if (!(is(t == struct)))
        result ~= "alias add" ~ t.stringof ~ "Property =" ~ "addProperty!" ~ t.stringof ~";"; 
    return result;
}

version(unittest)
{
    unittest
    {
        char[] text;
        ubyte[] value;
        SerNodeInfo inf;
        //
        value = [13];
        text = "13".dup;
        inf.type = SerializableType._byte ;
        inf.value = value ;
        inf.isArray = false;
        assert(value2text(&inf) == text);
        assert(text2value(text, &inf) == value);
        //
        value = [13,14];
        text = "[13, 14]".dup;
        inf.type = SerializableType._byte ;
        inf.value = value ;
        inf.isArray = true;
        assert(value2text(&inf) == text);
        assert(text2value(text, &inf) == value); 
        //  
        void testType(T)(T t)
        {
            char[] asText;
            T value = t;
            SerNodeInfo inf;
            PropDescriptor!T descr;
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
        
        writeln("Serializer passed the text-value conversions test");     
    }

    unittest 
    {
        foreach(fmt;EnumMembers!SerializationFormat)
            testByFormat!fmt();
        //testByFormat!(SerializationFormat.iztxt)();
        //testByFormat!(SerializationFormat.izbin)();
        //testByFormat!(SerializationFormat.json)();
    }
    
    class Referenced1 {}
    
    class ReferencedUser : Serializable
    {
        PropDescriptor!Object fRefDescr;
        SerializableReference fSerRef;
        Referenced1 * fRef;
    
        this() {
            fSerRef = construct!SerializableReference;
            fRefDescr.define(cast(Object*)&fSerRef, "theReference");
        }
        
        ~this() {destruct(fSerRef);}
        
        void declareProperties(Serializer serializer)
        {
            if (serializer.state == SerializationState.store)
                fSerRef.storeReference!Referenced1(fRef);
                
            serializer.addProperty(&fRefDescr);
            
            if (serializer.state == SerializationState.restore)
                fRef = fSerRef.restoreReference!Referenced1;
        }
    }
    
    class ClassA: ClassB
    {
        private:
            ClassB _aB1, _aB2;
            PropDescriptor!Object aB1descr, aB2descr;
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
            override void declareProperties(Serializer serializer) {
                super.declareProperties(serializer);
                serializer.addProperty(&aB1descr);
                serializer.addProperty(&aB2descr);
            }
    }
    
    class ClassB : Serializable
    {
        mixin PropertiesAnalyzer;
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
                _anIntArray = _anIntArray.init; 
                _aFloat = 0.0f;
                _someChars = _someChars.init;
            }
            
            mixin(genPropFromField!(typeof(_anIntArray), "anIntArray", "_anIntArray"));
            mixin(genPropFromField!(typeof(_aFloat), "aFloat", "_aFloat"));
            mixin(genPropFromField!(typeof(_someChars), "someChars", "_someChars")); 
            
            void declareProperties(Serializer serializer) {
                serializer.addProperty(getDescriptor!(typeof(_anIntArray))("anIntArray"));
                serializer.addProperty(getDescriptor!(typeof(_aFloat))("aFloat"));
                serializer.addProperty(getDescriptor!(typeof(_someChars))("someChars"));
            }
    }
    
    void testByFormat(SerializationFormat format)()
    {
        MemoryStream str  = construct!MemoryStream;
        Serializer ser    = construct!Serializer;
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
        auto aFloatDescr = PropDescriptor!float(&outside, "aFloat");
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
        
        assert( ReferenceMan.storeReference!Referenced1(&ref1, 0x11223344));
        assert( ReferenceMan.storeReference!Referenced1(&ref2, 0x55667788));
        assert( ReferenceMan.referenceID!Referenced1(&ref1) == 0x11223344);
        assert( ReferenceMan.referenceID!Referenced1(&ref2) == 0x55667788);
        
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
        void wantDescr(IstNode node, ref Ptr matchingDescriptor, out bool stop)
        {
            immutable string chain = node.parentIdentifiers;
            if (chain == "Root")
                matchingDescriptor = a.getUntypedDescriptor(node.info.name);
            else if (chain == "Root.aB1")
                matchingDescriptor = a._aB1.getUntypedDescriptor(node.info.name);
            else if (chain == "Root.aB2")
                matchingDescriptor = a._aB2.getUntypedDescriptor(node.info.name);                      
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
        
        // struct serialized as basicType or ---+
        
        import iz.enumset;
        enum A {a0,a1,a2}
        alias SetofA = EnumSet!(A,Set8);
        
        class Bar: Serializable
        {    
            private: 
                SetofA set;
                PropDescriptor!SetofA setDescr;
            public:
                this()
                {
                    setDescr.define(&set,"set");
                    with(A) set = SetofA(a1,a2);
                }
                void declareProperties(Serializer serializer)
                {
                    serializer.addProperty(&setDescr);
                }  
        }
        
        str.clear;
        auto bar = construct!Bar;
        scope(exit) bar.destruct;
        
        static assert(isSerStructType!SetofA);
        
        ser.objectToStream(bar, str, format);
        bar.set = [];
        str.position = 0;
        ser.streamToObject(str, bar, format);
        assert( bar.set == SetofA(A.a1,A.a2), to!string(bar.set));
        
        // ----
    
        writeln("Serializer passed the ", to!string(format), " format test");
    }


    // test fields renamed between two versions ---+
    class ErrSer: Serializable
    {
        @GetSet private uint _a = 78;
        @GetSet private char[] _b = "foobar".dup;
        
        mixin PropertiesAnalyzer;
        
        this()
        {
            analyzeAll;
        }
        
        void declareProperties(Serializer serializer)
        {
            serializer.addProperty(getDescriptor!uint("a"));
            serializer.addProperty(getDescriptor!(char[])("b"));
        }   
    }
    
    class ErrDeSer: Serializable
    {
        @GetSet private int _c;
        @GetSet private ubyte[] _d;
        
        mixin PropertiesAnalyzer;
        
        this()
        {
            analyzeAll;
        }
        
        void declareProperties(Serializer serializer)
        {
            serializer.addProperty(getDescriptor!int("c"));
            serializer.addProperty(getDescriptor!(ubyte[])("d"));
        }   
    }    
    
    unittest
    {
        ErrSer errser = construct!ErrSer;
        ErrDeSer errdeser = construct!ErrDeSer;
        Serializer ser = construct!Serializer;
        MemoryStream str = construct!MemoryStream;
        scope(exit) destruct(errser, ser, str, errdeser);
        
        ser.objectToStream(errser, str);
        str.position = 0;
        
        void error(IstNode node, ref Ptr matchingDescriptor, out bool stop)
        {
            if (node.info.name == "a")
            {/*will be restored in _c, same size, almost safe*/}
            if (node.info.name == "b")
            {matchingDescriptor = errdeser.getDescriptor!(ubyte[])("d");}
                
            stop = false;   
        }        
        
        ser.onWantDescriptor = &error;
        ser.streamToObject(str, errdeser); 
        
        assert(errdeser._c == 78);
        assert(cast(char[])errdeser._d == "foobar"); 
    }
    //----
}

