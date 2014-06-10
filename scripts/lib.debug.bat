@echo off
echo compiling lib...
dmd -lib -debug -w -wi "..\import\iz\types.d" "..\import\iz\streams.d" "..\import\iz\containers.d" "..\import\iz\properties.d" "..\import\iz\serializer.d" -of"..\lib\iz.lib" -Dd"..\doc" -I"..\import"
echo ...lib compiled
@echo on
pause