@echo off
echo compiling lib...
dmd -lib -O -release -inline -noboundscheck "..\import\iz\types.d" "..\import\iz\bitsets.d" "..\import\iz\observer.d" "..\import\iz\streams.d" "..\import\iz\containers.d" "..\import\iz\properties.d" "..\import\iz\referencable.d" "..\import\iz\serializer.d" -of"..\lib\iz.lib" -I"..\import"
echo ...lib compiled
@echo on
pause
