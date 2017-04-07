////////////////////////////////////////////////////////////////////////////////
// Subsystem "File functions".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceApplicationInterface

// Shows reminder describing how to work
// with file in web client if setting "Show tooltips when editing files" is enabled.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//
Procedure DisplayReminderOnEditing(ResultHandler) Export
	PersonalSettings = FileFunctionsServiceClientServer.PersonalFileOperationsSettings();
	If PersonalSettings.ShowFileEditTips = True Then
		If Not FileOperationsExtensionConnected() Then
			Form = FileFunctionsServiceClientReUse.GetFormOfReminderOnEditing();
			SetFormAlert(Form, ResultHandler);
			Form.Open();
			Return;
		EndIf;
	EndIf;
	ReturnResult(ResultHandler, Undefined);
EndProcedure

// Shows standard warning.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  CommandPresentation - String - Optional. Name of command for which the extension is required.
//
Procedure ShowWarningAboutNeedToFileOperationsExpansion(ResultHandler, CommandPresentation = "") Export
	If Not ClientSupportsSynchronousCalls() Then
		WarningText = NStr("en='Command ""%1"" can
		|not be executed in browser Google Chrome.';ru='Выполнение
		|команды ""%1"" в браузере Google Chrome не поддерживается.'");
	Else
		WarningText = NStr("en='For execution of command
		| ""%1"" you should install the extension for 1C: Enterprise web client.';ru='Для выполнения команды ""%1"" необходимо установить расширение для веб-клиента 1С:Предприятие.'");
	EndIf;
	If ValueIsFilled(CommandPresentation) Then
		WarningText = StrReplace(WarningText, "%1", CommandPresentation);
	Else
		WarningText = StrReplace(WarningText, " ""%1""", "");
	EndIf;
	ReturnResultAfterShowWarning(ResultHandler, WarningText, Undefined);
EndProcedure

// Returns path to user working directory.
Function UserWorkingDirectory() Export
	
	Return FileFunctionsServiceClientReUse.UserWorkingDirectory();
	
EndFunction

// Returns path to user working directory.
//
// Parameters:
//  Notification - NotifyDescription - warning after receipt of
//   working directory of the user. As a result, Structure with properties is returned:
//     * Directory        - String - full name of user working directory.
//     * ErrorDescription - String - text of error if directory can't be retrieved.
//
Procedure GetUserWorkingDirectory(Notification) Export
	
	FileFunctionsServiceClientReUse.GetUserWorkingDirectory(Notification);
	
EndProcedure

// Saves path to user working directory in the settings.
//
// Parameters:
//  DirectoryName - String - directory name.
//
Procedure SetUserWorkingDirectory(DirectoryName) Export
	
	CommonUseServerCall.CommonSettingsStorageSaveAndRefreshReusableValues(
		"LocalFilesCache", "PathToFilesLocalCache", DirectoryName);
	
EndProcedure

// Returns directory "My Documents" + name
// of current user or previously used folder for exports.
//
Function ExportDirectory() Export
	
	Path = "";
	
#If Not WebClient Then
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParameters();
	
	Path = CommonUseServerCall.CommonSettingsStorageImport("ExportFolderName", "ExportFolderName");
	
	If Path = Undefined Then
		If Not ClientParameters.ThisIsBasicConfigurationVersion Then
			Path = MyDocumentsDir();
			CommonUseServerCall.CommonSettingsStorageSave(
				"ExportFolderName", "ExportFolderName", Path);
		EndIf;
	EndIf;
	
#EndIf
	
	Return Path;
	
EndFunction

// Returns directory "My Documents".
//
Function MyDocumentsDir() Export
	Return DocumentsDir();
EndFunction

// Shows to user files selection dialog
// and returns the array - selected files for import.
//
Function GetImportedFilesList() Export
	
	FileOpeningDialog = New FileDialog(FileDialogMode.Open);
	FileOpeningDialog.FullFileName     = "";
	FileOpeningDialog.Filter             = NStr("en='All files(*.*)|*.*';ru='Все файлы(*.*)|*.*'");
	FileOpeningDialog.Multiselect = True;
	FileOpeningDialog.Title          = NStr("en='Select files';ru='Выбрать файлы'");
	
	FileNameArray = New Array;
	
	If FileOpeningDialog.Choose() Then
		FilesArray = FileOpeningDialog.SelectedFiles;
		
		For Each FileName IN FilesArray Do
			FileNameArray.Add(FileName);
		EndDo;
		
	EndIf;
	
	Return FileNameArray;
	
EndFunction

// Adds end slash to directory name if required,
// removes all prohibited characters from directory name and replaces "/" with "\".
//
Function NormalizeDirectory(DirectoryName) Export
	
	Result = TrimAll(DirectoryName);
	
	// Remember disk name in beginning of the path "Disk:" without the colon.
	StrDrive = "";
	If Mid(Result, 2, 1) = ":" Then
		StrDrive = Mid(Result, 1, 2);
		Result = Mid(Result, 3);
	Else
		
		// Check, it is not a UNC path (i.e. there is no "\\" in the beginning).
		If Mid(Result, 2, 2) = "\\" Then
			StrDrive = Mid(Result, 1, 2);
			Result = Mid(Result, 3);
		EndIf;
	EndIf;
	
	// Conversion of slashes to Windows format.
	Result = StrReplace(Result, "/", "\");
	
	// Insert final slash.
	Result = TrimAll(Result);
	If Right(Result,1) <> "\" Then
		Result = Result + "\";
	EndIf;
	
	// Replacement of all double slashes to single ones and receipt of full path.
	Result = StrDrive + StrReplace(Result, "\\", "\");
	
	Return Result;
	
EndFunction

// Checks attachment file name for incorrect characters.
//
// Parameters:
//  FileName - String- attachment file name to be checked.
//
//  DeleteIncorrectSymbols - Boolean - True suggests removing
//             invalid characters from transferred row.
//
Procedure CorrectFileName(FileName, DeleteIncorrectSymbols = False) Export
	
	// List of prohibited characters is taken from here: http://support.microsoft.com/kb/100108/ru
	// at the same time prohibited characters for FAT and NTFS file systems were combined.
	
	StrException = CommonUseClientServer.GetProhibitedCharsInFileName();
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='File name can not have symbols: %1';ru='В имени файла не должно быть следующих символов: %1'"), StrException);
	
	Result = True;
	
	FoundProhibitedCharArray =
		CommonUseClientServer.FindProhibitedCharsInFileName(FileName);
	
	If FoundProhibitedCharArray.Count() <> 0 Then
		
		Result = False;
		
		If DeleteIncorrectSymbols Then
			FileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(FileName, "");
		EndIf;
		
	EndIf;
	
	If Not Result Then
		Raise ErrorText;
	EndIf;
	
EndProcedure

// Bypasses the directories recursively and calculates the number of files and their total size.
Procedure BypassFilesSize(Path, FilesArray, TotalSize, QuantitySummary) Export
	
	For Each SelectedFile IN FilesArray Do
		
		If SelectedFile.IsDirectory() Then
			NewPath = String(Path);
			
			NewPath = NewPath + CommonUseClientServer.PathSeparator();
			
			NewPath = NewPath + String(SelectedFile.Name);
			FileArrayInDirectory = FindFiles(NewPath, "*.*");
			
			If FileArrayInDirectory.Count() <> 0 Then
				BypassFilesSize(
					NewPath, FileArrayInDirectory, TotalSize, QuantitySummary);
			EndIf;
		
			Continue;
		EndIf;
		
		TotalSize = TotalSize + SelectedFile.Size();
		QuantitySummary = QuantitySummary + 1;
		
	EndDo;
	
EndProcedure

// Returns the
// path to directory as: "C:\Documents and Settings\USER NAME\Application Data\1C\FilesA8\".
//
Function SelectPathToUserDataDirectory() Export
	
	DirectoryName = "";
	If FileOperationsExtensionConnected() Then
		DirectoryName = UserDataWorkDir();
	EndIf;
	
	Return DirectoryName;
	
EndFunction

// Returns the path to user data working directory. This directory
// is used as starting value for working directory of the user.
//
// Parameters:
//  Notification - NotifyDescription - warning after receipt of
//   working directory of the user. As a result, Structure with properties is returned:
//     * Directory        - String - Full name of user data working directory.
//     * ErrorDescription - String - text of error if directory can't be retrieved.
//
Procedure ReceiveUserDataWorkingDirectory(Notification) Export
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	
	BeginGettingUserDataWorkDir(New NotifyDescription(
		"ReceiveUserDataWorkingDirectoryAfterReceiving", ThisObject, Context,
		"ReceiveUserDataWorkingDirectoryAfterReceiptError", ThisObject));
	
EndProcedure

// Continue procedure ReceiveUserDataWorkingDirectory.
Procedure ReceiveUserDataWorkingDirectoryAfterReceiptError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	Result = New Structure;
	Result.Insert("Directory", "");
	Result.Insert("ErrorDescription", StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Failed to get working directory of user data
		|due to: %1';ru='Не удалось получить рабочий каталог данных
		|пользователя по причине: %1'"), BriefErrorDescription(ErrorInfo)));
	
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure

// Continue procedure ReceiveUserDataWorkingDirectory.
Procedure ReceiveUserDataWorkingDirectoryAfterReceiving(DirectoryDataUser, Context) Export
	
	Result = New Structure;
	Result.Insert("Directory", DirectoryDataUser);
	Result.Insert("ErrorDescription", "");
	
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure


// Opens Windows Explorer and selects specified file.
Function OpenExplorerWithFile(Val FullFileName) Export
	
	FileOnDrive = New File(FullFileName);
	
	If Not FileOnDrive.Exist() Then
		Return False;
	EndIf;
	
	If CommonUseClientServer.IsLinuxClient() Then
		RunApp(FileOnDrive.Path);
	Else
		RunApp("explorer.exe /select, """ + FileOnDrive.FullName + """");
	EndIf;
		
	Return True;
	
EndFunction

// Checks properties of the file in working
// directory and in files storage, inquires user if required and returns the action.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FileNameWithPath - String - full attachment file name with path in working directory.
// 
//  FileData    - Structure with properties:
//                   Size                       - Number.
//                   ModificationDateUniversal - Date.
//                   InWorkingDirectoryForRead     - Boolean.
//
// Returns:
//  String - possible rows:
//  "OpenExisting", "TakeFromStorageAndOpen", "Cancel".
// 
Procedure ActionOnFileOpeningInWorkingDirectory(ResultHandler, FileNameWithPath, FileData) Export
	
	If FileData.Property("UpdatePathFromFileOnDrive") Then
		ReturnResult(ResultHandler, "TakeFromStorageAndOpen");
		Return;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("ActionWithFile", "OpeningInWorkingDirectory");
	Parameters.Insert("FullFileNameInWorkingDirectory", FileNameWithPath);
	
	File = New File(Parameters.FullFileNameInWorkingDirectory);
	
	Parameters.Insert("UniversalModificationDateInFileStorage",
		FileData.ModificationDateUniversal);
	
	Parameters.Insert("UniversalModificationDateInWorkingDirectory",
		File.GetModificationUniversalTime());
	
	Parameters.Insert("ModificationDateInWorkingDirectory",
		ToLocalTime(Parameters.UniversalModificationDateInWorkingDirectory));
	
	Parameters.Insert("ModificationDateInFileStorage",
		ToLocalTime(Parameters.UniversalModificationDateInFileStorage));
	
	Parameters.Insert("SizeInWorkingDirectory", File.Size());
	Parameters.Insert("SizeInFileStorage", FileData.Size);
	
	DATEDIFFerence = Parameters.UniversalModificationDateInWorkingDirectory
	           - Parameters.UniversalModificationDateInFileStorage;
	
	If DATEDIFFerence < 0 Then
		DATEDIFFerence = -DATEDIFFerence;
	EndIf;
	
	If DATEDIFFerence <= 1 Then // From second - allowable difference (can be in Win95).
		
		If Parameters.SizeInFileStorage <> 0
		   AND Parameters.SizeInFileStorage <> Parameters.SizeInWorkingDirectory Then
			// Date is the same but the size is different - rare but possible case.
			
			Parameters.Insert("Title",
				NStr("en='The file size differs';ru='Размер файла отличается'"));
			
			Parameters.Insert("Message",
				NStr("en='File size in working directory and files storage is different.
		|
		|Take a file from files storage and replace the
		|existing file with it or open existing file without update?';ru='Размер файла в рабочем каталоге и в хранилище файлов отличается.
		|
		|Взять файл из хранилища файлов и
		|заменить им существующий или открыть существующий без обновления?'"));
		Else
			// All matches - both date and size.
			ReturnResult(ResultHandler, "OpenExisting");
			Return;
		EndIf;
		
	ElsIf Parameters.UniversalModificationDateInWorkingDirectory
	        < Parameters.UniversalModificationDateInFileStorage Then
		// There is a newer file in file storage.
		
		If FileData.InWorkingDirectoryForRead = False Then
			// File in working directory for editing.
			
			Parameters.Insert("Title", NStr("en='New file in the file storage';ru='В хранилище файлов новый файл'"));
			
			Parameters.Insert("Message",
				NStr("en='File in files storage marked as locked
		|for editing has later modification date (newer) than in working directory.
		|
		|Take a file from files storage and replace the
		|existing file with it or open existing file without update?';ru='Файл в хранилище файлов, отмеченный
		|как занятый для редактирования, имеет более позднюю дату изменения (новее), чем в рабочем каталоге.
		|
		|Взять файл из хранилища файлов и
		|заменить им существующий или открыть существующий без обновления?'"));
		Else
			// File in working directory for reading.
			
			// Update from files storage without questions.
			ReturnResult(ResultHandler, "TakeFromStorageAndOpen");
			Return;
		EndIf;
	
	ElsIf Parameters.UniversalModificationDateInWorkingDirectory
	        > Parameters.UniversalModificationDateInFileStorage Then
		// There is a newer file in working directory.
		
		If FileData.InWorkingDirectoryForRead = False
		   AND FileData.IsEditing = UsersClientServer.CurrentUser() Then
			
			// File in working directory is for editing and it is in use by current user.
			ReturnResult(ResultHandler, "OpenExisting");
			Return;
		Else
			// File in working directory for reading.
		
			Parameters.Insert("Title", NStr("en='New file in the work directory';ru='В рабочем каталоге новый файл'"));
			
			Parameters.Insert(
				"Message",
				NStr("en='File in working directory has later modification date
		|(newer), than in files storage. It may have been changed.
		|
		|Open existing file or replace it with
		|file from files storage with loss of changes and open?';ru='Файл в рабочем каталоге имеет более
		|позднюю дату изменения (новее), чем в хранилище файлов. Возможно, он был изменен.
		|
		|Открыть существующий файл или
		|заменить его на файл из хранилища файлов c потерей изменений и открыть?'"));
		EndIf;
	EndIf;
	
	// ActionSelectionWhenFileDifferencesDetected
	OpenForm("CommonForm.ActionSelectionWhenFileDifferencesDetected", Parameters, , , , , ResultHandler, FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure

// Returns the result of files extension connection.
//
//  Returns:
//   Boolean - always True in thin client, always False
//            in Google Chrome.
//
Function FileOperationsExtensionConnected() Export
	If ClientSupportsSynchronousCalls() Then
		Return AttachFileSystemExtension();
	Else
		Return False;
	EndIf;
EndFunction

// See procedure description in CommonUseClient.ShowQuestionFilesExtensionInstallation.
//
Procedure ShowQuestionAboutFileOperationsExtensionSetting(NOTifyDescription) Export
	If Not ClientSupportsSynchronousCalls() Then
		ExecuteNotifyProcessing(NOTifyDescription, False);
	Else
		CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NOTifyDescription);
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of work with cryptography.

// Check signatures of object data in the table.
// 
// Parameters:
//  Form - ManagedForm - with attributes:
//    * Object - FormDataStructure - as the object with properties Reference, Encrypted.
//                  For example, CatalogObject.File, CatalogObject.DocumentAttachedFiles.
//
//    * DigitalSignatures - FormDataCollection - with fields:
//       * Status       - String - (return value) - checking result.
//       * SignatureAddress - address of signature data in temporary storage.
//
//  ReferenceToBinaryData - BinaryData - binary data of file.
//                         - String - address in temporary storage or navigation reference.
//
//  SelectedRows - Array - property of table of parameter form DigitalSignatures.
//                   - Undefined - check all signatures.
//
Procedure CheckSignatures(Form, ReferenceToBinaryData, SelectedRows = Undefined) Export
	
	// 1. Receive address of binary data, addresses of signatures binary data.
	// 2. If the file is encrypted, decrypt it and then start the check.
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Form", Form);
	AdditionalParameters.Insert("SelectedRows", SelectedRows);
	
	If Not Form.Object.Encrypted Then
		CheckSignaturesAfterDataPreparation(ReferenceToBinaryData, AdditionalParameters);
		Return;
	EndIf;
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	DataDescription = New Structure;
	DataDescription.Insert("Operation",              NStr("en='File encryption';ru='Шифрование файла'"));
	DataDescription.Insert("DataTitle",       NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("Data",                ReferenceToBinaryData);
	DataDescription.Insert("Presentation",         Form.Object.Ref);
	DataDescription.Insert("EncryptionCertificates", Form.Object.Ref);
	DataDescription.Insert("NotifyAboutCompletion",   False);
	
	ContinuationHandler = New NotifyDescription("AfterFileDecryption", ThisObject, AdditionalParameters);
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.Decrypt(DataDescription, , ContinuationHandler);
	
EndProcedure

// Continue procedure CheckSignatures. Called from the DigitalSignature subsystem.
Procedure AfterFileDecryption(DataDescription, AdditionalParameters) Export
	
	If Not DataDescription.Success Then
		Return;
	EndIf;
	
	CheckSignaturesAfterDataPreparation(DataDescription.DecryptedData, AdditionalParameters);
	
EndProcedure

// Continue procedure CheckSignatures.
Procedure CheckSignaturesAfterDataPreparation(Data, AdditionalParameters)
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	ModuleDigitalSignatureClientServer = CommonUseClient.CommonModule("DigitalSignatureClientServer");
	
	VerifyDigitalSignaturesAtServer = ModuleDigitalSignatureClientServer.CommonSettings(
		).VerifyDigitalSignaturesAtServer;
	
	If AdditionalParameters.SelectedRows = Undefined Then
		Collection = AdditionalParameters.Form.DigitalSignatures;
	Else
		Collection = AdditionalParameters.SelectedRows;
	EndIf;
	
	If Not VerifyDigitalSignaturesAtServer Then
		ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
		AdditionalParameters.Insert("Data", Data);
		AdditionalParameters.Insert("Collection", Collection);
		AdditionalParameters.Insert("ModuleDigitalSignatureClient", ModuleDigitalSignatureClient);
		ModuleDigitalSignatureClient.CreateCryptoManager(
			New NotifyDescription("CheckSignaturesAfterCreatingCryptographicManager",
				ThisObject, AdditionalParameters),
			"SignatureCheck");
		Return;
	EndIf;
	
	If TypeOf(Data) = Type("BinaryData") Then
		DataAddress = PutToTempStorage(Data, AdditionalParameters.FormID);
	Else
		DataAddress = Data;
	EndIf;
	
	RowsData = New Array;
	
	For Each Item IN Collection Do
		SignatureRow = ?(TypeOf(Item) <> Type("Number"), Item,
			AdditionalParameters.Form.DigitalSignatures.FindByID(Item));
		
		RowData = New Structure;
		RowData.Insert("SignatureAddress", SignatureRow.SignatureAddress);
		RowData.Insert("Status",       SignatureRow.Status);
		RowData.Insert("Wrong",      SignatureRow.Wrong);
		RowsData.Add(RowData);
	EndDo;
	
	FileFunctionsServiceServerCall.CheckSignatures(DataAddress, RowsData);
	
	IndexOf = 0;
	For Each Item IN Collection Do
		SignatureRow = ?(TypeOf(Item) <> Type("Number"), Item,
			AdditionalParameters.Form.DigitalSignatures.FindByID(Item));
		
		SignatureRow.Status  = RowsData[IndexOf].Status;
		SignatureRow.Wrong = RowsData[IndexOf].Wrong;
		IndexOf = IndexOf + 1;
	EndDo;
	
EndProcedure

// Continue procedure CheckSignatures.
Procedure CheckSignaturesAfterCreatingCryptographicManager(CryptoManager, AdditionalParameters) Export
	
	If TypeOf(CryptoManager) <> Type("CryptoManager") Then
		Return;
	EndIf;
	
	AdditionalParameters.Insert("IndexOf", -1);
	AdditionalParameters.Insert("CryptoManager", CryptoManager);
	
	CheckSignaturesCycleStart(AdditionalParameters);
	
EndProcedure

// Continue procedure CheckSignatures.
Procedure CheckSignaturesCycleStart(AdditionalParameters)
	
	If AdditionalParameters.Collection.Count() <= AdditionalParameters.IndexOf + 1 Then
		AdditionalParameters.Form.RefreshDataRepresentation();
		Return;
	EndIf;
	
	AdditionalParameters.IndexOf = AdditionalParameters.IndexOf + 1;
	Item = AdditionalParameters.Collection[AdditionalParameters.IndexOf];
	
	AdditionalParameters.Insert("SignatureRow", ?(TypeOf(Item) <> Type("Number"), Item,
		AdditionalParameters.Form.DigitalSignatures.FindByID(Item)));
		
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.VerifySignature(
		New NotifyDescription("CheckSignaturesAfterRowCheck", ThisObject, AdditionalParameters),
		AdditionalParameters.Data,
		AdditionalParameters.SignatureRow.SignatureAddress,
		AdditionalParameters.CryptoManager);
	
EndProcedure

// Continue procedure CheckSignatures.
Procedure CheckSignaturesAfterRowCheck(Result, AdditionalParameters) Export
	
	SignatureRow = AdditionalParameters.SignatureRow;
	
	If Result = True Then
		SignatureRow.Status  = NStr("en='Correct';ru='Исправить'");
		SignatureRow.Wrong = False;
	Else
		SignatureRow.Status  = NStr("en='Wrong';ru='Неверна'") + ". " + String(Result);
		SignatureRow.Wrong = True;
	EndIf;
	
	CheckSignaturesCycleStart(AdditionalParameters);
	
EndProcedure

// For file form.
Procedure SetEnabledForElectronicSignaturesCommandsList(Form) Export
	
	Items = Form.Items;
	HasSignatures = (Form.DigitalSignatures.Count() <> 0);
	
	Items.DigitalSignaturesOpen.Enabled      = HasSignatures;
	Items.DigitalSignaturesValidate.Enabled    = HasSignatures;
	Items.DigitalSignaturesValidateAll.Enabled = HasSignatures;
	Items.DigitalSignaturesSave.Enabled    = HasSignatures;
	Items.DigitalSignaturesDelete.Enabled      = HasSignatures;
	
EndProcedure

// For file form.
Procedure SetEnabledForEncryptionCertificatesListCommands(Form) Export
	
	Object   = Form.Object;
	Items = Form.Items;
	
	Items.EncryptionCertificatesOpen.Enabled = Object.Encrypted;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions of work with files of the operating system.

// Executes the package of noninteractive actions with file.
// If the file does not exist, the actions will not be skipped.
//
// You can receive the following properties: Name, NameWithoutExtension, FullName,
//    Path, Extension, Exists, ModificationTime, UniversalModificationTime, ReadOnly, Invisible, Size, ThisIsDirectory, ThisIsFile.
//
// You can set the following properties: ModificationTime, UniversalModificationTime, ReadOnly, Invisible.
// You can execute actions with file: Delete.
//
// Parameters:
//  Notification - NotifyDescription - warning executed
//   after file actions. As a result, Structure with properties is returned:
//     * ErrorDescription - String - text of the error if one of actions could not be executed.
//     * Results     - Array - contains a result of each action as a structure:
//             * File       - File - initialized object file.
//                          - Undefined - file initialization error.
//             * Exists - Boolean - False if the file does not exist.
//
//  ActionsWithFile - Array - containing structures with name and parameters of the action;
//    * Action - String    - GetProperties, SetProperties,
//                             Delete, CopyFromSource, CreateDirectory, Get, Place.
//    * File     - String    - full name of the file on computer.
//               - File      - initialized object File.
//    * Properties - Structure - see properties that you can receive or set.
//    * Source - String    - full name of the file on computer from which the copy should be created.
//    * Address    - String    - address of file binary data, for example, address of temporary storage.
//    * ErrorTitle - String - text to which line feed and error presentation shall be added.
//
Procedure HandleFile(Notification, ActionsWithFile, FormID = Undefined) Export
	
	Context = New Structure;
	Context.Insert("Notification",         Notification);
	Context.Insert("ActionsWithFile",    ActionsWithFile);
	Context.Insert("FormID", FormID);
	
	Context.Insert("ActionsResult", New Structure);
	Context.ActionsResult.Insert("ErrorDescription", "");
	Context.ActionsResult.Insert("Results", New Array);
	
	Context.Insert("IndexOf", -1);
	HandleFileCycleStart(Context);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions


// Continue procedure HandleFile.
Procedure HandleFileCycleStart(Context)
	
	If Context.IndexOf + 1 >= Context.ActionsWithFile.Count() Then
		ExecuteNotifyProcessing(Context.Notification, Context.ActionsResult);
		Return;
	EndIf;
	
	Context.IndexOf = Context.IndexOf + 1;
	Context.Insert("ActionsDetails", Context.ActionsWithFile[Context.IndexOf]);
	
	Context.Insert("Result",  New Structure);
	Context.Result.Insert("File", Undefined);
	Context.Result.Insert("Exist", False);
	
	Context.ActionsResult.Results.Add(Context.Result);
	
	Context.Insert("PropertiesForReceiving", New Structure);
	Context.Insert("PropertiesForSetup", New Structure);
	
	Action = Context.ActionsDetails.Action;
	File = Context.ActionsDetails.File;
	FullFileName = ?(TypeOf(File) = Type("File"), File.FullName, File);
	
	If Action = "Delete" Then
		BeginDeletingFiles(New NotifyDescription(
			"HandleFileAfterDeletingFiles", ThisObject, Context,
			"HandleFileAfterError", ThisObject), FullFileName);
		Return;
	
	ElsIf Action = "CopyFromSource" Then
		BeginCopyingFile(New NotifyDescription(
			"HandleFileAfterCopyingFile", ThisObject, Context,
			"HandleFileAfterError", ThisObject), Context.ActionsDetails.Source, FullFileName);
		Return;
	
	ElsIf Action = "CreateDirectory" Then
		BeginCreatingDirectory(New NotifyDescription(
			"HandleFileAfterCreatingDirectory", ThisObject, Context,
			"HandleFileAfterError", ThisObject), FullFileName);
		Return;
	
	ElsIf Action = "Get" Then
		FileDescription = New TransferableFileDescription(FullFileName, Context.ActionsDetails.Address);
		FilesToReceive = New Array;
		FilesToReceive.Add(FileDescription);
		BeginGettingFiles(New NotifyDescription(
				"HandleFileAfterReceivingFiles", ThisObject, Context,
				"HandleFileAfterError", ThisObject),
			FilesToReceive, , False);
		Return;
	
	ElsIf Action = "Place" Then
		FileDescription = New TransferableFileDescription(FullFileName);
		FilesToPlace = New Array;
		FilesToPlace.Add(FileDescription);
		BeginPuttingFiles(New NotifyDescription(
				"HandleFileAfterPlacingFiles", ThisObject, Context,
				"HandleFileAfterError", ThisObject),
			FilesToPlace, , False, Context.FormID);
		Return;
	
	ElsIf Action = "GetProperties" Then
		Context.Insert("PropertiesForReceiving", Context.ActionsDetails.Properties);
		
	ElsIf Action = "SetProperties" Then
		Context.Insert("PropertiesForSetup", Context.ActionsDetails.Properties);
	EndIf;
	
	If TypeOf(File) = Type("File") Then
		Context.Insert("File", File);
		HandleFileAfterFileInitialization(File, Context);
	Else
		Context.Insert("File", New File);
		Context.File.BeginInitialization(New NotifyDescription(
			"HandleFileAfterFileInitialization", ThisObject, Context,
			"HandleFileAfterError", ThisObject), File);
	EndIf;
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	If TypeOf(ErrorInfo) = Type("ErrorInfo") Then
		Context.ActionsResult.ErrorDescription = BriefErrorDescription(ErrorInfo);
	Else
		Context.ActionsResult.ErrorDescription = ErrorInfo;
	EndIf;
	
	If Context.ActionsDetails.Property("ErrorTitle") Then
		Context.ActionsResult.ErrorDescription = Context.ActionsDetails.ErrorTitle
			+ Chars.LF + Context.ActionsResult.ErrorDescription;
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, Context.ActionsResult);
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterDeletingFiles(Context) Export
	
	HandleFileCycleStart(Context);
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterCopyingFile(CopiedFile, Context) Export
	
	HandleFileCycleStart(Context);
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterCreatingDirectory(Directory, Context) Export
	
	HandleFileCycleStart(Context);
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterReceivingFiles(ReceivedFiles, Context) Export
	
	If TypeOf(ReceivedFiles) <> Type("Array") Or ReceivedFiles.Count() = 0 Then
		HandleFileAfterError(NStr("en='File receiving was canceled.';ru='Получение файла было отменено.'"), , Context);
		Return;
	EndIf;
	
	HandleFileCycleStart(Context);
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterPlacingFiles(PlacedFiles, Context) Export
	
	If TypeOf(PlacedFiles) <> Type("Array") Or PlacedFiles.Count() = 0 Then
		HandleFileAfterError(NStr("en='Place filewas canceled.';ru='Помещение файла было отменено.'"), , Context);
		Return;
	EndIf;
	
	Context.ActionsDetails.Insert("Address", PlacedFiles[0].Location);
	
	HandleFileCycleStart(Context);
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterFileInitialization(File, Context) Export
	
	Context.Insert("File", File);
	Context.Result.Insert("File", File);
	FillPropertyValues(Context.PropertiesForReceiving, File);
	
	Context.File.StartExistenceCheck(New NotifyDescription(
		"HandleFileAfterCheckingExistence", ThisObject, Context,
		"HandleFileAfterError", ThisObject));
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterCheckingExistence(Exist, Context) Export
	
	Context.Result.Insert("Exist", Exist);
	
	If Not Context.Result.Exist Then
		HandleFileCycleStart(Context);
		Return;
	EndIf;
	
	If Context.PropertiesForReceiving.Count() = 0 Then
		HandleFileAfterCheckThisIsFile(Null, Context);
		
	ElsIf Context.PropertiesForReceiving.Property("ModifiedAt") Then
		Context.File.StartReceivingModificationTime(New NotifyDescription(
			"HandleFileAfterReceivingModificationTime", ThisObject, Context,
			"HandleFileAfterError", ThisObject));
	Else
		HandleFileAfterReceivingModificationTime(Null, Context);
	EndIf;
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterReceivingModificationTime(ModifiedAt, Context) Export
	
	If ModifiedAt <> Null Then
		Context.PropertiesForReceiving.ModifiedAt = ModifiedAt;
	EndIf;
	
	If Context.PropertiesForReceiving.Property("UniversalModificationTime") Then
		Context.File.StartReceivingUniversalModificationTime(New NotifyDescription(
			"HandleFileAfterReceivingUniversalModificationTime", ThisObject, Context,
			"HandleFileAfterError", ThisObject));
	Else
		HandleFileAfterReceivingUniversalModificationTime(Null, Context);
	EndIf;
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterReceivingUniversalModificationTime(UniversalModificationTime, Context) Export
	
	If UniversalModificationTime <> Null Then
		Context.PropertiesForReceiving.UniversalModificationTime = UniversalModificationTime;
	EndIf;
	
	If Context.PropertiesForReceiving.Property("ReadOnly") Then
		Context.File.StartReceivingReadOnly(New NotifyDescription(
			"HandleFileAfterReceivingReadOnly", ThisObject, Context,
			"HandleFileAfterError", ThisObject));
	Else
		HandleFileAfterReceivingReadOnly(Null, Context);
	EndIf;
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterReceivingReadOnly(ReadOnly, Context) Export
	
	If ReadOnly <> Null Then
		Context.PropertiesForReceiving.ReadOnly = ReadOnly;
	EndIf;
	
	If Context.PropertiesForReceiving.Property("Invisible") Then
		Context.File.StartReceivingInvisible(New NotifyDescription(
			"HandleFileAfterReceivingInvisible", ThisObject, Context,
			"HandleFileAfterError", ThisObject));
	Else
		HandleFileAfterReceivingInvisible(Null, Context);
	EndIf;
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterReceivingInvisible(Invisible, Context) Export
	
	If Invisible <> Null Then
		Context.PropertiesForReceiving.Invisible = Invisible;
	EndIf;
	
	If Context.PropertiesForReceiving.Property("Size") Then
		Context.File.BeginGettingSize(New NotifyDescription(
			"HandleFileAfterReceivingSize", ThisObject, Context,
			"HandleFileAfterError", ThisObject));
	Else
		HandleFileAfterReceivingSize(Null, Context);
	EndIf;
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterReceivingSize(Size, Context) Export
	
	If Size <> Null Then
		Context.PropertiesForReceiving.Size = Size;
	EndIf;
	
	If Context.PropertiesForReceiving.Property("IsDirectory") Then
		Context.File.StartCheckingIsDirectory(New NotifyDescription(
			"HandleFileAfterCheckThisIsDirectory", ThisObject, Context,
			"HandleFileAfterError", ThisObject));
	Else
		HandleFileAfterCheckThisIsDirectory(Null, Context);
	EndIf;
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterCheckThisIsDirectory(IsDirectory, Context) Export
	
	If IsDirectory <> Null Then
		Context.PropertiesForReceiving.IsDirectory = IsDirectory;
	EndIf;
	
	If Context.PropertiesForReceiving.Property("IsFile") Then
		Context.File.StartCheckingThisIsFile(New NotifyDescription(
			"HandleFileAfterCheckThisIsFile", ThisObject, Context,
			"HandleFileAfterError", ThisObject));
	Else
		HandleFileAfterCheckThisIsFile(Null, Context);
	EndIf;
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterCheckThisIsFile(IsFile, Context) Export
	
	If IsFile <> Null Then
		Context.PropertiesForReceiving.IsFile = IsFile;
	EndIf;
	
	If Context.PropertiesForSetup.Count() = 0 Then
		HandleFileAfterSettingInvisible(Context);
		
	ElsIf Context.PropertiesForSetup.Property("ModifiedAt") Then
		Context.File.StartSettingModificationTime(New NotifyDescription(
			"HandleFileAfterSettingModificationTime", ThisObject, Context,
			"HandleFileAfterError", ThisObject), Context.PropertiesForSetup.ModifiedAt);
	Else
		HandleFileAfterSettingModificationTime(Context);
	EndIf;
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterSettingModificationTime(Context) Export
	
	If Context.PropertiesForSetup.Property("UniversalModificationTime") Then
		Context.File.StartSettingUniversalModificationTime(New NotifyDescription(
			"HandleFileAfterSettingUniversalModificationTime", ThisObject, Context,
			"HandleFileAfterError", ThisObject), Context.PropertiesForSetup.UniversalModificationTime);
	Else
		HandleFileAfterSettingUniversalModificationTime(Context);
	EndIf;
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterSettingUniversalModificationTime(Context) Export
	
	If Context.PropertiesForSetup.Property("ReadOnly") Then
		Context.File.StartSettingReadOnly(New NotifyDescription(
			"HandleFileAfterSettingReadOnly", ThisObject, Context,
			"HandleFileAfterError", ThisObject), Context.PropertiesForSetup.ReadOnly);
	Else
		HandleFileAfterSettingReadOnly(Context);
	EndIf;
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterSettingReadOnly(Context) Export
	
	If Context.PropertiesForSetup.Property("Invisible") Then
		Context.File.StartSettingInvisible(New NotifyDescription(
			"HandleFileAfterSettingInvisible", ThisObject, Context,
			"HandleFileAfterError", ThisObject), Context.PropertiesForSetup.Invisible);
	Else
		HandleFileAfterSettingInvisible(Context);
	EndIf;
	
EndProcedure

// Continue procedure HandleFile.
Procedure HandleFileAfterSettingInvisible(Context) Export
	
	HandleFileCycleStart(Context);
	
EndProcedure


#If Not WebClient Then
// Retrieves text from file on disk on client and places the result on server.
Procedure ExtractVersionText(FileOrFileVersion,
                             FileURL,
                             Extension,
                             UUID,
                             Encoding = Undefined) Export
	
	FileNameWithPath = GetTempFileName(Extension);
	
	If Not GetFile(FileURL, FileNameWithPath, False) Then
		Return;
	EndIf;
	
	// For option with storage of files on disk
	// (on server) a file is deleted from temporary storage after receipt.
	If IsTempStorageURL(FileURL) Then
		DeleteFromTempStorage(FileURL);
	EndIf;
	
	ExtractionResult = "NotExtracted";
	TextTemporaryStorageAddress = "";
	
	Text = "";
	If FileNameWithPath <> "" Then
		
		// Text extraction from file.
		Cancel = False;
		Text = FileFunctionsServiceClientServer.ExtractText(FileNameWithPath, Cancel, Encoding);
		
		If Cancel = False Then
			ExtractionResult = "Extracted";
			
			If Not IsBlankString(Text) Then
				TempFileName = GetTempFileName();
				TextFile = New TextWriter(TempFileName, TextEncoding.UTF8);
				TextFile.Write(Text);
				TextFile.Close();
				
				ImportResult = PutFileFromDiskToTemporaryStorage(TempFileName, , UUID);
				If ImportResult <> Undefined Then
					TextTemporaryStorageAddress = ImportResult;
				EndIf;
				
				DeleteFiles(TempFileName);
			EndIf;
		Else
			// When Text extract "nobody" - this is
			// a normal case, error message is not generated.
			ExtractionResult = "ExtractFailed";
		EndIf;
		
	EndIf;
	
	DeleteFiles(FileNameWithPath);
	
	FileFunctionsServiceServerCall.WriteTextExtractionResult(
		FileOrFileVersion, ExtractionResult, TextTemporaryStorageAddress);
	
EndProcedure
#EndIf

// Imports file from client to temporary storage on server. Does not work without files extension.
Function PutFileFromDiskToTemporaryStorage(FullFileName, FileURL = "", UUID = Undefined) Export
	If Not FileOperationsExtensionConnected() Then
		Return Undefined;
	EndIf;
	WhatToImport = New Array;
	WhatToImport.Add(New TransferableFileDescription(FullFileName, FileURL));
	ImportResult = New Array;
	FileImported = PutFiles(WhatToImport, ImportResult, , False, UUID);
	If Not FileImported Or ImportResult.Count() = 0 Then
		Return Undefined;
	EndIf;
	Return ImportResult[0].Location;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedure for the support of asynchronous model.
//
// Common description of parameters:
//   ResultHandler - Procedure-handler of asynchronous method.
//       - Undefined - No processing is required.
//       - NotifyDescription - Description of procedure-handler.
//   Result - Arbitrary - Value to be returned to ResultHandler.

// Shows text and calls the handler with specified result.
Procedure ReturnResultAfterShowWarning(ResultHandler, WarningText, Result) Export
	If TypeOf(ResultHandler) = Type("NotifyDescription") Then
		HandlerParameters = New Structure;
		HandlerParameters.Insert("ResultHandler", ResultHandler);
		HandlerParameters.Insert("Result",             Result);
		Handler = New NotifyDescription("ReturnResultAfterSimpleDialogClosing", ThisObject, HandlerParameters);
		ShowMessageBox(Handler, WarningText);
	Else
		ShowMessageBox(, WarningText);
	EndIf;
EndProcedure

// result handler of procedure ReturnResultAfterShowingWarning.
Procedure ReturnResultAfterSimpleDialogClosing(Structure) Export
	ExecuteNotifyProcessing(Structure.ResultHandler, Structure.Result);
EndProcedure

// Returns the result of direct call when dialog opening was not required.
Procedure ReturnResult(ResultHandler, Result) Export
	If TypeOf(ResultHandler) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(ResultHandler, Result);
	EndIf;
EndProcedure

// Sets window closing handler of the form received with method GetForm.
Procedure SetFormAlert(Form, ResultHandler)
	If TypeOf(ResultHandler) = Type("NotifyDescription") Then
		Form.OnCloseNotifyDescription = ResultHandler;
	EndIf;
EndProcedure

Function ClientSupportsSynchronousCalls()
	
#If WebClient Then
	// Cannot connect the extension in Google Chrome.
	SystemInfo = New SystemInfo;
	ApplicationInformationArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(
		SystemInfo.UserAgentInformation, " ");
	
	For Each ApplicationInformation IN ApplicationInformationArray Do
		If Find(ApplicationInformation, "Chrome") > 0 Then
			Return False;
		EndIf;
	EndDo;
#EndIf
	
	Return True;
	
EndFunction

#EndRegion
