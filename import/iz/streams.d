module iz.streams;

import core.exception, std.exception;
import std.stdio, std.string, std.c.stdlib: malloc, free, realloc;
import core.stdc.string: memcpy, memmove;
import std.digest.md, std.conv;
import iz.types;

/// stream creation mode 'There': open only if exists.
public immutable int cmThere    = 0;
/// stream creation mode 'NotThere': create only if not exists.
public immutable int cmNotThere = 1;
/// stream creation mode 'Always': create if not exists otherwise open.
public immutable int cmAlways   = 2;

version (Windows) 
{
	import core.sys.windows.windows, std.windows.syserror, std.c.windows.windows;

    private immutable READ_WRITE =  GENERIC_READ | GENERIC_WRITE;
    private immutable FILE_SHARE_ALL = FILE_SHARE_READ | FILE_SHARE_WRITE;

    private immutable uint PIPE_ACCESS_INBOUND = 1;
    private immutable uint PIPE_ACCESS_OUTBOUND = 2;

    private extern(Windows) export BOOL SetEndOfFile(in HANDLE hFile);

    private extern(Windows) export HANDLE CreateNamedPipeA(
       LPCTSTR lpName,
       DWORD dwOpenMode,
       DWORD dwPipeMode,
       DWORD nMaxInstances,
       DWORD nOutBufferSize,
       DWORD nInBufferSize,
       DWORD nDefaultTimeOut,
       LPSECURITY_ATTRIBUTES lpSecurityAttributes
    );

    private extern(Windows) export BOOL ConnectNamedPipe(
        in HANDLE hNamedPipe,
        LPOVERLAPPED lpOverlapped = null
    );

    private extern(Windows) export BOOL PeekNamedPipe(
         in HANDLE hNamedPipe,
         out LPVOID lpBuffer,
         in DWORD nBufferSize,
         LPDWORD lpBytesRead,
         LPDWORD lpTotalBytesAvail,
         LPDWORD lpBytesLeftThisMessage
    );

    private extern(Windows) export BOOL DisconnectNamedPipe(
        in HANDLE hNamedPipe
    );


    public alias HANDLE izStreamHandle;

    /// seek modes.
    public immutable int skBeg = FILE_BEGIN;
    public immutable int skCur = FILE_CURRENT;
    public immutable int skEnd = FILE_END;

    /// share modes.
    public immutable int shNone = 0;
    public immutable int shRead = FILE_SHARE_READ;
    public immutable int shWrite= FILE_SHARE_WRITE;
    public immutable int shAll  = shWrite | shRead;

    /// access modes.
    public immutable uint acRead = GENERIC_READ;
    public immutable uint acWrite= GENERIC_WRITE;
    public immutable uint acAll  = acRead | acWrite;

    /// pipe direction
    public immutable uint pdIn  = PIPE_ACCESS_INBOUND;
    public immutable uint pdOut = PIPE_ACCESS_OUTBOUND;
    public immutable uint pdAll = pdIn | pdOut;


    /// returns true if aHandle is valid.
    public bool isHandleValid(izStreamHandle aHandle)
    {
        return (aHandle != INVALID_HANDLE_VALUE);
    }

    /// translates a cmXX to a platform specific option.
    public int cmToSystem(int aCreationMode)
    {
        switch(aCreationMode)
        {
            case cmThere: return OPEN_EXISTING;
            case cmNotThere: return CREATE_NEW;
            case cmAlways: return OPEN_ALWAYS;
            default: return OPEN_ALWAYS;
        }
    }

}
version (Posix) 
{
	import core.sys.posix.fcntl, core.sys.posix.unistd;

    public alias int izStreamHandle;

    /// seek modes.
    public immutable int skBeg = SEEK_SET;
    public immutable int skCur = SEEK_CUR;
    public immutable int skEnd = SEEK_END;

    /// share modes. (does not allow execution)
    public immutable int shNone = octal!600;
    public immutable int shRead = octal!644;
    public immutable int shWrite= octal!622;
    public immutable int shAll  = octal!666;

    /// access modes.
    public immutable uint acRead = O_RDONLY;
    public immutable uint acWrite= O_WRONLY;
    public immutable uint acAll  = O_RDWR;

    /// pipe direction
    public immutable uint pdIn  = 0;
    public immutable uint pdOut = 0;
    public immutable uint pdAll = 0;

    /// returns true if aHandle is valid.
    public bool isHandleValid(izStreamHandle aHandle)
    {
        return (aHandle > -1);
    }

    /// translates a cmXX to a platform specific option.
    public int cmToSystem(int aCreationMode)
    {
        switch(aCreationMode)
        {
            case cmThere: return 0;
            case cmNotThere: return O_CREAT | O_EXCL;
            case cmAlways: return O_CREAT;
            default: return O_CREAT;
        }
    }
}

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
    string filename();
}

private template genReadWriteVar()
{
    string genReadWriteVar()
    {
        string result;
        foreach(T; izConstantSizeTypes)
        {
            result ~= "alias readVariable!" ~ T.stringof ~ " read" ~
                T.stringof ~ ';' ~ '\r' ~ '\n';
            result ~= "alias writeVariable!" ~ T.stringof ~ " write" ~
                T.stringof ~ ';' ~ '\r' ~ '\n';
        }
        return result;
    }
}

interface izStream
{
	/**
	 * Reads aCount bytes from aBuffer.
	 * Returns the count of bytes effectively read.
	 */
	size_t read(izPtr aBuffer, size_t aCount);
	/**
	 * Read T.sizeof bytes in aValue.
	 * Returns the count of bytes effectively read (either T.sizeof or 0).
	 * T must verify isConstantSize.
     * A typed reader is generated for each type in izConstantSizeTypes
     * and named readint, readchar, etc.
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
     * A typed writer is generated for each type in izConstantSizeTypes
     * and named writeint, writechar, etc.
	 */
	size_t writeVariable(T)(T* aValue);
	/**
	 * Sets the position to anOffset if anOrigin = 0,
	 * to Position + anOffset if anOrigin = 1 or
	 * to Size + anOffset if anOrigin = 2.
	 */
	ulong seek(ulong anOffset, int anOrigin);
	/// ditto
	ulong seek(uint anOffset, int anOrigin);
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

/**
 * Unspecialized stream class. Descendant are all some
 * system stream (based on a file handle).
 * This class is not directly usable.
 */
package class izSystemStream: izObject, izStream, izStreamPersist
{
    private
    {
        izStreamHandle fHandle;
    }
    public
    {
        mixin(genReadWriteVar);
        size_t read(izPtr aBuffer, size_t aCount)
        {
            if (!fHandle.isHandleValid) return 0;
			version(Windows)
			{
				uint lCount = cast(uint) aCount;
				LARGE_INTEGER Li;
				Li.QuadPart = aCount;
				ReadFile(fHandle, aBuffer, Li.LowPart, &lCount, null);
				return lCount;
			}
			version(Posix)
			{
				return core.sys.posix.unistd.read(fHandle, aBuffer, aCount);
			}
        }

	    size_t readVariable(T)(T* aValue)
        {
            return read(&aValue, T.sizeof);
        }

        size_t write(izPtr aBuffer, size_t aCount)
        {
            if (!fHandle.isHandleValid) return 0;
			version(Windows)
			{
				uint lCount = cast(uint) aCount;
				LARGE_INTEGER Li;
				Li.QuadPart = aCount;
				WriteFile(fHandle, aBuffer, Li.LowPart, &lCount, null);
				return lCount;
			}
			version(Posix)
			{
				return core.sys.posix.unistd.write(fHandle, aBuffer, aCount);
			}
        }

	    size_t writeVariable(T)(T* aValue)
        {
            return write(&aValue, T.sizeof);
        }

	    ulong seek(ulong anOffset, int anOrigin)
        {
            if (!fHandle.isHandleValid) return 0;
			version(Windows)
			{
				LARGE_INTEGER Li;
				Li.QuadPart = anOffset;
				Li.LowPart = SetFilePointer(fHandle, Li.LowPart, &Li.HighPart, anOrigin);
				return Li.QuadPart;
			}
			version(Posix)
			{
				return core.sys.posix.unistd.lseek64(fHandle, anOffset, anOrigin);
			}
        }

	    ulong seek(uint anOffset, int anOrigin)
        {
            return seek(cast(ulong)anOffset, anOrigin);
        }

	    @property ulong size()
        {
            if (!fHandle.isHandleValid) return 0;
			ulong lRes, lSaved;

			lSaved = seek(0, skCur);
			lRes = seek(0, skEnd);
			seek(lSaved, skBeg);

			return lRes;
        }

	    @property void size(ulong aValue)
        {
            if (!fHandle.isHandleValid) return;
			if (size == aValue) return;

			version(Windows)
			{
				LARGE_INTEGER Li;
				Li.QuadPart = aValue;
				SetFilePointer(fHandle, Li.LowPart, &Li.HighPart, FILE_BEGIN);
				SetEndOfFile(fHandle);
			}
			version(Posix)
			{
				ftruncate(fHandle, aValue);
			}
        }

	    @property void size(uint aValue)
        {
            if (!fHandle.isHandleValid) return;
			version(Windows)
			{
				SetFilePointer(fHandle, aValue, null, FILE_BEGIN);
				SetEndOfFile(fHandle);
			}
			version(Posix)
			{
				ftruncate(fHandle, aValue);
			}
        }

	    @property ulong position()
        {
			return seek(0, skCur);
        }

	    @property void position(ulong aValue)
        {
			ulong lSize = size;
			if (aValue >  lSize) aValue = lSize;
			seek(aValue, skBeg);
        }

	    @property void position(uint aValue)
        {
            seek(aValue, skBeg);
        }

        /**
         * Exposes the handle for additional system stream operations.
         */
        @property const(izStreamHandle) handle(){return fHandle;}

	    void clear()
        {
            size(0);
            position(0);
        }

        void saveToStream(izStream aStream)
        {
            copyStream(this, aStream);
        }

	    void loadFromStream(izStream aStream)
        {
            copyStream(aStream, this);
        }
    }
}

/**
 * System stream specialized into reading and writing files, including huge ones
 * (up to 2^64 bytes). Various constructors are avalaible, providing predefined
 * sharing and access options.
 */
class izFileStream: izSystemStream
{
    private
    {
        string fFilename;
    }
    public
    {
        /**
         * Constructs the stream and call openPermissive.
         */
        this(in char[] aFilename, int creationMode = cmAlways)
        {
            openPermissive(aFilename, creationMode);
        }

        /**
         * Constructs the stream and call open.
         */
        this(in char[] aFilename, int access, int share, int creationMode)
        {
            open(aFilename, access, share, creationMode);
        }

        ~this()
        {
            closeFile;
        }

        /**
         * Opens a file for the current user. By default the file is always created or opened.
         */
        bool openStrict(in char[] aFilename, int creationMode = cmAlways)
        {
            version(Windows)
            {
			    fHandle = CreateFileA(aFilename.toStringz, READ_WRITE, shNone,
			        (SECURITY_ATTRIBUTES*).init, cmToSystem(creationMode),
                    FILE_ATTRIBUTE_NORMAL, HANDLE.init);
            }
            version(Posix)
            {
                fHandle = core.sys.posix.fcntl.open(aFilename.toStringz,
                    O_RDWR | cmToSystem(creationMode), shNone);
            }

			if (!fHandle.isHandleValid)
			{
				throw new Error(format("stream exception: cannot create or open '%s'", aFilename));
			}
            fFilename = aFilename.dup;
            return fHandle.isHandleValid;
        }

        /**
         * Opens a shared file. By default the file is always created or opened.
         */
        bool openPermissive(in char[] aFilename, int creationMode = cmAlways)
        {
            version(Windows)
            {
			    fHandle = CreateFileA(aFilename.toStringz, READ_WRITE, shAll,
			        (SECURITY_ATTRIBUTES*).init, cmToSystem(creationMode), FILE_ATTRIBUTE_NORMAL, HANDLE.init);
            }
            version(Posix)
            {
                fHandle = core.sys.posix.fcntl.open(aFilename.toStringz,
                    O_RDWR | cmToSystem(creationMode), shAll);
            }

			if (!fHandle.isHandleValid)
			{
				throw new Error(format("stream exception: cannot create or open '%s'", aFilename));
			}
            fFilename = aFilename.dup;
            return fHandle.isHandleValid;
        }

        /**
         * The fully parametric open version. Do not throw. Under POSIX, access can
         * be already OR-ed with other, unrelated flags (e.g: O_NOFOLLOW or O_NONBLOCK).
         */
        bool open(in char[] aFilename, int access, int share, int creationMode)
        {
            version(Windows)
            {
			    fHandle = CreateFileA(aFilename.toStringz, access, share,
			        (SECURITY_ATTRIBUTES*).init, cmToSystem(creationMode),
                    FILE_ATTRIBUTE_NORMAL, HANDLE.init);
            }
            version(Posix)
            {
                fHandle = core.sys.posix.fcntl.open(aFilename.toStringz,
                    access | cmToSystem(creationMode), share);
            }
            fFilename = aFilename.dup;
            return fHandle.isHandleValid;
        }

        /**
         * Closes the file and flushes any pending changes to the disk.
         * After the call, handle is not valid anymore.
         */
        void closeFile()
        {
			version(Windows)
			{
				if (fHandle.isHandleValid) CloseHandle(fHandle);
				fHandle = INVALID_HANDLE_VALUE;
			}
			version(Posix)
			{
				if (fHandle.isHandleValid) core.sys.posix.unistd.close(fHandle);
				fHandle = -1;
			}
			fFilename = "";
        }
        /**
         * Exposes the filename.
         */
        @property string filename(){return fFilename;}
    }
}


public uint pipeServer = 0;
public uint pipeClient = 1;

/**
 * System stream specialized into reading and writing from a named pipe.
 */
class izPipeStream: izSystemStream
{
    private
    {
        izStreamHandle fServer;
        string fPipeName;
        bool fAsServer;
    }
    public
    {
        static izPipeStream createAsServer(in char[] aPipeName, uint pipeAccess = pdAll)
        {
            return new izPipeStream(aPipeName, pipeAccess, pipeServer);
        }

        static izPipeStream createAsClient(in char[] aPipeName, uint pipeAccess = acAll)
        {
            return new izPipeStream(aPipeName, pipeAccess, pipeClient);
        }

        /**
         * Creates a pipe with the role pipeRole.
         */
        this(in char[] aPipeName, uint pipeAccess, uint pipeRole = pipeClient)
        {
            version(Windows)
            {
                if (pipeRole == pipeServer)
                {
                    uint BufSz = 4096;
                    fHandle = CreateNamedPipeA(
                        aPipeName.toStringz,
                        pipeAccess,
                        0, 255,
                        BufSz, BufSz,
                        0,
                        (SECURITY_ATTRIBUTES*).init
                    );
                    fAsServer = isHandleValid(fHandle);

                    if (!fAsServer)
                        throw new Error("stream exception: pipe server not created");

                    waitNewClient;
                }
                else
                {
                    fHandle = CreateFileA(aPipeName.toStringz, pipeAccess, shAll,
			            (SECURITY_ATTRIBUTES*).init, cmToSystem(cmThere),
                        FILE_ATTRIBUTE_NORMAL, HANDLE.init);
                    if (!fHandle.isHandleValid)
                        throw new Error("stream exception: pipe client not created");
                }
            }
            version(Posix)
            {
            }
        }

        ~this()
        {
            if (!fHandle.isHandleValid) return;
            version(Windows)
            {
                if (fAsServer)
                    CloseHandle(fServer);
                else
                    DisconnectNamedPipe(fHandle);
            }
            version(Posix)
            {
            }
        }

        bool waitNewClient()
        {
            version(Windows)
            {
                if (!fAsServer) return false;
                while(true)
                {
                    if (ConnectNamedPipe(fServer, null) == 0)
                        return false;
                }
            }
            version(Posix)
            {
                return false;
            }
        }

        size_t peek(izPtr aBuffer, size_t aCount)
        {
            uint lCount = cast(uint) aCount;
            uint cnt;
            uint nothing;
            version(Windows)
            {
                PeekNamedPipe(fHandle, aBuffer, lCount, &cnt, &nothing, &nothing);
            }
            version(Posix)
            {
            }
            return cnt;
        }
    }
}

/**
 * Implements a stream of contiguous, GC-free, heap-memory.
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
        string fFilename;
	}
	public
	{
        mixin(genReadWriteVar);
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

		ulong seek(ulong anOffset, int anOrigin)
		{
			switch(anOrigin)
			{
				case skBeg:
					fPosition = cast(typeof(fPosition)) anOffset;
					if (fPosition > fSize) fPosition = fSize;
					return fPosition;		
				case skCur:
					fPosition += anOffset;
					if (fPosition > fSize) fPosition = fSize;
					return fPosition;	
				case skEnd:
					return fSize;	
				default: 
					return fPosition;
			}
		}
		ulong seek(uint anOffset, int anOrigin)
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
			seek(aValue, skBeg);
		}
		
		@property void position(uint aValue)
		{
			seek(aValue, skBeg);
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

        @property string filename()
        {
            return fFilename;
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
				copyStream(aStream, this);
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
            fFilename = aFilename.idup;
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
            fFilename = aFilename.idup;
		}	
	}
}


version(unittest)
{
	class izMemoryStreamTest1 : commonStreamTester!izMemoryStream {}
	class izFileStreamTest1: commonStreamTester!(izFileStream, "filestream1.txt"){}

    unittest
    {
        auto sz = 0x1_FFFF_FFFFUL;
        auto huge = new izFileStream("huge.bin");
        scope(exit)
        {
            huge.demolish;
            std.stdio.remove("huge.bin");
        }
        huge.size = sz;
        huge.position = 0;
        assert(huge.size == sz);
    }

    version(Windows) unittest
    {
        // must be tested with several processes
        auto pipename = r"\\.\pipe\apipenname";
        auto srv = izPipeStream.createAsServer(pipename);
        auto clt1 = izPipeStream.createAsClient(pipename);
        scope(exit)
        {
            clt1.demolish;
            srv.demolish;
        }
    }

	class commonStreamTester(T, A...)
	{
		unittest
		{
			uint len = 25_000;
			auto str = new T(A);
			scope (exit)  str.demolish;
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
				auto c = str.read(&g, g.sizeof);
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

            static if (is(T == izFileStream))
            {
			    auto strcpy = new T("filestream2.txt");
            }
            else auto strcpy = new T(A);
			scope (exit) strcpy.demolish;
			strcpy.size = 100000;
			assert(str.size == len * 4);
			strcpy.loadFromStream(str);
			assert(str.size == len * 4);
			assert(strcpy.size == str.size);
			strcpy.position = 0;
			str.position = 0;
			for (int i = 0; i < len; i++)
			{
				int r0,r1;
				str.readint(&r0);
				strcpy.readint(&r1);
				assert(r0 == r1);
			}
			strcpy.position = 0;
			str.position = 0;
			assert(strcpy.size == len * 4);

			str.write("truncate the data".dup.ptr, 17);
			str.position = 0;
            strcpy.position = 0;
			ubyte[] food0, food1;
			food0.length = cast(size_t) str.size;
			food1.length = cast(size_t) strcpy.size;
			str.read(food0.ptr, food0.length);
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

            static if (is(T == izFileStream))
            {
                str.closeFile;
                strcpy.closeFile;
                std.stdio.remove("filestream1.txt");
                std.stdio.remove("filestream2.txt");
            }

            writeln( T.stringof ~ " passed the tests");
		}
	}
}
