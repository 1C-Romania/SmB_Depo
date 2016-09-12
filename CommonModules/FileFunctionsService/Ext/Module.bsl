////////////////////////////////////////////////////////////////////////////////
// Subsystem "File functions".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Declares service events of subsystem FileFunctions:
//
// Server events:
//   WhenAddingFilesInVolumesOnAllocate,
//   WhenDeletingModificationsHistory,
//   WhenDeterminingQueryForTextExtractionText,
//   WhenDeterminingVersionsWithUnextractedTextNumber,
//   WhenRecordingExtractedText,
//   WhenDeterminingFilesNumberInVolumes,
//   WhenDeterminingStoredFilesExistence,
//   WhenReceivingStoredFiles,
//   WhenDeterminingFileNavigationReference,
//   WhenDeterminingFileNameWithPathToBinaryData,
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Adds file to volume when "Allocate the files of initial image".
	//
	// Syntax:
	// Procedure WhenAddingFilesToVolumesOnAllocate (FilesPathsMap, StoreFilesInVolumesOnDisk, AttachedFiles) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\WhenConfidentialityOfFilesInVolumeWhenPlacing");
	
	// Deletes the history of modifications after "Allocate the files of initial image".
	//
	// Syntax:
	// Procedure WhenDeletingModificationsHistory(ExchangePlanReference, AttachedFiles) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\RegistrationChangesOnDelete");
	
	// It fills the query text to receive files with the text not extracted.
	// You can receive another request as a parameter and you shall merge with it.
	//
	// Parameters:
	//  QueryText - String (return value), variants of passed values:
	//                   Blank string   - the required query text will be returned.
	//                   String is not empty - the required query text added
	//                                     to the passed text using COMBINE ALL will be returned.
	// 
	//  GetAllFiles - Boolean - Initial value is False. It allows
	//                     you to disable file filtering by parts if True is passed.
	//
	// Syntax:
	// Procedure WhenDeterminingQueryForTextExtractionText(QueryText, GetAllFiles = False) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\WhenDefiningTextQueryForTextRetrieval");
	
	// Returns the number of files with unextracted text.
	//
	// Syntax:
	// Procedure WhenDeterminingVersionsWithUnextractedTextNumber(VersionsNumber) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnDeterminingNumberOfVersionsWithNotImportedText");
	
	// It writes the extracted text.
	//
	// Syntax:
	// Procedure WhenRecordingExtractedText(FileObject) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnWriteExtractedText");
	
	// It returns the number of files in the volumes in CountFilesInVolumes parameter
	//
	// Syntax:
	// Procedure WhenDeterminingFilesNumberInVolumes(FilesNumberInVolumes) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnDeterminingNumberOfFilesInVolumes");
	
	// It returns True in ThereAreStoredFiles parameter if there are stored files to ExternalObject object.
	//
	// Syntax:
	// Procedure WhenDeterminingStoredFilesExistence(ExternalObject, ThereAreStoredFiles) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnDeterminingExistenceOfStoredFiles");
	
	// It returns the array of stored files to the ExternalObject object in the StoredFiles parameter.
	//
	// Syntax:
	// Procedure WhenReceivingStoredFiles(ExternalObject, StoredFiles) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnStoredFilesGetting");
	
	// Returns navigation reference to file (to attribute or temporary storage).
	//
	// Syntax:
	// Procedure WhenDeterminingFileNavigationReference (FileReference, UUID, NavigationReference) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\WhenDefiningNavigationLinksFile");
	
	// Receives full path to the file on the disk.
	//
	// Syntax:
	// Procedure WhenDeterminingFileNameWithPathToBinaryData(FileReference, PathToFile) Export
	//
	ServerEvents.Add("StandardSubsystems.FileFunctions\OnDeterminingFileWithNameByBinaryData");
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
			"FileFunctionsService");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.JobQueue\OnDefenitionOfUsageOfScheduledJobs"].Add(
				"FileFunctionsService");
	EndIf;
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems"].Add(
			"FileFunctionsService");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnGettingObjectExceptionsOfExchangePlan"].Add(
			"FileFunctionsService");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\WhenFillingOutPermitsForAccessToExternalResources"].Add(
			"FileFunctionsService");
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers[
			"ServiceTechnology.DataExportImport\WhenFillingCommonDataTypesDoNotRequireMatchingRefsOnImport"].Add(
				"FileFunctionsService");
	EndIf;
	
EndProcedure

// Define the list of catalogs available for import using the Import data from file subsystem.
//
// Parameters:
//  ImportedCatalogs - ValueTable - list of catalogs, to which the data can be imported.
//      * FullName          - String - full name of the catalog (as in the metadata).
//      * Presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	// Import to catalog FileStorageVolumes is prohibited.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.FileStorageVolumes.FullName(), "FullName");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;
	
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
	Objects.Insert(Metadata.Catalogs.FileStorageVolumes.FullName(), "EditedAttributesInGroupDataProcessing");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Standard applicationming interface.

// Fills the structure of the parameters required
// for the client configuration code. 
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure AddClientWorkParameters(Parameters) Export
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	FileOperationsSettings = FileFunctionsServiceReUse.FileOperationsSettings();
	
	Parameters.Insert("PersonalFileOperationsSettings", New FixedStructure(
		FileOperationsSettings.PersonalSettings));
	
	Parameters.Insert("FileOperationsCommonSettings", New FixedStructure(
		FileOperationsSettings.CommonSettings));
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Files exchange support

// Service functions. Used to delete the file on server.
// 
Procedure DeleteFilesAtServer(FormerPathOnVolume) Export
	
	// Delete file.
	FileTemporary = New File(FormerPathOnVolume);
	If FileTemporary.Exist() Then
		
		Try
			FileTemporary.SetReadOnly(False);
			DeleteFiles(FormerPathOnVolume);
		Except
			WriteLogEvent(
				NStr("en='Files.Files deletion in the volume at exchange';ru='Файлы.Удаление файлов в томе при обмене'",
				     CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				,
				,
				ErrorInfo());
		EndTry;
		
	EndIf;
	
	// Delete file directory if the directory is empty after deletion of the file.
	Try
		FileArrayInDirectory = FindFiles(FileTemporary.Path, "*.*");
		If FileArrayInDirectory.Count() = 0 Then
			DeleteFiles(FileTemporary.Path);
		EndIf;
	Except
		WriteLogEvent(
			NStr("en='Files.Files deletion in the volume at exchange';ru='Файлы.Удаление файлов в томе при обмене'",
			     CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,
			,
			,
			ErrorInfo() );
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Operations with file volumes

// Returns the type of file storage.
// 
// Returns:
//  Boolean. True if the files shall be stored in volumes on the disk.
//
Function StoringFilesInVolumesOnDrive() Export
	
	SetPrivilegedMode(True);
	
	StoreFilesInVolumesOnHardDisk = Constants.StoreFilesInVolumesOnHardDisk.Get();
	
	Return StoreFilesInVolumesOnHardDisk;
	
EndFunction

// Returns file storage type with account of existence of volumes.
// If there are no file storage volumes, then store in IB.
//
// Returns:
//  EnumsRef.FileStorageTypes.
//
Function TypeOfFileStorage() Export
	
	SetPrivilegedMode(True);
	
	StoreFilesInVolumesOnHardDisk = Constants.StoreFilesInVolumesOnHardDisk.Get();
	
	If StoreFilesInVolumesOnHardDisk Then
		
		If FileFunctions.AreFileStorageVolumes() Then
			Return Enums.FileStorageTypes.InVolumesOnDrive;
		Else
			Return Enums.FileStorageTypes.InInfobase;
		EndIf;
		
	Else
		Return Enums.FileStorageTypes.InInfobase;
	EndIf;

EndFunction

// Verifies that there is at least one file in at least one volume.
//
// Returns:
//  Boolean.
//
Function AreFilesInVolumes() Export
	
	If CountFilesInVolumes() <> 0 Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Returns full path of volume - depending on OS.
Function FullPathOfVolume(VolumeRef) Export
	
	ServerPlatformType = CommonUseReUse.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Windows_x86
	 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
		
		Return VolumeRef.FullPathWindows;
	Else
		Return VolumeRef.FullPathLinux;
	EndIf;
	
EndFunction

// Adds the file in one of the volumes (which has space).
//  
// Parameters:
//   BinaryDataOrPath  - BinaryData, Row - binary data of file or full path to file on disk.
//   ModificationTimeUniversal - Date - universal time which will be set for
//                                        the file as the time of last modification.
//   BaseName       - String - File name without extension. 
//   Extension             - String - file extension without period. 
//   VersionNumber            - String - number of file version. If specified, then attachment file name for storing on
//                                     disk is generated as:
//                                     BaseName + "." + VersionNumber + "." + Extension
//                                     in opposite case, BaseName + "." + Extension.
//   Encrypted             - Boolean - If True, then extension ".p7m" will be added to a full attachment file name.
//   DateForPostingVolume - Date   - Current time of session is used, unless stated otherwise.
//  
//  Returns:
//    Structure - with properties:
//      * Volume         - CatalogRef.FileStorageVolumes - volume in which the file was placed.
//      * PathToFile  - String - path on which the file was placed in the volume.
//
Function AddFileToVolume(BinaryDataOrPath, ModificationTimeUniversal, BaseName, Extension,
	VersionNumber = "", Encrypted = False, DateForPostingVolume = Undefined) Export
	
	ExpectedTypes = New Array;
	ExpectedTypes.Add(Type("BinaryData"));
	ExpectedTypes.Add(Type("String"));
	CommonUseClientServer.CheckParameter("FileFunctionsService.AddToDisk", "BinaryDataOrPath", BinaryDataOrPath,	
		New TypeDescription(ExpectedTypes));
		
	SetPrivilegedMode(True);
	
	VolumeRef = Catalogs.FileStorageVolumes.EmptyRef();
	
	AllErrorsShortDescription   = ""; // Errors from all volumes.
	AllErrorsDetailedDescription = ""; // For event log monitor.
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FileStorageVolumes.Ref
		|FROM
		|	Catalog.FileStorageVolumes AS FileStorageVolumes
		|WHERE
		|	FileStorageVolumes.DeletionMark = FALSE
		|
		|ORDER BY
		|	FileStorageVolumes.FillOrder";

	Selection = Query.Execute().Select();
	
	If Selection.Count() = 0 Then
		Raise NStr("en='No volumes to place the files';ru='Нет ни одного тома для размещения файлов'");
	EndIf;
	
	While Selection.Next() Do
		
		VolumeRef = Selection.Ref;
		
		PathToVolume = FullPathOfVolume(VolumeRef);
		// Add a slash at the end in case it is absent.
		PathToVolume = CommonUseClientServer.AddFinalPathSeparator(PathToVolume);
		
		// Name of file for storing on disk shall be generated as follows
		// - attachment file name.version number.file extension.
		If IsBlankString(VersionNumber) Then
			FileName = BaseName + "." + Extension;
		Else
			FileName = BaseName + "." + VersionNumber + "." + Extension;
		EndIf;
		
		If Encrypted Then
			FileName = FileName + "." + "p7m";
		EndIf;
		
		Try
			
			If TypeOf(BinaryDataOrPath) = Type("BinaryData") Then
				FileSize = BinaryDataOrPath.Size();
			Else // Alternatively stated, this is a path to file on disk.
				FileSource = New File(BinaryDataOrPath);
				FileSize = FileSource.Size();
			EndIf;
			
			// If MaximumSize = 0 - no restriction on the size of files in the volume.
			If VolumeRef.MaximumSize <> 0 Then
				
				CurrentSizeInBytes = 0;
				
				OnDefenitionSizeOfFilesOnVolume(VolumeRef.Ref, CurrentSizeInBytes);
				
				NewSizeInBytes = CurrentSizeInBytes + FileSize;
				NewSize = NewSizeInBytes / (1024 * 1024);
				
				If NewSize > VolumeRef.MaximumSize Then
					
					Raise StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='Maximal volume size (%1 Mb) is exceeded.';ru='Превышен максимальный размер тома (%1 Мб).'"),
						VolumeRef.MaximumSize);
				EndIf;
			EndIf;
			
			Date = CurrentSessionDate();
			If DateForPostingVolume <> Undefined Then
				Date = DateForPostingVolume;
			EndIf;
			
			// Use of absolute date format "FS"
			// in the following line is correct as the date is used not for user view.
			DayPath = Format(Date, "DF=YYYYMMDD") + CommonUseClientServer.PathSeparator();
			
			PathToVolume = PathToVolume + DayPath;
			
			FileNameWithPath = FileFunctionsServiceClientServer.GetUniqueNameWithPath(PathToVolume, FileName);
			FileFullNameWithPath = PathToVolume + FileNameWithPath;
			
			If TypeOf(BinaryDataOrPath) = Type("BinaryData") Then
				BinaryDataOrPath.Write(FileFullNameWithPath);
			Else // Alternatively stated, this is a path to file on disk.
				FileCopy(BinaryDataOrPath, FileFullNameWithPath);
			EndIf;
			
			// Setting file modification time as it is set in current version.
			FileOnDrive = New File(FileFullNameWithPath);
			FileOnDrive.SetModificationUniversalTime(ModificationTimeUniversal);
			FileOnDrive.SetReadOnly(True);
			
			Return New Structure("Volume,PathToFile", VolumeRef, DayPath + FileNameWithPath); 
			
		Except
			ErrorInfo = ErrorInfo();
			
			If AllErrorsDetailedDescription <> "" Then
				AllErrorsDetailedDescription = AllErrorsDetailedDescription + Chars.LF + Chars.LF;
				AllErrorsShortDescription   = AllErrorsShortDescription   + Chars.LF + Chars.LF;
			EndIf;
			
			ErrorDescriptionTemplate =
				NStr("en='Failed to add"
"file ""%1"" to volume"
"""%2"" (%3): ""%4"".';ru='Ошибка"
"при добавлении файла"
"""%1"" в том ""%2"" (%3): ""%4"".'");
			
			AllErrorsDetailedDescription = AllErrorsDetailedDescription
				+ StringFunctionsClientServer.PlaceParametersIntoString(
					ErrorDescriptionTemplate,
					FileName,
					String(VolumeRef),
					PathToVolume,
					DetailErrorDescription(ErrorInfo));
			
			AllErrorsShortDescription = AllErrorsShortDescription
				+ StringFunctionsClientServer.PlaceParametersIntoString(
					ErrorDescriptionTemplate,
					FileName,
					String(VolumeRef),
					PathToVolume,
					BriefErrorDescription(ErrorInfo));
			
			// Move on to next volume.
			Continue;
		EndTry;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	// Record in the event
	// log monitor for the administrator - display errors from all volumes.
	MessageAboutErrorTemplate = NStr("en='Failed to add the file to the volumes."
"List"
""
"of errors: %1';ru='Не удалось добавить файл ни в один из томов."
"Список"
""
"ошибок: %1'");
	
	WriteLogEvent(
		NStr("en='Files. File adding';ru='Файлы.Добавление файла'", CommonUseClientServer.MainLanguageCode()),
		EventLogLevel.Error,,,
		StringFunctionsClientServer.PlaceParametersIntoString(MessageAboutErrorTemplate, AllErrorsDetailedDescription));
	
	If Users.InfobaseUserWithFullAccess() Then
		ExceptionString = StringFunctionsClientServer.PlaceParametersIntoString(MessageAboutErrorTemplate,	AllErrorsShortDescription);
	Else
		// Message to ordinary user.
		ExceptionString = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Failed to add"
"the file: ""%1.%2""."
""
"Contact your administrator.';ru='Не удалось"
"добавить файл: ""%1.%2""."
""
"Обратитесь к администратору.'"),
			BaseName, Extension);
	EndIf;
	
	Raise ExceptionString;

EndFunction

// Returns the number of files stored in volumes.
Function CountFilesInVolumes() Export
	
	CountFilesInVolumes = 0;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.FileFunctions\OnDeterminingNumberOfFilesInVolumes");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnDeterminingNumberOfFilesInVolumes(CountFilesInVolumes);
	EndDo;
	
	Return CountFilesInVolumes;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Digital signature and encryption for files.

// Controls the visible of items and commands depending
// on existence and use of digital signature and encryption.
//
Procedure CryptographyOnCreateFormAtServer(Form, ThisIsListForm = True, RowsPictureOnly = False) Export
	
	Items = Form.Items;
	
	ESigning = False;
	Encryption = False;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DigitalSignature")
	   AND Users.RolesAvailable("DSUsage")
	   AND Not CommonUseClientServer.ThisIsMacOSWebClient() Then
		
		ModuleDigitalSignature = CommonUse.CommonModule("DigitalSignature");
		
		ESigning = ModuleDigitalSignature.UseDigitalSignatures();
		Encryption            = ModuleDigitalSignature.UseEncryption();
	EndIf;
	
	Used = ESigning Or Encryption;
	
	If ThisIsListForm Then
		Items.ListPictureNumberDigitallySignedEncrypted.Visible = Used;
	EndIf;
	
	If Not RowsPictureOnly Then
		Items.FormCommandGroupDigitalSignatureAndEncryption.Visible = Used;
		
		If ThisIsListForm Then
			Items.ListContextMenuCommandGroupDigitalSignatureAndEncryption.Visible = Used;
		Else
			Items.DigitalSignaturesGroup.Visible = ESigning;
			Items.GroupEncryptionCertificates.Visible = Encryption;
			Items.GroupAdditionalInformationPage.PagesRepresentation =
				?(Used, FormPagesRepresentation.TabsOnTop, FormPagesRepresentation.None);
		EndIf;
	EndIf;
	
	If Not Used Then
		Return;
	EndIf;
	
	If Not RowsPictureOnly Then
		Items.FormCommandGroupDigitalSignature.Visible = ESigning;
		Items.FormCommandGroupEncryption.Visible = Encryption;
		
		If ThisIsListForm Then
			Items.ListContextMenuCommandGroupDigitalSignature.Visible = ESigning;
			Items.ListContextMenuCommandGroupEncryption.Visible = Encryption;
		EndIf;
	EndIf;
	
	If ESigning AND Encryption Then
		Title = NStr("en='Digital signature and encryption';ru='ЭЦП и шифрование'");
		ToolTip = NStr("en='Existence of electronic signature or encryption';ru='Наличие электронной подписи или шифрования'");
		Picture  = PictureLib["DigitallySignedEncryptedTitle"];
	ElsIf ESigning Then
		Title = NStr("en='Digital signature';ru='Электронная подпись'");
		ToolTip = NStr("en='Existence of digital signature';ru='Наличие электронной подписи'");
		Picture  = PictureLib["DigitallySigned"];
	Else // Encryption
		Title = NStr("en='Encryption';ru='Шифрование'");
		ToolTip = NStr("en='Existence of encryption';ru='Наличие шифрования'");
		Picture  = PictureLib["Encrypted"];
	EndIf;
	
	If ThisIsListForm Then
		Items.ListPictureNumberDigitallySignedEncrypted.HeaderPicture = Picture;
		Items.ListPictureNumberDigitallySignedEncrypted.ToolTip = ToolTip;
	EndIf;
	
	If Not RowsPictureOnly Then
		Items.FormCommandGroupDigitalSignatureAndEncryption.Title = Title;
		Items.FormCommandGroupDigitalSignatureAndEncryption.ToolTip = Title;
		Items.FormCommandGroupDigitalSignatureAndEncryption.Picture  = Picture;
		
		If ThisIsListForm Then
			Items.ListContextMenuCommandGroupDigitalSignatureAndEncryption.Title = Title;
			Items.ListContextMenuCommandGroupDigitalSignatureAndEncryption.ToolTip = Title;
			Items.ListContextMenuCommandGroupDigitalSignatureAndEncryption.Picture  = Picture;
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other functions

// Returns True if text is retrieved from files on the server, not on client.
//
// Returns:
//  Boolean. False - if a text is not
//                 retrieved on the server, i.e. it can and must be retrieved on the client.
//
Function ExtractFileTextsAtServer() Export
	
	SetPrivilegedMode(True);
	
	Return Constants.ExtractFileTextsAtServer.Get();
	
EndFunction

// Returns True if the server works under Windows.
Function ThisIsWindowsPlatform() Export
	
	ServerPlatformType = CommonUseReUse.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Windows_x86
	 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Receives a string from temporary storage (transfer from
// client to server is done through temporary storage).
//
Function GetStringFromTemporaryStorage(TextTemporaryStorageAddress) Export
	
	If IsBlankString(TextTemporaryStorageAddress) Then
		Return "";
	EndIf;
	
	TempFileName = GetTempFileName();
	GetFromTempStorage(TextTemporaryStorageAddress).Write(TempFileName);
	
	TextFile = New TextReader(TempFileName, TextEncoding.UTF8);
	Text = TextFile.Read();
	TextFile.Close();
	DeleteFiles(TempFileName);
	
	Return Text;
	
EndFunction

// Service function is used for allocation of binary data
// of the file in the volume to value storage.
//
Function PutBinaryDataIntoStorage(Volume, PathToFile, UUID) Export
	
	FullPath = FullPathOfVolume(Volume) + PathToFile;
	UUID = UUID;
	
	BinaryData = New BinaryData(FullPath);
	Return New ValueStorage(BinaryData);
	
EndFunction

// Service function is used when creating the initial image.
// Always executed on server.
//
Procedure CopyFileOnInitialImageCreation(FullPath, NewPathFile) Export
	
	Try
		// If the file is in volume - copy it to temporary directory (when you create initial image).
		FileCopy(FullPath, NewPathFile);
		FileTemporary = New File(NewPathFile);
		FileTemporary.SetReadOnly(False);
	Except
		// Cannot be registered, maybe the file is not found.
	EndTry;
	
EndProcedure

// It writes the text extraction result to the server - extracted text and TextExtractionStatus.
Procedure WriteTextExtractionResult(FileOrVersionRef,
                                            ExtractionResult,
                                            TextTemporaryStorageAddress) Export
	
	FileOrVersionObject = FileOrVersionRef.GetObject();
	FileOrVersionObject.Lock();
	
	If IsBlankString(TextTemporaryStorageAddress) Then
		Text = "";
	Else
		Text = GetStringFromTemporaryStorage(TextTemporaryStorageAddress);
		FileOrVersionObject.TextStorage = New ValueStorage(Text);
		DeleteFromTempStorage(TextTemporaryStorageAddress);
	EndIf;
	
	If ExtractionResult = "NotExtracted" Then
		FileOrVersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	ElsIf ExtractionResult = "Extracted" Then
		FileOrVersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
	ElsIf ExtractionResult = "ExtractFailed" Then
		FileOrVersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.ExtractFailed;
	EndIf;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.FileFunctions\OnWriteExtractedText");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnWriteExtractedText(FileOrVersionObject);
	EndDo;
	
EndProcedure

// Returns True if there are stored files to object ExternalObject.
Function AreStoredFiles(ExternalObject) Export
	
	Result = False;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.FileFunctions\OnDeterminingExistenceOfStoredFiles");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnDeterminingExistenceOfStoredFiles(ExternalObject, Result);
	EndDo;
	
	Return Result;
	
EndFunction

// Returns stored files to object ExternalObject.
//
Function GetStoredFiles(ExternalObject) Export
	
	ArrayOfData = New Array;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.FileFunctions\OnStoredFilesGetting");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.OnStoredFilesGetting(ExternalObject, ArrayOfData);
	EndDo;
	
	Return ArrayOfData;
	
EndFunction

// Receives the encoding of text file specified by user (if any).
//
// Parameters:
//  FileVersion - file version reference.
//
// Returns:
//  String - identifier of text encoding or empty row.
//
Function GetFileVersionEncoding(FileVersion) Export
	
	Encoding = "";
	OnDeterminingEncodingOfFileVersions(FileVersion, Encoding);
	
	Return Encoding;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Handlers of SSL subsystems internal events.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable
//                                  function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.1.6";
	Handler.Procedure = "FileFunctionsService.TransferExtensionsConstants";
	
EndProcedure	

// Generates scheduled
// jobs table with the flag of usage in the service model.
//
// Parameters:
// UsageTable - ValueTable - table that should be filled in with the scheduled jobs a flag of usage, columns:
//  ScheduledJob - String - name of the predefined scheduled job.
//  Use - Boolean - True if scheduled job
//   should be executed in the service model. False - if it should not.
//
Procedure OnDefenitionOfUsageOfScheduledJobs(UsageTable) Export
	
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "TextExtraction";
	NewRow.Use       = False;
	
EndProcedure

// Fills the structure of the parameters required
// for the client configuration code.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystems(Parameters) Export
	
	AddClientWorkParameters(Parameters);
	
EndProcedure

// Used to receive metadata objects that should not be included into the exchange plan content.
// If the subsystem has metadata objects that should not be included in
// the exchange plan, then these metadata objects should be added to the <Object> parameter.
//
// Parameters:
// Objects - Array. Array of the configuration metadata objects that should not be included into the exchange plan.
// DistributedInfobase (read only) - Boolean. Flag showing that objects for DIB exchange plan were received.
// True - required to get the list of the exception objects of the DIB exchange plan;
// False - it is required to receive a list for an exchange plan NOT RIB.
//
Procedure OnGettingObjectExceptionsOfExchangePlan(Objects, Val DistributedInfobase) Export
	
	Objects.Add(Metadata.Constants.ExtractFileTextsAtServer);
	Objects.Add(Metadata.Constants.StoreFilesInVolumesOnHardDisk);
	
	Objects.Add(Metadata.Catalogs.FileStorageVolumes);
	
EndProcedure

// Fills out a list of queries for external permissions
// that must be provided when creating an infobase or updating a application.
//
// Parameters:
//  PermissionsQueries - Array - list of values returned by the function.
//                      WorkInSafeMode.QueryOnExternalResourcesUse().
//
Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	If GetFunctionalOption("StoreFilesInVolumesOnHardDisk") Then
		Catalogs.FileStorageVolumes.AddQueriesToUseExternalResourcesAllVolumes(PermissionsQueries);
	EndIf;
	
EndProcedure

// Fills the array of types of undivided data for which
// the refs mapping during data import to another infobase is not necessary as correct refs
// mapping is guaranteed by using other mechanisms.
//
// Parameters:
//  Types - Array(MetadataObject)
//
Procedure WhenFillingCommonDataTypesDoNotRequireMatchingRefsOnImport(Types) Export
	
	// When exporting data, the references to catalog
	// FilesStorageVolumes are cleared; when importing, import is performed according to the settings
	// of volumes in IB to which the data is imported, rather than
	// the settings of volumes in IB from which the data was exported.
	Types.Add(Metadata.Catalogs.FileStorageVolumes);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Files exchange

// Create initial image of the file on server.
//
Function CreateFileInitialImageAtServer(Node, FormUUID, Language, WindowsFileBaseFullName, LinuxFileBaseFullName, PathToArchiveWithWindowsVolumesFiles, PathToArchiveWithLinuxVolumeFiles) Export
	
	// Check the content of exchange plan.
	StandardSubsystemsServer.ValidateExchangePlanContent(Node);
	
	PathToArchiveWithVolumeFiles = "";
	FileBaseFullName = "";
	
	AreFilesInVolumes = False;
	
	If FileFunctions.AreFileStorageVolumes() Then
		AreFilesInVolumes = AreFilesInVolumes();
	EndIf;
	
	ServerPlatformType = CommonUseReUse.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Windows_x86 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
		
		PathToArchiveWithVolumeFiles = PathToArchiveWithWindowsVolumesFiles;
		FileBaseFullName = WindowsFileBaseFullName;
		
		ClientWorkParameters = StandardSubsystemsServerCall.ClientWorkParameters();
		If Not ClientWorkParameters.FileInfobase Then
			If AreFilesInVolumes Then
				
				If Not IsBlankString(PathToArchiveWithVolumeFiles)
				   AND (Left(PathToArchiveWithVolumeFiles, 2) <> "\\"
				 OR Find(PathToArchiveWithVolumeFiles, ":") <> 0) Then
					
					CommonUseClientServer.MessageToUser(
						NStr("en='Path to archive volume files must"
"be in the UNC format (\\servername\resource)';ru='Путь к файловой базе"
"должен быть в формате UNC (\\servername\resource)'"),
						,
						"PathToArchiveWithWindowsVolumesFiles");
					Return False;
				EndIf;
			EndIf;
		EndIf;
		
		If Not ClientWorkParameters.FileInfobase Then
			If Not IsBlankString(FileBaseFullName) AND (Left(FileBaseFullName, 2) <> "\\" OR Find(FileBaseFullName, ":") <> 0) Then
				
				CommonUseClientServer.MessageToUser(
					NStr("en='Path to archive volume"
"files must be in the UNC format (\\servername\resource)';ru='Путь к"
"файловой базе должен быть в формате UNC (\\servername\resource)'"),
					,
					"WindowsFileBaseFullName");
				Return False;
			EndIf;
		EndIf;
		
	Else
		PathToArchiveWithVolumeFiles = PathToArchiveWithLinuxVolumeFiles;
		FileBaseFullName = LinuxFileBaseFullName;
	EndIf;
	
	If IsBlankString(FileBaseFullName) Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en='Specify full name of the file base (1cv8.1cd)';ru='Укажите полное имя файловой базы (файл 1cv8.1cd)'"),,
			"WindowsFileBaseFullName");
		Return False;
		
	EndIf;
	
	BaseFile = New File(FileBaseFullName);
	
	If BaseFile.Exist() Then
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='File ""%1"" already exists."
"Enter another attachment file name.';ru='Файл ""%1"" уже существует."
"Введите другое имя файла.'"),
				FileBaseFullName),, "WindowsFileBaseFullName");
		Return False;
	EndIf;
	
	If AreFilesInVolumes Then
		
		If IsBlankString(PathToArchiveWithVolumeFiles) Then
			CommonUseClientServer.MessageToUser(
				NStr("en='Specify the full name of the archive with files of volumes (file *.zip)';ru='Укажите полное имя архива с файлами томов (файл *.zip)'"),, 
				"PathToArchiveWithWindowsVolumesFiles");
			Return False;
		EndIf;
		
		File = New File(PathToArchiveWithVolumeFiles);
		
		If File.Exist() Then
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='File ""%1"" already exists."
"Enter another attachment file name.';ru='Файл ""%1"" уже существует."
"Введите другое имя файла.'"),
					PathToArchiveWithVolumeFiles),, "PathToArchiveWithWindowsVolumesFiles");
			Return False;
		EndIf;
		
	EndIf;
	
	// create a temporary directory
	DirectoryName = GetTempFileName();
	CreateDirectory(DirectoryName);
	
	// Create temporary directory for files.
	FilesDirectoryName = GetTempFileName();
	CreateDirectory(FilesDirectoryName);
	
	// To transfer the path of files directory to handler OnFileDataSending.
	SaveSetting("FilesExchange", "TemporaryDirectory", FilesDirectoryName);
	
	ZIP = Undefined;
	Record = Undefined;
	
	Try
		
		ConnectionString = "File=""" + DirectoryName + """;"
						 + "Locale=""" + Language + """;";
		ExchangePlans.CreateInitialImage(Node, ConnectionString);  // Creation of initial image.
		
		If AreFilesInVolumes Then
			ZIP = New ZipFileWriter;
			ZIP.Open(PathToArchiveWithVolumeFiles);
			
			TemporaryFiles = New Array;
			TemporaryFiles = FindFiles(FilesDirectoryName, "*.*");
			
			For Each TempFile IN TemporaryFiles Do
				If TempFile.IsFile() Then
					TemporaryFilePath = TempFile.FullName;
					ZIP.Add(TemporaryFilePath);
				EndIf;
			EndDo;
			
			ZIP.Write();
			
			DeleteFiles(FilesDirectoryName); // Delete with the files inside.
		EndIf;
		
	Except
		
		DeleteFiles(DirectoryName);
		Raise;
		
	EndTry;
	
	TemporaryBaseFilePath = DirectoryName + "\1Cv8.1CD";
	MoveFile(TemporaryBaseFilePath, FileBaseFullName);
	
	// clearing
	DeleteFiles(DirectoryName);
	
	Return True;
	
EndFunction

// Create initial server image on server.
//
Function CreateServerInitialImageAtServer(Node, ConnectionString, PathToArchiveWithWindowsVolumesFiles, PathToArchiveWithLinuxVolumeFiles) Export
	
	// Check the content of exchange plan.
	StandardSubsystemsServer.ValidateExchangePlanContent(Node);
	
	PathToArchiveWithVolumeFiles = "";
	FileBaseFullName = "";
	
	AreFilesInVolumes = False;
	
	If FileFunctions.AreFileStorageVolumes() Then
		AreFilesInVolumes = AreFilesInVolumes();
	EndIf;
	
	ServerPlatformType = CommonUseReUse.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Windows_x86 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
		
		PathToArchiveWithVolumeFiles = PathToArchiveWithWindowsVolumesFiles;
		
		If AreFilesInVolumes Then
			If Not IsBlankString(PathToArchiveWithVolumeFiles)
			   AND (Left(PathToArchiveWithVolumeFiles, 2) <> "\\"
			 OR Find(PathToArchiveWithVolumeFiles, ":") <> 0) Then
				
				CommonUseClientServer.MessageToUser(
					NStr("en='Path to the archive with files"
"of the volumes must be in UNC format (\\servername\resource).';ru='Путь к архиву с"
"файлами томов должен быть в формате UNC (\\servername\resource).'"),
					,
					"PathToArchiveWithWindowsVolumesFiles");
				Return False;
			EndIf;
		EndIf;
		
	Else
		PathToArchiveWithVolumeFiles = PathToArchiveWithLinuxVolumeFiles;
	EndIf;
	
	If AreFilesInVolumes Then
		If IsBlankString(PathToArchiveWithVolumeFiles) Then
			CommonUseClientServer.MessageToUser(
				NStr("en='Specify the full name of the archive with files of volumes (file *.zip)';ru='Укажите полное имя архива с файлами томов (файл *.zip)'"),
				,
				"PathToArchiveWithWindowsVolumesFiles");
			Return False;
		EndIf;
		
		FilePath = PathToArchiveWithVolumeFiles;
		File = New File(FilePath);
		If File.Exist() Then
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='File ""%1"" already exists."
"Enter another attachment file name.';ru='Файл ""%1"" уже существует."
"Введите другое имя файла.'"),
					FilePath));
			Return False;
		EndIf;
	EndIf;
	
	// create a temporary directory
	DirectoryName = GetTempFileName();
	CreateDirectory(DirectoryName);
	
	// Create temporary directory for files.
	FilesDirectoryName = GetTempFileName();
	CreateDirectory(FilesDirectoryName);
	
	// To transfer the path of files directory to handler OnFileDataSending.
	SaveSetting("FilesExchange", "TemporaryDirectory", FilesDirectoryName);
	
	ZIP = Undefined;
	Record = Undefined;
	
	Try
		
		ExchangePlans.CreateInitialImage(Node, ConnectionString);
		
		If AreFilesInVolumes Then
			ZIP = New ZipFileWriter;
			ZIPPath = FilePath;
			ZIP.Open(ZIPPath);
			
			TemporaryFiles = New Array;
			TemporaryFiles = FindFiles(FilesDirectoryName, "*.*");
			
			For Each TempFile IN TemporaryFiles Do
				If TempFile.IsFile() Then
					TemporaryFilePath = TempFile.FullName;
					ZIP.Add(TemporaryFilePath);
				EndIf;
			EndDo;
			
			ZIP.Write();
			DeleteFiles(FilesDirectoryName); // Delete with the files inside.
		EndIf;
		
	Except
		
		DeleteFiles(DirectoryName);
		Raise;
		
	EndTry;
	
	// clearing
	DeleteFiles(DirectoryName);
	
	Return True;
	
EndFunction

// Places files to volumes by setting references in FileVersions.
//
Function AddFilesToVolumes(PathToWindowsArchive, PathToLinuxArchive) Export
	
	ZipFileFullName = "";
	ServerPlatformType = CommonUseReUse.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Windows_x86 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
		ZipFileFullName = PathToWindowsArchive;
	Else
		ZipFileFullName = PathToLinuxArchive;
	EndIf;
	
	DirectoryName = GetTempFileName();
	CreateDirectory(DirectoryName);
	
	ZIP = New ZipFileReader(ZipFileFullName);
	ZIP.ExtractAll(DirectoryName, ZIPRestoreFilePathsMode.DontRestore);
	
	FilesPathCompliance = New Map;
	
	For Each ZIPItem IN ZIP.Items Do
		FileFullPath = DirectoryName + "\" + ZIPItem.Name;
		UUID = ZIPItem.BaseName;
		
		FilesPathCompliance.Insert(UUID, FileFullPath);
	EndDo;
	
	TypeOfFileStorage = TypeOfFileStorage();
	AttachedFiles = New Array;
	BeginTransaction();
	Try
		
		EventHandlers = CommonUse.ServiceEventProcessor(
			"StandardSubsystems.FileFunctions\WhenConfidentialityOfFilesInVolumeWhenPlacing");
		
		For Each Handler IN EventHandlers Do
			Handler.Module.WhenConfidentialityOfFilesInVolumeWhenPlacing(
				FilesPathCompliance, TypeOfFileStorage, AttachedFiles);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
		
	// Clear the history of modifications that we have just applied.
	For Each ExchangePlan IN Metadata.ExchangePlans Do
		ExchangePlanName      = ExchangePlan.Name;
		ExchangePlanManager = ExchangePlans[ExchangePlanName];
		
		ThisNode = ExchangePlanManager.ThisNode();
		Selection = ExchangePlanManager.Select();
		
		While Selection.Next() Do
			
			ExchangePlanObject = Selection.GetObject();
			If ExchangePlanObject.Ref <> ThisNode Then
				
				EventHandlers = CommonUse.ServiceEventProcessor(
					"StandardSubsystems.FileFunctions\RegistrationChangesOnDelete");
				
				For Each Handler IN EventHandlers Do
					Handler.Module.RegistrationChangesOnDelete(
						ExchangePlanObject.Ref, AttachedFiles);
				EndDo;
				
			EndIf;
		EndDo;
		
	EndDo;
	
EndFunction

// To transfer the path of files directory to handler OnFileDataSending.
//
Procedure SaveSetting(ObjectKey, SettingsKey, Settings) 
		
	SetPrivilegedMode(True);
	CommonSettingsStorage.Save(ObjectKey, SettingsKey, Settings);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of scheduled jobs.

// Handler of scheduled job TextExtraction.
// Retrieves text from files on disk.
//
Procedure ExtractTextFromFilesOnServer() Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	SetPrivilegedMode(True);
	
	ServerPlatformType = CommonUseReUse.ServerPlatformType();
	
	If Not ThisIsWindowsPlatform() Then
		Return; // Text extraction works only under Windows.
	EndIf;
	
	NameWithExtensionFile = "";
	
	WriteLogEvent(
		NStr("en='Files. Text extraction';ru='Файлы.Извлечение текста'",
		     CommonUseClientServer.MainLanguageCode()),
		EventLogLevel.Information,
		,
		,
		NStr("en='Scheduled text extraction has been started';ru='Начато регламентное извлечения текста'"));
		
	FinalQueryText = "";
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.FileFunctions\WhenDefiningTextQueryForTextRetrieval");
	
	For Each Handler IN EventHandlers Do
		CurrentQueryText = "";
		Handler.Module.WhenDefiningTextQueryForTextRetrieval(CurrentQueryText);
		If Not IsBlankString(CurrentQueryText) Then
			If IsBlankString(FinalQueryText) Then
				FinalQueryText = CurrentQueryText;
			Else
				FinalQueryText = FinalQueryText +
				"
				|
				|UNION ALL
				|
				|" + CurrentQueryText;
			EndIf;
		EndIf;
	EndDo;
	
	If IsBlankString(FinalQueryText) Then
		Return;
	EndIf;
	
	Query = New Query(FinalQueryText);
	Result = Query.Execute();
	
	ExportingTable = Result.Unload();
	
	For Each String IN ExportingTable Do
		
		FileObject = String.Ref.GetObject();
		Try
			FileObject.Lock();
		Except
			// Blocked files will be processed next time.
			Continue;
		EndTry;
		
		NameWithExtensionFile = FileObject.Description + "." + FileObject.Extension;
		FileNameWithPath = "";
		
		EventHandlers = CommonUse.ServiceEventProcessor(
			"StandardSubsystems.FileFunctions\OnDeterminingFileWithNameByBinaryData");
		
		For Each Handler IN EventHandlers Do
			Handler.Module.OnDeterminingFileWithNameByBinaryData(
				FileObject.Ref, FileNameWithPath, True);
		EndDo;
		
		Encoding = GetFileVersionEncoding(String.Ref);
		
		Cancel = False;
		If IsBlankString(FileNameWithPath) Then
			Cancel = True;
			Text = "";
		Else
			Text = FileFunctionsServiceClientServer.ExtractText(FileNameWithPath, Cancel, Encoding);
		EndIf;
		
		If Cancel = False Then
			FileObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		Else
			// If there is no one to retrieve the text, it is not a bug but a normal case.
			FileObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.ExtractFailed;
		EndIf;
			
		If String.FileStorageType = Enums.FileStorageTypes.InInfobase
		   AND Not IsBlankString(FileNameWithPath) Then
			
			DeleteFiles(FileNameWithPath);
		EndIf;
		
		FileObject.TextStorage = New ValueStorage(Text, New Deflation);
		
		Try
			EventHandlers = CommonUse.ServiceEventProcessor(
				"StandardSubsystems.FileFunctions\OnWriteExtractedText");
			
			For Each Handler IN EventHandlers Do
				Handler.Module.OnWriteExtractedText(FileObject);
			EndDo;
		Except
			WriteLogEvent(
				NStr("en='Files. Text extraction';ru='Файлы.Извлечение текста'",
				     CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				,
				,
				StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='During scheduled text extraction from"
"file"
"""%1"" an"
"error occurred: ""%2"".';ru='Во время регламентного извлечения"
"текста"
"из файла"
"""%1"" произошла ошибка: ""%2"".'"),
					NameWithExtensionFile,
					DetailErrorDescription(ErrorInfo()) ));
		EndTry;
		
	EndDo;
	
	WriteLogEvent(
		NStr("en='Files. Text extraction';ru='Файлы.Извлечение текста'",
		     CommonUseClientServer.MainLanguageCode()),
		EventLogLevel.Information,
		,
		,
		NStr("en='Scheduled extraction of the text has been completed';ru='Закончено регламентное извлечение текста'"));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// Tranfer constants ProhibitedExtensionsList and OpenDocumentFilesExtensionsList.
Procedure TransferExtensionsConstants() Export
	
	SetPrivilegedMode(True);
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		
		ProhibitedExtensionsList = Constants.ProhibitedExtensionsList.Get();
		Constants.ProhibitedDataAreaFileExtensionList.Set(ProhibitedExtensionsList);
		
		FileExtensionListOpenDocument = Constants.FileExtensionListOpenDocument.Get();
		Constants.DataAreasOpenDocumentFileExtensionList.Set(FileExtensionListOpenDocument);
		
	EndIf;	
	
EndProcedure	

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Complements the structure that contains general and personal settings for work with files.
Procedure WhenAddSettingsFileOperations(CommonSettings, PersonalSettings) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileOperations") Then
		ModuleFileOperationsServiceServerCall = CommonUse.CommonModule("FileOperationsServiceServerCall");
		ModuleFileOperationsServiceServerCall.AddFileOperationsSettings(CommonSettings, PersonalSettings);
	EndIf;
	
EndProcedure

// Calculates the size of volume files in bytes, the result is returned to parameter FilesSize.
Procedure OnDefenitionSizeOfFilesOnVolume(RefOfVolume, FilesSize) Export
	
	FilesSize = 0;
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileOperations") Then
		ModuleFileOperationsServiceServerCall = CommonUse.CommonModule("FileOperationsServiceServerCall");
		FilesSize = FilesSize + ModuleFileOperationsServiceServerCall.CountSizeOfFilesOnVolume(RefOfVolume);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AttachedFiles") Then
		ModuleAttachedFilesService = CommonUse.CommonModule("AttachedFilesService");
		FilesSize = FilesSize + ModuleAttachedFilesService.CountSizeOfFilesOnVolume(RefOfVolume);
	EndIf;
	
EndProcedure

// It reads the file version encoding.
//
// Parameters:
// VersionRef - file version reference.
//
// Returns:
//   Encoding string
Procedure OnDeterminingEncodingOfFileVersions(VersionRef, Encoding) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileOperations") Then
		ModuleFileOperationsServiceServerCall = CommonUse.CommonModule("FileOperationsServiceServerCall");
		Encoding = ModuleFileOperationsServiceServerCall.GetFileVersionEncoding(VersionRef);
	EndIf;
	
EndProcedure

#EndRegion
