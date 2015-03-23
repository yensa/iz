"use strict";
var items = [
{"iz.types" : "iz\types.html"},
{"iz.types.izPtr" : "iz\types.html#izPtr"},
{"iz.types.izConstantSizeTypes" : "iz\types.html#izConstantSizeTypes"},
{"iz.types.isConstantSize" : "iz\types.html#isConstantSize"},
{"iz.types.reset" : "iz\types.html#reset"},
{"iz.types.getMem" : "iz\types.html#getMem"},
{"iz.types.reallocMem" : "iz\types.html#reallocMem"},
{"iz.types.moveMem" : "iz\types.html#moveMem"},
{"iz.types.moveMem" : "iz\types.html#moveMem"},
{"iz.types.freeMem" : "iz\types.html#freeMem"},
{"iz.types.construct" : "iz\types.html#construct"},
{"iz.types.construct" : "iz\types.html#construct"},
{"iz.types.destruct" : "iz\types.html#destruct"},
{"iz.types.newPtr" : "iz\types.html#newPtr"},
{"iz.types.destruct" : "iz\types.html#destruct"},
{"iz.streams" : "iz\streams.html"},
{"iz.streams.cmThere" : "iz\streams.html#cmThere"},
{"iz.streams.cmNotThere" : "iz\streams.html#cmNotThere"},
{"iz.streams.cmAlways" : "iz\streams.html#cmAlways"},
{"iz.streams.shNone" : "iz\streams.html#shNone"},
{"iz.streams.acRead" : "iz\streams.html#acRead"},
{"iz.streams.isHandleValid" : "iz\streams.html#isHandleValid"},
{"iz.streams.cmToSystem" : "iz\streams.html#cmToSystem"},
{"iz.streams.shNone" : "iz\streams.html#shNone"},
{"iz.streams.acRead" : "iz\streams.html#acRead"},
{"iz.streams.pdIn" : "iz\streams.html#pdIn"},
{"iz.streams.isHandleValid" : "iz\streams.html#isHandleValid"},
{"iz.streams.cmToSystem" : "iz\streams.html#cmToSystem"},
{"iz.streams.izSeekMode" : "iz\streams\izSeekMode.html"},
{"iz.streams.izStreamPersist" : "iz\streams\izStreamPersist.html"},
{"iz.streams.izStreamPersist.saveToStream" : "iz\streams\izStreamPersist.html#saveToStream"},
{"iz.streams.izStreamPersist.loadFromStream" : "iz\streams\izStreamPersist.html#loadFromStream"},
{"iz.streams.izFilePersist8" : "iz\streams\izFilePersist8.html"},
{"iz.streams.izFilePersist8.saveToFile" : "iz\streams\izFilePersist8.html#saveToFile"},
{"iz.streams.izFilePersist8.loadFromFile" : "iz\streams\izFilePersist8.html#loadFromFile"},
{"iz.streams.izFilePersist8.filename" : "iz\streams\izFilePersist8.html#filename"},
{"iz.streams.genReadWriteVar" : "iz\streams\genReadWriteVar.html"},
{"iz.streams.izStream" : "iz\streams\izStream.html"},
{"iz.streams.izStream.read" : "iz\streams\izStream.html#read"},
{"iz.streams.izStream.readVariable" : "iz\streams\izStream.html#readVariable"},
{"iz.streams.izStream.write" : "iz\streams\izStream.html#write"},
{"iz.streams.izStream.writeVariable" : "iz\streams\izStream.html#writeVariable"},
{"iz.streams.izStream.seek" : "iz\streams\izStream.html#seek"},
{"iz.streams.izStream.seek" : "iz\streams\izStream.html#seek"},
{"iz.streams.izStream.size" : "iz\streams\izStream.html#size"},
{"iz.streams.izStream.size" : "iz\streams\izStream.html#size"},
{"iz.streams.izStream.size" : "iz\streams\izStream.html#size"},
{"iz.streams.izStream.position" : "iz\streams\izStream.html#position"},
{"iz.streams.izStream.position" : "iz\streams\izStream.html#position"},
{"iz.streams.izStream.position" : "iz\streams\izStream.html#position"},
{"iz.streams.izStream.clear" : "iz\streams\izStream.html#clear"},
{"iz.streams.izStream.opOpAssign" : "iz\streams\izStream.html#opOpAssign"},
{"iz.streams.copyStream" : "iz\streams.html#copyStream"},
{"iz.streams.izSystemStream" : "iz\streams\izSystemStream.html"},
{"iz.streams.izSystemStream.handle" : "iz\streams\izSystemStream.html#handle"},
{"iz.streams.izFileStream" : "iz\streams\izFileStream.html"},
{"iz.streams.izFileStream.this" : "iz\streams\izFileStream.html#this"},
{"iz.streams.izFileStream.this" : "iz\streams\izFileStream.html#this"},
{"iz.streams.izFileStream.openStrict" : "iz\streams\izFileStream.html#openStrict"},
{"iz.streams.izFileStream.openPermissive" : "iz\streams\izFileStream.html#openPermissive"},
{"iz.streams.izFileStream.open" : "iz\streams\izFileStream.html#open"},
{"iz.streams.izFileStream.closeFile" : "iz\streams\izFileStream.html#closeFile"},
{"iz.streams.izFileStream.filename" : "iz\streams\izFileStream.html#filename"},
{"iz.streams.izMemoryStream" : "iz\streams\izMemoryStream.html"},
{"iz.streams.izMemoryStream.setMemory" : "iz\streams\izMemoryStream.html#setMemory"},
{"iz.streams.izMemoryStream.memory" : "iz\streams\izMemoryStream.html#memory"},
{"iz.streams.izMemoryStream.saveToStream" : "iz\streams\izMemoryStream.html#saveToStream"},
{"iz.streams.izMemoryStream.loadFromStream" : "iz\streams\izMemoryStream.html#loadFromStream"},
{"iz.streams.izMemoryStream.saveToFile" : "iz\streams\izMemoryStream.html#saveToFile"},
{"iz.streams.izMemoryStream.loadFromFile" : "iz\streams\izMemoryStream.html#loadFromFile"},
{"iz.streams.izMemoryStream.filename" : "iz\streams\izMemoryStream.html#filename"},
{"iz.containers" : "iz\containers.html"},
{"iz.containers.izArray" : "iz\containers\izArray.html"},
{"iz.containers.izArray.granurality" : "iz\containers\izArray.html#granurality"},
{"iz.containers.izArray.granularity" : "iz\containers\izArray.html#granularity"},
{"iz.containers.izArray.blockCount" : "iz\containers\izArray.html#blockCount"},
{"iz.containers.izArray.length" : "iz\containers\izArray.html#length"},
{"iz.containers.izArray.length" : "iz\containers\izArray.html#length"},
{"iz.containers.izArray.ptr" : "iz\containers\izArray.html#ptr"},
{"iz.containers.izArray.toString" : "iz\containers\izArray.html#toString"},
{"iz.containers.izArray.dup" : "iz\containers\izArray.html#dup"},
{"iz.containers.izArray.opEquals" : "iz\containers\izArray.html#opEquals"},
{"iz.containers.izArray.opIndex" : "iz\containers\izArray.html#opIndex"},
{"iz.containers.izArray.opIndexAssign" : "iz\containers\izArray.html#opIndexAssign"},
{"iz.containers.izArray.opApply" : "iz\containers\izArray.html#opApply"},
{"iz.containers.izArray.opApplyReverse" : "iz\containers\izArray.html#opApplyReverse"},
{"iz.containers.izArray.opDollar" : "iz\containers\izArray.html#opDollar"},
{"iz.containers.izArray.opAssign" : "iz\containers\izArray.html#opAssign"},
{"iz.containers.izArray.opSlice" : "iz\containers\izArray.html#opSlice"},
{"iz.containers.izArray.opSlice" : "iz\containers\izArray.html#opSlice"},
{"iz.containers.izArray.opSliceAssign" : "iz\containers\izArray.html#opSliceAssign"},
{"iz.containers.izArray.opSliceAssign" : "iz\containers\izArray.html#opSliceAssign"},
{"iz.containers.izContainerChangeKind" : "iz\containers\izContainerChangeKind.html"},
{"iz.containers.izList" : "iz\containers\izList.html"},
{"iz.containers.izList.opIndex" : "iz\containers\izList.html#opIndex"},
{"iz.containers.izList.opIndexAssign" : "iz\containers\izList.html#opIndexAssign"},
{"iz.containers.izList.opApply" : "iz\containers\izList.html#opApply"},
{"iz.containers.izList.opApplyReverse" : "iz\containers\izList.html#opApplyReverse"},
{"iz.containers.izList.last" : "iz\containers\izList.html#last"},
{"iz.containers.izList.first" : "iz\containers\izList.html#first"},
{"iz.containers.izList.find" : "iz\containers\izList.html#find"},
{"iz.containers.izList.add" : "iz\containers\izList.html#add"},
{"iz.containers.izList.insert" : "iz\containers\izList.html#insert"},
{"iz.containers.izList.insert" : "iz\containers\izList.html#insert"},
{"iz.containers.izList.swapItems" : "iz\containers\izList.html#swapItems"},
{"iz.containers.izList.swapIndexes" : "iz\containers\izList.html#swapIndexes"},
{"iz.containers.izList.remove" : "iz\containers\izList.html#remove"},
{"iz.containers.izList.extract" : "iz\containers\izList.html#extract"},
{"iz.containers.izList.clear" : "iz\containers\izList.html#clear"},
{"iz.containers.izList.count" : "iz\containers\izList.html#count"},
{"iz.containers.izStaticList" : "iz\containers\izStaticList.html"},
{"iz.containers.izStaticList.add" : "iz\containers\izStaticList.html#add"},
{"iz.containers.izStaticList.insert" : "iz\containers\izStaticList.html#insert"},
{"iz.containers.izStaticList.insert" : "iz\containers\izStaticList.html#insert"},
{"iz.containers.dlistPayload" : "iz\containers\dlistPayload.html"},
{"iz.containers.izDynamicList" : "iz\containers\izDynamicList.html"},
{"iz.containers.izTreeItem" : "iz\containers\izTreeItem.html"},
{"iz.containers.izTreeItem.prevSibling" : "iz\containers\izTreeItem.html#prevSibling"},
{"iz.containers.izTreeItem.nextSibling" : "iz\containers\izTreeItem.html#nextSibling"},
{"iz.containers.izTreeItem.parent" : "iz\containers\izTreeItem.html#parent"},
{"iz.containers.izTreeItem.firstChild" : "iz\containers\izTreeItem.html#firstChild"},
{"iz.containers.izTreeItem.prevSibling" : "iz\containers\izTreeItem.html#prevSibling"},
{"iz.containers.izTreeItem.nextSibling" : "iz\containers\izTreeItem.html#nextSibling"},
{"iz.containers.izTreeItem.parent" : "iz\containers\izTreeItem.html#parent"},
{"iz.containers.izTreeItem.firstChild" : "iz\containers\izTreeItem.html#firstChild"},
{"iz.containers.izTreeItem.siblings" : "iz\containers\izTreeItem.html#siblings"},
{"iz.containers.izTreeItem.children" : "iz\containers\izTreeItem.html#children"},
{"iz.containers.izTreeItem.hasChanged" : "iz\containers\izTreeItem.html#hasChanged"},
{"iz.containers.izTreeItem.izTreeItemSiblings" : "iz\containers\izTreeItem.izTreeItemSiblings.html"},
{"iz.containers.izTreeItem.izTreeItemSiblings.opIndex" : "iz\containers\izTreeItem.izTreeItemSiblings.html#opIndex"},
{"iz.containers.izTreeItem.izTreeItemSiblings.opIndexAssign" : "iz\containers\izTreeItem.izTreeItemSiblings.html#opIndexAssign"},
{"iz.containers.izTreeItem.izTreeItemSiblings.opApply" : "iz\containers\izTreeItem.izTreeItemSiblings.html#opApply"},
{"iz.containers.izTreeItem.izTreeItemSiblings.opApplyReverse" : "iz\containers\izTreeItem.izTreeItemSiblings.html#opApplyReverse"},
{"iz.containers.izTreeItem.addNewSibling" : "iz\containers\izTreeItem.html#addNewSibling"},
{"iz.containers.izTreeItem.lastSibling" : "iz\containers\izTreeItem.html#lastSibling"},
{"iz.containers.izTreeItem.firstSibling" : "iz\containers\izTreeItem.html#firstSibling"},
{"iz.containers.izTreeItem.findSibling" : "iz\containers\izTreeItem.html#findSibling"},
{"iz.containers.izTreeItem.addSibling" : "iz\containers\izTreeItem.html#addSibling"},
{"iz.containers.izTreeItem.insertSibling" : "iz\containers\izTreeItem.html#insertSibling"},
{"iz.containers.izTreeItem.insertSibling" : "iz\containers\izTreeItem.html#insertSibling"},
{"iz.containers.izTreeItem.exchangeSibling" : "iz\containers\izTreeItem.html#exchangeSibling"},
{"iz.containers.izTreeItem.removeSibling" : "iz\containers\izTreeItem.html#removeSibling"},
{"iz.containers.izTreeItem.removeSibling" : "iz\containers\izTreeItem.html#removeSibling"},
{"iz.containers.izTreeItem.siblingCount" : "iz\containers\izTreeItem.html#siblingCount"},
{"iz.containers.izTreeItem.siblingIndex" : "iz\containers\izTreeItem.html#siblingIndex"},
{"iz.containers.izTreeItem.siblingIndex" : "iz\containers\izTreeItem.html#siblingIndex"},
{"iz.containers.izTreeItem.addNewChildren" : "iz\containers\izTreeItem.html#addNewChildren"},
{"iz.containers.izTreeItem.level" : "iz\containers\izTreeItem.html#level"},
{"iz.containers.izTreeItem.childrenCount" : "iz\containers\izTreeItem.html#childrenCount"},
{"iz.containers.izTreeItem.addChild" : "iz\containers\izTreeItem.html#addChild"},
{"iz.containers.izTreeItem.insertChild" : "iz\containers\izTreeItem.html#insertChild"},
{"iz.containers.izTreeItem.insertChild" : "iz\containers\izTreeItem.html#insertChild"},
{"iz.containers.izTreeItem.removeChild" : "iz\containers\izTreeItem.html#removeChild"},
{"iz.containers.izTreeItem.removeChild" : "iz\containers\izTreeItem.html#removeChild"},
{"iz.containers.izTreeItem.clearChildren" : "iz\containers\izTreeItem.html#clearChildren"},
{"iz.containers.izTreeItem.deleteChildren" : "iz\containers\izTreeItem.html#deleteChildren"},
{"iz.containers.izTreeItemAccessors" : "iz\containers\izTreeItemAccessors.html"},
{"iz.containers.izTreeItemAccessors.prevSibling" : "iz\containers\izTreeItemAccessors.html#prevSibling"},
{"iz.containers.izTreeItemAccessors.nextSibling" : "iz\containers\izTreeItemAccessors.html#nextSibling"},
{"iz.containers.izTreeItemAccessors.parent" : "iz\containers\izTreeItemAccessors.html#parent"},
{"iz.containers.izTreeItemAccessors.firstChild" : "iz\containers\izTreeItemAccessors.html#firstChild"},
{"iz.containers.izTreeItemAccessors.prevSibling" : "iz\containers\izTreeItemAccessors.html#prevSibling"},
{"iz.containers.izTreeItemAccessors.nextSibling" : "iz\containers\izTreeItemAccessors.html#nextSibling"},
{"iz.containers.izTreeItemAccessors.parent" : "iz\containers\izTreeItemAccessors.html#parent"},
{"iz.containers.izTreeItemAccessors.firstChild" : "iz\containers\izTreeItemAccessors.html#firstChild"},
{"iz.containers.izTreeItemAccessors.siblings" : "iz\containers\izTreeItemAccessors.html#siblings"},
{"iz.containers.izTreeItemAccessors.children" : "iz\containers\izTreeItemAccessors.html#children"},
{"iz.containers.izTreeItemAccessors.hasChanged" : "iz\containers\izTreeItemAccessors.html#hasChanged"},
{"iz.containers.izMakeTreeItem" : "iz\containers\izMakeTreeItem.html"},
{"iz.properties" : "iz\properties.html"},
{"iz.properties.izPropAccess" : "iz\properties\izPropAccess.html"},
{"iz.properties.izPropDescriptor" : "iz\properties\izPropDescriptor.html"},
{"iz.properties.izPropDescriptor.izPropSetter" : "iz\properties\izPropDescriptor.html#izPropSetter"},
{"iz.properties.izPropDescriptor.izPropGetter" : "iz\properties\izPropDescriptor.html#izPropGetter"},
{"iz.properties.izPropDescriptor.izPropSetterConst" : "iz\properties\izPropDescriptor.html#izPropSetterConst"},
{"iz.properties.izPropDescriptor.internalSetter" : "iz\properties\izPropDescriptor.html#internalSetter"},
{"iz.properties.izPropDescriptor.internalGetter" : "iz\properties\izPropDescriptor.html#internalGetter"},
{"iz.properties.izPropDescriptor.this" : "iz\properties\izPropDescriptor.html#this"},
{"iz.properties.izPropDescriptor.this" : "iz\properties\izPropDescriptor.html#this"},
{"iz.properties.izPropDescriptor.this" : "iz\properties\izPropDescriptor.html#this"},
{"iz.properties.izPropDescriptor.this" : "iz\properties\izPropDescriptor.html#this"},
{"iz.properties.izPropDescriptor.define" : "iz\properties\izPropDescriptor.html#define"},
{"iz.properties.izPropDescriptor.define" : "iz\properties\izPropDescriptor.html#define"},
{"iz.properties.izPropDescriptor.define" : "iz\properties\izPropDescriptor.html#define"},
{"iz.properties.izPropDescriptor.setter" : "iz\properties\izPropDescriptor.html#setter"},
{"iz.properties.izPropDescriptor.setter" : "iz\properties\izPropDescriptor.html#setter"},
{"iz.properties.izPropDescriptor.setDirectTarget" : "iz\properties\izPropDescriptor.html#setDirectTarget"},
{"iz.properties.izPropDescriptor.set" : "iz\properties\izPropDescriptor.html#set"},
{"iz.properties.izPropDescriptor.getter" : "iz\properties\izPropDescriptor.html#getter"},
{"iz.properties.izPropDescriptor.getter" : "iz\properties\izPropDescriptor.html#getter"},
{"iz.properties.izPropDescriptor.setDirectSource" : "iz\properties\izPropDescriptor.html#setDirectSource"},
{"iz.properties.izPropDescriptor.get" : "iz\properties\izPropDescriptor.html#get"},
{"iz.properties.izPropDescriptor.access" : "iz\properties\izPropDescriptor.html#access"},
{"iz.properties.izPropDescriptor.name" : "iz\properties\izPropDescriptor.html#name"},
{"iz.properties.izPropDescriptor.name" : "iz\properties\izPropDescriptor.html#name"},
{"iz.properties.izPropDescriptor.declarator" : "iz\properties\izPropDescriptor.html#declarator"},
{"iz.properties.izPropDescriptor.declarator" : "iz\properties\izPropDescriptor.html#declarator"},
{"iz.properties.Set" : "iz\properties\Set.html"},
{"iz.properties.Get" : "iz\properties\Get.html"},
{"iz.properties.SetGet" : "iz\properties\SetGet.html"},
{"iz.properties.GetSet" : "iz\properties.html#GetSet"},
{"iz.properties.genPropFromField" : "iz\properties.html#genPropFromField"},
{"iz.properties.izPropertiesAnalyzer" : "iz\properties\izPropertiesAnalyzer.html"},
{"iz.properties.izPropertiesAnalyzer.descriptors" : "iz\properties\izPropertiesAnalyzer.html#descriptors"},
{"iz.properties.izPropertiesAnalyzer.descriptorCount" : "iz\properties\izPropertiesAnalyzer.html#descriptorCount"},
{"iz.properties.izPropertiesAnalyzer.getDescriptor" : "iz\properties\izPropertiesAnalyzer.html#getDescriptor"},
{"iz.properties.izPropertiesAnalyzer.getUntypedDescriptor" : "iz\properties\izPropertiesAnalyzer.html#getUntypedDescriptor"},
{"iz.properties.izPropertiesAnalyzer.analyzeAll" : "iz\properties\izPropertiesAnalyzer.html#analyzeAll"},
{"iz.properties.izPropertiesAnalyzer.analyzeFields" : "iz\properties\izPropertiesAnalyzer.html#analyzeFields"},
{"iz.properties.izPropertiesAnalyzer.analyzeVirtualSetGet" : "iz\properties\izPropertiesAnalyzer.html#analyzeVirtualSetGet"},
{"iz.properties.izPropertyBinder" : "iz\properties\izPropertyBinder.html"},
{"iz.properties.izPropertyBinder.addBinding" : "iz\properties\izPropertyBinder.html#addBinding"},
{"iz.properties.izPropertyBinder.newBinding" : "iz\properties\izPropertyBinder.html#newBinding"},
{"iz.properties.izPropertyBinder.removeBinding" : "iz\properties\izPropertyBinder.html#removeBinding"},
{"iz.properties.izPropertyBinder.change" : "iz\properties\izPropertyBinder.html#change"},
{"iz.properties.izPropertyBinder.updateFromSource" : "iz\properties\izPropertyBinder.html#updateFromSource"},
{"iz.properties.izPropertyBinder.source" : "iz\properties\izPropertyBinder.html#source"},
{"iz.properties.izPropertyBinder.source" : "iz\properties\izPropertyBinder.html#source"},
{"iz.properties.izPropertyBinder.items" : "iz\properties\izPropertyBinder.html#items"},
{"iz.referencable" : "iz\referencable.html"},
{"iz.referencable.izReferenced" : "iz\referencable\izReferenced.html"},
{"iz.referencable.izReferenced.refID" : "iz\referencable\izReferenced.html#refID"},
{"iz.referencable.izReferenced.refType" : "iz\referencable\izReferenced.html#refType"},
{"iz.referencable.itemsById" : "iz\referencable.html#itemsById"},
{"iz.referencable.refStore" : "iz\referencable.html#refStore"},
{"iz.referencable.izReferenceMan" : "iz\referencable\izReferenceMan.html"},
{"iz.referencable.izReferenceMan.isTypeStored" : "iz\referencable\izReferenceMan.html#isTypeStored"},
{"iz.referencable.izReferenceMan.isReferenced" : "iz\referencable\izReferenceMan.html#isReferenced"},
{"iz.referencable.izReferenceMan.reset" : "iz\referencable\izReferenceMan.html#reset"},
{"iz.referencable.izReferenceMan.storeType" : "iz\referencable\izReferenceMan.html#storeType"},
{"iz.referencable.izReferenceMan.getIDProposal" : "iz\referencable\izReferenceMan.html#getIDProposal"},
{"iz.referencable.izReferenceMan.storeReference" : "iz\referencable\izReferenceMan.html#storeReference"},
{"iz.referencable.izReferenceMan.removeReference" : "iz\referencable\izReferenceMan.html#removeReference"},
{"iz.referencable.izReferenceMan.removeReference" : "iz\referencable\izReferenceMan.html#removeReference"},
{"iz.referencable.izReferenceMan.referenceID" : "iz\referencable\izReferenceMan.html#referenceID"},
{"iz.referencable.izReferenceMan.reference" : "iz\referencable\izReferenceMan.html#reference"},
{"iz.observer" : "iz\observer.html"},
{"iz.observer.izSubject" : "iz\observer\izSubject.html"},
{"iz.observer.izSubject.acceptObserver" : "iz\observer\izSubject.html#acceptObserver"},
{"iz.observer.izSubject.addObserver" : "iz\observer\izSubject.html#addObserver"},
{"iz.observer.izSubject.removeObserver" : "iz\observer\izSubject.html#removeObserver"},
{"iz.observer.izSubject.updateObservers" : "iz\observer\izSubject.html#updateObservers"},
{"iz.observer.izCustomSubject" : "iz\observer\izCustomSubject.html"},
{"iz.observer.izObserverInterconnector" : "iz\observer\izObserverInterconnector.html"},
{"iz.observer.izObserverInterconnector.beginUpdate" : "iz\observer\izObserverInterconnector.html#beginUpdate"},
{"iz.observer.izObserverInterconnector.endUpdate" : "iz\observer\izObserverInterconnector.html#endUpdate"},
{"iz.observer.izObserverInterconnector.addObserver" : "iz\observer\izObserverInterconnector.html#addObserver"},
{"iz.observer.izObserverInterconnector.addObservers" : "iz\observer\izObserverInterconnector.html#addObservers"},
{"iz.observer.izObserverInterconnector.removeObserver" : "iz\observer\izObserverInterconnector.html#removeObserver"},
{"iz.observer.izObserverInterconnector.addSubject" : "iz\observer\izObserverInterconnector.html#addSubject"},
{"iz.observer.izObserverInterconnector.addSubjects" : "iz\observer\izObserverInterconnector.html#addSubjects"},
{"iz.observer.izObserverInterconnector.removeSubject" : "iz\observer\izObserverInterconnector.html#removeSubject"},
{"iz.observer.izObserverInterconnector.updateObservers" : "iz\observer\izObserverInterconnector.html#updateObservers"},
{"iz.observer.izObserverInterconnector.updateAll" : "iz\observer\izObserverInterconnector.html#updateAll"},
{"iz.observer.izEnumBasedObserver" : "iz\observer\izEnumBasedObserver.html"},
{"iz.observer.izEnumBasedObserver.subjectNotification" : "iz\observer\izEnumBasedObserver.html#subjectNotification"},
{"iz.observer.izCustomSubject" : "iz\observer\izCustomSubject.html"},
{"iz.serializer" : "iz\serializer.html"},
{"iz.serializer.izSerializable" : "iz\serializer\izSerializable.html"},
{"iz.serializer.izSerializable.className" : "iz\serializer\izSerializable.html#className"},
{"iz.serializer.izSerializable.declareProperties" : "iz\serializer\izSerializable.html#declareProperties"},
{"iz.serializer.izSerializableReference" : "iz\serializer\izSerializableReference.html"},
{"iz.serializer.izSerializableReference.storeReference" : "iz\serializer\izSerializableReference.html#storeReference"},
{"iz.serializer.izSerializableReference.restoreReference" : "iz\serializer\izSerializableReference.html#restoreReference"},
{"iz.serializer.izSerType" : "iz\serializer\izSerType.html"},
{"iz.serializer.izSerNodeInfo" : "iz\serializer\izSerNodeInfo.html"},
{"iz.serializer.WantDescriptorEvent" : "iz\serializer.html#WantDescriptorEvent"},
{"iz.serializer.nodeInfo2Declarator" : "iz\serializer.html#nodeInfo2Declarator"},
{"iz.serializer.value2text" : "iz\serializer.html#value2text"},
{"iz.serializer.text2value" : "iz\serializer.html#text2value"},
{"iz.serializer.setNodeInfo" : "iz\serializer.html#setNodeInfo"},
{"iz.serializer.izIstNode" : "iz\serializer\izIstNode.html"},
{"iz.serializer.izSerWriter" : "iz\serializer.html#izSerWriter"},
{"iz.serializer.izSerReader" : "iz\serializer.html#izSerReader"},
{"iz.serializer.izSerState" : "iz\serializer\izSerState.html"},
{"iz.serializer.izStoreMode" : "iz\serializer\izStoreMode.html"},
{"iz.serializer.izRestoreMode" : "iz\serializer\izRestoreMode.html"},
{"iz.serializer.izSerFormat" : "iz\serializer\izSerFormat.html"},
{"iz.serializer.izSerializer" : "iz\serializer\izSerializer.html"},
{"iz.serializer.izSerializer.objectToIst" : "iz\serializer\izSerializer.html#objectToIst"},
{"iz.serializer.izSerializer.objectToStream" : "iz\serializer\izSerializer.html#objectToStream"},
{"iz.serializer.izSerializer.istToStream" : "iz\serializer\izSerializer.html#istToStream"},
{"iz.serializer.izSerializer.streamToIst" : "iz\serializer\izSerializer.html#streamToIst"},
{"iz.serializer.izSerializer.streamToObject" : "iz\serializer\izSerializer.html#streamToObject"},
{"iz.serializer.izSerializer.istToObject" : "iz\serializer\izSerializer.html#istToObject"},
{"iz.serializer.izSerializer.findNode" : "iz\serializer\izSerializer.html#findNode"},
{"iz.serializer.izSerializer.istToObject" : "iz\serializer\izSerializer.html#istToObject"},
{"iz.serializer.izSerializer.restoreProperty" : "iz\serializer\izSerializer.html#restoreProperty"},
{"iz.serializer.izSerializer.addProperty" : "iz\serializer\izSerializer.html#addProperty"},
{"iz.serializer.izSerializer.state" : "iz\serializer\izSerializer.html#state"},
{"iz.serializer.izSerializer.storeMode" : "iz\serializer\izSerializer.html#storeMode"},
{"iz.serializer.izSerializer.restoreMode" : "iz\serializer\izSerializer.html#restoreMode"},
{"iz.serializer.izSerializer.serializationFormat" : "iz\serializer\izSerializer.html#serializationFormat"},
{"iz.serializer.izSerializer.serializationTree" : "iz\serializer\izSerializer.html#serializationTree"},
{"iz.serializer.izSerializer.onWantDescriptor" : "iz\serializer\izSerializer.html#onWantDescriptor"},
{"iz.serializer.izSerializer.onWantDescriptor" : "iz\serializer\izSerializer.html#onWantDescriptor"},
{"iz.classes" : "iz\classes.html"},
{"iz.classes.izSerializableList" : "iz\classes\izSerializableList.html"},
{"iz.classes.izSerializableList.declareProperties" : "iz\classes\izSerializableList.html#declareProperties"},
{"iz.classes.izSerializableList.this" : "iz\classes\izSerializableList.html#this"},
{"iz.classes.izSerializableList.addItem" : "iz\classes\izSerializableList.html#addItem"},
{"iz.classes.izSerializableList.deleteItem" : "iz\classes\izSerializableList.html#deleteItem"},
{"iz.classes.izSerializableList.items" : "iz\classes\izSerializableList.html#items"},
{"iz.classes.izSerializableList.clear" : "iz\classes\izSerializableList.html#clear"},
{"iz.enumset" : "iz\enumset.html"},
{"iz.enumset.Set8" : "iz\enumset.html#Set8"},
{"iz.enumset.Set16" : "iz\enumset.html#Set16"},
{"iz.enumset.Set32" : "iz\enumset.html#Set32"},
{"iz.enumset.Set64" : "iz\enumset.html#Set64"},
{"iz.enumset.isSetSuitable" : "iz\enumset.html#isSetSuitable"},
{"iz.enumset.enumMemberCount" : "iz\enumset.html#enumMemberCount"},
{"iz.enumset.izEnumRankInfo" : "iz\enumset\izEnumRankInfo.html"},
{"iz.enumset.izEnumRankInfo.max" : "iz\enumset\izEnumRankInfo.html#max"},
{"iz.enumset.izEnumRankInfo.count" : "iz\enumset\izEnumRankInfo.html#count"},
{"iz.enumset.izEnumRankInfo.min" : "iz\enumset\izEnumRankInfo.html#min"},
{"iz.enumset.izEnumRankInfo.opIndex" : "iz\enumset\izEnumRankInfo.html#opIndex"},
{"iz.enumset.izEnumRankInfo.opIndex" : "iz\enumset\izEnumRankInfo.html#opIndex"},
{"iz.enumset.enumFitsInSet" : "iz\enumset.html#enumFitsInSet"},
{"iz.enumset.izEnumSet" : "iz\enumset\izEnumSet.html"},
{"iz.enumset.izEnumSet.this" : "iz\enumset\izEnumSet.html#this"},
{"iz.enumset.izEnumSet.this" : "iz\enumset\izEnumSet.html#this"},
{"iz.enumset.izEnumSet.this" : "iz\enumset\izEnumSet.html#this"},
{"iz.enumset.izEnumSet.this" : "iz\enumset\izEnumSet.html#this"},
{"iz.enumset.izEnumSet.this" : "iz\enumset\izEnumSet.html#this"},
{"iz.enumset.izEnumSet.asBitString" : "iz\enumset\izEnumSet.html#asBitString"},
{"iz.enumset.izEnumSet.toString" : "iz\enumset\izEnumSet.html#toString"},
{"iz.enumset.izEnumSet.fromString" : "iz\enumset\izEnumSet.html#fromString"},
{"iz.enumset.izEnumSet.opAssign" : "iz\enumset\izEnumSet.html#opAssign"},
{"iz.enumset.izEnumSet.opAssign" : "iz\enumset\izEnumSet.html#opAssign"},
{"iz.enumset.izEnumSet.opAssign" : "iz\enumset\izEnumSet.html#opAssign"},
{"iz.enumset.izEnumSet.opIndex" : "iz\enumset\izEnumSet.html#opIndex"},
{"iz.enumset.izEnumSet.opIndex" : "iz\enumset\izEnumSet.html#opIndex"},
{"iz.enumset.izEnumSet.opBinary" : "iz\enumset\izEnumSet.html#opBinary"},
{"iz.enumset.izEnumSet.opBinary" : "iz\enumset\izEnumSet.html#opBinary"},
{"iz.enumset.izEnumSet.opBinary" : "iz\enumset\izEnumSet.html#opBinary"},
{"iz.enumset.izEnumSet.opOpAssign" : "iz\enumset\izEnumSet.html#opOpAssign"},
{"iz.enumset.izEnumSet.opOpAssign" : "iz\enumset\izEnumSet.html#opOpAssign"},
{"iz.enumset.izEnumSet.opOpAssign" : "iz\enumset\izEnumSet.html#opOpAssign"},
{"iz.enumset.izEnumSet.opEquals" : "iz\enumset\izEnumSet.html#opEquals"},
{"iz.enumset.izEnumSet.opIn_r" : "iz\enumset\izEnumSet.html#opIn_r"},
{"iz.enumset.izEnumSet.include" : "iz\enumset\izEnumSet.html#include"},
{"iz.enumset.izEnumSet.include" : "iz\enumset\izEnumSet.html#include"},
{"iz.enumset.izEnumSet.exclude" : "iz\enumset\izEnumSet.html#exclude"},
{"iz.enumset.izEnumSet.exclude" : "iz\enumset\izEnumSet.html#exclude"},
{"iz.enumset.izEnumSet.isIncluded" : "iz\enumset\izEnumSet.html#isIncluded"},
{"iz.enumset.izEnumSet.none" : "iz\enumset\izEnumSet.html#none"},
{"iz.enumset.izEnumSet.any" : "iz\enumset\izEnumSet.html#any"},
{"iz.enumset.izEnumSet.all" : "iz\enumset\izEnumSet.html#all"},
{"iz.enumset.izEnumSet.max" : "iz\enumset\izEnumSet.html#max"},
{"iz.enumset.izEnumSet.rankInfo" : "iz\enumset\izEnumSet.html#rankInfo"},
{"iz.enumset.izEnumSet.memberCount" : "iz\enumset\izEnumSet.html#memberCount"},
{"iz.enumset.isCallableFromEnum" : "iz\enumset.html#isCallableFromEnum"},
{"iz.enumset.izEnumProcs" : "iz\enumset\izEnumProcs.html"},
{"iz.enumset.izEnumProcs.this" : "iz\enumset\izEnumProcs.html#this"},
{"iz.enumset.izEnumProcs.this" : "iz\enumset\izEnumProcs.html#this"},
{"iz.enumset.izEnumProcs.opIndex" : "iz\enumset\izEnumProcs.html#opIndex"},
{"iz.enumset.izEnumProcs.opCall" : "iz\enumset\izEnumProcs.html#opCall"},
{"iz.enumset.izEnumProcs.opCall" : "iz\enumset\izEnumProcs.html#opCall"},
{"iz.enumset.izEnumProcs.procs" : "iz\enumset\izEnumProcs.html#procs"},
{"iz.enumset.izEnumIndexedArray" : "iz\enumset\izEnumIndexedArray.html"},
{"iz.enumset.izEnumIndexedArray.length" : "iz\enumset\izEnumIndexedArray.html#length"},
{"iz.enumset.izEnumIndexedArray.length" : "iz\enumset\izEnumIndexedArray.html#length"},
{"iz.enumset.izEnumIndexedArray.opIndex" : "iz\enumset\izEnumIndexedArray.html#opIndex"},
{"iz.enumset.izEnumIndexedArray.opIndexAssign" : "iz\enumset\izEnumIndexedArray.html#opIndexAssign"},
{"iz.enumset.izEnumIndexedArray.opSlice" : "iz\enumset\izEnumIndexedArray.html#opSlice"},
];
function search(str) {
	var re = new RegExp(str.toLowerCase());
	var ret = {};
	for (var i = 0; i < items.length; i++) {
		var k = Object.keys(items[i])[0];
		if (re.test(k.toLowerCase()))
			ret[k] = items[i][k];
	}
	return ret;
}

function searchSubmit(value, event) {
	console.log("searchSubmit");
	var resultTable = document.getElementById("results");
	while (resultTable.firstChild)
		resultTable.removeChild(resultTable.firstChild);
	if (value === "" || event.keyCode == 27) {
		resultTable.style.display = "none";
		return;
	}
	resultTable.style.display = "block";
	var results = search(value);
	var keys = Object.keys(results);
	if (keys.length === 0) {
		var row = resultTable.insertRow();
		var td = document.createElement("td");
		var node = document.createTextNode("No results");
		td.appendChild(node);
		row.appendChild(td);
		return;
	}
	for (var i = 0; i < keys.length; i++) {
		var k = keys[i];
		var v = results[keys[i]];
		var link = document.createElement("a");
		link.href = v;
		link.textContent = k;
		link.attributes.id = "link" + i;
		var row = resultTable.insertRow();
		row.appendChild(link);
	}
}

function hideSearchResults(event) {
	if (event.keyCode != 27)
		return;
	var resultTable = document.getElementById("results");
	while (resultTable.firstChild)
		resultTable.removeChild(resultTable.firstChild);
	resultTable.style.display = "none";
}

