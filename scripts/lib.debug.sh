echo compiling lib...
dmd -lib -debug -w -wi "../import/iz/types.d" "../import/iz/classes.d" "../import/iz/enumset.d" "../import/iz/observer.d" "../import/iz/streams.d" "../import/iz/containers.d" "../import/iz/properties.d" "../import/iz/referencable.d" "../import/iz/serializer.d" -of"../lib/iz.a" -I"../import"
echo ...lib compiled
read
