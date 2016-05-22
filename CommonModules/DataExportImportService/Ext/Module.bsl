////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data export import".
//
////////////////////////////////////////////////////////////////////////////////

// Adds to the Handlers
// list update handler procedures required to this subsystem.
//
// Parameters:
//   Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	UndividedDataExportImport.RegisterUpdateHandlers(Handlers);
	
EndProcedure

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Data export/import

// Deletes the temporary file, the errors are ignored during deletion.
//
// Parameters:
//  Path - String - path to the deleted file.
//
Procedure DeleteTemporaryFile(Val Path) Export
	
	Try
		DeleteFiles(Path);
	Except
		// Data processor of an exception is not required, a
		// temporary file will be deleted on the next launch of the executable platform file.
	EndTry;
	
EndProcedure

// Return the array of all metadata objects, contained in configuration.
//  Used for launch and import data in configurations
//  not containing an SSL.
//
// Usage examples:
//
//  ExportParameters = New Structure();
//  ExportParameters.Insert("ExportedTypes", DataExportImportService.GetAllConfigurationTypes());
//  ExportParameters.Insert("ExportUsers", True);
//  ExportParameters.Insert("ExportUserSettings", True);
//  Filename = DataExportImport.DataExportToArchive(ExportParameters);
//
//  ImportParameters = New Structure();
//  ExportParameters.Insert("ImportedTypes", DataExportImportService.GetAllConfigurationTypes());
//  ImportParameters.Insert("ImportUsers", True);
//  ImportParameters.Insert("LoadUserSettings", True);
//  DataExportImport.ImportDataFromArchive(FileName, ExportParameters);
//
// Return value: Array(MetadataObject).
//
Function GetAllConfigurationTypes() Export
	
	MetadataCollectionsArray = New Array();
	
	FillConstantCollections(MetadataCollectionsArray);
	FillReferenceObjectsCollections(MetadataCollectionsArray);
	FillRecordSetsCollections(MetadataCollectionsArray);
	
EndFunction

// Export data to the directory.
//
// Parameters:
// ExportDirectory - String - export directory path.
// ExportParameters - The structure that contains the parameters of data export.
// 	Keys:
// 		ExportedTypes - Array(MetadataObject) - array of the
// 			metadata objects which data must be exported to the archive,
// 		ExportUsers - Boolean - export the information about the
// 		users of the infobase, ExportUserSettings - Boolean is ignored if ExportUsers = False.
// 		Also structure can contain additional keys that can be
// 			processed inside the arbitrary handlers of data export.
//
Procedure DataExportToDirectory(Val ExportDirectory, Val ExportParameters) Export
	
	Container = DataProcessors.DataExportImportContainerManager.Create();
	Container.InitializeExport(ExportDirectory, ExportParameters);
	
	AnnotatedReferenceTypes = DataExportImportServiceEvents.GetTypesRequireAnnotationRefsOnExport();
	Serializer = XDTOSerializerWithAnnotationTypes(Container, AnnotatedReferenceTypes);
	
	Handlers = DataProcessors.DataExportImportDataExportHandlersManager.Create();
	
	Handlers.BeforeDataExport(Container);
	
	SaveExportDescription(Container);
	
	DataProcessors.DataExportImportInfobaseDataExportManager.ExportInfobaseData(
		Container, Handlers, Serializer);
	
	If ExportParameters.ExportUsers Then
		
		InfobaseUsersExportImport.ExportInfobaseUsers(Container);
		
		If ExportParameters.ExportUserSettings Then
			
			DataProcessors.DataExportImportUserSettingsExportManager.ExportInfobaseUserSettings(
				Container, Handlers, Serializer);
			
		EndIf;
		
	EndIf;
	
	Handlers.AfterDataExport(Container);
	
	Container.FinishExport();
	
EndProcedure

// Imports data from a directory.
//
// Parameters:
// ImportingDirectory - String - Import directory.
// ExportParameters - Structure - Export parameters, see parameter "ExportParameters" of the procedure "ExportCurrentDataAreaFromArchive" of the common module "DataAreaExportImport"
//
Procedure ImportDataFromDirectory(Val ImportingDirectory, Val ExportParameters) Export
	
	SystemInfo = New SystemInfo();
	PlatformVersion = SystemInfo.AppVersion;
	
	If CommonUseClientServer.CompareVersions(PlatformVersion, "8.2.19.0") < 0
		OR (CommonUseClientServer.CompareVersions(PlatformVersion, "8.3.1.0") > 0
		AND CommonUseClientServer.CompareVersions(PlatformVersion, "8.3.4.0") < 0) Then
		
		Raise
			NStr("en = 'For executing the data import it is required to update the technology platform ""1C:Enterprise"".
                  |For version 8.2 you should use release 8.2.19 (or higher).
                  |For version 8.3 you should use release 8.3.4 (or higher).'");
		
	EndIf;
	
	If Right(ImportingDirectory, 1) <> "\" Then
		Folder = Folder + "\";
	EndIf;
	
	Handlers = DataProcessors.DataExportImportDataImportHandlersManager.Create();
	
	Container = DataProcessors.DataExportImportContainerManager.Create();
	Container.InitializeImport(ImportingDirectory, ExportParameters);
	
	ExportInfo = ReadInformationAboutExport(Container);
	
	If Not ExportArchiveIsCompatibleWithCurrentConfiguration(ExportInfo) Then
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en = 'Unable to import data from the file, as the file was exported from another configuration (the file is exported from the %1 configuration and can not be imported into the %2 configuration)'"),
			ExportInfo.Configuration.Name,
			Metadata.Name
		);
		
	EndIf;
	
	If Not ExportInArchiveIsCompatibleWithCurrentConfigurationVersion(ExportInfo) Then
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en = 'Unable to import data from the file, as the file was exported from another configuration version (the file is exported from the %1 configuration version and can not be imported into the %2 configuration version)'"),
			ExportInfo.Configuration.Version,
			Metadata.Version
		);
		
	EndIf;
	
	Handlers.BeforeCleaningData(Container);
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("StandardSubsystems.SaaS") Then 
		ModuleSaaSOperations = ServiceTechnologyIntegrationWithSSL.CommonModule("SaaSOperations");
		ModuleSaaSOperations.ClearAreaData(ExportParameters.ImportUsers);
	Else
		EraseInfobaseData();
	EndIf;
	
	Handlers.BeforeDataImport(Container);
	
	DataProcessors.DataExportImportInfobaseDataImportManager.ImportInfobaseData(Container, Handlers);
	
	If ExportParameters.ImportUsers Then
		
		InfobaseUsersExportImport.ImportInfobaseUsers(Container);
		
		If ExportParameters.LoadUserSettings Then
			
			DataProcessors.DataExportImportUserSettingsImportManager.ImportInfobaseUserSettings(
				Container, Handlers);
			
		EndIf;
		
	EndIf;
	
	Handlers.AfterDataImport(Container);
	
EndProcedure

// Compare whether the export is compatible with current configuration.
//
// Parameters:
//  ExportInfo - XDTODataObject - see procedure "SaveExportDescription"
//
// Returns:
//  Boolean - True if it matches.
//
Function ExportArchiveIsCompatibleWithCurrentConfiguration(Val ExportInfo) Export
	
	Return ExportInfo.Configuration.Name = Metadata.Name;
	
EndFunction

// Compare whether the configuration version is compatible with exported one.
//
// Parameters:
//  ExportInfo - XDTODataObject - see procedure "SaveExportDescription"
//
// Returns:
//  Boolean - True if it matches.
//
Function ExportInArchiveIsCompatibleWithCurrentConfigurationVersion(Val ExportInfo) Export
	
	Return ExportInfo.Configuration.Version = Metadata.Version;
	
EndFunction

// Data type of the file that stores the column name with the source reference.
//
// Returns:
//  String - type name.
//
Function DataTypeForValueTableColumnName() Export
	
	Return "1cfresh\ReferenceMapping\ValueTableColumnName";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// File types and structure of the import/export directories

// Returns the file type name with information about exporting.
//
Function DumpInfo() Export
	Return "DumpInfo";
EndFunction

// Returns the file type name with the information about the content of exporting.
//
Function PackageContents() Export
	Return "PackageContents";
EndFunction

// Returns the file type name with information about references mapping.
//
Function ReferenceMapping() Export
	Return "ReferenceMapping";
EndFunction

// Returns the file type name with information about the references recreation.
//
Function ReferenceRebuilding() Export
	Return "ReferenceRebuilding";
EndFunction

// Returns the file type name that stores the serialized data of the infobase.
//
Function InfobaseData() Export
	Return "InfobaseData";
EndFunction

// Returns the file type name that stores the serialized data of the sequence limits.
//
Function SequenceBoundary() Export
	Return "SequenceBoundary";
EndFunction

// Return the file type name that stores the serialized data of the users settings.
//
Function UserSettings() Export
	Return "UserSettings";
EndFunction

// Returns the file type name that stores the serialized users data.
//
Function Users() Export
	Return "Users";
EndFunction

// Returns the file type name that stores arbitrary data.
//
Function CustomData() Export
	Return "CustomData";
EndFunction

// Function forms the rules of directories structure in export.
//
// Returns:
// FixedStructure - structure of directories.
//
Function DirectoriesStructureCreationRules() Export
	
	RootDirectory = "";
	DataDirectory = "Data";
	
	Result = New Structure();
	Result.Insert(DumpInfo(), RootDirectory);
	Result.Insert(PackageContents(), RootDirectory);
	Result.Insert(ReferenceMapping(), ReferenceMapping());
	Result.Insert(ReferenceRebuilding(), ReferenceRebuilding());
	Result.Insert(InfobaseData(), DataDirectory);
	Result.Insert(SequenceBoundary(), DataDirectory);
	Result.Insert(Users(), RootDirectory);
	Result.Insert(UserSettings(), UserSettings());
	Result.Insert(CustomData(), CustomData());
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns the types of files that support the replacement of refs.
//
// Returns:
// Array - array of file types.
//
Function FileTypesThatSupportRefsReplacement() Export
	
	Result = New Array();
	
	Result.Add(InfobaseData());
	Result.Add(SequenceBoundary());
	Result.Add(UserSettings());
	
	Return Result;
	
EndFunction

// Return the type name that will be used in the xml
// file for the specified metadata object Used for searching and replacing refs when exporting, modifying schemas currentconfig and recording
// 
// Parameters:
//  Value - Metadata object or Ref
//
// Returns:
//  String - String of the AccountingRegisterRecordSet.SelfSupporting kind describing the metadata object 
//
Function XMLReferenceType(Val Value) Export
	
	If TypeOf(Value) = Type("MetadataObject") Then
		MetadataObject = Value;
		ObjectManager = ServiceTechnologyIntegrationWithSSL.ObjectManagerByFullName(MetadataObject.FullName());
		Refs = ObjectManager.GetRef();
	Else
		MetadataObject = Value.Metadata();
		Refs = Value;
	EndIf;
	
	If CommonUseSTL.ThisIsReferenceData(MetadataObject) Then
		
		Return XDTOSerializer.XMLTypeOf(Refs).TypeName;
		
	Else
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en = 'Error when defining XMLType of reference for the %1 object: object is not a reference!'"),
			MetadataObject.FullName());
		
	EndIf;
	
EndFunction

// Return the metadata object by the field type.
//
// Parameters:
//  FieldType - Type - Field type
//
// Returns:
//  MetadataObject - Metadata object.
//
Function MetadataObjectByTypeRefs(Val FieldType) Export
	
	BusinessProcessesRoutePointsRefs = BusinessProcessesRoutePointsRefs();
	
	BusinessProcess = BusinessProcessesRoutePointsRefs.Get(FieldType);
	If BusinessProcess = Undefined Then
		Refs = New(FieldType);
		MetadataRefs = Refs.Metadata();
	Else
		MetadataRefs = BusinessProcess;
	EndIf;
	
	Return MetadataRefs;
	
EndFunction

// Return the full list of the configuration constants
//
// Returns:
//  Array - Metadata objects
//
Function AllConstants() Export
	
	ObjectsMetadata = New Array;
	FillConstantCollections(ObjectsMetadata);
	Return AllCollectionsMetadata(ObjectsMetadata);
	
EndFunction

// Returns the full list of configuration reference types
//
// Returns:
//  Array - Metadata objects
//
Function AllReferenceData() Export
	
	ObjectsMetadata = New Array;
	FillReferenceObjectsCollections(ObjectsMetadata);
	Return AllCollectionsMetadata(ObjectsMetadata);
	
EndFunction

// Returns the full list of configuration records sets
//
// Returns:
//  Array - Metadata objects
//
Function AllRecordSets() Export
	
	ObjectsMetadata = New Array;
	FillRecordSetsCollections(ObjectsMetadata);
	Return AllCollectionsMetadata(ObjectsMetadata);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Read/write data

// Write an object to the file.
//
// Parameters:
//  Object - recorded object.
//  FileName - String - file path.
//  Serializer - XDTOSerializer - serializer.
//
Procedure WriteObjectToFile(Val Object, Val FileName, Serializer = Undefined) Export
	
	WriteStream = New XMLWriter();
	WriteStream.OpenFile(FileName);
	
	WriteObjectToStream(Object, WriteStream, Serializer);
	
	WriteStream.Close();
	
EndProcedure

// Write an object to the record stream.
//
// Parameters:
//  Object - recorded object.
//  WriteStream - XMLWriter - record stream.
//  Serializer - XDTOSerializer - serializer.
//
Procedure WriteObjectToStream(Val Object, WriteStream, Serializer = Undefined) Export
	
	If Serializer = Undefined Then
		Serializer = XDTOSerializer;
	EndIf;
	
	WriteStream.WriteStartElement(ItemNameContainingObject());
	
	NamespacePrefixes = NamespacePrefixes();
	For Each NamespacePrefix IN NamespacePrefixes Do
		WriteStream.WriteNamespaceMapping(NamespacePrefix.Value, NamespacePrefix.Key);
	EndDo;
	
	Serializer.WriteXML(WriteStream, Object, XMLTypeAssignment.Explicit);
	
	WriteStream.WriteEndElement();
	
EndProcedure

// Return an object from the file.
//
// Parameters:
//  FileName - String - file path.
//
// Returns:
//  Object.
//
Function ReadObjectFromFile(Val FileName) Export
	
	ReadStream = New XMLReader();
	ReadStream.OpenFile(FileName);
	ReadStream.MoveToContent();
	
	Object = ReadObjectFromStream(ReadStream);
	
	ReadStream.Close();
	
	Return Object;
	
EndFunction

// Return an object from the file.
//
// Parameters:
//  ReadStream - XMLReader - read stream.
//
// Returns:
//  Object.
//
Function ReadObjectFromStream(ReadStream) Export
	
	If ReadStream.NodeType <> XMLNodeType.StartElement
			Or ReadStream.Name <> ItemNameContainingObject() Then
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en = 'The XML reading error. Incorrect file format. The beginning of the item %1 is expected.'"),
			ItemNameContainingObject()
		);
		
	EndIf;
	
	If Not ReadStream.Read() Then
		Raise NStr("en = 'The XML reading error. File completion is detected.'");
	EndIf;
	
	Object = XDTOSerializer.ReadXML(ReadStream);
	
	Return Object;
	
EndFunction

// Write XDTOObject to the file.
//
// Parameters:
//  XDTODataObject - XDTODataObject - recorded XDTOObject.
//  FileName - String - full path to the file.
//  NamespacePrefixDefault - String - Prefix.
//
Procedure WriteXDTOObjectToFile(Val XDTODataObject, Val FileName, Val NamespacePrefixDefault = "") Export
	
	WriteStream = New XMLWriter();
	WriteStream.OpenFile(FileName);
	
	NamespacePrefixes = NamespacePrefixes();
	ObjectNamespace = XDTODataObject.Type().NamespaceURI;
	If IsBlankString(NamespacePrefixDefault) Then
		NamespacePrefixDefault = NamespacePrefixes.Get(ObjectNamespace);
	EndIf;
	UsedNamespaces = GetNamespacesForWritePackage(ObjectNamespace);
	
	WriteStream.WriteStartElement(ItemNameContainingXDTOObject());
	
	For Each UsedNamespace IN UsedNamespaces Do
		NamespacePrefix = NamespacePrefixes.Get(UsedNamespace);
		If NamespacePrefix = NamespacePrefixDefault Then
			WriteStream.WriteNamespaceMapping("", UsedNamespace);
		Else
			WriteStream.WriteNamespaceMapping(NamespacePrefix, UsedNamespace);
		EndIf;
	EndDo;
	
	XDTOFactory.WriteXML(WriteStream, XDTODataObject);
	
	WriteStream.WriteEndElement();
	
	WriteStream.Close();
	
EndProcedure

// Read XDTOObject from the file.
//
// Parameters:
//  FileName - String - full path to the file.
//  XDTOType - XDTOObjectType - XDTO object type.
//
// Returns:
//  ObjectXDTO.
//
Function ReadXDTOObjectFromFile(Val FileName, Val XDTOType) Export
	
	ReadStream = New XMLReader();
	ReadStream.OpenFile(FileName);
	ReadStream.MoveToContent();
	
	If ReadStream.NodeType <> XMLNodeType.StartElement
			Or ReadStream.Name <> ItemNameContainingXDTOObject() Then
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en = 'The XML reading error. Incorrect file format. The beginning of the item %1 is expected.'"),
			ItemNameContainingXDTOObject()
		);
		
	EndIf;
	
	If Not ReadStream.Read() Then
		Raise NStr("en = 'The XML reading error. File completion is detected.'");
	EndIf;
	
	XDTODataObject = XDTOFactory.ReadXML(ReadStream, XDTOType);
	
	ReadStream.Close();
	
	Return XDTODataObject;
	
EndFunction

// Return the prefixes for frequently used namespaces.
//
// Return value:
// Map:
//  Key - String - namespace.
//  Value - String - Prefix.
//
Function NamespacePrefixes() Export
	
	Result = New Map();
	
	Result.Insert("http://www.w3.org/2001/XMLSchema", "xs");
	Result.Insert("http://www.w3.org/2001/XMLSchema-instance", "xsi");
	Result.Insert("http://v8.1c.ru/8.1/data/core", "v8");
	Result.Insert("http://v8.1c.ru/8.1/data/enterprise", "ns");
	Result.Insert("http://v8.1c.ru/8.1/data/enterprise/current-config", "cc");
	Result.Insert("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "dmp");
	
	Return New FixedMap(Result);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other

Function StandardSettingsStorageTypes() Export
	
	Result = New Array();
	
	Result.Add("CommonSettingsStorage");
	Result.Add("SystemSettingsStorage");
	Result.Add("ReportsUserSettingsStorage");
	Result.Add("ReportsVariantsStorage");
	Result.Add("FormDataSettingsStorage");
	Result.Add("UserSettingsDynamicListsStorage");
	
	Return New FixedArray(Result);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Write the configuration description
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager -
//  container manager that is used in the process of data export. 
//  For more information, see a comment to the DataExportImportContainerManager application 
//  interface processor.
//
Procedure SaveExportDescription(Val Container)
	
	DumpInfoType = XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "DumpInfo");
	ConfigurationInfoType = XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "ConfigurationInfo");
	
	ExportInfo = XDTOFactory.Create(DumpInfoType);
	ExportInfo.Created = CurrentSessionDate();
	
	ConfigurationInfo = XDTOFactory.Create(ConfigurationInfoType);
	ConfigurationInfo.Name = Metadata.Name;
	ConfigurationInfo.Version = Metadata.Version;
	ConfigurationInfo.Vendor = Metadata.Vendor;
	ConfigurationInfo.Presentation = Metadata.Presentation();
	
	ExportInfo.Configuration = ConfigurationInfo;
	
	FileName = Container.CreateFile(DumpInfo());
	WriteXDTOObjectToFile(ExportInfo, FileName);
	
EndProcedure

// Read the configuration description
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager -
//  container manager that is used in the process of data export. 
//  For more information, see a comment to the DataExportImportContainerManager application 
//  interface processor.
//
Function ReadInformationAboutExport(Container)
	
	FileName = Container.GetFileFromDirectory(DumpInfo());
	
	Return ReadXDTOObjectFromFile(
		FileName, XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "DumpInfo"));
	
EndFunction

// Return the item name in the read/write stream in which the XDTOObject is stored.
//
// Returns:
//  String - item name.
//
Function ItemNameContainingXDTOObject()
	
	Return "XDTODataObject";
	
EndFunction

// Return the item name in the read/write stream in which the object is stored.
//
// Returns:
//  String - item name.
//
Function ItemNameContainingObject()
	
	Return "Data";
	
EndFunction

// Return the namespace array for recording packets.
//
// Parameters:
//  NamespaceURI - String - namespaces.
//
// Returns:
//  Array - array of the namespaces.
//
Function GetNamespacesForWritePackage(Val NamespaceURI)
	
	Result = New Array();
	Result.Add(NamespaceURI);
	
	Dependencies = XDTOFactory.packages.Get(NamespaceURI).Dependencies;
	For Each Dependence IN Dependencies Do
		DependentNamespace = GetNamespacesForWritePackage(Dependence.NamespaceURI);
		CommonUseClientServer.SupplementArray(Result, DependentNamespace, True);
	EndDo;
	
	Return Result;
	
EndFunction

// Fill the array with collection of the metadata reference objects.
//
// Parameters:
//  MetadataCollectionsArray - Array - array.
//
Procedure FillReferenceObjectsCollections(MetadataCollectionsArray)
	
	MetadataCollectionsArray.Add(Metadata.Catalogs);
	MetadataCollectionsArray.Add(Metadata.Documents);
	MetadataCollectionsArray.Add(Metadata.BusinessProcesses);
	MetadataCollectionsArray.Add(Metadata.Tasks);
	MetadataCollectionsArray.Add(Metadata.ChartsOfAccounts);
	MetadataCollectionsArray.Add(Metadata.ExchangePlans);
	MetadataCollectionsArray.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataCollectionsArray.Add(Metadata.ChartsOfCalculationTypes);
	
EndProcedure

// Fill the array with collection of the metadata records sets.
//
// Parameters:
//  MetadataCollectionsArray - Array - array.
//
Procedure FillRecordSetsCollections(MetadataCollectionsArray)
	
	MetadataCollectionsArray.Add(Metadata.InformationRegisters);
	MetadataCollectionsArray.Add(Metadata.AccumulationRegisters);
	MetadataCollectionsArray.Add(Metadata.AccountingRegisters);
	MetadataCollectionsArray.Add(Metadata.Sequences);
	MetadataCollectionsArray.Add(Metadata.CalculationRegisters);
	For Each CalculationRegister IN Metadata.CalculationRegisters Do
		MetadataCollectionsArray.Add(CalculationRegister.Recalculations);
	EndDo;
	
EndProcedure

// Fill the array with collection of the metadata constants.
//
// Parameters:
//  MetadataCollectionsArray - Array - array.
//
Procedure FillConstantCollections(MetadataCollectionsArray)
	
	MetadataCollectionsArray.Add(Metadata.Constants);
	
EndProcedure

// Return the full list of objects from specified collections
//
// Parameters:
//  Collection - Array - Collection
//
// Returns:
//  Array - Metadata objects
//
Function AllCollectionsMetadata(Val Collection)
	
	Result = New Array;
	For Each Collection IN Collection Do
		
		For Each Object IN Collection Do
			Result.Add(Object);
		EndDo;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Return the points references of the business process
//
// Returns:
// Map:
// 	Key - Type - the reference type of the business process point.
// 	Value - MetadataObject - business process.
//
Function BusinessProcessesRoutePointsRefs()
	
	Result = New Map();
	
	For Each BusinessProcess IN Metadata.BusinessProcesses Do
		
		Result.Insert(Type("BusinessProcessRoutePointRef." + BusinessProcess.Name), BusinessProcess);
		
	EndDo;
	
	Return Result;
	
EndFunction

// Return the XDTOSerializer with the types annotation.
//
// Returns:
//  XDTOSerializer - serializer.
//
Function XDTOSerializerWithAnnotationTypes(Val CurrentContainer, Val AnnotatedTypes)
	
	If AnnotatedTypes.Count() > 0 Then
		
		Factory = GetFactoryWithTypes(CurrentContainer, AnnotatedTypes);
		Return New XDTOSerializer(Factory);
		
	Else
		
		Return XDTOSerializer;
		
	EndIf;
	
EndFunction

// Returns a factory with types.
//
// Parameters:
//  Types - FixedArray (Metadata) - array of types.
//
// Returns:
//  XDTOFactory - Factory
//
Function GetFactoryWithTypes(Val CurrentContainer, Val Types)
	
	SchemaSet = XDTOFactory.ExportXMLSchema("http://v8.1c.ru/8.1/data/enterprise/current-config");
	Schema = SchemaSet[0];
	Schema.UpdateDOMElement();
	
	OriginalSchema = CurrentContainer.CreateRandomFile(
		"xsd", "http://v8.1c.ru/8.1/data/enterprise/current-config");
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(OriginalSchema);
	DOMWriter = New DOMWriter;
	DOMWriter.Write(Schema.DOMDocument, XMLWriter);
	XMLWriter.Close();
	
	CurrentContainer.SetObjectsQuantity(OriginalSchema, 1);
	
	SelectedTypes = New Map;
	For Each Type IN Types Do
		SelectedTypes.Insert(XMLReferenceType(Type), True);
	EndDo;
	
	TargetNamespace = New Map;
	TargetNamespace.Insert("xs", "http://www.w3.org/2001/XMLSchema");
	DOMNamespaceResolver = New DOMNamespaceResolver(TargetNamespace);
	TextXPath = "/xs:schema/xs:complexType/xs:sequence/xs:element[starts-with(@type,'tns:')]";
	
	Query = Schema.DOMDocument.CreateExpressionXPath(TextXPath,
		DOMNamespaceResolver);
	Result = Query.Eval(Schema.DOMDocument);

	While True Do
		
		NodeFields = Result.GetNext();
		If NodeFields = Undefined Then
			Break;
		EndIf;
		TypeAttribute = NodeFields.Attributes.GetNamedItem("type");
		TypeWithoutNSPrefix = Mid(TypeAttribute.TextContent, StrLen("tns:") + 1);
		
		If SelectedTypes.Get(TypeWithoutNSPrefix) = Undefined Then
			Continue;
		EndIf;
		
		NodeFields.SetAttribute("nillable", "true");
		NodeFields.RemoveAttribute("type");
	EndDo;
	
	SchemaWithAnnotationTypes = CurrentContainer.CreateRandomFile(
		"xsd", "http://v8.1c.ru/8.1/data/enterprise/current-config");
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(SchemaWithAnnotationTypes);
	DOMWriter = New DOMWriter;
	DOMWriter.Write(Schema.DOMDocument, XMLWriter);
	XMLWriter.Close();
	
	CurrentContainer.SetObjectsQuantity(SchemaWithAnnotationTypes, 1);
	Factory = CreateXDTOFactory(SchemaWithAnnotationTypes);
	
	Return Factory;
	
EndFunction

#EndRegion
