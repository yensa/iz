@echo off
echo ---------------------------------------
echo compiling library...
dmd -main -unittest -debug -w -wi "..\import\iz\types.d" "..\import\iz\bitsets.d" "..\import\iz\streams.d" "..\import\iz\containers.d" "..\import\iz\properties.d" "..\import\iz\referencable.d" "..\import\iz\serializer.d" -of"testsrunner.exe" -I"..\import"
echo ---------------------------------------
testsrunner
echo ---------------------------------------
del testsrunner.obj
del testsrunner.exe
echo on
pause
