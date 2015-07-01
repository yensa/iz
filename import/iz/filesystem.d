module iz.filesystem;

import std.stdio;
import std.file, std.path;
import std.array, std.algorithm, std.range;

import iz.types;

enum FileSystemKind {none, directory, file}

struct FileSystem
{
    private:
    
        bool _needUpdate;
        bool _updating;
        size_t _level;
        string _filename;
        FileSystemKind _kind;
        FileSystem * _directory;
        FileSystem * [] _directories;
        FileSystem * [] _files;
        
        void clearDirectories()
        {
            while (!_directories.empty)
            {
                _directories.back.clearDirectories;
                _directories.back.clearFiles;
                destruct(_directories.back);
                _directories.popBack;
            }
        }
        
        void clearFiles()
        {
            while (!_files.empty)
            {
                destruct(_files.back);
                _files.popBack;
            }    
        }
        
        void tryUpdate()
        {
            if (_needUpdate) update;
        }
        
        void update()
        {
            _needUpdate = false;
            if (_updating) 
            {
                "warning, recursive FileSystem update detected".writeln;
                return;
            }
            _updating = true;
            
            // update kind
            if (_filename.exists)
            {
                if (_filename.isDir)
                    _kind = FileSystemKind.directory;
                else
                    _kind = FileSystemKind.file;    
            }
            else _kind = FileSystemKind.none;
            
            // forces separator on dir
            /*if (_kind == FileSystemKind.directory)
            {
                if (_filename[$-1..$] != dirSeparator)
                    _filename ~= dirSeparator;    
            }*/
            
            // update sub items 
            with(FileSystemKind) final switch(_kind)
            {
                case none: break;
                case file: break;
                case directory: updateDirectories; updateFiles; break;
            }
            
            // update level
            _level = size_t.max;
            FileSystem * prt = &this;
            while (prt) {prt = prt._directory; ++_level;}
            
            _updating = false;
        }
        
        void updateFiles()
        {
            //try 
            foreach(entry; dirEntries(_filename, SpanMode.shallow, false))
            {
                if (entry.isDir) continue;
                if (!entry.exists) continue;
                
                void addEntry(size_t index)
                {
                    FileSystem * item = construct!FileSystem(entry);
                    item._directory = &this;
                    insertInPlace(_files, index, item);           
                }
                
                if (!_files.length) addEntry(0);
                else foreach(i,FileSystem * existing; _files)
                {
                    if (existing._filename == entry) continue;
                    addEntry(i);
                    break;
                }
            }
            //catch (Exception e) {} 
        }
                  
        void updateDirectories()
        {
            //try 
            foreach(entry; dirEntries(_filename, SpanMode.shallow, false))
            {
                if (!entry.isDir) continue;
                if (!entry.exists) continue;
                
                void addEntry(size_t index)
                {
                    FileSystem * item = construct!FileSystem(entry);
                    item._directory = &this;
                    insertInPlace(_directories, index, item);           
                }
                
                if (!_directories.length) addEntry(0);
                else foreach(i,FileSystem * existing; _directories)
                {
                    if (existing._filename == entry) continue;
                    addEntry(i);
                    break;
                }
            }
            //catch (Exception e) {}            
        }
         
    public:
    
        this(string aFilename)
        {
            _filename = aFilename;
            markForUpdate;     
        }
        
        ~this()
        {
            clearFiles;
            clearDirectories;               
        }
        
        void reduce()
        {
            clearDirectories;
        }
        
        void markForUpdate()
        {
            _needUpdate = true;
        }
        
        FileSystem * find(string aFilename)
        {
            FileSystem * result = null;
                
            if (!aFilename.exists) return result;
            
            // check this, trig any pending update or planed at (1)
            if (aFilename == filename)
                return &this;  
            
            // check known children, without updating them (read _prop and not prop)
            if (aFilename.isDir) foreach(FileSystem * child; _directories)
            {
                if (child._filename == aFilename)
                    return child; 
            }
            else foreach(FileSystem * child; _files)
            {
                if (child._filename == aFilename)
                    return child; 
            } 
            
            // check the children recursively, mark them for update (1)
            foreach_reverse(FileSystem * child; _directories)
            {
                child.markForUpdate;
                result = child.find(aFilename);
                if (result) return result;
            }                      
            
            return result;    
        }
        
        FileSystemKind kind() {tryUpdate; return _kind;}
        
        string filename(){tryUpdate; return _filename;}
        
        size_t level() {tryUpdate; return _level;}
        
        size_t directoryCount() {tryUpdate; return _directories.length;}
        
        size_t fileCount() {tryUpdate; return _files.length;}
        
        FileSystem * [] files() {tryUpdate; return _files;}
        
        FileSystem * [] directories() {tryUpdate; return _directories;}
        
        FileSystem * [] filesRange() {tryUpdate; return _files.dup;}
        
        FileSystem * [] directoriesRange() {tryUpdate; return _directories.dup;}    
}

unittest
{
    FileSystem root = FileSystem(r"C:\");
    root.filename.writeln;
    root.directoryCount.writeln;
    root.directories[1].filename.writeln;
    root.directories[1].directoryCount.writeln;
    root.directories[1].markForUpdate;
    root.directories[1].directoryCount.writeln;
    root.directories[1].markForUpdate;
    root.directories[1].directoryCount.writeln; 
    root.level.writeln;
    root.directories[1].level.writeln;    
    
    root.find(r"C:\Dev").writeln;
    root.find(r"C:\Dev\ceprojs").writeln;
    root.find(r"C:\Dev\pasproj").writeln;
    root.find(r"C:\Windows\Media\Afternoon").writeln;
    
}
