////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data export import".
//
////////////////////////////////////////////////////////////////////////////////

// Procedures and functions of this module provide
// the possibility of mapping and recreating the refs, stored in the value storages.
// In this case without additional data processor matching
// refs is no possible, as values, recorded in the value storages
// during serializing are written in XML as base64.
//

#Region DataExportImportHandlersRegistration

// It is called on the registration of the arbitrary handlers of data export.
//
// Parameters: HandlersTable - ValueTable, in
//  this procedure it is required to supplement this
//  table of values with information about registered random export data handlers. Columns:
//    MetadataObject - MetadataObject, when exporting
//      the data of which the registered handler must be called,
//    Handler - GeneralModule, a general module in
//      which random handler of the data export implemented. Set of export procedures
//      that must be implemented in the handler, depends on
//      the set values of the following table columns,
//    Version - String - Interface version number of exporting/importing
//      data handlers, supported by handler, 
//    BeforeExportType - Boolean, a flag showing that a handler is to be called before exporting all the infobase objects that are associated with the metadata object. If the True value is set - in the general module
//      of a handler, exported procedure
//      BeforeExportType() must be implemented, that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application data processor interface DataExportImportContainerManager, 
//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler 
//            requires additional data export - You should use SerializerXDTO that is passed to
//            the procedure BeforeExportType() as the parameter value of Serializer rather
//            than received by using the global context properties SerializerXDTO,
//        MetadataObject - MetadataObject before exporting
//            data of which the handler was called, 
//        Cancel - Boolean. If in the BeforeExportType() procedure set this parameter as True - exporting
//          of objects corresponding to the current metadata object will not be executed.
//    BeforeObjectExport - Boolean, a flag showing that it is required to call a handler before exporting a particular object of the infobase. If the
//      True value is set - in the general module of a handler, exported procedure must be implemented 
//      BeforeObjectExport() that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application data processor interface DataExportImportContainerManager,
//         ExportObjectManager - DataProcessorObject.DataExportImportInfobaseDataExportManager -
//          Manager of the current object export. See more the review to the
//          application data processor interface DataExportImportInfobaseDataExportManager.   
//          The parameter is passed only on the call of the handler procedures for which version higher than 1.0.0.1 is specified on registration, 
//         Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler 
//          requires additional data export - Youshould use SerializerXDTO that is passed to the procedure BeforeObjectExport() 
//          as the parameter value of Serializer rather than received
//          by using the global context properties SerializerXDTO, 
//         Object - ConstantValueManager.*, CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base before exporting of which the handler was called.
//          Value that is passed to the BeforeObjectExport() procedure as the Object parameter value can be modified within the BeforeObjectExport() 
//          processor, made changes will be shown in the object serialization of export files, but will not be recorded in the infobase
//        Artifacts  - Array (XDTOObject) - set of additional information logically
//          connected inextricably with the object but not not being his part artifacts object). Artifacts
//          should formed inside handler BeforeObjectExport() and added
//          to the array passed as parameter values Artifacts. Each artifact must be the XDTOobject for which type,
//          as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. 
//          It is allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem. Further
//          artifacts that are formed in the procedure BeforeObjectExport(), will
//          be available in handlers procedures of data import (see review for the procedure WhenDataImportHandlersRegistration().
//        Cancel - Boolean. If you set True for the parameter in procedure BeforeObjectExport()- object export for which the
//           handler was called will not be executed.
//    AfterExportType() - Boolean, a flag showing that a handler is to be called after exporting all objects of the infobase that belongs to that metadata object. If the
//      True value is set - in a general module of the handler, exported procedure AfterExportType() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application data processor interface DataExportImportContainerManager, 
//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. 
//          If a random exporting handler requires additional data export - Yo ushould use SerializerXDTO that is passed to
//          the procedure AfterExportType() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO,
//         MetadataObject - MetadataObject, after exporting
//          data of which the handler was called.
//
Procedure WhenDataImportHandlersRegistration(HandlersTable) Export
	
	MetadataList = ValueStorageDataExportImportReUse.MetadataObjectListWithValueStorage();
	
	For Each ItemOfList IN MetadataList Do
		
		NewHandler = HandlersTable.Add();
		NewHandler.MetadataObject = Metadata.FindByFullName(ItemOfList.Key);
		NewHandler.Handler = ValueStorageDataExportImport;
		NewHandler.BeforeObjectExport = True;
		NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
		
	EndDo;
	
	NewHandler = HandlersTable.Add();
	NewHandler.Handler = ValueStorageDataExportImport;
	NewHandler.BeforeExportSettings = True;
	NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
	
EndProcedure

// It is called on registering the data import arbitrary handlers.
//
// Parameters: HandlersTable - ValueTable, in
//  this procedure it is required to supplement this
//  table of values with information about registered random import data handlers. Columns:
//    MetadataObject - MetadataObject, when importing
//      the data of which the registered handler must be called,
//     Handler - CommonModule, a common module in which a random handler of the data import is implemented. Set of export procedures
//      that must be implemented in the handler, depends on
//      the set values of the following table columns,
//     Version - String - Interface version number of exporting/importing
//      data handlers, supported by handler 
//    BeforeMatchRefs - Boolean, a flag showing that a handler is to be called before matching the references (in original and current IB) that belong to the metadata object. If the True value is set - in a general module of the handler, exported procedure BeforeMatchRefs() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        MetadataObject - MetadataObject before mapping the references of which the handler was called, StandardProcessor - Boolean. If procedure
//          BeforeMatchRefs() install that False parameter value instead of
//          standard mathcing refs (search of objects in the current IB with
//          the same natural key values, that were exported
//          from the IBsource) function MatchRefs() will be
//          called of general module, in
//          the procedure BeforeMatchRefs() which the value parameter StandardDataProcessor  was installed to False.
//          MatchRefs() function parameters:
//            Container - DataProcessorObject.DataExportImportContainerManager - manager
//              of a container that is used in the data import process. See more
//              the review to the application processing interface DataExportImportContainerManager, 
//            SourceLinksTable - ValueTable, that contains information about the refs exported from the original IB. Columns:
//                SourceRef - AnyRef, object ref of original IB, which is required to be mapped with the ref of current IB, Remaining columns of equal fields of natural object key that were passed to the DataExportImportInfobase.RequiredMatchRefsOnImport() function during data export Function's return value MatchRefs() - ValueTable, columns:
//            SourceRef - AnyReference, object refs, exported from the original IB, 
//            Refs - AnyRef mapped with the original reference in current IB.
//        Cancel - Boolean. If you set True for the parameter in procedure BeforeMatchRefs() - mapping of the references corresponding to the current metadata object will not be executed.
//    BeforeImportType - Boolean, the flag showing the necessity to call the handler before importing all data objects that belong to that metadata object. If the True value is set - in a general module of the handler, exported procedure BeforeImportType() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process. 
//          For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        MetadataObject - MetadataObject, before importing
//          all data of which the handler was called, 
//        Cancel - Boolean. If you set True for the parameter in procedure BeforeImportType()- all data objects corresponding to the current metadata object will not be imported.
//    BeforeObjectImport - Boolean, the flag showing the necessity to call the handler before importing the data object that belongs to that metadata object. If the True value is set - in a general module of the handler, the BeforeObjectImport() exported procedure must be implemented supporting the parameters as follows:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process.
//          For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base before importing of which the handler was called.
//          Value that is passed to procedure BeforeObjectImport() as the Object parameter value can be modified within the handler procedure BeforeObjectImport().
//        Artifacts - Array(XDTOObject) - additional data that is logically inextricably associated with the data object, 
//          but not being part of it. Created in exported procedures BeforeObjectExport() of data export handlers (see a comment to procedure OnDataExportHandlersRegistration(). Each artifact must be the XDTOobject for which type, as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. 
//          It is allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem.
//        Cancel - Boolean. If you set this parameter value to True in the BeforeObjectImport() procedure - Import of the data object will not be executed.
//    AftertObjectImport - Boolean, the flag showing the necessity to call the handler after importing the data object that belongs to that metadata object. If the True value is set - in a general module of the handler, the AftertObjectImport() exported procedure must be implemented supporting the parameters as follows:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process.
//          For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base after importing of which the handler was called.
//        Artifacts - Array(XDTOObject) - additional data that is logically inextricably associated with the data object, 
//          but not being part of it. Created in exported procedures BeforeObjectExport() of data export handlers (see a comment to procedure OnDataExportHandlersRegistration(). Each artifact must be the XDTOobject for which type, as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. 
//          It is allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem.
//    AfterImportType - Boolean, the flag showing the necessity to call the handler after importing all data objects that belong to that metadata object. If the True value is set - in a general module of the handler, the AfterImportType() exported procedure must be implemented supporting the parameters as follows:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process. 
//          For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        MetadataObject - MetadataObject, after importing
//          all objects of which the handler was called.
//
Procedure WhenDataExportHandlersRegistration(HandlersTable) Export
	
	MetadataList = ValueStorageDataExportImportReUse.MetadataObjectListWithValueStorage();
	
	For Each ItemOfList IN MetadataList Do
		
		NewHandler = HandlersTable.Add();
		NewHandler.MetadataObject = Metadata.FindByFullName(ItemOfList.Key);
		NewHandler.Handler = ValueStorageDataExportImport;
		NewHandler.BeforeObjectImport = True;
		NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
		
	EndDo;
	
	NewHandler = HandlersTable.Add();
	NewHandler.Handler = ValueStorageDataExportImport;
	NewHandler.BeforeLoadSettings = True;
	NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
	
EndProcedure

#EndRegion

#Region DataExportImportHandlers

//Called before exporting the object.
//  see "OnRegisteringDataExportHandlers"
//
Procedure BeforeObjectExport(Container, ObjectExportManager, Serializer, Object, Artifacts, Cancel) Export
	
	MetadataObject = Object.Metadata();
	AttributesWithValuesStorage = ObjectAttributesWithValuesStorage(Container, MetadataObject);
	
	If AttributesWithValuesStorage = Undefined Then
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en = '%1 metadata object can not be processed by the handler ValueStorageDataExportImport.BeforeObjectExport()!'"),
			MetadataObject.FullName());
		
	EndIf;
	
	If CommonUseSTL.ThisIsConstant(MetadataObject) Then
		
		BeforeExportConstant(Container, Object, Artifacts, AttributesWithValuesStorage);
		
	ElsIf CommonUseSTL.ThisIsReferenceData(MetadataObject) Then
		
		BeforeExportReferenceObject(Container, Object, Artifacts, AttributesWithValuesStorage);
		
	ElsIf CommonUseSTL.ThisIsRecordSet(MetadataObject) Then
		
		BeforeExportRecordSet(Container, Object, Artifacts, AttributesWithValuesStorage);
		
	Else
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en = 'Unexpected metadata object: %1!'"),
			MetadataObject.DescriptionFull);
		
	EndIf;
	
EndProcedure

Procedure BeforeExportSettings(Container, Serializer, SettingsStorageName, SettingsKey, ObjectKey, Settings, User, Presentation, Artifacts, Cancel) Export
	
	If TypeOf(Settings) = Type("ValueStorage") Then
		
		NewArtifact = XDTOFactory.Create(ArtifactTypeValueStorage());
		NewArtifact.Owner = XDTOFactory.Create(OwnerTypeBody());
		
		If ExportValueStorage(Container, Settings, NewArtifact.Data) Then
			Settings = Undefined;
			Artifacts.Add(NewArtifact);
		EndIf;
		
	EndIf;
	
EndProcedure

//Called before exporting the object.
//  see "OnRegisteringDataExportHandlers"
//
Procedure BeforeObjectImport(Container, Object, Artifacts, Cancel) Export
	
	MetadataObject = Object.Metadata();
	
	For Each Artifact IN Artifacts Do
		
		If Artifact.Type() <> ArtifactTypeValueStorage() Then
			Continue;
		EndIf;
		
		If CommonUseSTL.ThisIsConstant(MetadataObject) Then
			
			BeforeUpdateConstant(Container, Object, Artifact);
			
		ElsIf CommonUseSTL.ThisIsReferenceData(MetadataObject) Then
			
			BeforeImportReferenceObject(Container, Object, Artifact);
			
		ElsIf CommonUseSTL.ThisIsRecordSet(MetadataObject) Then
			
			BeforeImportRecordSet(Container, Object, Artifact);
			
		Else
			
			Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
				NStr("en = 'Unexpected metadata object: %1!'"),
				MetadataObject.DescriptionFull);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure BeforeLoadSettings(Container, SettingsStorageName, SettingsKey, ObjectKey, Settings, User, Presentation, Artifacts, Cancel) Export
	
	For Each Artifact IN Artifacts Do
		
		If Artifact.Type() = ArtifactTypeValueStorage() AND Artifact.Owner.Type() = OwnerTypeBody() Then
			
			ImportValueStorage(Container, Settings, Artifact);
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Data export of the values storages

// It is called before exporting the constant with the value storage.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// Object - object of the exported data.
// Artifacts - Array - array of the artifacts (XDTO Objects).
// AttributesWithValuesStorage - Array - array of structures see "AttributesStructureWithValueStorage".
//
Procedure BeforeExportConstant(Container, Object, Artifacts, AttributesWithValuesStorage)
	
	NewArtifact = XDTOFactory.Create(ArtifactTypeValueStorage());
	NewArtifact.Owner = XDTOFactory.Create(ConstantOwnerType());
	
	If ExportValueStorage(Container, Object.Value, NewArtifact.Data) Then
		Object.Value = New ValueStorage(Undefined);
		Artifacts.Add(NewArtifact);
	EndIf;
	
EndProcedure

// It is called before exporting the reference object with the value storage.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// Object - object of the exported data.
// Artifacts - Array - array of the artifacts (XDTO Objects).
// AttributesWithValuesStorage - Array - array of structures see "AttributesStructureWithValueStorage".
//
Procedure BeforeExportReferenceObject(Container, Object, Artifacts, AttributesWithValuesStorage)
	
	For Each CurrentAttribute IN AttributesWithValuesStorage Do
		
		If CurrentAttribute.TabularSectionName = Undefined Then
			
			AttributeName = CurrentAttribute.AttributeName;
			
			NewArtifact = XDTOFactory.Create(ArtifactTypeValueStorage());
			NewArtifact.Owner = XDTOFactory.Create(OwnerTypeObject());
			NewArtifact.Owner.Property = AttributeName;
			
			If ExportValueStorage(Container, Object[AttributeName], NewArtifact.Data) Then
				Object[AttributeName] = New ValueStorage(Undefined);
				Artifacts.Add(NewArtifact);
			EndIf;
			
		Else
			
			AttributeName      = CurrentAttribute.AttributeName;
			TabularSectionName = CurrentAttribute.TabularSectionName;
			
			For Each TabularSectionRow IN Object[TabularSectionName] Do 
				
				NewArtifact = XDTOFactory.Create(ArtifactTypeValueStorage());
				NewArtifact.Owner = XDTOFactory.Create(OwnerTypeTabularSection());
				NewArtifact.Owner.TabularSection = TabularSectionName;
				NewArtifact.Owner.Property = AttributeName;
				NewArtifact.Owner.LineNumber = TabularSectionRow.LineNumber;
				
				If ExportValueStorage(Container, TabularSectionRow[AttributeName], NewArtifact.Data) Then
					TabularSectionRow[AttributeName] = New ValueStorage(Undefined);
					Artifacts.Add(NewArtifact);
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// It is called before exporting of object's record set with value storage.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// Object - object of the exported data.
// Artifacts - Array - array of the artifacts (XDTO Objects).
// AttributesWithValuesStorage - Array - array of structures see "AttributesStructureWithValueStorage".
//
Procedure BeforeExportRecordSet(Container, RecordSet, Artifacts, AttributesWithValuesStorage)
	
	For Each CurrentAttribute IN AttributesWithValuesStorage Do
		
		PropertyName = CurrentAttribute.AttributeName;
		
		For Each Record IN RecordSet Do
			
			NewArtifact = XDTOFactory.Create(ArtifactTypeValueStorage());
			NewArtifact.Owner = XDTOFactory.Create(OwnerTypeRecordSet());
			NewArtifact.Owner.Property = PropertyName;
			NewArtifact.Owner.LineNumber = RecordSet.IndexOf(Record);
			
			If ExportValueStorage(Container, Record[PropertyName], NewArtifact.Data) Then
				Record[PropertyName] = New ValueStorage(Undefined);
				Artifacts.Add(NewArtifact);
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Export the values storage.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// ValueStorage - ValuesStorage - storage.
// Artifact - XDTODataObject - artifact.
//
// Returns:
// Boolean - True if exported.
//
Function ExportValueStorage(Container, ValueStorage, Artifact)
	
	If ValueStorage = Null Then
		// For example attributes values that are used
		// only for catalog items, read from catalog group
		Return False;
	EndIf;
	
	Value = ValueStorage.Get();
	If Value = Undefined OR
		(CommonUseSTL.IsPrimitiveType(TypeOf(Value)) AND Not ValueIsFilled(Value)) Then
		Return False;
	Else
		
		Try
			
			Artifact = WriteValueStorageInArtifact(Container, Value);
			Return True;
			
		Except
			
			Return False; // If it is not managed to serialize the storage - leave it in the object
			
		EndTry;
		
	EndIf;
	
EndFunction

// Write the value storage to the artifact.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// ValueStore - AnyType - storage value.
//
// Return value:
// XDTODataObject - artifact.
//
Function WriteValueStorageInArtifact(Container, Val ValueStore)
	
	ExportAsBinary = TypeOf(ValueStore) = Type("BinaryData");
	
	If ExportAsBinary Then
		
		Return WriteBinaryValueStorageInArtifact(Container, ValueStore);
		
	Else
		
		Return WriteSerializableValueStorageInArtifact(Container, ValueStore);
		
	EndIf;
	
EndFunction

// Write the serializable value to the artifact.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// ValueStore - AnyType - storage value.
//
// Return value:
// XDTODataObject - artifact.
//
Function WriteSerializableValueStorageInArtifact(Container, Val ValueStore)
	
	ValueDescription = XDTOFactory.Create(SerializableValueType());
	ValueDescription.Data = XDTOSerializer.WriteXDTO(ValueStore);
	
	Return ValueDescription;
	
EndFunction

// Write the binary value to the artifact.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// ValueStore - AnyType - storage value.
//
// Return value:
// XDTODataObject - artifact.
//
Function WriteBinaryValueStorageInArtifact(Container, Val ValueStore)
	
	FileName = Container.CreateRandomFile("bin");
	ValueStore.Write(FileName);
	
	ValueDescription = XDTOFactory.Create(BinaryValueType());
	ValueDescription.RelativeFilePath = Container.GetRelativeFileName(FileName);
	
	Return ValueDescription;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Data import of the values storages

//It is called before import of constant.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// Object - ConstantValueManager - manager of the constant value.
// Artifact - XDTOObject - artifact.
//
Procedure BeforeUpdateConstant(Container, Object, Artifact)
	
	If Artifact.Owner.Type() = ConstantOwnerType() Then
		ImportValueStorage(Container, Object.Value, Artifact);
	Else
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en = 'The {%1}%2 owner type should not be used for the %3 metadata object!'"),
			Artifact.Owner.Type().NamespaceURI,
			Artifact.Owner.Type().Name,
			Object.Metadata().FullName()
		);
		
	EndIf;
	
EndProcedure

//It is called before the importing of the reference object.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// Object - an object of a reference type.
// Artifact - XDTOObject - artifact.
//
Procedure BeforeImportReferenceObject(Container, Object, Artifact)
	
	If Artifact.Owner.Type() = OwnerTypeObject() Then
		ImportValueStorage(Container, Object[Artifact.Owner.Property], Artifact);
	ElsIf Artifact.Owner.Type() = OwnerTypeTabularSection() Then
		ImportValueStorage(Container,
			Object[Artifact.Owner.TabularSection].Get(Artifact.Owner.LineNumber - 1)[Artifact.Owner.Property],
			Artifact);
	Else
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en = 'The {%1}%2 owner type should not be used for the %3 metadata object!'"),
			Artifact.Owner.Type().NamespaceURI,
			Artifact.Owner.Type().Name,
			Object.Metadata().FullName()
		);
		
	EndIf;
	
EndProcedure

//It is called before the importing of the record set.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// RecordSet - record set.
// Artifact - XDTOObject - artifact.
//
Procedure BeforeImportRecordSet(Container, RecordSet, Artifact)
	
	If Artifact.Owner.Type() = OwnerTypeRecordSet() Then
		ImportValueStorage(Container,
			RecordSet.Get(Artifact.Owner.LineNumber)[Artifact.Owner.Property],
			Artifact);
	Else
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en = 'The {%1}%2 owner type should not be used for the %3 metadata object!'"),
			Artifact.Owner.Type().NamespaceURI,
			Artifact.Owner.Type().Name,
			RecordSet.Metadata().FullName()
		);
		
	EndIf;
	
EndProcedure

//Import the value of storage from the artifact.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// RecordSet - record set.
// Artifact - XDTOObject - artifact.
//
Procedure ImportValueStorage(Container, ValueStorage, Artifact)
	
	If Artifact.Data.Type() = BinaryValueType() Then
		FileName = Container.GetFullFileName(Artifact.Data.RelativeFilePath);
		Value = New BinaryData(FileName);
	ElsIf Artifact.Data.Type() = SerializableValueType() Then
		If TypeOf(Artifact.Data.Data) = Type("XDTODataObject") Then
			Value = XDTOSerializer.ReadXDTO(Artifact.Data.Data);
		Else
			Value = Artifact.Data.Data;
		EndIf;
	Else
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en = 'Unexpected placement type of value storage data in the exporting container: {%1}%2!'"),
			Artifact.Data.Type().NamespaceURI,
			Artifact.Data.Type().Name,
		);
		
	EndIf;
	
	ValueStorage = New ValueStorage(Value);
	
EndProcedure

// Return an array of structures that store the names of
// the attributes and tabular sections where there are value storages.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// ObjectMetadata - Metadata - Metadata
//
// Returns:
// Array - array of structures see "AttributesStructureWithValueStorage"
//
Function ObjectAttributesWithValuesStorage(Container, Val ObjectMetadata)
	
	FullMetadataName = ObjectMetadata.FullName();
	
	MetadataList = ValueStorageDataExportImportReUse.MetadataObjectListWithValueStorage();
	
	AttributesWithValuesStorage = MetadataList.Get(FullMetadataName);
	If AttributesWithValuesStorage = Undefined Then 
		Return Undefined;
	EndIf;
	
	Return AttributesWithValuesStorage;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions defining XDTO objects types

// Artifact type of the value storage.
//
// Returns:
// XDTOObjectType - type of the returned object.
//
Function ArtifactTypeValueStorage()
	
	Return XDTOFactory.Type(Package(), "ValueStorageArtefact");
	
EndFunction

// Type of a binary value.
//
// Returns:
// XDTOObjectType - type of the returned object.
//
Function BinaryValueType()
	
	Return XDTOFactory.Type(Package(), "BinaryValueStorageData");
	
EndFunction

// Type of the serializable value.
//
// Returns:
// XDTOObjectType - type of the returned object.
//
Function SerializableValueType()
	
	Return XDTOFactory.Type(Package(), "SerializableValueStorageData");
	
EndFunction

// Owner type of a constant.
//
// Returns:
// XDTOObjectType - type of the returned object.
//
Function ConstantOwnerType()
	
	Return XDTOFactory.Type(Package(), "OwnerConstant");
	
EndFunction

// Owner type of the reference object.
//
// Returns:
// XDTOObjectType - type of the returned object.
//
Function OwnerTypeObject()
	
	Return XDTOFactory.Type(Package(), "OwnerObject");
	
EndFunction

// Owner type of the tabular section.
//
// Returns:
// XDTOObjectType - type of the returned object.
//
Function OwnerTypeTabularSection()
	
	Return XDTOFactory.Type(Package(), "OwnerObjectTabularSection");
	
EndFunction

// Owner type of the record set.
//
// Returns:
// XDTOObjectType - type of the returned object.
//
Function OwnerTypeRecordSet()
	
	Return XDTOFactory.Type(Package(), "OwnerOfRecordset");
	
EndFunction

Function OwnerTypeBody()
	
	Return XDTOFactory.Type(Package(), "OwnerBody");
	
EndFunction

// Returns the namespace of XDTOpackage for value storages.
//
// Returns:
// String - name space of the XDTOpackage for value storages.
//
Function Package()
	
	Return "http://www.1c.ru/1cFresh/Data/Artefacts/ValueStorage/1.0.0.1";
	
EndFunction

#EndRegion
