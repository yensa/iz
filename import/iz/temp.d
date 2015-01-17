module iz.temp;

import std.typetuple, std.conv, std.traits;
import iz.types, iz.properties, iz.containers, iz.streams;

// Serializable types ----------------------------------------------------------
public interface izSerializable
{
    string className();
	void declareProperties(izSerializer aSerializer);
}

private enum izSerType
{
    _invalid = 0,
    _byte = 0x01, _ubyte, _short, _ushort, _int, _uint, _long, _ulong,
    _float= 0x10, _double,
    _char = 0x20, _wchar, _dchar,
    _izSerializable = 0x30, _Object
} 

private alias izSerTypeTuple = TypeTuple!(uint, 
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

static bool isSerObjectType(T)()
{
    static if (is(T : izSerializable)) return true;
    else static if (is(T == Object)) return true;
    else return false;
}

bool isSerObjectType(izSerType type)
{
    return (type == izSerType._izSerializable) | (type == izSerType._Object);
}

static bool isSerSimpleType(T)()
{
    static if (isArray!T) return false;
    else static if (isSerObjectType!T) return false;
    else static if (staticIndexOf!(T, izSerTypeTuple) == -1) return false;
    else return true;
}

bool isSerArrayType(T)()
{
    static if (is(T : izSerializable)) return false;
    else static if (isSerObjectType!T) return false;
    else static if (staticIndexOf!(typeof(T.init[0]), izSerTypeTuple) == -1) return false;
    else return true;
}

string getElemStringOf(T)() if (isArray!T)
{
    return typeof(T.init[0]).stringof;
}

// Tree representation ---------------------------------------------------------

/// Represents a serializable property without genericity.
public struct izSerNodeInfo
{
    izSerType type;
    izPtr   descriptor;
    ubyte[] value;
    char[]  name;
    size_t  level;
    bool    isArray;
    bool    isDamaged;
    bool    isLastChild;
}

/// add double quotes escape 
char[] add_dqe(char[] input)
{
    char[] result;
    foreach(i; 0 .. input.length) {
        if (input[i] != '"') result ~= input[i];
        else result ~= "\\\"";                         
    }
    return result;
}

/// remove double quotes escape
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

/// Converts the raw data contained in a izSerNodeInfo to its string representation.
char[] value2text(const izSerNodeInfo * nodeInfo)
{
    char[] v2t_1(T)(){return to!string(*cast(T*)nodeInfo.value.ptr).dup;}
    char[] v2t_2(T)(){return to!string(cast(T[])nodeInfo.value[]).dup;}

    final switch(nodeInfo.type)
    {
        case izSerType._invalid:
            return "invalid".dup;
        case izSerType._izSerializable, izSerType._Object:
            return cast(char[])(nodeInfo.value);
        case izSerType._ubyte:
            if (!nodeInfo.isArray) return v2t_1!ubyte; else return v2t_2!ubyte;
        case izSerType._byte:
            if (!nodeInfo.isArray) return v2t_1!byte; else return v2t_2!byte;
        case izSerType._ushort:
            if (!nodeInfo.isArray) return v2t_1!ushort; else return v2t_2!ushort;
        case izSerType._short:
            if (!nodeInfo.isArray) return v2t_1!short; else return v2t_2!short;
        case izSerType._uint:
            if (!nodeInfo.isArray) return v2t_1!uint; else return v2t_2!uint;
        case izSerType._int:
            if (!nodeInfo.isArray) return v2t_1!int; else return v2t_2!int;
        case izSerType._ulong:
            if (!nodeInfo.isArray) return v2t_1!ulong; else return v2t_2!ulong;
        case izSerType._long:
            if (!nodeInfo.isArray) return v2t_1!long; else return v2t_2!long;
        case izSerType._float:
            if (!nodeInfo.isArray) return v2t_1!float; else return v2t_2!float;
        case izSerType._double:
            if (!nodeInfo.isArray) return v2t_1!double; else return v2t_2!double;
        case izSerType._char:
            if (!nodeInfo.isArray) return v2t_1!char; else return v2t_2!char;
        case izSerType._wchar:
            if (!nodeInfo.isArray) return v2t_1!wchar; else return v2t_2!wchar;
        case izSerType._dchar:
            if (!nodeInfo.isArray) return v2t_1!dchar; else return v2t_2!dchar;
    }
}

/// Converts the literal representation to a ubyte array according to type.
ubyte[] text2value(in char[] text, izSerType type, bool isArray)
{
    ubyte[] t2v_1(T)(){
        auto res = new ubyte[](type2size[type]);  
        *cast(T*) res.ptr = to!T(text);
        return res; 
    }
    ubyte[] t2v_2(T)(){
        auto v = to!(T[])(text);
        auto res = new ubyte[](v.length * type2size[type]);
        memmove(res.ptr, v.ptr, res.length);
        return res;
    }
    
    final switch(type)
    {
        case izSerType._invalid:
            return cast(ubyte[])"invalid".dup;
        case izSerType._izSerializable, izSerType._Object: 
            return cast(ubyte[])(text);
        case izSerType._ubyte:
            if (!isArray) return t2v_1!ubyte; else return t2v_2!ubyte;
        case izSerType._byte:
            if (!isArray) return t2v_1!byte; else return t2v_2!byte;
        case izSerType._ushort:
            if (!isArray) return t2v_1!ushort; else return t2v_2!ushort;
        case izSerType._short:
            if (!isArray) return t2v_1!short; else return t2v_2!short;
        case izSerType._uint:
            if (!isArray) return t2v_1!uint; else return t2v_2!uint;
        case izSerType._int:
            if (!isArray) return t2v_1!int; else return t2v_2!int;
        case izSerType._ulong:
            if (!isArray) return t2v_1!ulong; else return t2v_2!ulong;
        case izSerType._long:
            if (!isArray) return t2v_1!long; else return t2v_2!long;
        case izSerType._float:
            if (!isArray) return t2v_1!float; else return t2v_2!float;
        case izSerType._double:
            if (!isArray) return t2v_1!double; else return t2v_2!double;
        case izSerType._char:
            if (!isArray) return t2v_1!char; else return t2v_2!char;
        case izSerType._wchar:
            return t2v_2!wchar;
        case izSerType._dchar:
            if (!isArray) return t2v_1!dchar; else return t2v_2!dchar;
    }
}

/// Fills an izSerNodeInfo according to an izPropDescriptor
//!\ generate all the possible instance /!\ 
void setNodeInfo(T)(izSerNodeInfo * nodeInfo, izPropDescriptor!T * descriptor)
{
    scope(failure) nodeInfo.isDamaged = true;
    
    // simple, fixed-length, types
    static if (isSerSimpleType!T)
    {
        nodeInfo.type = text2type[T.stringof];
        nodeInfo.isArray = false;
        nodeInfo.value.length = type2size[nodeInfo.type];
        nodeInfo.descriptor = cast(izPtr) descriptor;
        nodeInfo.name = descriptor.name;
        * cast(T*) nodeInfo.value.ptr = descriptor.getter()();
        //
        return;
    }
    
    // arrays types
    else static if (isSerArrayType!T)
    {
        T value = descriptor.getter()();
        //
        nodeInfo.type = text2type[getElemStringOf!T];
        nodeInfo.isArray = true;
        nodeInfo.descriptor = cast(izPtr) descriptor;
        nodeInfo.name = descriptor.name;
        nodeInfo.value.length = value.length * type2size[nodeInfo.type];
        memmove(nodeInfo.value.ptr, cast(void*) value.ptr, nodeInfo.value.length);
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
        nodeInfo.name = descriptor.name;
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
        //!\ generate all the possible instance /!\
        void setDescriptor(T)(izPropDescriptor!T * descriptor)
        {
            if(descriptor)
                setNodeInfo!T(&fNodeInfo, descriptor);
        }
        izSerNodeInfo * nodeInfo()
        {
            return &fNodeInfo;
        }   
    }
}

// format reader/writer template -----------------------------------------------
private class izSerWriter
{
    protected
    {
        izIstNode fNode; 
        izStream fStream; 
    }
    public
    {
        this(izIstNode istNode, izStream stream)
        {
            fNode = istNode;
            fStream = stream;
        }
        abstract void writeObjectBeg();
        abstract void writeObjectEnd();
        //!\ endianism /!\
        abstract void writeProp();
    }  
}

private class izSerReader
{
    protected
    {
        izIstNode fNode; 
        izStream fStream; 
    }
    public
    {
        this(izIstNode istNode, izStream stream)
        {
            fNode = istNode;
            fStream = stream;
        }
        abstract bool readObjectBeg();
        abstract bool readObjectEnd();
        //!\ endianism /!\
        abstract void readProp();
    }  
}

// Text format -----------------------------------------------------------------
private final class izSerTextWriter : izSerWriter 
{
    this(izIstNode istNode, izStream stream)
    {super(istNode, stream);}
    final override void writeObjectBeg(){}
    final override void writeObjectEnd(){}
    final override void writeProp()
    {
        char separator = ' ';
        // indentation
        char tabulation = '\t';
        foreach(i; 0 .. fNode.level)
            fStream.write(&tabulation, tabulation.sizeof);
        // type
        char[] type = type2text[fNode.nodeInfo.type].dup;
        fStream.write(type.ptr, type.length);
        // array
        char[2] arr = "[]";
        if (fNode.nodeInfo.isArray) fStream.write(arr.ptr, arr.length); 
        fStream.write(&separator, separator.sizeof);
        // name
        char[] name = fNode.nodeInfo.name.dup;
        fStream.write(name.ptr, name.length);
        fStream.write(&separator, separator.sizeof);
        // name value separators
        char[] name_value = " = \"".dup;
        fStream.write(name_value.ptr, name_value.length);
        // value
        char[] classname = value2text(fNode.nodeInfo); // add_dqe
        fStream.write(classname.ptr, classname.length);
        char[] eol = "\"\n".dup;
        fStream.write(eol.ptr, eol.length);
    }  
}

private final class izSerTextReader : izSerReader
{
    this(izIstNode istNode, izStream stream){super(istNode, stream);}
    final override bool readObjectBeg(){return false;}
    final override bool readObjectEnd(){return false;}
    final override void readProp()
    {
        size_t i;
        char[] identifier;
        char reader;   
        // cache the property
        char[] propText;
        char[2] eop;
        auto initPos = fStream.position;
        while((eop != "\"\n") & (fStream.position != fStream.size)) 
        {
            fStream.read(eop.ptr, 2);
            fStream.position = fStream.position -1;
        }
        auto endPos = fStream.position;
        propText.length = cast(ptrdiff_t)(endPos - initPos);
        fStream.position = initPos;
        fStream.read(propText.ptr, propText.length);
        fStream.position = endPos + 1;
            
        // level
        i = 0;
        while (propText[i] == '\t') i++;
        fNode.nodeInfo.level = i;
        
        // type
        identifier = identifier.init;
        while(propText[i] != ' ') 
            identifier ~= propText[i++];
        char[2] arr;
        if (identifier.length > 2) 
        {
            arr = identifier[$-2 .. $];
            fNode.nodeInfo.isArray = (arr == "[]");
        }
        if (fNode.nodeInfo.isArray) 
            identifier = identifier[0 .. $-2];
        if (identifier in text2type) 
            fNode.nodeInfo.type = text2type[identifier];
             
        // name
        i++;
        identifier = identifier.init;
        while(propText[i] != ' ') 
            identifier ~= propText[i++];
        fNode.nodeInfo.name = identifier; 
        
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
        fNode.nodeInfo.value = text2value(identifier, fNode.nodeInfo.type, fNode.nodeInfo.isArray);
    }  
}

// Binary format ---------------------------------------------------------------
private final class izSerBinaryWriter : izSerWriter 
{
    this(izIstNode istNode, izStream stream)
    {super(istNode, stream);}
    final override void writeObjectBeg(){}
    final override void writeObjectEnd(){}
    final override void writeProp(){}  
}

private final class izSerBinaryReader : izSerReader
{
    this(izIstNode istNode, izStream stream)
    {super(istNode, stream);}
    final override bool readObjectBeg(){return false;}
    final override bool readObjectEnd(){return false;}
    final override void readProp(){}  
}

// High end serializer ---------------------------------------------------------
public enum izSerState
{
    none,
    store,      /// from declarator to serializer
    restore     /// from serializer to declarator
}

public enum izStoreMode
{
    sequential, /// store directly after declaration. order is granted. a single property descriptor can be used for several properties. 
    bulk        /// store when eveything is declared. a single property descriptor cannot be used for several properties.
}

public enum izRestoreMode
{
    sequential, /// restore following declaration. order is granted.
    random      /// restore without declaration, or according to a custom query.
}

public enum izSerFormat
{
    binary,
    text
    // OGDL
}

izSerWriter newWriter(P...)(izSerFormat format, P params)
{
    if (format == izSerFormat.binary)
        return construct!izSerBinaryWriter(params);
    else if (format == izSerFormat.text)
        return construct!izSerTextWriter(params);
    assert(false);
}

izSerReader newReader(P...)(izSerFormat format, P params)
{
    if (format == izSerFormat.binary)
        return construct!izSerBinaryReader(params);
    else if (format == izSerFormat.text)
        return construct!izSerTextReader(params);
    assert(false);
}

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
        
        // the izSerializable linked to fRootNode
        izSerializable fRootSerializable;
        // the izSerializable linked to fParentNode
        izSerializable fCurrSerializable;
        
        izSerState fSerState;
        izStoreMode fStoreMode;
        izRestoreMode fRestoreMode;
        izSerFormat fFormat;
        izStream fStream;
        izPropDescriptor!izSerializable fRootDescr;
        
        bool fMustWrite;
        bool fMustRead;
        
        /// prepares the first IST node
        void setRoot(izSerializable root)
        {
            fRootSerializable = root;
            fCurrNode = fRootNode;
            fRootDescr.define(&fRootSerializable, "Root");
            fRootNode.setDescriptor(&fRootDescr);
        }
        
        /// creates a writer object which renders a node into a stream
        void writeNode(izIstNode node)
        {
            auto writer = newWriter(fFormat, fCurrNode, fStream);
            scope(exit) destruct(writer);
            //
            if (isSerObjectType(node.nodeInfo.type))
                writer.writeObjectBeg;
            //
            writer.writeProp;
            // last children closes the branch
            if (!node.nextSibling)
                writer.writeObjectEnd;
        }

        /// IST -> declarator
        void readNode(izIstNode node)
        {
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
              
  
//---- serialization -----------------------------------------------------------  
        
        /** 
         * Builds the IST from an izSerializable, 1st serialization phase.
         * declarator -> IST
         */
        void buildIST(izSerializable root)
        {
            fStoreMode = izStoreMode.bulk;
            fRootNode.deleteChildren;
            setRoot(root);
            fCurrSerializable = fRootSerializable;
            fParentNode = fRootNode;
            fCurrNode = fRootNode;
            fMustWrite = false;
            fCurrSerializable.declareProperties(this);
        }
        
        /** 
         * Builds the IST from an izSerializable and store sequentially, merged serialization phases.
         * declarator -> IST -> stream
         */
        void buildAndStoreIST(izSerializable root, izStream outputStream, izSerFormat format)
        {
            fFormat = format;
            fStream = outputStream;
            fStoreMode = izStoreMode.sequential;
            fMustWrite = true;
            //
            fRootNode.deleteChildren;
            setRoot(root);
            fCurrSerializable = fRootSerializable;
            fCurrNode = fRootNode;
            writeNode(fCurrNode);
            //
            fParentNode = fRootNode;
            fCurrSerializable.declareProperties(this);
            fMustWrite = false;
        }
        
        /** 
         * Saves the IST to outputStream, bulk, 2nd serialization phase.
         * IST -> stream
         */
        void saveIST(izStream outputStream, izSerFormat format)
        {
            fStoreMode = izStoreMode.bulk;
            fStream = outputStream;
            fFormat = format;
            fMustWrite = true;
            //
            void writeNodesFrom(izIstNode parent)
            {
                writeNode(parent);
                for (auto i = 0; i < parent.childrenCount; i++)
                {
                    auto child = cast(izIstNode) parent.children[i];
                    
                    if (isSerObjectType(child.nodeInfo.type))
                        writeNodesFrom(child);
                    else
                        writeNode(child);
                }
            }
            writeNodesFrom(fRootNode);
            fMustWrite = false;
        }
        
        
        
//---- deserialization ---------------------------------------------------------         
            
        /**
         * Builds the IST from a stream, 1st deserialization phase.
         * stream -> IST
         */
        void buildIST(izStream inputStream, izSerFormat format)
        {
            izIstNode[] unorderNodes;
            izIstNode oldParent;
            izIstNode[] parents;
            fRootNode.deleteChildren;
            fCurrNode = fRootNode;
            fMustRead = false;
            while(inputStream.position < inputStream.size)
            {
                unorderNodes ~= fCurrNode;      
                auto reader = newReader(format, fCurrNode, inputStream);
                reader.readProp;
                std.stdio.writeln( *fCurrNode.nodeInfo );
                fCurrNode = new izIstNode;
                
            }
            
            parents ~= fRootNode;
            foreach(i; 1 .. unorderNodes.length)
            {
                auto node = unorderNodes[i];
                parents[$-1].addChild(node);
                if (isSerObjectType(node.nodeInfo.type))
                    parents ~= node;
                if (node.nodeInfo.isLastChild) // isLastChild is not yet set.
                    parents.length = parents.length-1; 
                
            }
            
        }
        
        /** 
         * Builds the IST from a stream and restore sequentially to rootObject, merged deserialization phases, the declarations lead the process.
         * stream -> IST -> declarator
         */
        void buildAndRestoreIST(izSerializable root, izStream inputStream, izSerFormat format)
        {
            fSerState = izSerState.restore;
            fRestoreMode = izRestoreMode.sequential;
            fMustRead = true;
            fRootNode.deleteChildren;
            setRoot(root);
            fCurrSerializable = fRootSerializable;
            fCurrSerializable.declareProperties(this);        
        }   
        
        /**
         * Restores sequentially from the IST to root, 2nd deserialization phase, the declarations lead the the process.
         * IST -> declarator
         */
        void restoreIST(izSerializable root)   
        {
            fSerState = izSerState.restore;
            fRestoreMode = izRestoreMode.sequential;
            fMustRead = true;
            fRootNode.deleteChildren;
            setRoot(root);
            fCurrSerializable = fRootSerializable;
            fCurrSerializable.declareProperties(this);
        }    
        
        /// find the node named according to descriptorName, deserialization utility, 2nd phase 
        izIstNode findNode(in char[] descriptorName)
        {
            if (fRootNode.nodeInfo.name == descriptorName)
                return fRootNode;
            
            izIstNode scanNode(izIstNode parent, in char[] namePipe)
            {
                izIstNode result;
                for(auto i = 0; i < parent.childrenCount; i++)
                {
                    auto child = cast(izIstNode) parent.children[i]; 
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
        
        /// restores the IST from node in rootObject. node can be determined by a call to findNode(), partial deserialization, 2nd phase  
        void restoreFromNode(izIstNode node, izSerializable rootObject, bool recursive = false)
        {
            fMustRead = true;
            fSerState = izSerState.restore;
            fRestoreMode = izRestoreMode.sequential;
        }
        
        ///restores the single property from node using aDescriptor setter. node can be determined by a call to findNode(), partial deserialization, 2nd phase
        void restoreProperty(T)(izIstNode node, izPropDescriptor!T * aDescriptor)
        {
            fMustRead = true;
            fSerState = izSerState.restore;
            fRestoreMode = izRestoreMode.random;
        }        
    

    
//---- declaration from an izSerializable --------------------------------------    
    
    
        mixin(genAllAdders);
        
        /// an izSerializable declare a property descibed by aDescriptor
        void addProperty(T)(izPropDescriptor!T * aDescriptor)
        {
            
            fCurrNode = fParentNode.addNewChildren!izIstNode;
            fCurrNode.setDescriptor(aDescriptor);
            
            if (fMustWrite && fStoreMode == izStoreMode.sequential)
                writeNode(fCurrNode); 
                
            if (fMustRead)
                readNode(fCurrNode);
            
            static if (isSerObjectType!T)
            {
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
        }
        
        /// state is set visible to an izSerializable to let it know how the properties will be used (store: getter, restore: setter)
        izSerState state() {return fSerState;}
        
        /// storeMode is set visible to an izSerializable to let it adjust the way to declare the properties. 
        izStoreMode storeMode() {return fStoreMode;}
        
        /// restoreMode is set visible to an izSerializable to let it adjust the way to declare the properties. 
        izRestoreMode restoreMode() {return fRestoreMode;}
         
        /// serializationFormat is set visible to an izSerializable to let it adjust the way to declare the properties. 
        izSerFormat serializationFormat() {return fFormat;} 
        
        /// The IST can be modified, build, cleaned from the root node
        izIstNode serializationTree(){return fRootNode;}
    }
    
}

private template genAllAdders()
{
    char[] genAllAdders()
    {
        char[] result;
        foreach(t; izSerTypeTuple) if (!(is(t  == struct)))
            result ~= "alias add" ~ t.stringof ~ "Property =" ~ "addProperty!" ~ t.stringof ~";"; 
        return result;
    }
}

version(devnewser)
void main()
{
    import std.stdio;
    writeln(type2text);
    writeln(text2type);
    writeln(type2size);
    
    izSerNodeInfo inf;
    uint a = 8;
    float[] b = [0.1f, 0.2f];
    int[2] c = [1,2];
    
    
    class D: izSerializable
    {
        void declareProperties(izSerializer serializer){}
        string className(){return "DEF";} // 68..70
    }
    auto d = new D;
    
    auto aDescr = izPropDescriptor!uint(&a, "prop_a");
    setNodeInfo!uint(&inf, &aDescr);
    writeln(inf);
    
    auto bDescr = izPropDescriptor!(float[])(&b, "prop_b");
    setNodeInfo!(float[])(&inf, &bDescr);
    writeln(inf);    
    
    auto cDescr = izPropDescriptor!(int[2])(&c, "prop_c");
    setNodeInfo!(int[2])(&inf, &cDescr);
    writeln(inf);    
    
    izSerializable asSer = cast(izSerializable) d;
    auto dDescr = izPropDescriptor!izSerializable(&asSer, "prop_d");
    setNodeInfo!izSerializable(&inf, &dDescr);
    writeln(inf);  
    
    Object e =  d;
    auto eDescr = izPropDescriptor!Object(&e, "prop_e");
    setNodeInfo!Object(&inf, &eDescr);
    writeln(inf);
    
     
    class classA : izSerializable
    {
        private:
            izPropDescriptor!uint aDescr;
            izPropDescriptor!uint bDescr;
            uint a;
            uint b;
        public:
            this()
            {
                a = 512;
                b = 1024;
                aDescr.define(&a, "property_a");
                bDescr.define(&b, "property_b");
            }
            string className(){return "classA";}
	        void declareProperties(izSerializer aSerializer)
            {
                aSerializer.addProperty(&aDescr);
                aSerializer.addProperty(&bDescr);
            }
    }
    
    class classB : classA
    {
        private
        {
            float[] e;
            classA c, d;
            izSerializable ciz, diz;
            izPropDescriptor!izSerializable cDescr;
            izPropDescriptor!Object dDescr;
            izPropDescriptor!(float[]) eDescr;
        }
        this()
        {
            a = 88;
            b = 99;
            c = new classA;
            d = new classA;
            e = [0.1f,0.2f];
            ciz = cast(izSerializable) c;
            diz = cast(izSerializable) d;
            cDescr.define(&ciz, "property_c");
            dDescr.define(cast(Object*)&d, "property_d");
            eDescr.define(&e, "property_e");
        }
        override string className(){return "classB";}
	    override void declareProperties(izSerializer aSerializer)
        {
            super.declareProperties(aSerializer);
            aSerializer.addProperty(&cDescr);
            aSerializer.addProperty(&dDescr);
            aSerializer.addProperty(&eDescr);
        }
    }
    
    izMemoryStream str = new izMemoryStream;
    izSerializer ser = new izSerializer;
    auto bc = new classB;
    
    ser.buildAndStoreIST(bc, str, izSerFormat.text);
    str.saveToFile("newser.txt");
    
    auto treeStr = new izMemoryStream;
    ser.serializationTree.saveToStream(treeStr);
    treeStr.saveToFile("NativeTreeItems.txt");
    delete treeStr;
    
    
    writeln( ser.findNode("Root.property_c.property_a"));
    writeln( ser.findNode("Root.property_e"));
    writeln( ser.findNode("Root.property_e.nil"));
    writeln( ser.findNode("Root.property_d.property_b"));
    writeln( ser.findNode("Root.property_e."));
    writeln( ser.findNode("Root"));
    
    str.position = 0;
    ser.buildIST(str, izSerFormat.text);
    
    delete str;
    delete ser;
        
}