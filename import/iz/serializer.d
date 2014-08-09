module iz.serializer;

import
	std.stdio: writeln, writefln;
import
	core.exception, std.traits, std.conv, std.typetuple, std.string, std.array,
    std.algorithm, std.c.stdlib, std.string, std.exception,
	iz.types, iz.containers, iz.properties, iz.streams, iz.referencable;
import
	core.stdc.string: memcpy, memmove;

/**
 * Determines if T can be serialized.
 * Serializable types include:
 * - classes implementing izSerializable.
 * - the members of izConstantSizeTypes.
 * - the members of izConstantSizeTypes when organized in a single-dimension array.
 */
static bool isTypeSerializable(T)()
{
	static if (is(T : izSerializable)) return true;
	else static if (!isArray!T) return (staticIndexOf!(T,izConstantSizeTypes) != -1);
	else static if (isStaticArray!T)
	{
		return (staticIndexOf!(typeof(T.init[0]),izConstantSizeTypes) != -1);
	}
	else static if (isDynamicArray!T)
	{
		T arr;
		return (staticIndexOf!(typeof(arr[0]),izConstantSizeTypes) != -1);
	}
	else return false;
}

unittest
{
	class test1: izSerializable
	{
		void declareProperties(izMasterSerializer aSerializer){}
		void getDescriptor(const unreadProperty infos, out izPtr aDescriptor){}
        string className(){return typeof(this).stringof;}
	}
	static assert(isTypeSerializable!byte);
	static assert(isTypeSerializable!(byte[2]));
	static assert(isTypeSerializable!(ubyte[]));
	static assert(isTypeSerializable!test1);
	static assert(isTypeSerializable!(char[]));
	static assert(!isTypeSerializable!(char[][]));
}

/// Flag used to define the serialization format.
enum izSerializationFormat {
	bin,	/// raw binary format, cf. with izIstNode doc. for a full specification
	text,	/// simple utf8 text, cf. with izIstNode doc. for a full specification
	json,	/// JSON
	xml		/// XML
};


/// Build the IST from a document
class izSerTreeBuilder: izObject
{
    private
    {
        izIstObjectNode fRoot;
        void delegate(izStream aStream)[4] rebuilder;

        void rebuildFromBin(izStream aStream)
        {
            size_t cnt;
            ubyte rdr;
            aStream.read(&rdr, 1);

            do
            {
			    // type
			    ushort typeix;
			    cnt = aStream.read(&typeix, typeix.sizeof);
			    ushort type = 	(typeix & cast(ushort)0x000F);
			    bool isArray = (typeix & cast(ushort)0xFFF0) == 0x0F;
                // creates a node
                switch(typeix)
                {
                    case fixedSerializableTypes.stObject: break;
                    case fixedSerializableTypes.stUnknow: break;
                    case fixedSerializableTypes.stBool: break;
                    case fixedSerializableTypes.stByte: break;
                    default: break;
                }
                while (rdr != 0xB0)
                {
                    cnt = aStream.read(&rdr, 1);
                    if (cnt == 0) break;
                }
            }
            while (cnt != 0);

        }
        void rebuildFromText(izStream aStream)
        {
        }

    }
    public
    {
        this()
        {
            rebuilder[0] = &rebuildFromBin;
            rebuilder[1] = &rebuildFromText;
        }

        izIstObjectNode rebuildIST(izStream aStream, izSerializationFormat aFormat)
        {
            assert(rebuilder[aFormat],"forgot to set the array entry !");
            rebuilder[aFormat](aStream);
            return fRoot;
        }
    }
}

interface izSerializable
{
    /**
     * Used by the izMasterSerializer to determine the type of class implementing
     * izSerializable.
     */
    string className();
	/**
	 * Called by an izMasterSerializer before reading or writing.
	 * The implementer uses this method to declare its properties to aSerializer.
	 */
	void declareProperties(izMasterSerializer aSerializer);
	/**
	 * Called for each unread property by an izMasterSerializer after reading.
	 * This can be used, for example, if since the last serialization, the
	 * declarations have changed (new property name, new order, new type, ...)
	 */
	void getDescriptor(const unreadProperty infos, out izPtr aDescriptor);
}

/**
 * Turns a referenced variable of type RT in a izSerializable.
 * The source must be stored in the referenceMan.
 * A "referenced variable" is typically something that is modified
 * at the run-time, such as the source of a delegate, a pointer to an Object, etc.
 */
class izSerializableReference: izSerializable
{
    private
    {
        char[] fType;
        ulong  fID;
        izPropDescriptor!(char[]) fTypeDescr;
        izPropDescriptor!ulong fIdDescr;
    }
    public
    {
        this()
        {
            fTypeDescr.define(&Type, &Type, "Type");
            fIdDescr.define(&ID, &ID, "ID");
        }

        /**
         * Sets the internal fields according to aReferenced.
         * Usually called before the serialization.
         */
        void storeReference(RT)(RT* aReferenced)
        {
            fType = RT.stringof.dup;
            fID = referenceMan.referenceID!RT(aReferenced);
        }

        /**
         * Sets aReferenced according to the internal fields.
         * Usually called after the deserialization.
         */
        void restoreReference(RT)(out RT* aReferenced)
        {
            aReferenced = referenceMan.reference!RT(fID);
        }

        mixin(genPropFromField!(char[], "Type", "fType"));
        mixin(genPropFromField!(ulong, "ID", "fID"));
        void getDescriptor(const unreadProperty infos, out izPtr aDescriptor){}
        string className(){return typeof(this).stringof;}
        void declareProperties(izMasterSerializer aSerializer)
        {
            aSerializer.addProperty(fTypeDescr);
            aSerializer.addProperty(fIdDescr);
        }
    }
}

enum fixedSerializableTypes
{
	stObject,
	stUnknow,
	stBool,
	stByte, stUbyte,
	stShort, stUshort,
	stInt, stUint,
	stLong, stUlong,
	stFloat, stDouble,
	stLast
};

/**
 * izSerTypes represents all the fixed-length types, directly representing a data.
 */
 
private alias izSerTypes = TypeTuple!( izSerializable, null,
	bool, byte, ubyte, short, ushort, int, uint, long, ulong,
	char, wchar, dchar, float, double);
	
private immutable string[] izSerTypesString = [ "izSerializable", "unknown",
	"bool", "byte", "ubyte", "short", "ushort", "int", "uint", "long", "ulong",
	"char", "wchar", "dchar", "float", "double"];

private immutable ubyte[] izSerTypesLen =
[
	0, 0, 1, 1, 1, 2, 2, 4, 4, 8, 8,
	1, 2, 4, 4, 8
];

/**
 * unreadProperty contains the informations an izSerializable can
 * use to set an erroneous property.
 */
struct unreadProperty
{
	/// the type.
	ubyte type;
	/// structure
	bool isArray;
	/// value copied in a variable length chunk
	ubyte[] value;
	/// property name
	char[] name;
	/// parent name
	char[] parentName;
	/// parent object
	const izSerializable parent;
}

/**
 * Prepares an izIstNode.
 */
class izPreIstNode: izObject, izTreeItem
{
	mixin izTreeItemAccessors;
	abstract void write(izStream aStream, izSerializationFormat aFormat);
	abstract void read(izStream aStream, izSerializationFormat aFormat);
	abstract void restore();
}

/**
 * Element of the Intermediate Serialization Tree (IST).
 * Represents a single property which it's able to write to various formats.
 */
class izIstNode(T): izPreIstNode if(isTypeSerializable!T)
{
	private
	{
		alias void delegate (izStream aStream) rwProc;

		rwProc[4] readFormat;
		rwProc[4] writeFormat;

		unreadProperty uprop;
		izPropDescriptor!T fDescriptor;
		izSerializable fDeclarator;

		bool fIsRead;

		/*
			bin format:

			-------------------------------------------------------------------
			byte	|	type	|	description
			-------------------------------------------------------------------
			0		|	byte	|	property header, always 0x99
			1		|	byte	|	type (index in 'izSerTypes')
			2		|	byte	|	organized in array if 1.
			3		|	ushort	|	length of the property name (X)
			4		|	...		|
			5		|	ubyte[]	|   property name
			...		|	...		|
            ...		|	...		|
			5+X		|	uint	|	length of the property value (Y)
			...		|			|
			...		|			|
			...		|			|
			9+X		|	ubyte[]	|	property value.
			...		|			|
			...		|			|
			...		|			|
			9+X+Y	|	byte	|	property footer, always '0xA0'	.
			10+X+Y	|	byte	|	optional footer for object end, '0xB0'.
		*/
		void writeBin(izStream aStream)
		{
			// header
			ubyte symbol = 0x99;
			aStream.write(&symbol, symbol.sizeof);

			// type
			ubyte tp = 0, ar = 0;
			static if (!is(T == izSerializable))
			{
				T arr;
                static if (isArray!T)
                {
                    ar = 1;
				    static if (isStaticArray!T)
                        tp = cast(ubyte)countUntil(izSerTypesString, typeof(T.init[0]).stringof);
				    else static if (isDynamicArray!T)
                        tp = cast(ubyte)countUntil(izSerTypesString, typeof(arr[0]).stringof);
                }
                else
                {
                    tp = cast(ubyte)(countUntil(izSerTypesString, T.stringof));
                }
			}
			aStream.write(&tp, tp.sizeof);
            aStream.write(&ar, ar.sizeof);

			//name length
			ushort namelen = cast(ushort) fDescriptor.name.length;
			aStream.write(&namelen, namelen.sizeof);

            // name...
			char[] namecpy = fDescriptor.name.dup;
			aStream.write(namecpy.ptr, namecpy.length);

			// value length + value...
			static if (!is(T == izSerializable))
			{
				T value = fDescriptor.getter()();
				static if(!isArray!T)
                {
                    uint valuelen = value.sizeof;
                    aStream.write(&valuelen, valuelen.sizeof);
                    aStream.write(&value, valuelen);
                }
				else
				{
					uint valuelen = 0;
					static if (isStaticArray!T) valuelen = cast(uint) (typeof(T.init[0]).sizeof * value.length);
					static if (isDynamicArray!T) valuelen = cast(uint) (typeof(arr[0]).sizeof * value.length);
                    aStream.write(&valuelen, valuelen.sizeof);
					aStream.write(value.ptr, valuelen);
				}
			}
            else
            {
                char[] value = (cast(T)fDescriptor.getter()()).className.dup;
                uint valuelen = cast(uint) value.length;
                aStream.write(&valuelen, valuelen.sizeof);
				aStream.write(value.ptr, valuelen);
            }

			// footer
			symbol = 0xA0;
			aStream.write(&symbol, symbol.sizeof);
		}

		void readBin(izStream aStream)
		{
			size_t cnt;
			auto headerpos = aStream.position;
			ulong footerPos;
			// header
			ubyte symbol;
			cnt = aStream.read(&symbol, symbol.sizeof);

            // type
			ubyte ar;
			cnt = aStream.read(&uprop.type, uprop.type.sizeof);
            cnt = aStream.read(&ar, ar.sizeof);
			uprop.isArray = ar == 1;

            //name length
			ushort namelen;
			cnt = aStream.read(&namelen, namelen.sizeof);

			// name...
			uprop.name.length = namelen;
			cnt = aStream.read(uprop.name.ptr, namelen);

            // value len
            uint valuelen;
            cnt = aStream.read(&valuelen, valuelen.sizeof);

			// value...
            uprop.value.length = valuelen;
            cnt = aStream.read(uprop.value.ptr, valuelen);

			// footer
			cnt = aStream.read(&symbol, symbol.sizeof);
		}

		/*
			text format:

			<level times TAB>Type<space>PropertyName<space(s)>=<space(s)>"PropertyValue"<CR/LF or LF only after '"' count%2 == 0>

		*/
		void writeText(izStream aStream)
		{
			char[] tabstring(char[] astr)
			{
				char[] trans1, result;
				trans1.length = level + 3;
				trans1[0] = '\r';
				trans1[1] = '\n';
				trans1[2..$] = '\t';
				auto trans2 = trans1[1..$];
				result = replace(astr, "\r\n", trans1);
				result = replace(result, "\n", trans2);
				return result;
			}

			char[] data;
			ubyte mark = 0x09;

			// tabulations
			for (auto i = 0; i < level; i++)
			{
				aStream.write(&mark,mark.sizeof);
			}

			// type
			data = T.stringof.dup;
			aStream.write(data.ptr,data.length);
			mark = 0x20;
			aStream.write(&mark,mark.sizeof);

			// name;
			data = fDescriptor.name.dup;
			aStream.write(data.ptr,data.length);

			// name = value;
			data = " = \"".dup;
			aStream.write(data.ptr,data.length);

			// value
			static if (!is(T == izSerializable))
			{
                // http://forum.dlang.org/thread/ipepszxjboblskllwvlv@forum.dlang.org
                auto val = fDescriptor.getter()();

				data = to!(string)( val ).dup;
				if (is(T==char[])) data = tabstring(data);
				aStream.write(data.ptr,data.length);
			}
            else
            {
                char[] value = (cast(T)fDescriptor.getter()()).className.dup;
				aStream.write(value.ptr, value.length);
            }

			// close double quotes + EOL
			data = "\"\r\n".dup;
			aStream.write(data.ptr,data.length);
		}

		void readText(izStream aStream)
		{
			// removes the TAB added for the document readability
			char[] detabstring(char[] astr)
			{
				char[] trans1, result;
				trans1.length = level + 3;
				trans1[0] = '\r';
				trans1[1] = '\n';
				trans1[2..$] = '\t';
				auto trans2 = trans1[1..$];
				result = replace(astr, trans1, "\r\n");
				result = replace(result, trans2, "\n");
				return result;
			}

			// copy a full property in a string
			char[] fullProp;
			size_t readIx = 0;
			ubyte head = 0;
			size_t quoteCount = 0;

			auto posStore = aStream.position;
			while(aStream.position < aStream.size)
			{
				aStream.read(&head,head.sizeof);
				readIx++;
				if (head == '"')
					quoteCount++;
				if ((head == 0x0A) & (quoteCount%2 == 0) & (quoteCount>0))
					break;
			}

			aStream.position = posStore;
			fullProp.length = readIx;
			aStream.read(fullProp.ptr, readIx);
			readIx = 0;

			// detab the prop level
			head = 0x09;
			size_t tbsCount = 0;
			while(head == 0x09)
			{
				head = fullProp[readIx];
				readIx++;
			}
			tbsCount = readIx-1;

			// property type
			head = 0;
			while(head != 0x20)
			{
				head = fullProp[readIx];
				readIx++;
			}
			auto propType = fullProp[tbsCount..readIx-1];
			posStore = readIx;

			// property name
			head = 0;
			while((head != 0x20) & (head != '='))
			{
				head = fullProp[readIx];
				readIx++;
			}
			auto propName = fullProp[cast(size_t)posStore..readIx-1].dup;

			// skip spaces and equal symbol
			head = 0;
			while(head != '"')
			{
				head = fullProp[readIx];
				readIx++;
			}
			posStore = readIx;

			// last double quote.
			head = 0;
			readIx = fullProp.length;
			while(head != '"')
			{
				readIx--; // " inside string are included as it starts from the end.
				head = fullProp[readIx];
			}
			// property value
			auto propValue = fullProp[cast(size_t)posStore..readIx];
			
			// unread prop
			
			uprop.isArray = (propType[$-2..$] == "[]" ) ;
				
			if (!uprop.isArray) uprop.type = cast(ubyte)
				countUntil( izSerTypesString, propType[0..$]);
			else uprop.type = cast(ubyte)
				countUntil( izSerTypesString, propType[0..$-2]);
				
			T value;
			static if (!is(T==izSerializable))
			    value = to!T(propValue);

			static if (!is(T==izSerializable))
            {
			    static if (!isArray!T) //if (!uprop.isArray)
			    {
				    uprop.value.length = izSerTypesLen[uprop.type];
				    *cast(T*) uprop.value.ptr = value;
			    }
                else static if (isArray!T)
                {
                    if (value.length > 0)
                    {
                        uprop.value.length = value.length * value[0].sizeof;
                        memmove(uprop.value.ptr, value.ptr, uprop.value.length);
                    }
                    else uprop.value.length = 0;
                }
            }
				
			uprop.name = propName;

			//static if (!is(T==izSerializable)) if (!uprop.isArray) 
			//writeln(uprop.name, " ", izSerTypesString[uprop.type], " ", *cast(T*)uprop.value.ptr );


		}
	}
	protected
	{
		override void write(izStream aStream, izSerializationFormat aFormat)
		{
			fIsRead = false;
            assert(writeFormat[aFormat], "forgot to set the array entry !");
			writeFormat[aFormat](aStream);
			if ( is(T == izSerializable))
			{
				for(auto i = 0; i < childrenCount; i++)
					(cast(izPreIstNode) children[i]).write(aStream,aFormat);

				switch(aFormat)
				{
					case izSerializationFormat.bin:
						ubyte mark = 0xB0;
						aStream.write(&mark, mark.sizeof);
						break;
					default:
						break;
				}
			}
		}
		override void read(izStream aStream, izSerializationFormat aFormat)
		{
            assert(readFormat[aFormat], "forgot to set the array entry !");
			readFormat[aFormat](aStream);
			if ( is(T == izSerializable))
			{
				for(auto i = 0; i < childrenCount; i++)
					(cast(izPreIstNode) children[i]).read(aStream,aFormat);

				switch(aFormat)
				{
					case izSerializationFormat.bin:
						ubyte mark = 0x00;
						aStream.read(&mark, mark.sizeof);
						assert(mark == 0xB0);
						break;
					default:
						break;
				}
			}
		}
		override void restore()
		{
			fIsRead = false;
			scope(success) fIsRead = true;

			if (!is(T == izSerializable))
			{
				static if(!isArray!T)
				{
					fDescriptor.setter()( *cast(T*) uprop.value.ptr );
				}
				else
				{
					T arr;
					size_t elemSz = 0;
					static if (isStaticArray!T) elemSz = typeof(T.init[0]).sizeof;
					static if (isDynamicArray!T) 
					{
						elemSz = typeof(arr[0]).sizeof;
						arr.length = uprop.value.length / elemSz;
					}
					assert(elemSz);
					memmove(arr.ptr, uprop.value.ptr, uprop.value.length);
					fDescriptor.setter()(arr);
				}
			}
			else
			{
				for(auto i = 0; i < childrenCount; i++)
					(cast(izPreIstNode) children[i]).restore();
			}
		}
	}
	public
	{
		this()
		{
			readFormat = [&readBin, &readText, null, null];
			writeFormat = [&writeBin, &writeText, null, null];
		}

		/**
		 * Defines the descriptor and the parentObject.
		 */
		void setSource(izSerializable aSerializable, ref izPropDescriptor!T aDescriptor)
		in
        {
            assert(aSerializable);
        }
		body
		{
			fDescriptor = aDescriptor;
			fDeclarator = aSerializable;
		}

		/**
		 * Returns the property descriptor linked to this tree item.
		 */
		@property izPropDescriptor!T descriptor(){return fDescriptor;}

		/**
		 * Returns the izSerializable Object which declared descriptor.
		 */
		@property izSerializable parentObject(){ return fDeclarator; }

		/**
		 * Returns true if the items has been read.
		 */
		@property const(bool) isRead(){ return fIsRead; }
	}
}

/**
 * IST element representing a serializable sub object.
 */
alias izIstNode!izSerializable izIstObjectNode;

/**
 * Flag used to describe the state of an izMasterSerializer.
 */
enum izSerializationState
{
	none, 		/// the izMasterSerializer does nothing.
	reading,	/// the izMasterSerializer is reading from an izSerializable
	writing		/// the izMasterSerializer is writing to an izSerializable
};

/**
 * Handles the de/serialization of tree of izSerializable objects.
 */
class izMasterSerializer: izObject
{
	private
	{
		izIstObjectNode fRoot;
		izIstObjectNode fCurNode;
		izSerializable fObj;
		izStream fStream;
		izSerializationState fState;
		izSerializationFormat fFormat;
	}
	public
	{
		this()
		{
			fRoot = new izIstObjectNode;
		}

		~this()
		{
			fRoot.deleteChildren;
			delete fRoot;
		}

		/**
		 * Serializes aRoot in aStream.
		 */
		void serialize(izSerializable aRoot, izStream aStream, izSerializationFormat aFormat = izSerializationFormat.bin)
		in
		{
			assert(aRoot);
			assert(aStream);
		}
		body
		{
            fFormat = aFormat;
			fState = izSerializationState.reading;
			scope(exit) fState = izSerializationState.none;

			fStream = aStream;
			fRoot.deleteChildren;
			fCurNode = fRoot;
			fObj = aRoot;
			auto rootDescr = izPropDescriptor!izSerializable(&fObj, "Root");
			fRoot.setSource(fObj, rootDescr);
			fObj.declareProperties(this);
			fRoot.write(fStream,fFormat);
		}

		/**
		 * De-serializes aStream to aRoot.
		 */
		void deserialize(izSerializable aRoot, izStream aStream, izSerializationFormat aFormat = izSerializationFormat.bin)
		in
		{
			assert(aRoot);
			assert(aStream);
		}
		body
		{
            fFormat = aFormat;
			fState = izSerializationState.writing;
			scope(exit) fState = izSerializationState.none;
			fStream = aStream;
			fRoot.deleteChildren;
			fCurNode = fRoot;
			fObj = aRoot;
			auto rootDescr = izPropDescriptor!izSerializable(&fObj, "Root");
			fRoot.setSource(fObj, rootDescr);
			fObj.declareProperties(this);
			fRoot.read(fStream,fFormat);
			fRoot.restore();
		}

		/**
		 * writes the IST to a stream. To be used for converting an existing document.
		 */
		void serialize(izStream aStream)
		in
		{
			assert(aStream);
		}
		body
		{
			fState = izSerializationState.reading;
			scope(exit) fState = izSerializationState.none;
		}

		/**
		 * Builds the IST from a stream. To be used for converting an existing document.
		 */
		void deserialize(izStream aStream)
		in
		{
			assert(aStream);
		}
		body
		{
			fState = izSerializationState.writing;
			scope(exit) fState = izSerializationState.none;
            // TODO
            auto bld = new izSerTreeBuilder;
            delete fRoot;
            fRoot = bld.rebuildIST(aStream, fFormat);
		}

		/**
		 * Called by an izSerializable in its declareProperties implementation.
         * aDescriptor must not be a stack allocated descriptor because the property
         * is neither read or written directly during a call to this function.
         * Writing and reading appends after all the properties are declared.
		 */
		void addProperty(T)(ref izPropDescriptor!T aDescriptor) if(isTypeSerializable!T)
		{
			if (aDescriptor.name == "")
				throw new Error("serializer error, unnamed property descriptor");

			alias izIstNode!T node_t;

			static if (is(T == izSerializable))
			{
				auto istItem = fCurNode.addNewChildren!izIstObjectNode;
				istItem.setSource(fObj, aDescriptor);
				auto old = fCurNode;
				auto oldobj = fObj;
				fCurNode = istItem;
				old.addChild(istItem);
				fObj = aDescriptor.getter()();
				fObj.declareProperties(this);
				fCurNode = old;
				fObj = oldobj;
			}
			else
			{
				auto istItem = fCurNode.addNewChildren!node_t;
				istItem.setSource(fObj, aDescriptor);
				fCurNode.addChild(istItem);
			}
		}

		/**
		 * Informs about the serialization state.
		 */
		@property const(izSerializationState) state(){return fState;}

        /**
		 * Access to the IST.
		 */
        @property izIstObjectNode serializationTree() {return fRoot;}
	}
}

version(unittest)
{

	class foo: izSerializable
	{
		private:
			int fa, fb;
			char[] fc;
            ubyte[] fd;
            ubyte[4] fe;
			izPropDescriptor!int ADescr,BDescr;
			izPropDescriptor!(char[]) CDescr;
            izPropDescriptor!(ubyte[]) DDescr;
            izPropDescriptor!(ubyte[4]) EDescr;
		public:
            mixin(genPropFromField!(int,"A","fa"));
            mixin(genPropFromField!(int,"B","fb"));
            mixin(genPropFromField!(char[],"C","fc"));
            mixin(genPropFromField!(ubyte[],"D","fd"));
			mixin(genPropFromField!(ubyte[4],"E","fe"));
			//
			this()
			{
				ADescr.define(&A,&A,"A");
				BDescr.define(&B,&B,"B");
				CDescr.define(&C,&C,"C");
                DDescr.define(&D,&D,"D");
                EDescr.define(&E,&E,"E");
			}

            void initPublishedMembers()
            {
                A = 0;
		        B = 0;
                C = [];
                D = [];
                E = [0,0,0,0];
            }

			void declareProperties(izMasterSerializer aSerializer)
			{
				aSerializer.addProperty!int(ADescr);
				aSerializer.addProperty!int(BDescr);
                aSerializer.addProperty!(char[])(CDescr);
                aSerializer.addProperty!(ubyte[])(DDescr);
				aSerializer.addProperty!(ubyte[4])(EDescr);
			}
			void getDescriptor(const unreadProperty infos, out izPtr aDescriptor){}
            string className(){return typeof(this).stringof;}
	}
	class bar: foo
	{
		private:
            class baz{}
            baz fb0, fb1;
            baz* fx;
			foo fg;
            izEvent* fEvent;
            izEvent SrcEvent;
            izSerializableReference bazRef;
            izSerializableReference eventRef;
			izPropDescriptor!izSerializable GDescr;
            izPropDescriptor!izSerializable XDescr;
            izPropDescriptor!izSerializable UDescr;
            void anAssignableEvent(izObject aNotifier){writeln("shhhhhhhh...");}
		public:
			@property void NullObjSetter(izSerializable value){}
			@property izSerializable G(){return fg;}
            @property izSerializable X(){return bazRef;}
            @property izSerializable U(){return eventRef;}
			this()
			{
				fg = new foo;
                fb0 = new baz;
                fb1 = new baz;

                referenceMan.storeType!baz;
                referenceMan.storeReference!(baz)(&fb0,498754UL);
                referenceMan.storeReference!(baz)(&fb1,127856UL);
                bazRef = new izSerializableReference;

                SrcEvent = &anAssignableEvent; // this assignment is "pseudo const", used as source because...
                referenceMan.storeType!izEvent;
                referenceMan.storeReference!(izEvent)(&SrcEvent,184369UL); // ...cant pass &&anAssignableEvent
                eventRef = new izSerializableReference;

                GDescr.define(&NullObjSetter, &G, "G");
                XDescr.define(&NullObjSetter, &X, "X");
                UDescr.define(&NullObjSetter, &U, "U");

			}
			~this()
			{
				delete fg;
                delete fb0;
                delete fb1;
                delete eventRef;
                delete bazRef;
			}
			override void declareProperties(izMasterSerializer aSerializer)
			{
                // grab current references: current value to baz/eventref
                if (aSerializer.state == izSerializationState.reading)
                {
                    bazRef.storeReference!baz(fx);
                    eventRef.storeReference!izEvent(fEvent);
                }

				super.declareProperties(aSerializer);
				aSerializer.addProperty!izSerializable(GDescr);
                aSerializer.addProperty!izSerializable(XDescr);
                aSerializer.addProperty!izSerializable(UDescr);

                // restore references: baz/eventref to current values
                if (aSerializer.state == izSerializationState.writing)
                {
                    bazRef.restoreReference!baz(fx);
                    eventRef.restoreReference!izEvent(fEvent);
                }
			}
            override string className(){return typeof(this).stringof;}
	}

	unittest
	{

		auto Bar = new bar;
		auto str = new izMemoryStream;
		auto ser = new izMasterSerializer;

		Bar.A = 8;
		Bar.B = 4;
        Bar.C = "bla".dup;
        Bar.D = [1,2,3];
		Bar.E = [1,2,3,4];
        Bar.fx = &Bar.fb0;
        Bar.fEvent = &Bar.SrcEvent;

		Bar.fg.A = 88;
		Bar.fg.B = 44;
        Bar.fg.C = "bla bla".dup;
        Bar.fg.D = [11,22,33];
		Bar.fg.E = [11,22,33,44];

		scope(exit)
		{
			delete Bar;
			delete ser;
			delete str;
		}

//----bin

		ser.serialize(Bar, str, izSerializationFormat.text);
		str.position = 0;

		str.saveToFile("ser.txt");
        //scope(exit) std.stdio.remove("ser.txt");

        str.position = 0;
		Bar.initPublishedMembers;
        Bar.fg.initPublishedMembers;
        Bar.fx = null;
        Bar.fEvent = null;


		ser.deserialize(Bar, str, izSerializationFormat.text);

		assert( Bar.A == 8);
		assert( Bar.B == 4);
        assert( Bar.C == "bla");
        assert( Bar.D == [1,2,3]);
        assert( Bar.E == [1,2,3,4]);
        assert( Bar.fx == &Bar.fb0);
        assert( Bar.fEvent == &Bar.SrcEvent);

        assert( Bar.fg.A == 88);
		assert( Bar.fg.B == 44);
        assert( Bar.fg.C == "bla bla");
        assert( Bar.fg.D == [11,22,33]);
        assert( Bar.fg.E == [11,22,33,44]);

        writeln( "izSerializer passed the bin format tests");

//----text

        ser.serialize(Bar, str, izSerializationFormat.text);
		str.position = 0;

		str.saveToFile("ser.txt");
        //scope(exit) std.stdio.remove("ser.txt");

        str.position = 0;
		Bar.initPublishedMembers;
        Bar.fg.initPublishedMembers;
        Bar.fx = null;
        Bar.fEvent = null;


		ser.deserialize(Bar, str, izSerializationFormat.text);

		assert( Bar.A == 8);
		assert( Bar.B == 4);
        assert( Bar.C == "bla");
        assert( Bar.D == [1,2,3]);
        assert( Bar.E == [1,2,3,4]);
        assert( Bar.fx == &Bar.fb0);
        assert( Bar.fEvent == &Bar.SrcEvent);

        assert( Bar.fg.A == 88);
		assert( Bar.fg.B == 44);
        assert( Bar.fg.C == "bla bla");
        assert( Bar.fg.D == [11,22,33]);
        assert( Bar.fg.E == [11,22,33,44]);

        writeln( "izSerializer passed the text format tests");

    }
}
