module iz.streams;

import core.exception, std.exception;
import std.stdio, std.string, std.c.stdlib: malloc, free, realloc;
import core.stdc.string: memcpy, memmove;
import std.digest.md;

version (Windows)
{
	import core.sys.windows.windows, std.windows.syserror, std.c.windows.windows;
}
version (Posix)
{
	import core.sys.posix.fcntl, core.sys.posix.unistd;
}

import iz.types;


/**
 * An implementer can save or load from an izStream.
 * in loadFromStream, aStream initial position is preserved.
 */
interface izStreamPersist
{
	void saveToStream(izStream aStream);
	void loadFromStream(izStream aStream);
}

/**
 * An implementer can save or load to/from a file with a given UTF8 file name.
 */
interface izFilePersist8
{
	void saveToFile(in char[] aFilename);
	void loadFromFile(in char[] aFilename);
}

interface izStream
{
	/**
	 * Reads aCount bytes from aBuffer.
	 * Returns the count of bytes effectively read.
	 */
	size_t read(izPtr aBuffer, size_t aCount);
	/**
	 * Read T.sizeof bytes from the pointer aValue.
	 * Returns the count of bytes effectively read (either T.sizeof or 0).
	 * T must verify isConstantSize.
	 */
	size_t readVariable(T)(T* aValue);
	/**
	 * Writes aCount bytes to aBuffer.
	 * Returns the count of bytes effectively written.
	 */
	size_t write(izPtr aBuffer, size_t aCount);
	/**
	 * Writes T.sizeof bytes to the pointer aValue.
	 * Returns the count of bytes effectively written (either T.sizeof or 0).
	 * T must verify isConstantSize.
	 */
	size_t writeVariable(T)(T* aValue);
	/**
	 * Sets the position to anOffset if anOrigin = 0,
	 * to Position + anOffset if anOrigin = 1 or
	 * to Size + anOffset if anOrigin = 2.
	 */
	ulong seek(long anOffset, int anOrigin);
	/// ditto
	ulong seek(int anOffset, int anOrigin);
	/**
	 * Stream size.
	 */
	@property ulong size();
	/// ditto
	@property void size(ulong aValue);
	/// ditto
	@property void size(uint aValue);
	/**
	 * Cursor position in the stream.
	 */
	@property ulong position();
	/// ditto
	@property void position(ulong aValue);
	/// ditto
	@property void position(uint aValue);
	/**
	 * Resets the stream size to 0.
	 */
	void clear();
}


/**
 * An izStream to izStream copier.
 * It preserves aSource initial position.
 */
void copyStream(izStream aSource, izStream aTarget)
{
	auto oldpos = aSource.position; 
	auto buffsz = 4096;
	auto buff = malloc(buffsz);
	if (!buff) throw new OutOfMemoryError();
	
	scope(exit)
	{
		aSource.position = oldpos;
		free(buff);
	}
	
	aSource.position = 0;
	aTarget.size = aSource.size;
	aTarget.position = 0;
	
	while(aSource.position != aSource.size)
	{
		auto cnt = aSource.read(buff, buffsz);
		aTarget.write(buff, cnt);
	}
}

/*
class izSystemStream: izObject, izStream, izStreamPersist
{
}

class izFileStream: izSystemStream
{
}*/

/**
 * Implements a stream of contiguous, GC-free, memory.
 * Its maximal theoretical size is 2^32 bytes (x86) or 2^64 bytes (x86_64).
 * Its practical size limit is damped by the amount of remaining DRAM.
 * This limit is itself reduced by the memory fragmentation. 
 */
class izMemoryStream: izObject, izStream, izStreamPersist, izFilePersist8
{
	private
	{
		izPtr fMemory;
		size_t fSize;
		size_t fPosition;
	}
	public
	{
		this()
		{
			fMemory = malloc(16);
			if (!fMemory) throw new OutOfMemoryError();
		}
		
		~this()
		{
			if(fMemory) std.c.stdlib.free(fMemory);
		}
		
// read -------------------------------

		size_t read(izPtr aBuffer, size_t aCount)
		{
			if (aCount + fPosition > fSize) aCount = fSize - fPosition;
			memmove(aBuffer, fMemory + fPosition, aCount);
			fPosition += aCount;
			return aCount;
		}
		
		size_t readVariable(T)(T* aValue) if (isConstantSize!T)
		{
			if (fPosition + T.sizeof > fSize) return 0;
			memmove(aValue, fMemory + fPosition, T.sizeof);
			fPosition += T.sizeof;
			return T.sizeof;
		}
		
// write -------------------------------

		size_t write(izPtr aBuffer, size_t aCount)
		{
			if (fPosition + aCount > fSize) size(fPosition + aCount);
			memmove(fMemory + fPosition, aBuffer, aCount);
			fPosition += aCount;
			return aCount;
		}
		
		size_t writeVariable(T)(T* aValue) if (isConstantSize!T)
		{
			if (fPosition + T.sizeof > fSize) size(fPosition + T.sizeof);
			memmove(fMemory + fPosition, aValue, T.sizeof);
			fPosition += T.sizeof;
			return T.sizeof;
		}
		
// seek -------------------------------

		ulong seek(long anOffset, int anOrigin)
		{
			switch(anOrigin)
			{
				case 0:		
					fPosition = cast(typeof(fPosition)) anOffset;
					if (fPosition > fSize) fPosition = fSize;
					return fPosition;		
				case 1:	
					fPosition += anOffset;
					if (fPosition > fSize) fPosition = fSize;
					return fPosition;	
				case 2:
					return fSize;	
				default: 
					return fPosition;
			}
		}
		ulong seek(int anOffset, int anOrigin)
		{
			switch(anOrigin)
			{
				case 0:		
					fPosition = cast(typeof(fPosition)) anOffset;
					if (fPosition > fSize) fPosition = fSize;
					return fPosition;		
				case 1:	
					fPosition += anOffset;
					if (fPosition > fSize) fPosition = fSize;
					return fPosition;	
				case 2:
					return fSize;	
				default: 
					return fPosition;
			}
		}
		
// size -------------------------------	

		@property ulong size()
		{
			return fSize;
		}
		
		@property void size(uint aValue)
		{
			if (fSize == aValue) return;
			if (aValue == 0)
			{
				clear;
				return;
			}
			fMemory = realloc(fMemory, aValue);
			if (!fMemory) throw new OutOfMemoryError();
			else fSize = aValue;			
		}
		
		@property void size(ulong aValue)
		{
			static if (size_t.sizeof == 4)
			{
				if (aValue > 0xFFFFFFFF)
					throw new Exception("cannot allocate more than 0xFFFFFFFF bytes");
			}
			size(cast(uint) aValue);		
		}
		
// position -------------------------------			
		
		@property ulong position()
		{
			return fPosition;
		}
		
		@property void position(ulong aValue)
		{
			seek(aValue, 0);
		}
		
		@property void position(uint aValue)
		{
			seek(aValue, 0);
		}
		
// misc -------------------------------	

		void clear()
		{
			fMemory = std.c.stdlib.realloc(fMemory, 16);
			if (!fMemory) throw new OutOfMemoryError();
			fSize = 0;
			fPosition = 0;
		}

		/**
		 * Read-only access to the memory chunk.
		 */
		@property final const(izPtr) memory()
		{
			return fMemory;
		}

// operators -------------------------------

        ubyteArray ubytes()
        {
            return ubyteArray(fMemory, fSize);
        }
	
// izStreamPersist -------------------------------
	
		/**
		 * Clones the content to aStream. After the call aStream position 
		 * matches to its new size. The position is maintained.
		 */
		void saveToStream(izStream aStream)
		{
			if (cast(izMemoryStream) aStream)
			{
				auto target = cast(izMemoryStream) aStream;
				auto oldpos = target.position;
				scope(exit) target.position = oldpos;
				
				position = 0;
				aStream.size = size;
				aStream.position = 0;
				
				size_t sz = cast(size_t) size;
				size_t buffsz = 8192;
				size_t blocks = sz / buffsz;
				size_t tail = sz - blocks * buffsz;
				
				size_t pos;
				for (auto i = 0; i < blocks; i++)
				{
					memmove(target.fMemory + pos, fMemory + pos, buffsz);
					pos += buffsz;
				}
				if (tail) memmove(target.fMemory + pos, fMemory + pos, tail);	
			}
			else
			{
				this.copyStream(aStream);
			}
		}
		
		/**
		 * Clones the content from aStream. After the call the position 
		 * matches to the new size. aStream position is maintained.
		 */
		void loadFromStream(izStream aStream)
		{
			if (cast(izMemoryStream) aStream) 
			{
				izMemoryStream source = cast(izMemoryStream) aStream;
				source.saveToStream(this);
			}
			else
			{
				this.copyStream(aStream);
			}
		}

// izFilePersist8 -------------------------------
		
		/**
		 * Saves the stream content to the file aFilename.
		 * An existing file is automatically overwritten.
		 */
		void saveToFile(in char[] aFilename)
		{
			version(Windows)
			{
				auto hdl = CreateFileA( aFilename.toStringz, GENERIC_WRITE, 0,
					(SECURITY_ATTRIBUTES*).init, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, HANDLE.init);
				
				if (hdl == INVALID_HANDLE_VALUE)
					throw new Error(format("stream exception: cannot create or overwrite '%s'", aFilename));
				
				scope(exit) CloseHandle(hdl); 
				uint numRead;
				SetFilePointer(hdl, 0, null, FILE_BEGIN);
				WriteFile(hdl, fMemory, cast(uint)fSize, &numRead, null);
				
				if (numRead != fSize)
					throw new Error(format("stream exception: '%s' is corrupted", aFilename));
			}
            version(Posix)
            {
                auto hdl = open( aFilename.toStringz, O_CREAT | O_TRUNC | O_WRONLY, octal!666);
				if (hdl <= -1)
				    throw new Error(format("stream exception: cannot create or overwrite '%s'", aFilename));

                scope(exit) core.sys.posix.unistd.close(hdl);
                auto numRead = core.sys.posix.unistd.write(hdl, fMemory, fSize);
				ftruncate64(hdl, fSize);

                if (numRead != fSize)
					throw new Error(format("stream exception: '%s' is corrupted", aFilename));
            }
		}
		
		/**
		 * Loads the stream content from the file aFilename.
		 */
		void loadFromFile(in char[] aFilename)		
		{
			version(Windows)
			{
				auto hdl = CreateFileA(aFilename.toStringz, GENERIC_READ, 0,
					(SECURITY_ATTRIBUTES*).init, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, HANDLE.init);
						
				if (hdl == INVALID_HANDLE_VALUE)
					throw new Error(format("stream exception: cannot open '%s'", aFilename));
					
				uint numRead;
				scope(exit) CloseHandle(hdl);
				size( SetFilePointer(hdl, 0, null, FILE_END));
				SetFilePointer(hdl, 0, null, FILE_BEGIN);
				ReadFile(hdl, fMemory, cast(uint)fSize, &numRead, null);
				position = 0;
				
				if (numRead != fSize)
					throw new Error(format("stream exception: '%s' is not correctly loaded", aFilename));
			}
            version(Posix)
			{
                auto hdl = open(aFilename.toStringz, O_CREAT | O_RDONLY, octal!666);

                if (hdl <= -1)
                    throw new Error(format("stream exception: cannot open '%s'", aFilename));

                scope(exit) core.sys.posix.unistd.close(hdl);
                size(core.sys.posix.unistd.lseek64(hdl, 0, SEEK_END));
				core.sys.posix.unistd.lseek64(hdl, 0, SEEK_SET);
				auto numRead = core.sys.posix.unistd.read(hdl, fMemory, fSize);
				position = 0;

                if (numRead != fSize)
					throw new Error(format("stream exception: '%s' is not correctly loaded", aFilename));
            }
		}	
	}
}


version(unittest)
{
	class izMemoryStreamTest1 : commonStreamTester!izMemoryStream {}
	//class izFileStreamTest1: commonStreamTester!(izFileStream,"izFileStreamTest1.txt") {}

	class commonStreamTester(T, A...)
	{
		unittest
		{
			size_t len = 25_000;
			auto str = new T(A);
			scope (exit) delete str;
			for (int i = 0; i < len; i++)
			{
				str.write(&i, i.sizeof);
				assert(str.position == (i + 1) * i.sizeof);
			}	
			str.position = 0;
			assert(str.size == len * 4);
			while(str.position < str.size)
			{
				int g;
				str.read(&g, g.sizeof);
				assert(g == (str.position - 1) / g.sizeof );
			}
			str.clear;
			assert(str.size == 0);
			assert(str.position == 0);
			for (int i = 0; i < len; i++)
			{
				str.write(&i, i.sizeof);
				assert(str.position == (i + 1) * i.sizeof);
			}	
			str.position = 0;
			
			auto strcpy = new T(A);
			scope (exit) delete strcpy;
			strcpy.size = 1000;
			assert(str.size == len * 4);
			strcpy.loadFromStream(str);
			assert(str.size == len * 4);
			assert(strcpy.size == str.size);
			strcpy.position = 0;
			str.position = 0;
			for (int i = 0; i < len; i++)
			{
				int r0,r1;
				str.readVariable!int(&r0);
				strcpy.readVariable!int(&r1);
				assert(r0 == r1);
			}
			strcpy.position = 0;
			str.position = 0;
			assert(strcpy.size == len * 4);

			str.write("truncate the data".dup.ptr, 17);
			str.position = 0;
			ubyte[] food0, food1;
			food0.length = cast(size_t) str.size;
			food1.length = cast(size_t) strcpy.size;
			str.read(food0.ptr,food0.length);
			strcpy.read(food1.ptr,food1.length);
			ubyte[16] md5_0 = md5Of(food0);
			ubyte[16] md5_1 = md5Of(food1);
			assert(md5_0 != md5_1);
			
			static if (is(T == izMemoryStream))
			{
				str.saveToFile("memstream.txt");
				str.clear;
				str.loadFromFile("memstream.txt");
				assert(str.size == strcpy.size);
				std.stdio.remove("memstream.txt");
			}
			
			str.position = 0;
			strcpy.position = 0;
			strcpy.saveToStream(str);
			str.position = 0;
			strcpy.position = 0;
			food0.length = cast(size_t) str.size;
			food1.length = cast(size_t) strcpy.size;
			str.read(food0.ptr,food0.length);
			strcpy.read(food1.ptr,food1.length);
			md5_0 = md5Of(food0);
			md5_1 = md5Of(food1);
			assert(md5_0 == md5_1);

            static if (is(T == izMemoryStream))
			{
              str.clear;
              for(ubyte i = 0; i < 100; i++) str.write(&i, 1);
              for(ubyte i = 0; i < 100; i++) assert( str.ubytes[i] == i );
              for(ubyte i = 0; i < 100; i++) str.ubytes[i] = cast(ubyte) (99 - i);
              for(ubyte i = 0; i < 100; i++) assert( str.ubytes[i] == 99 - i  );
            }

			writeln( T.stringof ~ "(T) passed the tests");
		}
	}
}
