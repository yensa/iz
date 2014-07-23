module processcript;

import std.stdio, std.path, std.getopt, std.process;
import iz.types, iz.properties, iz.serializer, iz.streams;

pragma(lib, "iz.lib");

class scriptedProc: izSerializable
{
    private
    {
        char[] fExecutable;
        char[] fWorkingDirectory;
        char[] fParameters;
        bool fWaitOnExit;
        uint fParameterCount;
        //
        izPropDescriptor!(char[]) fExecutableDescr;
        izPropDescriptor!(char[]) fWorkingDirDescr;
        izPropDescriptor!(char[]) fParametersDescr;
        izPropDescriptor!(bool) fWaitOnExitDescr;
        izPropDescriptor!(uint) fParamCountDescr;
    }
    public
    {
        mixin(genPropFromField!(char[],"Executable","fExecutable"));
        mixin(genPropFromField!(char[],"Parameters","fParameters"));
        mixin(genPropFromField!(char[],"WorkingDirectory","fWorkingDirectory"));
        mixin(genPropFromField!(bool,"WaitOnExit","fWaitOnExit"));
        mixin(genPropFromField!(uint,"ParameterCount","fParameterCount"));

        this()
        {
            fExecutable = " ".dup;
            fWorkingDirectory = " ".dup;
            fParameters = " ".dup;
            //
            fExecutableDescr = izPropDescriptor!(char[])
                (&Executable, &Executable, "Executable");
            fWorkingDirDescr = izPropDescriptor!(char[])
                (&WorkingDirectory, &WorkingDirectory, "WorkingDirectory");
            fParametersDescr = izPropDescriptor!(char[])
                (&Parameters, &Parameters, "Parameter");
            fWaitOnExitDescr = izPropDescriptor!(bool)
                (&WaitOnExit, &WaitOnExit, "WaitOnExit");
            fParamCountDescr = izPropDescriptor!(uint)
                (&ParameterCount, &ParameterCount, "ParameterCount");
        }

        void execute()
        {
            if (fWaitOnExit)
            {
                wait(

                    spawnProcess([fExecutable, fParameters])

                );
            }
            else
            {
                spawnProcess([fExecutable, fParameters]);
            }
        }

        void declareProperties(izMasterSerializer aSerializer)
        {
            aSerializer.addProperty!(char[])(fExecutableDescr);
            aSerializer.addProperty!(char[])(fWorkingDirDescr);
            aSerializer.addProperty(fParametersDescr);
            aSerializer.addProperty!bool(fWaitOnExitDescr);
            aSerializer.addProperty!uint(fParamCountDescr);

        }

	    void getDescriptor(const unreadProperty infos, out izPtr aDescriptor){}
    }
}

void main(string[] args)
{

    auto prc = new scriptedProc;
    auto str = new izMemoryStream;
    auto ser = new izMasterSerializer;
    scope(exit)
    {
        delete str;
        delete ser;
        delete prc;
    }

    if (args.length > 1)
    {
        foreach(fname; args[1..$])
        {
            str.loadFromFile(fname);
            str.position = 0;
            ser.deserialize(prc, str, izSerializationFormat.text);
            prc.execute;
            str.clear;
        }
    }
    else
    {
        str.clear;
        ser.serialize(prc, str, izSerializationFormat.text);
        str.saveToFile("template.txt");
    }
    readln;
}
