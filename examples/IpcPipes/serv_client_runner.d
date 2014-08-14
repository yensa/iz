module server_client_runner;

import std.stdio;
import iz.streams;
import std.process, std.path, std.file;

string pipeName = r"\\.\pipe\runnerpipe";

void main(string args[])
{
    version(server)
    {
        auto srv = izPipeStream.createAsServer(pipeName);
        do{srv.waitNewClient;} while (true);
    }
    version(client)
    {
        auto clt = izPipeStream.createAsClient(pipeName);
        while(true) {}
    }
    version(runner)
    {
        string dir = args[0].dirName ~ dirSeparator;

        writeln(dir);

        auto srvr = spawnProcess(dir ~ "server.exe", null);
        auto clt1 = spawnProcess(dir ~ "client.exe", null);
        auto clt2 = spawnProcess(dir ~ "client.exe", null);
        auto clt3 = spawnProcess(dir ~ "client.exe", null);

        readln;
    }
}
