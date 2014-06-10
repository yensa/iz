module iz.serializer;

import
	std.stdio: writeln, writefln;
import
	core.exception, std.traits, std.conv, std.typetuple, std.string, std.array, std.algorithm,
	iz.types, iz.containers, iz.properties, iz.streams;
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

interface izSerializable
{
	/**
	 * Called by an izMasterSerializer before reading or writing.
	 * The implementer should use this method to declare its properties
	 * to aSerializer.
	 */
	void declareProperties(izMasterSerializer aSerializer);
	/**
	 * Called for each unread property by an izMasterSerializer after reading.
	 * This can be used, for example, if since the last serialization, the
	 * declarations have changed (new property name, new order, new type, ...)
	 */
	void getDescriptor(const unreadProperty infos, out izPtr aDescriptor);
}

enum fixedSerializableTypes
{
	stObject,
	stUnknow,				// if IndexOf(T,izSerTypes) == -1
	stBool,					// if IndexOf(T,izSerTypes) == 0
	stByte, stUbyte,		// ...
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
	
private string izSerTypesString [izSerTypes.length] = [ "izSerializable", "unknown",
	"bool", "byte", "ubyte", "short", "ushort", "int", "uint", "long", "ulong",
	"char", "wchar", "dchar", "float", "double"];

private ubyte izSerTypesLen[izSerTypes.length] =
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
	ushort type;
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
			0		|	byte	|	property header, constant, 0x0B
			1		|	ushort	|	type +
			2		|	...		|	organized in array if (value & 0x000F) > 0
			3		|	uint	|	length of the property name, uint (X)
			4		|	...		|
			5		|	...		|
			6		|	...		|
			7		|	ubyte[]	|	property name
			...		|			|
			...		|			|
			...		|			|
			7+X		|	ubyte[]	|	property value.
			...		|			|
			...		|			|
			...		|			|
			N		|	byte	|	property footer, constant, 0xA0	.
			N + 1	|	byte	|	optional footer, constant, 0xB0, end of object mark.
		*/
		void writeBin(izStream aStream)
		{
			// header
			ubyte mark = 0x99;
			aStream.write(&mark, mark.sizeof);
			// type
			ushort typeix = 0;
			static if (!is(T == izSerializable))
			{
				T arr;
				static if (isStaticArray!T) typeix =
					staticIndexOf!(typeof(T.init[0]),izSerTypes) + 0x200F;
				else static if (isDynamicArray!T) typeix =
					staticIndexOf!(typeof(arr[0]),izSerTypes) + 0x200F;
				else typeix = staticIndexOf!(T,izSerTypes) + 2;
			}
			aStream.write(&typeix, typeix.sizeof);
			//name length
			uint namelen = fDescriptor.name.length;
			aStream.write(&namelen, namelen.sizeof);
			// name...
			char[] namecpy = fDescriptor.name.dup;
			aStream.write(namecpy.ptr,namecpy.length);
			// value...
			static if (!is(T == izSerializable))
			{
				T value = fDescriptor.getter()();
				static if(!isArray!T) aStream.write(&value, value.sizeof);
				else
				{
					size_t byteSz = 0;
					static if (isStaticArray!T) byteSz = typeof(T.init[0]).sizeof * value.length ;
					static if (isDynamicArray!T) byteSz = typeof(arr[0]).sizeof * value.length ;
					aStream.write(value.ptr, byteSz);
				}
			}
			// footer
			mark = 0xA0;
			aStream.write(&mark, mark.sizeof);
		}

		void readBin(izStream aStream)
		{
			size_t cnt;
			auto headerpos = aStream.position;
			ulong footerPos;
			//uprop.parentName =
			// header
			ubyte mark;
			cnt = aStream.read(&mark, mark.sizeof);
			// type
			ushort typeix;
			cnt = aStream.read(&typeix, typeix.sizeof);
			uprop.type = 	(typeix & cast(ushort)0x000F);
			uprop.isArray = (typeix & cast(ushort)0xFFF0) == 0x0F;
			//name length
			uint namelen;
			cnt = aStream.read(&namelen, namelen.sizeof);
			// name...
			uprop.name.length = namelen;
			cnt = aStream.read(uprop.name.ptr,namelen);
			// value...
			mark = 0;
			auto savedPos = aStream.position;
			while ((mark != 0xA0) && (aStream.position < aStream.size))
			{
				aStream.read(&mark, mark.sizeof);
				footerPos = aStream.position;
			}
			footerPos--;
			aStream.position = savedPos;
			static if (!is(T == izSerializable))
			{
				ulong valueLen = footerPos - aStream.position;
				uprop.value.length = cast(size_t) valueLen;
				cnt = aStream.read(uprop.value.ptr, cast(size_t) valueLen);
			}
			// footer
			cnt = aStream.read(&mark, mark.sizeof);
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
				data = to!string( fDescriptor.getter()() ).dup;
				if (is(T==char[])) data = tabstring(data);
				aStream.write(data.ptr,data.length);
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
				readIx--;
				head = fullProp[readIx];
			}
			// property value
			auto propValue = fullProp[cast(size_t)posStore..readIx];
			
			// unread prop
			
			uprop.isArray = (propType[$-2..$] == "[]" ) ;
				
			if (!uprop.isArray) uprop.type = cast(ushort)
				countUntil( cast(string[])izSerTypesString,propType[0..$]);
			else uprop.type = cast(ushort)
				countUntil( cast(string[])izSerTypesString,propType[0..$-2]);
				
			T value;
			static if (!is(T==izSerializable))
				if (!uprop.isArray) 
					value = to!T(propValue);
			//else
				//value = to!T(propValue);
			static if (!is(T==izSerializable))
			if (!uprop.isArray)			
			{
				uprop.value.length = izSerTypesLen[uprop.type];	
				*cast(T*) uprop.value.ptr = value;
			}
				
			uprop.name = propName;

			static if (!is(T==izSerializable)) if (!uprop.isArray) 
			writeln(uprop.name, " ", izSerTypesString[uprop.type], " ", *cast(T*)uprop.value.ptr );


		}
	}
	protected
	{
		override void write(izStream aStream, izSerializationFormat aFormat)
		{
			fIsRead = false;
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
		@property izPropDescriptor!T descriptor()
		{
			return fDescriptor;
		}

		/**
		 * Returns the izSerializable Object which declared descriptor.
		 */
		@property izSerializable parentObject()
		{
			return fDeclarator;
		}

		/**
		 * Returns true if the items has been read.
		 */
		@property const(bool) isRead()
		{
			return fIsRead;
		}
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
	writing		/// the izMasterSerializer is restoring to an izSerializable
};

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
			fState = izSerializationState.reading;
			scope(exit) fState = izSerializationState.none;

			fStream = aStream;
			fRoot.deleteChildren;
			fCurNode = fRoot;
			fObj = aRoot;
			auto rootDescr = izPropDescriptor!izSerializable(&fObj,"Root");
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
			fState = izSerializationState.writing;
			scope(exit) fState = izSerializationState.none;

			fStream = aStream;
			fRoot.deleteChildren;
			fCurNode = fRoot;
			fObj = aRoot;
			auto rootDescr = izPropDescriptor!izSerializable(&fObj,"Root");
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
		}

		/**
		 * Called by an izSerializable in its declareProperties implementation.
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
		@property const(izSerializationState) state()
		{
			return fState;
		}
	}
}

version(unittest)
{

	class foo: izSerializable
	{
		private:
			int fAlpha, fBeta;
			char[] fOmega;
			ubyte[4] fZeta;
			izPropDescriptor!int ADescr,BDescr;
			izPropDescriptor!(char[]) ODescr;
			izPropDescriptor!(ubyte[4]) ZDescr;
		public:
			@property void Alpha(int value){fAlpha = value;}
			@property int Alpha(){return fAlpha;}
			@property void Beta(int value){fBeta = value;}
			@property int Beta(){return fBeta;}
			@property void Omega(char[] value){fOmega = value;}
			@property char[] Omega(){return fOmega;}
			@property void Zeta(ubyte[4] value){fZeta = value;}
			@property ubyte[4] Zeta(){return fZeta;}
			//
			this()
			{
				ADescr.define(&Alpha,&Alpha,"Alpha");
				BDescr.define(&Beta,&Beta,"Beta");
				ODescr.define(&Omega,&Omega,"Omega");
				ZDescr.define(&Zeta,&Zeta,"Zeta");
			}
			void declareProperties(izMasterSerializer aSerializer)
			{
				aSerializer.addProperty!int(ADescr);
				aSerializer.addProperty!int(BDescr);
				aSerializer.addProperty!(char[])(ODescr);
				//aSerializer.addProperty!(ubyte[4])(ZDescr);
			}
			void getDescriptor(const unreadProperty infos, out izPtr aDescriptor)
			{
			}
	}
	class bar: foo
	{
		private:
			foo fGamma;
			izPropDescriptor!izSerializable GDescr;
			izSerializable ffG;
		public:
			@property void Gamma(izSerializable value){/*fGamma = value;*/}
			@property izSerializable Gamma(){return fGamma;}
			this()
			{
				fGamma = new foo;

				// must be cast before getting the addr.
				ffG = cast(izSerializable) fGamma;

				GDescr.define(cast(izSerializable*)&ffG,"Gamma");

				assert( cast(izSerializable) (&fGamma) );

			}
			~this()
			{
				delete fGamma;
			}
			override void declareProperties(izMasterSerializer aSerializer)
			{
				super.declareProperties(aSerializer);
				aSerializer.addProperty!izSerializable(GDescr);
			}
	}

	unittest
	{

		auto Bar0 = new bar;
		auto Bar1 = new bar;
		auto str = new izMemoryStream;
		auto ser = new izMasterSerializer;

		Bar0.Omega = "whoosh".dup;
		Bar0.Alpha = 8;
		Bar0.Beta = 4;
		Bar0.Zeta = [1,2,3,4];
		Bar0.fGamma.Omega = "whoosh whoosh whoosh".dup;
		Bar0.fGamma.Alpha = 88;
		Bar0.fGamma.Beta = 44;
		Bar0.fGamma.Zeta = [11,22,33,44];

		Bar1.Omega = "blah".dup;
		Bar1.Alpha = 9;
		Bar1.Beta = 3;
		Bar1.Zeta = [5,6,7,8];
		Bar1.fGamma.Omega = "blah blah blah blah blah blah blah blah
			blah blah blah blah blah blah blah blah blah blah blah
			blah blah blah blah blah blah blah blah blah blah blah
			blah blah blah blah blah blah blah blah blah blah blah
			blah blah blah blah blah blah blah blah blah blah blah".dup;
		Bar1.fGamma.Alpha = 99;
		Bar1.fGamma.Beta = 33;

		scope(exit)
		{
			delete Bar0;
			delete Bar1;
			delete ser;
			delete str;
		}

		ser.fFormat = izSerializationFormat.text;
		ser.serialize(Bar0,str);
		ser.serialize(Bar1,str);
		str.position = 0;
		str.saveToFile("ser.bin");str.position = 0;
		Bar0.Alpha = 0;
		Bar0.Beta = 0;
		Bar0.Omega = "...".dup;

		ser.deserialize(Bar0,str);
		ser.deserialize(Bar1,str);
		

		
		
		assert( Bar0.Alpha == 8);
		assert( Bar0.Beta == 4);
	}
}