module iz.temp;

import std.stdio, std.typetuple, std.conv, std.traits;
import iz.types, iz.properties, iz.containers, iz.streams;

// Serializable types ----------------------------------------------------------
public interface izSerializable
{
    string className();
	void declareProperties(izSerializer aSerializer);
}
// TODO-cfeature: serializable structures, using isCompatible()/delegatedInterface

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

static bool isSerObjectType(izSerType type)
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
    ubyte[] t2v(T)(){
        if (!isArray) return t2v_1!T; else return t2v_2!T;
    }
    //    
    final switch(type)
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

private izSerWriter newWriter(P...)(izSerFormat format, P params)
{
    with(izSerFormat) final switch(format) {
        case binary: return construct!izSerBinaryWriter(params);
        case text:   return construct!izSerTextWriter(params);   
    }
}

private izSerReader newReader(P...)(izSerFormat format, P params)
{
    with(izSerFormat) final switch(format) {
        case binary: return construct!izSerBinaryReader(params);
        case text:   return construct!izSerTextReader(params);   
    }
}
/*

Features:

 - flexible because based on an intermediate, in-memory, tree representation, aka the "IST"
 - serialize object, according to its declaration
 - deserialize object, according to its declaration
 - convert serialized stream to another format without the declarations
 - object randomly restores some properties, without using declarations
 
 - not based on compile time traits: 
    - properties can be renamed and reloaded even from an obsolete stream (renamed field, renamed option)
    - properties to be saved or reloaded can be arbitrarly chosen at run-time    
    
 - in case of errors in sequential restoration the process can be finished manually.

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
        
        // IST -> stream
        void writeNode(izIstNode node)
        in 
        {
            assert(fStream);
            assert(node);
        }
        body
        {
            auto writer = newWriter(fFormat, node, fStream);
            scope(exit) destruct(writer);
            //
            if (isSerObjectType(node.nodeInfo.type))
                writer.writeObjectBeg;
            writer.writeProp;
            if (!node.nextSibling) writer.writeObjectEnd;
        }

        // stream -> IST
        void readNode(izIstNode node)
        in 
        {
            assert(fStream);
            assert(node);
        }
        body
        {
            auto reader = newReader(fFormat, node, fStream);
            scope(exit) destruct(reader);
            //
            if (isSerObjectType(node.nodeInfo.type))
                reader.readObjectBeg;            
            reader.readProp;
            if (!node.nextSibling) reader.readObjectEnd;
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
         * Builds the IST from an izSerializable and store sequentially, merged serialization phases.
         * declarator -> IST -> stream
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
            writeNode(fCurrNode);
            //
            fParentNode = fRootNode;
            fCurrSerializable.declareProperties(this);
            //
            fMustWrite = false;
            fSerState = izSerState.none;
            fStream = null;
        }
        
        /** 
         * Saves the IST to outputStream, bulk, 2nd serialization phase.
         * IST -> stream
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
                writeNode(parent);
                for (auto i = 0; i < parent.childrenCount; i++)
                {
                    auto child = cast(izIstNode) parent.children[i];           
                    if (isSerObjectType(child.nodeInfo.type))
                        writeNodesFrom(child);
                    else writeNode(child);
                }
            }
            writeNodesFrom(fRootNode);
            //
            fMustWrite = false;
            fStream = null;
        }
               
//---- deserialization ---------------------------------------------------------         
            
        /**
         * Builds the IST from a stream, 1st deserialization phase. 
         * The IST nodes are not linked to a declarator.
         * stream -> IST
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
                readNode(fCurrNode);
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
         * Builds the IST from a stream and restore sequentially to root, 
         * merged deserialization phases, the declarations lead the process.
         * stream -> IST -> declarator
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
            readNode(fCurrNode);
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
         * Restores sequentially from the IST to root, 2nd deserialization phase, 
         * the declarations lead the the process.
         * IST -> declarator
         */
        void istToObject(izSerializable root, izSerFormat format)   
        {
            //TODO-cfeature : restoreIST().
            
            /*
                IST nodes don't always have a descriptor in their infos.
                for example after a call to buildIST.
            */ 
        }    
        
        /**
         * Finds the node named according to descriptorName.
         * Deserialization utility, 2nd phase.
         */ 
        izIstNode findNode(in char[] descriptorName)
        {
        
            //TODO-cfeature : optimize random access by caching in an AA, "à la JSON"
            
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
        void istToObject(izIstNode node, izSerializable root, bool recursive = false)
        {
            //TODO-cfeature : restoreFromNode().
        }
        
        ///restores the single property from node using aDescriptor setter. node can be determined by a call to findNode(), partial deserialization, 2nd phase
        void restoreProperty(T)(izIstNode node, izPropDescriptor!T * aDescriptor)
        {
            fSerState = izSerState.restore;
            fRestoreMode = izRestoreMode.random;
            node.nodeInfo.descriptor = aDescriptor;
            nodeInfo2Declarator(node.nodeInfo); 
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
                
            if (fMustRead) {
                readNode(fCurrNode);
                nodeInfo2Declarator(fCurrNode.nodeInfo);
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

private static string genAllAdders()
{
    string result;
    foreach(t; izSerTypeTuple) if (!(is(t  == struct)))
        result ~= "alias add" ~ t.stringof ~ "Property =" ~ "addProperty!" ~ t.stringof ~";"; 
    return result;
}

version(devnewser)
void main()
{
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
            void clear(){reset(a); reset(b);}
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
        override void clear(){super.clear; c.clear; d.clear; reset(e);}
    }
    
    auto str = construct!izMemoryStream;
    auto ser = construct!izSerializer;
    auto bc  = construct!classB;
    scope(exit) destruct(str, ser, bc);
    
// sequential ser --------------------------------------------------------------      
    
    ser.objectToStream(bc, str, izSerFormat.text);
    str.saveToFile("serialized_sequential.txt");
    
// find node ----------------------    
    
    writeln( ser.findNode("Root.property_c.property_a"));
    writeln( ser.findNode("Root.property_e"));
    writeln( ser.findNode("Root.property_e.nil"));
    writeln( ser.findNode("Root.property_d.property_b"));
    writeln( ser.findNode("Root.property_e") !is null);
    writeln( ser.findNode("Root"));
    
// sequential deser ------------------------------------------------------------    
    
    str.position = 0;
    bc.clear;
    writeln( bc.a, " ", bc.b, " ", bc.e, " ",bc.c.a, " ", bc.c.b, " ", bc.d.a, " ", bc.d.b, " ");    
    
    ser.streamToObject(str, bc, izSerFormat.text);
    writeln( bc.a, " ", bc.b, " ", bc.e, " ",bc.c.a, " ", bc.c.b, " ", bc.d.a, " ", bc.d.b, " ");
    
// random deser ----------------------------------------------------------------    
    
    str.position = 0;
    bc.clear;
    writeln( bc.a, " ", bc.b,);    
    
    ser.streamToIst(str, izSerFormat.text);
    
    izIstNode nd;
    nd = ser.findNode("Root.property_a");
    if (nd) ser.restoreProperty(nd, &bc.aDescr);
    nd = ser.findNode("Root.property_b");
    if (nd) ser.restoreProperty(nd, &bc.bDescr);
    nd = ser.findNode("Root.property_e");
    if (nd) ser.restoreProperty(nd, &bc.eDescr);
    
    writeln( bc.a, " ", bc.b, " ", bc.e);
    
// bulk ser --------------------------------------------------------------------

    bc.a = 777;
    bc.b = 888;
    bc.e = [0.111f,0.222f,0.333f,0.444f];
    bc.c.a = 777;
    bc.c.b = 888;
    bc.d.a = 951;
    bc.d.b = 846;

    str.clear;
    ser.objectToIst(bc);
    ser.istToStream(str, izSerFormat.text);
    str.saveToFile("serialized_bulk.txt");
              
}
