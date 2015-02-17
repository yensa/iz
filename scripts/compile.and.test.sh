echo ---------------------------------------
echo compiling library...
dmd -main -unittest -debug -w -wi "../import/iz/types.d" "../import/iz/classes.d" "../import/iz/bitsets.d" "../import/iz/observer.d" "../import/iz/streams.d" "../import/iz/containers.d" "../import/iz/properties.d" "../import/iz/referencable.d" "../import/iz/serializer.d" -of"testsrunner" -I"../import"
echo ---------------------------------------
./testsrunner
echo ---------------------------------------
rm ./testsrunner.o
rm ./testsrunner
read
