dmd -D -o- -X -Xf"..\doc\docs.json" -I"..\import" "..\import\iz\types.d" "..\import\iz\bitsets.d" "..\import\iz\streams.d" "..\import\iz\containers.d" "..\import\iz\properties.d" "..\import\iz\referencable.d" "..\import\iz\serializer.d" -Dd"..\doc"
pause
