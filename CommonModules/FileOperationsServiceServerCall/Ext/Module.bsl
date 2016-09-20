
////////////////////////////////////////////////////////////////////////////////
// Subsystem "Working with files".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// It creates a new file by analogy with the specified one and returns a reference to it.
// Parameters:
//  SourceFile  - CatalogRef.Files - existing file.
//  OwnerOfNewFile - AnyRef - file owner.
//
// Returns:
//   CatalogRef.Files - new file.
//
Function CopyFile(SourceFile, OwnerOfNewFile) Export
	
	If SourceFile = Undefined Or SourceFile.IsEmpty() Or SourceFile.CurrentVersion.IsEmpty()Then
		Return Undefined;
	EndIf;	
	
	FileInformation = FileOperationsClientServer.FileInformation("FileWithVersion");
	FileInformation.Comment = SourceFile.Description;
	FileInformation.BaseName = SourceFile.FullDescr;
	FileInformation.StoreVersions = SourceFile.StoreVersions;

	NewFile = CreateFile(OwnerOfNewFile, FileInformation);
		
	FileStorage = Undefined;
	If SourceFile.CurrentVersion.FileStorageType = Enums.FileStorageTypes.InInfobase Then 
		FileStorage = GetFileStorageFromInformationBase(SourceFile.CurrentVersion);
	EndIf;
		
	FileInformation.Size = SourceFile.CurrentVersion.Size;
	FileInformation.ExtensionWithoutDot = SourceFile.CurrentVersion.Extension;
	FileInformation.FileTemporaryStorageAddress = FileStorage;
	FileInformation.TextTemporaryStorageAddress = SourceFile.CurrentVersion.TextStorage;
	FileInformation.RefOnVersionSource = SourceFile.CurrentVersion;
	
	Version = Create_Version(NewFile, FileInformation);
	RefreshVersionInFile(NewFile, Version, SourceFile.CurrentVersion.TextStorage);
	
	VersionObject = NewFile.CurrentVersion.GetObject();
	
	NumberOfSignatures = 0;
	For Each String IN SourceFile.CurrentVersion.DigitalSignatures Do
		NewRow = VersionObject.DigitalSignatures.Add();
		FillPropertyValues(NewRow, String);
		NumberOfSignatures = NumberOfSignatures + 1;
	EndDo;
	
	If NumberOfSignatures <>  0 Then
		FileObject = NewFile.GetObject();
		FileObject.DigitallySigned = True;
		FileObject.Write();
		
		VersionObject.DigitallySigned = True;
		VersionObject.Write();
	EndIf;
	
	If SourceFile.Encrypted Then
		
		FileObject = NewFile.GetObject();
		FileObject.Encrypted = True;
		
		For Each String IN SourceFile.EncryptionCertificates Do
			NewRow = FileObject.EncryptionCertificates.Add();
			FillPropertyValues(NewRow, String);
		EndDo;
		
		// To record a previously signed object.
		FileObject.AdditionalProperties.Insert("DigitallySignedObjectRecord", True);
		FileObject.Write();
		
		VersionObject = NewFile.CurrentVersion.GetObject();
		VersionObject.Encrypted = True;
		// To record a previously signed object.
		VersionObject.AdditionalProperties.Insert("DigitallySignedObjectRecord", True);
		VersionObject.Write();
		
	EndIf;
	
	FileOperationsOverridable.FillFileAttributesFromSourceFile(NewFile, SourceFile);
	
	Return NewFile;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// It releases the file.
//
// Parameters:
//   FileData - Structure - see FileData.
//   UUID - UUID - form unique ID.
//
Procedure ReleaseFile(FileData, UUID = Undefined) Export
	
	FileObject = FileData.Ref.GetObject();
	
	LockDataForEdit(FileObject.Ref, , UUID);
	FileObject.IsEditing = Catalogs.Users.EmptyRef();
	FileObject.LoanDate = Date("00010101000000");
	FileObject.Write();
	UnlockDataForEdit(FileObject.Ref, UUID);
	
	FileOperationsOverridable.OnFileRelease(FileData, UUID);
	
EndProcedure

// Locks the file for editing (checkout).
//
// Parameters:
//  FileData    - structure with file data.
//  ErrorString - String used to return the error reason in case of failure
//                 (for example, the file is busy by the other user).
//  UUID - form unique ID.
//
// Returns:
//   Boolean  - whether the operation is successfully completed.
//
Function LockFile(FileData, ErrorString = "", UUID = Undefined) Export
	
	If Not FileOperationsOverridable.ProbablyFileIsLocked(FileData, ErrorString) Then
		Return False;
	EndIf;
	
	ErrorString = "";
	FileOperationsOverridable.WhenTryingToLockFile(FileData, ErrorString);
	If Not IsBlankString(ErrorString) Then
		Return False;
	EndIf;
	
	FileObject = FileData.Ref.GetObject();
	
	LockDataForEdit(FileObject.Ref, , UUID);
	FileObject.IsEditing = Users.CurrentUser();
	FileObject.LoanDate = CurrentSessionDate();
	FileObject.Write();
	UnlockDataForEdit(FileObject.Ref, UUID);

	CurrentVersionURL = FileData.CurrentVersionURL;
	OwnerWorkingDirectory = FileData.OwnerWorkingDirectory;
	
	FileData = FileData(FileData.Version);
	FileData.CurrentVersionURL = CurrentVersionURL;
	FileData.OwnerWorkingDirectory = OwnerWorkingDirectory;
	
	FileOperationsOverridable.AtFileCapture(FileData, UUID);
	
	Return True;
	
EndFunction

// It moves the File to another folder.
//
// Parameters:
//  FileData  - structure with file data.
//  Folder - CatalogRef.FileFolders - ref to the folder where the file shall be moved.
//
Procedure TransferFile(FileData, Folder) Export 
	
	FileObject = FileData.Ref.GetObject();
	FileObject.Lock();
	FileObject.FileOwner = Folder;
	FileObject.Write();
	
EndProcedure

// It moves the Files to another folder.
//
// Parameters:
//  ObjectsRef - Array - array of references to files.
//  Folder - CatalogRef.FileFolders - ref to the folder where the files shall be moved.
//
Function TransferFiles(ObjectsRef, Folder) Export 
	
	DataFiles = New Array;
	
	For Each FileRef IN ObjectsRef Do
		TransferFile(FileRef, Folder);
		FileData = FileData(FileRef);
		DataFiles.Add(FileData);
	EndDo;
	
	Return DataFiles;
	
EndFunction

// It creates file in IB.
//
// Parameters:
//   Owner           - CatalogRef.FileFolders, AnyRef - It will be set to
//                    the FileOwner attribute for the created file.
//   FileInformation - Structure - see FileOperationsClientServer.FileInfo in File mode.
//
// Returns:
//    CatalogRef.Files - created file.
//
Function CreateFile(Val Owner, Val FileInformation) Export
	
	File = Catalogs.Files.CreateItem();
	File.FileOwner = Owner;
	File.Description = FileInformation.BaseName;
	File.FullDescr = FileInformation.BaseName;
	File.Author = ?(FileInformation.Author <> Undefined, FileInformation.Author, Users.CurrentUser());
	File.CreationDate = CurrentSessionDate();
	File.Description = FileInformation.Comment;
	File.PictureIndex = FileFunctionsServiceClientServer.GetFileIconIndex(Undefined);
	File.StoreVersions = FileInformation.StoreVersions;
	
	If TypeOf(FileInformation.TextTemporaryStorageAddress) = Type("ValueStorage") Then
		// When you create a file based on the template, the storage value is copied directly.
		File.TextStorage = FileInformation.TextTemporaryStorageAddress;
	ElsIf Not IsBlankString(FileInformation.TextTemporaryStorageAddress) Then
		Text = FileFunctionsService.GetStringFromTemporaryStorage(FileInformation.TextTemporaryStorageAddress);
		File.TextStorage = New ValueStorage(Text);
	EndIf;
	
	File.Write();
	Return File.Ref;
	
EndFunction

// It finds the maximum version number for this File object. If there is no versions - then 0.
// Parameters:
//  FileRef  - CatalogRef.Files - Ref to the file.
//
// Returns:
//   Number  - maximum version number.
//
Function FindMaximumVersionNumber(FileRef)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ISNULL(MAX(Versions.VersionNumber), 0) AS MaximumNumber
	|FROM
	|	Catalog.FileVersions AS Versions
	|WHERE
	|	Versions.Owner = &File";
	
	Query.Parameters.Insert("File", FileRef);
		
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		If Selection.MaximumNumber = Null Then
			Return 0;
		EndIf;
		
		Return Number(Selection.MaximumNumber);
	EndIf;
	
	Return 0;
EndFunction

// It creates a version of the saved file to be saved in IB.
//
// Parameters:
//   FileRef     - CatalogRef.Files - file for which you create a new version.
//   FileInformation - Structure - see FileOperationsClientServer.FileInfo, in FileWithVersion mode.
//
// Returns:
//   CatalogRef.FileVersions - created version.
//
Function Create_Version(FileRef, FileInformation) Export
	
	FileStorage = Undefined;
	
	SetPrivilegedMode(True);
	
	If Not ValueIsFilled(FileInformation.ModificationTimeUniversal)
		Or FileInformation.ModificationTimeUniversal > CurrentUniversalDate() Then
		
		FileInformation.ModificationTimeUniversal = CurrentUniversalDate();
	EndIf;
	
	If Not ValueIsFilled(FileInformation.ModifiedAt)
		Or ToUniversalTime(FileInformation.ModifiedAt) > FileInformation.ModificationTimeUniversal Then
		
		FileInformation.ModifiedAt = CurrentSessionDate();
	EndIf;
	
	FileFunctionsServiceClientServer.CheckFileExtensionForImporting(FileInformation.ExtensionWithoutDot);
	
	Version = Catalogs.FileVersions.CreateItem();
	
	If FileInformation.NewVersionVersionNumber = Undefined Then
		Version.VersionNumber = FindMaximumVersionNumber(FileRef) + 1;
	Else
		Version.VersionNumber = FileInformation.NewVersionVersionNumber;
	EndIf;
	
	Version.Owner = FileRef;
	Version.ModificationDateUniversal = FileInformation.ModificationTimeUniversal;
	Version.FileModificationDate = FileInformation.ModifiedAt;
	
	Version.Comment = FileInformation.NewVersionComment;
	
	If FileInformation.NewVersionAuthor = Undefined Then
		Version.Author = Users.CurrentUser();
	Else
		Version.Author = FileInformation.NewVersionAuthor;
	EndIf;
	
	If FileInformation.NewVersionCreationDate = Undefined Then
		Version.CreationDate = CurrentSessionDate();
	Else
		Version.CreationDate = FileInformation.NewVersionCreationDate;
	EndIf;
	
	Version.FullDescr = FileInformation.BaseName;
	Version.Size = FileInformation.Size;
	Version.Extension = CommonUseClientServer.ExtensionWithoutDot(FileInformation.ExtensionWithoutDot);
	
	TypeOfFileStorage = FileFunctionsService.TypeOfFileStorage();
	Version.FileStorageType = TypeOfFileStorage;

	If FileInformation.RefOnVersionSource <> Undefined Then // create File using the template
		
		TypeOfTemplateFilesStorage = FileInformation.RefOnVersionSource.FileStorageType;
		
		If TypeOfTemplateFilesStorage = Enums.FileStorageTypes.InInfobase AND TypeOfFileStorage = Enums.FileStorageTypes.InInfobase Then
			// both template and new file - in the base.
			// When you create a file based on the template, the storage value is copied directly.
			FileStorage = FileInformation.FileTemporaryStorageAddress;
			
		ElsIf TypeOfTemplateFilesStorage = Enums.FileStorageTypes.InVolumesOnDrive AND TypeOfFileStorage = Enums.FileStorageTypes.InVolumesOnDrive Then
			//  Both template and new file - on the disk - simply copy the file.
			
			If Not FileInformation.RefOnVersionSource.Volume.IsEmpty() Then
				TemplateFileFullPath = FileFunctionsService.FullPathOfVolume(FileInformation.RefOnVersionSource.Volume) 
					+ FileInformation.RefOnVersionSource.PathToFile; 
				
				Information = FileFunctionsService.AddFileToVolume(TemplateFileFullPath, FileInformation.ModificationTimeUniversal,
					FileInformation.BaseName, FileInformation.ExtensionWithoutDot, Version.VersionNumber, FileInformation.RefOnVersionSource.Encrypted); 
				Version.Volume = Information.Volume;
				Version.PathToFile = Information.PathToFile;
			EndIf;
			
		ElsIf TypeOfTemplateFilesStorage = Enums.FileStorageTypes.InInfobase AND TypeOfFileStorage = Enums.FileStorageTypes.InVolumesOnDrive Then
			// Template in the base, new File - on the disk.
			// IN this case ValueStorage with the file is located in FileTemporaryStorageAddress.
			Information = FileFunctionsService.AddFileToVolume(FileInformation.FileTemporaryStorageAddress.Get(),
				FileInformation.ModificationTimeUniversal, FileInformation.BaseName, FileInformation.ExtensionWithoutDot,
				Version.VersionNumber, FileInformation.RefOnVersionSource.Encrypted); 
			Version.Volume = Information.Volume;
			Version.PathToFile = Information.PathToFile;
			
		ElsIf TypeOfTemplateFilesStorage = Enums.FileStorageTypes.InVolumesOnDrive AND TypeOfFileStorage = Enums.FileStorageTypes.InInfobase Then
			// Template is on the disk, new File - in the base.
			If Not FileInformation.RefOnVersionSource.Volume.IsEmpty() Then
				TemplateFileFullPath = FileFunctionsService.FullPathOfVolume(FileInformation.RefOnVersionSource.Volume) + FileInformation.RefOnVersionSource.PathToFile; 
				BinaryData = New BinaryData(TemplateFileFullPath);
				FileStorage = New ValueStorage(BinaryData);
			EndIf;
			
		EndIf;
	Else // Creating File object based on the selected file from the disk.
		
		If TypeOfFileStorage = Enums.FileStorageTypes.InInfobase Then
			
			FileStorage = New ValueStorage(
				GetFromTempStorage(FileInformation.FileTemporaryStorageAddress));
				
			If Version.Size = 0 Then
				FileBinaryData = FileStorage.Get();
				Version.Size = FileBinaryData.Size();
				
				FileFunctionsServiceClientServer.CheckFileSizeForImporting(Version);
			EndIf;
				
		Else // storage on the disk
			
			BinaryData = GetFromTempStorage(FileInformation.FileTemporaryStorageAddress);
			
			If Version.Size = 0 Then
				Version.Size = BinaryData.Size();
				FileFunctionsServiceClientServer.CheckFileSizeForImporting(Version);
			EndIf;
			
			Information = FileFunctionsService.AddFileToVolume(BinaryData,
				FileInformation.ModificationTimeUniversal, FileInformation.BaseName, FileInformation.ExtensionWithoutDot,
				Version.VersionNumber); 
			Version.Volume = Information.Volume;
			Version.PathToFile = Information.PathToFile;
			
		EndIf; 
		
	EndIf;
	
	Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;

	If TypeOf(FileInformation.TextTemporaryStorageAddress) = Type("ValueStorage") Then
		// When you create a file based on the template, the storage value is copied directly.
		Version.TextStorage = FileInformation.TextTemporaryStorageAddress;
		Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
	ElsIf Not IsBlankString(FileInformation.TextTemporaryStorageAddress) Then
		Text = FileFunctionsService.GetStringFromTemporaryStorage(FileInformation.TextTemporaryStorageAddress);
		Version.TextStorage = New ValueStorage(Text);
		Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
	EndIf;
		
	If Version.Size = 0 Then
		If TypeOfFileStorage = Enums.FileStorageTypes.InInfobase Then
			FileBinaryData = FileStorage.Get();
			Version.Size = FileBinaryData.Size();
		EndIf;
	EndIf;

	Version.Write();
	
	If TypeOfFileStorage = Enums.FileStorageTypes.InInfobase Then
		WriteFileToInformationBase(Version.Ref, FileStorage);
	EndIf;
	
	Return Version.Ref;
	
EndFunction

// It inserts a version reference to the file card.
//
// Parameters:
// FileRef - CatalogRef.Files - File where the version is created.
// Version  - CatalogRef.FileVersions - file version.
// TextTemporaryStorageAddress - String - It contains address in the temporary storage where
//                                           binary data with the text file or ValueStorage are stored - contains
//                                           binary data with the text file.
//  UUID - form unique ID.
//
Procedure RefreshVersionInFile(FileRef,
                               Version,
                               Val TextTemporaryStorageAddress,
                               UUID = Undefined) Export
	
	FileObject = FileRef.GetObject();
	LockDataForEdit(FileObject.Ref, , UUID);
	
	FileObject.CurrentVersion = Version.Ref;
	
	If TypeOf(TextTemporaryStorageAddress) = Type("ValueStorage") Then
		// When you create a file based on the template, the storage value is copied directly.
		FileObject.TextStorage = TextTemporaryStorageAddress;
	Else
		Text = FileFunctionsService.GetStringFromTemporaryStorage(TextTemporaryStorageAddress);
		FileObject.TextStorage = New ValueStorage(Text);
	EndIf;
	
	FileObject.Write();
	UnlockDataForEdit(FileObject.Ref, UUID);
	
EndProcedure

// It updates the text portion of the file in the file card.
//
// Parameters:
// FileRef - CatalogRef.Files - File where the version is created.
// TextTemporaryStorageAddress - String - It contains address in the temporary storage where
//                                           binary data with the text file or ValueStorage are stored. - contains
//                                           binary data with the text file.
//  UUID - form unique ID.
//
Procedure UpdateTextInFile(FileRef,
                              Val TextTemporaryStorageAddress,
                              UUID = Undefined)
	
	FileObject = FileRef.GetObject();
	LockDataForEdit(FileObject.Ref, , UUID);
	
	Text = FileFunctionsService.GetStringFromTemporaryStorage(TextTemporaryStorageAddress);
	FileObject.TextStorage = New ValueStorage(Text);
	
	FileObject.Write();
	UnlockDataForEdit(FileObject.Ref, UUID);
	
EndProcedure

// It updates or creates a file version and returns a reference to the updated version (or
// False if the file is not binary modified).
//
// Parameters:
//   FileRef         - CatalogRef.Files        - file for which you create a new version.
//   FileInformation - Structure               - see FileOperationsClientServer.FileInfo,
//                                               in the FileWithVersion mode.
//   VersionRef      - CatalogRef.FileVersions - file version to be updated.
//   FormUUID                                  - UUID - form unique ID
//                                               for the purpose of the operation execution.
//
// Returns:
//   CatalogRef.FileVersions - created or modified version; Undefined if the file is not binary changed.
//
Function UpdateFileVersion(FileRef, FileInformation, VersionRef = Undefined, FormUUID = Undefined)
	
	IsRightSave = AccessRight("SaveUserData", Metadata);
	
	SetPrivilegedMode(True);
	
	ModificationTimeUniversal = FileInformation.ModificationTimeUniversal;
	If Not ValueIsFilled(ModificationTimeUniversal)
		OR ModificationTimeUniversal > CurrentUniversalDate() Then
		ModificationTimeUniversal = CurrentUniversalDate();
	EndIf;
	
	ModifiedAt = FileInformation.ModifiedAt;
	If Not ValueIsFilled(ModifiedAt)
		OR ToUniversalTime(ModifiedAt) > ModificationTimeUniversal Then
		ModifiedAt = CurrentSessionDate();
	EndIf;
	
	FileFunctionsServiceClientServer.CheckFileExtensionForImporting(FileInformation.ExtensionWithoutDot);
	
	CurrentVersionSize = 0;
	BinaryData = Undefined;
	CurrentVersionFileStorageType = Enums.FileStorageTypes.InInfobase;
	CurrentVersionVolume = Undefined;
	CurrentVersionPathToFile = Undefined;
	
	VersionRefForSizeComparing = VersionRef;
	If VersionRef <> Undefined Then
		VersionRefForSizeComparing = VersionRef;
	Else
		VersionRefForSizeComparing = FileRef.CurrentVersion;
	EndIf;
	
	PrevVersionEncoding = GetFileVersionEncoding(VersionRefForSizeComparing);
	
	AttributesStructure = CommonUse.ObjectAttributesValues(VersionRefForSizeComparing, 
		"Size, FileStorageType, Volume, PathToFile");
	CurrentVersionSize = AttributesStructure.Size;
	CurrentVersionFileStorageType = AttributesStructure.FileStorageType;
	CurrentVersionVolume = AttributesStructure.Volume;
	CurrentVersionPathToFile = AttributesStructure.PathToFile;
	
	FileStorage = Undefined;
	If FileInformation.Size = CurrentVersionSize Then
		PreviousVersionBinaryData = Undefined;
		
		If CurrentVersionFileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
			If Not CurrentVersionVolume.IsEmpty() Then
				FullPath = FileFunctionsService.FullPathOfVolume(CurrentVersionVolume) + CurrentVersionPathToFile; 
				PreviousVersionBinaryData = New BinaryData(FullPath);
			EndIf;
		Else
			FileStorage = GetFileStorageFromInformationBase(VersionRefForSizeComparing);
			PreviousVersionBinaryData = FileStorage.Get();
		EndIf;
		
		BinaryData = GetFromTempStorage(FileInformation.FileTemporaryStorageAddress);
		
		If PreviousVersionBinaryData = BinaryData Then
			Return Undefined; // The file is not binary changed - return False.
		EndIf;
	EndIf;
	
	OldStorageType = Undefined;
	VersionBlocked = False;
	Version = Undefined;
	
	If FileInformation.StoreVersions Then
		Version = Catalogs.FileVersions.CreateItem();
		Version.ParentalVersion = FileRef.CurrentVersion;
		Version.VersionNumber = FindMaximumVersionNumber(FileRef) + 1;
	Else
		
		If VersionRef = Undefined Then
			Version = FileRef.CurrentVersion.GetObject();
		Else
			Version = VersionRef.GetObject();
		EndIf;
	
		LockDataForEdit(Version.Ref, , FormUUID);
		VersionBlocked = True;
		
		// Remove the file from the disk - we replace it by the new one.
		If Version.FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
			If Not Version.Volume.IsEmpty() Then
				FullPath = FileFunctionsService.FullPathOfVolume(Version.Volume) + Version.PathToFile; 
				FileOnDrive = New File(FullPath);
				If FileOnDrive.Exist() Then
					FileOnDrive.SetReadOnly(False);
					DeleteFiles(FullPath);
				EndIf;
				PathWithSubdirectory = FileOnDrive.Path;
				FileArrayInDirectory = FindFiles(PathWithSubdirectory, "*.*");
				If FileArrayInDirectory.Count() = 0 Then
					DeleteFiles(PathWithSubdirectory);
				EndIf;
			EndIf;
		EndIf;
		
	EndIf;
	
	Version.Owner = FileRef;
	Version.Author = Users.CurrentUser();
	Version.ModificationDateUniversal = ModificationTimeUniversal;
	Version.FileModificationDate = ModifiedAt;
	Version.CreationDate = CurrentSessionDate();
	Version.Size = FileInformation.Size;
	Version.FullDescr = FileInformation.BaseName;
	Version.Comment = FileInformation.Comment;
	Version.Extension = CommonUseClientServer.ExtensionWithoutDot(FileInformation.ExtensionWithoutDot);
	
	TypeOfFileStorage = FileFunctionsService.TypeOfFileStorage();
	Version.FileStorageType = TypeOfFileStorage;
	
	If BinaryData = Undefined Then
		BinaryData = GetFromTempStorage(FileInformation.FileTemporaryStorageAddress);
	EndIf;
	
	If TypeOfFileStorage = Enums.FileStorageTypes.InInfobase Then
		
		FileStorage = New ValueStorage(BinaryData);
			
		If Version.Size = 0 Then
			FileBinaryData = FileStorage.Get();
			Version.Size = FileBinaryData.Size();
			
			FileFunctionsServiceClientServer.CheckFileSizeForImporting(Version);
		EndIf;
		
		// clear fields
		Version.PathToFile = "";
		Version.Volume = Catalogs.FileStorageVolumes.EmptyRef();
	Else // storage on the disk
		
		If Version.Size = 0 Then
			Version.Size = BinaryData.Size();
			FileFunctionsServiceClientServer.CheckFileSizeForImporting(Version);
		EndIf;
		
		FileEncrypted = False;
		If FileInformation.Encrypted <> Undefined Then
			FileEncrypted = FileInformation.Encrypted;
		EndIf;	
		
		Information = FileFunctionsService.AddFileToVolume(BinaryData,
			ModificationTimeUniversal, FileInformation.BaseName, Version.Extension,
			Version.VersionNumber, FileEncrypted); 
		Version.Volume = Information.Volume;
		Version.PathToFile = Information.PathToFile;
		FileStorage = New ValueStorage(Undefined); // clear ValueStorage
		
	EndIf;
	
	If FileInformation.TextTemporaryStorageAddress <> Undefined Then
		If FileFunctionsService.ExtractFileTextsAtServer() Then
			Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		Else
			Text = FileFunctionsService.GetStringFromTemporaryStorage(FileInformation.TextTemporaryStorageAddress);
			Version.TextStorage = New ValueStorage(Text);
			Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		EndIf;
	Else
		Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	EndIf;
	
	If FileInformation.NewTextExtractionStatus <> Undefined Then
		Version.TextExtractionStatus = FileInformation.NewTextExtractionStatus;
	EndIf;

	If Version.Size = 0 Then
		If TypeOfFileStorage = Enums.FileStorageTypes.InInfobase Then
			FileBinaryData = FileStorage.Get();
			Version.Size = FileBinaryData.Size();
		EndIf;
	EndIf;
	
	If FileInformation.Encrypted <> Undefined Then
		Version.Encrypted = FileInformation.Encrypted;
	EndIf;
	
	Version.Write();
	
	If TypeOfFileStorage = Enums.FileStorageTypes.InInfobase Then
		WriteFileToInformationBase(Version.Ref, FileStorage);
	EndIf;
	
	If VersionBlocked Then
		UnlockDataForEdit(Version.Ref, FormUUID);
	EndIf;
	
	WriteFileVersionEncoding(Version.Ref, PrevVersionEncoding);

	If IsRightSave Then
		URLFile = GetURL(FileRef);
		UserWorkHistory.Add(URLFile);
	EndIf;
	
	Return Version.Ref;
	
EndFunction

// It updates or creates a file version and removes the lock. 
//
// Parameters:
//   FileData                          - Structure - structure with file data.
//   FileInformation                   - Structure - see FileOperationsClientServer.FileInfo, in FileWithVersion mode.
//   NotChangeRecordInWorkingDirectory - Boolean   - do not change the record in the FilesInWorkingDirectory info register.
//   FullPathToFile                    - String    - It is specified if DoNotChangeRecordInWorkingDirectory = False.
//   UserWorkingDirectory              - String    - It is specified if DoNotChangeRecordInWorkingDirectory = False.
//   FormUUID                          - UUID      - form unique ID.
//
// Returns:
//   Boolean - True if the version creation is completed (and the file is binary changed).
//
Function SaveChangesAndReleaseFile(FileData, FileInformation,
	NotChangeRecordInWorkingDirectory, FullPathToFile, UserWorkingDirectory, 
	FormUUID = Undefined) Export
	
	FileDataCurrent = FileData(FileData.Ref);
	If Not FileDataCurrent.CurrentUserIsEditing Then
		Raise NStr("en='File is not in use by the current user';ru='Файл не занят текущим пользователем'");
	EndIf;
	
	VersionIsNotCreated = False;
	
	BeginTransaction();
	Try
		PreviousVersion = FileData.CurrentVersion;
		FileInformation.Encrypted = FileData.Encrypted;
		NewVersion = UpdateFileVersion(FileData.Ref, FileInformation,, FormUUID);
		If NewVersion <> Undefined Then
			If FileInformation.StoreVersions Then
				RefreshVersionInFile(FileData.Ref, NewVersion, FileInformation.TextTemporaryStorageAddress, FormUUID);
			Else
				UpdateTextInFile(FileData.Ref, FileInformation.TextTemporaryStorageAddress, FormUUID);
			EndIf;
			FileData.CurrentVersion = NewVersion;
		EndIf;
		
		ReleaseFile(FileData, FormUUID);
		
		If FileInformation.Encoding <> Undefined Then
			If Not ValueIsFilled(GetFileVersionEncoding(FileData.CurrentVersion)) Then
				WriteFileVersionEncoding(FileData.CurrentVersion, FileInformation.Encoding);
			EndIf;
		EndIf;
		
		If NewVersion <> Undefined AND Not CommonUseClientServer.ThisIsWebClient() AND Not NotChangeRecordInWorkingDirectory Then
			DeleteVersionAndRecordFileInformationToRegister(PreviousVersion, NewVersion,
				FullPathToFile, UserWorkingDirectory, FileData.OwnerWorkingDirectory <> "");
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return NewVersion <> Undefined;
	
EndFunction

// It receives the file data, updates or creates the file version and removes the lock.
// It is necessary for cases if there is no FileData on the client (for saving client server calls).
//
// Parameters:
//   FileRef           - CatalogRef.Files - file where the version is updated.
//   FileInformation   - Structure - see FileOperationsClientServer.FileInfo, in FileWithVersion mode.
//   FullPathToFile         - String
//   UserWorkingDirectory   - String 
//   FormUUID               - UUID - form unique ID.
//
// Returns:
//   Structure - with properties:
//     * Successfully - Boolean   - True if the version creation is completed (and the file is binary changed).
//     * FileData     - Structure - structure with file data.
//
Function SaveChangesAndReleaseFileByLink(FileRef, FileInformation, 
	FullPathToFile, UserWorkingDirectory, FormUUID = Undefined) Export
	
	FileData = FileData(FileRef);
	VersionCreated = SaveChangesAndReleaseFile(FileData, FileInformation, False, FullPathToFile, UserWorkingDirectory,
		FormUUID);
	Return New Structure("Successfully,FileData", VersionCreated, FileData);
	
EndFunction

// It is intended to record file changes without its release.
//
// Parameters:
//   FileData                          - Structure - structure with file data.
//   FileInformation                   - Structure - see FileOperationsClientServer.FileInfo, in FileWithVersion mode.
//   NotChangeRecordInWorkingDirectory - Boolean   - do not change the record in the FilesInWorkingDirectory info register.
//   RelativePathToFile                - String    - relative path without path of
//                                                   the working directory, for example
//                                                   "A1/Order.doc "; it is specified if DoNotChangeRecordInWorkingDirectory = False.
//   FullPathToFile                    - String    - path on client in the working
//                                                   directory; it is specified if DoNotChangeRecordInWorkingDirectory = False.
//   InOwnerWorkingDirectory           - Boolean   - The file is located in the owner working directory.
//   FormUUID                          - UUID      - form unique ID.
//
// Returns:
//   Boolean  - True if the version creation is completed (and the file is binary changed).
//
Function SaveFileChanges(FileRef, FileInformation, 
	NotChangeRecordInWorkingDirectory, RelativePathToFile, FullPathToFile, InOwnerWorkingDirectory,
	FormUUID = Undefined) Export
	
	FileDataCurrent = FileData(FileRef);
	If Not FileDataCurrent.CurrentUserIsEditing Then
		Raise NStr("en='File is not in use by the current user';ru='Файл не занят текущим пользователем'");
	EndIf;
	
	VersionIsNotCreated = False;
	CurrentVersion = FileDataCurrent.CurrentVersion;
	
	BeginTransaction();
	Try
		
		OldVersion = FileRef.CurrentVersion;
		FileInformation.Encrypted = FileDataCurrent.Encrypted;
		NewVersion = UpdateFileVersion(FileRef, FileInformation, ,	FormUUID);
		
		If NewVersion <> Undefined Then
			CurrentVersion = NewVersion;
			If FileInformation.StoreVersions Then
				RefreshVersionInFile(FileRef, NewVersion, FileInformation.TextTemporaryStorageAddress, FormUUID);
			Else
				UpdateTextInFile(FileRef, FileInformation.TextTemporaryStorageAddress, FormUUID);
			EndIf;
		
			If Not CommonUseClientServer.ThisIsWebClient() AND Not NotChangeRecordInWorkingDirectory Then
				DeleteFromRegister(OldVersion);
				WriteFullFileNameToRegister(NewVersion, RelativePathToFile, False, InOwnerWorkingDirectory);
			EndIf;
		EndIf;
		
		If FileInformation.Encoding <> Undefined Then
			If Not ValueIsFilled(GetFileVersionEncoding(CurrentVersion)) Then
				WriteFileVersionEncoding(CurrentVersion, FileInformation.Encoding);
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return NewVersion <> Undefined;
	
EndFunction

// It gets CurrentUserIsEditing - in the privileged mode.
// Parameters:
//  VersionRef  - CatalogRef.FileVersions - file version.
//
// Returns:
//   Boolean - True if the current user edits the file.
//
Function GetCurrentUserIsEditing(VersionRef) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Files.IsEditing AS IsEditing
	|FROM
	|	Catalog.Files AS Files
	|		INNER JOIN Catalog.FileVersions AS FileVersions
	|		BY (TRUE)
	|WHERE
	|	FileVersions.Ref = &Version
	|	AND Files.Ref = FileVersions.Owner";
	
	Query.Parameters.Insert("Version", VersionRef);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		CurrentUserIsEditing = (Selection.IsEditing = Users.CurrentUser());
		Return CurrentUserIsEditing;
	EndIf;
	
	Return False;
	
EndFunction

// The function returns a structure containing various data of the File and version.
//
// Parameters:
//  FileOrVersionRef  - CatalogRef.Files, CatalogRef.FileVersions - file or file version.
//
// Returns:
//   Structure - structure with file data.
//
Function FileData(FileOrVersionRef) Export
	
	If TypeOf(FileOrVersionRef) = Type("CatalogRef.Files") Then
		FileRef = FileOrVersionRef;
		VersionRef = Undefined;
	Else
		FileRef = Undefined;
		VersionRef = FileOrVersionRef;
	EndIf;
	
	Query = New Query;
	If FileRef <> Undefined Then
		
		Query.Text =
		"SELECT
		|	Files.Ref AS Ref,
		|	Files.Code AS Code,
		|	Files.IsEditing AS IsEditing,
		|	Files.CurrentVersion AS CurrentVersion,
		|	Files.FileOwner AS FileOwner,
		|	Files.StoreVersions AS StoreVersions,
		|	Files.DeletionMark AS DeletionMark,
		|	FileVersions.FullDescr AS FullDescr,
		|	FileVersions.Extension AS Extension,
		|	FileVersions.Size AS Size,
		|	FileVersions.VersionNumber AS VersionNumber,
		|	FileVersions.PathToFile AS PathToFile,
		|	FileVersions.Volume AS Volume,
		|	FileVersions.ModificationDateUniversal AS ModificationDateUniversal,
		|	FileVersions.Author AS Author,
		|	FileVersions.TextExtractionStatus AS TextExtractionStatus,
		|	Files.Encrypted AS Encrypted,
		|	Files.LoanDate AS LoanDate
		|FROM
		|	Catalog.Files AS Files
		|		LEFT JOIN Catalog.FileVersions AS FileVersions
		|		BY Files.CurrentVersion = FileVersions.Ref";
		
		If TypeOf(FileRef) = Type("Array") Then 
			Query.Text = Query.Text + " WHERE Files.Ref To (&File) ";
		Else
			Query.Text = Query.Text + " WHERE Files.Ref = &File ";
		EndIf;
		
		Query.Parameters.Insert("File", FileRef);
		
	Else
		
		Query.Text =
		"SELECT
		|	Files.Ref AS Ref,
		|	Files.Code AS Code,
		|	Files.IsEditing AS IsEditing,
		|	Files.CurrentVersion AS CurrentVersion,
		|	Files.FileOwner AS FileOwner,
		|	Files.StoreVersions AS StoreVersions,
		|	Files.DeletionMark AS DeletionMark,
		|	FileVersions.FullDescr AS FullDescr,
		|	FileVersions.Extension AS Extension,
		|	FileVersions.Size AS Size,
		|	FileVersions.VersionNumber AS VersionNumber,
		|	FileVersions.PathToFile AS PathToFile,
		|	FileVersions.Volume AS Volume,
		|	FileVersions.ModificationDateUniversal AS ModificationDateUniversal,
		|	FileVersions.Author AS Author,
		|	FileVersions.TextExtractionStatus AS TextExtractionStatus,
		|	Files.Encrypted AS Encrypted,
		|	Files.LoanDate AS LoanDate
		|FROM
		|	Catalog.Files AS Files
		|		INNER JOIN Catalog.FileVersions AS FileVersions
		|		BY (TRUE)
		|WHERE
		|	FileVersions.Ref = &Version
		|	AND Files.Ref = FileVersions.Owner";
		
		Query.Parameters.Insert("Version", VersionRef);
		
	EndIf;
	
	ArrayFileData = New Array;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
	
		FileData = New Structure;
		FileData.Insert("Ref", Selection.Ref);
		FileData.Insert("FileCode", Selection.Code);
		FileData.Insert("IsEditing", Selection.IsEditing);
		FileData.Insert("Owner", Selection.FileOwner);
		FileData.Insert("URL", GetURL(Selection.Ref));
		
		If VersionRef <> Undefined Then
			FileData.Insert("Version", VersionRef);
		Else
			FileData.Insert("Version", Selection.CurrentVersion);
		EndIf;	

		FileData.Insert("CurrentVersion", Selection.CurrentVersion);
		
		KeyStructure = New Structure("FileVersion", FileData.CurrentVersion);
		RecordKey = InformationRegisters.VersionStoredFiles.CreateRecordKey(KeyStructure);
		CurrentVersionURL = GetURL(RecordKey, "StoredFile");
		FileData.Insert("CurrentVersionURL", CurrentVersionURL);
		
		CurrentVersionEncoding = GetFileVersionEncoding(FileData.CurrentVersion);
		FileData.Insert("CurrentVersionEncoding", CurrentVersionEncoding);
		
		FileData.Insert("Size", Selection.Size);
		FileData.Insert("VersionNumber", Selection.VersionNumber);
		FileData.Insert("ModificationDateUniversal", Selection.ModificationDateUniversal);
		FileData.Insert("Extension", Selection.Extension);
		FileData.Insert("FullDescrOfVersion", TrimAll(Selection.FullDescr));
		FileData.Insert("StoreVersions", Selection.StoreVersions);
		FileData.Insert("DeletionMark", Selection.DeletionMark);
		FileData.Insert("CurrentVersionAuthor", Selection.Author);
		FileData.Insert("Encrypted", Selection.Encrypted);
		FileData.Insert("LoanDate", Selection.LoanDate);
		
		If FileData.Encrypted Then
			ArrayOfEncryptionCertificates = GetArrayOfEncryptionCertificates(FileData.Ref);
			FileData.Insert("ArrayOfEncryptionCertificates", ArrayOfEncryptionCertificates);
		EndIf;
		
		ForRead = FileData.IsEditing <> Users.CurrentUser();
		FileData.Insert("ForRead", ForRead);
		
		InWorkingDirectoryForRead = True;
		InOwnerWorkingDirectory = False;
		DirectoryName = CommonUse.CommonSettingsStorageImport("LocalFilesCache", "PathToFilesLocalCache");
		If DirectoryName = Undefined Then
			DirectoryName = "";
		EndIf;

		If VersionRef <> Undefined Then
			FullFileNameInWorkingDirectory = GetFullFileNameFromRegister(VersionRef, DirectoryName, InWorkingDirectoryForRead, InOwnerWorkingDirectory);
		Else
			FullFileNameInWorkingDirectory = GetFullFileNameFromRegister(Selection.CurrentVersion, DirectoryName, InWorkingDirectoryForRead, InOwnerWorkingDirectory);
		EndIf;

		FileData.Insert("FullFileNameInWorkingDirectory", FullFileNameInWorkingDirectory);
		FileData.Insert("InWorkingDirectoryForRead", InWorkingDirectoryForRead);
		FileData.Insert("OwnerWorkingDirectory", "");
		
		CurrentUserIsEditing = (FileData.IsEditing = Users.CurrentUser());
		FileData.Insert("CurrentUserIsEditing", CurrentUserIsEditing);
		
		TextExtractionStatusString = "NotExtracted";
		If Selection.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted Then
			TextExtractionStatusString = "NotExtracted";
		ElsIf Selection.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted Then
			TextExtractionStatusString = "Extracted";
		ElsIf Selection.TextExtractionStatus = Enums.FileTextExtractionStatuses.ExtractFailed Then
			TextExtractionStatusString = "ExtractFailed";
		EndIf;
		FileData.Insert("TextExtractionStatus", TextExtractionStatusString);
		
		ArrayFileData.Add(FileData);
		
	EndDo;
	
	// If the array was transferred - We return the array
	If TypeOf(FileRef) = Type("Array") Then 
		Return ArrayFileData;
	EndIf;

	If ArrayFileData.Count() > 0 Then 
		Return ArrayFileData[0];
	Else
		Return New Structure;
	EndIf;
	
EndFunction

// It creates both a file in IB and a version.
//
// Parameters:
//   Owner           - CatalogRef.FileFolders, AnyRef - It will be set to
//                     the FileOwner attribute for the created file.
//   FileInformation - Structure - see FileOperationsClientServer.FileInfo, in FileWithVersion mode.
//
// Returns:
//    CatalogRef.Files - created file.
//
Function CreateFileWithVersion(FileOwner, FileInformation) Export
	
	BeginTransaction();
	Try
	
		// Create a file card in DB.
		FileRef = CreateFile(FileOwner, FileInformation);
		// Create a version of the saved file to be saved in the File card.
		Version = Create_Version(FileRef, FileInformation);
		// Insert the version reference to the file card.
		RefreshVersionInFile(FileRef, Version, FileInformation.TextTemporaryStorageAddress);
		
		If FileInformation.Encoding <> Undefined Then
			WriteFileVersionEncoding(Version, FileInformation.Encoding);
		EndIf;
		
		IsRightSave = AccessRight("SaveUserData", Metadata);
		If FileInformation.WriteIntoHistory AND IsRightSave Then
			URLFile = GetURL(FileRef);
			UserWorkHistory.Add(URLFile);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	FileOperationsOverridable.OnFileCreate(FileRef);
	
	Return FileRef;
	
EndFunction

// It receives file data and makes a loan (checkout) - to save client server calls we moved GetFileData and LockFile to one function.
// Parameters:
//  FileRef     - CatalogRef.Files - file.
//  FileData    - Structure - structure with file data.
//  ErrorString - String used to return the error reason in case of failure
//                 (for example, the file is busy by the other user).
//  UUID - form unique ID.
//
// Returns:
//   Boolean  - whether the operation is successfully completed.
//
Function GetFileDataAndLockFile(FileRef, FileData, ErrorString, UUID = Undefined) Export

	FileData = FileData(FileRef);

	ErrorString = "";
	If Not FileOperationsClientServer.IfYouCanLockFile(FileData, ErrorString) Then
		Return False;
	EndIf;	
	
	If FileData.IsEditing.IsEmpty() Then
		
		ErrorString = "";
		If Not LockFile(FileData, ErrorString, UUID) Then 
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

// It receives FileData for files and places to FileDataArray.
//  FilesArray - array of references to files.
//  ArrayFileData - structure array with the file data.
//
Procedure GetDataForArrayOfFiles(Val FilesArray, ArrayFileData) Export
	
	For Each File IN FilesArray Do
		FileData = FileData(File);
		ArrayFileData.Add(FileData);
	EndDo;
	
EndProcedure

// It receives file data for opening and making loan (checkout) - to save the client server calls we moved FileDataForOpening and LockFile to one function.
// Parameters:
//  FileRef     - CatalogRef.Files - file.
//  FileData    - Structure - structure with file data.
//  ErrorString - String used to return the error reason in case of failure
//                 (for example, the file is busy by the other user).
//  UUID        - form unique ID.
//  OwnerWorkingDirectory - String - working directory of the file owner.
//
// Returns:
//   Boolean  - whether the operation is successfully completed.
//
Function GetFileDataForOpeningAndLockFile(FileRef,
	FileData, ErrorString, UUID = Undefined, OwnerWorkingDirectory = Undefined) Export

	FileData = FileDataForOpening(FileRef, UUID, OwnerWorkingDirectory);

	ErrorString = "";
	If Not FileOperationsClientServer.IfYouCanLockFile(FileData, ErrorString) Then
		Return False;
	EndIf;
	
	If FileData.IsEditing.IsEmpty() Then
		
		ErrorString = "";
		If Not LockFile(FileData, ErrorString, UUID) Then 
			Return False;
		EndIf;
	EndIf;
	
	Return True;
EndFunction

// It executes MoveToTemporaryStorage (if a file is stored on the disk) and returns the required reference.
// Parameters:
// VersionRef - file version.
//  FormID - form unique ID.
//
// Returns:
//   String  - navigation link in the temporary storage.
//
Function GetURLForOpening(VersionRef, FormID = Undefined) Export
	
	Address = "";
	
	FileStorageType = VersionRef.FileStorageType;
	
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
		If Not VersionRef.Volume.IsEmpty() Then
			FullPath = FileFunctionsService.FullPathOfVolume(VersionRef.Volume) + VersionRef.PathToFile; 
			Try
				BinaryData = New BinaryData(FullPath);
				Address = PutToTempStorage(BinaryData, FormID);
			Except
				// Record in the event log.
				ErrorInfo = GenerateObtainingErrorTextFileFromVolumeForAdministrator(
					ErrorInfo(), VersionRef.Owner);
				
				WriteLogEvent(
					NStr("en='Files.File opening';ru='Файлы.Открытие файла'",
					     CommonUseClientServer.MainLanguageCode()),
					EventLogLevel.Error,
					Metadata.Catalogs.Files,
					VersionRef.Owner,
					ErrorInfo);
				
				Raise FileFunctionsServiceClientServer.ErrorFileIsNotFoundInFileStorage(
					VersionRef.FullDescr + "." + VersionRef.Extension);
			EndTry;
		EndIf;
	Else
		KeyStructure = New Structure("FileVersion", VersionRef);
		RecordKey = InformationRegisters.VersionStoredFiles.CreateRecordKey(KeyStructure);
		Address = GetURL(RecordKey, "StoredFile");
	EndIf;
	
	Return Address;
	
EndFunction

// It executes FileData and identifies OwnerWorkingDirectory.
//
// Parameters:
//  FileOrVersionRef     - CatalogRef.Files, CatalogRef.FileVersions - file or file version.
//  OwnerWorkingDirectory - String - the file owner working directory is returned in it.
//
// Returns:
//   Structure - structure with file data.
//
Function FileDataAndWorkingDirectory(FileOrVersionRef, OwnerWorkingDirectory = Undefined) Export
	
	FileData = FileData(FileOrVersionRef);
	If TypeOf(FileOrVersionRef) = Type("CatalogRef.Files") Then
		FileRef = FileOrVersionRef;
		VersionRef = Undefined;
	Else
		FileRef = Undefined;
		VersionRef = FileOrVersionRef;
	EndIf;
	
	If OwnerWorkingDirectory = Undefined Then
		OwnerWorkingDirectory = FolderWorkingDirectory(FileData.Owner);
	EndIf;
	FileData.Insert("OwnerWorkingDirectory", OwnerWorkingDirectory);
	
	If FileData.OwnerWorkingDirectory <> "" Then
		
		FullFileNameInWorkingDirectory = "";
		DirectoryName = ""; // Path to the local cache is not used here.
		InWorkingDirectoryForRead = True; // not used 
		InOwnerWorkingDirectory = True;
		
		If VersionRef <> Undefined Then
			FullFileNameInWorkingDirectory = GetFullFileNameFromRegister(VersionRef, DirectoryName, InWorkingDirectoryForRead, InOwnerWorkingDirectory);
		Else
			FullFileNameInWorkingDirectory = GetFullFileNameFromRegister(FileRef.CurrentVersion, DirectoryName, InWorkingDirectoryForRead, InOwnerWorkingDirectory);
		EndIf;	
		
		FileData.Insert("FullFileNameInWorkingDirectory", FullFileNameInWorkingDirectory);
	EndIf;
	
	Return FileData;
EndFunction

// It performs ReceiveFileData and calculates the number of the file versions.
// Parameters:
//  FileRef  - CatalogRef.Files - file.
//
// Returns:
//   Structure - structure with file data.
//
Function GetFileDataAndNumberOfVersions(FileRef) Export
	
	FileData = FileData(FileRef);
	CountVersions = GetNumberOfVersions(FileRef);
	FileData.Insert("CountVersions", CountVersions);
	
	Return FileData;
	
EndFunction

// It generates the error text to move to the event log.
// Parameters:
//  FunctionErrorInfo  - ErrorInfo
//  FileRef  - CatalogRef.Files - file.
//
// Returns:
//   String - error description
//
Function GenerateObtainingErrorTextFileFromVolumeForAdministrator(FunctionErrorInfo, FileRef) Export
	
	Return StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Ref to the file: ""%1"".
		|""%2"".';ru='Ссылка на файл: ""%1"".
		|""%2"".'"),
		GetURL(FileRef),
		DetailErrorDescription(FunctionErrorInfo));
	
EndFunction

// The function returns a structure containing various data of the File and version.
//
// Parameters:
//  FileVersionRef        - CatalogRef.Files, CatalogRef.FileVersions - file or file version.
//  FormID                - UUID - form unique ID.
//  OwnerWorkingDirectory - String - the file owner working directory is returned in it.
//  PreviousFileURL       - String - the file owner working directory is returned in it.
//
// Returns:
//   Structure - structure with the file data. See ReceiveFileData.
//
Function FileDataForOpening(FileOrVersionRef, FormID = Undefined,
	OwnerWorkingDirectory = Undefined, PreviousFileURL = Undefined) Export
	
	If PreviousFileURL <> Undefined Then
		If Not IsBlankString(PreviousFileURL) AND IsTempStorageURL(PreviousFileURL) Then
			DeleteFromTempStorage(PreviousFileURL);
		EndIf;
	EndIf;
	
	If TypeOf(FileOrVersionRef) = Type("CatalogRef.Files") Then
		FileRef = FileOrVersionRef;
		VersionRef = Undefined;
	Else
		FileRef = Undefined;
		VersionRef = FileOrVersionRef;
	EndIf;
	FileData = FileData(FileOrVersionRef);
	
	If OwnerWorkingDirectory = Undefined Then
		OwnerWorkingDirectory = FolderWorkingDirectory(FileData.Owner);
	EndIf;
	FileData.Insert("OwnerWorkingDirectory", OwnerWorkingDirectory);
	
	If FileData.OwnerWorkingDirectory <> "" Then
		FileName = CommonUseClientServer.GetNameWithExtention(
			FileData.FullDescrOfVersion, FileData.Extension);
		FullFileNameInWorkingDirectory = OwnerWorkingDirectory + FileName;
		FileData.Insert("FullFileNameInWorkingDirectory", FullFileNameInWorkingDirectory);
	EndIf;
	
	FileStorageType = FileData.Version.FileStorageType;
	
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive AND FileData.Version <> Undefined Then
		
		SetPrivilegedMode(True);
		
		Query = New Query;
		
		Query.Text =
		"SELECT
		|	FileVersions.PathToFile AS PathToFile,
		|	FileVersions.Volume AS Volume
		|FROM
		|	Catalog.FileVersions AS FileVersions
		|WHERE
		|	FileVersions.Ref = &Version";
		
		Query.Parameters.Insert("Version", FileData.Version);
		
		FileDataQuantity = Catalogs.FileStorageVolumes.EmptyRef();
		FileDataPathToFile = "";
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			FileDataQuantity = Selection.Volume;
			FileDataPathToFile = Selection.PathToFile;
		EndIf;
		
		If Not FileDataQuantity.IsEmpty() Then
			FullPath = FileFunctionsService.FullPathOfVolume(FileDataQuantity) + FileDataPathToFile; 
			Try
				BinaryData = New BinaryData(FullPath);
				// We work only with the current version - we get the reference in GetURLForOpening for the noncurrent one.
				FileData.CurrentVersionURL = PutToTempStorage(BinaryData, FormID);
			Except
				// Record in the event log.
				FileReference = ?(FileRef <> Undefined, FileRef, VersionRef);
				ErrorInfo = GenerateObtainingErrorTextFileFromVolumeForAdministrator(
					ErrorInfo(), FileReference);
				
				WriteLogEvent(
					NStr("en='Files.File opening';ru='Файлы.Открытие файла'",
					     CommonUseClientServer.MainLanguageCode()),
					EventLogLevel.Error,
					Metadata.Catalogs.Files,
					FileRef,
					ErrorInfo);
				
				Raise FileFunctionsServiceClientServer.ErrorFileIsNotFoundInFileStorage(
					FileData.FullDescrOfVersion + "." + FileData.Extension);
			EndTry;
		EndIf;
	EndIf;
	
	PreviousFileURL = FileData.CurrentVersionURL;
	
	Return FileData;
	
EndFunction

// Release File with data receiving.
// Parameters:
//  FileRef  - CatalogRef.Files - file.
//  FileData  - structure with file data.
//  UUID - form unique ID.
//
Procedure GetFileDataAndReleaseFile(FileRef, FileData, UUID = Undefined) Export
	
	FileData = FileData(FileRef);
	ReleaseFile(FileData, UUID);
	
EndProcedure

// To record file changes without its release.
//
// Parameters:
//   FileRef                    - Structure - structure with file data.
//   FileInformation            - Structure - see FileOperationsClientServer.FileInfo, in FileWithVersion mode.
//   RelativePathToFile         - String    - relative path without path of
//                                             the working directory, for example
//                                            "A1/Order.doc "; it is specified if DoNotChangeRecordInWorkingDirectory = False.
//   FullPathToFile             - String    - path on client in the working
//                                            directory; it is specified if DoNotChangeRecordInWorkingDirectory = False.
//   InOwnerWorkingDirectory    - Boolean    - The file is located in the owner working directory.
//   FormUUID - UUID - form unique ID.
//
// Returns:
//   Structure - with properties:
//     Data recovery executed successfully     - Boolean    - True if the version creation is completed (and the file is binary changed).
//     * FileData - Structure - structure with file data.
//
Function GetFileDataAndSaveFileChanges(FileRef, FileInformation, 
	RelativePathToFile, FullPathToFile, InOwnerWorkingDirectory,
	FormUUID = Undefined) Export
	
	FileData = FileData(FileRef);
	If Not FileData.CurrentUserIsEditing Then
		Raise NStr("en='File is not in use by the current user';ru='Файл не занят текущим пользователем'");
	EndIf;
	
	VersionCreated = SaveFileChanges(FileRef, FileInformation, 
		False, RelativePathToFile, FullPathToFile, InOwnerWorkingDirectory,
		FormUUID);
	Return New Structure("Successfully,FileData", VersionCreated, FileData);	
	
EndFunction

// It receives synthetic folder working directory on the disk (it can be moved from the parent folder).
// Parameters:
//  FolderRef  - CatalogRef.FileFolders - file owner.
//
// Returns:
//   String  - working directory.
//
Function FolderWorkingDirectory(FolderRef) Export
	
	If TypeOf(FolderRef) <> Type("CatalogRef.FileFolders") Then
		Return ""
	EndIf;
	
	SetPrivilegedMode(True);
	
	WorkingDirectory = "";
	
	// Prepare filter structure by measurements.
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Folder", FolderRef);
	FilterStructure.Insert("User", Users.CurrentUser());
	
	// Get the structure with data resources records.
	StructureOfResources = InformationRegisters.WorkingFileDirectories.Get(FilterStructure);
	
	// Get path from the register
	WorkingDirectory = StructureOfResources.Path;
	
	If Not IsBlankString(WorkingDirectory) Then
		// Add a slash at the end in case it is absent.
		WorkingDirectory = CommonUseClientServer.AddFinalPathSeparator(WorkingDirectory);
	EndIf;
	
	Return WorkingDirectory;
	
EndFunction

// It saves the folder working directory in the info register.
// Parameters:
//  FolderRef  - CatalogRef.FileFolders - file owner.
//  OwnerWorkingDirectory - String - folder working directory.
//
Procedure SaveFolderWorkingDirectory(FolderRef, FolderWorkingDirectory) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.WorkingFileDirectories.CreateRecordSet();
	
	RecordSet.Filter.Folder.Set(FolderRef);
	RecordSet.Filter.User.Set(Users.CurrentUser());
	
	NewRecord = RecordSet.Add();
	NewRecord.Directory = FolderRef;
	NewRecord.User = Users.CurrentUser();
	NewRecord.Path = FolderWorkingDirectory;
	
	RecordSet.Write();
	
EndProcedure

// It saves the working directory in the
// folder in the info register and replaces the path in the FilesInWorkingDirectory info register.
//
// Parameters:
//  FolderRef  - CatalogRef.FileFolders - file owner.
//  FolderWorkingDirectory - String - folder working directory.
//  DirectoryNameFormerValue - String - previous value of the working directory.
//
Procedure SaveFolderWorkingDirectoryAndChangePathesInRegister(FolderRef,
                                                        FolderWorkingDirectory,
                                                        DirectoryNameFormerValue) Export
	
	SaveFolderWorkingDirectory(FolderRef, FolderWorkingDirectory);
	
	// below replace the paths in the FilesInWorkingDirectory info register.
	SetPrivilegedMode(True);
	
	ListForReplacement = New Array;
	CurrentUser = Users.CurrentUser();
	
	// We find record in the info register for our each record - we take the Version and IsEditing fields from there.
	QueryOnTable = New Query;
	QueryOnTable.SetParameter("User", CurrentUser);
	QueryOnTable.SetParameter("Path", DirectoryNameFormerValue + "%");
	QueryOnTable.Text =
	"SELECT
	|	FilesInWorkingDirectory.Version AS Version,
	|	FilesInWorkingDirectory.Path AS Path,
	|	FilesInWorkingDirectory.Size AS Size,
	|	FilesInWorkingDirectory.PlacementDateIntoWorkingDirectory AS PlacementDateIntoWorkingDirectory,
	|	FilesInWorkingDirectory.ForRead AS ForRead
	|FROM
	|	InformationRegister.FilesInWorkingDirectory AS FilesInWorkingDirectory
	|WHERE
	|	FilesInWorkingDirectory.User = &User
	|	AND FilesInWorkingDirectory.InOwnerWorkingDirectory = TRUE
	|	AND FilesInWorkingDirectory.Path LIKE &Path";
	
	QueryResult = QueryOnTable.Execute(); 
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		NewPath = Selection.Path;
		NewPath = StrReplace(NewPath, DirectoryNameFormerValue, FolderWorkingDirectory);
		
		RecordStructure = New Structure;
		RecordStructure.Insert("Version",                       Selection.Version);
		RecordStructure.Insert("Path",                         NewPath);
		RecordStructure.Insert("Size",                       Selection.Size);
		RecordStructure.Insert("PlacementDateIntoWorkingDirectory", Selection.PlacementDateIntoWorkingDirectory);
		RecordStructure.Insert("ForRead",                     Selection.ForRead);
		
		ListForReplacement.Add(RecordStructure);
		
	EndDo;
	
	For Each RecordStructure IN ListForReplacement Do
		
		InOwnerWorkingDirectory = True;
		WriteRecordStructureIntoRegister(
			RecordStructure.Version,
			RecordStructure.Path,
			RecordStructure.Size,
			RecordStructure.PlacementDateIntoWorkingDirectory,
			RecordStructure.ForRead,
			InOwnerWorkingDirectory);
		
	EndDo;
	
EndProcedure

// Write again after changing the path - with the same values of other fields.
// Parameters:
//  Version - CatalogRef.FileVersions - version.
//  Path - String - relative path inside the working directory.
//  Size  - file size in bytes.
//  PlacementDateIntoWorkingDirectory - Date - date of file moving to the working directory.
//  ForRead - Boolean - File is placed for reading.
//  InOwnerWorkingDirectory - Boolean - file in the owner working directory (not in the home working directory).
//
Procedure WriteRecordStructureIntoRegister(Version,
                                          Path,
                                          Size,
                                          PlacementDateIntoWorkingDirectory,
                                          ForRead,
                                          InOwnerWorkingDirectory) Export
	
	SetPrivilegedMode(True);
	
	// Create record set
	RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();
	
	RecordSet.Filter.Version.Set(Version);
	RecordSet.Filter.User.Set(Users.CurrentUser());

	NewRecord = RecordSet.Add();
	NewRecord.Version = Version;
	NewRecord.Path = Path;
	NewRecord.Size = Size;
	NewRecord.PlacementDateIntoWorkingDirectory = PlacementDateIntoWorkingDirectory;
	NewRecord.User = Users.CurrentUser();

	NewRecord.ForRead = ForRead;
	NewRecord.InOwnerWorkingDirectory = InOwnerWorkingDirectory;
	
	RecordSet.Write();
	
EndProcedure

// It clears the folder working directory in the info register.
// Parameters:
//  FolderRef  - CatalogRef.FileFolders - file owner.
//
Procedure ClearWorkingDirectory(FolderRef) Export
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.WorkingFileDirectories.CreateRecordSet();
	
	RecordSet.Filter.Folder.Set(FolderRef);
	RecordSet.Filter.User.Set(Users.CurrentUser());
	
	// Do not add records in the set - to erase all.
	RecordSet.Write();
	
	// For subordinate folders clear working directories.
	Query = New Query;
	Query.Text =
	"SELECT
	|	FileFolders.Ref AS Ref
	|FROM
	|	Catalog.FileFolders AS FileFolders
	|WHERE
	|	FileFolders.Parent = &Refs";
	
	Query.SetParameter("Ref", FolderRef);
	
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		ClearWorkingDirectory(Selection.Ref);
	EndDo;
	
EndProcedure

// It finds a record in the FilesInWorkingDirectory info register by the path of the file on the disk (relative).
//
// Parameters:
//  FileName - String - attachment file name with the relative way (without the path to the working directory).
//
// Returns:
//  Structure with properties:
//    Version            - CatalogRef.FileVersions - found version.
//    DateSpaces     - Date of file moving to the working directory.
//    Owner          - Refs - file owner.
//    VersionNumber       - Number - version number.
//    RegisterForRead - Boolean - ForReading resource value.
//    InRegisterFileCode - Number for the file code to be placed here.
//    InFolder    - CatalogRef.FileFolders - file folder.
//
Function FindInRegisterByPath(FileName) Export
	
	SetPrivilegedMode(True);
	
	FoundProperties = New Structure;
	FoundProperties.Insert("FileIsInRegister", False);
	FoundProperties.Insert("Version", Catalogs.FileVersions.GetRef());
	FoundProperties.Insert("DateSpaces");
	FoundProperties.Insert("Owner");
	FoundProperties.Insert("VersionNumber");
	FoundProperties.Insert("RegisterForRead");
	FoundProperties.Insert("InRegisterFileCode");
	FoundProperties.Insert("InFolder");
	
	// We find the record in the info register for each one based on the path - we take the field from there.
	// Version and Size and PlacementDateIntoWorkingDirectory
	QueryOnTable = New Query;
	QueryOnTable.SetParameter("FileName", FileName);
	QueryOnTable.SetParameter("User", Users.CurrentUser());
	QueryOnTable.Text =
	"SELECT
	|	FilesInWorkingDirectory.Version AS Version,
	|	FilesInWorkingDirectory.PlacementDateIntoWorkingDirectory AS DateSpaces,
	|	FilesInWorkingDirectory.ForRead AS RegisterForRead,
	|	FilesInWorkingDirectory.Version.Owner AS Owner,
	|	FilesInWorkingDirectory.Version.VersionNumber AS VersionNumber,
	|	FilesInWorkingDirectory.Version.Owner.Code AS InRegisterFileCode,
	|	FilesInWorkingDirectory.Version.Owner.FileOwner AS InFolder
	|FROM
	|	InformationRegister.FilesInWorkingDirectory AS FilesInWorkingDirectory
	|WHERE
	|	FilesInWorkingDirectory.Path = &FileName
	|	AND FilesInWorkingDirectory.User = &User";
	
	QueryResult = QueryOnTable.Execute(); 
	
	If Not QueryResult.IsEmpty() Then
		FoundProperties.FileIsInRegister = True;
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(FoundProperties, Selection);
	EndIf;
	
	Return FoundProperties;
	
EndFunction

// It returns the current user ID from the server to the client.
// Returns:
//   UUID  - Unique identifier of the current user.
//
Function SessionParametersCurrentUserID() Export
	
	Return Users.CurrentUser().UUID();
	
EndFunction

// It finds FileVersion data in the FilesInWorkingDirectory info register (path to the version file
// in the working directory and status - for reading or editing).
// Parameters:
//  Version - CatalogRef.FileVersions - version.
//  DirectoryName - working directory path.
//  InWorkingDirectoryForRead - Boolean - File is placed for reading.
//  InOwnerWorkingDirectory - Boolean - file in the owner working directory (not in the home working directory).
//
Function GetFullFileNameFromRegister(Version,
                                         DirectoryName,
                                         InWorkingDirectoryForRead,
                                         InOwnerWorkingDirectory) Export
	
	SetPrivilegedMode(True);
	
	FullFileName = "";
	
	// Prepare filter structure by measurements.
	FilterStructure = New Structure;
	FilterStructure.Insert("Version", Version.Ref);
	FilterStructure.Insert("User", Users.CurrentUser());
	   
	// Get the structure with data resources records.
	StructureOfResources = InformationRegisters.FilesInWorkingDirectory.Get(FilterStructure);
	   
	// Get path from the register
	FullFileName = StructureOfResources.Path;
	InWorkingDirectoryForRead = StructureOfResources.ForRead;
	InOwnerWorkingDirectory = StructureOfResources.InOwnerWorkingDirectory;
	If FullFileName <> "" AND InOwnerWorkingDirectory = False Then
		FullFileName = DirectoryName + FullFileName;
	EndIf;
	
	Return FullFileName;
	
EndFunction

// It finds FileVersions data in the FilesInWorkingDirectory info register (path to the file version in the working directory).
// Parameters:
//  Refs  - CatalogRef.FileVersions - file version.
//
// Returns:
//   String - name with the path in the working directory.
//
Function GetFileNameFromRegister(Refs) Export
	
	SetPrivilegedMode(True);
	
	FullFileName = "";
	
	// Prepare filter structure by measurements.
	FilterStructure = New Structure;
	FilterStructure.Insert("Version", Refs);
	FilterStructure.Insert("User", Users.CurrentUser());
	   
	// Get the structure with data resources records.
	StructureOfResources = InformationRegisters.FilesInWorkingDirectory.Get(FilterStructure);
	   
	// Get path from the register
	FullFileName = StructureOfResources.Path;
	
	Return FullFileName;
	
EndFunction

// Write info of the file path to the FilesInWorkingDirectory info register.
// Parameters:
//  CurrentVersion - CatalogRef.FileVersions - version.
//  FullFileName - name with the path in the working directory.
//  ForRead - Boolean - File is placed for reading.
//  InOwnerWorkingDirectory - Boolean - file in the owner working directory (not in the home working directory).
//
Procedure WriteFullFileNameToRegister(CurrentVersion,
                                         FullFileName,
                                         ForRead,
                                         InOwnerWorkingDirectory) Export
	
	SetPrivilegedMode(True);
	
	// Create record set
	RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();
	
	RecordSet.Filter.Version.Set(CurrentVersion.Ref);
	RecordSet.Filter.User.Set(Users.CurrentUser());

	NewRecord = RecordSet.Add();
	NewRecord.Version = CurrentVersion.Ref;
	NewRecord.Path = FullFileName;
	NewRecord.Size = CurrentVersion.Size;
	NewRecord.PlacementDateIntoWorkingDirectory = CurrentSessionDate();
	NewRecord.User = Users.CurrentUser();

	NewRecord.ForRead = ForRead;
	NewRecord.InOwnerWorkingDirectory = InOwnerWorkingDirectory;
	
	RecordSet.Write();
	
EndProcedure

// Delete the record of the file version from FilesInWorkingDirectory info register.
// Parameters:
//  Version - CatalogRef.FileVersions - version.
//
Procedure DeleteFromRegister(Version) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();
	
	RecordSet.Filter.Version.Set(Version);
	RecordSet.Filter.User.Set(Users.CurrentUser());
	
	RecordSet.Write();
	
EndProcedure

// Delete all records except for
// records of the files used by the current user from the FilesInWorkingDirectory info register.
//
Procedure ClearAllOursExceptLockedOnes() Export
	
	// Filter all in the info register. Iterate - find the ones that are not used by the current user -
	//  and delete all - we assume that they have been already deleted from the disk.
	
	SetPrivilegedMode(True);
	
	ListDelete = New Array;
	CurrentUser = Users.CurrentUser();
	
	// We find record in the info register for our each record - we take the Version and IsEditing fields from there.
	QueryOnTable = New Query;
	QueryOnTable.SetParameter("User", CurrentUser);
	QueryOnTable.Text =
	"SELECT
	|	FilesInWorkingDirectory.Version AS Version,
	|	FilesInWorkingDirectory.Version.Owner.IsEditing AS IsEditing
	|FROM
	|	InformationRegister.FilesInWorkingDirectory AS FilesInWorkingDirectory
	|WHERE
	|	FilesInWorkingDirectory.User = &User
	|	AND FilesInWorkingDirectory.InOwnerWorkingDirectory = FALSE";
	
	QueryResult = QueryOnTable.Execute(); 
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		While Selection.Next() Do
				
			If Selection.IsEditing <> CurrentUser Then
				ListDelete.Add(Selection.Version);
			EndIf;
			
		EndDo;
	EndIf;
	
	SetPrivilegedMode(True);
	For Each Version IN ListDelete Do
		// Create record set
		RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();
		
		RecordSet.Filter.Version.Set(Version);
		RecordSet.Filter.User.Set(CurrentUser);
		
		RecordSet.Write();
	EndDo;
	
EndProcedure

// Delete the old version record from the FilesInWorkingDirectory info register and enter a new record.
// Parameters:
//  OldVersion - CatalogRef.FileVersions - old version.
//  NewVersion - CatalogRef.FileVersions - new version.
//  FullFileName - name with the path in the working directory.
//  DirectoryName - working directory path.
//  InOwnerWorkingDirectory - Boolean - file in the owner working directory (not in the home working directory).
//
Procedure DeleteVersionAndRecordFileInformationToRegister(OldVersion,
                                                       NewVersion,
                                                       FullFileName,
                                                       DirectoryName,
                                                       InOwnerWorkingDirectory)
	
	DeleteFromRegister(OldVersion);
	ForRead = True;
	AddFileInformationToRegister(NewVersion, FullFileName, DirectoryName, ForRead, 0, InOwnerWorkingDirectory);
	
EndProcedure

// Write info of the file path to the FilesInWorkingDirectory info register.
//  Version - CatalogRef.FileVersions - version.
//  FullPath - String - full file path.
//  DirectoryName - working directory path.
//  ForRead - Boolean - File is placed for reading.
//  FileSize  - file size in bytes.
//  InOwnerWorkingDirectory - Boolean - file in the owner working directory (not in the home working directory).
//
Procedure AddFileInformationToRegister(Version,
                                         FullPath,
                                         DirectoryName,
                                         ForRead,
                                         FileSize,
                                         InOwnerWorkingDirectory) Export
	FullFileName = FullPath;
	
	If InOwnerWorkingDirectory = False Then
		If Find(FullPath, DirectoryName) = 1 Then
			FullFileName = Mid(FullPath, StrLen(DirectoryName) + 1);
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	
	// Create record set
	RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();
	
	RecordSet.Filter.Version.Set(Version.Ref);
	RecordSet.Filter.User.Set(Users.CurrentUser());

	NewRecord = RecordSet.Add();
	NewRecord.Version = Version.Ref;
	NewRecord.Path = FullFileName;

	If FileSize <> 0 Then
		NewRecord.Size = FileSize;
	Else
		NewRecord.Size = Version.Size;
	EndIf;

	NewRecord.PlacementDateIntoWorkingDirectory = CurrentSessionDate();
	NewRecord.User = Users.CurrentUser();
	NewRecord.ForRead = ForRead;
	NewRecord.InOwnerWorkingDirectory = InOwnerWorkingDirectory;

	RecordSet.Write();
	
EndProcedure

// Create
// Parameters file folder:
// Name - String - Parent
// folder name - CatalogRef.FileFolders - parent folder.
// User - CatalogRef.Users - responsible for the folder.
//
// Returns:
//   CatalogRef.FileFolders
//
Function CatalogsFoldersCreateItem(Name, Parent, User = Undefined) Export
	
	Folder = Catalogs.FileFolders.CreateItem();
	Folder.Description = Name;
	Folder.Parent = Parent;
	Folder.CreationDate = CurrentSessionDate();
	
	If User = Undefined Then
		Folder.Responsible = Users.CurrentUser();
	Else	
		Folder.Responsible = User;
	EndIf;
	
	Folder.Write();
	Return Folder.Ref;
	
EndFunction

// It generates a report for files with errors.
//
// Parameters:
//   FilenamesWithErrorsArray - String array of paths to files.
//
// Returns:
//   TableDocument with the report.
//
Function FilesImportGenerateReport(FilenamesWithErrorsArray) Export
	
	Document = New SpreadsheetDocument;
	Template = Catalogs.Files.GetTemplate("ReportTemplate");
	
	HeaderArea = Template.GetArea("Title");
	HeaderArea.Parameters.Description = NStr("en='It failed to export the following files:';ru='Не удалось загрузить следующие файлы:'");
	Document.Put(HeaderArea);
	
	AreaRow = Template.GetArea("String");

	For Each Selection IN FilenamesWithErrorsArray Do
		AreaRow.Parameters.Description = Selection.FileName;
		AreaRow.Parameters.Error = Selection.Error;
		Document.Put(AreaRow);
	EndDo;
	
	Report = New SpreadsheetDocument;
	Report.Put(Document);

	Return Report;
	
EndFunction

// It filters the array of structures by Date field - on the server since the thin client does not have ValueTable.
//
// Parameters:
// StructuresArray - array of structures descriptions files.
//
Procedure SortStructuresArray(StructuresArray) Export
	
	FileTable = New ValueTable;
	FileTable.Columns.Add("Path");
	FileTable.Columns.Add("Version");
	FileTable.Columns.Add("Size");
	
	FileTable.Columns.Add("PlacementDateIntoWorkingDirectory", New TypeDescription("Date"));
	
	For Each String IN StructuresArray Do
		NewRow = FileTable.Add();
		FillPropertyValues(NewRow, String, "Path, Size, Version, MovingDateToWorkingDirectory");
	EndDo;
	
	// Sort by the date - the earliest placed in a working directory will be at the beginning.
	FileTable.Sort("PlacementDateIntoWorkingDirectory asc");  
	
	StructureArrayReturn = New Array;
	
	For Each String IN FileTable Do
		Record = New Structure;
		Record.Insert("Path", String.Path);
		Record.Insert("Size", String.Size);
		Record.Insert("Version", String.Version);
		Record.Insert("PlacementDateIntoWorkingDirectory", String.PlacementDateIntoWorkingDirectory);
		StructureArrayReturn.Add(Record);
	EndDo;
	
	StructuresArray = StructureArrayReturn;
	
EndProcedure

// It returns the setting - Ask editing mode when opening a file.
// Returns:
//   Boolean - Ask editing mode when opening a file.
//
Function PromptForEditModeOnOpenFile()
	PromptForEditModeOnOpenFile = 
		CommonUse.CommonSettingsStorageImport("OpenFileSettings", "PromptForEditModeOnOpenFile");
	If PromptForEditModeOnOpenFile = Undefined Then
		PromptForEditModeOnOpenFile = True;
		CommonUse.CommonSettingsStorageSave("OpenFileSettings", "PromptForEditModeOnOpenFile", PromptForEditModeOnOpenFile);
	EndIf;
	
	Return PromptForEditModeOnOpenFile;
EndFunction

// Count DoubleClickAction - if first time - select the correct value.
//
// Returns:
//   String - Action by the mouse double click.
//
Function DoubleClickAction()
	
	HowToOpen = CommonUse.CommonSettingsStorageImport(
		"OpenFileSettings", "DoubleClickAction");
	
	If HowToOpen = Undefined
	 OR HowToOpen = Enums.FileDoubleClickActions.EmptyRef() Then
		
		HowToOpen = Enums.FileDoubleClickActions.ToOpenFile;
		
		CommonUse.CommonSettingsStorageSave(
			"OpenFileSettings", "DoubleClickAction", HowToOpen);
	EndIf;
	
	If HowToOpen = Enums.FileDoubleClickActions.ToOpenFile Then
		Return "ToOpenFile";
	Else
		Return "ToOpenCard";
	EndIf;
	
EndFunction

// Read FileVersionComparisonMethod from the settings.
//
// Returns:
//   String - File versions comparison method.
//
Function FileVersionComparisonMethod()
	
	CompareMethod = CommonUse.CommonSettingsStorageImport(
		"FileComparisonSettings", "FileVersionComparisonMethod");
	
	If CompareMethod = Enums.FileVersionComparisonMethods.MicrosoftOfficeWord Then
		Return "MicrosoftOfficeWord";
		
	ElsIf CompareMethod = Enums.FileVersionComparisonMethods.OpenOfficeOrgWriter Then
		Return "OpenOfficeOrgWriter";
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// The function returns the number of
// files used by the current user in terms of the owner.
// Parameters:
//  FileOwner  - AnyRef - file owner.
//
// Returns:
//   Number  - number of locked files.
//
Function CountOfFilesLockedByCurrentUser(FileOwner) Export
	
	CountEmployedFiles = GetLockedFilesCount(FileOwner, Users.CurrentUser());
	Return CountEmployedFiles;
	
EndFunction

// It receives the ShowColumnSize setting value.
// Returns:
//   Boolean - Show size column.
//
Function GetShowColumnSize() Export
	ShowColumnSize = CommonUse.CommonSettingsStorageImport("ApplicationSettings", "ShowColumnSize");
	If ShowColumnSize = Undefined Then
		ShowColumnSize = False;
		CommonUse.CommonSettingsStorageSave("ApplicationSettings", "ShowColumnSize", ShowColumnSize);
	EndIf;
	
	Return ShowColumnSize;
	
EndFunction

// The function changes FileOwner for the objects of Catalog.File type, it returns True if successfully changed.
// Parameters:
//  RefsToFilesArray - Array - file array.
//  NewFileOwner  - AnyRef - new owner of the file.
//
// Returns:
//   Boolean  - whether the operation is successfully completed.
//
Function SetFileOwner(RefsToFilesArray, NewFileOwner) Export
	If RefsToFilesArray.Count() = 0 Or Not ValueIsFilled(NewFileOwner) Then
		Return False;
	EndIf;
	
	// The same parent - nothing should be done.
	If RefsToFilesArray.Count() > 0 AND (RefsToFilesArray[0].FileOwner = NewFileOwner) Then
		Return False;
	EndIf;
	
	BeginTransaction();
	Try
	
		For Each AcceptedFile IN RefsToFilesArray Do
			FileObject = AcceptedFile.GetObject();
			FileObject.Lock();
			FileObject.FileOwner = NewFileOwner;
			FileObject.Write();
		EndDo;
	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return True;
	
EndFunction

// It returns True if there is looping (if we move one of the folders to its child folder).
// Parameters:
//  RefsToFilesArray - Array - file array.
//  NewParent  - AnyRef - new owner of the file.
//
// Returns:
//   Boolean  - there is looping.
//
Function IsLooping(Val RefsToFilesArray, NewParent)
	
	If RefsToFilesArray.Find(NewParent) <> Undefined Then
		Return True; // looping is found
	EndIf;
	
	Parent = NewParent.Parent;
	If Parent.IsEmpty() Then // go to the root
		Return False;
	EndIf;
	
	If IsLooping(RefsToFilesArray, Parent) = True Then
		Return True; // looping is found
	EndIf;
	
	Return False;
	
EndFunction

// The function changes the Parent attribute for the Catalog type objects.FileFolders, it returns True in case of success, for LoopFound variable it returns True if one of the folders is moved to its child folder.
//
// Parameters:
//  RefsToFilesArray - Array - file array.
//  NewParent  - AnyRef - new owner of the file.
//  InfiniteLoopFound - Boolean - It returns True if the looping is found.
//
// Returns:
//   Boolean  - whether the operation is successfully completed.
//
Function ChangeParentOfFolders(RefsToFilesArray, NewParent, InfiniteLoopFound) Export
	InfiniteLoopFound = False;
	
	If RefsToFilesArray.Count() = 0 Then
		Return False;
	EndIf;
	
	// The same parent - nothing should be done.
	If RefsToFilesArray.Count() = 1 AND (RefsToFilesArray[0].Parent = NewParent) Then
		Return False;
	EndIf;
	
	If IsLooping(RefsToFilesArray, NewParent) Then
		InfiniteLoopFound = True;
		Return False;
	EndIf;
	
	BeginTransaction();
	Try
	
		For Each AcceptedFile IN RefsToFilesArray Do
			FileObject = AcceptedFile.GetObject();
			FileObject.Lock();
			FileObject.Parent = NewParent;
			FileObject.Write();
		EndDo;
	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return True;
	
EndFunction

// It returns True if there is a child with the same name in the specified FileFolders catalog item.
// Parameters:
//  FileName  - Parent
//  folder name - CatalogRef.FileFolders - Folder parent.
//  FirstFolderWithSameName - CatalogRef.FileFolders - the first found folder with the specified name.
//
// Returns:
//   Boolean  - there is a child item with such name.
//
Function IsFolderWithSuchName(FileName, Parent, FirstFolderWithSameName) Export
	
	FirstFolderWithSameName = Catalogs.FileFolders.EmptyRef();
	
	QueryIntoFolders = New Query;
	QueryIntoFolders.SetParameter("Description", FileName);
	QueryIntoFolders.SetParameter("Parent", Parent);
	QueryIntoFolders.Text =
	"SELECT ALLOWED TOP 1
	|	FileFolders.Ref AS Ref
	|FROM
	|	Catalog.FileFolders AS FileFolders
	|WHERE
	|	FileFolders.Description = &Description
	|	AND FileFolders.Parent = &Parent";
	
	QueryResult = QueryIntoFolders.Execute(); 
	
	If Not QueryResult.IsEmpty() Then
		QuerySelection = QueryResult.Unload();
		FirstFolderWithSameName = QuerySelection[0].Ref;
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// It returns True if there is a file with such name in the specified File catalog item.
// Parameters:
//  FileName  - attachment file name 
//  Parent - AnyRef - file owner.
//  FirstFolderWithSameName - CatalogRef.FileFolders - the first found folder with the specified name.
//
// Returns:
//   Boolean  - there is a child item with such name.
//
Function IsFileWithSuchName(FileName, Parent) Export
	
	QueryIntoFolders = New Query;
	QueryIntoFolders.SetParameter("Description", FileName);
	QueryIntoFolders.SetParameter("Parent", Parent);
	QueryIntoFolders.Text =
	"SELECT ALLOWED TOP 1
	|	Files.Ref AS Ref
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.FullDescr = &Description
	|	AND Files.FileOwner = &Parent";
	
	QueryResult = QueryIntoFolders.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// For FileVersions catalog it renames a file on the disk if FileStorageType = InVolumesOnDrive.
// Parameters:
//  Version  - CatalogRef.FileVersions - file version.
//  OldDescription - String - old name.
//  NewDescription - String - new name.
//
Procedure RenameVersionFileOnDrive(Version,
                                         OldDescription,
                                         NewDescription,
                                         UUID = Undefined) Export
	
	If Not Version.Volume.IsEmpty() Then
		VersionObject = Version.GetObject();
		LockDataForEdit(Version, , UUID);
		
		OldFullPath = FileFunctionsService.FullPathOfVolume(Version.Volume) + Version.PathToFile; 
		
		FileOnDrive = New File(OldFullPath);
		FullPath = FileOnDrive.Path;
		BaseName = FileOnDrive.BaseName;
		Extension = FileOnDrive.Extension;
		NewNameWithoutExtension = StrReplace(BaseName, OldDescription, NewDescription);
		
		NewFullPath = FullPath + NewNameWithoutExtension + Extension;
		FullPathToVolume = FileFunctionsService.FullPathOfVolume(Version.Volume);
		NewPartialPath = Right(NewFullPath, StrLen(NewFullPath) - StrLen(FullPathToVolume));
	
		MoveFile(OldFullPath, NewFullPath);
		VersionObject.PathToFile = NewPartialPath;
		VersionObject.Write();
		UnlockDataForEdit(Version, UUID);
	EndIf;
	
EndProcedure

// It returns the number of locked files.
// Parameters:
// FileOwner - AnyRef - file owner.
// IsEditing - CatalogRef.Users - ref. to the user working with the file.
// 
// Returns:
//   Number  - number of locked files.
//
Function GetLockedFilesCount(FileOwner = Undefined, IsEditing = Undefined) Export
	
	Count = 0;
	
	If Not AccessRight("Read", Metadata.Catalogs.Files) Then
		Return 0;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Files.Ref AS Ref,
	|	Files.Presentation AS Presentation
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.IsEditing <> VALUE(Catalog.Users.EmptyRef)";
	
	If IsEditing <> Undefined Then 
		Query.Text = Query.Text + " AND Files.IsEditing = &IsEditing ";
		Query.SetParameter("IsEditing", IsEditing);
	EndIf;
	
	If FileOwner <> Undefined Then 
		Query.Text = Query.Text + " AND Files.FileOwner = &FileOwner ";
		Query.SetParameter("FileOwner", FileOwner);
	EndIf;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Count = Count + 1;
	EndDo;
	
	Return Count;
	
EndFunction

// It receives data to transfer file from one list of attached files to the other.
//
// Parameters:
// FileArray - array of references to files or CatalogRef.Files
// FileOwner - AnyRef - file owner.
//
// Returns:
//   ValueTable - attachment description.
//
Function GetDataForTransferToAttachedFiles(FileArray, FileOwner) Export

	If TypeOf(FileArray) = Type("Array") Then 
		FilesArray = FileArray;
	Else
		FilesArray = New Array;
		FilesArray.Add(FileArray);
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Files.Ref AS Ref,
	|	Files.FullDescr AS FullDescr
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner";
	Query.SetParameter("FileOwner", FileOwner);
	TablResult = Query.Execute().Unload();
	
	Result = New Map;
	For Each FileRef IN FilesArray Do
		
		If TablResult.Find(FileRef, "Ref") <> Undefined Then 
			Result.Insert(FileRef, "Skip");
		ElsIf TablResult.Find(FileRef.FullDescr, "FullDescr") <> Undefined Then 
			Result.Insert(FileRef, "Refresh");
		Else
			Result.Insert(FileRef, "Copy");
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// It copies files while transferring them from one list of attached files to the other.
//
// Parameters:
//   FileArray - Array - array of references to files or CatalogRef.Files
//   FileOwner - AnyRef - file owner.
//
// Returns:
//   CatalogRef.Files - copied file.
//
Function CopyFileInAttached(FileArray, FileOwner) Export
	
	If TypeOf(FileArray) = Type("Array") Then 
		FilesArray = FileArray;
	Else
		FilesArray = New Array;
		FilesArray.Add(FileArray);
	EndIf;
	
	For Each FileRef IN FilesArray Do
		
		Source = FileRef;
		SourceObject = Source.GetObject();
		
		ReceiverObject = SourceObject.Copy();
		ReceiverObject.FileOwner = FileOwner;
		ReceiverObject.Write();
		
		Receiver = ReceiverObject.Ref;
		
		If Not Source.CurrentVersion.IsEmpty() Then
			
			FileStorage = Undefined;
			If Source.CurrentVersion.FileStorageType = Enums.FileStorageTypes.InInfobase Then 
				FileStorage = GetFileStorageFromInformationBase(Source.CurrentVersion);
			EndIf;
			
			FileInformation = FileOperationsClientServer.FileInformation("FileWithVersion");
			FileInformation.BaseName = Receiver.Description;
			FileInformation.Size = Source.CurrentVersion.Size;
			FileInformation.ExtensionWithoutDot = Source.CurrentVersion.Extension;
			FileInformation.FileTemporaryStorageAddress = FileStorage;
			FileInformation.TextTemporaryStorageAddress = Source.CurrentVersion.TextStorage;
			FileInformation.RefOnVersionSource = Source.CurrentVersion;
			Version = Create_Version(Receiver, FileInformation);
			RefreshVersionInFile(Receiver, Version, Source.CurrentVersion.TextStorage);
		EndIf;
		
	EndDo;
	
	Return Receiver;
	
EndFunction

// It updates the versions of equally-named files while moving from one list of attached files to the other.
//
// Parameters:
//   FileArray - array of references to files or CatalogRef.Files
//   FileOwner - AnyRef - file owner.
//
// Returns:
//   CatalogRef.Files - copied file.
//
Function RefreshFileInAttached(FileArray, FileOwner) Export
	
	If TypeOf(FileArray) = Type("Array") Then 
		FilesArray = FileArray;
	Else
		FilesArray = New Array;
		FilesArray.Add(FileArray);
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Files.Ref AS Ref,
	|	Files.FullDescr AS FullDescr
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner";
	Query.SetParameter("FileOwner", FileOwner);
	
	TablResult = Query.Execute().Unload();
	For Each FileRef IN FilesArray Do
		
		FoundString = TablResult.Find(FileRef.FullDescr, "FullDescr");
		
		Source = FileRef;
		Receiver = FoundString.Ref;
		
		If Not Source.CurrentVersion.IsEmpty() Then
			
			FileStorage = Undefined;
			If Source.CurrentVersion.FileStorageType = Enums.FileStorageTypes.InInfobase Then 
				FileStorage = GetFileStorageFromInformationBase(Source.CurrentVersion);
			EndIf;
			
			FileInformation = FileOperationsClientServer.FileInformation("FileWithVersion");
			FileInformation.BaseName = Receiver.Description;
			FileInformation.Size = Source.CurrentVersion.Size;
			FileInformation.ExtensionWithoutDot = Source.CurrentVersion.Extension;
			FileInformation.FileTemporaryStorageAddress = FileStorage;
			FileInformation.TextTemporaryStorageAddress = Source.CurrentVersion.TextStorage;
			FileInformation.RefOnVersionSource = Source.CurrentVersion;
			Version = Create_Version(Receiver, FileInformation);
			RefreshVersionInFile(Receiver, Version, Source.CurrentVersion.TextStorage);
		EndIf;
		
	EndDo;
	
	Return Receiver;
	
EndFunction

// Is there any duplicate item in the conditional list design.
// Parameters:
// Items - item array for conditional list design.
// SearchItem - item for conditional design of the list.
//
// Returns:
//   Boolean - there is duplicate item.
//
Function IsDuplicateItem(Items, SearchItem)
	
	For Each Item IN Items Do
		If Item <> SearchItem Then
			
			If Item.Appearance.Items.Count() <> SearchItem.Appearance.Items.Count() Then
				Continue;
			EndIf;
			
			IsFoundWithItem = False;
			
			// We override all design items - if there is at least one different - do Continue;
			ItemsNumber = Item.Appearance.Items.Count();
			For IndexOf = 0 To ItemsNumber - 1 Do
				Item1 = Item.Appearance.Items[IndexOf];
				Item2 = SearchItem.Appearance.Items[IndexOf];
				
				If Item1.Use AND Item2.Use Then
					If Item1.Parameter <> Item2.Parameter OR Item1.Value <> Item2.Value Then
						IsFoundWithItem = True;
						Break;
					EndIf;
				EndIf;
			EndDo;
			
			If IsFoundWithItem Then
				Continue;
			EndIf;
			
			If Item.Filter.Items.Count() <> SearchItem.Filter.Items.Count() Then
				Continue;
			EndIf;
			
			// We override all filtered items - if there is at least one different - do Continue;
			ItemsNumber = Item.Filter.Items.Count();
			For IndexOf = 0 To ItemsNumber - 1 Do
				Item1 = Item.Filter.Items[IndexOf];
				Item2 = SearchItem.Filter.Items[IndexOf];
				
				If Item1.Use AND Item2.Use Then
					If Item1.ComparisonType <> Item2.ComparisonType
						OR Item1.LeftValue <> Item2.LeftValue
						OR Item1.RightValue <> Item2.RightValue Then
						
						IsFoundWithItem = True;
						Break;
						
					EndIf;
				EndIf;
			EndDo;
			
			If IsFoundWithItem Then
				Continue;
			EndIf;
			
			// Bypass all items of execution and filter - they are all equal - this is double.
			Return True;
			
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Fills a conditional design of the file list.
//
// Parameters:
// List - dynamic list.
//
Procedure FillFileListConditionalAppearance(List) Export
	
	ConditionalAppearanceCD = List.SettingsComposer.Settings.ConditionalAppearance;
	ConditionalAppearanceCD.UserSettingID = "MainAppearance";
	
	Item = ConditionalAppearanceCD.Items.Add();
	Item.Use = True;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);
	
	Filter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.Use = True;
	Filter.ComparisonType = DataCompositionComparisonType.NotEqual;
	Filter.LeftValue = New DataCompositionField("IsEditing");
	Filter.RightValue = Catalogs.Users.EmptyRef();
	
	If IsDuplicateItem(ConditionalAppearanceCD.Items, Item) Then
		ConditionalAppearanceCD.Items.Delete(Item);
	EndIf;
	
	Item = ConditionalAppearanceCD.Items.Add();
	Item.Use = True;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.FileLockedByCurrentUser);
	
	Filter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.Use = True;
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.LeftValue = New DataCompositionField("IsEditing");
	Filter.RightValue = Users.CurrentUser();
	
	If IsDuplicateItem(ConditionalAppearanceCD.Items, Item) Then
		ConditionalAppearanceCD.Items.Delete(Item);
	EndIf;
	
EndProcedure

// It returns an object for which the access right is checked - for File this is FileFolders (FileOwner attribute).
// Parameters:
//  Object  - AnyRef - object reference.
//
// Returns:
//   AnyRef  - object for which access rights are calculated.
//
Function GetAccessObject(Object) Export
	If TypeOf(Object) <> Type("CatalogRef.Files") Then
		Return Undefined;
	EndIf;
	
	If TypeOf(Object.FileOwner) = Type("CatalogRef.FileFolders") Then
		Return Object.FileOwner;
	EndIf;
	
	Return Undefined;
	
EndFunction

// It returns number ascending. Previous value is taken from the ScannedFileNumbers info register.
// Parameters:
// Owner - AnyRef - file owner.
//
// Returns:
//   Number  - new number for scanning.
//
Function GetNewNumberForScanning(Owner) Export
	
	// Prepare filter structure by measurements.
	FilterStructure = New Structure;
	FilterStructure.Insert("Owner", Owner);
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.ScannedFileNumbers");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.SetValue("Owner", Owner);
		Block.Lock();   		
	
		// Get the structure with data resources records.
		StructureOfResources = InformationRegisters.ScannedFileNumbers.Get(FilterStructure);
		   
		// Get the maximum number from the register.
		Number = StructureOfResources.Number;
		Number = Number + 1; // increase by 1
		
		// Write the new number to the register.
		RecordSet = InformationRegisters.ScannedFileNumbers.CreateRecordSet();
		
		RecordSet.Filter.Owner.Set(Owner);
		
		NewRecord = RecordSet.Add();
		NewRecord.Owner = Owner;
		NewRecord.Number = Number;
		
		RecordSet.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Number;
	
EndFunction

// It logs the number to the ScannedFileNumbers info register.
//
// Parameters:
// Owner - AnyRef - file owner.
// NewNumber -  Number  - maximum number for scanning.
//
Procedure PlaceMaxNumberForScanning(Owner, NewNumber) Export
	
	// Prepare filter structure by measurements.
	FilterStructure = New Structure;
	FilterStructure.Insert("Owner", Owner);
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.ScannedFileNumbers");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.SetValue("Owner", Owner);
		Block.Lock();   		
		
		// Get the structure with data resources records.
		StructureOfResources = InformationRegisters.ScannedFileNumbers.Get(FilterStructure);
		   
		// Get the maximum number from the register.
		Number = StructureOfResources.Number;
		If NewNumber <= Number Then // Someone has already written the larger number.
			RollbackTransaction();
			Return;
		EndIf;
		
		Number = NewNumber;
		
		// Write the new number to the register.
		RecordSet = InformationRegisters.ScannedFileNumbers.CreateRecordSet();
		
		RecordSet.Filter.Owner.Set(Owner);
		
		NewRecord = RecordSet.Add();
		NewRecord.Owner = Owner;
		NewRecord.Number = Number;
		
		RecordSet.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Clear settings of the NewOneForm forms.
Procedure ClearFormSettingsOfNewFile() Export
	
	SetPrivilegedMode(True);
	// Clear settings of the NewOneForm window.
	SystemSettingsStorage.Delete("Catalog.Files.Form.FormOfNew/WindowSettings", "", Undefined);
	
	RefreshReusableValues();
	
EndProcedure

// It receives the first 100 versions of files which text is not extracted.
//
// Returns:
//   Array - array of file versions.
//
Function GetVersionsArrayForTextExtraction() Export
	
	VersionArray = New Array;
	
	Query = New Query;
	
	Query.Text =
	"SELECT TOP 100
	|	FileVersions.Ref AS Ref,
	|	FileVersions.TextExtractionStatus AS TextExtractionStatus
	|FROM
	|	Catalog.FileVersions AS FileVersions
	|WHERE
	|	(FileVersions.TextExtractionStatus = &Status
	|			OR FileVersions.TextExtractionStatus = VALUE(Enum.FileTextExtractionStatuses.EmptyRef))";
	
	Query.SetParameter("Status", Enums.FileTextExtractionStatuses.NotExtracted);
	
	Result = Query.Execute();
	ExportingTable = Result.Unload();
	
	For Each String IN ExportingTable Do
		VersionRef = String.Ref;
		VersionArray.Add(VersionRef);
	EndDo;
	
	Return VersionArray;
	
EndFunction

// It receives reference array for all files in the folder (if Recursively then for subfolders as well).
// Parameters:
//  Folder  - CatalogRef.FileFolders - file folder.
//  Recursively - Boolean - whether to override subfolders.
//
// Returns:
//   Array - files array
//
Function GetAllFilesInFolder(Folder, Recursively) Export
	
	FilesArray = New Array;
	
	GetAllFilesInOneFolder(Folder, FilesArray);
	
	If Recursively Then
		
		FoldersArray = New Array;
		
		QueryIntoFolders = New Query;
		QueryIntoFolders.SetParameter("Parent", Folder);
		QueryIntoFolders.Text =
		"SELECT ALLOWED
		|	FileFolders.Ref AS Ref
		|FROM
		|	Catalog.FileFolders AS FileFolders
		|WHERE
		|	FileFolders.Parent IN HIERARCHY(&Parent)";
		
		Result = QueryIntoFolders.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			FoldersArray.Add(Selection.Ref);
		EndDo;
		
		For Each Subfolder IN FoldersArray Do
			GetAllFilesInOneFolder(Subfolder, FilesArray);
		EndDo;
		
	EndIf;
	
	Return FilesArray;
	
EndFunction

// It receives an array of references for all files in the directory.
// Parameters:
//  Folder  - CatalogRef.FileFolders - file folder.
//  FilesArray - Array - file array.
//
Procedure GetAllFilesInOneFolder(Folder, FilesArray) Export
	
	QueryIntoFolders = New Query;
	QueryIntoFolders.SetParameter("Parent", Folder);
	QueryIntoFolders.Text =
	"SELECT ALLOWED
	|	Files.Ref AS Ref
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.FileOwner = &Parent";
	
	Result = QueryIntoFolders.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		FilesArray.Add(Selection.Ref);
	EndDo;
	
EndProcedure

// It receives file data for opening and reads from the common settings FolderForSaveAs.
//
// Parameters:
//  FileOrVersionRef     - CatalogRef.Files, CatalogRef.FileVersions - file or file version.
//  FormID      - UUID - form unique ID.
//  OwnerWorkingDirectory - String - working directory of the file owner.
//
// Returns:
//   Structure - structure with file data.
//
Function FileDataForSave(FileOrVersionRef, FormID = Undefined, OwnerWorkingDirectory = Undefined) Export

	FileData = FileDataForOpening(FileOrVersionRef, FormID, OwnerWorkingDirectory);
	
	FolderForSaveAs = CommonUse.CommonSettingsStorageImport("ApplicationSettings", "FolderForSaveAs");
	FileData.Insert("FolderForSaveAs", FolderForSaveAs);

	Return FileData;
EndFunction

// Receives all subordinate files.
// Parameters:
//  FileOwner - AnyRef - file owner.
//
// Returns:
//   Array - files array
Function GetAllSubordinateFiles(FileOwner) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Files.Ref AS Ref
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner";
	
	Query.SetParameter("FileOwner", FileOwner);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// It receives the number of file versions.
// Parameters:
//  FileRef - CatalogRef.Files - file.
//
// Returns:
//   Number - number of versions
Function GetNumberOfVersions(FileRef) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(*) AS Count
	|FROM
	|	Catalog.FileVersions AS FileVersions
	|WHERE
	|	FileVersions.Owner = &FileRef";
	
	Query.SetParameter("FileRef", FileRef);
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Number(Selection.Quantity);
	
EndFunction

// It receives FileData and VersionURL for all subordinated files.
// Parameters:
//  FileRef - CatalogRef.Files - file.
//  FormID - form unique ID.
//
// Returns:
//   Array - structure array with the file data.
Function FileDataAndURLForAllFileVersions(FileRef, FormID) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	FileVersions.Ref AS Ref
		|FROM
		|	Catalog.FileVersions AS FileVersions
		|WHERE
		|	FileVersions.Owner = &FileRef";
	
	Query.SetParameter("FileRef", FileRef);
	Result = Query.Execute();
	Selection = Result.Select();
	
	ReturnArray = New Array;
	While Selection.Next() Do
		
		VersionRef = Selection.Ref;
		FileData = FileData(VersionRef);
		VersionURL = GetURLToTemporaryStorage(VersionRef, FormID);
		
		ReturnStructure = New Structure("FileData, VersionURL, VersionRef", 
			FileData, VersionURL, VersionRef);
		ReturnArray.Add(ReturnStructure);
	EndDo;
	
	Return ReturnArray;
EndFunction

// It moves the encrypted files to the base and assigns Encrypted to the file and all versions.
// Parameters:
//  FileRef - CatalogRef.Files - file.
//  Encrypt - Boolean - encrypt the file if True - else decode.
//  ArrayDataForPlacingToBase - array of structures.
//  UUID - UUID - form unique ID.
//  WorkingDirectoryName - String - working directory.
//  FilesArrayInWorkingDirectoryForDelete - Array - Files to be deleted from the register.
//  ThumbprintArray  - Array - array of certificate printouts used for encryption.
Procedure AddInformationAboutEncryption(FileRef, Encrypt, ArrayDataForPlacingToBase, UUID, 
	WorkingDirectoryName, FilesArrayInWorkingDirectoryForDelete, ThumbprintArray) Export
	
	BeginTransaction();
	Try
		
		CurrentVersionTextTemporaryStorageAddress = "";
		
		For Each DataForRecordsAtServer IN ArrayDataForPlacingToBase Do
			
			TemporaryStorageAddress = DataForRecordsAtServer.TemporaryStorageAddress;
			VersionRef = DataForRecordsAtServer.VersionRef;
			TextTemporaryStorageAddress = DataForRecordsAtServer.TextTemporaryStorageAddress;
			
			If VersionRef = FileRef.CurrentVersion Then
				CurrentVersionTextTemporaryStorageAddress = TextTemporaryStorageAddress;
			EndIf;
			
			FullFileNameInWorkingDirectory = "";
			InWorkingDirectoryForRead = True; // not used 
			InOwnerWorkingDirectory = True;
			FullFileNameInWorkingDirectory = GetFullFileNameFromRegister(VersionRef, WorkingDirectoryName, InWorkingDirectoryForRead, InOwnerWorkingDirectory);
			If Not IsBlankString(FullFileNameInWorkingDirectory) Then
				FilesArrayInWorkingDirectoryForDelete.Add(FullFileNameInWorkingDirectory);
			EndIf;
			
			DeleteFromRegister(VersionRef);
			
			TextExtractionStatus = Undefined;
			If Encrypt = False Then
				TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
			EndIf;
			
			FileInformation = FileOperationsClientServer.FileInformation("FileWithVersion");
			FileInformation.BaseName = VersionRef.FullDescr;
			FileInformation.Comment = VersionRef.Comment;
			FileInformation.FileTemporaryStorageAddress = TemporaryStorageAddress;
			FileInformation.ExtensionWithoutDot = VersionRef.Extension;
			FileInformation.ModifiedAt = VersionRef.CreationDate;
			FileInformation.ModificationTimeUniversal = VersionRef.ModificationDateUniversal;
			FileInformation.Size = VersionRef.Size;
			FileInformation.ModificationTimeUniversal = VersionRef.ModificationDateUniversal;
			FileInformation.NewTextExtractionStatus = TextExtractionStatus;
			FileInformation.Encrypted = Encrypt;
			FileInformation.StoreVersions = False;
			UpdateFileVersion(FileRef, FileInformation, VersionRef, UUID);
			
			// For variant with file storage on the disk (on the server) we remove File from the temporary storage after its reception.
			If Not IsBlankString(DataForRecordsAtServer.FileURL) AND IsTempStorageURL(DataForRecordsAtServer.FileURL) Then
				DeleteFromTempStorage(DataForRecordsAtServer.FileURL);
			EndIf;
				
		EndDo;
		
		FileObject = FileRef.GetObject();
		LockDataForEdit(FileRef, , UUID);
		
		FileObject.Encrypted = Encrypt;
		FileObject.TextStorage = New ValueStorage(""); // clear the
		// extracted text To complete writing of the previously signed object.
		FileObject.AdditionalProperties.Insert("DigitallySignedObjectRecord", True);
		
		If Encrypt Then
			For Each ThumbprintStructure IN ThumbprintArray Do
				NewRow = FileObject.EncryptionCertificates.Add();
				NewRow.Imprint = ThumbprintStructure.Imprint;
				NewRow.Presentation = ThumbprintStructure.Presentation;
				NewRow.Certificate = New ValueStorage(ThumbprintStructure.Certificate);
			EndDo;
		Else
			FileObject.EncryptionCertificates.Clear();
		EndIf;
		
		If CurrentVersionTextTemporaryStorageAddress <> "" Then
			Text = FileFunctionsService.GetStringFromTemporaryStorage(CurrentVersionTextTemporaryStorageAddress);
			FileObject.TextStorage = New ValueStorage(Text);
		EndIf;
		
		FileObject.Write();
		UnlockDataForEdit(FileRef, UUID);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// It executes MoveToTemporaryStorage (if a file is stored on the disk) and returns the required reference.
// Parameters:
//  VersionRef  - CatalogRef.FileVersions - file version.
//  FormID - form unique ID.
//
// Returns:
//   String - navigation link.
Function GetURLToTemporaryStorage(VersionRef, FormID = Undefined) Export
	Address = "";
	
	FileStorageType = VersionRef.FileStorageType;
	
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
		If Not VersionRef.Volume.IsEmpty() Then
			FullPath = FileFunctionsService.FullPathOfVolume(VersionRef.Volume) + VersionRef.PathToFile; 
			Try
				BinaryData = New BinaryData(FullPath);
				Address = PutToTempStorage(BinaryData, FormID);
			Except
				// Record in the event log.
				ErrorInfo = GenerateObtainingErrorTextFileFromVolumeForAdministrator(
					ErrorInfo(), VersionRef.Owner);
				
				WriteLogEvent(
					NStr("en='Files.File opening';ru='Файлы.Открытие файла'",
					     CommonUseClientServer.MainLanguageCode()),
					EventLogLevel.Error,
					Metadata.Catalogs.Files,
					VersionRef.Owner,
					ErrorInfo);
				
				Raise FileFunctionsServiceClientServer.ErrorFileIsNotFoundInFileStorage(
					VersionRef.FullDescr + "." + VersionRef.Extension);
			EndTry;
		EndIf;
	Else
		FileStorage = GetFileStorageFromInformationBase(VersionRef);
		BinaryData = FileStorage.Get();
		
		Address = PutToTempStorage(BinaryData, FormID);
	EndIf;
	
	Return Address;
	
EndFunction

// It receives FileData and VersionURL having previously placed the version file to the temporary storage.
//
// Parameters:
//  FileOrVersionRef - CatalogRef.Files, CatalogRef.FileVersions - file or file version.
//  FormID  - UUID - form unique ID.
//
// Returns:
//   Structure - file data and navigation link.
//
Function FileDataAndVersionURLInTemporaryStorage(FileOrVersionRef, FormID) Export
	
	FileData = FileData(FileOrVersionRef);
	If TypeOf(FileOrVersionRef) = Type("CatalogRef.Files") Then
		VersionRef = FileOrVersionRef.CurrentVersion;
	Else
		VersionRef = FileOrVersionRef;
	EndIf;
	VersionURL = GetURLToTemporaryStorage(VersionRef, FormID);
	Result = New Structure("FileData, VersionURL", FileData, VersionURL);
	Return Result;
EndFunction

// It receives the array of encryption certificates.
// Parameters:
//  Refs  - CatalogRef.Files - file.
//
// Returns:
//   Array - structure array
Function GetArrayOfEncryptionCertificates(Refs) Export
	
	SetPrivilegedMode(True);
	Query = New Query;
	Query.Text =
	"SELECT
	|	EncryptionCertificates.Presentation AS Presentation,
	|	EncryptionCertificates.Imprint AS Imprint,
	|	EncryptionCertificates.Certificate AS Certificate
	|FROM
	|	Catalog.Files.EncryptionCertificates AS EncryptionCertificates
	|WHERE
	|	EncryptionCertificates.Ref = &ObjectRef";
	
	Query.Parameters.Insert("ObjectRef", Refs);
	QuerySelection = Query.Execute().Select();
	
	ArrayOfEncryptionCertificates = New Array;
	While QuerySelection.Next() Do
		ThumbprintStructure = New Structure("Thumbprint, Presentation, Certificate",
			QuerySelection.Imprint, QuerySelection.Presentation, QuerySelection.Certificate.Get());
		ArrayOfEncryptionCertificates.Add(ThumbprintStructure);
	EndDo;
	
	Return ArrayOfEncryptionCertificates;
	
EndFunction

// It receives file data and his binary data.
//
// Parameters:
//  FileOrVersionRef - CatalogRef.Files, CatalogRef.FileVersions - file or file version.
//  SignatureAddress - String - URL containing the signature file address in the temporary storage.
//  FormID  - UUID - form unique ID.
//
// Returns:
//   Structure - FileData and the file as BinaryData and the file signature as BinaryData.
//
Function FileDataAndBinaryData(FileOrVersionRef, SignatureAddress = Undefined, FormID = Undefined) Export
	
	FileData = FileData(FileOrVersionRef);
	If TypeOf(FileOrVersionRef) = Type("CatalogRef.Files") Then
		VersionRef = FileOrVersionRef.CurrentVersion;
	Else
		VersionRef = FileOrVersionRef;
	EndIf;
	
	BinaryData = Undefined;
	
	FileStorageType = VersionRef.FileStorageType;
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
		If Not VersionRef.Volume.IsEmpty() Then
			FullPath = FileFunctionsService.FullPathOfVolume(VersionRef.Volume) + VersionRef.PathToFile; 
			Try
				BinaryData = New BinaryData(FullPath);
			Except
				// Record in the event log.
				ErrorInfo = GenerateObtainingErrorTextFileFromVolumeForAdministrator(
					ErrorInfo(), VersionRef.Owner);
				
				WriteLogEvent(
					NStr("en='Files.File opening';ru='Файлы.Открытие файла'",
					     CommonUseClientServer.MainLanguageCode()),
					EventLogLevel.Error,
					Metadata.Catalogs.Files,
					VersionRef.Owner,
					ErrorInfo);
				
				Raise FileFunctionsServiceClientServer.ErrorFileIsNotFoundInFileStorage(
					VersionRef.FullDescr + "." + VersionRef.Extension);
			EndTry;
		EndIf;
	Else
		FileStorage = GetFileStorageFromInformationBase(VersionRef);
		BinaryData = FileStorage.Get();
	EndIf;

	BinaryDataSignatures = Undefined;
	If SignatureAddress <> Undefined Then
		BinaryDataSignatures = GetFromTempStorage(SignatureAddress);
	EndIf;
	
	If FormID <> Undefined Then
		BinaryData = PutToTempStorage(BinaryData, FormID);
	EndIf;
	
	ReturnStructure = New Structure("FileData, BinaryData, SignatureBinaryData",
		FileData, BinaryData, BinaryDataSignatures);
	
	Return ReturnStructure;
EndFunction

// It adds signature to the file version and marks the file as signed.
Procedure AddFileSignature(FileRef, SignatureProperties, FormID) Export
	
	AttributesStructure = CommonUse.ObjectAttributesValues(FileRef, "IsEditing, Encrypted");
	
	IsEditing = AttributesStructure.IsEditing;
	If Not IsEditing.IsEmpty() Then
		Raise FileFunctionsServiceClientServer.MessageStringAboutImpossibilityOfLockedFileSigning(FileRef);
	EndIf;
	
	Encrypted = AttributesStructure.Encrypted;
	If Encrypted Then
		ExceptionString = FileFunctionsServiceClientServer.MessageStringAboutImpossibilityOfEncryptedFileSigning(FileRef);
		Raise ExceptionString;
	EndIf;
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	ModuleDigitalSignature = CommonUse.CommonModule("DigitalSignature");
	
	VersionRef = CommonUse.ObjectAttributeValue(FileRef, "CurrentVersion");
	
	BeginTransaction();
	Try
		ModuleDigitalSignature.AddSignature(VersionRef, SignatureProperties, FormID);
		
		FileRefDigitallySigned = CommonUse.ObjectAttributeValue(FileRef, "DigitallySigned");
		If FileRefDigitallySigned = False Then
			FileObject = FileRef.GetObject(); 
			LockDataForEdit(FileRef, , FormID);
			FileObject.DigitallySigned = True;
			
			FileObject.Write();
			UnlockDataForEdit(FileRef, FormID);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// It deletes records from EP tabular section
//
// Parameters:
//  VersionRef - CatalogRef.FileVersions - file version reference.
//  RowIndexes  - Array - index of the tablular section row.
//  AttributeDigitallySignedChanged - Boolean - the return value - If the last signature
// is deleted, AttributeSignedChanged will take the True value.
//  UUID - UUID - form unique ID.
Procedure DeleteFileVersionSignatures(VersionRef, RowIndexes, AttributeDigitallySignedChanged,
	UUID = Undefined) Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	ModuleDigitalSignature = CommonUse.CommonModule("DigitalSignature");
	
	BeginTransaction();
	Try
		
		WrittenObject = Undefined;
		ModuleDigitalSignature.DeleteSignature(VersionRef,
			RowIndexes, UUID, , WrittenObject);
		
		FileRef = WrittenObject.Owner;
		FileRefDigitallySigned = CommonUse.ObjectAttributeValue(FileRef, "DigitallySigned");
		
		If FileRefDigitallySigned = True AND WrittenObject.DigitalSignatures.Count() = 0 Then
			AttributeDigitallySignedChanged = True;
			FileObject = FileRef.GetObject(); 
			LockDataForEdit(FileRef, , UUID);
			FileObject.DigitallySigned = False;
			FileObject.Write();
			UnlockDataForEdit(FileRef, UUID);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// The procedure adds specific settings for the Work With Files subsystem.
//
// Parameters:
//  CommonSettings        - Structure - common settings for all users.
//  PersonalSettings - Structure - different settings for different users.
//  
Procedure AddFileOperationsSettings(CommonSettings, PersonalSettings) Export
	
	SetPrivilegedMode(True);
	
	PersonalSettings.Insert("DoubleClickAction", DoubleClickAction());
	PersonalSettings.Insert("FileVersionComparisonMethod",  FileVersionComparisonMethod());
	
	PersonalSettings.Insert("PromptForEditModeOnOpenFile",
		PromptForEditModeOnOpenFile());
	
	PersonalSettings.Insert("InfobaseUserWithFullAccess",
		Users.InfobaseUserWithFullAccess(,, False));
	
	ShowLockedFilesOnExit = CommonUse.CommonSettingsStorageImport(
		"ApplicationSettings", "ShowLockedFilesOnExit");
	
	If ShowLockedFilesOnExit = Undefined Then
		ShowLockedFilesOnExit = True;
		
		CommonUse.CommonSettingsStorageSave(
			"ApplicationSettings",
			"ShowLockedFilesOnExit",
			ShowLockedFilesOnExit);
	EndIf;
	
	PersonalSettings.Insert("ShowLockedFilesOnExit",
		ShowLockedFilesOnExit);
	
EndProcedure

// It adds a file to volumes when executing the command "allocate files of primary image".
// Parameters:
//  FilesPathCompliance - Map - matching of the file ID and path to the file on the disk.
//  FileStorageType - Enums.FileStorageTypes - file storage type.
Procedure AddFilesToVolumesOnPlacing(FilesPathCompliance, FileStorageType) Export
	
	Selection = Catalogs.FileVersions.Select();
	
	While Selection.Next() Do
		
		Object = Selection.GetObject();
		
		If Object.FileStorageType <> Enums.FileStorageTypes.InVolumesOnDrive Then
			Continue;
		EndIf;
		
		UUID = String(Object.Ref.UUID());
		
		FileFullPathOnDrive = FilesPathCompliance.Get(UUID);
		FullPathNew = "";
		
		If FileFullPathOnDrive = Undefined Then
			Continue;
		EndIf;
		
		FileStorage = Undefined;
		
		// IN the receiving base the files shall be stored in the infobase - so we place them there (even if
		// they were in the volumes in the original base).
		If FileStorageType = Enums.FileStorageTypes.InInfobase Then
			
			Object.FileStorageType = Enums.FileStorageTypes.InInfobase;
			Object.PathToFile = "";
			Object.Volume = Catalogs.FileStorageVolumes.EmptyRef();
			
			BinaryData = New BinaryData(FileFullPathOnDrive);
			FileStorage = New ValueStorage(BinaryData);
			
		Else // IN the receiving base the files shall be stored in the volumes on the disk - move the unzipped file to the volume.
			
			SourceFile = New File(FileFullPathOnDrive);
			FullPathNew = SourceFile.Path + Object.Description + "." + Object.Extension;
			MoveFile(FileFullPathOnDrive, FullPathNew);
			
			// Add to one of the volumes (where free space is).
			FileInformation = FileFunctionsService.AddFileToVolume(FullPathNew, Object.ModificationDateUniversal,
				Object.Description, Object.Extension, Object.VersionNumber, Object.Encrypted); 
			Object.Volume = FileInformation.Volume;
			Object.PathToFile = FileInformation.PathToFile;
			
		EndIf;
		
		Object.AdditionalProperties.Insert("FilePlacementInVolumes", True); // For the signed files to be record.
		Object.Write();
		
		If FileStorageType = Enums.FileStorageTypes.InInfobase Then
			WriteFileToInformationBase(Object.Ref, FileStorage);	
		EndIf;
		
		If Not IsBlankString(FullPathNew) Then
			DeleteFiles(FullPathNew);
		EndIf;
		
	EndDo;
	
EndProcedure

// It deletes the changes history - after allocation in volumes.
// Parameters:
//  ExchangePlanRef - ExchangePlan.Ref - exchange plan.
Procedure DeleteChangeRecords(ExchangePlanRef) Export
	
	ExchangePlans.DeleteChangeRecords(ExchangePlanRef, Metadata.Catalogs.FileVersions);
	ExchangePlans.DeleteChangeRecords(ExchangePlanRef, Metadata.Catalogs.Files);
	ExchangePlans.DeleteChangeRecords(ExchangePlanRef, Metadata.InformationRegisters.VersionStoredFiles);
	
EndProcedure

// It fills the query text to receive files with the text not extracted.
// You can receive another request as a parameter and you shall merge with it.
// 
// Parameters:
//  QueryText - String (return value), variants of passed values:
//                   Blank string   - the required query text will be returned.
//                   String is not empty - the required query text added to the passed text using COMBINE ALL will be returned.
// 
//  GetAllFiles - Boolean - Initial value is False. It allows you to disable file filtering by parts if True is passed.
//
Procedure WhenDefiningTextQueryForTextRetrieval(QueryText, GetAllFiles = False) Export
	
	QueryText =
	"SELECT TOP 100
	|	FileVersions.Ref AS Ref,
	|	FileVersions.TextExtractionStatus AS TextExtractionStatus,
	|	FileVersions.FileStorageType AS FileStorageType,
	|	FileVersions.Extension AS Extension,
	|	FileVersions.Owner.Description AS Description
	|FROM
	|	Catalog.FileVersions AS FileVersions
	|WHERE
	|	(FileVersions.TextExtractionStatus = VALUE(Enum.FileTextExtractionStatuses.NotExtracted)
	|			OR FileVersions.TextExtractionStatus = VALUE(Enum.FileTextExtractionStatuses.EmptyRef))
	|	AND Not FileVersions.Encrypted";
	
	If GetAllFiles Then
		QueryText = StrReplace(QueryText, "TOP 100", "");
	EndIf;
	
EndProcedure

// Receives full path to the file on the disk.
// Parameters:
//  VersionRef  - CatalogRef.FileVersions - file version.
//
// Returns:
//   String - full path to the file on the disk.
Function GetFileNameWithPathToBinaryData(VersionRef, PathIsEmptyForEmptyData = False) Export
	
	FullFileName = "";
	
	If VersionRef.FileStorageType = Enums.FileStorageTypes.InInfobase Then
		
		FileStorage = GetFileStorageFromInformationBase(VersionRef);
		FileBinaryData = FileStorage.Get();
		
		If PathIsEmptyForEmptyData AND TypeOf(FileBinaryData) <> Type("BinaryData") Then
			Return "";
		EndIf;
		
		FullFileName = GetTempFileName(VersionRef.Extension);
		FileBinaryData.Write(FullFileName);
	Else
		If Not VersionRef.Volume.IsEmpty() Then
			FullFileName = FileFunctionsService.FullPathOfVolume(VersionRef.Volume) + VersionRef.PathToFile;
		EndIf;
	EndIf;
	
	Return FullFileName;
	
EndFunction

// It writes the extracted text.
//
// Parameters:
//  CurrentVersion  - CatalogRef.FileVersions - file version.
//
Procedure OnWriteExtractedText(CurrentVersion) Export
	
	FileLocked = False;
	
	File = CurrentVersion.Owner;
	If File.CurrentVersion = CurrentVersion.Ref Then
		Try
			LockDataForEdit(File);
			FileLocked = True;
		Except
			// Except if an object is already locked including using the Lock method.
			Return;
		EndTry;
	EndIf;
	
	BeginTransaction();
	Try
		CurrentVersion.DataExchange.Load = True;
		CurrentVersion.Write();
		
		If File.CurrentVersion = CurrentVersion.Ref Then
			FileObject = File.GetObject();
			FileObject.TextStorage = CurrentVersion.TextStorage;
			FileObject.DataExchange.Load = True;
			FileObject.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		If FileLocked Then
			UnlockDataForEdit(File);
		EndIf;
		
		Raise;
	EndTry;
	
	If FileLocked Then
		UnlockDataForEdit(File);
	EndIf;
	
EndProcedure

// It returns the number of files in volumes.
// Returns:
//   Number - Number of files in volumes.
//
Function CountNumberOfFilesInVolumes() Export
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	ISNULL(COUNT(Versions.Ref), 0) AS CountOfFiles
	|FROM
	|	Catalog.FileVersions AS Versions
	|WHERE
	|	Versions.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnDrive)";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return Number(Selection.CountOfFiles);
	EndIf;
	
	Return 0;
	
EndFunction

// It returns the number of files in the volumes in CountFilesInVolumes parameter
Procedure DetermineCountOfFilesInVolumes(CountFilesInVolumes) Export
	
	CountFilesInVolumes = CountFilesInVolumes + CountNumberOfFilesInVolumes();
	
EndProcedure

// It returns True in ThereAreStoredFiles parameter if there are stored files to ExternalObject object.
//
Procedure DetermineStoredFilesExisting(ExternalObject, AreStoredFiles) Export
	
	If AreStoredFiles = True Then
		Return;
	EndIf;
	OwnerTypes = Metadata.CommonCommands.AttachedFiles.CommandParameterType.Types();
	If OwnerTypes.Find(TypeOf(ExternalObject)) <> Undefined Then
		FilesArray = GetAllSubordinateFiles(ExternalObject);
		AreStoredFiles = FilesArray.Count() <> 0;
	EndIf;
	
EndProcedure

// It returns the array of stored files to the ExternalObject object in the StoredFiles parameter.
//
Procedure GetStoredFiles(ExternalObject, StoredFiles) Export
	
	OwnerTypes = Metadata.CommonCommands.AttachedFiles.CommandParameterType.Types();
	If OwnerTypes.Find(TypeOf(ExternalObject)) = Undefined Then
		Return;
	EndIf;
	
	FilesArray = GetAllSubordinateFiles(ExternalObject);
	For Each File IN FilesArray Do
		FileData = New Structure("ModificationDateUniversal, Size, Name, Extension, FileBinaryData, Text");
		
		FileData.ModificationDateUniversal = CommonUse.ObjectAttributeValue(File.CurrentVersion, "ModificationDateUniversal");
		FileData.Size = File.CurrentVersionSize;
		FileData.Description = File.Description;
		FileData.Extension = File.CurrentVersionExtension;
		
		DataForOpening = GetURLToTemporaryStorage(File.CurrentVersion);
		FileData.FileBinaryData = DataForOpening;
		
		FileData.Text = File.TextStorage.Get();
		
		StoredFiles.Add(FileData);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE HANDLERS

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.2"; // At updating by 1.0.5.2 the handler is enabled.
	Handler.Procedure = "FileOperationsServiceServerCall.FillVersionNumberFromCatalogCode";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.2"; // At updating by 1.0.5.2 the handler is enabled.
	Handler.Procedure = "FileOperationsServiceServerCall.FillFileStorageTypeInBase";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.7"; // At updating by 1.0.5.7 the handler is enabled.
	Handler.Procedure = "FileOperationsServiceServerCall.ChangeIconIndex";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.6.3"; // At updating by 1.0.6.3 the handler is enabled.
	Handler.SharedData = True;
	Handler.Procedure = "FileOperationsServiceServerCall.FillVolumePaths";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.7.1";
	Handler.Procedure = "FileOperationsServiceServerCall.OverwriteAllFiles";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.2.2";
	Handler.Procedure = "FileOperationsServiceServerCall.FillFileModificationDate";
	
	Handler = Handlers.Add();
	Handler.Version = "1.2.1.2";
	Handler.Procedure = "FileOperationsServiceServerCall.MoveFilesFromInfobaseToInfoRegister";
	
	Handler = Handlers.Add();
	Handler.Version = "1.2.1.2";
	Handler.Procedure = "FileOperationsServiceServerCall.FillLoanDate";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "FileOperationsServiceServerCall.ReplaceRightsInFileFolderRightsSettings";
	
EndProcedure

// It fills VersionNumber(Number) from the data in Code(String) in FileVersions catalog.
Procedure FillVersionNumberFromCatalogCode() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	FileVersions.Ref,
	|	FileVersions.DeletionMark,
	|	FileVersions.Code,
	|	FileVersions.VersionNumber,
	|	FileVersions.Owner.DeletionMark AS OwnerDeletionMark,
	|	FileVersions.Owner.CurrentVersion
	|FROM
	|	Catalog.FileVersions AS FileVersions";

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.VersionNumber = 0 Then 
			
			TypeDescription = New TypeDescription("Number");
			CodeNumber = TypeDescription.AdjustValue(Selection.Code);
			If CodeNumber <> 0 Then
				Object = Selection.Ref.GetObject();
				Object.VersionNumber = CodeNumber;
				
				// Correction of the situation permitted before but invalid now - active version is marked for deletion and the owner
				// - no.
				If Selection.DeletionMark = True AND Selection.OwnerDeletionMark = False AND Selection.CurrentVersion = Selection.Ref Then
					Object.DeletionMark = False;
				EndIf;
				
				InfobaseUpdate.WriteData(Object);
			EndIf
			
		EndIf;
		
	EndDo;
	
EndProcedure

// It fills FileStorageType with the InBase value in the FileVersions catalog.
Procedure FillFileStorageTypeInBase() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FileVersions.Ref
	|FROM
	|	Catalog.FileVersions AS FileVersions";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		
		If Object.FileStorageType.IsEmpty() Then
			Object.FileStorageType = Enums.FileStorageTypes.InInfobase;
			InfobaseUpdate.WriteData(Object);
		EndIf;
		
	EndDo;
	
EndProcedure

// It increases 2 times PictureIndex in the FileVersions and Files catalogs.
Procedure ChangeIconIndex() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FileVersions.Ref
	|FROM
	|	Catalog.FileVersions AS FileVersions";

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		Object.DataExchange.Load = True;
		Object.PictureIndex = FileFunctionsServiceClientServer.GetFileIconIndex(Object.Extension);
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Files.Ref
	|FROM
	|	Catalog.Files AS Files";

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		Object.DataExchange.Load = True;
		Object.PictureIndex = Object.CurrentVersion.PictureIndex;
		Object.Write();
	EndDo;
	
EndProcedure

// It is  called when updating to 1.0.6.3 - fills the FileStorageVolumes paths.
Procedure FillVolumePaths() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FileStorageVolumes.Ref
	|FROM
	|	Catalog.FileStorageVolumes AS FileStorageVolumes";

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		Object.FullPathLinux = Object.FullPathWindows;
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

// It rewrites all items in Files catalog.
Procedure OverwriteAllFiles() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Files.Ref
	|FROM
	|	Catalog.Files AS Files";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		Object.Write();
	EndDo;
	
EndProcedure

// IN the FileVersions catalog it fills FileModificationDate - from creation date.
Procedure FillFileModificationDate() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FileVersions.Ref
		|FROM
		|	Catalog.FileVersions AS FileVersions";

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		Object = Selection.Ref.GetObject();
		
		If Object.FileModificationDate = Date("00010101000000") Then
			Object.FileModificationDate = Object.CreationDate;
			Object.Write();
		EndIf;
		
	EndDo;
	
	OverwriteAllFiles(); // To move the values of FileModificationDate attribute from the version to the file.
	
EndProcedure

// It creates new files by analogy with the specified ones.
// Parameters:
//  FilesArray  - Array - CatalogRef.Files object array - existing files.
//  OwnerOfNewFile - AnyRef - file owner.
//
Procedure CopyFiles(FilesArray, OwnerOfNewFile) Export
	
	For Each File IN FilesArray Do
		NewFile = CopyFile(File, OwnerOfNewFile);
	EndDo;
	
EndProcedure
	
// It returns the array of references to files.
// Parameters:
//  Object - AnyRef - file owner.
//
// Returns:
//   Array - files array
Procedure GetAttachedFilesToObject(Object, FilesArray) Export
	
	If TypeOf(Object) = Type("CatalogRef.Files") Then
		FilesArray.Add(Object);
		Return;
	EndIf;
	
	CommandParameterTypes = Metadata.CommonCommands.AttachedFiles.CommandParameterType.Types();
	OwnerTypes = Metadata.Catalogs.Files.Attributes.FileOwner.Type.Types();
	
	If OwnerTypes.Find(TypeOf(Object)) <> Undefined
		AND CommandParameterTypes.Find(TypeOf(Object)) <> Undefined Then
		
		LocalFilesArray = GetAllSubordinateFiles(Object);
		For Each String IN LocalFilesArray Do
			FilesArray.Add(String);
		EndDo;
		
		Return;
		
	EndIf;
	
EndProcedure

// It writes the FileStorage to the infobase.
//
// Parameters:
// VersionRef - file version reference.
// FileStorage - ValueStorage with the file binary data to be written.
//
Procedure WriteFileToInformationBase(VersionRef, FileStorage) Export
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.VersionStoredFiles.CreateRecordManager();
	RecordManager.FileVersion = VersionRef;
	RecordManager.StoredFile = FileStorage;
	RecordManager.Write(True);
	
EndProcedure

// It deletes the record in the StoredVersionFiles register.
//
// Parameters:
// VersionRef - file version reference.
//
Procedure DeleteRecordFromStoragedFileVersionsRegister(VersionRef) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.VersionStoredFiles.CreateRecordSet();
	RecordSet.Filter.FileVersion.Set(VersionRef);
	RecordSet.Write();
	
EndProcedure

// Reads FileStorage from the infobase.
//
// Parameters:
// VersionRef - file version reference.
//
// Returns:
//   DataStorage with thew attachment binary data.
Function GetFileStorageFromInformationBase(VersionRef) Export
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.VersionStoredFiles.CreateRecordManager();
	RecordManager.FileVersion = VersionRef;
	RecordManager.Read();
	
	Return RecordManager.StoredFile;
	
EndFunction

// It transfers the binary file from FileStorage of FileVersions catalog to the VersionStoredFiles info register.
Procedure MoveFilesFromInformationBaseToInformationRegister() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FileVersions.Ref
	|FROM
	|	Catalog.FileVersions AS FileVersions
	|WHERE
	|	FileVersions.FileStorageType = &FileStorageType";
		
	Query.SetParameter("FileStorageType", Enums.FileStorageTypes.InInfobase);	

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		Object = Selection.Ref.GetObject();
		
		DataInStorage = Object.FileStorage.Get();
		If TypeOf(DataInStorage) = Type("BinaryData") Then
			WriteFileToInformationBase(Selection.Ref, Object.FileStorage);
			Object.FileStorage = New ValueStorage(""); // clear the value
			InfobaseUpdate.WriteData(Object);
		EndIf;
		
	EndDo;
	
EndProcedure

// It fills LoanDate field by the current date.
Procedure FillOccupationDate() Export
	
	SetPrivilegedMode(True);
	
	LoanDate = CurrentSessionDate();
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Files.Ref
		|FROM
		|	Catalog.Files AS Files";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Not Selection.Ref.IsEditing.IsEmpty() Then
			Object = Selection.Ref.GetObject();
			// To record a previously signed object.
			Object.AdditionalProperties.Insert("DigitallySignedObjectRecord", True);
			Object.LoanDate = LoanDate;
			InfobaseUpdate.WriteData(Object);
		EndIf;
	EndDo;
	
EndProcedure

// It renames old rights to new ones.
Procedure ReplaceRightsInFileFolderRightsSettings() Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	AccessControlModule = CommonUse.CommonModule("AccessManagement");
	
	ReplacementTable = AccessControlModule.RightReplacementTableInObjectRighsSettings();
	
	String = ReplacementTable.Add();
	String.OwnerType = Catalogs.FileFolders.EmptyRef();
	String.OldName = "FoldersAndFilesReading";
	String.NewName  = "Read";
	
	String = ReplacementTable.Add();
	String.OwnerType = Catalogs.FileFolders.EmptyRef();
	String.OldName = "AddingFoldersAndFiles";
	String.NewName  = "FilesAdd";
	
	String = ReplacementTable.Add();
	String.OwnerType = Catalogs.FileFolders.EmptyRef();
	String.OldName = "FoldersAndFilesChanging";
	String.NewName  = "FilesUpdate";
	
	String = ReplacementTable.Add();
	String.OwnerType = Catalogs.FileFolders.EmptyRef();
	String.OldName = "FoldersAndFilesChanging";
	String.NewName  = "FoldersUpdate";
	
	String = ReplacementTable.Add();
	String.OwnerType = Catalogs.FileFolders.EmptyRef();
	String.OldName = "FoldersAndFilesDeletionMark";
	String.NewName  = "FileDeletionMark";
	
	AccessControlModule.ReplaceRightsInObjectRightSettings(ReplacementTable);
	
EndProcedure

// It assigns Encrypted to the file.
Procedure SetSignEncrypted(FileRef, Encrypted, UUID = Undefined) Export
	
	FileObject = FileRef.GetObject();
	LockDataForEdit(FileRef, , UUID);
	
	FileObject.Encrypted = Encrypted;
	// To record a previously signed object.
	FileObject.AdditionalProperties.Insert("DigitallySignedObjectRecord", True);
	FileObject.Write();
	UnlockDataForEdit(FileRef, UUID);
	
EndProcedure

// It fills the file tabular section with the encryption certificate info.
Procedure AddInformationAboutEncryptionCertificates(FileRef, ThumbprintArray, UUID) Export
	
	BeginTransaction();
	Try
		
		FileObject = FileRef.GetObject();
		LockDataForEdit(FileRef, , UUID);
		
		For Each ThumbprintStructure IN ThumbprintArray Do
			NewRow = FileObject.EncryptionCertificates.Add();
			NewRow.Imprint = ThumbprintStructure.Imprint;
			NewRow.Presentation = ThumbprintStructure.Presentation;
			NewRow.Certificate = New ValueStorage(ThumbprintStructure.Certificate);
		EndDo;
		
		// To record a previously signed object.
		FileObject.AdditionalProperties.Insert("DigitallySignedObjectRecord", True);
		FileObject.Write();
		UnlockDataForEdit(FileRef, UUID);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Updates the file and current version size. It is necessary while loading an encrypted file in email.
Procedure RefreshFileAndVersionSize(FileData, FileSize, UUID) Export
	
	BeginTransaction();
	Try
		
		VersionObject = FileData.Version.GetObject();
		VersionObject.Lock();
		VersionObject.Size = FileSize;
		// To record a previously signed object.
		VersionObject.AdditionalProperties.Insert("DigitallySignedObjectRecord", True);
		VersionObject.Write();
		VersionObject.Unlock();
		
		FileObject = FileData.Ref.GetObject();
		LockDataForEdit(FileObject.Ref, , UUID);
		// To record a previously signed object.
		FileObject.AdditionalProperties.Insert("DigitallySignedObjectRecord", True);
		FileObject.Write();
		UnlockDataForEdit(FileObject.Ref, UUID);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// It receives the number of versions with the unextracted text.
Function GetVersionsNumberWithNotExtractedText() Export
	
	Query = New Query;
	
	Query.Text = 
	"SELECT
	|	COUNT(*) AS NumberOfVersions
	|FROM
	|	Catalog.FileVersions AS FileVersions
	|WHERE
	|	(FileVersions.TextExtractionStatus = VALUE(Enum.FileTextExtractionStatuses.NotExtracted)
	|			OR FileVersions.TextExtractionStatus = VALUE(Enum.FileTextExtractionStatuses.EmptyRef))
	|	AND Not FileVersions.Encrypted";
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Result = Selection.NumberOfVersions;
	
	Return Result;
	
EndFunction

// It returns the file size in the volume - in bytes.
Function CountSizeOfFilesOnVolume(RefOfVolume) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ISNULL(SUM(Versions.Size), 0) AS FilesSize
	|FROM
	|	Catalog.FileVersions AS Versions
	|WHERE
	|	Versions.Volume = &Volume";
	
	Query.Parameters.Insert("Volume", RefOfVolume);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return Number(Selection.FilesSize);
	EndIf;
	
	Return 0;
	
EndFunction

// It reads the file version encoding.
//
// Parameters:
// VersionRef - file version reference.
//
// Returns:
//   Encoding string
Function GetFileVersionEncoding(VersionRef) Export
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.FileVersionsEncodings.CreateRecordManager();
	RecordManager.FileVersion = VersionRef;
	RecordManager.Read();
	
	Return RecordManager.Encoding;
	
EndFunction

// Writes the file version encoding.
//
// Parameters:
// VersionRef - CatalogRef.FileVersions - file version reference.
// Encoding - String - new file version encoding.
//
Procedure WriteFileVersionEncoding(VersionRef, Encoding) Export
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.FileVersionsEncodings.CreateRecordManager();
	RecordManager.FileVersion = VersionRef;
	RecordManager.Encoding = Encoding;
	RecordManager.Write(True);
	
EndProcedure

// Writes the file version encoding.
//
// Parameters:
// VersionRef - file version reference.
// Encoding - Encoding string.
// ExtractedText - text extracted from the file.
//
Procedure WriteFileVersionEncodingAndExtractedText(VersionRef, Encoding, ExtractedText) Export
	
	WriteFileVersionEncoding(VersionRef, Encoding);
	WriteTextExtractionResult(VersionRef, Enums.FileTextExtractionStatuses.Extracted, 
		ExtractedText);
	
EndProcedure

// It writes the text extraction result to the server - extracted text and TextExtractionStatus.
Procedure WriteTextExtractionResult(VersionRef, ExtractionResult, TextTemporaryStorageAddress) Export
	
	FileLocked = False;
	File = VersionRef.Owner;
	
	If File.CurrentVersion = VersionRef Then
		
		Try
			LockDataForEdit(File);
			FileLocked = True;
		Except
			// Except if an object is already locked including using the Lock method.
			Return;
		EndTry;
		
	EndIf;
	
	Text = "";
	
	VersionObject = VersionRef.GetObject();
	
	If Not IsBlankString(TextTemporaryStorageAddress) Then
		
		If IsTempStorageURL(TextTemporaryStorageAddress) Then
			Text = FileFunctionsService.GetStringFromTemporaryStorage(TextTemporaryStorageAddress);
		Else	
			Text = TextTemporaryStorageAddress;
		EndIf;
		
		VersionObject.TextStorage = New ValueStorage(Text);
		VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		
	EndIf;
	
	If ExtractionResult = "NotExtracted" Then
		VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	ElsIf ExtractionResult = "Extracted" Then
		VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
	ElsIf ExtractionResult = "ExtractFailed" Then
		VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.ExtractFailed;
	EndIf;    
	
	Try
		BeginTransaction();
		
		// To record a previously signed object.
		VersionObject.AdditionalProperties.Insert("DigitallySignedObjectRecord", True);
		VersionObject.Write();
		
		If File.CurrentVersion = VersionRef Then
			FileObject = File.GetObject();
			FileObject.TextStorage = VersionObject.TextStorage;
			// To record a previously signed object.
			FileObject.AdditionalProperties.Insert("DigitallySignedObjectRecord", True);
			FileObject.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		If FileLocked Then
			UnlockDataForEdit(File);
		EndIf;
		
		Raise;
	EndTry;
	
	If FileLocked Then
		UnlockDataForEdit(File);
	EndIf;
	
EndProcedure

#EndRegion
