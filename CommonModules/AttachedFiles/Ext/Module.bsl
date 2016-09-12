////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns binary data of the attached file.
//
// Parameters:
//  AttachedFile - CatalogRef - ref to catalog with the "AttachedFiles" name.
//
// Returns:
//  BinaryData - attached attachment binary data.
//
Function GetFileBinaryData(Val AttachedFile) Export
	
	CommonUseClientServer.CheckParameter("AttachedFiles.ReceiveFileBinaryData", "AttachedFile", 
		AttachedFile, Metadata.InformationRegisters.AttachedFiles.Dimensions.AttachedFile.Type);
		
	FileObject = AttachedFile.GetObject();
	CommonUseClientServer.Validate(FileObject <> Undefined, 
		StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='Attached file is not found ""%1"" (%2)';ru='Не найден присоединенный файл ""%1"" (%2)'"),
			String(AttachedFile), AttachedFile.Metadata()));
	
	SetPrivilegedMode(True);
	
	If FileObject.FileStorageType = Enums.FileStorageTypes.InInfobase Then
		Query = New Query;
		Query.Text = 
		"SELECT
		|	AttachedFiles.AttachedFile,
		|	AttachedFiles.StoredFile
		|FROM
		|	InformationRegister.AttachedFiles AS AttachedFiles
		|WHERE
		|	AttachedFiles.AttachedFile = &AttachedFile";
		
		Query.SetParameter("AttachedFile", AttachedFile);
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			Return Selection.StoredFile.Get();
		Else
			// Record in the event log.
			ErrorInfo = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='There is no binary data in"
""
"the AttachedFiles register Ref to file: ""%1"".';ru='Двоичные данные файла отсутствуют в регистре ПрисоединенныеФайлы"
""
"Ссылка на файл: ""%1"".'"),
				GetURL(AttachedFile));
			WriteLogEvent(NStr("en='Files.File opening';ru='Файлы.Открытие файла'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs[AttachedFile.Metadata().Name],
				AttachedFile,
				ErrorInfo);
			
			Raise FileFunctionsServiceClientServer.ErrorFileIsNotFoundInFileStorage(
				FileObject.Description + "." + FileObject.Extension, False);
		EndIf;
	Else
		FullPath = FileFunctionsService.FullPathOfVolume(FileObject.Volume) + FileObject.PathToFile;
		
		Try
			Return New BinaryData(FullPath);
		Except
			// Record in the event log.
			ErrorInfo = ErrorTextOnFileReceiving(ErrorInfo(), AttachedFile);
			WriteLogEvent(NStr("en='Files. Receiving of file from the volume';ru='Файлы.Получение файла из тома'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs[AttachedFile.Metadata().Name],
				AttachedFile,
				ErrorInfo);
			
			Raise FileFunctionsServiceClientServer.ErrorFileIsNotFoundInFileStorage(
				FileObject.Description + "." + FileObject.Extension);
		EndTry;
	EndIf;
	
EndFunction

// Returns structure of file data. Used in work with files
// commands both as FileData parameter value of other procedures and functions value.
//
// Parameters:
//  AttachedFile - CatalogRef - ref to catalog with the "AttachedFiles" name.
//
//  FormID - UUID - form ID
//                       that is used while receiving attachment binary data.
//
//  GetRefToBinaryData - Boolean - if you pass False, then ref to
//                 bunary data will not be connected and it will speed up execution for big binary data.
//
//  ForEditing - Boolean - if you specify True, then free file will be taken for editing.
//
// Returns:
//  Structure - with properties:
//    * RefToFileBinaryData        - String - address in the temporary storage.
//    * RelativePath                  - String -
//    * UniversalModificationDate       - Date   -
//    * FileName                           - String -
//    * Description                       - String -
//    * Extension                         - String -
//    * Size                             - Number  -
//    * Edits                        - Undefined, CatalogRef.Users, CatalogRef.ExternalUsers -
//    * DigitallySigned                         - Boolean -
//    * Encrypted                         - Boolean -
//    * FileEditing                  - Boolean -
//    * CurrentUserIsEditing - Boolean -
//
Function GetFileData(Val AttachedFile,
                            Val FormID = Undefined,
                            Val GetRefToBinaryData = True,
                            Val ForEditing = False) Export
	
	CommonUseClientServer.CheckParameter("AttachedFiles.ReceiveFileData", "AttachedFile", 
		AttachedFile, Metadata.InformationRegisters.AttachedFiles.Dimensions.AttachedFile.Type);
		
	FileObject = AttachedFile.GetObject();
	CommonUseClientServer.Validate(FileObject <> Undefined, 
		StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='Attached file is not found ""%1"" (%2)';ru='Не найден присоединенный файл ""%1"" (%2)'"),
			String(AttachedFile), AttachedFile.Metadata()));
	
	If ForEditing AND Not ValueIsFilled(FileObject.IsEditing) Then
		FileObject.Lock();
		AttachedFilesService.LockFileForEditingServer(FileObject);
	EndIf;
	
	SetPrivilegedMode(True);
	
	FileBinaryDataRef = Undefined;
	
	If GetRefToBinaryData Then
		
		BinaryData = GetFileBinaryData(AttachedFile);
		If TypeOf(FormID) = Type("UUID") Then
			FileBinaryDataRef = PutToTempStorage(BinaryData, FormID);
		Else
			FileBinaryDataRef = PutToTempStorage(BinaryData);
		EndIf;
		
	EndIf;
	
	Result = New Structure;
	Result.Insert("FileBinaryDataRef",  FileBinaryDataRef);
	Result.Insert("RelativePath",            GetObjectIdentifier(FileObject.FileOwner) + "\");
	Result.Insert("ModificationDateUniversal", FileObject.ModificationDateUniversal);
	Result.Insert("FileName",                     FileObject.Description + "." + FileObject.Extension);
	Result.Insert("Description",                 FileObject.Description);
	Result.Insert("Extension",                   FileObject.Extension);
	Result.Insert("Size",                       FileObject.Size);
	Result.Insert("IsEditing",                  FileObject.IsEditing);
	Result.Insert("DigitallySigned",                   FileObject.DigitallySigned);
	Result.Insert("Encrypted",                   FileObject.Encrypted);
	Result.Insert("FileIsEditing",            ValueIsFilled(FileObject.IsEditing));
	Result.Insert("FileCurrentUserIsEditing",
		?(Result.FileIsEditing, FileObject.IsEditing = Users.AuthorizedUser(), False) );
	
	If FileObject.Encrypted Then
		ArrayOfEncryptionCertificates = New Array;
		For Each TSRow IN FileObject.EncryptionCertificates Do
			ArrayOfEncryptionCertificates.Add(New Structure("Thumbprint, Presentation", TSRow.Imprint, TSRow.Presentation));
		EndDo;
		Result.Insert("ArrayOfEncryptionCertificates", ArrayOfEncryptionCertificates);
	EndIf;
	
	Return Result;
	
EndFunction

// Fills in array with references to object files.
//
// Parameters:
//  Object       - Ref - ref to object that can contain attached files.
//  FilesArray - Array - array to which references to object files will be added:
//                  * CatalogRef - (return value) references to the attached file.
//
Procedure GetAttachedFilesToObject(Val Object, Val FilesArray) Export
	
	OwnerTypes = Metadata.InformationRegisters.AttachedFilesExist.Dimensions.ObjectWithFiles.Type.Types();
	If OwnerTypes.Find(TypeOf(Object)) <> Undefined Then
		
		LocalFilesArray = AttachedFilesService.GetAllSubordinateFiles(Object);
		For Each FileReference IN LocalFilesArray Do
			FilesArray.Add(FileReference);
		EndDo;
		
	EndIf;
	
EndProcedure

// Creates an object in the catalog to store file and fills in its attributes with the passed properties.
//
// Parameters:
//  FilesOwner                 - Ref - object to which a file is added.
//  BaseName               - String - File name without extension.
//  ExtensionWithoutDot             - String - file extension (without point at the beginning).
//  ModifiedAt                 - Date   - (not used) date and tine of file change (local time).
//  ModificationTimeUniversal    - Date   - date and time of
//                                            the file change (UTC + 0:00) if it is not specified, then CurrentUniversalDate() is used.
//  FileAddressInTemporaryStorage - String - address that points to the binary data in temporary storage.
//  TextTemporaryStorageAddress - String - address pointing to extracted text from file in the temporary storage.
//  Definition                       - String - file text description.
//
//  NewRefToFile              - Undefined - create a new ref to file
//                                   in standard or non-standard catalog, but in the single catalog. If the file
//                                   owner has multiple catalogs, it is required to
//                                   pass ref, otherwise, an exception will be thrown.
//                                 - Ref - ref to file storage
//                                   catalog item which should be used to add a file.
//                                   It should correspond to one of the catalog
//                                   types of files owner files storage.
//
// Returns:
//  CatalogRef - ref to the created attached file.
//
Function AddFile(Val FilesOwner,
                     Val BaseName,
                     Val ExtensionWithoutDot = Undefined,
                     Val ModifiedAt = Undefined,
                     Val ModificationTimeUniversal = Undefined,
                     Val FileAddressInTemporaryStorage,
                     Val TextTemporaryStorageAddress = "",
                     Val Definition = "",
                     Val NewRefToFile = Undefined) Export
	
	// If the extension is not specified explicitly, extract it from the attachment file name.
	If ExtensionWithoutDot = Undefined Then
		FileNameParts = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(BaseName, ".", False);
		If FileNameParts.Count() > 1 Then
			ExtensionWithoutDot = FileNameParts[FileNameParts.Count()-1];
			BaseName = Left(BaseName, StrLen(BaseName) - (StrLen(ExtensionWithoutDot)+1));
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(ModificationTimeUniversal)
		Or ModificationTimeUniversal > CurrentUniversalDate() Then
		ModificationTimeUniversal = CurrentUniversalDate();
	EndIf;
	
	BinaryData = GetFromTempStorage(FileAddressInTemporaryStorage);
	
	ErrorTitle = NStr("en='Error when adding the attached file.';ru='Ошибка при добавлении присоединенного файла.'");
	
	If NewRefToFile = Undefined Then
		CatalogName = AttachedFilesService.CatalogNameStorageFiles(FilesOwner, "", ErrorTitle,
			NStr("en='In this case, the ""NewRefToFile"" parameter should be specified.';ru='В этом случае параметр ""НоваяСсылкаНаФайл"" должен быть указан.'"));
		
		NewRefToFile = Catalogs[CatalogName].GetRef();
	Else
		If Not Catalogs.AllRefsType().ContainsType(TypeOf(NewRefToFile))
			Or Not ValueIsFilled(NewRefToFile) Then
			
			Raise NStr("en='Error when adding the attached file."
"Reference to the new file is not filled.';ru='Ошибка при добавлении присоединенного файла."
"Ссылка на новый файл не заполнена.'");
		EndIf;
		
		CatalogName = AttachedFilesService.CatalogNameStorageFiles(
			FilesOwner, NewRefToFile.Metadata().Name, ErrorTitle);
	EndIf;
	
	AttachedFile = Catalogs[CatalogName].CreateItem();
	AttachedFile.SetNewObjectRef(NewRefToFile);
	
	AttachedFile.FileOwner                = FilesOwner;
	AttachedFile.ModificationDateUniversal = ModificationTimeUniversal;
	AttachedFile.CreationDate                 = CurrentSessionDate();
	AttachedFile.Definition                     = Definition;
	AttachedFile.DigitallySigned                   = False;
	AttachedFile.Description                 = BaseName;
	AttachedFile.Extension                   = ExtensionWithoutDot;
	AttachedFile.FileStorageType             = FileFunctionsService.TypeOfFileStorage();
	AttachedFile.Size                       = BinaryData.Size();
	
	OwnTransactionOpened = False;
	
	Try
		If AttachedFile.FileStorageType = Enums.FileStorageTypes.InInfobase Then
			BeginTransaction();
			OwnTransactionOpened = True;
			AttachedFilesService.WriteFileToInformationBase(NewRefToFile, BinaryData);
			AttachedFile.Volume = Catalogs.FileStorageVolumes.EmptyRef();
			AttachedFile.PathToFile = "";
		Else
			// Add to one of the volumes (where there is a vacant place).
			FileInformation = FileFunctionsService.AddFileToVolume(BinaryData, ModificationTimeUniversal,
				BaseName, ExtensionWithoutDot, , AttachedFile.Encrypted);
			AttachedFile.Volume = FileInformation.Volume;
			AttachedFile.PathToFile = FileInformation.PathToFile;
		EndIf;
		
		TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		ExtractedText = "";
		
		If IsTempStorageURL(TextTemporaryStorageAddress) Then
			ExtractedText = FileFunctionsService.GetStringFromTemporaryStorage(TextTemporaryStorageAddress);
			TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
			
		ElsIf Not FileFunctionsService.ExtractFileTextsAtServer() Then
			// Texts are extracted at once not in a background job.
			TextExtractionStatus = AttachedFilesService.ExtractText(
				BinaryData, AttachedFile.Extension, ExtractedText);
		EndIf;
		
		AttachedFile.TextExtractionStatus = TextExtractionStatus;
		AttachedFile.TextStorage = New ValueStorage(ExtractedText);
		
		AttachedFile.Write();
		
		If OwnTransactionOpened Then
			CommitTransaction();
		EndIf;
	
	Except
		ErrorInfo = ErrorInfo();
		
		If OwnTransactionOpened Then
			RollbackTransaction();
		EndIf;
		
		MessagePattern = NStr("en='An error occurred while adding"
"attached file ""%1"": %2';ru='Ошибка при добавлении"
"присоединенного файла ""%1"": %2'");
		CommentEventLogMonitor = StringFunctionsClientServer.PlaceParametersIntoString(
			MessagePattern,
			BaseName + "." + ExtensionWithoutDot,
			DetailErrorDescription(ErrorInfo));
		
		WriteLogEvent(
			NStr("en='Files. Attached file adding';ru='Файлы.Добавление присоединенного файла'",
			     CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,
			,
			,
			CommentEventLogMonitor);
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			MessagePattern,
			BaseName + "." + ExtensionWithoutDot,
			BriefErrorDescription(ErrorInfo));
	EndTry;
	
	Return AttachedFile.Ref;
	
EndFunction

// Returns new ref to file for
// the specified owner that can be used and later pass to the AddFile function.
//  
// Parameters:
//  FilesOwner - Ref - ref to object to which file is added.
//  
//  CatalogName - Undefined - calculate ref by owner
//                   (allowed when there is only one catalog, otherwise, it an exception will be thrown).
//  
//                 - String - * AttachedFiles catalog
//                            name that differs from the standard <OwnerName>AttachedFiles.
//  
// Returns:
//  CatalogRef - ref to a new not crated attached file.
//
Function NewRefToFile(FilesOwner, CatalogName = Undefined) Export
	
	ErrorTitle = NStr("en='Error when receiving a new reference to the attached file.';ru='Ошибка при получении новой ссылки на присоединенный файл.'");
	
	CatalogName = AttachedFilesService.CatalogNameStorageFiles(
		FilesOwner, CatalogName, ErrorTitle);
	
	Return Catalogs[CatalogName].GetRef();
	
EndFunction

// Updates file property - binary data, text,
// change date and other optional properties.
//
// Parameters:
//  AttachedFile - CatalogRef - ref to catalog with the "AttachedFiles" name.
//  InformationAboutFile - Structure - with properties:
//     <mandatory>
//     * FileAddressInTemporaryStorage - String - address of new binary file data.
//     * TemporaryTextStorageAddress - String - address of new
//                                                 binary data of a text extracted from the file.
//     <optional>
//     * NameWithoutExtension               - String - if property is not specified or
//                                                 not filled in, then it will not be changed.
//     * UniversalModificationDate   - Date   - date of the last
//                                                 file modification if a property is not set
//                                                 or specified, then the current session date is set.
//     * Extension                     - String - new file extension.
//     * Edits                    - Ref - new user that edits file.
//
Procedure UpdateAttachedFile(Val AttachedFile, Val InformationAboutFile) Export
	
	CommonUseClientServer.CheckParameter("AttachedFiles.ReceiveFileBinaryData", "AttachedFile", 
		AttachedFile, Metadata.InformationRegisters.AttachedFiles.Dimensions.AttachedFile.Type);
		
	ValueAttributes = New Structure;
	
	If InformationAboutFile.Property("BaseName") AND ValueIsFilled(InformationAboutFile.BaseName) Then
		ValueAttributes.Insert("Description", InformationAboutFile.BaseName);
	EndIf;
	
	If Not InformationAboutFile.Property("ModificationDateUniversal")
	 OR Not ValueIsFilled(InformationAboutFile.ModificationDateUniversal)
	 OR InformationAboutFile.ModificationDateUniversal > CurrentUniversalDate() Then
		
		// Fill in current date as universal time.
		ValueAttributes.Insert("ModificationDateUniversal", CurrentUniversalDate());
	Else
		ValueAttributes.Insert("ModificationDateUniversal", InformationAboutFile.ModificationDateUniversal);
	EndIf;
	
	If InformationAboutFile.Property("IsEditing") Then
		ValueAttributes.Insert("IsEditing", InformationAboutFile.IsEditing);
	EndIf;
	
	If InformationAboutFile.Property("Extension") Then
		ValueAttributes.Insert("Extension", InformationAboutFile.Extension);
	EndIf;
	
	BinaryData = GetFromTempStorage(InformationAboutFile.FileAddressInTemporaryStorage);
	
	ValueAttributes.Insert("TextExtractionStatus", Enums.FileTextExtractionStatuses.NotExtracted);
	ExtractedText = "";
	
	If IsTempStorageURL(InformationAboutFile.TextTemporaryStorageAddress) Then
		
		ExtractedText = FileFunctionsService.GetStringFromTemporaryStorage(
			InformationAboutFile.TextTemporaryStorageAddress);
		
		ValueAttributes.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		
	ElsIf Not FileFunctionsService.ExtractFileTextsAtServer() Then
		// Texts are extracted at once not in a background job.
		ValueAttributes.TextExtractionStatus = AttachedFilesService.ExtractText(
			BinaryData, AttachedFile.Extension, ExtractedText);
	EndIf;
	
	ValueAttributes.Insert("TextStorage", New ValueStorage(ExtractedText));
	
	AttachedFilesService.UpdateBinaryDataOfFileAtServer(
		AttachedFile, BinaryData, ValueAttributes);
	
EndProcedure

// Returns the form name of the attached files object by the owner.
//
// Parameters:
//  FilesOwner - Ref - ref to object according to which form name is determined.
//
// Returns:
//  String - form name of th attached files object by owner.
//
Function GetAttachedFilesObjectFormNameByOwner(Val FilesOwner) Export
	
	ErrorTitle = NStr("en='Error when receiving the attached file form name.';ru='Ошибка при получении имени формы присоединенного файла.'");
	EndErrors = NStr("en='In this case the form receiving is impossible.';ru='В этом случае получение формы невозможно.'");
	
	CatalogName = AttachedFilesService.CatalogNameStorageFiles(
		FilesOwner, "", ErrorTitle, EndErrors);
	
	FullMOName = "Catalog." + CatalogName;
	
	AttachedFilesMetadata = Metadata.FindByFullName(FullMOName);
	
	If AttachedFilesMetadata.DefaultObjectForm = Undefined Then
		FormName = FullMOName + ".ObjectForm";
	Else
		FormName = AttachedFilesMetadata.DefaultObjectForm.FullName();
	EndIf;
	
	Return FormName;
	
EndFunction

// Determines whether there is attached
// files storage in object right Add to storage (attached files catalog).
//
// Parameters:
//  FilesOwner - Ref - ref to object for which check is executed.
//  CatalogName - String - if it is required to check adding to the specified storage.
//
// Returns:
//  Boolean - if True, then it can attach files to object.
//
Function CanAttachFilesToObject(FilesOwner, CatalogName = "") Export
	
	CatalogName = AttachedFilesService.CatalogNameStorageFiles(
		FilesOwner, CatalogName);
		
	CatalogAttachedFiles = Metadata.Catalogs.Find(CatalogName);
	
	StoredFileTypes =
		Metadata.InformationRegisters.AttachedFiles.Dimensions.AttachedFile.Type;
	
	Return CatalogAttachedFiles <> Undefined
	      AND AccessRight("Insert", CatalogAttachedFiles)
	      AND StoredFileTypes.ContainsType(Type("CatalogRef." + CatalogName));
	
EndFunction

// Converts files from the Work with files subsystem to the Attached files subsystem.
// It requires the Work with files subsystem.
//
// For use in procedures of IB update if transition from
// use of one subsystem to another one is executed in a  files object-owner.
// Executed sequentially for each item
// of the files object-owner(catalog item, CCT, document etc.).
//
// Parameters:
//   FilesOwner - Ref - ref to object for which conversion is executed.
//   CatalogName - String - if conversion to the specified storage is required.
//
Procedure ConvertFilesToAttached(Val FilesOwner, CatalogName = Undefined) Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.FileOperations") Then
		Return;
	EndIf;
	
	ModuleFileOperationsServiceServerCall = CommonUse.CommonModule("FileOperationsServiceServerCall");
	ModuleFileOperationsService = CommonUse.CommonModule("FileOperationsService");
	
	ErrorTitle = NStr("en='An error occurred while converting subsystem attached files"
"Work with files to attached files of the Attached files subsystem.';ru='Ошибка при конвертации присоединенных файлов подсистемы Работа с файлами в присоединенные файлы подсистемы Присоединенные файлы.'");
	
	CatalogName = AttachedFilesService.CatalogNameStorageFiles(
		FilesOwner, CatalogName, ErrorTitle);
		
	SetPrivilegedMode(True);
	
	FilesSource = ModuleFileOperationsServiceServerCall.GetAllSubordinateFiles(FilesOwner);
	
	AttachedFilesManager = Catalogs[CatalogName];
	
	BeginTransaction();
	
	Try
		
		For Each FileSource IN FilesSource Do
			FileSourceObject = FileSource.GetObject();
			CurrentVersionObject = FileSourceObject.CurrentVersion.GetObject();
			
			RefNew = AttachedFilesManager.GetRef();
			AttachedFile = AttachedFilesManager.CreateItem();
			AttachedFile.SetNewObjectRef(RefNew);
			
			AttachedFile.FileOwner                = FilesOwner;
			AttachedFile.Description                 = FileSourceObject.Description;
			AttachedFile.Author                        = FileSourceObject.Author;
			AttachedFile.ModificationDateUniversal = CurrentVersionObject.ModificationDateUniversal;
			AttachedFile.CreationDate                 = FileSourceObject.CreationDate;
			
			AttachedFile.Encrypted                   = FileSourceObject.Encrypted;
			AttachedFile.Changed                      = CurrentVersionObject.Author;
			AttachedFile.Definition                     = FileSourceObject.Definition;
			AttachedFile.DigitallySigned                  = FileSourceObject.DigitallySigned;
			AttachedFile.Size                       = CurrentVersionObject.Size;
			
			AttachedFile.Extension                   = CurrentVersionObject.Extension;
			AttachedFile.IsEditing                  = FileSourceObject.IsEditing;
			AttachedFile.TextStorage               = FileSourceObject.TextStorage;
			AttachedFile.FileStorageType             = CurrentVersionObject.FileStorageType;
			AttachedFile.DeletionMark              = FileSourceObject.DeletionMark;
			
			// If file is stored in volume - reference is made to an existing file.
			AttachedFile.Volume                          = CurrentVersionObject.Volume;
			AttachedFile.PathToFile                   = CurrentVersionObject.PathToFile;
			
			For Each EncryptionCertificatesRow IN FileSourceObject.EncryptionCertificates Do
				NewRow = AttachedFile.EncryptionCertificates.Add();
				FillPropertyValues(NewRow, EncryptionCertificatesRow);
			EndDo;
			
			For Each ESString IN CurrentVersionObject.DigitalSignatures Do
				NewRow = AttachedFile.DigitalSignatures.Add();
				FillPropertyValues(NewRow, ESString);
			EndDo;
			
			AttachedFile.Write();
			
			If AttachedFile.FileStorageType = Enums.FileStorageTypes.InInfobase Then
				FileStorage = ModuleFileOperationsServiceServerCall.GetFileStorageFromInformationBase(CurrentVersionObject.Ref);
				BinaryData = FileStorage.Get();
				
				RecordManager = InformationRegisters.AttachedFiles.CreateRecordManager();
				RecordManager.AttachedFile = RefNew;
				RecordManager.Read();
				RecordManager.AttachedFile = RefNew;
				RecordManager.StoredFile = New ValueStorage(BinaryData, New Deflation(9));
				RecordManager.Write();
			EndIf;
			
			CurrentVersionObject.DeletionMark = True;
			FileSourceObject.DeletionMark = True;
			
			// Delete refs to volume in the old file. IN tjis case files will remain there during removal.
			If CurrentVersionObject.FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
				CurrentVersionObject.PathToFile = "";
				CurrentVersionObject.Volume = Catalogs.FileStorageVolumes.EmptyRef();
				FileSourceObject.CurrentVersionPathToFile = "";
				FileSourceObject.CurrentVersionVolume = "";
				ModuleFileOperationsService.MarkToDeleteFileVersions(FileSourceObject.Ref, CurrentVersionObject.Ref);
			EndIf;
			
			CurrentVersionObject.AdditionalProperties.Insert("FileConversion", True);
			CurrentVersionObject.Write();
			
			FileSourceObject.AdditionalProperties.Insert("FileConversion", True);
			FileSourceObject.Write();
			
		EndDo;
		
	Except
		ErrorInfo = ErrorInfo();
		RollbackTransaction();
		Raise DetailErrorDescription(ErrorInfo);
	EndTry;
	
	CommitTransaction();
	
EndProcedure

// Returns references to objects with files from the work with files subsystem.
// It requires the Work with files subsystem.
//
// Used together with the GenerateFilesToAttached function.
//
// Parameters:
//  FilesOwnersTable - String - full name
//                            of metadata object that can own attached files.
//
// Returns:
//  Array - with values:
//   * Ref - ref to object that has at least one attached file.
//
Function RefsToObjectsWithFiles(Val FilesOwnersTable) Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.FileOperations") Then
		Return New Array;
	EndIf;
	
	ModuleFileOperationsService = CommonUse.CommonModule("FileOperationsService");
	
	Return ModuleFileOperationsService.RefsToObjectsWithFiles(FilesOwnersTable);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures connected to the managed forms events.

// OnWriteAtServer event handler of managed form of the attached file owner.
//
// Parameters:
//  Cancel - Boolean  - OnWriteAtServer standard event parameter of the managed form.
//  CurrentObject   - Object - OnWriteAtServer standard event parameter of the managed form.
//  WriteParameters - Structure - OnWriteAtServer standard event parameter of the managed form.
//  Parameters       - FormDataStructure - property Managed form parameters.
//
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters, Parameters) Export
	
	If ValueIsFilled(Parameters.CopyingValue) Then
		
		AttachedFilesService.CopyAttachedFiles(
			Parameters.CopyingValue, CurrentObject);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures called from the module of catalogs manager with the attached files.

// Returns the list of
// attributes allowed to be changed with the help of the group change data processor.
//
// Returns:
//  Array - values:
//   * String - attached files attribute name that can
//              be edited in the bulk processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	EditableAttributes = New Array;
	EditableAttributes.Add("Definition");
	EditableAttributes.Add("IsEditing");
	
	Return EditableAttributes;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Operations with the digital signature.

// Adds signature to file.
// Parameters:
//  AttachedFile - Ref - references to attached file.
//
//  SignatureProperties    - Structure - contains data that is
//                       returned by the Sign procedure of the DigitalSignatureClient general module as a result.
//                     - Array - array of structures described above.
//                     
//  FormID - UUID - if it is specified, then it is used during the object lock.
//
Procedure AddFileSignature(AttachedFile, SignatureProperties, FormID = Undefined) Export
	
	If CommonUse.IsReference(TypeOf(AttachedFile)) Then
		AttributesStructure = CommonUse.ObjectAttributesValues(AttachedFile, "IsEditing, Encrypted");
		AttachedFileRef = AttachedFile;
	Else
		AttributesStructure = New Structure("IsEditing, Encrypted");
		AttributesStructure.IsEditing = AttachedFile.IsEditing;
		AttributesStructure.Encrypted  = AttachedFile.Encrypted;
		AttachedFileRef = AttachedFile.Ref;
	EndIf;
	
	CommonUseClientServer.CheckParameter("AttachedFiles.AddSignatureToFile", "AttachedFile", 
		AttachedFileRef, Metadata.InformationRegisters.AttachedFiles.Dimensions.AttachedFile.Type);
		
	If ValueIsFilled(AttributesStructure.IsEditing) Then
		Raise FileFunctionsServiceClientServer.MessageStringAboutImpossibilityOfLockedFileSigning(AttachedFileRef);
	EndIf;
	
	If AttributesStructure.Encrypted Then
		Raise FileFunctionsServiceClientServer.MessageStringAboutImpossibilityOfEncryptedFileSigning(AttachedFileRef);
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignature = CommonUse.CommonModule("DigitalSignature");
		ModuleDigitalSignature.AddSignature(AttachedFile, SignatureProperties, FormID);
	EndIf;
	
EndProcedure

// Outdated. You should use the AddSignatureToFile procedure.
Procedure AddInformationOfOneSignature(Val AttachedFile, Val SignatureData) Export
	
	SignatureProperties = New Structure;
	SignatureProperties.Insert("Signature",             SignatureData.NewSignatureBinaryData);
	SignatureProperties.Insert("Imprint",           SignatureData.Imprint);
	SignatureProperties.Insert("SignatureDate",         SignatureData.SignatureDate);
	SignatureProperties.Insert("Comment",         SignatureData.Comment);
	SignatureProperties.Insert("SignatureFileName",     SignatureData.SignatureFileName);
	SignatureProperties.Insert("CertificateIsIssuedTo", SignatureData.CertificateIsIssuedTo);
	SignatureProperties.Insert("Certificate",          SignatureData.CertificateBinaryData);
	
	AddFileSignature(AttachedFile, SignatureProperties);
	
EndProcedure

// Outdated. You should use the AddSignatureToFile procedure.
Procedure AddInformationAboutSignatures(Val AttachedFile, Val SignaturesArray) Export
	
	SignaturesProperties = New Array;
	For Each SignatureData IN SignaturesArray Do
		
		SignatureProperties = New Structure;
		SignatureProperties.Insert("Signature",             SignatureData.NewSignatureBinaryData);
		SignatureProperties.Insert("Imprint",           SignatureData.Imprint);
		SignatureProperties.Insert("SignatureDate",         SignatureData.SignatureDate);
		SignatureProperties.Insert("Comment",         SignatureData.Comment);
		SignatureProperties.Insert("SignatureFileName",     SignatureData.SignatureFileName);
		SignatureProperties.Insert("CertificateIsIssuedTo", SignatureData.CertificateIsIssuedTo);
		SignatureProperties.Insert("Certificate",          SignatureData.CertificateBinaryData);
		
		SignaturesProperties.Add(SignatureProperties);
	EndDo;
	
	AddFileSignature(AttachedFile, SignatureProperties);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the subscriptions to events.

// Handler of BeforeWrite event subscription to fill in auto attributes of attached file.
//
// Parameters:
//  Source   - CatalogObject - catalog object with the "*AttachedFiles" name.
//  Cancel      - Boolean - parameter passed to the BeforeWrite event subscription.
//
Procedure PerformActionsBeforeWriteAttachedFile(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Source.FileOwner) Then
		
		ErrorDescription = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Owner in file is"
"not filled in ""%1"".';ru='Не заполнен"
"владелец в файле ""%1"".'"),
			Source.Description);
		
		If InfobaseUpdate.InfobaseUpdateInProgress() Then
			
			WriteLogEvent(
				NStr("en='Files. File record error at IB update';ru='Файлы.Ошибка записи файла при обновлении ИБ'",
				     CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				,
				Source.Ref,
				ErrorDescription);
		Else
			Raise ErrorDescription;
		EndIf;
		
	EndIf;
	
	Source.PictureIndex = FileFunctionsServiceClientServer.GetFileIconIndex(Source.Extension);
	
	If Source.IsNew() Then
		Source.Author = Users.AuthorizedUser();
	EndIf;
	
EndProcedure

// Handler of BeforeDeletion event subscription to delete data connected with attached file.
//
// Parameters:
//  Source   - CatalogObject - catalog object with the "*AttachedFiles" name.
//  Cancel      - Boolean - parameter passed to the BeforeWrite event subscription.
//
Procedure ExecuteActionsBeforeDeleteAttachedFile(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	AttachedFilesService.BeforeAttachedFileDeletingServer(
		Source.Ref,
		Source.FileOwner,
		Source.Volume,
		Source.FileStorageType,
		Source.PathToFile);
	
EndProcedure

// Handler of OnWrite event subscription to update data connected with attached file.
//
// Parameters:
//  Source   - CatalogObject - catalog object with the "*AttachedFiles" name.
//  Cancel      - Boolean - parameter passed to the BeforeWrite event subscription.
//
Procedure ExecuteActionsOnWriteAttachedFile(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		WriteDataFileIntoTableWhenExchange(Source);
		Return;
	EndIf;
	
	AttachedFilesService.OnAttachedFileWriteServer(
		Source.FileOwner);
		
	AttachedFilesService.WhenUpdatingStatusQueueTextExtraction(
		Source.Ref, Source.TextExtractionStatus);
	
EndProcedure

// Handler of FormReceiptDataProcessor event subscription to override attached file form.
//
// Parameters:
//  Source                 - CatalogManager - catalog manager with the "AttachedFiles" name.
//  FormKind                 - String - standard form name.
//  Parameters                - Structure - form parameters.
//  SelectedForm           - String - metadata name or object of the opened form.
//  AdditionalInformation - Structure - form opening additional information.
//  StandardProcessing     - Boolean - shows that standard (system) event data processor is executed.
//
Procedure OverrideReceivedFormAttachedFile(Source, FormKind, Parameters,
			SelectedForm, AdditionalInformation, StandardProcessing) Export
	
	If FormKind = "ObjectForm" Then
		SelectedForm = "CommonForm.AttachedFile";
		StandardProcessing = False;
		
	ElsIf FormKind = "ListForm" Then
		SelectedForm = "CommonForm.AttachedFiles";
		StandardProcessing = False;
	EndIf;
	
EndProcedure

// Handler of BeforeWrite event subscription of the attached file owner.
// Marks linked files for deletion.
//
// Parameters:
//  Source - Object - attached file owner except of ObjectDocument.
//  Cancel    - Boolean - shows that record has been canceled.
// 
Procedure SetDeletionMarkOnAttachedFiles(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	MarkToDeleteAttachedFiles(Source);
	
EndProcedure

// Handler of BeforeWrite event subscription of the attached file owner.
// Marks linked files for deletion.
//
// Parameters:
//  Source        - DocumentObject - attached file owner.
//  Cancel           - Boolean - parameter passed to the BeforeWrite event subscription.
//  WriteMode     - Boolean - parameter passed to the BeforeWrite event subscription.
//  PostingMode - Boolean - parameter passed to the BeforeWrite event subscription.
// 
Procedure SetDeletionMarkOnAttachedDocumentFiles(Source, Cancel, WriteMode, PostingMode) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	MarkToDeleteAttachedFiles(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OUTDATED PROCEDURES AND FUNCTIONS

// Outdated. You should use ExecuteActionsBeforeWritingAttachedFile.
Procedure BeforeAttachedFileWrite(Source, Cancel) Export
	
	PerformActionsBeforeWriteAttachedFile(Source, Cancel);
	
EndProcedure

// Outdated. You should use ExecuteActionsBeforeDeletingAttachedFile.
Procedure BeforeAttachedFileDeleting(Source, Cancel) Export
	
	ExecuteActionsBeforeDeleteAttachedFile(Source, Cancel);
	
EndProcedure

// Outdated. You should use ExecuteActionsOnWriteAttachedFile.
Procedure OnAttachedFileWrite(Source, Cancel) Export
	
	ExecuteActionsOnWriteAttachedFile(Source, Cancel);
	
EndProcedure

// Outdated. You should use OverrideAttachedFileReceivedForm.
Procedure AttachedFileFormGetProcessing(Source,
                                                      FormKind,
                                                      Parameters,
                                                      SelectedForm,
                                                      AdditionalInformation,
                                                      StandardProcessing) Export
	
	AttachedFilesClientServer.OverrideReceivedFormAttachedFile(Source, FormKind, Parameters,
		SelectedForm, AdditionalInformation, StandardProcessing);

EndProcedure

// Outdated. You should use subscription to the FormReceiptProcessor event.See
// AttachedFilesClientServer.OverrideAttachedFileReceivedForm
//
// Sets form of the OnCreateAtServer attached file.
Procedure OnCreateAtServerAttachedFile(Val Form) Export
	
	If Form.Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Form.Parameters.Property("Key", Form.Key) Then
		Form.Key = Form.Parameters.Key;
	EndIf;
	
	Form.AutoTitle = False;
	Form.Title = NStr("en='Attached file';ru='Присоединенный файл'");
	
	Command = Form.Commands.Add("GoToFileForm");
	Command.Action = "Attachable_GoToFileForm";
	
	Decoration = Form.Items.Add("ExplanationText", Type("FormDecoration"));
	Decoration.Title = NStr("en='In order to proceed to the file card press the hyperlink';ru='Для того, чтобы перейти к карточке файла, нажмите на гиперссылку'");
	
	Button = Form.Items.Add("GoToFileForm1", Type("FormButton"));
	Button.Type        = FormButtonType.Hyperlink;
	Button.Title  = NStr("en='Go to file form';ru='Перейти к форме файла'");
	Button.CommandName = "GoToFileForm";
	
EndProcedure

// Outdated. Do not use.
// Throws exception in the standard form of the attached files catalog list.
Procedure CallFormOpeningException(Form) Export
	
	If Form.Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Raise NStr("en='Cannot open the form directly.';ru='Самостоятельное использование формы не предусмотрено.'");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// Returns an error text and adds a ref to
// the catalog item of the stored file to it.
//
Function ErrorTextOnFileReceiving(Val ErrorInfo, Val File)
	
	ErrorInfo = BriefErrorDescription(ErrorInfo);
	
	If File <> Undefined Then
		ErrorInfo = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='%1"
""
"Ref to file: ""%2"".';ru='%1"
""
"Ссылка на файл: ""%2"".'"),
			ErrorInfo,
			GetURL(File) );
	EndIf;
	
	Return ErrorInfo;
	
EndFunction

// Returns attached file owner ID.
Function GetObjectIdentifier(Val FilesOwner)
	
	QueryText =
	"SELECT
	|	AttachedFilesExist.ObjectID
	|FROM
	|	InformationRegister.AttachedFilesExist AS AttachedFilesExist
	|WHERE
	|	AttachedFilesExist.ObjectWithFiles = &ObjectWithFiles";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ObjectWithFiles", FilesOwner);
	ExecutionResult = Query.Execute();
	
	If ExecutionResult.IsEmpty() Then
		Return "";
	EndIf;
	
	Selection = ExecutionResult.Select();
	Selection.Next();
	
	Return Selection.ObjectID;
	
EndFunction

Procedure MarkToDeleteAttachedFiles(Val Source, CatalogName = Undefined)
	
	If Source.IsNew() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	SourceRefDeletionMark = CommonUse.ObjectAttributeValue(Source.Ref, "DeletionMark");
	
	If Source.DeletionMark = SourceRefDeletionMark Then
		Return;
	EndIf;
	
	Try
		NamesOfCatalogs = AttachedFilesService.CatalogsNamesFilesStorage(
			TypeOf(Source.Ref));
	Except
		ErrorPresentation = BriefErrorDescription(ErrorInfo());
		Raise NStr("en='Error when marking for deletion of the attached files.';ru='Ошибка при пометке на удаление присоединенных файлов.'")
			+ Chars.LF
			+ ErrorPresentation;
	EndTry;
	
	Query = New Query;
	Query.SetParameter("FileOwner", Source.Ref);
	
	QueryText =
	"SELECT
	|	Files.Ref AS Ref,
	|	Files.IsEditing AS IsEditing
	|FROM
	|	&CatalogName AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner";
	
	For Each DetailsNameCatalog IN NamesOfCatalogs Do
		
		CatalogFullName = "Catalog." + DetailsNameCatalog.Key;
		Query.Text = StrReplace(QueryText, "&CatalogName", CatalogFullName);
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			If Source.DeletionMark AND ValueIsFilled(Selection.IsEditing) Then
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='""%1"" can not be"
"deleted, so. contains attached"
"file ""%2"" taken for editing.';ru='""%1"" не может быть удален,"
"т.к. содержит присоединенный файл ""%2"","
"занятый для редактирования.'"),
					String(Source.Ref),
					String(Selection.Ref));
			EndIf;
			FileObject = Selection.Ref.GetObject();
			FileObject.Lock();
			FileObject.SetDeletionMark(Source.DeletionMark);
		EndDo;
	EndDo;
	
EndProcedure

Procedure WriteDataFileIntoTableWhenExchange(Val Source)
	
	Var FileBinaryData;
	
	If Source.AdditionalProperties.Property("FileBinaryData", FileBinaryData) Then
		RecordSet = InformationRegisters.AttachedFiles.CreateRecordSet();
		RecordSet.Filter.AttachedFile.Use = True;
		RecordSet.Filter.AttachedFile.Value = Source.Ref;
		
		Record = RecordSet.Add();
		Record.AttachedFile = Source.Ref;
		Record.StoredFile = New ValueStorage(FileBinaryData, New Deflation(9));
		
		RecordSet.DataExchange.Load = True;
		RecordSet.Write();
		
		Source.AdditionalProperties.Delete("FileBinaryData");
	EndIf;
	
EndProcedure

#EndRegion
