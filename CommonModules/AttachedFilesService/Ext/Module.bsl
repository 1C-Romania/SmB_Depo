////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Updates events of procedure AttachedFiles:
//
// Server events:
//   OnDefineFilesStorageCatalogs.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Allows to override files storage catalogs by owners types.
	// 
	// Parameters:
	//  TypeFileOwner   - Reference type of the object to which the file is attached.
	//
	//  NamesOfCatalogs - Map that contains the catalogs names in the keys.
	//                      Contains name of one standard catalog during the call.
	//                      If you place True to
	//                      the match value only ones, then if in case
	//                      you need one catalog, such catalog will be selected.
	//                      If there are several catalogs and none contains in value.
	//                      Source or more that one contain Source, then an error will occur.
	//
	// Syntax:
	// Procedure OnDefineFilesStorageCatalogs (FileOwnerType, CatalogsNames) Export
	//
	ServerEvents.Add("StandardSubsystems.AttachedFiles\OnDeterminingFilesStorageCatalogs");
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"AttachedFilesService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddExceptionsSearchLinks"].Add(
		"AttachedFilesService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnSendDataToSubordinate"].Add(
		"AttachedFilesService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnSendDataToMaster"].Add(
		"AttachedFilesService");
		
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromSubordinate"].Add(
		"AttachedFilesService");
		
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromMaster"].Add(
		"AttachedFilesService");
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileFunctions") Then
		ServerHandlers["StandardSubsystems.FileFunctions\WhenConfidentialityOfFilesInVolumeWhenPlacing"].Add(
			"AttachedFilesService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\RegistrationChangesOnDelete"].Add(
			"AttachedFilesService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\WhenDefiningTextQueryForTextRetrieval"].Add(
			"AttachedFilesService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDeterminingNumberOfVersionsWithNotImportedText"].Add(
			"AttachedFilesService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnWriteExtractedText"].Add(
			"AttachedFilesService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDeterminingNumberOfFilesInVolumes"].Add(
			"AttachedFilesService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDeterminingExistenceOfStoredFiles"].Add(
			"AttachedFilesService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnStoredFilesGetting"].Add(
			"AttachedFilesService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\WhenDefiningNavigationLinksFile"].Add(
			"AttachedFilesService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDeterminingFileWithNameByBinaryData"].Add(
			"AttachedFilesService");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGetPrimaryImagePlanExchangeObjects"].Add(
		"AttachedFilesService");
	
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.FileFunctionsSaaS") Then
		
		ServerHandlers["ServiceTechnology.SaaS.FileFunctionsSaaS\OnFillFileFunctionsIntegrationHandlersSaaS"].Add(
			"AttachedFilesService");
		
	EndIf;
	
EndProcedure

// Places files from the generated image.
Procedure AddFilesToVolumesOnPlacing(Val FilesPathCompliance,
                                          Val TypeOfFileStorage,
                                          Val Files) Export
	
	For Each MapItem IN FilesPathCompliance Do
		
		Position = Find(MapItem.Key, "CatalogRef");
		
		If Position = 0 Then
			Continue;
		EndIf;
		
		FileFullPathOnDrive = FilesPathCompliance.Get(MapItem.Key);
		
		If FileFullPathOnDrive = Undefined Then
			Continue;
		EndIf;
		
		UUID = New UUID(Left(MapItem.Key, Position - 1));
		
		CatalogName = Right(MapItem.Key, StrLen(MapItem.Key) - Position -10);
		Ref = Catalogs[CatalogName].GetRef(UUID);
		
		If Ref.IsEmpty() Then
			Continue;
		EndIf;
		
		Object = Ref.GetObject();
		
		If Object.FileStorageType <> Enums.FileStorageTypes.InVolumesOnDrive Then
			Continue;
		EndIf;
		
		If Files.Find(TypeOf(Object)) = Undefined Then
			Files.Add(TypeOf(Object));
		EndIf;
		
		// Place files to base receiver inside the base regardless of storage in base source.
		If TypeOfFileStorage = Enums.FileStorageTypes.InInfobase Then
			
			Object.FileStorageType = Enums.FileStorageTypes.InInfobase;
			Object.PathToFile = "";
			Object.Volume = Catalogs.FileStorageVolumes.EmptyRef();
			
			BinaryData = New BinaryData(FileFullPathOnDrive);
			UpdateBinaryDataOfFileAtServer(Object, PutToTempStorage(BinaryData));
			
		Else // Place files to base receiver inside the volume regardless of storage in base source.
			SourceFile = New File(FileFullPathOnDrive);
			FullPathNew = SourceFile.Path + Object.Description + "." + Object.Extension;
			MoveFile(FileFullPathOnDrive, FullPathNew);
			
			// Add file to one of the volumes (where there is a vacant place).
			FileInformation = FileFunctionsService.AddFileToVolume(FullPathNew, Object.ModificationDateUniversal,
				Object.Description, Object.Extension,, Object.Encrypted);
			Object.Volume = FileInformation.Volume;
			Object.PathToFile = FileInformation.PathToFile;
			Object.FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive;
			
		EndIf;
		
		Object.Write();
		
		If Not IsBlankString(FullPathNew) Then
			DeleteFiles(FullPathNew);
		EndIf;
		
	EndDo;
	
EndProcedure

// Deletes registration in the exchange plan during files exchange.
//
// Parameters:
//  ExchangePlanRef  - Ref to an exchange plan.
//  TypesFiles       - Catalogs types array with the attached files.
//
Procedure DeleteChangeRecords(ExchangePlanRef, TypesFiles) Export
	
	For Each Type IN TypesFiles Do
		ExchangePlans.DeleteChangeRecords(ExchangePlanRef, Metadata.FindByType(Type));
	EndDo;
	
EndProcedure

// Checks whether passed data item - it is object of the attached file.
Function IsItemAttachedFiles(DataItem) Export
	
	If TypeOf(DataItem) = Type("ObjectDeletion") Then
		Return False;
	EndIf;
	
	MetadataElement = DataItem.Metadata();
	
	Return CommonUse.ThisIsCatalog(MetadataElement)
	      AND Upper(Right(MetadataElement.Name, StrLen("AttachedFiles"))) = Upper("AttachedFiles");
	
EndFunction

// Returns attached file properties: binary data and signature.
//
// Parameters:
//  AttachedFile     - Ref to the attached file.
//  SignatureAddress - String - signature address in the temporary storage.
//
// Returns:
//  Structure with properties:
//    BinaryData           - BinaryData of the attached file.
//    BinaryDataSignatures - signature BinaryData.
//
Function GetBinaryDataOfFileAndSignature(Val AttachedFile, Val SignatureAddress) Export
	
	Properties = New Structure;
	
	Properties.Insert("BinaryData", AttachedFiles.GetFileBinaryData(
		AttachedFile));
	
	Properties.Insert("BinaryDataSignatures", GetFromTempStorage(SignatureAddress));
	
	Return Properties;
	
EndFunction

// Returns versions quantity with unextracted text.
Function GetVersionsNumberWithNotExtractedText() Export
	
	CountOfFiles = 0;
	
	OwnerTypes = Metadata.InformationRegisters.AttachedFilesExist.Dimensions.ObjectWithFiles.Type.Types();
	CatalogAllNames = New Map;
	
	For Each Type IN OwnerTypes Do
		
		NamesOfCatalogs = CatalogsNamesFilesStorage(Type);
		
		For Each KeyAndValue IN NamesOfCatalogs Do
			If CatalogAllNames[KeyAndValue.Key] <> Undefined Then
				Continue;
			EndIf;
			AttachedFilesCatalogName = KeyAndValue.Key;
			CatalogAllNames.Insert(KeyAndValue.Key, True);
			
			Query = New Query;
			Query.Text = QueryTextForFilesNumberWithUnextractedText(AttachedFilesCatalogName);
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				CountOfFiles = CountOfFiles + Selection.CountOfFiles;
			EndIf
		EndDo;
	EndDo;
	
	Return CountOfFiles;
	
EndFunction

// Returns path to file on disc. If file is stored in
// the infobase, it saves it beforehand.
//
// Parameters:
//  AttachedFile - Ref to the attached file.
//
// Returns:
//  String - full path to the file on the disk.
//
Function GetFileNameWithPathToBinaryData(Val AttachedFile, PathIsEmptyForEmptyData = False) Export
	
	FileNameWithPath = GetTempFileName(AttachedFile.Extension);
	
	If AttachedFile.FileStorageType = Enums.FileStorageTypes.InInfobase Then
		Query = New Query;
		Query.Text = 
		"SELECT
		|	AttachedFiles.AttachedFile,
		|	AttachedFiles.StoredFile
		|FROM
		|	InformationRegister.AttachedFiles AS AttachedFiles
		|WHERE
		|	AttachedFiles.AttachedFile = &AttachedFile";
		
		Query.SetParameter("AttachedFile", AttachedFile.Ref);
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			BinaryData = Selection.StoredFile.Get();
			
			If PathIsEmptyForEmptyData AND TypeOf(BinaryData) <> Type("BinaryData") Then
				Return "";
			EndIf;
			
			BinaryData.Write(FileNameWithPath);
			
		ElsIf PathIsEmptyForEmptyData Then
			Return "";
		Else
			Raise FileFunctionsServiceClientServer.ErrorFileIsNotFoundInFileStorage(
				AttachedFile.Description + "." + AttachedFile.Extension);
		EndIf;
	Else
		If Not AttachedFile.Volume.IsEmpty() Then
			FileNameWithPath = FileFunctionsService.FullPathOfVolume(AttachedFile.Volume) + AttachedFile.PathToFile;
		EndIf;
	EndIf;
	
	Return FileNameWithPath;
	
EndFunction

// Fills in the FilesInVolumesQuantity parameter.
Procedure DetermineCountOfFilesInVolumes(CountFilesInVolumes) Export
	
	OwnerTypes = Metadata.InformationRegisters.AttachedFilesExist.Dimensions.ObjectWithFiles.Type.Types();
	CatalogAllNames = New Map;
	
	Query = New Query;
	
	For Each Type IN OwnerTypes Do
		
		NamesOfCatalogs = CatalogsNamesFilesStorage(Type);
		
		For Each KeyAndValue IN NamesOfCatalogs Do
			If CatalogAllNames[KeyAndValue.Key] <> Undefined Then
				Continue;
			EndIf;
			AttachedFilesCatalogName = KeyAndValue.Key;
			CatalogAllNames.Insert(KeyAndValue.Key, True);
		
			Query.Text =
			"SELECT
			|	ISNULL(COUNT(AttachedFiles.Ref), 0) AS CountOfFiles
			|FROM
			|	&CatalogName AS AttachedFiles
			|WHERE
			|	AttachedFiles.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnDrive)";
			Query.Text = StrReplace(Query.Text, "&CatalogName",
				"Catalog." + AttachedFilesCatalogName);
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				CountFilesInVolumes = CountFilesInVolumes + Selection.CountOfFiles;
			EndIf
		EndDo;
	EndDo;
	
EndProcedure

// Returns files size in volume (in bytes).
Function CountSizeOfFilesOnVolume(RefOfVolume) Export
	
	OwnerTypes = Metadata.InformationRegisters.AttachedFilesExist.Dimensions.ObjectWithFiles.Type.Types();
	CatalogAllNames = New Map;
	
	Query = New Query;
	Query.Parameters.Insert("Volume", RefOfVolume);
	
	FilesSizeInVolume = 0;
	
	For Each Type IN OwnerTypes Do
		
		NamesOfCatalogs = CatalogsNamesFilesStorage(Type);
		
		For Each KeyAndValue IN NamesOfCatalogs Do
			If CatalogAllNames[KeyAndValue.Key] <> Undefined Then
				Continue;
			EndIf;
			AttachedFilesCatalogName = KeyAndValue.Key;
			CatalogAllNames.Insert(KeyAndValue.Key, True);
		
			Query.Text =
			"SELECT
			|	ISNULL(SUM(AttachedFiles.Size), 0) AS FilesSize
			|FROM
			|	&CatalogName AS AttachedFiles
			|WHERE
			|	AttachedFiles.Volume = &Volume";
			Query.Text = StrReplace(Query.Text, "&CatalogName",
				"Catalog." + AttachedFilesCatalogName);
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				FilesSizeInVolume = FilesSizeInVolume + Selection.FilesSize;
			EndIf
		EndDo;
	EndDo;
	
	Return FilesSizeInVolume;
	
EndFunction

// It returns True in ThereAreStoredFiles parameter if there are stored files to ExternalObject object.
// Determines whether there are stored files in the external object.
// 
// Parameters:
//  ExternalObject     - Ref to an external object.
//  AreStoredFiles     - Boolean (return value), parameter values options:
//                        True - return,
//                        False   - sets True if object has stored files.
//
Procedure DetermineStoredFilesExisting(Val ExternalObject, AreStoredFiles) Export
	
	If AreStoredFiles = True Then
		Return;
	EndIf;
	
	OwnerTypes = Metadata.InformationRegisters.AttachedFilesExist.Dimensions.ObjectWithFiles.Type.Types();
	If OwnerTypes.Find(TypeOf(ExternalObject)) <> Undefined Then
		AreStoredFiles = ObjectHasFiles(ExternalObject);
	EndIf;
	
EndProcedure

// Fills in the StoredFiles array with data of the ExternalObject object stored files.
Procedure GetStoredFiles(Val ExternalObject, Val StoredFiles) Export
	
	OwnerTypes = Metadata.InformationRegisters.AttachedFilesExist.Dimensions.ObjectWithFiles.Type.Types();
	If OwnerTypes.Find(TypeOf(ExternalObject)) = Undefined Then
		Return;
	EndIf;
		
	FilesArray = GetAllSubordinateFiles(ExternalObject);
	For Each File IN FilesArray Do
		
		FileData = New Structure;
		FileData.Insert("ModificationDateUniversal", File.ModificationDateUniversal);
		FileData.Insert("Size",                       File.Size);
		FileData.Insert("Description",                 File.Description);
		FileData.Insert("Extension",                   File.Extension);
		
		FileData.Insert("FileBinaryData",          AttachedFiles.GetFileData(
			File, Undefined).FileBinaryDataRef);
		
		FileData.Insert("Text",                        File.TextStorage.Get());
		
		StoredFiles.Add(FileData);
	EndDo;
		
EndProcedure

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.5";
	Handler.Procedure = "AttachedFilesService.ClearInformationRegisterIncorrectRecordsAttachedFilesPresence";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures used while exchanging data and downoading / importing data.

// Returns catalogs array that are also file owners.
//
// Return value: Array(MetadataObject).
//
Function FileCatalogs() Export
	
	Result = New Array();
	
	MetadataCollections = New Array();
	MetadataCollections.Add(Metadata.Catalogs);
	MetadataCollections.Add(Metadata.Documents);
	MetadataCollections.Add(Metadata.BusinessProcesses);
	MetadataCollections.Add(Metadata.Tasks);
	MetadataCollections.Add(Metadata.ChartsOfAccounts);
	MetadataCollections.Add(Metadata.ExchangePlans);
	MetadataCollections.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataCollections.Add(Metadata.ChartsOfCalculationTypes);
	
	For Each MetadataCollection IN MetadataCollections Do
		
		For Each MetadataObject IN MetadataCollection Do
			
			ObjectManager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
			EmptyRef = ObjectManager.EmptyRef();
			CatalogsNamesFilesStorage = CatalogsNamesFilesStorage(EmptyRef, True);
			
			For Each CatalogNameStorageFiles IN CatalogsNamesFilesStorage Do
				
				Result.Add(Metadata.Catalogs[CatalogNameStorageFiles.Key]);
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Returns metadata objects array that are
// used to store files binary data in the infobase.
//
// Return value: Array(MetadataObject).
//
Function InfobaseFilesStorageObjects() Export
	
	Result = New Array();
	Result.Add(Metadata.InformationRegisters.AttachedFiles);
	Return Result;
	
EndFunction

// Returns file extension.
//
// Object - CatalogObject.
//
Function FileExtension(Object) Export
	
	Return Object.Extension;
	
EndFunction

// For the service usage.
Procedure OnFileSending(DataItem,
                           ItemSend,
                           Val CreatingInitialImage = False,
                           Recipient = Undefined) Export
	
	If ItemSend = DataItemSend.Delete
		OR ItemSend = DataItemSend.Ignore Then
		
		// Do not override standard data processor.
		
	ElsIf IsItemAttachedFiles(DataItem) Then
		
		If CreatingInitialImage Then
			
			If DataItem.FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
				
				If Recipient <> Undefined
					AND Recipient.AdditionalProperties.Property("PlaceFilesIntoInitialImage") Then
					
					// Put file data from volume on disc to catalog service attribute.
					PlaceFileIntoCatalogAttribute(DataItem);
					
				Else
					
					// Copy file from volume on disc to catalog of initial image creation.
					FilesDirectoryName = CommonSettingsStorage.Load("FilesExchange", "TemporaryDirectory");
					
					FullPath = FileFunctionsService.FullPathOfVolume(DataItem.Volume) + DataItem.PathToFile;
					UUID = DataItem.Ref.UUID();
					
					NewPathFile = CommonUseClientServer.GetFullFileName(
							FilesDirectoryName,
							String(UUID) + "CatalogRef_" + DataItem.Metadata().Name);
					
					FileFunctionsService.CopyFileOnInitialImageCreation(FullPath, NewPathFile);
					
				EndIf;
				
			Else
				
				// If file is stored in IB, then while creating
				// an initial image it will be exported within the AttachedFiles information register.
				
			EndIf;
			
		Else
			
			If DataItem.FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
				
				// Put file data from volume on disc to catalog service attribute.
				PlaceFileIntoCatalogAttribute(DataItem);
				
			Else // Enums.FileStorageTypes.InInfobase
				
				Try
					// Put file data from infobase to catalog service attribute.
					AddressInTemporaryStorage = AttachedFiles.GetFileData(DataItem.Ref).FileBinaryDataRef;
					DataItem.FileStorage = New ValueStorage(GetFromTempStorage(AddressInTemporaryStorage), New Deflation(9));
				Except
					// File may not have been found. Do not abort data sending.
					WriteLogEvent(
						NStr("en='Files. Failed to send the file when exchanging the data';ru='Файлы.Не удалось отправить файл при обмене данными'",
						     CommonUseClientServer.MainLanguageCode()),
						EventLogLevel.Error,
						,
						,
						DetailErrorDescription(ErrorInfo()) );
					
					DataItem.FileStorage = New ValueStorage(Undefined);
				EndTry;
				
				DataItem.FileStorageType = Enums.FileStorageTypes.InInfobase;
				DataItem.PathToFile = "";
				DataItem.Volume = Catalogs.FileStorageVolumes.EmptyRef();
				
			EndIf;
			
		EndIf;
		
	ElsIf TypeOf(DataItem) = Type("InformationRegisterRecordSet.AttachedFilesExist") Then
		
		// Each node has its own object identifiers. Reset before sending.
		For Each Record IN DataItem Do
			Record.ObjectID = "";
		EndDo;
		
	ElsIf TypeOf(DataItem) = Type("InformationRegisterRecordSet.AttachedFiles")
		AND Not CreatingInitialImage Then
		
		// Export the register only when you create initial image.
		ItemSend = DataItemSend.Ignore;
		
	EndIf;
	
EndProcedure

// Only for internal use.
//
Procedure ExportFile(Val ObjectFile, Val NewFileName) Export
	
	If ObjectFile.FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
		
		FullPath = FileFunctionsService.FullPathOfVolume(ObjectFile.Volume) + ObjectFile.PathToFile;
		FileCopy(FullPath, NewFileName);
		
	Else // Enums.FileStorageTypes.InInfobase
		
		AddressInTemporaryStorage = AttachedFiles.GetFileData(ObjectFile.Ref).FileBinaryDataRef;
		GetFromTempStorage(AddressInTemporaryStorage).Write(NewFileName);
		
	EndIf;
	
EndProcedure

// For the service usage.
Procedure OnReceiveFile(DataItem, ItemReceive) Export
	
	If ItemReceive = DataItemReceive.Ignore Then
		
		// Do not override standard data processor.
		
	ElsIf IsItemAttachedFiles(DataItem) Then
		
		If FileReceivingProhibited(DataItem) Then
			
			ItemReceive = DataItemReceive.Ignore;
			Return;
		EndIf;
		
		// Delete from volumes for existing files placed in volumes as while receiving a new file it will be placed to volume or infobase again.
		If Not DataItem.IsNew() Then
			
			FileVersion = CommonUse.ObjectAttributesValues(DataItem.Ref, "FileStorageType, Volume, PathToFile");
			
			If FileVersion.FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
				
				FormerPathOnVolume = FileFunctionsService.FullPathOfVolume(FileVersion.Volume) + FileVersion.PathToFile;
				
				FileFunctionsService.DeleteFilesAtServer(FormerPathOnVolume);
				
			EndIf;
			
		EndIf;
		
		If FileFunctionsService.TypeOfFileStorage() = Enums.FileStorageTypes.InVolumesOnDrive Then
			
			// By exchange an item came with the storage in the base - but you should store it in volumes in the base receiver.
			// Place file from the service attribute to volume and change FileStorageType to InVolumesOnDiscs.
			FileInformation = FileFunctionsService.AddFileToVolume(DataItem.FileStorage.Get(), 
				DataItem.ModificationDateUniversal, DataItem.Description, DataItem.Extension,, 
				DataItem.Encrypted);
			DataItem.PathToFile = FileInformation.PathToFile;
			DataItem.Volume        = FileInformation.Volume;
			
			DataItem.FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive;
			DataItem.FileStorage = New ValueStorage(Undefined);
			
		Else
			
			BinaryData = DataItem.FileStorage.Get();
			
			If TypeOf(BinaryData) = Type("BinaryData") Then
				DataItem.AdditionalProperties.Insert("FileBinaryData", BinaryData);
			EndIf;
			
			DataItem.FileStorage = New ValueStorage(Undefined);
			DataItem.Volume = Catalogs.FileStorageVolumes.EmptyRef();
			DataItem.PathToFile = "";
			DataItem.FileStorageType = Enums.FileStorageTypes.InInfobase;
			
		EndIf;
		
	ElsIf TypeOf(DataItem) = Type("InformationRegisterRecordSet.AttachedFilesExist") Then
		
		Set = InformationRegisters.AttachedFilesExist.CreateRecordSet();
		If DataItem.Filter.ObjectWithFiles.Use Then
			Set.Filter.ObjectWithFiles.Set(DataItem.Filter.ObjectWithFiles.Value);
		EndIf;
		Set.Read();
		
		OldData = Set.Unload();
		OldData.Indexes.Add("ObjectWithFiles");
		
		// Each node has its own object identifiers. Restore before import.
		For Each Record IN DataItem Do
			String = OldData.Find(Record.ObjectWithFiles, "ObjectWithFiles");
			If String <> Undefined Then
				Record.ObjectID = String.ObjectID;
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

// Only for internal use.
//
Procedure ImportFile(Val ObjectFile, Val PathToFile) Export
	
	BinaryData = New BinaryData(PathToFile);
	
	If FileFunctionsService.TypeOfFileStorage() = Enums.FileStorageTypes.InVolumesOnDrive Then
		
		// Add file to one of the volumes (where there is a vacant place).
		FileInformation = FileFunctionsService.AddFileToVolume(BinaryData, ObjectFile.ModificationDateUniversal,
			ObjectFile.Description, ObjectFile.Extension, ObjectFile.VersionNumber, ObjectFile.Encrypted);
		ObjectFile.PathToFile = FileInformation.PathToFile;
		ObjectFile.Volume        = FileInformation.Volume;
		ObjectFile.FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive;
		ObjectFile.FileStorage = New ValueStorage(Undefined);
		
	Else
		
		ObjectFile.AdditionalProperties.Insert("FileBinaryData", BinaryData);
		ObjectFile.FileStorage = New ValueStorage(Undefined);
		ObjectFile.Volume = Catalogs.FileStorageVolumes.EmptyRef();
		ObjectFile.PathToFile = "";
		ObjectFile.FileStorageType = Enums.FileStorageTypes.InInfobase;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Updates the file properties while editing end.
//
// Parameters:
//  AttachedFile - Ref to the attached file.
//  InformationAboutFile   - Structure with properties:
//                           <mandatory>
//                            FileAddressInTemporaryStorage - String - address of new binary file data.
//                            TextTemporaryStorageAddress   - String - address of new
//                                                            binary data of a text extracted from the file.
//                           <optional>
//                            ModificationDateUniversal     - Date - date of the last
//                                                            file modification if a property is not set
//                                                            or specified, then the current session date is set.
//                            Extension                        - String - new file extension.
//
Procedure PlaceFileIntoStorageAndRelease(Val AttachedFile, Val InformationAboutFile) Export
	
	InformationAboutFile.Insert("IsEditing", Catalogs.Users.EmptyRef());
	
	AttachedFiles.UpdateAttachedFile(AttachedFile, InformationAboutFile)
	
EndProcedure

// Cancels file editing.
//
// Parameters:
//  AttachedFile - Ref or Object of the attached file to be released.
//
Procedure ReleaseFile(Val AttachedFile) Export
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
		FileObject = AttachedFile.GetObject();
		FileObject.Lock();
	Else
		FileObject = AttachedFile;
	EndIf;
	
	If ValueIsFilled(FileObject.IsEditing) Then
		FileObject.IsEditing = Catalogs.Users.EmptyRef();
		FileObject.Write();
	EndIf;
	
EndProcedure

// Marks a file as being edited.
//
// Parameters:
//  AttachedFile - Ref or Object of the attached file to be marked.
//
Procedure LockFileForEditingServer(Val AttachedFile) Export
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
		FileObject = AttachedFile.GetObject();
		FileObject.Lock();
	Else
		FileObject = AttachedFile;
	EndIf;
	
	FileObject.IsEditing = Users.AuthorizedUser();
	FileObject.Write();
	
EndProcedure

// Places encrypted file data to storage and sets the Encrypted flag to file.
//
// Parameters:
//  AttachedFile    - Ref to the attached file.
//  EncryptedData   - Structure with a property:
//                     TemporaryStorageAddress - String - address of encrypted binary data.
//  ThumbprintArray - Thumbprints structures array by certificates.
// 
Procedure Encrypt(Val AttachedFile, Val EncryptedData, Val ThumbprintArray) Export
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
		AttachedFileObject = AttachedFile.GetObject();
		AttachedFileObject.Lock();
	Else
		AttachedFileObject = AttachedFile;
	EndIf;
	
	For Each ThumbprintStructure IN ThumbprintArray Do
		NewRow = AttachedFileObject.EncryptionCertificates.Add();
		NewRow.Imprint = ThumbprintStructure.Imprint;
		NewRow.Presentation = ThumbprintStructure.Presentation;
		NewRow.Certificate = New ValueStorage(ThumbprintStructure.Certificate);
	EndDo;
	
	ValueAttributes = New Structure;
	ValueAttributes.Insert("Encrypted", True);
	ValueAttributes.Insert("TextStorage", New ValueStorage(""));
	UpdateBinaryDataOfFileAtServer(AttachedFileObject, EncryptedData.TemporaryStorageAddress, ValueAttributes);
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
		AttachedFileObject.Write();
		AttachedFileObject.Unlock();
	EndIf;
	
EndProcedure

// Puts decrypted file data to storage and clears Encrypted flag from file.
// 
// Parameters:
//  AttachedFile  - Ref to the attached file.
//  EncryptedData - Structure with a property:
//                    TemporaryStorageAddress - String - address of decrypted binary data.
//
Procedure Decrypt(Val AttachedFile, Val DecryptedData) Export
	
	Var Cancel;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
		AttachedFileObject = AttachedFile.GetObject();
		AttachedFileObject.Lock();
	Else
		AttachedFileObject = AttachedFile;
	EndIf;
	
	AttachedFileObject.EncryptionCertificates.Clear();
	
	ValueAttributes = New Structure;
	ValueAttributes.Insert("Encrypted", False);
	
	BinaryData = GetFromTempStorage(DecryptedData.TemporaryStorageAddress);
	TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	ExtractedText = "";
	
	If IsTempStorageURL(DecryptedData.TextTemporaryStorageAddress) Then
		ExtractedText = FileFunctionsService.GetStringFromTemporaryStorage(DecryptedData.TextTemporaryStorageAddress);
		TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		
	ElsIf Not FileFunctionsService.ExtractFileTextsAtServer() Then
		// Texts are extracted at once not in a background job.
		TextExtractionStatus = ExtractText(BinaryData, AttachedFile.Extension, ExtractedText);
	EndIf;
	
	AttachedFileObject.TextExtractionStatus = TextExtractionStatus;
	
	ValueAttributes.Insert("TextStorage", New ValueStorage(ExtractedText, New Deflation(9)));
	
	UpdateBinaryDataOfFileAtServer(AttachedFileObject, BinaryData, ValueAttributes);
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
		AttachedFileObject.Write();
		AttachedFileObject.Unlock();
	EndIf;
	
EndProcedure

// Replaces binary file data in the IB with data in a temporary storage.
Procedure UpdateBinaryDataOfFileAtServer(Val AttachedFile,
                                               Val FileURLInTemporaryStorageOfBinaryData,
                                               Val ValueAttributes = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
		FileObject = AttachedFile.GetObject();
		FileObject.Lock();
		FileRef = AttachedFile;
	Else
		FileObject = AttachedFile;
		FileRef = FileObject.Ref;
	EndIf;
	
	If TypeOf(FileURLInTemporaryStorageOfBinaryData) = Type("BinaryData") Then
		BinaryData = FileURLInTemporaryStorageOfBinaryData;
	Else
		BinaryData = GetFromTempStorage(FileURLInTemporaryStorageOfBinaryData);
	EndIf;
	
	FileObject.Changed = Users.AuthorizedUser();
	
	If TypeOf(ValueAttributes) = Type("Structure") Then
		FillPropertyValues(FileObject, ValueAttributes);
	EndIf;
	
	TransactionActive = False;
	
	Try
		If FileObject.FileStorageType = Enums.FileStorageTypes.InInfobase Then
			BeginTransaction();
			TransactionActive = True;
			RecordManager = InformationRegisters.AttachedFiles.CreateRecordManager();
			RecordManager.AttachedFile = FileRef;
			RecordManager.Read();
			RecordManager.AttachedFile = FileRef;
			RecordManager.StoredFile = New ValueStorage(BinaryData, New Deflation(9));
			RecordManager.Write();
		Else
			FullPath = FileFunctionsService.FullPathOfVolume(FileObject.Volume) + FileObject.PathToFile;
			
			Try
				FileOnDrive = New File(FullPath);
				FileOnDrive.SetReadOnly(False);
				DeleteFiles(FullPath);
				
				FileInformation = FileFunctionsService.AddFileToVolume(BinaryData, FileObject.ModificationDateUniversal,
					FileObject.Description, FileObject.Extension,, FileObject.Encrypted);
				FileObject.PathToFile = FileInformation.PathToFile;
				FileObject.Volume = FileInformation.Volume;
			Except
				ErrorInfo = ErrorInfo();
				WriteLogEvent(
					NStr("en='Files. The file record on a disk';ru='Файлы.Запись файла на диск'", CommonUseClientServer.MainLanguageCode()),
					EventLogLevel.Error,
					Metadata.Catalogs[FileRef.Metadata().Name],
					FileRef,
					ErrorTextOnSavingFileInVolume(DetailErrorDescription(ErrorInfo), FileRef));
				
				Raise ErrorTextOnSavingFileInVolume(BriefErrorDescription(ErrorInfo), FileRef);
			EndTry;
			
		EndIf;
		
		FileObject.Size = BinaryData.Size();
		
		FileObject.Write();
		
		If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
			FileObject.Unlock();
		EndIf;
		
		If TransactionActive Then
			CommitTransaction();
		EndIf;
		
	Except
		If TransactionActive Then
			RollbackTransaction();
		EndIf;
		WriteLogEvent(
			NStr("en='Files. Update of the attached file data to the files storage';ru='Файлы.Обновление данных присоединенного файла в хранилище файлов'",
			     CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,
			,
			,
			DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// Writes file binary data to the info base.
//
// Parameters:
//  AttachedFile - Ref to the attached file.
//  BinaryData   - BinaryData to be rewritten.
//
Procedure WriteFileToInformationBase(Val AttachedFile, Val BinaryData) Export
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.AttachedFiles.CreateRecordManager();
	RecordManager.AttachedFile = AttachedFile;
	RecordManager.StoredFile = New ValueStorage(BinaryData, New Deflation(9));
	RecordManager.Write(True);
	
EndProcedure

// Determines whether at least one file attached to the object.
Function ObjectHasFiles(Val FilesOwner, Val FileException = Undefined) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Parameters.Insert("FilesOwner", FilesOwner);
	
	QueryText =
	"SELECT
	|	AttachedFiles.Ref
	|FROM
	|	&CatalogName AS AttachedFiles
	|WHERE
	|	AttachedFiles.FileOwner = &FilesOwner";
	
	If FileException <> Undefined Then
		QueryText =  QueryText +
		"
		|	AND AttachedFiles.Ref <> &Ref";
		
		Query.Parameters.Insert("Ref", FileException);
	EndIf;
	
	NamesOfCatalogs = CatalogsNamesFilesStorage(FilesOwner);
	
	For Each KeyAndValue IN NamesOfCatalogs Do
		Query.Text = StrReplace(
			QueryText, "&CatalogName", "Catalog." + KeyAndValue.Key);
		
		If Not Query.Execute().IsEmpty() Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Returns attached files array for the specified owner.
//
// Parameters:
//  FilesOwner - Ref to the attached files owner.
//
// Returns:
//  Array of references to attached files.
//
Function GetAllSubordinateFiles(Val FilesOwner) Export
	
	SetPrivilegedMode(True);
	
	NamesOfCatalogs = CatalogsNamesFilesStorage(FilesOwner);
	TextOfQueries = "";
	
	For Each KeyAndValue IN NamesOfCatalogs Do
		If ValueIsFilled(TextOfQueries) Then
			TextOfQueries = TextOfQueries + 
			"
			|UNION ALL
			|
			|";
		EndIf;
		QueryText =
		"SELECT
		|	AttachedFiles.Ref
		|FROM
		|	&CatalogName AS AttachedFiles
		|WHERE
		|	AttachedFiles.FileOwner = &FilesOwner";
		QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + KeyAndValue.Key);
		TextOfQueries = TextOfQueries + QueryText;
	EndDo;
	
	Query = New Query(TextOfQueries);
	Query.SetParameter("FilesOwner", FilesOwner);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Handler of subscription to the "Before deleting" event of the attached file.
Procedure BeforeAttachedFileDeletingServer(Val Ref,
                                                   Val FilesOwner,
                                                   Val Volume,
                                                   Val FileStorageType,
                                                   Val PathToFile) Export
	
	SetPrivilegedMode(True);
	
	If Not ObjectHasFiles(FilesOwner, Ref) Then
		RecordManager = InformationRegisters.AttachedFilesExist.CreateRecordManager();
		RecordManager.ObjectWithFiles = FilesOwner;
		RecordManager.Read();
		If RecordManager.Selected() Then
			RecordManager.HasFiles = False;
			RecordManager.Write();
		EndIf;
	EndIf;
	
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
		If Not Volume.IsEmpty() Then
			FullPath = FileFunctionsService.FullPathOfVolume(Volume) + PathToFile;
			Try
				File = New File(FullPath);
				File.SetReadOnly(False);
				DeleteFiles(FullPath);
				PathWithSubdirectory = File.Path;
				FileArrayInDirectory = FindFiles(PathWithSubdirectory, "*.*");
				If FileArrayInDirectory.Count() = 0 Then
					DeleteFiles(PathWithSubdirectory);
				EndIf;
			Except
				// If a file is not deleted - no error occurred.
			EndTry;
		EndIf;
	EndIf;
	
EndProcedure

// Handler of the "during writing" subscription of the attached file.
//
Procedure OnAttachedFileWriteServer(FilesOwner) Export
	
	SetPrivilegedMode(True);
	
	RecordChanged = False;
	
	RecordManager = InformationRegisters.AttachedFilesExist.CreateRecordManager();
	RecordManager.ObjectWithFiles = FilesOwner;
	RecordManager.Read();
	
	If Not ValueIsFilled(RecordManager.ObjectWithFiles) Then
		RecordManager.ObjectWithFiles = FilesOwner;
		RecordChanged = True;
	EndIf;
	
	If Not RecordManager.HasFiles Then
		RecordManager.HasFiles = True;
		RecordChanged = True;
	EndIf;
	
	If IsBlankString(RecordManager.ObjectID) Then
		RecordManager.ObjectID = GetNextObjectIdentifier();
		RecordChanged = True;
	EndIf;
	
	If RecordChanged Then
		RecordManager.Write();
	EndIf;
	
EndProcedure

// Creates copies of all Source attached files in Receiver.
// Source and Recipient should be objects of the same type.
//
// Parameters:
//  Source    - Ref - object that has the attached files for copying.
//  Recipient - Ref - object to which attached files are copied.
//
Procedure CopyAttachedFiles(Val Source, Val Recipient) Export
	
	CopiedFiles = GetAllSubordinateFiles(Source.Ref);
	For Each CopiedFile IN CopiedFiles Do
		If CopiedFile.DeletionMark Then
			Continue;
		EndIf;
		ObjectManager = CommonUse.ObjectManagerByRef(CopiedFile);
		CopyFile = CopiedFile.Copy();
		FileCopyRef = ObjectManager.GetRef();
		CopyFile.SetNewObjectRef(FileCopyRef);
		CopyFile.FileOwner = Recipient.Ref;
		CopyFile.IsEditing = Catalogs.Users.EmptyRef();
		
		CopyFile.TextStorage = New ValueStorage(CopiedFile.TextStorage.Get());
		CopyFile.FileStorage = New ValueStorage(CopiedFile.FileStorage.Get());
		
		CopyFile.DigitalSignatures.Clear();
		For Each CopyTableRow IN CopiedFile.DigitalSignatures Do
			TableRowCopy = CopyFile.DigitalSignatures.Add();
			FillPropertyValues(TableRowCopy, CopyTableRow);
			TableRowCopy.Signature = CopyTableRow.Signature;
			TableRowCopy.Certificate = CopyTableRow.Certificate;
		EndDo;
		
		CopyFile.EncryptionCertificates.Clear();
		For Each CopyTableRow IN CopiedFile.EncryptionCertificates Do
			TableRowCopy = CopyFile.EncryptionCertificates.Add();
			FillPropertyValues(TableRowCopy, CopyTableRow);
			TableRowCopy.Certificate = CopyTableRow.Certificate;
		EndDo;
		
		BinaryData = AttachedFiles.GetFileBinaryData(CopiedFile);
		CopyFile.FileStorageType = FileFunctionsService.TypeOfFileStorage();
		If FileFunctionsService.TypeOfFileStorage() = Enums.FileStorageTypes.InInfobase Then
			WriteFileToInformationBase(FileCopyRef, BinaryData);
		Else
			// Add to one of the volumes (where free space is).
			FileInformation = FileFunctionsService.AddFileToVolume(BinaryData, CopyFile.ModificationDateUniversal,
				CopyFile.Description, CopyFile.Extension);
			CopyFile.PathToFile = FileInformation.PathToFile;
			CopyFile.Volume = FileInformation.Volume;
		EndIf;
		CopyFile.Write();
	EndDo;
	
EndProcedure

// Extracts text from binary data, returns extraction status.
Function ExtractText(Val BinaryData, Val Extension, ExtractedText) Export
	
	If FileFunctionsService.ThisIsWindowsPlatform()
	   AND FileFunctionsService.ExtractFileTextsAtServer() Then
		
		TempFileName = GetTempFileName(Extension);
		BinaryData.Write(TempFileName);
		
		Cancel = False;
		ExtractedText = FileFunctionsServiceClientServer.ExtractTextToTemporaryStorage(TempFileName, , Cancel);
		
		Try
			DeleteFiles(TempFileName);
		Except
			WriteLogEvent(
				NStr("en='Files. Text extraction';ru='Файлы.Извлечение текста'",
				     CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				,
				,
				DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		If Cancel Then
			Return Enums.FileTextExtractionStatuses.ExtractFailed;
		Else
			Return Enums.FileTextExtractionStatuses.Extracted;
		EndIf;
	Else
		ExtractedText = "";
		Return Enums.FileTextExtractionStatuses.NotExtracted;
	EndIf;
	
EndFunction

// Clears ObjectID attribute if it contains incorrect characters.
Procedure ClearInformationRegisterIncorrectRecordsAttachedFilesPresence() Export
	
	QueryText = 
	"SELECT
	|	AttachedFilesExist.ObjectWithFiles,
	|	AttachedFilesExist.ObjectID
	|FROM
	|	InformationRegister.AttachedFilesExist AS AttachedFilesExist";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	
	RecordSet = InformationRegisters.AttachedFilesExist.CreateRecordSet();
	While Selection.Next() Do
		If IsOutsidersCharsInIdentifier(Selection.ObjectID) Then
			RecordSet.Filter.ObjectWithFiles.Set(Selection.ObjectWithFiles);
			RecordSet.Read();
			For Each Record IN RecordSet Do
				Record.ObjectID = "";
			EndDo;
			InfobaseUpdate.WriteData(RecordSet);
		EndIf;
	EndDo;
	
EndProcedure

// Returns catalog names match and Boolean
// values for the specified owner.
// 
// Parameters:
//  FilesOwner - Ref - object to which a file is added.
// 
Function CatalogsNamesFilesStorage(FilesOwner, NotCallingException = False) Export
	
	If TypeOf(FilesOwner) = Type("Type") Then
		TypeOfOwnerFiles = FilesOwner;
	Else
		TypeOfOwnerFiles = TypeOf(FilesOwner);
	EndIf;
	
	OwnerMetadata = Metadata.FindByType(TypeOfOwnerFiles);
	
	NamesOfCatalogs = New Map;
	NameStandardBasicCatalog = OwnerMetadata.Name + "AttachedFiles";
	If Metadata.Catalogs.Find(NameStandardBasicCatalog) <> Undefined Then
		NamesOfCatalogs.Insert(NameStandardBasicCatalog, True);
	EndIf;
	
	// Override standard catalog of the attached files storage.
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AttachedFiles\OnDeterminingFilesStorageCatalogs");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnDeterminingFilesStorageCatalogs(
			TypeOfOwnerFiles, NamesOfCatalogs);
	EndDo;
	
	AttachedFilesOverridable.OnDeterminingFilesStorageCatalogs(
		TypeOfOwnerFiles, NamesOfCatalogs);
	
	MainCatalogSpecified = False;
	
	For Each KeyAndValue IN NamesOfCatalogs Do
		
		If Metadata.Catalogs.Find(KeyAndValue.Key) = Undefined Then
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred while determining catalogs names to store files.
		|In files owner of
		|the type ""%1"" nonexistent catalog ""%2"" is specified.';ru='Ошибка при определении имен справочников для хранения файлов.
		|У владельца файлов
		|типа ""%1"" указан несуществующий справочник ""%2"".'"),
				String(TypeOfOwnerFiles),
				String(KeyAndValue.Key));
				
		ElsIf Right(KeyAndValue.Key, StrLen("AttachedFiles"))<> "AttachedFiles" Then
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred while determining catalogs names to store files.
		|In files owner of
		|the type ""%1"" catalog
		|name ""%2"" is specified without ending ""AttachedFiles"".';ru='Ошибка при определении имен справочников для хранения файлов.
		|У владельца файлов
		|типа ""%1"" указано
		|имя справочника ""%2"" без окончания ""ПрисоединенныеФайлы"".'"),
				String(TypeOfOwnerFiles),
				String(KeyAndValue.Key));
			
		ElsIf KeyAndValue.Value = Undefined Then
			NamesOfCatalogs.Insert(KeyAndValue.Key, False);
			
		ElsIf KeyAndValue.Value = True Then
			If MainCatalogSpecified Then
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='An error occurred while determining catalogs names to store files.
		|Files owner of the
		|type ""%1"" has main catalog specified more than ones.';ru='Ошибка при определении имен справочников для хранения файлов.
		|У владельца
		|файлов типа ""%1"" основной справочник указан более одного раза.'"),
					String(TypeOfOwnerFiles),
					String(KeyAndValue.Key));
			EndIf;
			MainCatalogSpecified = True;
		EndIf;
	EndDo;
	
	If NamesOfCatalogs.Count() = 0 Then
		
		If NotCallingException Then
			Return NamesOfCatalogs;
		EndIf;
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred while determining catalogs names to store files.
		|Files owner of the
		|type ""%1"" does not have catalogs to store files.';ru='Ошибка при определении имен справочников для хранения файлов.
		|У владельца
		|файлов типа ""%1"" не имеется справочников для хранения файлов.'"),
			String(TypeOfOwnerFiles));
	EndIf;
	
	Return NamesOfCatalogs;
	
EndFunction

// Returns catalog name for the specified owner
// and throws exception  if there are more than one.
// 
// Parameters:
//  FilesOwner   - Ref - object to which a file is added.
//  CatalogName  - String if it is
//                    filled in, then it is checked whether there is a catalog among owner catalogs to store files.
//                    If it is not filled in, returns name of the main catalog.
//  ErrorTitle      - String - error title .
//                  - Undefined - do not throw exception, return an empty string.
//  ParameterName   - String    - required parameter name to determine catalog name.
//  EndErrors       - String    - error end (only when ParameterName = Undefined).
// 
Function CatalogNameStorageFiles(FilesOwner, CatalogName = "",
	ErrorTitle = Undefined, EndErrors = Undefined) Export
	
	NotCallingException = (ErrorTitle = Undefined);
	NamesOfCatalogs = CatalogsNamesFilesStorage(FilesOwner, NotCallingException);
	
	If NamesOfCatalogs.Count() = 0 Then
		If NotCallingException Then
			Return "";
		EndIf;
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			ErrorTitle + Chars.LF +
			NStr("en='Owner of file ""%1"" of
		|the type ""%2"" does not have catalogs to store files.';ru='У владельца файлов
		|""%1"" типа ""%2"" нет справочников для хранения файлов.'"),
			String(FilesOwner),
			String(TypeOf(FilesOwner)));
	EndIf;
	
	If ValueIsFilled(CatalogName) Then
		If NamesOfCatalogs[CatalogName] <> Undefined Then
			Return CatalogName;
		EndIf;
	
		If NotCallingException Then
			Return "";
		EndIf;
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			ErrorTitle + Chars.LF +
			NStr("en='Owner of file ""%1"" of
		|the type ""%2"" does not have catalog ""%3"" to store files.';ru='У владельца файлов
		|""%1"" типа ""%2"" нет справочника ""%3"" для хранения файлов.'"),
			String(FilesOwner),
			String(TypeOf(FilesOwner)),
			String(CatalogName));
	EndIf;
	
	MainCatalog = "";
	For Each KeyAndValue IN NamesOfCatalogs Do
		If KeyAndValue.Value = True Then
			MainCatalog = KeyAndValue.Key;
			Break;
		EndIf;
	EndDo;
	
	If ValueIsFilled(MainCatalog) Then
		Return MainCatalog;
	EndIf;
		
	If NotCallingException Then
		Return "";
	EndIf;
	
	TemplateErrorReasons = 
		NStr("en='Main catalog for file storage
		|is not specified in owner of file ""%1"" of the type ""%2"".';ru='У владельца файлов
		|""%1"" типа ""%2"" не указан основной справочник для хранения файлов.'") + Chars.LF;
			
	CauseErrors = StringFunctionsClientServer.PlaceParametersIntoString(
		TemplateErrorReasons, String(FilesOwner), String(TypeOf(FilesOwner)));
		
	ErrorText = ErrorTitle + Chars.LF
		+ CauseErrors + Chars.LF
		+ EndErrors;
		
	Raise TrimAll(ErrorText);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see description of the OnSendDataToSubordinate event handler in the syntax helper.
// 
Procedure OnSendDataToSubordinate(DataItem, ItemSend, CreatingInitialImage, Recipient) Export
	
	OnFileSending(DataItem, ItemSend, CreatingInitialImage, Recipient);
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see description of the OnSendDataMain() event handler in the syntax helper.
// 
Procedure OnSendDataToMaster(DataItem, ItemSend, Recipient) Export
	
	OnFileSending(DataItem, ItemSend);
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of the event handler WhenDataIsReceivedFromSecondary() in the syntax helper.
// 
Procedure OnReceiveDataFromSubordinate(DataItem, ItemReceive, SendBack, Sender) Export
	
	OnReceiveFile(DataItem, ItemReceive);
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of event handler WhenDataIsReceivedFromMain() in syntax helper.
// 
Procedure OnReceiveDataFromMaster(DataItem, ItemReceive, SendBack, Sender) Export
	
	OnReceiveFile(DataItem, ItemReceive);
	
EndProcedure

// Fills the array with the list of metadata objects names that might include
// references to different metadata objects with these references ignored in the business-specific application logic
//
// Parameters:
//  Array - array of strings for example "InformationRegister.ObjectsVersions".
//
Procedure OnAddExceptionsSearchLinks(Array) Export
	
	Array.Add(Metadata.InformationRegisters.AttachedFilesExist.FullName());
	
EndProcedure

// Adds file to volume when "Allocate the files of initial image".
//
Procedure WhenConfidentialityOfFilesInVolumeWhenPlacing(FilesPathCompliance, StoreFilesInVolumesOnHardDisk, AttachedFiles) Export
	
	AddFilesToVolumesOnPlacing(FilesPathCompliance, StoreFilesInVolumesOnHardDisk, AttachedFiles);
	
EndProcedure

// Deletes the history of modifications after "Allocate the files of initial image".
//
Procedure RegistrationChangesOnDelete(ExchangePlanRef, AttachedFiles) Export
	
	DeleteChangeRecords(ExchangePlanRef, AttachedFiles);
	
EndProcedure

// It fills the query text to receive files with the text not extracted.
// You can receive another request as a parameter and you shall merge with it.
// 
// Parameters:
//  QueryText   - String (return value), variants of passed values:
//                 Blank string   - the required query text will be returned.
//                 String is not empty - the required query text added to the passed text using COMBINE ALL will be returned.
// 
//  GetAllFiles - Boolean - Initial value is False. It allows you to disable file filtering by parts if True is passed.
//
Procedure WhenDefiningTextQueryForTextRetrieval(QueryText, GetAllFiles = False) Export
	
	// Query text is generated by all catalogs of attached files.
	
	OwnerTypes = Metadata.InformationRegisters.AttachedFilesExist.Dimensions.ObjectWithFiles.Type.Types();
	
	TypeCount = OwnerTypes.Count();
	If TypeCount = 0 Then
		Return;
	EndIf;
	
	CatalogAllNames = New Map;
	
	For Each Type IN OwnerTypes Do
		NamesOfCatalogs = CatalogsNamesFilesStorage(Type);
		
		For Each KeyAndValue IN NamesOfCatalogs Do
			If CatalogAllNames[KeyAndValue.Key] <> Undefined Then
				Continue;
			EndIf;
			CatalogAllNames.Insert(KeyAndValue.Key, True);
		EndDo;
	EndDo;
	
	FilesNumberInSelection = Int(100 / CatalogAllNames.Count());
	FilesNumberInSelection = ?(FilesNumberInSelection < 10, 10, FilesNumberInSelection);
	
	For Each KeyAndValue IN CatalogAllNames Do
	
		If Not IsBlankString(QueryText) Then
			QueryText = QueryText +
			"
			|
			|UNION ALL
			|
			|";
		EndIf;
		
		QueryText = QueryText + QueryTextForFilesWithUnextractedText(
			KeyAndValue.Key,
			FilesNumberInSelection,
			GetAllFiles);
	EndDo;
	
EndProcedure

// Returns the number of files with unextracted text.
//
Procedure OnDeterminingNumberOfVersionsWithNotImportedText(NumberOfVersions) Export
	
	NumberOfVersions = 0;
	NumberOfVersions = NumberOfVersions + GetVersionsNumberWithNotExtractedText();
	
EndProcedure

// It writes the extracted text.
//
Procedure OnWriteExtractedText(FileObject) Export
	
	If Not IsItemAttachedFiles(FileObject) Then
		Return;
	EndIf;
	
	FileObject.DataExchange.Load = True;
	FileObject.Write();
	
EndProcedure

// It returns the number of files in the volumes in CountFilesInVolumes parameter
//
Procedure OnDeterminingNumberOfFilesInVolumes(CountFilesInVolumes) Export
	
	DetermineCountOfFilesInVolumes(CountFilesInVolumes);
	
EndProcedure

// It returns True in ThereAreStoredFiles parameter if there are stored files to ExternalObject object.
//
Procedure OnDeterminingExistenceOfStoredFiles(ExternalObject, AreStoredFiles) Export
	
	DetermineStoredFilesExisting(ExternalObject, AreStoredFiles);
	
EndProcedure

// It returns the array of stored files to the ExternalObject object in the StoredFiles parameter.
//
Procedure OnStoredFilesGetting(ExternalObject, StoredFiles) Export
	
	GetStoredFiles(ExternalObject, StoredFiles);
	
EndProcedure

// Returns navigation reference to file (to attribute or temporary storage).
//
Procedure WhenDefiningNavigationLinksFile(FileRef, UUID, URL) Export
	
	If IsItemAttachedFiles(FileRef) Then
		URL = AttachedFiles.GetFileData(FileRef, UUID).FileBinaryDataRef;
	EndIf;
	
EndProcedure

// Receives full path to the file on the disk.
//
Procedure OnDeterminingFileWithNameByBinaryData(FileRef, PathToFile, PathIsEmptyForEmptyData = False) Export
	
	If IsItemAttachedFiles(FileRef) Then
		PathToFile = GetFileNameWithPathToBinaryData(FileRef, PathIsEmptyForEmptyData);
	EndIf;
	
EndProcedure

// Used to receive metadata objects that should be included in the
// content of the exchange plan and should NOT be included in the content of subscriptions to the events of changes registration for this plan.
// These metadata objects are used only at the time of creation
// of the initial image of the subnode and do not migrate during the exchange.
// If the subsystem has metadata objects that take part in creating an initial
// image of the subnode, the <Object> parameter needs to be added to these metadata objects.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects.
//
Procedure OnGetPrimaryImagePlanExchangeObjects(Objects) Export
	
	Objects.Add(Metadata.InformationRegisters.AttachedFiles);
	
EndProcedure

// Fills in listing of subsystem integration  handlers.
// "ServiceTechnology.SaaS.FileFunctionsSaaS"
//
// Parameters:
//  Handlers - Array(String), name of the handler general mode,
//
Procedure OnFillFileFunctionsIntegrationHandlersSaaS(Handlers) Export
	
	Handlers.Add("AttachedFilesService");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Adds and deletes records from the TextExtraction information
// register while changing state of files version text extraction.
//
// Parameters:
// SourceText - CatalogRef.FileVersions,
// 	CatalogRef.*AttachedFiles file which text extraction state was changed.
// TextExtractionState - EnumRef.FileTextExtractionStatuses,
// 	new status of text extraction from file.
//
Procedure WhenUpdatingStatusQueueTextExtraction(SourceText, TextExtractionState) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.FileFunctionsSaaS") Then
		
		If CommonUse.UseSessionSeparator() Then
			ModuleFileFunctionsAuxilarySaaS = CommonUse.CommonModule("FileFunctionsServiceSaaS");
			ModuleFileFunctionsAuxilarySaaS.RefreshTextExtractionQueueStatus(SourceText, TextExtractionState);
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

Function FileReceivingProhibited(DataItem)
	
	Return DataItem.IsNew()
	   AND Not FileFunctionsServiceClientServer.CheckFileExtensionForImporting(
	          DataItem.Extension, False);
	
EndFunction

Procedure PlaceFileIntoCatalogAttribute(DataItem)
	
	Try
		// Put file data from volume on disc to catalog service attribute.
		DataItem.FileStorage = FileFunctionsService.PutBinaryDataIntoStorage(DataItem.Volume, DataItem.PathToFile, DataItem.Ref.UUID());
	Except
		// File may not have been found. Do not abort data sending.
		WriteLogEvent(
			NStr("en='Files. Failed to send the file when exchanging the data';ru='Файлы.Не удалось отправить файл при обмене данными'",
			     CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,
			,
			,
			DetailErrorDescription(ErrorInfo()) );
		
		DataItem.FileStorage = New ValueStorage(Undefined);
	EndTry;
	
	DataItem.FileStorageType = Enums.FileStorageTypes.InInfobase;
	DataItem.PathToFile = "";
	DataItem.Volume = Catalogs.FileStorageVolumes.EmptyRef();
	
EndProcedure

// Returns object new identifier.
//  To select new identifier, it selects 
//  object last identifier from the
//  AttachedFilesPresence register, increases its value by one unit and returns the result.
//
// Returns:
//  Row (10) - object new identifier.
//
Function GetNextObjectIdentifier()
	
	// Calculate object new identifier.
	Result = "0000000000"; // By the ObjectID resource length.
	
	QueryText =
	"SELECT TOP 1
	|	AttachedFilesExist.ObjectID AS ObjectID
	|FROM
	|	InformationRegister.AttachedFilesExist AS AttachedFilesExist
	|
	|ORDER BY
	|	ObjectID DESC";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		ID = Selection.ObjectID;
		
		If IsBlankString(ID) Then
			Return Result;
		EndIf;
		
		// Calculation rules as in the regular
		// addition: during filling the current digit
		// position the next one increases by a unit and
		// in the current digit position the vakue becomes equal to zero. Values of digits
		// positions are characters [0..9] and [a..z]. This way one digit position
		// can contain 36 values.
		
		Position = 10; // 9- index of the 10th character
		While Position > 0 Do
			
			Char = Mid(ID, Position, 1);
			
			If Char = "z" Then
				ID = Left(ID, Position-1) + "0" + Right(ID, 10 - Position);
				Position = Position - 1;
				Continue;
				
			ElsIf Char = "9" Then
				NewChar = "a";
			Else
				NewChar = Char(CharCode(Char)+1);
			EndIf;
			
			ID = Left(ID, Position-1) + NewChar + Right(ID, 10 - Position);
			Break;
		EndDo;
		
		Result = ID;
	EndIf;
	
	Return Result;
	
EndFunction

Function QueryTextForFilesWithUnextractedText(Val CatalogName, Val FilesNumberInSelection, Val GetAllFiles = False)
	
	QueryText = 
	"SELECT TOP 1
	|	AttachedFiles.Ref AS Ref,
	|	AttachedFiles.TextExtractionStatus AS TextExtractionStatus,
	|	AttachedFiles.FileStorageType AS FileStorageType,
	|	AttachedFiles.Extension AS Extension,
	|	AttachedFiles.Description AS Description
	|FROM
	|	&CatalogName AS AttachedFiles
	|WHERE
	|	(AttachedFiles.TextExtractionStatus = VALUE(Enum.FileTextExtractionStatuses.NotExtracted)
	|			OR AttachedFiles.TextExtractionStatus = VALUE(Enum.FileTextExtractionStatuses.EmptyRef))
	|	AND Not AttachedFiles.Encrypted";
	
	QueryText = StrReplace(QueryText, "TOP 1", ?(
		GetAllFiles,
		"",
		"TOP " + Format(FilesNumberInSelection, "NG=; NZ=")) );
	
	QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + CatalogName);
	
	Return QueryText;
	
EndFunction

Function QueryTextForFilesNumberWithUnextractedText(Val CatalogName)
	
	QueryText = 
	"SELECT
	|	ISNULL(COUNT(AttachedFiles.Ref), 0) AS CountOfFiles
	|FROM
	|	&CatalogName AS AttachedFiles
	|WHERE
	|	(AttachedFiles.TextExtractionStatus = VALUE(Enum.FileTextExtractionStatuses.NotExtracted)
	|			OR AttachedFiles.TextExtractionStatus = VALUE(Enum.FileTextExtractionStatuses.EmptyRef))
	|	AND Not AttachedFiles.Encrypted";
	
	QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + CatalogName);
	
	Return QueryText;
	
EndFunction

// Returns an error text and adds a ref to
// the catalog item of the stored file to it.
//
Function ErrorTextOnSavingFileInVolume(Val ErrorInfo, Val File)
	
	Return StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='An error occurred while saving
		|file in volume: ""%1"".
		|
		|Ref to file: ""%2"".';ru='Ошибка, при сохранении
		|файла в томе: ""%1"".
		|
		|Ссылка на файл: ""%2"".'"),
		ErrorInfo,
		GetURL(File) );
	
EndFunction

Function IsOutsidersCharsInIdentifier(ID)
	
	For Position = 1 To StrLen(ID) Do
		Char = Mid(ID, Position, 1);
		If (CharCode(Char) < CharCode("a") Or CharCode(Char) > CharCode("z"))
			AND (CharCode(Char) < CharCode("0") Or CharCode(Char) > CharCode("9")) Then
				Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

#EndRegion
