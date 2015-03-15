@echo off
echo compiling lib...
dmd "..\import\iz\types.d" "..\import\iz\enumset.d" "..\import\iz\classes.d" "..\import\iz\observer.d" "..\import\iz\streams.d" "..\import\iz\containers.d" "..\import\iz\properties.d" "..\import\iz\referencable.d" "..\import\iz\serializer.d" -lib -O -release -inline -boundscheck=off  -of"..\lib\iz.lib" -I"..\import"
echo ...lib compiled
@echo on
pause
