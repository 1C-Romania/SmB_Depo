////////////////////////////////////////////////////////////////////////////////
// Subsystem "Working with files".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\OnGetListOfWarningsToCompleteJobs"].Add(
			"FileOperationsServiceClient");
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsOnComplete"].Add(
		"FileOperationsService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnSendDataToSubordinate"].Add(
		"FileOperationsService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnSendDataToMaster"].Add(
		"FileOperationsService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromSubordinate"].Add(
		"FileOperationsService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromMaster"].Add(
		"FileOperationsService");
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileFunctions") Then
		ServerHandlers["StandardSubsystems.FileFunctions\WhenConfidentialityOfFilesInVolumeWhenPlacing"].Add(
			"FileOperationsService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\RegistrationChangesOnDelete"].Add(
			"FileOperationsService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\WhenDefiningTextQueryForTextRetrieval"].Add(
			"FileOperationsServiceServerCall");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDeterminingNumberOfVersionsWithNotImportedText"].Add(
			"FileOperationsService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnWriteExtractedText"].Add(
			"FileOperationsService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDeterminingNumberOfFilesInVolumes"].Add(
			"FileOperationsService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDeterminingExistenceOfStoredFiles"].Add(
			"FileOperationsService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnStoredFilesGetting"].Add(
			"FileOperationsService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\WhenDefiningNavigationLinksFile"].Add(
			"FileOperationsService");
		
		ServerHandlers["StandardSubsystems.FileFunctions\OnDeterminingFileWithNameByBinaryData"].Add(
			"FileOperationsService");
	EndIf;
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"FileOperationsServiceServerCall");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddExceptionsSearchLinks"].Add(
		"FileOperationsService");
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillingInPossibleRightsForObjectRightsSettings"].Add(
			"FileOperationsService");
	
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillingKindsOfRestrictionsRightsOfMetadataObjects"].Add(
			"FileOperationsService");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnGetPrimaryImagePlanExchangeObjects"].Add(
		"FileOperationsService");
	
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.FileFunctionsSaaS") Then
		
		ServerHandlers["ServiceTechnology.SaaS.FileFunctionsSaaS\OnFillFileFunctionsIntegrationHandlersSaaS"].Add(
			"FileOperationsService");
		
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ServerHandlers["StandardSubsystems.CurrentWorks\AtFillingToDoList"].Add(
			"FileOperationsService");
	EndIf;
	
EndProcedure

// Returns True if this is a data item belonging to subsystem FileOperations.
//
Function ThisIsItemFileOperations(DataItem) Export
	
	Return TypeOf(DataItem) = Type("CatalogObject.FileVersions")
		OR TypeOf(DataItem) = Type("CatalogRef.FileVersions");
	
EndFunction

// Fills the structure of the parameters required
// for the client configuration code at logout.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure AddClientWorkParametersOnComplete(Parameters) Export
	
	 Parameters.Insert("FileOperations", GetParametersOnExit());
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures used during the data exchange.

// Returns catalogs array that are also file owners.
//
// Return value: Array(MetadataObject).
//
Function FileCatalogs() Export
	
	Result = New Array();
	Result.Add(Metadata.Catalogs.FileVersions);
	Return Result;
	
EndFunction

// Returns metadata objects array that are
// used to store files binary data in the infobase.
//
// Return value: Array(MetadataObject).
//
Function InfobaseFilesStorageObjects() Export
	
	Result = New Array();
	Result.Add(Metadata.InformationRegisters.VersionStoredFiles);
	Return Result;
	
EndFunction

// Returns file extension.
//
// Object - CatalogObject.
//
Function FileExtension(Object) Export
	
	Return Object.Extension;
	
EndFunction

// Only for internal use.
//
Procedure OnFileSending(DataItem, ItemSend, Val CreatingInitialImage = False, Recipient = Undefined) Export
	
	If ItemSend = DataItemSend.Delete
		OR ItemSend = DataItemSend.Ignore Then
		
		// Do not override standard data processor.
		
	ElsIf TypeOf(DataItem) = Type("CatalogObject.FileVersions") Then
		
		If CreatingInitialImage Then
			
			If DataItem.FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
				
				If Recipient <> Undefined
					AND Recipient.AdditionalProperties.Property("PlaceFilesIntoInitialImage") Then
					
					// Put file data from volume on disc to catalog service attribute.
					PlaceFileIntoCatalogAttribute(DataItem);
					
				Else
					
					// Copy file from volume on disc to catalog of initial image creation.
					FilesDirectoryName = String(CommonSettingsStorage.Load("FilesExchange", "TemporaryDirectory"));
					
					FullPath = FileFunctionsService.FullPathOfVolume(DataItem.Volume) + DataItem.PathToFile;
					UUID = DataItem.Ref.UUID();
					
					NewPathFile = CommonUseClientServer.GetFullFileName(
							FilesDirectoryName,
							UUID);
					
					FileFunctionsService.CopyFileOnInitialImageCreation(FullPath, NewPathFile);
					
				EndIf;
				
			Else
				
				// If the file is stored in IB then during
				// creation of initial image it will be exported with information register VersionStoredFiles.
				
			EndIf;
			
		Else
			
			If DataItem.FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
				
				// Put file data from volume on disc to catalog service attribute.
				PlaceFileIntoCatalogAttribute(DataItem);
				
			Else // Enums.FileStorageTypes.InInfobase
				
				Try
					// Put file data from infobase to catalog service attribute.
					AddressInTemporaryStorage = FileOperationsServiceServerCall.GetURLToTemporaryStorage(DataItem.Ref);
					DataItem.FileStorage = New ValueStorage(GetFromTempStorage(AddressInTemporaryStorage), New Deflation(9));
				Except
					// File may not have been found. Do not abort data sending.
					WriteLogEvent(EventLogMonitorForExchange(), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
					DataItem.FileStorage = New ValueStorage(Undefined);
				EndTry;
				
				DataItem.FileStorageType = Enums.FileStorageTypes.InInfobase;
				DataItem.PathToFile = "";
				DataItem.Volume = Catalogs.FileStorageVolumes.EmptyRef();
				
			EndIf;
			
		EndIf;
		
	ElsIf TypeOf(DataItem) = Type("InformationRegisterRecordSet.VersionStoredFiles")
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
		
		AddressInTemporaryStorage = FileOperationsServiceServerCall.GetURLToTemporaryStorage(ObjectFile.Ref);
		GetFromTempStorage(AddressInTemporaryStorage).Write(NewFileName);
		
	EndIf;
	
EndProcedure

// Only for internal use.
//
Procedure OnReceiveFile(DataItem, ItemReceive) Export
	
	If ItemReceive = DataItemReceive.Ignore Then
		
		// Do not override standard data processor.
		
	ElsIf TypeOf(DataItem) = Type("CatalogObject.Files")
		AND FileReceivingProhibited(DataItem) Then
		
		ItemReceive = DataItemReceive.Ignore;
		
	ElsIf TypeOf(DataItem) = Type("CatalogObject.FileVersions") Then
		
		If VersionFileReceivingProhibited(DataItem) Then
			
			ItemReceive = DataItemReceive.Ignore;
			Return;
		EndIf;
		
		// Delete from volumes for existing files placed in volumes
		// as while receiving a new file it will be placed to volume or infobase again.
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
				DataItem.ModificationDateUniversal, DataItem.Description, DataItem.Extension,
				DataItem.VersionNumber, DataItem.Encrypted); 
			DataItem.Volume = FileInformation.Volume;
			DataItem.PathToFile = FileInformation.PathToFile;
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
		
	EndIf;
	
EndProcedure

// Only for internal use.
//
Procedure ImportFile(Val ObjectFile, Val PathToFile) Export
	
	BinaryData = New BinaryData(PathToFile);
	
	If FileFunctionsService.TypeOfFileStorage() = Enums.FileStorageTypes.InVolumesOnDrive Then
		
		// Add file to one of the volumes (where there is a vacant place).
		FileInformation = FileFunctionsService.AddFileToVolume(BinaryData, 
			ObjectFile.ModificationDateUniversal, ObjectFile.Description, ObjectFile.Extension,
			ObjectFile.VersionNumber, ObjectFile.Encrypted); 
		ObjectFile.Volume = FileInformation.Volume;
		ObjectFile.PathToFile = FileInformation.PathToFile;
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

// Returns the objects that have attached (by means of subsystem "Work with files") files.
//
// Used together with AttachedFiles function.ConvertFilesToAttached().
//
// Parameters:
//  FilesOwnersTable - String - full name
//                            of metadata object that can own attached files.
//
Function RefsToObjectsWithFiles(Val FilesOwnersTable) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ObjectsWithFiles.Ref AS Ref
	|FROM
	|	&Table AS ObjectsWithFiles
	|WHERE
	|	TRUE In
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				Catalog.Files AS Files
	|			WHERE
	|				Files.FileOwner = ObjectsWithFiles.Ref)";
	
	Query.Text = StrReplace(Query.Text, "&Table", FilesOwnersTable);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into this subsystem.

// Writes attachments in folder.
// 
// Parameters: see the description of procedure "ExecuteDeliverty" of module "ReportsMailing".
//
Procedure OnTransferringToFolderExecution(TransportParameters, Attachments) Export
	
	// Transferring attachments to table
	SetPrivilegedMode(True);
	
	TableAttachment = New ValueTable;
	TableAttachment.Columns.Add("FileName",              New TypeDescription("String"));
	TableAttachment.Columns.Add("FullPathToFile",      New TypeDescription("String"));
	TableAttachment.Columns.Add("File",                  New TypeDescription("File"));
	TableAttachment.Columns.Add("FileRef",            New TypeDescription("CatalogRef.Files"));
	TableAttachment.Columns.Add("FileDescriptionWithoutExtension", Metadata.Catalogs.Files.Attributes.FullDescr.Type);
	
	SetPrivilegedMode(False);
	
	For Each Attachment IN Attachments Do
		TableRow = TableAttachment.Add();
		TableRow.FileName              = Attachment.Key;
		TableRow.FullPathToFile      = Attachment.Value;
		TableRow.File                  = New File(TableRow.FullPathToFile);
		TableRow.FileDescriptionWithoutExtension = TableRow.File.BaseName;
	EndDo;
	
	// Search for existing files
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	Files.Ref,
	|	Files.FullDescr
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner
	|	AND Files.FullDescr IN(&FileNameArray)";
	
	Query.SetParameter("FileOwner", TransportParameters.Folder);
	Query.SetParameter("FileNameArray", TableAttachment.UnloadColumn("FileDescriptionWithoutExtension"));
	
	ExistingFiles = Query.Execute().Unload();
	For Each File IN ExistingFiles Do
		TableRow = TableAttachment.Find(File.FullDescr, "FileDescriptionWithoutExtension");
		TableRow.FileRef = File.Ref;
	EndDo;
	
	Comment = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Report mailing %1 from %2';ru='Рассылка отчетов %1 от %2'"),
		"'"+ TransportParameters.Mailing +"'",
		Format(TransportParameters.ExecutionDate, "DLF=DT"));
	
	For Each Attachment IN TableAttachment Do
		
		FileInformation = FileOperationsClientServer.FileInformation("FileWithVersion", Attachment.File);
		FileInformation.FileTemporaryStorageAddress = PutToTempStorage(New BinaryData(Attachment.FullPathToFile));
		FileInformation.BaseName = Attachment.FileDescriptionWithoutExtension;
		FileInformation.Comment = Comment;
		
		// Record
		If ValueIsFilled(Attachment.FileRef) Then
			VersionRef = FileOperationsServiceServerCall.Create_Version(Attachment.FileRef, FileInformation);
			FileOperationsServiceServerCall.RefreshVersionInFile(Attachment.FileRef, VersionRef, FileInformation.TextTemporaryStorageAddress);
		Else
			Attachment.FileRef = FileOperationsServiceServerCall.CreateFileWithVersion(TransportParameters.Folder, FileInformation); 
		EndIf;
		
		// Filling in reference to file
		If TransportParameters.AddReferences <> "" Then
			TransportParameters.ReportPresentationsRecipient = StrReplace(
				TransportParameters.ReportPresentationsRecipient,
				Attachment.FullPathToFile,
				GetInfobaseURL() + "#" + GetURL(Attachment.FileRef));
		EndIf;
		
		// Clearing
		DeleteFromTempStorage(FileInformation.FileTemporaryStorageAddress);
	EndDo;
	
EndProcedure

// Sets deletion mark for all versions of a specified file.
Procedure MarkToDeleteFileVersions(Val FileRef, Val VersionException) Export
	
	QueryText =
	"SELECT
	|	FileVersions.Ref AS Ref
	|FROM
	|	Catalog.FileVersions AS FileVersions
	|WHERE
	|	FileVersions.Owner = &Owner
	|	AND Not FileVersions.DeletionMark
	|	AND FileVersions.Ref <> &Except";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Owner", FileRef);
	Query.SetParameter("Except", VersionException);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		VersionObject = Selection.Ref.GetObject();
		VersionObject.DeletionMark = True;
		VersionObject.AdditionalProperties.Insert("FileConversion", True);
		VersionObject.Write();
		
	EndDo;
	
EndProcedure

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.FileFolders.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.Files.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.FileVersions.FullName(), "EditedAttributesInGroupDataProcessing");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Fills in parameters structure required for client
// code work during the configuration end i.e. in the handlers.:
// - BeforeExit,
// - OnExit
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystemsOnComplete(Parameters) Export
	
	AddClientWorkParametersOnComplete(Parameters);
	
EndProcedure

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
//  Array       - array of strings for example "InformationRegister.ObjectsVersions".
//
Procedure OnAddExceptionsSearchLinks(Array) Export
	
	Array.Add(Metadata.InformationRegisters.FilesInWorkingDirectory.FullName());
	
EndProcedure

// Adds file to volume when "Allocate the files of initial image".
//
Procedure WhenConfidentialityOfFilesInVolumeWhenPlacing(FilesPathCompliance, StoreFilesInVolumesOnHardDisk, AttachedFiles) Export
	
	FileOperationsServiceServerCall.AddFilesToVolumesOnPlacing(FilesPathCompliance, StoreFilesInVolumesOnHardDisk);
	
EndProcedure

// Deletes the history of modifications after "Allocate the files of initial image".
//
Procedure RegistrationChangesOnDelete(ExchangePlanRef, AttachedFiles) Export
	
	FileOperationsServiceServerCall.DeleteChangeRecords(ExchangePlanRef);
	
EndProcedure

// Returns the number of files with unextracted text.
//
Procedure OnDeterminingNumberOfVersionsWithNotImportedText(NumberOfVersions) Export
	
	NumberOfVersions = 0;
	NumberOfVersions = NumberOfVersions + FileOperationsServiceServerCall.GetVersionsNumberWithNotExtractedText();
	
EndProcedure

// It writes the extracted text.
//
Procedure OnWriteExtractedText(FileObject) Export
	
	If ThisIsItemFileOperations(FileObject) Then
		FileOperationsServiceServerCall.OnWriteExtractedText(FileObject);
	EndIf;
	
EndProcedure

// It returns the number of files in the volumes in CountFilesInVolumes parameter
//
Procedure OnDeterminingNumberOfFilesInVolumes(CountFilesInVolumes) Export
	
	FileOperationsServiceServerCall.DetermineCountOfFilesInVolumes(CountFilesInVolumes);
	
EndProcedure

// It returns True in ThereAreStoredFiles parameter if there are stored files to ExternalObject object.
//
Procedure OnDeterminingExistenceOfStoredFiles(ExternalObject, AreStoredFiles) Export
	
	FileOperationsServiceServerCall.DetermineStoredFilesExisting(ExternalObject, AreStoredFiles);
	
EndProcedure

// It returns the array of stored files to the ExternalObject object in the StoredFiles parameter.
//
Procedure OnStoredFilesGetting(ExternalObject, StoredFiles) Export
	
	FileOperationsServiceServerCall.GetStoredFiles(ExternalObject, StoredFiles);
	
EndProcedure

// Returns navigation reference to file (to attribute or temporary storage).
//
Procedure WhenDefiningNavigationLinksFile(FileRef, UUID, URL) Export
	
	If ThisIsItemFileOperations(FileRef) Then
		URL = FileOperationsServiceServerCall.GetURLForOpening(FileRef, UUID);
	EndIf;
	
EndProcedure

// Receives full path to the file on the disk.
//
Procedure OnDeterminingFileWithNameByBinaryData(FileRef, PathToFile, PathIsEmptyForEmptyData = False) Export
	
	If ThisIsItemFileOperations(FileRef) Then
		PathToFile = FileOperationsServiceServerCall.GetFileNameWithPathToBinaryData(FileRef, PathIsEmptyForEmptyData);
	EndIf;
	
EndProcedure

// Fills in descriptions of possible rights appointed for objects, specified types.
// 
// Parameters:
//  PossibleRights - ValuesTable containing
//                   the fields description of which you can see in the comment to the function.
//                   InformationRegisters.ObjectRightsSettings.PossibleRights().
//
Procedure OnFillingInPossibleRightsForObjectRightsSettings(PossibleRights) Export
	
	////////////////////////////////////////////////////////////
	// Catalog.FileFolders
	
	// Right "Reading folders and files".
	Right = PossibleRights.Add();
	Right.RightsOwner  = "Catalog.FileFolders";
	Right.Name           = "Read";
	Right.Title     = NStr("en='Read';ru='Чтение'");
	Right.ToolTip     = NStr("en='Folders and files reading';ru='Чтение папок и файлов'");
	Right.InitialValue = True;
	// Rights for standard templates of access restrictions.
	Right.ReadingInTables.Add("*");
	
	// Right "Folders editing"
	Right = PossibleRights.Add();
	Right.RightsOwner  = "Catalog.FileFolders";
	Right.Name           = "FoldersUpdate";
	Right.Title     = NStr("en='Folders update';ru='Изменение папок'");
	Right.ToolTip     = NStr("en='Addition, change
		|and deletion mark of files folders';ru='Добавление, изменение и пометка удаления папок файлов'");
	// Rights required for this right.
	Right.RequiredRights.Add("Read");
	// Rights for standard templates of access restrictions.
	Right.ChangingInTables.Add("Catalog.FileFolders");
	
	// Right "Files editing"
	Right = PossibleRights.Add();
	Right.RightsOwner  = "Catalog.FileFolders";
	Right.Name           = "FilesUpdate";
	Right.Title     = NStr("en='Files update';ru='Изменение файлов'");
	Right.ToolTip     = NStr("en='Files editing in folder';ru='Изменение файлов в папке'");
	// Rights required for this right.
	Right.RequiredRights.Add("Read");
	// Rights for standard templates of access restrictions.
	Right.ChangingInTables.Add("*");
	
	// Right "Adding files"
	Right = PossibleRights.Add();
	Right.RightsOwner  = "Catalog.FileFolders";
	Right.Name           = "FilesAdd";
	Right.Title     = NStr("en='Files add';ru='Добавление файлов'");
	Right.ToolTip     = NStr("en='Adding files to folder';ru='Добавление файлов в папку'");
	// Rights required for this right.
	Right.RequiredRights.Add("FilesUpdate");
	
	// Right "Files deletion mark".
	Right = PossibleRights.Add();
	Right.RightsOwner  = "Catalog.FileFolders";
	Right.Name           = "FileDeletionMark";
	Right.Title     = NStr("en='Deletion mark';ru='ПометкаУдаления'");
	Right.ToolTip     = NStr("en='Deletion mark of files in folder';ru='Пометка удаления файлов в папке'");
	// Rights required for this right.
	Right.RequiredRights.Add("FilesUpdate");
	
	Right = PossibleRights.Add();
	Right.RightsOwner  = "Catalog.FileFolders";
	Right.Name           = "RightsManagement";
	Right.Title     = NStr("en='Rights management';ru='Управление правами'");
	Right.ToolTip     = NStr("en='Folder rights management';ru='Управление правами папки'");
	// Rights required for this right.
	Right.RequiredRights.Add("Read");
	
EndProcedure

// Fills the content of access kinds used when metadata objects rights are restricted.
// If the content of access kinds is not filled, "Access rights" report will show incorrect information.
//
// Only the access types clearly used
// in access restriction templates must be filled, while
// the access types used in access values sets may be
// received from the current data register AccessValueSets.
//
//  To prepare the procedure content
// automatically, you should use the developer tools for subsystem.
// Access management.
//
// Parameters:
//  Definition     - String, multiline string in format <Table>.<Right>.<AccessKind>[.Object table].
//                 For
//                           example,
//                           Document.SupplierInvoice.Read.Company
//                           Document.SupplierInvoice.Read.Counterparties
//                           Document.SupplierInvoice.Change.Companies
//                           Document.SupplierInvoice.Change.Counterparties
//                           Document.EMails.Read.Object.Document.EMails
//                           Document.EMails.Change.Object.Document.EMails
//                           Document.Files.Read.Object.Catalog.FileFolders
//                           Document.Files.Read.Object.Document.EMail
//                 Document.Files.Change.Object.Catalog.FileFolders Document.Files.Change.Object.Document.EMail Access kind Object predefined as literal. This access kind is
//                 used in the access limitations templates as "ref" to another
//                 object according to which the current table object is restricted.
//                 When the Object access kind is specified, you should
//                 also specify tables types that are used for this
//                 access kind. I.e. enumerate types that correspond to
//                 the field used in the access limitation template in the pair with the Object access kind. While enumerating types by the "Object"
//                 access kind, you need to list only those field types that the field has.
//                 InformationRegisters.AccessValueSets.Object, the rest types are extra.
// 
Procedure OnFillingKindsOfRestrictionsRightsOfMetadataObjects(Definition) Export
	
	Definition = Definition +
	"
	|Catalog.FileFolders.Reading.RightSettings.Catalog.FileFolders Catalog.FileFolders.Change.RightSettings.Catalog.FileFolders Catalog.FileVersions.Reading.Object.Catalog.FileFolders Catalog.FileVersions.Change.Object.Catalog.FileFolders Catalog.Files.Reading.Object.Catalog.FileFolders Catalog.Files.Change.Object.Catalog.FileFolders InformationRegister.VersionStoredFiles.Reading.Object.Catalog.FileFolders
	|";
	
	If CommonUse.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		Definition = Definition + 
		"
		|Catalog.FileVersions.Reading.Object.BusinessProcess.Task Catalog.Files.Reading.Object.BusinessProcess.Task Catalog.Files.Change.Object.BusinessProcess.Task InformationRegister.VersionStoredFiles.Reading.Object.BusinessProcess.Task
		|";
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
	
	Objects.Add(Metadata.InformationRegisters.VersionStoredFiles);
	
EndProcedure

// Fills in listing of subsystem integration  handlers.
// "ServiceTechnology.SaaS.FileFunctionsSaaS"
//
// Parameters:
//  Handlers - Array (Row), name of the handler general mode,
//
Procedure OnFillFileFunctionsIntegrationHandlersSaaS(Handlers) Export
	
	Handlers.Add("FileOperationsService");
	
EndProcedure

// Fills the user current work list.
//
// Parameters:
//  CurrentWorks - ValueTable - a table of values with the following columns:
//    * Identifier - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    * Important        - Boolean - If True, the work is marked in red.
//    * Presentation - String - a work presentation displayed to the user.
//    * Count    - Number  - a quantitative indicator of work, it is displayed in the work header string.
//    * Form         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner      - String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip     - String - The tooltip wording.
//
Procedure AtFillingToDoList(CurrentWorks) Export
	
	ModuleCurrentWorksService = CommonUse.CommonModule("CurrentWorksService");
	If Not AccessRight("Read", Metadata.Catalogs.Files)
		Or ModuleCurrentWorksService.WorkDisabled("EditableFiles") Then
		Return;
	EndIf;
	ModuleCurrentWorksServer = CommonUse.CommonModule("CurrentWorksServer");
	
	CountEmployedFiles = CountEmployedFiles(Users.CurrentUser());
	
	// The procedure is called only if there is the
	// To-do lists subsystem, that is why here is no checking of subsystem existence.
	Sections = ModuleCurrentWorksServer.SectionsForObject(Metadata.Catalogs.Files.FullName());
	
	If Sections = Undefined Then
		Return; // Interface for working with files is not displayed in command interface of the user.
	EndIf;
	
	For Each Section IN Sections Do
		
		IdentifierEditedFiles = "EditableFiles" + StrReplace(Section.FullName(), ".", "");
		Work = CurrentWorks.Add();
		Work.ID  = IdentifierEditedFiles;
		Work.ThereIsWork       = CountEmployedFiles > 0;
		Work.Presentation  = NStr("en='Edited files';ru='Редактируемые файлы'");
		Work.Quantity     = CountEmployedFiles;
		Work.Important         = False;
		Work.Form          = "Catalog.Files.Form.EditableFiles";
		Work.Owner       = Section;
		
	EndDo;
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////////////
// Work with encodings

// Function returns the table of encodings names.
// Returns:
// Result (ValuesList)
// - Value (String) - for example, "ibm852".
// - Presentation (String) - for example, "ibm852 (Central European DOS)".
//
Function GetEncodingsList() Export

	EncodingsList = New ValueList;
	
	EncodingsList.Add("ibm852",       NStr("en='IBM852 (Central European  DOS)';ru='IBM852 (Центральноевропейская DOS)'"));
	EncodingsList.Add("ibm866",       NStr("en='IBM866 (Cyrillic DOS)';ru='IBM866 (Кириллица DOS)'"));
	EncodingsList.Add("iso-8859-1",   NStr("en='ISO-8859-1 (Western European ISO)';ru='ISO-8859-1 (Западноевропейская ISO)'"));
	EncodingsList.Add("iso-8859-2",   NStr("en='ISO-8859-2 (Central European ISO)';ru='ISO-8859-2 (Центральноевропейская ISO)'"));
	EncodingsList.Add("iso-8859-3",   NStr("en='ISO-8859-3 (Latin 3 ISO)';ru='ISO-8859-3 (Латиница 3 ISO)'"));
	EncodingsList.Add("iso-8859-4",   NStr("en='ISO-8859-4 (Baltic ISO)';ru='ISO-8859-4 (Балтийская ISO)'"));
	EncodingsList.Add("iso-8859-5",   NStr("en='ISO-8859-5 (Cyrillic ISO)';ru='ISO-8859-5 (Кириллица ISO)'"));
	EncodingsList.Add("iso-8859-7",   NStr("en='ISO-8859-7 (Greek ISO)';ru='ISO-8859-7 (Греческая ISO)'"));
	EncodingsList.Add("iso-8859-9",   NStr("en='ISO-8859-9 (Turkish ISO)';ru='ISO-8859-9 (Турецкая ISO)'"));
	EncodingsList.Add("iso-8859-15",  NStr("en='ISO-8859-15 (Latin 9 ISO)';ru='ISO-8859-15 (Латиница 9 ISO)'"));
	EncodingsList.Add("koi8-r",       NStr("en='KOI8-R (Cyrillic KOI8-R)';ru='KOI8-R (Кириллица KOI8-R)'"));
	EncodingsList.Add("koi8-u",       NStr("en='KOI8-U (Cyrillic KOI8-U)';ru='KOI8-U (Кириллица KOI8-U)'"));
	EncodingsList.Add("us-ascii",     NStr("en='US-ASCII (USA)';ru='US-ASCII (США)'"));
	EncodingsList.Add("utf-8",        NStr("en='UTF-8 (Unicode UTF-8)';ru='UTF-8 (Юникод UTF-8)'"));
	EncodingsList.Add("windows-1250", NStr("en='Windows-1250 (Central European Windows)';ru='Windows-1250 (Центральноевропейская Windows)'"));
	EncodingsList.Add("windows-1251", NStr("en='windows-1251 (Cyrillic Windows)';ru='windows-1251 (Кириллица Windows)'"));
	EncodingsList.Add("windows-1252", NStr("en='Windows-1252 (Western European Windows)';ru='Windows-1252 (Западноевропейская Windows)'"));
	EncodingsList.Add("windows-1253", NStr("en='Windows-1253 (Greek Windows)';ru='Windows-1253 (Греческая Windows)'"));
	EncodingsList.Add("windows-1254", NStr("en='Windows-1254 (Turkish Windows)';ru='Windows-1254 (Турецкая Windows)'"));
	EncodingsList.Add("windows-1257", NStr("en='Windows-1257 (Baltic Windows)';ru='Windows-1257 (Балтийская Windows)'"));
	
	Return EncodingsList;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of the subscriptions to events.

// Handler of subscription "when writing" of file version.
//
Procedure FileVersionsOnWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		WriteDataFileIntoTableWhenExchange(Source);
		Return;
	EndIf;
	
	If Source.AdditionalProperties.Property("FileRenaming") Then
		Return;
	EndIf;
	
	If Source.AdditionalProperties.Property("FileConversion") Then
		Return;
	EndIf;
	
	// Copy attributes from version to file.
	CurrentVersion = Source;
	If Not CurrentVersion.Ref.IsEmpty() Then
	
		FileRef = Source.Owner;
		
		FileAttributes = CommonUse.ObjectAttributesValues(FileRef, 
			"PictureIndex, CurrentVersionSize, CurrentVersionCreationDate, CurrentVersionAuthor, CurrentVersionExtension, CurrentVersionVersionNumber, CurrentVersionVolume, CurrentVersionPathToFile, CurrentVersionCode, CurrentVersionFileModificationDate");
			
			If FileAttributes.CurrentVersionSize <> CurrentVersion.Size 
				OR FileAttributes.CurrentVersionCreationDate <> CurrentVersion.CreationDate
				OR FileAttributes.CurrentVersionExtension <> CurrentVersion.Extension
				OR FileAttributes.CurrentVersionVersionNumber <> CurrentVersion.VersionNumber
				OR FileAttributes.CurrentVersionVolume <> CurrentVersion.Volume
				OR FileAttributes.CurrentVersionPathToFile <> CurrentVersion.PathToFile 
				OR FileAttributes.CurrentVersionCode <> CurrentVersion.Code
				OR FileAttributes.PictureIndex <> CurrentVersion.PictureIndex
				OR FileAttributes.CurrentVersionFileModificationDate <> CurrentVersion.FileModificationDate
			Then
				FileObject = FileRef.GetObject();
				
				// Change image index, perhaps a version appeared or image index of the version has changed.
				FileObject.PictureIndex = CurrentVersion.PictureIndex;
				
				// Copy attributes for acceleration of RLS operation.
				FileObject.CurrentVersionSize = CurrentVersion.Size;
				FileObject.CurrentVersionCreationDate = CurrentVersion.CreationDate;
				FileObject.CurrentVersionAuthor = CurrentVersion.Author;
				FileObject.CurrentVersionExtension = CurrentVersion.Extension;
				FileObject.CurrentVersionVersionNumber = CurrentVersion.VersionNumber;
				FileObject.CurrentVersionVolume = CurrentVersion.Volume;
				FileObject.CurrentVersionPathToFile = CurrentVersion.PathToFile;
				FileObject.CurrentVersionCode = CurrentVersion.Code;
				FileObject.CurrentVersionFileModificationDate = CurrentVersion.FileModificationDate;
				
				If Source.AdditionalProperties.Property("DigitallySignedObjectRecord") Then
					FileObject.AdditionalProperties.Insert("DigitallySignedObjectRecord",
						Source.AdditionalProperties.DigitallySignedObjectRecord);
				EndIf;
				
				FileObject.Write();
			EndIf;
		
	EndIf;
		
	WhenUpdatingStatusQueueTextExtraction(
		Source.Ref, Source.TextExtractionStatus);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Conditional call handlers.

// Checks the
// right of current user when using a restriction for a folder or a file.
//
// Parameters:
//   Folder - CatalogRef.FileFolders, CatalogRef.Files - Files folder.
//       - CatalogRef - Files owner.
//
// Usage location:
//   ReportsMailing.FillInMailingParametersWithDefaultParameters().
//   Catalog.ReportMailings.Forms.ItemForm.FoldersAndFilesEditRight().
//
Function FilesToFolderAddingRight(Folder) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		AccessControlModule = CommonUse.CommonModule("AccessManagement");
		Return AccessControlModule.IsRight("FilesAdd", Folder);
	EndIf;
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Checks the
// right of current user when using a restriction for a folder or a file.
// 
// Parameters:
//  Right        - Right name.
//  RightsOwner - CatalogRef.FilesFolder,
//                 CatalogRef.Files, <reference to owner>.
//
Function IsRight(Right, RightsOwner) Export
	
	If TypeOf(RightsOwner) <> Type("CatalogRef.FileFolders") Then
		Return True;
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		AccessControlModule = CommonUse.CommonModule("AccessManagement");
		
		If Not AccessControlModule.IsRight(Right, RightsOwner) Then
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

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
// Scanning

Function ScannerParametersInEnumerations(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber) Export 
	
	If PermissionNumber = 200 Then
		Resolution = Enums.ScannedImageResolutions.dpi200;
	ElsIf PermissionNumber = 300 Then
		Resolution = Enums.ScannedImageResolutions.dpi300;
	ElsIf PermissionNumber = 600 Then
		Resolution = Enums.ScannedImageResolutions.dpi600;
	ElsIf PermissionNumber = 1200 Then
		Resolution = Enums.ScannedImageResolutions.dpi1200;
	EndIf;
	
	If ChromaticityNumber = 0 Then
		Chromaticity = Enums.ImageChromaticities.Monochrome;
	ElsIf ChromaticityNumber = 1 Then
		Chromaticity = Enums.ImageChromaticities.GrayGradations;
	ElsIf ChromaticityNumber = 2 Then
		Chromaticity = Enums.ImageChromaticities.Color;
	EndIf;
	
	If RotationNumber = 0 Then
		Rotation = Enums.ImageRotationMethods.NoRotation;
	ElsIf RotationNumber = 90 Then
		Rotation = Enums.ImageRotationMethods.ToTheRightAt90;
	ElsIf RotationNumber = 180 Then
		Rotation = Enums.ImageRotationMethods.ToTheRightAt180;
	ElsIf RotationNumber = 270 Then
		Rotation = Enums.ImageRotationMethods.ToTheLeftAt90;
	EndIf;
	
	If PaperSizeNumber = 0 Then
		PaperSize = Enums.PaperSizes.NotDefined;
	ElsIf PaperSizeNumber = 11 Then
		PaperSize = Enums.PaperSizes.A3;
	ElsIf PaperSizeNumber = 1 Then
		PaperSize = Enums.PaperSizes.A4;
	ElsIf PaperSizeNumber = 5 Then
		PaperSize = Enums.PaperSizes.A5;
	ElsIf PaperSizeNumber = 6 Then
		PaperSize = Enums.PaperSizes.B4;
	ElsIf PaperSizeNumber = 2 Then
		PaperSize = Enums.PaperSizes.B5;
	ElsIf PaperSizeNumber = 7 Then
		PaperSize = Enums.PaperSizes.B6;
	ElsIf PaperSizeNumber = 14 Then
		PaperSize = Enums.PaperSizes.C4;
	ElsIf PaperSizeNumber = 15 Then
		PaperSize = Enums.PaperSizes.C5;
	ElsIf PaperSizeNumber = 16 Then
		PaperSize = Enums.PaperSizes.C6;
	ElsIf PaperSizeNumber = 3 Then
		PaperSize = Enums.PaperSizes.USLetter;
	ElsIf PaperSizeNumber = 4 Then
		PaperSize = Enums.PaperSizes.USLegal;
	ElsIf PaperSizeNumber = 10 Then
		PaperSize = Enums.PaperSizes.USExecutive;
	EndIf;
	
	Result = New Structure;
	Result.Insert("Resolution", Resolution);
	Result.Insert("Chromaticity", Chromaticity);
	Result.Insert("Rotation", Rotation);
	Result.Insert("PaperSize", PaperSize);
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

Procedure WriteDataFileIntoTableWhenExchange(Source)
	
	Var FileBinaryData;
	
	If Source.AdditionalProperties.Property("FileBinaryData", FileBinaryData) Then
		RecordSet = InformationRegisters.VersionStoredFiles.CreateRecordSet();
		RecordSet.Filter.FileVersion.Set(Source.Ref);
		
		Record = RecordSet.Add();
		Record.FileVersion = Source.Ref;
		Record.StoredFile = New ValueStorage(FileBinaryData);
		
		RecordSet.DataExchange.Load = True;
		RecordSet.Write();
		
		Source.AdditionalProperties.Delete("FileBinaryData");
	EndIf;
	
EndProcedure

Function FileReceivingProhibited(DataItem)
	
	Return DataItem.IsNew()
	      AND Not FileFunctionsServiceClientServer.CheckFileExtensionForImporting(
	             DataItem.CurrentVersionExtension, False);
	
EndFunction

Function VersionFileReceivingProhibited(DataItem)
	
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
		WriteLogEvent(EventLogMonitorForExchange(), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		DataItem.FileStorage = New ValueStorage(Undefined);
	EndTry;
	
	DataItem.FileStorageType = Enums.FileStorageTypes.InInfobase;
	DataItem.PathToFile = "";
	DataItem.Volume = Catalogs.FileStorageVolumes.EmptyRef();
	
EndProcedure

Function GetParametersOnExit()
	
	ParametersOnComplete  = New Structure;
	ParametersOnComplete.Insert("CountEmployedFiles", 0);
	
	If CommonUseReUse.CanUseSeparatedData() Then
		
		User = UsersClientServer.AuthorizedUser();
		If TypeOf(User) = Type("CatalogRef.Users") Then
			
			ParametersOnComplete.Insert("CountEmployedFiles",
				FileOperationsServiceServerCall.GetLockedFilesCount(, User));
		EndIf;
	EndIf;
	
	Return ParametersOnComplete;
	
EndFunction

// Returns the number of locked files of passed user.
//
// Parameters:
//  IsEditing - CatalogRef.Users - ref. to the user working with the file.
//
// Returns:
//  Number  - number of locked files.
//
Function CountEmployedFiles(User)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Files.Ref AS Ref,
	|	Files.Presentation AS Presentation
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.IsEditing <> VALUE(Catalog.Users.EmptyRef)
	|	AND Files.IsEditing = &User";
	
	Query.SetParameter("User", User);
	
	Result = Query.Execute().Unload();
	
	Return Result.Count();
	
EndFunction

// Returns a string constant to form the events log messages.
//
// Returns:
//   String
//
Function EventLogMonitorForExchange() 
	
	Return NStr("en='Files. Failed to send the file when exchanging the data';ru='Файлы.Не удалось отправить файл при обмене данными'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

#EndRegion
