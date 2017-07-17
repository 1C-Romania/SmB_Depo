////////////////////////////////////////////////////////////////////////////////
// Subsystem "Working with files".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceApplicationInterface

// Opens folder form with the list of files.
//
// Parameters:
//   StandardProcessing - Boolean - Passed as is from the parameters of "Opening" handler.
//   Folder - CatalogRef.Files - Opened folder.
//
// Usage location:
//   Catalog.ReportMailings.Form.ItemForm.FolderOpening().
//
Procedure ReportMailingViewFolders(StandardProcessing, Folder) Export
	
	StandardProcessing = False;
	FormParameters = New Structure("Folder", Folder);
	OpenForm("Catalog.Files.Form.Files", FormParameters, , Folder);
	
EndProcedure

// Creates a list of alerts for user on application exit.
//
// Parameters:
// see OnReceiveListOfEndWorkWarning.
//
Procedure OnExit(Warnings) Export
	
	Response = CheckLockedFilesOnExit();
	If Response = Undefined Then 
		Return;
	EndIf;
	
	If TypeOf(Response) <> Type("Structure") Then
		Return;
	EndIf;
	
	UserWarning = StandardSubsystemsClient.AlertOnEndWork();
	UserWarning.HyperlinkText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Open list of edited files (%1)';ru='Открыть список редактируемых файлов (%1)'"),
		Response.CountEmployedFiles);
	
	ActionOnHyperlinkClick = UserWarning.ActionOnHyperlinkClick;
	
	ApplicationWarningForm = Undefined;
	Response.Property("ApplicationWarningForm", ApplicationWarningForm);
	ApplicationWarningFormParameters = Undefined;
	Response.Property("ApplicationWarningFormParameters", ApplicationWarningFormParameters);
	
	Form = Undefined;
	Response.Property("Form", Form);
	FormParameters = Undefined;
	Response.Property("FormParameters", FormParameters);
	
	If ApplicationWarningForm <> Undefined Then 
		ActionOnHyperlinkClick.ApplicationWarningForm = ApplicationWarningForm;
		ActionOnHyperlinkClick.ApplicationWarningFormParameters = ApplicationWarningFormParameters;
	EndIf;
	If Form <> Undefined Then 
		ActionOnHyperlinkClick.Form = Form;
		ActionOnHyperlinkClick.FormParameters = FormParameters;
	EndIf;
	
	Warnings.Add(UserWarning);
	
EndProcedure	

Procedure TransferAllFilesInVolumes() Export
	
	OpenForm("DataProcessor.TransferFilesToVolumes.Form");
	
EndProcedure	

#EndRegion

#Region ServiceProceduresAndFunctions

// Checks whether File can be released.
//
// Parameters:
//  ObjectRef - CatalogRef.Files - file.
//
//  CurrentUserIsEditing - Boolean -
//                 current user is editing the file.
//
//  IsEditing  - CatalogRef.Users - user who locked the file.
//
//  ErrorString - String in which error cause is returned
//                 in case of failure (e.g. "file is locked by another user").
//
// Returns:
//  Boolean. True if the file can be released.
//
Function PossibilityToReleaseFile(ObjectRef,
                                  CurrentUserIsEditing,
                                  IsEditing,
                                  ErrorString = "") Export
	
	If CurrentUserIsEditing Then 
		Return True;
	ElsIf IsEditing.IsEmpty() Then
		ErrorString = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Impossible to unlock
		|file ""%1"" due to it is occupied by nobody.';ru='Невозможно освободить файл ""%1"",
		|т.к. он никем не занят.'"),
			String(ObjectRef));
		Return False;
	Else
		If FileFunctionsServiceClientServer.PersonalFileOperationsSettings(
		       ).InfobaseUserWithFullAccess Then
			
			Return True;
		EndIf;
		
		ErrorString = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Impossible to unlock
		|file ""%1"" due to it is occupied by user ""%2"".';ru='Невозможно освободить файл ""%1"",
		|т.к. он занят пользователем ""%2"".'"),
			String(ObjectRef),
			String(IsEditing));
		Return False;
	EndIf;
	
EndFunction

// Releases the file without update.
//
// Parameters:
//  FileData             - Structure with file data.
//  UUID - UUID of managed form.
//
Procedure ReleaseFileWithoutQuestion(FileData, UUID = Undefined) Export
	
	FileOperationsServiceServerCall.ReleaseFile(FileData, UUID);
	ExtensionAttached = FileFunctionsServiceClient.FileOperationsExtensionConnected();
	If ExtensionAttached Then
		ReregisterFileInWorkingDirectory(FileData, True, FileData.OwnerWorkingDirectory <> "");
	EndIf;
	
	ShowUserNotification(NStr("en='File is released';ru='Файл освобожден'"),
		FileData.URL, FileData.FullDescrOfVersion, PictureLib.Information32);
	
EndProcedure

// Moves files to specified folder.
//
// Parameters:
//  ObjectsRef - Array - file array.
//
//  Folder         - CatalogRef.FileFolders - folder
//                  to which the files shall be transferred.
//
Procedure MoveFilesToFolder(ObjectsRef, Folder) Export
	
	DataFiles = FileOperationsServiceServerCall.TransferFiles(ObjectsRef, Folder);
	
	For Each FileData IN DataFiles Do
		
		ShowUserNotification(
			NStr("en='Transfer file';ru='Перенос файла'"),
			FileData.URL,
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='The
		|""%1"" file is moved to the ""%2"" folder.';ru='Файл
		|""%1"" перенесен в папку ""%2"".'"),
				String(FileData.Ref),
				String(Folder)),
			PictureLib.Information32);
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// End of file editing and placing on server.

// Finish editing the file and put it on server.
//
// Parameters:
//   Parameters - Structure - see FileUpdateParameters.
//
Procedure EndEdit(Parameters)
	
	Handler = New NotifyDescription("EndEditingAfterInstallingExtension", ThisObject, Parameters);
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(Handler);
	
EndProcedure

// Procedure continued (see above).
Procedure EndEditingAfterInstallingExtension(ExtensionIsSet, ExecuteParameters) Export
	ExecuteParameters.Insert("FileData", Undefined);
	
	If FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		EndEditWithExtension(ExecuteParameters);
	Else
		FinishEditingWithoutExtension(ExecuteParameters);
	EndIf;
EndProcedure

// Procedure continued (see above).
Procedure EndEditWithExtension(ExecuteParameters)
	// Web client with the extension
	// for work
	// with files, Thin client, Thick client.
	
	ExecuteParameters.FileData = FileOperationsServiceServerCall.FileDataAndWorkingDirectory(ExecuteParameters.ObjectRef);
	
	// Checking the possibility to unlock the file.
	ErrorText = "";
	YouCanUnlockFile = PossibilityToReleaseFile(
		ExecuteParameters.FileData.Ref,
		ExecuteParameters.FileData.CurrentUserIsEditing,
		ExecuteParameters.FileData.IsEditing,
		ErrorText);
	If Not YouCanUnlockFile Then
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, False);
		Return;
	EndIf;
	
	ExecuteParameters.Insert("FullPathToFile", ExecuteParameters.TransferredFullPathToFile);
	If ExecuteParameters.FullPathToFile = "" Then
		ExecuteParameters.FullPathToFile = ExecuteParameters.FileData.FullFileNameInWorkingDirectory;
	EndIf;
	
	// Checking file existence on the disk.
	ExecuteParameters.Insert("NewVersionFile", New File(ExecuteParameters.FullPathToFile));
	If Not ExecuteParameters.NewVersionFile.Exist() Then
		If ExecuteParameters.ApplyToAll = False Then
			If Not IsBlankString(ExecuteParameters.FullPathToFile) Then
				WarningString = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Failed to put
		|file ""%1""
		|(%2) to file storage due to it has not been found in the work directory.
		|
		|Unlock file?';ru='Не удалось поместить файл
		|""%1"" (%2),
		|в хранилище файлов, т.к. он не найден в рабочем каталоге.
		|
		|Освободить файл?'"),
					String(ExecuteParameters.FileData.Ref),
					ExecuteParameters.FullPathToFile);
			Else
				WarningString = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Failed to place file
		|""%1"" in files storage due to it has not been found in the work directory.
		|
		|Unlock file?';ru='Не удалось поместить файл ""%1"" в хранилище файлов:
		|Файл не найден в рабочем каталоге.
		|
		|Освободить файл?'"),
					String(ExecuteParameters.FileData.Ref));
				WarningString = WarningString + ".";
			EndIf;
			
			Handler = New NotifyDescription("FinishEditingWithExtensionAfterAnswerToQuestionUnlockFile", ThisObject, ExecuteParameters);
			ShowQueryBox(Handler, WarningString, QuestionDialogMode.YesNo);
		Else
			FinishEditingWithExtensionAfterAnswerToQuestionUnlockFile(-1, ExecuteParameters)
		EndIf;
		
		Return;
	EndIf;
	
	Try
		ReadOnly = ExecuteParameters.NewVersionFile.GetReadOnly();
		ExecuteParameters.NewVersionFile.SetReadOnly(NOT ReadOnly);
		ExecuteParameters.NewVersionFile.SetReadOnly(ReadOnly);
	Except
		ErrorText = NStr("en='Failed to place the ""%1"" file in
		|file storage, it may be locked by another application.';ru='Не удалось поместить файл
		|""%1"" в хранилище файлов, возможно он заблокирован другой программой.'");
		ErrorText = StrReplace(ErrorText, "%1", String(ExecuteParameters.FileData.Ref));
		Raise ErrorText + Chars.LF + Chars.LF + DetailErrorDescription(ErrorInfo());
	EndTry;
	
	// Query for comment and version storage flag.
	If ExecuteParameters.CreateNewVersion = Undefined Then
		ReturnForm = FileOperationsServiceClientReUse.FileReturnForm();
		
		ExecuteParameters.CreateNewVersion = True;
		CreateNewVersionEnabled = True;
		
		If ExecuteParameters.FileData.StoreVersions Then
			ExecuteParameters.CreateNewVersion = True;
			
			// If the author of current version is
			// not current user, then check box "Do not create a new version" is disabled.
			If ExecuteParameters.FileData.CurrentVersionAuthor <> ExecuteParameters.FileData.IsEditing Then
				CreateNewVersionEnabled = False;
			Else
				CreateNewVersionEnabled = True;
			EndIf;
		Else
			ExecuteParameters.CreateNewVersion = False;
			CreateNewVersionEnabled = False;
		EndIf;
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("FileRef",                    ExecuteParameters.FileData.Ref);
		ParametersStructure.Insert("CommentToVersion",            "");
		ParametersStructure.Insert("CreateNewVersion",            ExecuteParameters.CreateNewVersion);
		ParametersStructure.Insert("CreateNewVersionEnabled", CreateNewVersionEnabled);
		
		ReturnForm.SetUsageParameters(ParametersStructure);
		
		Handler = New NotifyDescription("FinishEditingWithExtensionAfterPlacingFileOnServer", ThisObject, ExecuteParameters);
		SetFormAlert(ReturnForm, Handler);
		
		ReturnForm.Open();
		
	Else // Parameters CreateNewVersion and CommentToVersion are passed from the outside.
		
		If ExecuteParameters.FileData.StoreVersions Then
			
			// If the author of current version is
			// not current user, then check box "Do not create a new version" is disabled.
			If ExecuteParameters.FileData.CurrentVersionAuthor <> ExecuteParameters.FileData.IsEditing Then
				ExecuteParameters.CreateNewVersion = True;
			EndIf;
			
		Else
			ExecuteParameters.CreateNewVersion = False;
		EndIf;
		
		FinishEditingWithExtensionAfterCheckingNewVersion(ExecuteParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingWithExtensionAfterAnswerToQuestionUnlockFile(Response, ExecuteParameters) Export
	If Response <> -1 Then
		If Response = DialogReturnCode.Yes Then
			ExecuteParameters.ToReleaseFiles = True;
		Else
			ExecuteParameters.ToReleaseFiles = False;
		EndIf;
	EndIf;
	
	If ExecuteParameters.ToReleaseFiles Then
		ReleaseFileWithoutQuestion(ExecuteParameters.FileData, ExecuteParameters.FormID);
		ReturnResult(ExecuteParameters.ResultHandler, True);
	Else
		ReturnResult(ExecuteParameters.ResultHandler, False);
	EndIf;
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingWithExtensionAfterPlacingFileOnServer(Result, ExecuteParameters) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	If Result.ReturnCode <> DialogReturnCode.OK Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	ExecuteParameters.CreateNewVersion = Result.CreateNewVersion;
	ExecuteParameters.CommentToVersion = Result.CommentToVersion;
	
	FinishEditingWithExtensionAfterCheckingNewVersion(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingWithExtensionAfterCheckingNewVersion(ExecuteParameters) Export
	
	OldVersion = ExecuteParameters.FileData.CurrentVersion;
	
	If Not ExecuteParameters.FileData.Encrypted Then
		FinishEditingWithExtensionAfterCheckingEncrypted(, ExecuteParameters);
		Return;
	EndIf;
	
	// File with flag "encrypted" is encrypted again for the same certificates.
	
	ExecuteParameters.Insert("AlertAfterEncryption", New NotifyDescription(
		"FinishEditingWithExtensionAfterCheckingEncrypted", ThisObject, ExecuteParameters));
	
	EncryptFileBeforePlacingToFilesStorage(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingWithExtensionAfterCheckingEncrypted(NOTSpecified, ExecuteParameters) Export
	
	FileInformation = FileOperationsClientServer.FileInformation("FileWithVersion", ExecuteParameters.NewVersionFile);
	FileInformation.Comment = ExecuteParameters.CommentToVersion;
	FileInformation.StoreVersions = ExecuteParameters.CreateNewVersion;
	
	If ExecuteParameters.Property("AddressAfterEncryption") Then
		FileInformation.FileTemporaryStorageAddress = ExecuteParameters.AddressAfterEncryption;
	Else
		SizeInMB = FileInformation.Size / (1024 * 1024);
		ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Transfer of ""%1"" file is in progress (%2 Mb)...
		|Please, wait.';ru='Выполняется передача файла ""%1"" (%2 Мб)...
		|Пожалуйста, подождите.'"),
			FileInformation.BaseName,
			FileFunctionsServiceClientServer.GetStringWithFileSize(SizeInMB));
		Status(ExplanationText);
		
		FilesToPlace = New Array;
		Definition = New TransferableFileDescription(ExecuteParameters.FullPathToFile, "");
		FilesToPlace.Add(Definition);
		
		PlacedFiles = New Array;
		Try
			FilesPlaced = PutFiles(FilesToPlace,	PlacedFiles,, False, ExecuteParameters.FormID);
		Except
			ErrorInfo = ErrorInfo();
			
			QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Failed to place the file in file storage
		|due to: ""%1"".
		|
		|Repeat operation?';ru='Не удалось поместить файл в
		|хранилище файлов по причине: ""%1"".
		|
		|Повторить операцию?'"),
				BriefErrorDescription(ErrorInfo));
			
			Notification  = New NotifyDescription("FinishEditingWithExtensionAfterCheckingEncryptedRepeat", ThisObject, ExecuteParameters);
			ShowQueryBox(Notification, QuestionText, QuestionDialogMode.RetryCancel);
			Return;
		EndTry;

		Status();
		If Not FilesPlaced Then
			ReturnResult(ExecuteParameters.ResultHandler, False);
			Return;
		EndIf;
		
		If PlacedFiles.Count() = 1 Then
			FileInformation.FileTemporaryStorageAddress = PlacedFiles[0].Location;
		EndIf;
	EndIf;
	
	FileOperationsCommonSettings = FileFunctionsServiceClientServer.FileOperationsCommonSettings();
	If Not FileOperationsCommonSettings.ExtractFileTextsAtServer Then
		Try
			FileInformation.TextTemporaryStorageAddress = FileFunctionsServiceClientServer.ExtractTextToTemporaryStorage(
				ExecuteParameters.FullPathToFile, ExecuteParameters.FormID,, ExecuteParameters.Encoding);
		Except
			EndEditingWithExtensionExceptionProcessor(ErrorInfo(), ExecuteParameters);
			Return;
		EndTry;
	EndIf;
	
	InOwnerWorkingDirectory = ExecuteParameters.FileData.OwnerWorkingDirectory <> "";
	
	NotChangeRecordInWorkingDirectory = False;
	If ExecuteParameters.TransferredFullPathToFile <> "" Then
		NotChangeRecordInWorkingDirectory = True;
	EndIf;
	
	Try
		VersionUpdated = FileOperationsServiceServerCall.SaveChangesAndReleaseFile(ExecuteParameters.FileData, FileInformation, 
			NotChangeRecordInWorkingDirectory, ExecuteParameters.FullPathToFile, FileFunctionsServiceClient.UserWorkingDirectory(), 
			ExecuteParameters.FormID);
	Except
		EndEditingWithExtensionExceptionProcessor(ErrorInfo(), ExecuteParameters);
		Return;
	EndTry;
	
	ExecuteParameters.Insert("VersionUpdated", VersionUpdated);
	NewVersion = ExecuteParameters.FileData.CurrentVersion;
	
	If ExecuteParameters.TransferredFullPathToFile = "" Then
		
		DeleteFileFromFilesLocalCacheOnEditEnd =
			FileFunctionsServiceClientServer.PersonalFileOperationsSettings().DeleteFileFromFilesLocalCacheOnEditEnd;
		
		If DeleteFileFromFilesLocalCacheOnEditEnd = Undefined Then
			DeleteFileFromFilesLocalCacheOnEditEnd = False;
		EndIf;
		
		If ExecuteParameters.FileData.OwnerWorkingDirectory <> "" Then
			DeleteFileFromFilesLocalCacheOnEditEnd = False;
		EndIf;
		
		If DeleteFileFromFilesLocalCacheOnEditEnd Then
			Handler = New NotifyDescription("FinishEditingWithExtensionAfterDeletingFileFromWorkingDirectory", ThisObject, ExecuteParameters);
			DeleteFileFromWorkingDirectory(Handler, NewVersion);
			Return;
		Else
			File = New File(ExecuteParameters.FullPathToFile);
			File.SetReadOnly(True);
		EndIf;
	EndIf;
	
	FinishEditingWithExtensionAfterDeletingFileFromWorkingDirectory(-1, ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
//
Procedure FinishEditingWithExtensionAfterCheckingEncryptedRepeat(Result, Parameter) Export
	If Result = DialogReturnCode.Retry Then
		FinishEditingWithExtensionAfterCheckingEncrypted(, Parameter);
	EndIf;
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingWithExtensionAfterDeletingFileFromWorkingDirectory(Result, ExecuteParameters) Export
	
	If ExecuteParameters.ShowAlert Then
		If ExecuteParameters.VersionUpdated Then
			ExplanationTemplate = NStr("en='File
		|""% 1"" is updated and released.';ru='Файл
		|""%1"" обновлен и освобожден.'");
		Else
			ExplanationTemplate = NStr("en='File
		|""% 1"" has not been changed and unlocked.';ru='Файл
		|""%1"" не изменился и освобожден.'");
		EndIf;
		
		ShowUserNotification(
			NStr("en='Editing is complete';ru='Редактирование закончено'"),
			ExecuteParameters.FileData.URL,
			StringFunctionsClientServer.SubstituteParametersInString(
				ExplanationTemplate, String(ExecuteParameters.FileData.Ref)),
			PictureLib.Information32);
		
		If Not ExecuteParameters.VersionUpdated Then
			Handler = New NotifyDescription("FinishEditingWithExtensionAfterDisplayingNotification", ThisObject, ExecuteParameters);
			ShowInformationFileWasNotChanged(Handler);
			Return;
		EndIf;
	EndIf;
	
	FinishEditingWithExtensionAfterDisplayingNotification(-1, ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingWithExtensionAfterDisplayingNotification(Result, ExecuteParameters) Export
	
	ReturnResult(ExecuteParameters.ResultHandler, True);
	
EndProcedure

// Procedure continued (see above).
Procedure EndEditingWithExtensionExceptionProcessor(ErrorInfo, ExecuteParameters)
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Failed to place the
		|""%1"" file to file storage
		|due to ""%2"".
		|
		|Repeat operation?';ru='Не удалось поместить
		|файл ""%1"" в
		|хранилище файлов по причине ""%2"".
		|
		|Повторить операцию?'"),
		String(ExecuteParameters.FileData.Ref),
		BriefErrorDescription(ErrorInfo));
	
	Handler = New NotifyDescription("FinishEditingWithExtensionAfterAnswerToQuestionRepeat", ThisObject, ExecuteParameters);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.RetryCancel);
	
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingWithExtensionAfterAnswerToQuestionRepeat(Response, ExecuteParameters) Export
	
	If Response = DialogReturnCode.Cancel Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	FinishEditingWithExtensionAfterCheckingEncrypted(, ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingWithoutExtension(ExecuteParameters)
	// Web client without extension for work with files.
	
	If ExecuteParameters.StoreVersions = Undefined Then
		ExecuteParameters.FileData  = FileOperationsServiceServerCall.FileData(ExecuteParameters.ObjectRef);
		ExecuteParameters.StoreVersions                  = ExecuteParameters.FileData.StoreVersions;
		ExecuteParameters.CurrentUserIsEditing = ExecuteParameters.FileData.CurrentUserIsEditing;
		ExecuteParameters.IsEditing                    = ExecuteParameters.FileData.IsEditing;
		ExecuteParameters.CurrentVersionAuthor             = ExecuteParameters.FileData.CurrentVersionAuthor;
		ExecuteParameters.Encoding                      = ExecuteParameters.FileData.CurrentVersionEncoding;
	EndIf;
	
	// Checking the possibility to unlock the file.
	ErrorText = "";
	YouCanUnlockFile = PossibilityToReleaseFile(
		ExecuteParameters.ObjectRef,
		ExecuteParameters.CurrentUserIsEditing,
		ExecuteParameters.IsEditing,
		ErrorText);
	If Not YouCanUnlockFile Then
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, False);
		Return;
	EndIf;
	
	ExecuteParameters.Insert("FullPathToFile", "");
	
	If ExecuteParameters.CreateNewVersion = Undefined Then
		ReturnForm = FileOperationsServiceClientReUse.FileReturnForm();
		
		ExecuteParameters.CreateNewVersion = True;
		CreateNewVersionEnabled = True;
		
		If ExecuteParameters.StoreVersions Then
			ExecuteParameters.CreateNewVersion = True;
			
			// If the author of current version is
			// not current user, then check box "Do not create a new version" is disabled.
			If ExecuteParameters.CurrentVersionAuthor <> ExecuteParameters.IsEditing Then
				CreateNewVersionEnabled = False;
			Else
				CreateNewVersionEnabled = True;
			EndIf;
		Else
			ExecuteParameters.CreateNewVersion = False;
			CreateNewVersionEnabled = False;
		EndIf;
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("FileRef",                    ExecuteParameters.ObjectRef);
		ParametersStructure.Insert("CommentToVersion",            "");
		ParametersStructure.Insert("CreateNewVersion",            ExecuteParameters.CreateNewVersion);
		ParametersStructure.Insert("CreateNewVersionEnabled", CreateNewVersionEnabled);
		
		ReturnForm.SetUsageParameters(ParametersStructure);
		
		Handler = New NotifyDescription("FinishEditingWithoutExtensionAfterPlacingFileOnServer", ThisObject, ExecuteParameters);
		SetFormAlert(ReturnForm, Handler);
		
		ReturnForm.Open();
		
	Else // Parameters CreateNewVersion and CommentToVersion are passed from the outside.
		
		If ExecuteParameters.StoreVersions Then
			
			// If the author of current version is
			// not current user, then check box "Do not create a new version" is disabled.
			If ExecuteParameters.CurrentVersionAuthor <> ExecuteParameters.IsEditing Then
				ExecuteParameters.CreateNewVersion = True;
			EndIf;
			
		Else
			ExecuteParameters.CreateNewVersion = False;
		EndIf;
		
		FinishEditingWithoutExtensionAfterCheckingNewVersion(ExecuteParameters)
		
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingWithoutExtensionAfterPlacingFileOnServer(Result, ExecuteParameters) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	If Result.ReturnCode <> DialogReturnCode.OK Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	ExecuteParameters.CreateNewVersion = Result.CreateNewVersion;
	ExecuteParameters.CommentToVersion = Result.CommentToVersion;
	
	FinishEditingWithoutExtensionAfterCheckingNewVersion(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingWithoutExtensionAfterCheckingNewVersion(ExecuteParameters) Export
	
	Handler = New NotifyDescription("FinishEditingWithoutExtensionAfterReminder", ThisObject, ExecuteParameters);
	ShowReminderBeforePutFile(Handler);
	
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingWithoutExtensionAfterReminder(Result, ExecuteParameters) Export
	
	Handler = New NotifyDescription("FinishEditingWithoutExtensionAfterFileImport", ThisObject, ExecuteParameters);
	BeginPutFile(Handler, , ExecuteParameters.FullPathToFile, , ExecuteParameters.FormID);
	
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingWithoutExtensionAfterFileImport(Placed, Address, SelectedFileName, ExecuteParameters) Export
	
	If Not Placed Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	ExecuteParameters.Insert("ImportedFileAddress", Address);
	ExecuteParameters.Insert("SelectedFileName", SelectedFileName);
	
	If ExecuteParameters.FileData = Undefined Then
		FileData = FileOperationsServiceServerCall.FileData(ExecuteParameters.ObjectRef);
	Else
		FileData = ExecuteParameters.FileData;
	EndIf;
	If Not FileData.Encrypted Then
		FinishEditingWithoutExtensionAfterEncryptingFile(Null, ExecuteParameters);
		Return;
	EndIf;
	If CertificatesNotSpecified(FileData.ArrayOfEncryptionCertificates) Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	// No need to OfferSettingFileOperationsExtension() as all is done in memory through BinaryData.
	
	DataDescription = New Structure;
	DataDescription.Insert("Operation",            NStr("en='File encryption';ru='Шифрование файла'"));
	DataDescription.Insert("DataTitle",     NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("Data",              Address);
	DataDescription.Insert("Presentation",       ExecuteParameters.ObjectRef);
	DataDescription.Insert("CertificatesSet",   ExecuteParameters.ObjectRef);
	DataDescription.Insert("WithoutConfirmation",    True);
	DataDescription.Insert("NotifyAboutCompletion", False);
	
	ContinuationHandler = New NotifyDescription("FinishEditingWithoutExtensionAfterEncryptingFile",
		ThisObject, ExecuteParameters);
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.Encrypt(DataDescription, , ContinuationHandler);
	
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingWithoutExtensionAfterEncryptingFile(DataDescription, ExecuteParameters) Export
	
	If DataDescription = Null Then
		Address = ExecuteParameters.ImportedFileAddress;
		
	ElsIf Not DataDescription.Success Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	Else
		If TypeOf(DataDescription.EncryptedData) = Type("BinaryData") Then
			Address = PutToTempStorage(DataDescription.EncryptedData,
				ExecuteParameters.FormID);
		Else
			Address = DataDescription.EncryptedData;
		EndIf;
	EndIf;
	
	FileInformation = FileOperationsClientServer.FileInformation("FileWithVersion");
	
	FileInformation.FileTemporaryStorageAddress = Address;
	FileInformation.Comment = ExecuteParameters.CommentToVersion;
	
	PathStrings = CommonUseClientServer.SortStringByPointsAndSlashes(ExecuteParameters.SelectedFileName);
	If PathStrings.Count() >= 2 Then
		FileInformation.ExtensionWithoutDot = PathStrings[PathStrings.Count() - 1];
		FileInformation.BaseName = PathStrings[PathStrings.Count() - 2];
	EndIf;
	FileInformation.StoreVersions = ExecuteParameters.CreateNewVersion;
	
	Try
		Result = FileOperationsServiceServerCall.SaveChangesAndReleaseFileByLink(ExecuteParameters.ObjectRef,
			FileInformation, ExecuteParameters.FullPathToFile, FileFunctionsServiceClient.UserWorkingDirectory(), 
			ExecuteParameters.FormID);
		ExecuteParameters.FileData = Result.FileData;
	Except
		FinishEditingExceptionHandler(ErrorInfo(), ExecuteParameters);
		Return;
	EndTry;
	
	NewVersion = ExecuteParameters.FileData.CurrentVersion;
	If ExecuteParameters.ShowAlert Then
		If Result.Successfully Then
			ExplanationTemplate = NStr("en='File
		|""% 1"" is updated and released.';ru='Файл
		|""%1"" обновлен и освобожден.'");
		Else
			ExplanationTemplate = NStr("en='File
		|""% 1"" has not been changed and unlocked.';ru='Файл
		|""%1"" не изменился и освобожден.'");
		EndIf;
		
		ShowUserNotification(
			NStr("en='Editing is complete';ru='Редактирование закончено'"),
			ExecuteParameters.FileData.URL,
			StringFunctionsClientServer.SubstituteParametersInString(
				ExplanationTemplate, String(ExecuteParameters.FileData.Ref)),
			PictureLib.Information32);
		
		If Not Result.Successfully Then
			Handler = New NotifyDescription("FinishEditingWithoutExtensionAfterDisplayingNotification", ThisObject, ExecuteParameters);
			ShowInformationFileWasNotChanged(Handler);
			Return;
		EndIf;
	EndIf;
	
	FinishEditingWithoutExtensionAfterDisplayingNotification(-1, ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingWithoutExtensionAfterDisplayingNotification(Result, ExecuteParameters) Export
	
	ReturnResult(ExecuteParameters.ResultHandler, True);
	
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingExceptionHandler(ErrorInfo, ExecuteParameters) Export
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Failed to place the
		|""%1"" file to file storage
		|due to ""%2"".
		|
		|Repeat operation?';ru='Не удалось поместить
		|файл ""%1"" в
		|хранилище файлов по причине ""%2"".
		|
		|Повторить операцию?'"),
		String(ExecuteParameters.ObjectRef),
		BriefErrorDescription(ErrorInfo));
	
	Handler = New NotifyDescription("FinishEditingWithoutExtensionAfterAnswerToQuestionRepeat", ThisObject, ExecuteParameters);
	ShowQueryBox(Handler, ErrorText, QuestionDialogMode.RetryCancel);
	
EndProcedure

// Procedure continued (see above).
Procedure FinishEditingWithoutExtensionAfterAnswerToQuestionRepeat(Response, ExecuteParameters) Export
	If Response = DialogReturnCode.Cancel Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
	Else
		FinishEditingWithoutExtensionAfterCheckingNewVersion(ExecuteParameters);
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Select file and create new version based on it.

// Selects a file on disk and creates a new version from it.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FileData - structure with file data.
//  FormID - form unique ID.
//
// Returns:
//  Boolean. True if the operation is completed successfully.
//
Procedure UpdateFromFileOnDrive(ResultHandler, FileData, FormID) Export
	
	If Not FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		ReturnResult(ResultHandler, False);
		Return;
	EndIf;
		
	Dialog = New FileDialog(FileDialogMode.Open);
	
	If Not IsBlankString(FileData.OwnerWorkingDirectory) Then
		ChoicePath = FileData.OwnerWorkingDirectory;
	Else
		ChoicePath = CommonUseServerCall.CommonSettingsStorageImport("ApplicationSettings", "FolderForUpdateFromFile");
	EndIf;
	
	If ChoicePath = Undefined Or ChoicePath = "" Then
		#If Not WebClient Then
			If StandardSubsystemsClientReUse.ClientWorkParameters().ThisIsBasicConfigurationVersion Then
				CommonUseClientServer.MessageToUser(
					NStr("en='This command is not supported in base version.';ru='Данная команда не поддерживается в базовой версии.'"));
				ReturnResult(ResultHandler, False);
				Return;
			EndIf;
		#EndIf
		ChoicePath = FileFunctionsServiceClient.MyDocumentsDir();
	EndIf;
	
	Dialog.Title                   = NStr("en='Select file';ru='Выбор файла'");
	Dialog.Preview     = False;
	Dialog.CheckFileExist = False;
	Dialog.Multiselect          = False;
	Dialog.Directory                     = ChoicePath;
	
	Dialog.FullFileName = CommonUseClientServer.GetNameWithExtention(
		FileData.FullDescrOfVersion, FileData.Extension); 
	
	
	ExtensionForEncryptedFiles = "";
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureClientServer =
			CommonUseClient.CommonModule("DigitalSignatureClientServer");
		
		If ModuleDigitalSignatureClientServer.CommonSettings().UseEncryption Then
			ExtensionForEncryptedFiles =
				ModuleDigitalSignatureClientServer.PersonalSettings(
					).ExtensionForEncryptedFiles;
		EndIf;
	EndIf;
	
	If ValueIsFilled(ExtensionForEncryptedFiles) Then
		Filter = NStr("en='File *.%1)|*.%1|Encrypted file (*.%2)|*.%2|All files (*.*)|*.*';ru='Файл (*.%1)|*.%1|Зашифрованный файл (*.%2)|*.%2|Все файлы (*.*)|*.*'");
	Else
		Filter = NStr("en='File (*.%1)|*.%1|All files (*.*)|*.*';ru='Файл (*.%1)|*.%1|Все файлы (*.*)|*.*'");
	EndIf;
	
	Dialog.Filter = StringFunctionsClientServer.SubstituteParametersInString(Filter,
		FileData.Extension, ExtensionForEncryptedFiles);
	
	If Not Dialog.Choose() Then
		ReturnResult(ResultHandler, False);
		Return;
	EndIf;
	
	ChoicePathFormer = ChoicePath;
	FileOnDrive = New File(Dialog.FullFileName);
	ChoicePath = FileOnDrive.Path;
	
	If IsBlankString(FileData.OwnerWorkingDirectory) Then
		If ChoicePathFormer <> ChoicePath Then
			CommonUseServerCall.CommonSettingsStorageSave("ApplicationSettings", "FolderForUpdateFromFile",  ChoicePath);
		EndIf;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("FileData",          FileData);
	ExecuteParameters.Insert("FormID",   FormID);
	ExecuteParameters.Insert("DialogFullFileName", Dialog.FullFileName);
	ExecuteParameters.Insert("CreateNewVersion",   Undefined);
	ExecuteParameters.Insert("CommentToVersion",   Undefined);
	
	ExecuteParameters.Insert("FileOnDrive", New File(ExecuteParameters.DialogFullFileName));
	ExecuteParameters.Insert("FileOnDriveNameAndExtension", ExecuteParameters.FileOnDrive.Name);
	ExecuteParameters.Insert("FileName", ExecuteParameters.FileOnDrive.BaseName);
	
	ExecuteParameters.Insert("ModificationTimeOfSelected",
		ExecuteParameters.FileOnDrive.GetModificationUniversalTime());
	
	ExecuteParameters.Insert("FileOnDriveExtension",
		CommonUseClientServer.ExtensionWithoutDot(ExecuteParameters.FileOnDrive.Extension));
	
	ExecuteParameters.Insert("ExtensionForEncryptedFiles", ExtensionForEncryptedFiles);
	
	ExecuteParameters.Insert("FileEncrypted", Lower(ExecuteParameters.FileOnDriveExtension)
		= Lower(ExecuteParameters.ExtensionForEncryptedFiles));
	
	If Not ExecuteParameters.FileEncrypted Then
		UpdateFromFileOnDiskContinued(ExecuteParameters);
		Return;
	EndIf;
	
	// cut .p7m in the end
	Position = Find(ExecuteParameters.FileOnDriveNameAndExtension, ExecuteParameters.FileOnDriveExtension);
	ExecuteParameters.FileOnDriveNameAndExtension = Left(ExecuteParameters.FileOnDriveNameAndExtension, Position - 2);
	
	// cut .p7m in the end
	ExecuteParameters.Insert("DialogFullFileNameFormer", ExecuteParameters.DialogFullFileName);
	Position = Find(ExecuteParameters.DialogFullFileName, ExecuteParameters.FileOnDriveExtension);
	ExecuteParameters.DialogFullFileName = Left(ExecuteParameters.DialogFullFileName, Position - 2);
	
	TemporaryFileNotEncrypted = New File(ExecuteParameters.DialogFullFileName);
	
	ExecuteParameters.FileOnDriveExtension = CommonUseClientServer.ExtensionWithoutDot(
		TemporaryFileNotEncrypted.Extension);
	
	FileFunctionsServiceClientServer.CheckFileExtensionForImporting(
		ExecuteParameters.FileOnDriveExtension);
	
	// Decrypt here and put same modification date as DialogFullFileNameFormer.
	
	BeginPutFile(New NotifyDescription("UpdateFromFileOnDiskBeforeDecryption", ThisObject, ExecuteParameters),
		, ExecuteParameters.DialogFullFileNameFormer, False, ExecuteParameters.FormID);
	
EndProcedure

// Procedure continued (see above).
Procedure UpdateFromFileOnDiskBeforeDecryption(Result, FileURL, SelectedFileName, ExecuteParameters) Export
	
	If Result <> True Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	DataDescription = New Structure;
	DataDescription.Insert("Operation",              NStr("en='File decryption';ru='Расшифровка файла'"));
	DataDescription.Insert("DataTitle",       NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("Data",                FileURL);
	DataDescription.Insert("Presentation",         ExecuteParameters.FileData.Ref);
	DataDescription.Insert("EncryptionCertificates", New Array);
	DataDescription.Insert("NotifyAboutCompletion",   False);
	
	ContinuationHandler = New NotifyDescription("UpdateFromFileOnDiskAfterDecryption",
		ThisObject, ExecuteParameters);
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.Decrypt(DataDescription, , ContinuationHandler);
	
EndProcedure

// Procedure continued (see above).
Procedure UpdateFromFileOnDiskAfterDecryption(DataDescription, ExecuteParameters) Export
	
	If Not DataDescription.Success Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	If TypeOf(DataDescription.DecryptedData) = Type("BinaryData") Then
		FileURL = PutToTempStorage(DataDescription.DecryptedData,
			ExecuteParameters.FormID);
	Else
		FileURL = DataDescription.DecryptedData;
	EndIf;
	
	ExecuteParameters.Insert("FileURL", FileURL);
	
	If Not GetFile(FileURL, ExecuteParameters.DialogFullFileName, False) Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	TemporaryFileNotEncrypted = New File(ExecuteParameters.DialogFullFileName);
	TemporaryFileNotEncrypted.SetModificationUniversalTime(ExecuteParameters.ModificationTimeOfSelected);
	
	ExecuteParameters.FileEncrypted = False;
	
	UpdateFromFileOnDiskContinued(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure UpdateFromFileOnDiskContinued(ExecuteParameters)
	
	// File data could have changed - update.
	ExecuteParameters.FileData = FileOperationsServiceServerCall.FileDataAndWorkingDirectory(ExecuteParameters.FileData.Ref);
	
	PreviousVersion = ExecuteParameters.FileData.Version;
	
	FileInBaseNameAndExtension = CommonUseClientServer.GetNameWithExtention(
		ExecuteParameters.FileData.FullDescrOfVersion, ExecuteParameters.FileData.Extension);
	
	ExecuteParameters.Insert("DateFileInBase", ExecuteParameters.FileData.ModificationDateUniversal);
	
	If ExecuteParameters.ModificationTimeOfSelected < ExecuteParameters.DateFileInBase Then // Newer in the storage.
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='File
		|""%1"" in the file storage has later modification
		|date (%2) than selected file (%3).
		|
		|Operation is aborted.';ru='Файл
		|""%1"" в хранилище файлов имеет более
		|позднюю дату изменения (%2), чем выбранный файл (%3).
		|
		|Операция прервана.'"),
			String(ExecuteParameters.FileData.Ref),
			ToLocalTime(ExecuteParameters.DateFileInBase),
			ToLocalTime(ExecuteParameters.ModificationTimeOfSelected));
		
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, False);
		Return;
	EndIf;
	
	// Check the existence of file in working directory.
	InWorkingDirectoryForRead = True;
	InOwnerWorkingDirectory = False;
	FullFileName = "";
	FileInWorkingDirectory = FileIsInFilesLocalCache(
		Undefined,
		PreviousVersion,
		FullFileName,
		InWorkingDirectoryForRead,
		InOwnerWorkingDirectory);
	
	If ExecuteParameters.FileData.CurrentUserIsEditing Then // File was already locked.
		
		If FileInWorkingDirectory = True Then
			FileInCache = New File(FullFileName);
			ChangeTimeInCache = FileInCache.GetModificationUniversalTime();
			
			If ExecuteParameters.ModificationTimeOfSelected < ChangeTimeInCache Then // There is a newer file in working directory.
				
				ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='File
		|""%1"" in working directory has later modification date
		|(%2) than selected file (%3).
		|
		|Operation is aborted.';ru='Файл
		|""%1"" в рабочем каталоге имеет более
		|позднюю дату изменения (%2), чем выбранный файл (%3).
		|
		|Операция прервана.'"),
					String(ExecuteParameters.FileData.Ref),
					ToLocalTime(ChangeTimeInCache),
					ToLocalTime(ExecuteParameters.ModificationTimeOfSelected));
				
				ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, False);
				Return;
			EndIf;
			
			#If Not WebClient Then
				// Checking that the file is not locked by the application.
				Try
					TextDocument = New TextDocument;
					TextDocument.Read(FullFileName);
				Except
					ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='File
		|""%1"" in working directory is opened for editing.
		|
		|Finish editing before
		|updating from file on disk.';ru='Файл
		|""%1"" в рабочем каталоге открыт для редактирования.
		|
		|Закончите редактирование
		|перед выполнением обновления из файла на диске.'"),
						FullFileName);
					ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, Undefined);
					Return;
				EndTry;
			#EndIf
			
		EndIf;
		
	EndIf;
	
	If FileInWorkingDirectory AND ExecuteParameters.FileOnDriveNameAndExtension <> FileInBaseNameAndExtension Then
		Handler = New NotifyDescription("UpdateFromFileOnDiskAfterRemovingFileFromWorkingDirectory", ThisObject, ExecuteParameters);
		DeleteFileFromWorkingDirectory(Handler, ExecuteParameters.FileData.CurrentVersion, True);
		Return;
	EndIf;
	
	UpdateFromFileOnDiskAfterRemovingFileFromWorkingDirectory(-1, ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure UpdateFromFileOnDiskAfterRemovingFileFromWorkingDirectory(Result, ExecuteParameters) Export
	
	If Result <> -1 Then
		If Result.Success <> True Then
			ReturnResult(ExecuteParameters.ResultHandler, False);
			Return;
		EndIf;
	EndIf;
	
	ExecuteParameters.Insert("CurrentUserIsEditing", ExecuteParameters.FileData.CurrentUserIsEditing);
	
	If Not ExecuteParameters.FileData.CurrentUserIsEditing Then
		
		ErrorText = "";
		YouCanLockFile = FileOperationsClientServer.IfYouCanLockFile(ExecuteParameters.FileData, ErrorText);
		If Not YouCanLockFile Then
			ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, Undefined);
			Return;
		EndIf;
		
		ErrorText = "";
		FileIsBusy = FileOperationsServiceServerCall.LockFile(ExecuteParameters.FileData, ErrorText, 
			ExecuteParameters.FormID);
		If Not FileIsBusy Then 
			ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, Undefined);
			Return;
		EndIf;
		
		ForRead = False;
		InOwnerWorkingDirectory = ExecuteParameters.FileData.OwnerWorkingDirectory <> "";
		ReregisterFileInWorkingDirectory(ExecuteParameters.FileData, ForRead, InOwnerWorkingDirectory);
		
	EndIf;
	
	NewFullFileName = "";
	ExecuteParameters.FileData.Insert("UpdatePathFromFileOnDrive", ExecuteParameters.DialogFullFileName);
	ExecuteParameters.FileData.Extension = CommonUseClientServer.ExtensionWithoutDot(ExecuteParameters.FileOnDriveExtension);
	
	// Placing to working directory from the file
	// selected on the disk as property UpdatePathFromFileOnDisk is specified.
	Handler = New NotifyDescription("UpdateFromFileOnDiskAfterReceivingFileInWorkingDirectory", ThisObject, ExecuteParameters);
	GetVersionFileToWorkingDirectory(Handler, ExecuteParameters.FileData, NewFullFileName, ExecuteParameters.FormID);
	
EndProcedure

// Procedure continued (see above).
Procedure UpdateFromFileOnDiskAfterReceivingFileInWorkingDirectory(Result, ExecuteParameters) Export
	
	// Results processing is not required.
	If ExecuteParameters.FileEncrypted Then
		FileOperationsServiceServerCall.SetSignEncrypted(ExecuteParameters.FileData.Ref, ExecuteParameters.FileEncrypted);
	EndIf;
	
	TransferredFullPathToFile = "";
	
	Handler = New NotifyDescription("UpdateFromFileOnDiskAfterFinishingEditing", ThisObject, ExecuteParameters);
	If ExecuteParameters.CurrentUserIsEditing Then // File was already locked.
		HandlerParameters = FileUpdateParameters(Handler, ExecuteParameters.FileData.Ref, ExecuteParameters.FormID);
		HandlerParameters.TransferredFullPathToFile = TransferredFullPathToFile;
		HandlerParameters.CreateNewVersion = ExecuteParameters.CreateNewVersion;
		HandlerParameters.CommentToVersion = ExecuteParameters.CommentToVersion;
		SaveFileChanges(HandlerParameters);
	Else
		HandlerParameters = FileUpdateParameters(Handler, ExecuteParameters.FileData.Ref, ExecuteParameters.FormID);
		HandlerParameters.StoreVersions = ExecuteParameters.FileData.StoreVersions;
		HandlerParameters.CurrentUserIsEditing = ExecuteParameters.FileData.CurrentUserIsEditing;
		HandlerParameters.IsEditing = ExecuteParameters.FileData.IsEditing;
		HandlerParameters.CurrentVersionAuthor = ExecuteParameters.FileData.CurrentVersionAuthor;
		HandlerParameters.TransferredFullPathToFile = TransferredFullPathToFile;
		HandlerParameters.CreateNewVersion = ExecuteParameters.CreateNewVersion;
		HandlerParameters.CommentToVersion = ExecuteParameters.CommentToVersion;
		EndEdit(HandlerParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure UpdateFromFileOnDiskAfterFinishingEditing(EditResult, ExecuteParameters) Export
	
	If ExecuteParameters.FileEncrypted Then
		DeleteFileWithoutConfirmation(ExecuteParameters.DialogFullFileName);
	EndIf;
	ReturnResult(ExecuteParameters.ResultHandler, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Marking the file as locked for editing.

// Marks the file as locked for editing.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  ObjectRef            - CatalogRef.Files - file.
//  UUID - UUID of the form.
//
// Returns:
//  Boolean. True if the operation is completed successfully.
//
Procedure LockFileByRef(ResultHandler, ObjectRef, UUID = Undefined) Export
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("ResultHandler", ResultHandler);
	HandlerParameters.Insert("ObjectRef", ObjectRef);
	HandlerParameters.Insert("UUID", UUID);
	
	Handler = New NotifyDescription("LockFileByRefAfterInstallingExtension", ThisObject, HandlerParameters);
	
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(Handler);
	
EndProcedure

// Procedure continued (see above).
Procedure LockFileByRefAfterInstallingExtension(ExtensionIsSet, ExecuteParameters) Export
	
	ExecuteParameters.Insert("FileData", Undefined);
	
	ErrorText = "";
	FileDataReceivedAndItIsLocked = FileOperationsServiceServerCall.GetFileDataAndLockFile(ExecuteParameters.ObjectRef,
		ExecuteParameters.FileData, ErrorText, ExecuteParameters.UUID);
	If Not FileDataReceivedAndItIsLocked Then // If you can not lock the file, then error message is displayed.
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, False);
		Return;
	EndIf;
	
	If FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		ForRead = False;
		InOwnerWorkingDirectory = ExecuteParameters.FileData.OwnerWorkingDirectory <> "";
		ReregisterFileInWorkingDirectory(ExecuteParameters.FileData, ForRead, InOwnerWorkingDirectory);
	EndIf;
	
	ShowUserNotification(
		NStr("en='Edit file';ru='Редактирование файла'"),
		ExecuteParameters.FileData.URL,
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='The
		|file ""%1"" busy for editing.';ru='Файл
		|""%1"" занят для редактирования.'"), String(ExecuteParameters.FileData.Ref)),
		PictureLib.Information32);
	
	ReturnResult(ExecuteParameters.ResultHandler, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Marking the files as locked for editing.

// Marks the files as locked for editing.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FilesArray - Array - file array.
//
Procedure LockFilesByRefs(ResultHandler, Val FilesArray) Export
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("ResultHandler", ResultHandler);
	HandlerParameters.Insert("FilesArray", FilesArray);
	
	Handler = New NotifyDescription("LockFilesByReferencesAfterInstallingExtension", ThisObject, HandlerParameters);
	
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(Handler);
	
EndProcedure

// Procedure continued (see above).
Procedure LockFilesByReferencesAfterInstallingExtension(ExtensionIsSet, ExecuteParameters) Export
	
	// Getting the array of files data.
	DataFiles = New Array;
	FileOperationsServiceServerCall.GetDataForArrayOfFiles(ExecuteParameters.FilesArray, DataFiles);
	ArrayVBoundary  = DataFiles.UBound();
	
	For Ind = 0 To ArrayVBoundary Do
		FileData = DataFiles[ArrayVBoundary - Ind];
		
		ErrorString = "";
		If Not FileOperationsClientServer.IfYouCanLockFile(FileData, ErrorString)
		 Or Not FileData.IsEditing.IsEmpty() Then // Not possible to lock.
			
			DataFiles.Delete(ArrayVBoundary - Ind);
		EndIf;
	EndDo;
	
	// Lock the files.
	LockedCount = 0;
	
	For Each FileData IN DataFiles Do
		
		If Not FileOperationsServiceServerCall.LockFile(FileData, "") Then 
			Continue;
		EndIf;
		
		If FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
			ForRead = False;
			InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
			ReregisterFileInWorkingDirectory(FileData, ForRead, InOwnerWorkingDirectory);
		EndIf;
		
		LockedCount = LockedCount + 1;
	EndDo;
	
	ShowUserNotification(
		NStr("en='Lock files';ru='Занять файлы'"),
		,
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Files (%1 of %2) are locked for editing.';ru='Файлы (%1 из %2) заняты для редактирования.'"),
			LockedCount,
			ExecuteParameters.FilesArray.Count()),
		PictureLib.Information32);
	
	ReturnResult(ExecuteParameters.ResultHandler, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Opening the file for editing by reference.

// Opens file for editing.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  ObjectRef            - CatalogRef.Files - file.
//  UUID - UUID of the form.
//  OwnerWorkingDirectory - String - owner working directory.
//
// Returns:
//  Boolean. True if the operation is completed successfully.
//
Procedure EditFileByRef(ResultHandler,
	ObjectRef,
	UUID = Undefined,
	OwnerWorkingDirectory = Undefined) Export
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("ResultHandler", ResultHandler);
	HandlerParameters.Insert("ObjectRef", ObjectRef);
	HandlerParameters.Insert("UUID", UUID);
	HandlerParameters.Insert("OwnerWorkingDirectory", OwnerWorkingDirectory);
	
	Handler = New NotifyDescription("EditFileByRefAfterInstallingExtension", ThisObject, HandlerParameters);
	
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(Handler);
	
EndProcedure

// Procedure continued (see above).
Procedure EditFileByRefAfterInstallingExtension(ExtensionIsSet, ExecuteParameters) Export
	
	ExecuteParameters.Insert("FileData", Undefined);
	ExecuteParameters.Insert("ExtensionAttached", FileFunctionsServiceClient.FileOperationsExtensionConnected());
	
	ErrorText = "";
	DataReceived = FileOperationsServiceServerCall.GetFileDataForOpeningAndLockFile(ExecuteParameters.ObjectRef,
		ExecuteParameters.FileData, ErrorText, ExecuteParameters.UUID, ExecuteParameters.OwnerWorkingDirectory);
	
	If Not DataReceived Then
		StandardProcessing = True;
		FileOperationsClientOverridable.AtFileCaptureError(ExecuteParameters.FileData, StandardProcessing);
		
		If StandardProcessing Then
			// If you can not lock the file, then error message is displayed.
			ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, False);
			Return;
		EndIf;
		
		ReturnResult(ExecuteParameters.ResultHandler, True);
		Return;
	EndIf;
	
	If ExecuteParameters.ExtensionAttached Then
		ForRead = False;
		InOwnerWorkingDirectory = ExecuteParameters.FileData.OwnerWorkingDirectory <> "";
		ReregisterFileInWorkingDirectory(ExecuteParameters.FileData, ForRead, InOwnerWorkingDirectory);
	EndIf;
	
	ShowUserNotification(
		NStr("en='Edit file';ru='Редактирование файла'"),
		ExecuteParameters.FileData.URL,
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='The
		|file ""%1"" busy for editing.';ru='Файл
		|""%1"" занят для редактирования.'"), String(ExecuteParameters.FileData.Ref)),
			PictureLib.Information32);
	
	// If it is File without file, then the card is opened.
	If ExecuteParameters.FileData.Version.IsEmpty() Then 
		ReturnResultAfterDisplayValues(ExecuteParameters.ResultHandler, ExecuteParameters.FileData.Ref, True);
		Return;
	EndIf;
	
	If ExecuteParameters.ExtensionAttached Then
		Handler = New NotifyDescription("EditFileByReferenceWithExtensionAfterReceivingFileInWorkingDirectory", ThisObject, ExecuteParameters);
		GetVersionFileToWorkingDirectory(
			Handler,
			ExecuteParameters.FileData,
			"",
			ExecuteParameters.UUID);
	Else
		FillInTemporaryFormIdentifier(ExecuteParameters.UUID, ExecuteParameters);
		
		Handler = New NotifyDescription("EditFileByReferenceEnd", ThisObject, ExecuteParameters);
		OpenFileWithoutExtension(Handler, ExecuteParameters.FileData, ExecuteParameters.UUID);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure EditFileByReferenceWithExtensionAfterReceivingFileInWorkingDirectory(Result, ExecuteParameters) Export
	
	If Result.FileReceived = True Then
		OpenFileByApplication(ExecuteParameters.FileData, Result.FullFileName, ExecuteParameters.ResultHandler);
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, Result.FileReceived = True);
	
EndProcedure

// Procedure continued (see above).
Procedure EditFileByReferenceEnd(Result, ExecuteParameters) Export
	
	ClearTemporaryFormIdentifier(ExecuteParameters);
	
	ReturnResult(ExecuteParameters.ResultHandler, Result = True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Opening the file for editing.

// Opens file for editing.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FileData             - Structure with file data.
//  UUID - UUID of the form.
//
Procedure EditFile(ResultHandler, FileData, UUID = Undefined) Export
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("ResultHandler", ResultHandler);
	HandlerParameters.Insert("FileData", FileData);
	HandlerParameters.Insert("UUID", UUID);
	
	Handler = New NotifyDescription("EditFileAfterInstallingExtension", ThisObject, HandlerParameters);
	
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(Handler);
	
EndProcedure

// Procedure continued (see above).
Procedure EditFileAfterInstallingExtension(ExtensionIsSet, ExecuteParameters) Export
	
	ErrorText = "";
	YouCanLockFile = FileOperationsClientServer.IfYouCanLockFile(
		ExecuteParameters.FileData,
		ErrorText);
	If Not YouCanLockFile Then
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, False);
		Return;
	EndIf;
	
	// If File is not locked, then lock the file.
	If ExecuteParameters.FileData.IsEditing.IsEmpty() Then
		Handler = New NotifyDescription("EditFileAfterLockingFile", ThisObject, ExecuteParameters);
		LockFile(Handler, ExecuteParameters.FileData);
		Return;
	EndIf;
	
	EditFileAfterLockingFile(-1, ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure EditFileAfterLockingFile(FileData, ExecuteParameters) Export
	
	If FileData = Undefined Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	If FileData <> -1 Then
		ExecuteParameters.FileData = FileData;
	EndIf;
	
	// If File without file, then open the card.
	If ExecuteParameters.FileData.Version.IsEmpty() Then 
		ReturnResultAfterDisplayValues(ExecuteParameters.ResultHandler, ExecuteParameters.FileData.Ref, True);
		Return;
	EndIf;
	
	If FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		Handler = New NotifyDescription("EditFileWithExtensionAfterReceivingFileInWorkingDirectory", ThisObject, ExecuteParameters);
		GetVersionFileToWorkingDirectory(
			Handler,
			ExecuteParameters.FileData,
			"",
			ExecuteParameters.UUID);
	Else
		FillInTemporaryFormIdentifier(ExecuteParameters.UUID, ExecuteParameters);
		
		Handler = New NotifyDescription("EditFileWithoutExtensionEnd", ThisObject, ExecuteParameters);
		OpenFileWithoutExtension(Handler, ExecuteParameters.FileData, ExecuteParameters.UUID);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure EditFileWithExtensionAfterReceivingFileInWorkingDirectory(Result, ExecuteParameters) Export
	
	If Result.FileReceived = True Then
		OpenFileByApplication(ExecuteParameters.FileData, Result.FullFileName);
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, Result.FileReceived = True);
	
EndProcedure

// Procedure continued (see above).
Procedure EditFileWithoutExtensionEnd(Result, ExecuteParameters) Export
	
	ClearTemporaryFormIdentifier(ExecuteParameters);
	
	ReturnResult(ExecuteParameters.ResultHandler, Result = True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Opening file version.

// Open file version.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FileData             - Structure with file data.
//  UUID - UUID of the form.
//
Procedure OpenFileVersion(ResultHandler, FileData, UUID = Undefined) Export
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("ResultHandler", ResultHandler);
	HandlerParameters.Insert("FileData", FileData);
	HandlerParameters.Insert("UUID", UUID);
	
	Handler = New NotifyDescription("OpenFileVersionAfterInstallingExtension", ThisObject, HandlerParameters);
	
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(Handler);
	
EndProcedure

// Procedure continued (see above).
Procedure OpenFileVersionAfterInstallingExtension(ExtensionIsSet, ExecuteParameters) Export
	
	If FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		Handler = New NotifyDescription("OpenFileVersionAfterReceivingFileInWorkingDirectory", ThisObject, ExecuteParameters);
		GetVersionFileToWorkingDirectory(
			Handler,
			ExecuteParameters.FileData,
			"",
			ExecuteParameters.UUID);
	Else
		Address = FileOperationsServiceServerCall.GetURLForOpening(
			ExecuteParameters.FileData.Version, ExecuteParameters.UUID);
		
		FileName = CommonUseClientServer.GetNameWithExtention(
			ExecuteParameters.FileData.FullDescrOfVersion, ExecuteParameters.FileData.Extension);
		
		GetFile(Address, FileName, True);
		
		ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure OpenFileVersionAfterReceivingFileInWorkingDirectory(Result, ExecuteParameters) Export
	
	If Result.FileReceived Then
		OpenFileByApplication(ExecuteParameters.FileData, Result.FullFileName);
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Unlocking files without update.

// Releases files without update.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FilesArray - Array - file array.
//
Procedure ReleaseFilesByRefs(ResultHandler, Val FilesArray) Export
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("ResultHandler", ResultHandler);
	HandlerParameters.Insert("FilesArray", FilesArray);
	
	Handler = New NotifyDescription("UnlockFilesByReferencesAfterInstallingExtension", ThisObject, HandlerParameters);
	
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(Handler);
	
EndProcedure

// Procedure continued (see above).
Procedure UnlockFilesByReferencesAfterInstallingExtension(ExtensionIsSet, ExecuteParameters) Export
	
	// Getting the array of files data.
	ExecuteParameters.Insert("DataFiles", New Array);
	FileOperationsServiceServerCall.GetDataForArrayOfFiles(ExecuteParameters.FilesArray, ExecuteParameters.DataFiles);
	ArrayVBoundary = ExecuteParameters.DataFiles.UBound();
	
	// Checking the possibility to unlock the files.
	For Ind = 0 To ArrayVBoundary Do
		FileData = ExecuteParameters.DataFiles[ArrayVBoundary - Ind];
		
		ErrorText = "";
		YouCanUnlockFile = PossibilityToReleaseFile(
			FileData.Ref,
			FileData.CurrentUserIsEditing,
			FileData.IsEditing,
			ErrorText);
		If Not YouCanUnlockFile Then
			ExecuteParameters.DataFiles.Delete(ArrayVBoundary - Ind);
		EndIf;
		
	EndDo;
	
	ExtensionAttached = FileFunctionsServiceClient.FileOperationsExtensionConnected();
	
	Handler = New NotifyDescription("UnlockFilesByReferencesAfterAnswerToQuestionCancelEditing", ThisObject, ExecuteParameters);
	
	ShowQueryBox(
		Handler,
		NStr("en='Cancelling files editing
		|can lead to losing your changes.
		|
		|Continue?';ru='Отмена редактирования
		|файлов может привести к потере Ваших изменений.
		|
		|Продолжить?'"),
		QuestionDialogMode.YesNo,
		,
		DialogReturnCode.No);
	
EndProcedure

// Procedure continued (see above).
Procedure UnlockFilesByReferencesAfterAnswerToQuestionCancelEditing(Response, ExecuteParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		ReturnResult(ExecuteParameters.ResultHandler, Undefined);
		Return;
	EndIf;
	
	// Files locking.
	For Each FileData IN ExecuteParameters.DataFiles Do
		
		Parameters = FileReleaseParameters(Undefined, FileData.Ref);
		Parameters.StoreVersions = FileData.StoreVersions;
		Parameters.CurrentUserIsEditing = FileData.CurrentUserIsEditing;
		Parameters.IsEditing = FileData.IsEditing;
		Parameters.DoNotAskQuestion = True;
		ReleaseFile(Parameters);
		
	EndDo;
	
	ShowUserNotification(
		NStr("en='Cancel file editing';ru='Отменить редактирование файлов'"),,
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='File editing is canceled (%1 of %2).';ru='Отменено редактирование файлов (%1 из %2).'"),
			ExecuteParameters.DataFiles.Count(),
			ExecuteParameters.FilesArray.Count()),
		PictureLib.Information32);
	
	ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Unlocking the file without update.

// Returns:
//   Structure - with properties:
//    * ResultHandler    - AlertDescription, Undefined - description of the procedure
//                                that receives the result of method work.
//    * ObjectRef            - CatalogRef.Files - file.
//    * Version                  - CatalogRef.FileVersions - file version.
//    * StoreVersions           - Boolean - store versions.
//    * CurrentUserIsEditing - Boolean - current user is editing the file.
//    * Edits             - CatalogRef.Users - who locked the file.
//    *UUID - UUID - identifier of managed form.
//    * DoNotAskQuestion        - Boolean - do not ask the question
//                                         "Cancellation of file editing may lead to loss of your changes. Continue?".
//
Function FileReleaseParameters(ResultHandler, ObjectRef) Export
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("ResultHandler", ResultHandler);
	HandlerParameters.Insert("ObjectRef", ObjectRef);
	HandlerParameters.Insert("Version");
	HandlerParameters.Insert("StoreVersions");
	HandlerParameters.Insert("CurrentUserIsEditing");
	HandlerParameters.Insert("IsEditing");
	HandlerParameters.Insert("UUID");
	HandlerParameters.Insert("DoNotAskQuestion", False);
	Return HandlerParameters;
	
EndFunction	
	
// Releases the file without update.
//
// Parameters:
//  FileReleaseParameters - Structure - see FileUnlockingParameters.
//
Procedure ReleaseFile(FileReleaseParameters)
	
	Handler = New NotifyDescription("UnlockFileAfterExtensionInstallation", ThisObject, FileReleaseParameters);
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(Handler);
	
EndProcedure

// Procedure continued (see above).
Procedure UnlockFileAfterExtensionInstallation(ExtensionIsSet, ExecuteParameters) Export
	
	ExecuteParameters.Insert("FileData", Undefined);
	ExecuteParameters.Insert("ContinueWork", True);
	
	If ExecuteParameters.StoreVersions = Undefined Then
		ExecuteParameters.FileData = FileOperationsServiceServerCall.FileData(
			?(ExecuteParameters.ObjectRef <> Undefined, ExecuteParameters.ObjectRef, ExecuteParameters.Version));
		
		If Not ValueIsFilled(ExecuteParameters.ObjectRef) Then
			ExecuteParameters.ObjectRef = ExecuteParameters.FileData.Ref;
		EndIf;
		ExecuteParameters.StoreVersions                  = ExecuteParameters.FileData.StoreVersions;
		ExecuteParameters.CurrentUserIsEditing = ExecuteParameters.FileData.CurrentUserIsEditing;
		ExecuteParameters.IsEditing                    = ExecuteParameters.FileData.IsEditing;
	EndIf;
	
	// Checking the possibility to unlock the file.
	ErrorText = "";
	YouCanUnlockFile = PossibilityToReleaseFile(
		ExecuteParameters.ObjectRef,
		ExecuteParameters.CurrentUserIsEditing,
		ExecuteParameters.IsEditing,
		ErrorText);
	
	If Not YouCanUnlockFile Then
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, False);
		Return;
	EndIf;
	
	If ExecuteParameters.DoNotAskQuestion = False Then
		ExecuteParameters.ResultHandler = PrepareHandlerForDialog(ExecuteParameters.ResultHandler);
		Handler = New NotifyDescription("UnlockFileAfterAnswerToQuestionCancelEdit", ThisObject, ExecuteParameters);
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Cancellation of
		|file
		|""%1"" editing may lead to loss of your changes.
		|
		|Continue?';ru='Отмена
		|редактирования
		|файла ""%1"" может привести к потере ваших изменений.
		|
		|Продолжить?'"),
			String(ExecuteParameters.ObjectRef));
		ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No);
		Return;
	EndIf;
	
	UnlockFileAfterAnswerToQuestionCancelEdit(-1, ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure UnlockFileAfterAnswerToQuestionCancelEdit(Response, ExecuteParameters) Export
	
	If Response <> -1 Then
		If Response = DialogReturnCode.Yes Then
			ExecuteParameters.ContinueWork = True;
		Else
			ExecuteParameters.ContinueWork = False;
		EndIf;
	EndIf;
	
	If ExecuteParameters.ContinueWork Then
		
		FileOperationsServiceServerCall.GetFileDataAndReleaseFile(ExecuteParameters.ObjectRef,
			ExecuteParameters.FileData, ExecuteParameters.UUID);
		
		If FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
			ForRead = True;
			InOwnerWorkingDirectory = ExecuteParameters.FileData.OwnerWorkingDirectory <> "";
			ReregisterFileInWorkingDirectory(ExecuteParameters.FileData, ForRead, InOwnerWorkingDirectory);
		EndIf;
		
		If Not ExecuteParameters.DoNotAskQuestion Then
			ShowUserNotification(
				NStr("en='File is released';ru='Файл освобожден'"),
				ExecuteParameters.FileData.URL,
				ExecuteParameters.FileData.FullDescrOfVersion,
				PictureLib.Information32);
		EndIf;
		
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// File changes record.

Function FileUpdateParameters(ResultHandler, ObjectRef, FormID) Export
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("ResultHandler", ResultHandler);
	HandlerParameters.Insert("ObjectRef", ObjectRef);
	HandlerParameters.Insert("FormID", FormID);
	HandlerParameters.Insert("StoreVersions");
	HandlerParameters.Insert("CurrentUserIsEditing");
	HandlerParameters.Insert("IsEditing");
	HandlerParameters.Insert("CurrentVersionAuthor");
	HandlerParameters.Insert("TransferredFullPathToFile", "");
	HandlerParameters.Insert("CreateNewVersion");
	HandlerParameters.Insert("CommentToVersion");
	HandlerParameters.Insert("ShowAlert", True);
	HandlerParameters.Insert("ApplyToAll", False);
	HandlerParameters.Insert("ToReleaseFiles", True);
	HandlerParameters.Insert("Encoding");
	Return HandlerParameters;
	
EndFunction	

// Start recording file changes.
//
// Parameters:
//   FileUpdateParameters - Structure - see FileUpdateParameters.
//
Procedure SaveFileChanges(FileUpdateParameters) 
	
	Handler = New NotifyDescription("SaveFileChangesAfterInstallingExtension", ThisObject, FileUpdateParameters);
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(Handler);
		
EndProcedure

// Procedure continued (see above).
Procedure SaveFileChangesAfterInstallingExtension(ExtensionIsSet, ExecuteParameters) Export
	
	ExecuteParameters.Insert("FileData", Undefined);
	ExecuteParameters.Insert("TemporaryStorageAddress", Undefined);
	ExecuteParameters.Insert("FullPathToFile", Undefined);
	
	If FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		SaveFileWithExpansionChanges(ExecuteParameters);
	Else
		SaveFileChangesWithoutExtension(ExecuteParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure SaveFileWithExpansionChanges(ExecuteParameters)
	// Code for thin client, thick client and web client with a connected extension.
	
	ExecuteParameters.FileData = FileOperationsServiceServerCall.FileDataAndWorkingDirectory(ExecuteParameters.ObjectRef);
	
	ExecuteParameters.StoreVersions = ExecuteParameters.FileData.StoreVersions;
	
	// Checking the possibility to unlock the file.
	ErrorText = "";
	YouCanUnlockFile = PossibilityToReleaseFile(
		ExecuteParameters.FileData.Ref,
		ExecuteParameters.FileData.CurrentUserIsEditing,
		ExecuteParameters.FileData.IsEditing,
		ErrorText);
	If Not YouCanUnlockFile Then
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, False);
		Return;
	EndIf;
	
	ExecuteParameters.FullPathToFile = ExecuteParameters.TransferredFullPathToFile;
	If ExecuteParameters.FullPathToFile = "" Then
		ExecuteParameters.FullPathToFile = ExecuteParameters.FileData.FullFileNameInWorkingDirectory;
	EndIf;
	
	// Checking file existence on the disk.
	ExecuteParameters.Insert("NewVersionFile", New File(ExecuteParameters.FullPathToFile));
	If Not ExecuteParameters.NewVersionFile.Exist() Then
		If Not IsBlankString(ExecuteParameters.FullPathToFile) Then
			WarningString = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Failed to place the ""%1"" file in
		|file storage: File is not found
		|in working directory: %2.
		|
		|Unlock file?';ru='Не удалось поместить файл
		|""%1"" в хранилище файлов: Файл
		|не найден в рабочем каталоге: %2.
		|
		|Освободить файл?'"),
				String(ExecuteParameters.FileData.Ref),
				ExecuteParameters.FullPathToFile);
		Else
			WarningString = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Failed to place the ""%1"" file in
		|file storage: File is not found in working directory.
		|
		|Unlock file?';ru='Не удалось поместить файл
		|""%1"" в хранилище файлов: Файл не найден в рабочем каталоге.
		|
		|Освободить файл?'"),
				String(ExecuteParameters.FileData.Ref));
		EndIf;
		
		Handler = New NotifyDescription("SaveFileChangesWithExtensionAfterAnswerToQuestionUnlockFile", ThisObject, ExecuteParameters);
		ShowQueryBox(Handler, WarningString, QuestionDialogMode.YesNo);
		Return;
	EndIf;
	
	// Query for comment and version storage flag.
	If ExecuteParameters.CreateNewVersion = Undefined Then
		
		ReturnForm = FileOperationsServiceClientReUse.FileReturnForm();
		
		ExecuteParameters.CreateNewVersion = True;
		CreateNewVersionEnabled = True;
		
		If ExecuteParameters.FileData.StoreVersions Then
			ExecuteParameters.CreateNewVersion = True;
			
			// If the author of current version is
			// not current user, then check box "Do not create a new version" is disabled.
			If ExecuteParameters.FileData.CurrentVersionAuthor <> ExecuteParameters.FileData.IsEditing Then
				CreateNewVersionEnabled = False;
			Else
				CreateNewVersionEnabled = True;
			EndIf;
		Else
			ExecuteParameters.CreateNewVersion = False;
			CreateNewVersionEnabled = False;
		EndIf;
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("FileRef",                    ExecuteParameters.FileData.Ref);
		ParametersStructure.Insert("CommentToVersion",            "");
		ParametersStructure.Insert("CreateNewVersion",            ExecuteParameters.CreateNewVersion);
		ParametersStructure.Insert("CreateNewVersionEnabled", CreateNewVersionEnabled);
		
		ReturnForm.SetUsageParameters(ParametersStructure);
		
		Handler = New NotifyDescription("SaveFileWithExtesionChangesAfterPlacingFileOnServer", ThisObject, ExecuteParameters);
		SetFormAlert(ReturnForm, Handler);
		
		ReturnForm.Open();
		
	Else // Parameters CreateNewVersion and CommentToVersion are passed from the outside.
		
		If ExecuteParameters.StoreVersions Then
			
			// If the author of current version is
			// not current user, then check box "Do not create a new version" is disabled.
			If ExecuteParameters.CurrentVersionAuthor <> ExecuteParameters.IsEditing Then
				ExecuteParameters.CreateNewVersion = True;
			EndIf;
			
		Else
			ExecuteParameters.CreateNewVersion = False;
		EndIf;
		
		SaveFileChangesWithExtensionAfterCheckingNewVersion(ExecuteParameters);
		
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure SaveFileChangesWithExtensionAfterAnswerToQuestionUnlockFile(Response, ExecuteParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		ReleaseFileWithoutQuestion(ExecuteParameters.FileData, ExecuteParameters.FormID);
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, False);
	
EndProcedure

// Procedure continued (see above).
Procedure SaveFileWithExtesionChangesAfterPlacingFileOnServer(Result, ExecuteParameters) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	ReturnCode = Result.ReturnCode;
	If ReturnCode <> DialogReturnCode.OK Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	ExecuteParameters.CreateNewVersion = Result.CreateNewVersion;
	ExecuteParameters.CommentToVersion = Result.CommentToVersion;
	
	SaveFileChangesWithExtensionAfterCheckingNewVersion(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure SaveFileChangesWithExtensionAfterCheckingNewVersion(ExecuteParameters)
	
	If Not ExecuteParameters.FileData.Encrypted Then
		SaveFileChangesWithExtensionAfterCheckingEncrypted(, ExecuteParameters);
		Return;
	EndIf;
	
	// File with flag "encrypted" is encrypted again for the same certificates.
	
	ExecuteParameters.Insert("AlertAfterEncryption", New NotifyDescription(
		"SaveFileChangesWithExtensionAfterCheckingEncrypted", ThisObject, ExecuteParameters));
	
	EncryptFileBeforePlacingToFilesStorage(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure SaveFileChangesWithExtensionAfterCheckingEncrypted(NOTSpecified, ExecuteParameters) Export
	
	FileInformation = FileOperationsClientServer.FileInformation("FileWithVersion", ExecuteParameters.NewVersionFile);
	FileInformation.Comment = ExecuteParameters.CommentToVersion;
	FileInformation.StoreVersions = ExecuteParameters.CreateNewVersion;
	
	If ExecuteParameters.Property("AddressAfterEncryption") Then
		FileInformation.FileTemporaryStorageAddress = ExecuteParameters.AddressAfterEncryption;
	Else
		SizeInMB = FileInformation.Size / (1024 * 1024);
		ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Transfer of ""%1"" file is in progress (%2 Mb)...
		|Please, wait.';ru='Выполняется передача файла ""%1"" (%2 Мб)...
		|Пожалуйста, подождите.'"),
			FileInformation.BaseName,
			FileFunctionsServiceClientServer.GetStringWithFileSize(SizeInMB));
		Status(ExplanationText);
		
		FilesToPlace = New Array;
		Definition = New TransferableFileDescription(ExecuteParameters.FullPathToFile, "");
		FilesToPlace.Add(Definition);
		
		PlacedFiles = New Array;
		FilesPlaced = PutFiles(FilesToPlace, PlacedFiles, , False, ExecuteParameters.FormID);
		
		Status();
		If Not FilesPlaced Then
			ReturnResult(ExecuteParameters.ResultHandler, True);
			Return;
		EndIf;
		
		If PlacedFiles.Count() = 1 Then
			FileInformation.FileTemporaryStorageAddress = PlacedFiles[0].Location;
		EndIf;
	EndIf;
	
	FileOperationsCommonSettings = FileFunctionsServiceClientServer.FileOperationsCommonSettings();
	DirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	
	RelativePathToFile = "";
	If ExecuteParameters.FileData.OwnerWorkingDirectory <> "" Then // There is a working directory.
		RelativePathToFile = ExecuteParameters.FullPathToFile;
	Else
		Position = Find(ExecuteParameters.FullPathToFile, DirectoryName);
		If Position <> 0 Then
			RelativePathToFile = Mid(ExecuteParameters.FullPathToFile, StrLen(DirectoryName) + 1);
		EndIf;
	EndIf;
	
	If Not FileOperationsCommonSettings.ExtractFileTextsAtServer Then
		TextTemporaryStorageAddress = FileFunctionsServiceClientServer.ExtractTextToTemporaryStorage(
			ExecuteParameters.FullPathToFile,
			ExecuteParameters.FormID);
	Else
		TextTemporaryStorageAddress = "";
	EndIf;
	
	NotChangeRecordInWorkingDirectory = False;
	If ExecuteParameters.TransferredFullPathToFile <> "" Then
		NotChangeRecordInWorkingDirectory = True;
	EndIf;
	
	VersionUpdated = FileOperationsServiceServerCall.SaveFileChanges(ExecuteParameters.FileData.Ref, FileInformation, 
		NotChangeRecordInWorkingDirectory, RelativePathToFile, ExecuteParameters.FullPathToFile, 
		ExecuteParameters.FileData.OwnerWorkingDirectory <> "", ExecuteParameters.FormID);
	If ExecuteParameters.ShowAlert Then
		If VersionUpdated Then
			ShowUserNotification(
				NStr("en='New version is saved';ru='Новая версия сохранена'"),
				ExecuteParameters.FileData.URL,
				ExecuteParameters.FileData.FullDescrOfVersion,
				PictureLib.Information32);
		Else
			ShowUserNotification(
				NStr("en='New version is not saved';ru='Новая версия не сохранена'"),,
				NStr("en='File is not changed';ru='Файл не изменился'"),
				PictureLib.Information32);
			Handler = New NotifyDescription("SaveFileChangesWithExtensionAfterShowingNotification", ThisObject, ExecuteParameters);
			ShowInformationFileWasNotChanged(Handler);
			Return;
		EndIf;
	EndIf;
	
	SaveFileChangesWithExtensionAfterShowingNotification(-1, ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure SaveFileChangesWithExtensionAfterShowingNotification(Result, ExecuteParameters) Export
	
	ReturnResult(ExecuteParameters.ResultHandler, True);
	
EndProcedure

// Procedure continued (see above).
Procedure SaveFileChangesWithoutExtension(ExecuteParameters)
	
	If ExecuteParameters.StoreVersions = Undefined Then
		ExecuteParameters.FileData = FileOperationsServiceServerCall.FileData(ExecuteParameters.ObjectRef);
		ExecuteParameters.StoreVersions                  = ExecuteParameters.FileData.StoreVersions;
		ExecuteParameters.CurrentUserIsEditing = ExecuteParameters.FileData.CurrentUserIsEditing;
		ExecuteParameters.IsEditing                    = ExecuteParameters.FileData.IsEditing;
		ExecuteParameters.CurrentVersionAuthor             = ExecuteParameters.FileData.CurrentVersionAuthor;
	EndIf;
	
	// Checking the possibility to unlock the file.
	ErrorText = "";
	YouCanUnlockFile = PossibilityToReleaseFile(
		ExecuteParameters.ObjectRef,
		ExecuteParameters.CurrentUserIsEditing,
		ExecuteParameters.IsEditing,
		ErrorText);
	If Not YouCanUnlockFile Then
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, False);
		Return;
	EndIf;
	
	ExecuteParameters.FullPathToFile = "";
	If ExecuteParameters.CreateNewVersion = Undefined Then
		
		// Query for comment and version storage flag.
		ReturnForm = FileOperationsServiceClientReUse.FileReturnForm();
		
		ExecuteParameters.CreateNewVersion = True;
		CreateNewVersionEnabled = True;
		
		If ExecuteParameters.StoreVersions Then
			ExecuteParameters.CreateNewVersion = True;
			
			// If the author of current version is
			// not current user, then check box "Do not create a new version" is disabled.
			If ExecuteParameters.CurrentVersionAuthor <> ExecuteParameters.IsEditing Then
				CreateNewVersionEnabled = False;
			Else
				CreateNewVersionEnabled = True;
			EndIf;
		Else
			ExecuteParameters.CreateNewVersion = False;
			CreateNewVersionEnabled = False;
		EndIf;
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("FileRef",                    ExecuteParameters.ObjectRef);
		ParametersStructure.Insert("CommentToVersion",            "");
		ParametersStructure.Insert("CreateNewVersion",            ExecuteParameters.CreateNewVersion);
		ParametersStructure.Insert("CreateNewVersionEnabled", CreateNewVersionEnabled);
		
		ReturnForm.SetUsageParameters(ParametersStructure);
		
		Handler = New NotifyDescription("SaveFileChangesWithoutExtensionAfterPlacingFileOnServer", ThisObject, ExecuteParameters);
		SetFormAlert(ReturnForm, Handler);
		
		ReturnForm.Open();
		
	Else // Parameters CreateNewVersion and CommentToVersion are passed from the outside.
		
		If ExecuteParameters.StoreVersions Then
			
			// If the author of current version is
			// not current user, then check box "Do not create a new version" is disabled.
			If ExecuteParameters.CurrentVersionAuthor <> ExecuteParameters.IsEditing Then
				ExecuteParameters.CreateNewVersion = True;
			EndIf;
			
		Else
			ExecuteParameters.CreateNewVersion = False;
		EndIf;
		
		SaveFileChangesWithoutExtensionAfterCheckingNewVersion(ExecuteParameters);
		
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure SaveFileChangesWithoutExtensionAfterPlacingFileOnServer(Result, ExecuteParameters) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	If Result.ReturnCode <> DialogReturnCode.OK Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	ExecuteParameters.CreateNewVersion = Result.CreateNewVersion;
	ExecuteParameters.CommentToVersion = Result.CommentToVersion;
	
	SaveFileChangesWithoutExtensionAfterCheckingNewVersion(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure SaveFileChangesWithoutExtensionAfterCheckingNewVersion(ExecuteParameters) Export
	
	Handler = New NotifyDescription("SaveFileChangesWithoutExtensionAfterReminder", ThisObject, ExecuteParameters);
	ShowReminderBeforePutFile(Handler);
	
EndProcedure

// Procedure continued (see above).
Procedure SaveFileChangesWithoutExtensionAfterReminder(Result, ExecuteParameters) Export
	
	Handler = New NotifyDescription("SaveFileChangesWithoutExtensionAfterFileImport", ThisObject, ExecuteParameters);
	BeginPutFile(Handler, , ExecuteParameters.FullPathToFile, , ExecuteParameters.FormID);
	
EndProcedure

// Procedure continued (see above).
Procedure SaveFileChangesWithoutExtensionAfterFileImport(Placed, Address, SelectedFileName, ExecuteParameters) Export
	
	If Not Placed Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	ExecuteParameters.Insert("ImportedFileAddress", Address);
	ExecuteParameters.Insert("SelectedFileName", SelectedFileName);
	
	If ExecuteParameters.FileData = Undefined Then
		FileData = FileOperationsServiceServerCall.FileData(ExecuteParameters.ObjectRef);
	Else
		FileData = ExecuteParameters.FileData;
	EndIf;
	If Not FileData.Encrypted Then
		SaveFileChangesWithoutExtensionAfterEncryptingFile(Null, ExecuteParameters);
		Return;
	EndIf;
	If CertificatesNotSpecified(FileData.ArrayOfEncryptionCertificates) Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	// No need to OfferSettingFileOperationsExtension() as all is done in memory through BinaryData.
	
	DataDescription = New Structure;
	DataDescription.Insert("Operation",            NStr("en='File encryption';ru='Шифрование файла'"));
	DataDescription.Insert("DataTitle",     NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("Data",              Address);
	DataDescription.Insert("Presentation",       ExecuteParameters.ObjectRef);
	DataDescription.Insert("CertificatesSet",   ExecuteParameters.ObjectRef);
	DataDescription.Insert("WithoutConfirmation",    True);
	DataDescription.Insert("NotifyAboutCompletion", False);
	
	ContinuationHandler = New NotifyDescription("SaveFileChangesWithoutExtensionAfterEncryptingFile",
		ThisObject, ExecuteParameters);
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.Encrypt(DataDescription, , ContinuationHandler);
	
EndProcedure

// Procedure continued (see above).
Procedure SaveFileChangesWithoutExtensionAfterEncryptingFile(DataDescription, ExecuteParameters) Export
	
	If DataDescription = Null Then
		Address = ExecuteParameters.ImportedFileAddress;
		
	ElsIf Not DataDescription.Success Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	Else
		If TypeOf(DataDescription.EncryptedData) = Type("BinaryData") Then
			Address = PutToTempStorage(DataDescription.EncryptedData,
				ExecuteParameters.FormID);
		Else
			Address = DataDescription.EncryptedData;
		EndIf;
	EndIf;
	
	FileInformation = FileOperationsClientServer.FileInformation("FileWithVersion");
	ExecuteParameters.TemporaryStorageAddress = Address;
	FileInformation.FileTemporaryStorageAddress = Address;
	FileInformation.StoreVersions = ExecuteParameters.CreateNewVersion;
	
	PathStrings = CommonUseClientServer.SortStringByPointsAndSlashes(ExecuteParameters.SelectedFileName);
	If PathStrings.Count() >= 2 Then
		FileInformation.ExtensionWithoutDot = PathStrings[PathStrings.Count() - 1];
		FileInformation.BaseName = PathStrings[PathStrings.Count() - 2];
	EndIf;
	
	Result = FileOperationsServiceServerCall.GetFileDataAndSaveFileChanges(ExecuteParameters.ObjectRef, FileInformation, 
		"", ExecuteParameters.FullPathToFile, False, ExecuteParameters.FormID);
	ExecuteParameters.FileData = Result.FileData;
	If ExecuteParameters.ShowAlert Then
		ShowUserNotification(
			NStr("en='New version is saved';ru='Новая версия сохранена'"),
			ExecuteParameters.FileData.URL,
			ExecuteParameters.FileData.FullDescrOfVersion,
			PictureLib.Information32);
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, True);
	
EndProcedure


// For procedures SaveFileChanges, EndEdit.
Procedure EncryptFileBeforePlacingToFilesStorage(ExecuteParameters)
	
	If CertificatesNotSpecified(ExecuteParameters.FileData.ArrayOfEncryptionCertificates) Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	// No need to OfferSettingFileOperationsExtension() as all is done in memory through BinaryData.
	
	DataDescription = New Structure;
	DataDescription.Insert("Operation",            NStr("en='File encryption';ru='Шифрование файла'"));
	DataDescription.Insert("DataTitle",     NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("Data",              ExecuteParameters.FullPathToFile);
	DataDescription.Insert("Presentation",       ExecuteParameters.ObjectRef);
	DataDescription.Insert("CertificatesSet",   ExecuteParameters.ObjectRef);
	DataDescription.Insert("WithoutConfirmation",    True);
	DataDescription.Insert("NotifyAboutCompletion", False);
	
	ContinuationHandler = New NotifyDescription("EncryptFileBeforePlacingToFilesStorageAfterEncryptingFile",
		ThisObject, ExecuteParameters);
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.Encrypt(DataDescription, , ContinuationHandler);
	
EndProcedure

// Procedure continued (see above).
Procedure EncryptFileBeforePlacingToFilesStorageAfterEncryptingFile(DataDescription, ExecuteParameters) Export
	
	If DataDescription = Null Then
		Address = ExecuteParameters.ImportedFileAddress;
		
	ElsIf Not DataDescription.Success Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	Else
		If TypeOf(DataDescription.EncryptedData) = Type("BinaryData") Then
			Address = PutToTempStorage(DataDescription.EncryptedData,
				ExecuteParameters.FormID);
		Else
			Address = DataDescription.EncryptedData;
		EndIf;
	EndIf;
	
	ExecuteParameters.Insert("AddressAfterEncryption", Address);
	
	ExecuteNotifyProcessing(ExecuteParameters.AlertAfterEncryption);
	
EndProcedure


// For procedures SaveFileChanges, EndEdit.
Function CertificatesNotSpecified(CertificatesArray)
	
	If CertificatesArray.Count() = 0 Then
		ShowMessageBox(,
			NStr("en='Encrypted file does not have specified certificates.
		|Decrypt the file and encrypt again.';ru='У зашифрованного файла не указаны сертификаты.
		|Расшифруйте файл и зашифруйте заново.'"));
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Marking the file as locked for editing.

// Marking the file as locked for editing.
//
// Parameters:
//   ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//   FileData - structure with file data.
//
// Returns:
//   * Undefined - If the file is not locked.
//   * Structure with file data - If the file is locked.
//
Procedure LockFile(ResultHandler, FileData)
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("ResultHandler", ResultHandler);
	HandlerParameters.Insert("FileData",           FileData);
	
	Handler = New NotifyDescription("LockFileAfterSettingExtension", ThisObject, HandlerParameters);
	
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(Handler);
	
EndProcedure

// Procedure continued (see above).
Procedure LockFileAfterSettingExtension(ExtensionIsSet, ExecuteParameters) Export
	
	ErrorText = "";
	YouCanLockFile = FileOperationsClientServer.IfYouCanLockFile(
		ExecuteParameters.FileData,
		ErrorText);
	If Not YouCanLockFile Then
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, Undefined);
		Return;
	EndIf;
	
	ErrorText = "";
	FileIsBusy = FileOperationsServiceServerCall.LockFile(ExecuteParameters.FileData, ErrorText);
	If Not FileIsBusy Then
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, Undefined);
		Return;
	EndIf;
	
	If FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		ForRead = False;
		InOwnerWorkingDirectory = ExecuteParameters.FileData.OwnerWorkingDirectory <> "";
		ReregisterFileInWorkingDirectory(ExecuteParameters.FileData, ForRead, InOwnerWorkingDirectory);
	EndIf;
	
	ShowUserNotification(
		NStr("en='Edit file';ru='Редактирование файла'"),
		ExecuteParameters.FileData.URL,
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='The
		|file ""%1"" busy for editing.';ru='Файл
		|""%1"" занят для редактирования.'"),
			String(ExecuteParameters.FileData.Ref)),
		PictureLib.Information32);
	
	ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters.FileData);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Unlocking files without update.

// Releases files without update.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  ObjectsRef - Array - file array.
//
Procedure ReleaseFiles(ResultHandler, ObjectsRef) Export
	
	ListImpossibleRelease = New ValueList;
	
	// Getting Files data array.
	DataFiles = FileOperationsServiceServerCall.FileData(ObjectsRef);
	ArrayVBoundary  = DataFiles.UBound();
	
	// Checking the possibility to unlock the files.
	For Ind = 0 To ArrayVBoundary Do
		FileData = DataFiles[ArrayVBoundary - Ind];
		
		ErrorText = "";
		YouCanUnlockFile = PossibilityToReleaseFile(
			FileData.Ref,
			FileData.CurrentUserIsEditing,
			FileData.IsEditing,
			ErrorText);
		If Not YouCanUnlockFile Then // Impossible to release.
			ListImpossibleRelease.Add(FileData.Ref, ErrorText);
			DataFiles.Delete(ArrayVBoundary - Ind);
		EndIf;
		
	EndDo;
	
	// If it is impossible to unlock, then the dialog is opened.
	HandlerParameters = New Structure;
	HandlerParameters.Insert("ResultHandler", ResultHandler);
	HandlerParameters.Insert("ObjectsRef", ObjectsRef);
	HandlerParameters.Insert("DataFiles", DataFiles);
	Handler = New NotifyDescription("UnlockFilesAfterReplyToQuestion", ThisObject, HandlerParameters);
	
	If ListImpossibleRelease.Count() > 0 Then
		QuestionWithListDialog(
			Handler,
			ListImpossibleRelease,
			NStr("en='Unlock the files left?';ru='Освободить остальные файлы?'"),
			NStr("en='The following errors occurred while trying to unlock the files:';ru='При попытке освободить файлы возникли следующие ошибки:'"),
			NStr("en='Unlock files';ru='Освободить файлы'"));
	Else
		ShowQueryBox(
			Handler,
			NStr("en='Unlocking the
		|files may lead to loss of your changes.
		|
		|Unlock files?';ru='Освобождение
		|файлов может привести к потере ваших изменений.
		|
		|Освободить файлы?'"),
			QuestionDialogMode.YesNo,
			,
			DialogReturnCode.No);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure UnlockFilesAfterReplyToQuestion(Response, ExecuteParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		ReturnResult(ExecuteParameters.ResultHandler, Undefined);
		Return;
	EndIf;
	
	// Unlocking the files.
	For Each FileData IN ExecuteParameters.DataFiles Do
		
		FileOperationsServiceServerCall.ReleaseFile(FileData);
		
		If FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
			ForRead = True;
			InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
			ReregisterFileInWorkingDirectory(FileData, ForRead, InOwnerWorkingDirectory);
		EndIf;
		
		ShowUserNotification(
			NStr("en='File is released';ru='Файл освобожден'"),
			FileData.URL,
			FileData.FullDescrOfVersion,
			PictureLib.Information32);
		
	EndDo;
	
	ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Opening question dialog with the list of files or information.

// Opens question dialog with a list of files or information about the files.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  List - ValueList - files list.
//  MessageQuestion - String - question text.
//  MessageTitle - String - text of question header.
//  Title - String - form title.
//
Procedure QuestionWithListDialog(ResultHandler, List, MessageQuestion, MessageTitle, Title)
	
	FormParameters = New Structure;
	FormParameters.Insert("MessageQuestion", MessageQuestion);
	FormParameters.Insert("MessageTitle", MessageTitle);
	FormParameters.Insert("Title", Title);
	FormParameters.Insert("Files", List);
	
	WindowOpeningMode = FormWindowOpeningMode.LockWholeInterface;
	
	OpenForm("Catalog.Files.Form.QuestionForm", FormParameters, , , , , ResultHandler, WindowOpeningMode);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// File deletion. Before deletion "Read only" attribute is removed.

// Deleting the file with removing the readonly attribute without dialogs.
//
// Parameters:
//  FullFileName - String -  Full attachment file name.
//
Procedure DeleteFileWithoutConfirmation(FullFileName)
	
	File = New File(FullFileName);
	If File.Exist() Then
		File.SetReadOnly(False);
		DeleteFiles(FullFileName);
	EndIf;
	
EndProcedure

// Deleting the file with removing the readonly attribute.
//
// Parameters:
//  ResultHandler - NotifyDescription, Structure, Undefined - Description of the
//                         procedure that receives the result of method work.
//  FullFileName - String -  Full attachment file name.
//  AskQuestion - Boolean- Ask the question about removing.
//  QuestionHeader - String - Question header - adds text to the question about removing.
//
Procedure DeleteFile(ResultHandler, FullFileName, AskQuestion = Undefined, QuestionHeader = Undefined) Export
	
	If AskQuestion = Undefined Then
		PersonalSettings = FileFunctionsServiceClientServer.PersonalFileOperationsSettings();
		AskQuestion = PersonalSettings.ConfirmWhenDeletingFromLocalFilesCache;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("FullFileName", FullFileName);
	
	If AskQuestion = True Then
		QuestionText =
			NStr("en='Delete
		|file ""%1"" from working directory?';ru='Удалить
		|файл ""%1"" из рабочего каталога?'");
		QuestionText = StrReplace(QuestionText, "%1", FullFileName);
		If QuestionHeader <> Undefined Then
			QuestionText = QuestionHeader + Chars.LF + Chars.LF + QuestionText;
		EndIf;
		ExecuteParameters.ResultHandler = PrepareHandlerForDialog(ExecuteParameters.ResultHandler);
		Handler = New NotifyDescription("DeleteFileAfterAnswerToQuestion", ThisObject, ExecuteParameters);
		ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo);
		Return;
	EndIf;
	
	DeleteFileAfterAnswerToQuestion(-1, ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure DeleteFileAfterAnswerToQuestion(Response, ExecuteParameters) Export
	
	If Response <> -1 Then
		If Response = DialogReturnCode.No Then
			ReturnResult(ExecuteParameters.ResultHandler, False);
			Return;
		EndIf;
	EndIf;
	
	DeleteFileWithoutConfirmation(ExecuteParameters.FullFileName);
	
	ReturnResult(ExecuteParameters.ResultHandler, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Receiving the file from the storage in working directory.

// Receives File from file storage
// in working directory and returns path to this file.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FileData        - Structure with file data.
//  FullFileName     - String.
//  ForRead           - Boolean - False - for reading, True for editing.
//  FormID - UUID of the form.
//
// Returns:
//   Structure - Result.
//       * FileReceived - Boolean - Whether the operation was completed successfully.
//       * FileFullName - String - Full attachment file name.
//
Procedure GetVersionFileIntoLocalFilesCache(
	ResultHandler,
	FileData,
	ForRead,
	FormID,
	AdditionalParameters)
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("FileData", FileData);
	ExecuteParameters.Insert("ForRead", ForRead);
	ExecuteParameters.Insert("FormID", FormID);
	ExecuteParameters.Insert("AdditionalParameters", AdditionalParameters);
	
	GetVersionFileInLocalFilesCacheStart(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure GetVersionFileInLocalFilesCacheStart(ExecuteParameters)
	
	ExecuteParameters.Insert("FullFileName", "");
	ExecuteParameters.Insert("FileReceived", False);
	
	DateFileInBase   = ExecuteParameters.FileData.ModificationDateUniversal;
	FileSizeInBase = ExecuteParameters.FileData.Size;
	
	InWorkingDirectoryForRead = True;
	InOwnerWorkingDirectory = False;
	
	FileInWorkingDirectory = FileIsInFilesLocalCache(
		ExecuteParameters.FileData,
		ExecuteParameters.FileData.Version,
		ExecuteParameters.FullFileName,
		InWorkingDirectoryForRead,
		InOwnerWorkingDirectory);
	
	If FileInWorkingDirectory = False Then
		GetFromServerAndRegisterInFilesLocalCache(
			ExecuteParameters.ResultHandler,
			ExecuteParameters.FileData,
			ExecuteParameters.FullFileName,
			ExecuteParameters.FileData.ModificationDateUniversal,
			ExecuteParameters.ForRead,
			ExecuteParameters.FormID,
			ExecuteParameters.AdditionalParameters);
		Return;
	EndIf;

	// Get file path in working directory - with the check on uniqueness.
	If ExecuteParameters.FullFileName = "" Then
		CommonUseClientServer.MessageToUser(
			NStr("en='An error occurred when receiving
		|the file from files storage in working directory.';ru='Ошибка получения
		|файла из хранилища файлов в рабочий каталог.'"));
		ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
		Return;
	EndIf;
	
	// It was found out that the File exists in the working directory.
	// Date change checking and decision making, what is the next step.
	Handler = New NotifyDescription("GetVersionFileInLocalFilesCacheAfterSelectingAction", ThisObject, ExecuteParameters);
	
	FileFunctionsServiceClient.ActionOnFileOpeningInWorkingDirectory(
		Handler,
		ExecuteParameters.FullFileName,
		ExecuteParameters.FileData);
	
EndProcedure

// Procedure continued (see above).
Procedure GetVersionFileInLocalFilesCacheAfterSelectingAction(Result, ExecuteParameters) Export
	
	If Result = "TakeFromStorageAndOpen" Then
		
		Handler = New NotifyDescription("GetVersionFileInLocalFilesCacheAfterDeletion", ThisObject, ExecuteParameters);
		DeleteFile(Handler, ExecuteParameters.FullFileName);
		
	ElsIf Result = "OpenExisting" Then
		
		If ExecuteParameters.FileData.InWorkingDirectoryForRead <> ExecuteParameters.ForRead Then
			InOwnerWorkingDirectory = ExecuteParameters.FileData.OwnerWorkingDirectory <> "";
			
			ReregisterInWorkingDirectory(
				ExecuteParameters.FileData.Version,
				ExecuteParameters.FullFileName,
				ExecuteParameters.ForRead,
				InOwnerWorkingDirectory);
		EndIf;
		
		ExecuteParameters.FileReceived = True;
		ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
		
	Else // Result = "Cancel".
		ExecuteParameters.FullFileName = "";
		ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure GetVersionFileInLocalFilesCacheAfterDeletion(FileRemoved, ExecuteParameters) Export
	
	GetFromServerAndRegisterInFilesLocalCache(
		ExecuteParameters.ResultHandler,
		ExecuteParameters.FileData,
		ExecuteParameters.FullFileName,
		ExecuteParameters.FileData.ModificationDateUniversal,
		ExecuteParameters.ForRead,
		ExecuteParameters.FormID,
		ExecuteParameters.AdditionalParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Receiving file from the application on disk.

// Gets File from infobase on local disk and
// returns the path to this file in the parameter.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FileData  - structure with file data.
//  FullFileName - String - here full attachment file name is returned.
//  FormID - form unique ID.
//
// Returns:
//   Structure - Result of file receipt.
//       * FileReceived - Boolean - Whether the operation was completed successfully.
//       * FileFullName - String - Full attachment file name.
//
Procedure GetVersionFileToWorkingDirectory(
		ResultHandler,
		FileData,
		FullFileName,
		FormID = Undefined,
		AdditionalParameters = Undefined) Export
	
	DirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	
	If DirectoryName = Undefined Or IsBlankString(DirectoryName) Then
		ReturnResult(ResultHandler, New Structure("FileReceived, FullFileName", False, FullFileName));
		Return;
	EndIf;
	
	If FileData.OwnerWorkingDirectory = "" Or FileData.Version <> FileData.CurrentVersion Then
		GetVersionFileIntoLocalFilesCache(
			ResultHandler,
			FileData,
			FileData.ForRead,
			FormID,
			AdditionalParameters);
	Else
		GetVersionFileIntoFolderWorkingDirectory(
			ResultHandler,
			FileData,
			FullFileName,
			FileData.ForRead,
			FormID,
			AdditionalParameters);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Opening Windows Explorer with positioning on the file.

// Procedure opens Windows Explorer positioning on File.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FileData  - structure with file data.
//
Procedure FileDir(ResultHandler, FileData) Export
	
	// If File without file  - this operation is meaningless.
	If FileData.Version.IsEmpty() Then 
		Return;
	EndIf;
	
	#If WebClient Then
		If Not FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
			FileFunctionsServiceClient.ShowWarningAboutNeedToFileOperationsExpansion(ResultHandler);
			Return;
		EndIf;
	#EndIf
	
	FullFileName = GetFilePathInWorkingDirectory(FileData);
	If FileFunctionsServiceClient.OpenExplorerWithFile(FullFileName) = True Then
		Return;
	EndIf;
	
	FileName = CommonUseClientServer.GetNameWithExtention(
		FileData.FullDescrOfVersion, FileData.Extension);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("ResultHandler", ResultHandler);
	HandlerParameters.Insert("FileData", FileData);
	HandlerParameters.Insert("FileName", FileName);
	HandlerParameters.Insert("FullFileName", FullFileName);
	Handler = New NotifyDescription("FileDirectoryAfterAnsweringQuestionGetFile", ThisObject, HandlerParameters);
	
	ShowQueryBox(
		Handler,
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='File
		|""%1"" is absent in the working directory.
		|
		|Do you want to receive the file from the file storage?';ru='Файл
		|""%1"" отсутствует в рабочем каталоге.
		|
		|Получить файл из хранилища файлов?'"),
			FileName),
		QuestionDialogMode.YesNo);
	
EndProcedure

// Procedure continued (see above).
Procedure FileDirectoryAfterAnsweringQuestionGetFile(Response, ExecuteParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		Handler = New NotifyDescription("FileDirectoryAfterReceivingFileInWorkingDirectory", ThisObject, ExecuteParameters);
		GetVersionFileToWorkingDirectory(Handler, ExecuteParameters.FileData, ExecuteParameters.FullFileName);
	Else
		FileDirectoryAfterReceivingFileInWorkingDirectory(-1, ExecuteParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure FileDirectoryAfterReceivingFileInWorkingDirectory(Result, ExecuteParameters) Export
	
	If Result <> -1 Then
		ExecuteParameters.FullFileName = Result.FullFileName;
		FileFunctionsServiceClient.OpenExplorerWithFile(ExecuteParameters.FullFileName);
	EndIf;
	
	// For variant with file storage on the disk (on the server) we remove File from the temporary storage after its reception.
	If IsTempStorageURL(ExecuteParameters.FileData.CurrentVersionURL) Then
		DeleteFromTempStorage(ExecuteParameters.FileData.CurrentVersionURL);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Deleting the file from disk and information register.

// Delete from disk and information register.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  Ref  - CatalogRef.Files - file.
//  DeleteInWorkingDirectory - Boolean - Delete even in working directory.
//
// Returns:
//   Structure - Result of file deletion from the disk and information register.
//       * Success - Boolean - whether the operation is successfully completed.
//
Procedure DeleteFileFromWorkingDirectory(ResultHandler, Ref, DeleteInWorkingDirectory = False) Export
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("Ref", Ref);
	ExecuteParameters.Insert("Success", False);
	ExecuteParameters.Insert("DirectoryName", FileFunctionsServiceClient.UserWorkingDirectory());
	
	ExecuteParameters.Insert("FullFileNameFromRegister", Undefined);
	
	InOwnerWorkingDirectory = False;
	ExecuteParameters.FullFileNameFromRegister = FileOperationsServiceServerCall.GetFullFileNameFromRegister(
		ExecuteParameters.Ref, ExecuteParameters.DirectoryName, False, InOwnerWorkingDirectory);
	
	If ExecuteParameters.FullFileNameFromRegister <> "" Then
		
		// IN the working directory you normally do not remove - only if transferred DeleteInWorkingDirectory.
		If Not InOwnerWorkingDirectory OR DeleteInWorkingDirectory = True Then
			
			FileOnDrive = New File(ExecuteParameters.FullFileNameFromRegister);
			
			If FileOnDrive.Exist() Then
				FileOnDrive.SetReadOnly(False);
				
				RegisterHandlerDescription(
					ExecuteParameters, ThisObject, "DeleteFileFromWorkingDirectoryAfterDeletingFile");
				
				DeleteFile(ExecuteParameters, ExecuteParameters.FullFileNameFromRegister);
				If ExecuteParameters.AsynchronousDialog.Open = True Then
					Return;
				EndIf;
				
				DeleteFileFromWorkingDirectoryAfterDeletingFile(
					ExecuteParameters.AsynchronousDialog.ResultWhenNotOpen, ExecuteParameters);
				Return;
				
			EndIf;
		EndIf;
	EndIf;
	
	DeleteFileFromWorkingDirectoryEnd(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure DeleteFileFromWorkingDirectoryAfterDeletingFile(Result, ExecuteParameters) Export
	
	PathWithSubdirectory = ExecuteParameters.DirectoryName;
	Position = Find(ExecuteParameters.FullFileNameFromRegister, CommonUseClientServer.PathSeparator());
	If Position <> 0 Then
		PathWithSubdirectory = PathWithSubdirectory + Left(ExecuteParameters.FullFileNameFromRegister, Position);
	EndIf;
	
	FileArrayInDirectory = FindFiles(PathWithSubdirectory, "*");
	If FileArrayInDirectory.Count() = 0 Then
		If PathWithSubdirectory <> ExecuteParameters.DirectoryName Then
			DeleteFiles(PathWithSubdirectory);
		EndIf;
	EndIf;
	
	DeleteFileFromWorkingDirectoryEnd(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure DeleteFileFromWorkingDirectoryEnd(ExecuteParameters)
	
	If ExecuteParameters.FullFileNameFromRegister = "" Then
		FileOperationsServiceServerCall.DeleteFromRegister(ExecuteParameters.Ref);
	Else
		FileOnDrive = New File(ExecuteParameters.FullFileNameFromRegister);
		If Not FileOnDrive.Exist() Then
			FileOperationsServiceServerCall.DeleteFromRegister(ExecuteParameters.Ref);
		EndIf;
	EndIf;
	
	ExecuteParameters.Success = True;
	ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Clearing working directory.

// Free up the space to place the file - if there is space, it does not do anything.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  VersionAttributes  - structure with version attributes.
//
Procedure FreePlaceInWorkingDirectory(ResultHandler, VersionAttributes)

	#If WebClient Then
		// Impossible to determine the amount of free space on disk in web client.
		ReturnResultAfterShowWarning(
			ResultHandler,
			NStr("en='Working directory cleanup is not supported in web client.';ru='Очистка рабочего каталога не поддерживается в веб-клиенте.'"),
			Undefined);
		Return;
	#EndIf
	
	MaxSize = FileFunctionsServiceClientServer.PersonalFileOperationsSettings(
		).LocalFilesCacheMaximumSize;
	
	// If the size of WorkingDirectory
	// is set equal to 0, then it is assumed that there is no restriction and default 10 Mb is not used.
	If MaxSize = 0 Then
		Return;
	EndIf;
	
	DirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	
	FilesArray = FindFiles(DirectoryName, "*.*");
	
	FilesSizeInWorkingDirectory = 0;
	QuantitySummary = 0;
	// Calculate total size of files in working directory.
	FileFunctionsServiceClient.BypassFilesSize(DirectoryName, FilesArray, FilesSizeInWorkingDirectory, QuantitySummary);
	
	Size = VersionAttributes.Size;
	If FilesSizeInWorkingDirectory + Size > MaxSize Then
		ClearWorkingDirectory(ResultHandler, FilesSizeInWorkingDirectory, Size, False); // ClearAll = False.
	EndIf;
	
EndProcedure

// Clearing working directory - to free up the space - first removes the files most recently placed in a working directory.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FilesSizeInWorkingDirectory  - Number - the size of files in working directory.
//  AddedFileSize - Number - Added file size.
//  ToClearAll - Boolean - Delete all files in the directory (not only before freeing up necessary space on disk).
//
Procedure ClearWorkingDirectory(ResultHandler, FilesSizeInWorkingDirectory, AddedFileSize, ToClearAll) Export
	
	#If WebClient Then
		ReturnResultAfterShowWarning(ResultHandler, NStr("en='Working directory cleanup is not supported in web client.';ru='Очистка рабочего каталога не поддерживается в веб-клиенте.'"), Undefined);
		Return;
	#EndIf
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("ResultHandler", ResultHandler);
	HandlerParameters.Insert("FilesSizeInWorkingDirectory", FilesSizeInWorkingDirectory);
	HandlerParameters.Insert("AddedFileSize", AddedFileSize);
	HandlerParameters.Insert("ToClearAll", ToClearAll);
	
	ClearWorkingDirectoryStart(HandlerParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure ClearWorkingDirectoryStart(ExecuteParameters)
	
	DirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	
	FileTable = New Array;
	FilesArray = FindFiles(DirectoryName, "*");
	BypassFilesTable(DirectoryName, FilesArray, FileTable);
	
	// Calling the server - for
	//  sorting sort by date - the earliest placed in a working directory will be at the beginning.
	FileOperationsServiceServerCall.SortStructuresArray(FileTable);
	
	PersonalSettings = FileFunctionsServiceClientServer.PersonalFileOperationsSettings();
	MaxSize = PersonalSettings.LocalFilesCacheMaximumSize;
	
	AverageFileSize = 1000;
	If FileTable.Count() <> 0 Then
		AverageFileSize = ExecuteParameters.FilesSizeInWorkingDirectory / FileTable.Count();
	EndIf;
	
	HowMuchRequiredFreeSpace = MaxSize / 10;
	If AverageFileSize * 3 / 2 > HowMuchRequiredFreeSpace Then
		HowMuchRequiredFreeSpace = AverageFileSize * 3 / 2;
	EndIf;
	
	HowMuchRemained = ExecuteParameters.FilesSizeInWorkingDirectory + ExecuteParameters.AddedFileSize;
	
	ExecuteParameters.Insert("DirectoryName", DirectoryName);
	ExecuteParameters.Insert("MaxSize", MaxSize);
	ExecuteParameters.Insert("HowMuchRemained", HowMuchRemained);
	ExecuteParameters.Insert("HowMuchRequiredFreeSpace", HowMuchRequiredFreeSpace);
	
	ExecuteParameters.Insert("FileTable", FileTable);
	ExecuteParameters.Insert("ItemNumber", 1);
	ExecuteParameters.Insert("ItemCount", FileTable.Count());
	ExecuteParameters.Insert("Item", Undefined);
	ExecuteParameters.Insert("YesForAll", False);
	ExecuteParameters.Insert("NoForAll", False);
	
	ExecuteParameters.Insert("StepNumber", 0);
	ExecuteParameters.Insert("InterruptCycle", False);
	
	RegisterHandlerDescription(ExecuteParameters, ThisObject, "ClearWorkingDirectoryDialogHandlerInCycle");
	
	ClearWorkingDirectoryCycleStart(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure ClearWorkingDirectoryCycleStart(ExecuteParameters)
	
	While ExecuteParameters.ItemNumber <= ExecuteParameters.ItemCount Do
		ExecuteParameters.Item = ExecuteParameters.FileTable[ExecuteParameters.ItemNumber - 1];
		ExecuteParameters.ItemNumber = ExecuteParameters.ItemNumber + 1;
		
		ExecuteParameters.StepNumber = 1;
		ClearWorkingDirectoryCycleHandler(ExecuteParameters);
		If ExecuteParameters.AsynchronousDialog.Open Then
			Return; // Cycle pause. Stack clearing in progress.
		EndIf;
		If ExecuteParameters.InterruptCycle Then
			Break;
		EndIf;
	EndDo;
	
	// Actions after the cycle.
	If ExecuteParameters.ToClearAll Then
		FileOperationsServiceServerCall.ClearAllOursExceptLockedOnes();
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	
EndProcedure

// Procedure continued (see above).
Procedure ClearWorkingDirectoryCycleHandler(ExecuteParameters)
	
	If ExecuteParameters.StepNumber = 1 Then
		If Not ExecuteParameters.YesForAll
			AND ExecuteParameters.Item.Version.IsEmpty() Then
			
			If ExecuteParameters.NoForAll Then
				Return; // IN relation to the cycle this is equal to key word "Continue".
			EndIf;
			
			If ExecuteParameters.ToClearAll = False Then
				QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Work directory is cleared when adding the file.
		|
		|In files storage file ""%1""
		|was not found.
		|
		|Do you want to delete it from the work directory?';ru='Выполняется очистка рабочего каталога при добавлении файла.
		|
		|В хранилище файлов не
		|найден файл ""%1"".
		|
		|Удалить его из рабочего каталога?'"),
					ExecuteParameters.DirectoryName + ExecuteParameters.Item.Path);
			Else
				QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='In files storage file ""%1""
		|was not found.
		|
		|Do you want to delete it from the work directory?';ru='В хранилище файлов не
		|найден файл ""%1"".
		|
		|Удалить его из рабочего каталога?'"),
					ExecuteParameters.DirectoryName + ExecuteParameters.Item.Path);
			EndIf;
			
			Buttons = New ValueList;
			Buttons.Add("Yes",         NStr("en='Yes';ru='Да'"));
			Buttons.Add("YesForAll",  NStr("en='Yes to all';ru='Да для всех'"));
			Buttons.Add("No",        NStr("en='No';ru='Нет'"));
			Buttons.Add("NoForAll", NStr("en='No for all';ru='Нет для всех'"));
			
			ShowQueryBox(PrepareHandlerForDialog(ExecuteParameters), QuestionText, Buttons);
			Return;
		EndIf;
		
		ExecuteParameters.StepNumber = 2;
	EndIf;
	
	If ExecuteParameters.StepNumber = 2 Then
		FullPath = ExecuteParameters.DirectoryName + ExecuteParameters.Item.Path;
		FileOnDrive = New File(FullPath);
		FileOnDrive.SetReadOnly(False);
		If ExecuteParameters.ToClearAll = False Then
			QuestionHeader = NStr("en='Clearing the working directory while adding a file.';ru='Выполняется очистка рабочего каталога при добавлении файла.'");
		Else
			QuestionHeader = NStr("en='Clearing the working directory.';ru='Выполняется очистка рабочего каталога.'");
		EndIf;
		
		DeleteFile(ExecuteParameters, FullPath, Undefined, QuestionHeader);
		If ExecuteParameters.AsynchronousDialog.Open Then
			Return; // Cycle pause. Stack clearing in progress.
		EndIf;
		
		ExecuteParameters.StepNumber = 3;
	EndIf;
	
	If ExecuteParameters.StepNumber = 3 Then
		
		PathWithSubdirectory = ExecuteParameters.DirectoryName;
		Position = Find(ExecuteParameters.Item.Path, CommonUseClientServer.PathSeparator());
		If Position <> 0 Then
			PathWithSubdirectory = ExecuteParameters.DirectoryName + Left(ExecuteParameters.Item.Path, Position);
		EndIf;
		
		// If the directory has become empty - delete it.
		FileArrayInDirectory = FindFiles(PathWithSubdirectory, "*");
		If FileArrayInDirectory.Count() = 0 Then
			If PathWithSubdirectory <> ExecuteParameters.DirectoryName Then
				DeleteFiles(PathWithSubdirectory);
			EndIf;
		EndIf;
		
		// Deleting from information register.
		FileOperationsServiceServerCall.DeleteFromRegister(ExecuteParameters.Item.Version);
		
		ExecuteParameters.HowMuchRemained = ExecuteParameters.HowMuchRemained - ExecuteParameters.Item.Size;
		If ExecuteParameters.HowMuchRemained < ExecuteParameters.MaxSize - ExecuteParameters.HowMuchRequiredFreeSpace Then
			If Not ExecuteParameters.ToClearAll Then
				// Freed up enough - exit from cycle.
				ExecuteParameters.InterruptCycle = True;
				Return;
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure ClearWorkingDirectoryDialogHandlerInCycle(Result, ExecuteParameters) Export
	
	If ExecuteParameters.StepNumber = 1 Then
		If Result = "No" Then
			ContinueExecution = False;
		ElsIf Result = "NoForAll" Then
			ContinueExecution = False;
			ExecuteParameters.NoForAll = True;
		ElsIf Result = "Yes" Then
			ContinueExecution = True;
		ElsIf Result = "YesForAll" Then
			ContinueExecution = True;
			ExecuteParameters.YesForAll = True;
		EndIf;
	ElsIf ExecuteParameters.StepNumber = 2 Then
		ContinueExecution = True;
	EndIf;
	
	// Continue deleting the file
	If ContinueExecution Then
		ExecuteParameters.StepNumber = ExecuteParameters.StepNumber + 1;
		ExecuteParameters.AsynchronousDialog.Open = False;
		ClearWorkingDirectoryCycleHandler(ExecuteParameters);
		If ExecuteParameters.AsynchronousDialog.Open Then
			Return; // Cycle pause. Stack clearing in progress.
		EndIf;
	EndIf;
	
	// Continue the cycle.
	ExecuteParameters.AsynchronousDialog.Open = False;
	ClearWorkingDirectoryCycleStart(ExecuteParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Receiving the file from server and registering in local cache.

// Get File from server and register in local cache.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FileData  - structure with file data.
//  FullFileNameInWorkingDirectory - String - here full attachment file name is returned.
//  DateFileInBase - Date - file date in the base.
//  ForRead - Boolean - File is placed for reading.
//  FormID - form unique ID.
//
// Returns:
//   Structure - Result.
//       * FileReceived - Boolean - Whether the operation was completed successfully.
//       * FileFullName - String - Full attachment file name.
//
Procedure GetFromServerAndRegisterInFilesLocalCache(ResultHandler,
	FileData,
	FullFileName,
	ModificationTimeUniversal,
	ForRead,
	FormID,
	AdditionalParameters = Undefined)
	
	// Parameterization variables:
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("FileData", FileData);
	ExecuteParameters.Insert("FullFileName", FullFileName);
	ExecuteParameters.Insert("ModificationTimeUniversal", ModificationTimeUniversal);
	ExecuteParameters.Insert("ForRead", ForRead);
	ExecuteParameters.Insert("FormID", FormID);
	ExecuteParameters.Insert("AdditionalParameters", AdditionalParameters);
	
	GetFromServerAndRegisterInLocalFilesCacheStart(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure GetFromServerAndRegisterInLocalFilesCacheStart(ExecuteParameters)
	
	// Variables of execution:
	ExecuteParameters.Insert("InOwnerWorkingDirectory", ExecuteParameters.FileData.OwnerWorkingDirectory <> "");
	ExecuteParameters.Insert("DirectoryName", "");
	ExecuteParameters.Insert("DirectoryNameFormerValue", "");
	ExecuteParameters.Insert("FileName", "");
	ExecuteParameters.Insert("FullPathMaxLength", 260);
	ExecuteParameters.Insert("FileReceived", False);
	
	If ExecuteParameters.FullFileName = "" Then
		ExecuteParameters.DirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
		ExecuteParameters.DirectoryNameFormerValue = ExecuteParameters.DirectoryName;
		
		// Generating attachment file name with extension.
		ExecuteParameters.FileName = ExecuteParameters.FileData.FullDescrOfVersion;
		If Not IsBlankString(ExecuteParameters.FileData.Extension) Then 
			ExecuteParameters.FileName = CommonUseClientServer.GetNameWithExtention(ExecuteParameters.FileName, ExecuteParameters.FileData.Extension);
		EndIf;
		
		ExecuteParameters.FullFileName = "";
		If Not IsBlankString(ExecuteParameters.FileName) Then
			ExecuteParameters.FullFileName = ExecuteParameters.DirectoryName + FileFunctionsServiceClientServer.GetUniqueNameWithPath(
				ExecuteParameters.DirectoryName,
				ExecuteParameters.FileName);
		EndIf;
		
		If IsBlankString(ExecuteParameters.FileName) Then
			ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
			Return;
		EndIf;
		
		ExecuteParameters.FullPathMaxLength = 260;
		If Lower(ExecuteParameters.FileData.Extension) = "xls" Or Lower(ExecuteParameters.FileData.Extension) = "xlsx" Then
			// Excel Length of attachment file name together with path should not exceed 218 characters.
			ExecuteParameters.FullPathMaxLength = 218;
		EndIf;
		
		FileNameMaxLength = ExecuteParameters.FullPathMaxLength - 5; // 5 - minimum for "C:\1\"
		
		If ExecuteParameters.InOwnerWorkingDirectory = False Then
#If Not WebClient Then
			If StrLen(ExecuteParameters.FullFileName) > ExecuteParameters.FullPathMaxLength Then
				UserDirectoryPath = DirectoryDataUser();
				FileNameMaxLength = ExecuteParameters.FullPathMaxLength - StrLen(UserDirectoryPath);
				
				// If  file  name plus 5 exceeds 260 - write "Change attachment file name to a shorter one. OK" and exit.
				If StrLen(ExecuteParameters.FileName) > FileNameMaxLength Then
					MessageText =
					StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='The length of path to file (working directory plus file
		|name) exceeds %1 characters %2';ru='Длина пути к файлу (рабочий каталог плюс имя файла) превышает %1 символов
		|%2'"),
						ExecuteParameters.FullPathMaxLength,
						ExecuteParameters.FullFileName);
					
					MessageText = MessageText + Chars.CR + Chars.CR
						+ NStr("en='Replace the file name with a shorter one.';ru='Измените имя файла на более короткое.'");
					ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, MessageText, ExecuteParameters);
					Return;
				EndIf;
				
				GetFromServerAndRegisterInLocalFilesCacheOfferToSelectDirectory(-1, ExecuteParameters);
				Return;
			EndIf;
#EndIf
		EndIf;
		
	EndIf;
	
	GetFromServerAndRegisterInLocalFilesCacheContinued(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure GetFromServerAndRegisterInLocalFilesCacheOfferToSelectDirectory(Response, ExecuteParameters) Export
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='File path length exceeds %1 characters: %2 Choose another working directory?';ru='Длина пути к файлу превышает %1 символов: %2 Выбрать другой основной рабочий каталог?'"),
		ExecuteParameters.FullPathMaxLength,
		ExecuteParameters.FullFileName);
	Handler = New NotifyDescription("GetFromServerAndRegisterInLocalFilesCacheStartDirectorySelection", ThisObject, ExecuteParameters);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

// Procedure continued (see above).
Procedure GetFromServerAndRegisterInLocalFilesCacheStartDirectorySelection(Response, ExecuteParameters) Export
	
	If Response = DialogReturnCode.No Then
		ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
		Return;
	EndIf;
	
	// Choose another path to the working directory.
	Title = NStr("en='Select another main working directory';ru='Выберите другой основной рабочий каталог'");
	DirectorySelected = ChoosePathToWorkingDirectory(ExecuteParameters.DirectoryName, Title, False);
	If Not DirectorySelected Then
		ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
		Return;
	EndIf;
	
	ExecuteParameters.FullFileName = ExecuteParameters.DirectoryName + FileFunctionsServiceClientServer.GetUniqueNameWithPath(
		ExecuteParameters.DirectoryName,
		ExecuteParameters.FileName);
	
	// within 260 characters
	If StrLen(ExecuteParameters.FullFileName) <= ExecuteParameters.FullPathMaxLength Then
		Handler = New NotifyDescription("GetFromServerAndRegisterInLocalFilesCacheAfterTrasferringWorkingDirectoryContent", ThisObject, ExecuteParameters);
		TransferWorkingDirectoryContents(Handler, ExecuteParameters.DirectoryNameFormerValue, ExecuteParameters.DirectoryName);
	Else
		GetFromServerAndRegisterInLocalFilesCacheOfferToSelectDirectory(-1, ExecuteParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure GetFromServerAndRegisterInLocalFilesCacheAfterTrasferringWorkingDirectoryContent(ContentMoved, ExecuteParameters) Export
	
	If ContentMoved Then
		FileFunctionsServiceClient.SetUserWorkingDirectory(ExecuteParameters.DirectoryName);
		GetFromServerAndRegisterInLocalFilesCacheContinued(ExecuteParameters);
	Else
		ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure GetFromServerAndRegisterInLocalFilesCacheContinued(ExecuteParameters)
	
	#If Not WebClient Then
		If ExecuteParameters.InOwnerWorkingDirectory = False Then
			FreePlaceInWorkingDirectory(, ExecuteParameters.FileData);
		EndIf;
	#EndIf
	
	FileSize = 0;
	
	// Record File to directory
	ExecuteParameters.FileName = CommonUseClientServer.GetNameWithExtention(
		ExecuteParameters.FileData.FullDescrOfVersion,
		ExecuteParameters.FileData.Extension);
	
	SizeInMB = ExecuteParameters.FileData.Size / (1024 * 1024);
	
	FileOnDriveByName = New File(ExecuteParameters.FullFileName);
	NameAndExtensionInPath = FileOnDriveByName.Name;
	Position = Find(ExecuteParameters.FullFileName, NameAndExtensionInPath);
	PathToFile = "";
	If Position <> 0 Then
		PathToFile = Left(ExecuteParameters.FullFileName, Position - 1); // -1 - slash deduction
	EndIf;
	
	PathToFile = CommonUseClientServer.AddFinalPathSeparator(PathToFile);
	ExecuteParameters.Insert("ParameterPathToFile", PathToFile);
	
	ExecuteParameters.FullFileName = PathToFile + ExecuteParameters.FileName; // the extension could have changed
	
	ExplanationText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Transfer of ""%1"" file is in progress (%2 Mb)...
		|Please, wait.';ru='Выполняется передача файла ""%1"" (%2 Мб)...
		|Пожалуйста, подождите.'"),
		ExecuteParameters.FileName,
		FileFunctionsServiceClientServer.GetStringWithFileSize(SizeInMB));
	
	Status(ExplanationText);
	
	If ExecuteParameters.FileData.Property("UpdatePathFromFileOnDrive") Then
		
		FileCopy(ExecuteParameters.FileData.UpdatePathFromFileOnDrive, ExecuteParameters.FullFileName);
		
		Status();
		GetFromServerAndRegisterInLocalFilesCacheEnd(ExecuteParameters);
		
		Return;
	EndIf;
	
	If ExecuteParameters.FileData.Encrypted Then
		
		If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
			Return;
		EndIf;
		
		FillInTemporaryFormIdentifier(ExecuteParameters.FormID, ExecuteParameters);
		
		ReturnStructure = FileOperationsServiceServerCall.FileDataAndBinaryData(
			ExecuteParameters.FileData.Version,, ExecuteParameters.FormID);
		
		DataDescription = New Structure;
		DataDescription.Insert("Operation",              NStr("en='File decryption';ru='Расшифровка файла'"));
		DataDescription.Insert("DataTitle",       NStr("en='File';ru='Файловый'"));
		DataDescription.Insert("Data",                ReturnStructure.BinaryData);
		DataDescription.Insert("Presentation",         ExecuteParameters.FileData.Ref);
		DataDescription.Insert("EncryptionCertificates", ExecuteParameters.FileData.Ref);
		DataDescription.Insert("NotifyAboutCompletion",   False);
		
		ContinuationHandler = New NotifyDescription(
			"GetFromServerAndRegisterInLocalFilesCacheAfterDecryption",
			ThisObject,
			ExecuteParameters);
		
		ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
		ModuleDigitalSignatureClient.Decrypt(DataDescription, , ContinuationHandler);
		
		Return;
	EndIf;
	
	GetFromServerAndRegisterInLocalFilesCacheFileTransfer(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure GetFromServerAndRegisterInLocalFilesCacheAfterDecryption(DataDescription, ExecuteParameters) Export
	
	If Not DataDescription.Success Then
		ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
		Return;
	EndIf;
	
	If TypeOf(DataDescription.DecryptedData) = Type("BinaryData") Then
		FileURL = PutToTempStorage(DataDescription.DecryptedData,
			ExecuteParameters.FormID);
	Else
		FileURL = DataDescription.DecryptedData;
	EndIf;
	
	GetFromServerAndRegisterInLocalFilesCacheFileTransfer(ExecuteParameters, FileURL);
	
EndProcedure

// Procedure continued (see above).
Procedure GetFromServerAndRegisterInLocalFilesCacheFileTransfer(ExecuteParameters, FileURL = Undefined) Export
	
	If FileURL = Undefined Then
		If ExecuteParameters.FileData.Version <> ExecuteParameters.FileData.CurrentVersion Then
			FileURL = FileOperationsServiceServerCall.GetURLForOpening(
				ExecuteParameters.FileData.Version, ExecuteParameters.FormID);
		Else
			FileURL = ExecuteParameters.FileData.CurrentVersionURL;
		EndIf;
	EndIf;
	
	FilesToTransfer = New Array;
	Definition = New TransferableFileDescription(ExecuteParameters.FileName, FileURL);
	FilesToTransfer.Add(Definition);
	
	#If WebClient Then
		If ExecuteParameters.AdditionalParameters <> Undefined AND ExecuteParameters.AdditionalParameters.Property("OpenFile") Then
			
		OperationArray = New Array;
		
		CallDetails = New Array;
		CallDetails.Add("GetFiles");
		CallDetails.Add(FilesToTransfer);
		CallDetails.Add(Undefined);  // Not used.
		CallDetails.Add(ExecuteParameters.ParameterPathToFile);
		CallDetails.Add(False);          // Interactively = False.
		OperationArray.Add(CallDetails);
		
		CallDetails = New Array;
		CallDetails.Add("RunApp");
		CallDetails.Add(ExecuteParameters.FullFileName);
		OperationArray.Add(CallDetails);
		
		If Not RequestUserPermission(OperationArray) Then
			// User didn't permit.
			ClearTemporaryFormIdentifier(ExecuteParameters);
			ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
			Return;
		EndIf;
		
		EndIf;
	#EndIf
	
	If Not GetFiles(FilesToTransfer,, ExecuteParameters.ParameterPathToFile, False) Then
		ClearTemporaryFormIdentifier(ExecuteParameters);
		ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
		Return;
	EndIf;
	
	// For an option with files storing on disk
	// (server) file is removed from temporary storage after receipt.
	If IsTempStorageURL(FileURL) Then
		DeleteFromTempStorage(FileURL);
	EndIf;
	
	Status();
	
	// Set the time of file change in such a way that it stands in the current version.
	FileOnDrive = New File(ExecuteParameters.FullFileName);
	FileOnDrive.SetModificationUniversalTime(ExecuteParameters.ModificationTimeUniversal);
	
	GetFromServerAndRegisterInLocalFilesCacheEnd(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure GetFromServerAndRegisterInLocalFilesCacheEnd(ExecuteParameters)
	
	FileOnDrive = New File(ExecuteParameters.FullFileName);
	
	// T.k. size on disk may differ from size in the base (when adding from web client).
	FileSize = FileOnDrive.Size();
	
	FileOnDrive.SetReadOnly(ExecuteParameters.ForRead);
	
	ExecuteParameters.DirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	
	FileOperationsServiceServerCall.AddFileInformationToRegister(ExecuteParameters.FileData.Version,
		ExecuteParameters.FullFileName,	ExecuteParameters.DirectoryName, ExecuteParameters.ForRead, FileSize,
		ExecuteParameters.InOwnerWorkingDirectory);
	
	If ExecuteParameters.FileData.Size <> FileSize Then
		// When you update from a file, there is no need for correction on the disk.
		If Not ExecuteParameters.FileData.Property("UpdatePathFromFileOnDrive") Then
			
			FileOperationsServiceServerCall.RefreshFileAndVersionSize(ExecuteParameters.FileData, 
				FileSize, ExecuteParameters.FormID);
			
			NotifyChanged(ExecuteParameters.FileData.Ref);
			NotifyChanged(ExecuteParameters.FileData.Version);
			
			Notify("Record_File",
			           New Structure("Event", "FileDataChanged"),
			           ExecuteParameters.FileData.Ref);
		EndIf;
	EndIf;
	
	ClearTemporaryFormIdentifier(ExecuteParameters);
	
	ExecuteParameters.FileReceived = True;
	ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Receiving the file from the storage in working directory.

// Receives File from file storage in working
// directory of the folder and returns path to this file.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FileData        - Structure with file data.
//  FullFileName     - String (return value).
//  ForRead           - Boolean - False - for reading, True for editing.
//  FormID - UUID of the form.
//
// Returns:
//   Structure - Result.
//       * FileReceived - Boolean - Whether the operation was completed successfully.
//       * FileFullName - String - Full attachment file name.
//
Procedure GetVersionFileIntoFolderWorkingDirectory(ResultHandler,
	FileData,
	FullFileName,
	ForRead,
	FormID,
	AdditionalParameters)
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("FileData", FileData);
	ExecuteParameters.Insert("FullFileName", FullFileName);
	ExecuteParameters.Insert("ForRead", ForRead);
	ExecuteParameters.Insert("FormID", FormID);
	ExecuteParameters.Insert("AdditionalParameters", AdditionalParameters);
	
	GetFileVersionInFolderWorkingDirectoryStart(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure GetFileVersionInFolderWorkingDirectoryStart(ExecuteParameters)
	Var Version;
	Var DateSpaces;
	
	ExecuteParameters.Insert("FileReceived", False);
	
	InOwnerWorkingDirectory = True;
	
	// Generating attachment file name with extension.
	FileName = ExecuteParameters.FileData.FullDescrOfVersion;
	If Not IsBlankString(ExecuteParameters.FileData.Extension) Then 
		FileName = CommonUseClientServer.GetNameWithExtention(
			FileName, ExecuteParameters.FileData.Extension);
	EndIf;
	
	If ExecuteParameters.FullFileName = "" Then
		ExecuteParameters.FullFileName = ExecuteParameters.FileData.OwnerWorkingDirectory + FileName;
		Handler = New NotifyDescription("GetVersionFileInFolderWorkingDirectoryAfterCheckingPathLength", ThisObject, ExecuteParameters);
		CheckFullPathMaxLengthInWorkingDirectory(Handler, ExecuteParameters.FileData, ExecuteParameters.FullFileName, FileName);
	Else
		GetVersionFileInFolderWorkingDirectoryContinued(ExecuteParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure GetVersionFileInFolderWorkingDirectoryAfterCheckingPathLength(Result, ExecuteParameters) Export
	
	If Result = False Then
		ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
	Else
		GetVersionFileInFolderWorkingDirectoryContinued(ExecuteParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure GetVersionFileInFolderWorkingDirectoryContinued(ExecuteParameters)
	
	// Searching file registration in working directory (full name with path).
	FoundProperties = FileOperationsServiceServerCall.FindInRegisterByPath(ExecuteParameters.FullFileName);
	ExecuteParameters.Insert("FileIsInRegister", FoundProperties.FileIsInRegister);
	Version            = FoundProperties.Version;
	DateSpaces     = ?(ExecuteParameters.FileIsInRegister, FoundProperties.DateSpaces, DateSpaces);
	Owner          = FoundProperties.Owner;
	VersionNumber       = FoundProperties.VersionNumber;
	RegisterForRead = FoundProperties.RegisterForRead;
	InRegisterFileCode = FoundProperties.InRegisterFileCode;
	InFolder    = FoundProperties.InFolder;
	
	FileOnDrive = New File(ExecuteParameters.FullFileName);
	FileOnDriveExist = FileOnDrive.Exist();
	
	// Deleting file registration if it does not exist.
	If ExecuteParameters.FileIsInRegister AND Not FileOnDriveExist Then
		FileOperationsServiceServerCall.DeleteFromRegister(Version);
		ExecuteParameters.FileIsInRegister = False;
	EndIf;
	
	If Not ExecuteParameters.FileIsInRegister AND Not FileOnDriveExist Then
		GetFromServerAndRegisterInFolderWorkingDirectory(
			ExecuteParameters.ResultHandler,
			ExecuteParameters.FileData,
			ExecuteParameters.FullFileName,
			ExecuteParameters.FileData.ModificationDateUniversal,
			ExecuteParameters.ForRead,
			ExecuteParameters.FormID,
			ExecuteParameters.AdditionalParameters);
		Return;
	EndIf;
	
	// It has been established that the file exists in working directory.
	
	If ExecuteParameters.FileIsInRegister AND Version <> ExecuteParameters.FileData.CurrentVersion Then
		
		If Owner = ExecuteParameters.FileData.Ref AND RegisterForRead = True Then
			// If file versions have same
			// owner and existing file in working directory is
			// registered for reading, then it can be replaced by other file from the storage.
			GetFromServerAndRegisterInFolderWorkingDirectory(
				ExecuteParameters.ResultHandler,
				ExecuteParameters.FileData,
				ExecuteParameters.FullFileName,
				ExecuteParameters.FileData.ModificationDateUniversal,
				ExecuteParameters.ForRead,
				ExecuteParameters.FormID,
				ExecuteParameters.AdditionalParameters);
			Return;
		EndIf;
		
		If ExecuteParameters.FileData.Owner = InFolder Then // The same folder.
			WarningText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='File ""%1"" already exists in
		|work
		|directory and is connected with another file in infobase.
		|
		|File code in files storage: %2.
		|File code in working directory: %3.
		|
		|Rename the one of the infobase files.';ru='В рабочем каталоге уже
		|есть
		|файл ""%1"", связанный с другим файлом в информационной базе.
		|
		|Код файла в хранилище файлов: %2.
		|Код файла в рабочем каталоге: %3.
		|
		|Переименуйте один из файлов в информационной базе.'"),
				ExecuteParameters.FullFileName,
				ExecuteParameters.FileData.FileCode,
				InRegisterFileCode);
		Else
			WarningText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='File ""%1"" already exists in
		|work
		|directory and is connected with another file of infobase.
		|
		|File code in files storage: %2.
		|File code in working directory: %3.
		|
		|Change working directory of one of the folders in the infobase.
		|(Two folders must not have the same work directory).';ru='В рабочем каталоге уже
		|есть
		|файл ""%1"", связанный с другим файлом информационной базы.
		|
		|Код файла в хранилище файлов: %2.
		|Код файла в рабочем каталоге: %3.
		|
		|В информационной базе измените рабочий каталог одной из папок.
		|(У двух папок не должно быть одинакового рабочего каталога).'"),
				ExecuteParameters.FullFileName,
				ExecuteParameters.FileData.FileCode,
				InRegisterFileCode);
		EndIf;
		
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, WarningText, ExecuteParameters);
		Return;
	EndIf;
	
	// It was found out that the File exists in the working directory.
	// Either the file is not registered or it is registered and the version is the same.
	
	// Date change checking and decision making, what is the next step.
	Handler = New NotifyDescription("GetVersionFileInFolderWorkingDirectoryAfterSelectingAction", ThisObject, ExecuteParameters);
	
	FileFunctionsServiceClient.ActionOnFileOpeningInWorkingDirectory(
		Handler,
		ExecuteParameters.FullFileName,
		ExecuteParameters.FileData);
	
EndProcedure

// Procedure continued (see above).
Procedure GetVersionFileInFolderWorkingDirectoryAfterSelectingAction(Result, ExecuteParameters) Export
	
	If Result = "TakeFromStorageAndOpen" Then
		
		// IN working directory of the folder the setting for confirmation at deletion is not used.
		DeleteFileWithoutConfirmation(ExecuteParameters.FullFileName);
		GetFromServerAndRegisterInFilesLocalCache(
			ExecuteParameters.ResultHandler,
			ExecuteParameters.FileData,
			ExecuteParameters.FullFileName,
			ExecuteParameters.FileData.ModificationDateUniversal,
			ExecuteParameters.ForRead,
			ExecuteParameters.FormID,
			ExecuteParameters.AdditionalParameters);
		
	ElsIf Result = "OpenExisting" Then
		
		If ExecuteParameters.FileData.InWorkingDirectoryForRead <> ExecuteParameters.ForRead
			Or Not ExecuteParameters.FileIsInRegister Then
			
			InOwnerWorkingDirectory = ExecuteParameters.FileData.OwnerWorkingDirectory <> "";
			
			ReregisterInWorkingDirectory(
				ExecuteParameters.FileData.Version,
				ExecuteParameters.FullFileName,
				ExecuteParameters.ForRead,
				InOwnerWorkingDirectory);
		EndIf;
		
		ExecuteParameters.FileReceived = True;
		ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
		
	Else // Result = "Cancel".
		ExecuteParameters.FullFileName = "";
		ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Receiving the file from server and registering in working directory.

// Get File from server and register in working directory.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FileData  - structure with file data.
//  FullFileNameInWorkingDirectory - String - here full attachment file name is returned.
//  DateFileInBase - Date - file date in the base.
//  ForRead - Boolean - File is placed for reading.
//  FormID - form unique ID.
//
// Returns:
//   Structure - Result.
//       * FileReceived - Boolean - Whether the operation was completed successfully.
//       * FileFullName - String - Full attachment file name.
//
Procedure GetFromServerAndRegisterInFolderWorkingDirectory(
	ResultHandler,
	FileData,
	FullFileNameInFolderWorkingDirectory,
	DateFileInBase,
	ForRead,
	FormID,
	AdditionalParameters)
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("FileData", FileData);
	ExecuteParameters.Insert("FullFileNameInFolderWorkingDirectory", FullFileNameInFolderWorkingDirectory);
	ExecuteParameters.Insert("DateFileInBase", DateFileInBase);
	ExecuteParameters.Insert("ForRead", ForRead);
	ExecuteParameters.Insert("FormID", FormID);
	ExecuteParameters.Insert("AdditionalParameters", AdditionalParameters);
	
	GetFromServerAndRegisterInFolderWorkingDirectoryStart(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure GetFromServerAndRegisterInFolderWorkingDirectoryStart(ExecuteParameters)
	
	ExecuteParameters.Insert("FullFileName", "");
	ExecuteParameters.Insert("FileReceived", False);
	
	InWorkingDirectoryForRead = True;
	InOwnerWorkingDirectory = False;
	
	FileInWorkingDirectory = FileIsInFilesLocalCache(
		ExecuteParameters.FileData,
		ExecuteParameters.FileData.Version,
		ExecuteParameters.FullFileName,
		InWorkingDirectoryForRead,
		InOwnerWorkingDirectory);
	
	If FileInWorkingDirectory = False Then
		GetFromServerAndRegisterInFilesLocalCache(
			ExecuteParameters.ResultHandler,
			ExecuteParameters.FileData,
			ExecuteParameters.FullFileNameInFolderWorkingDirectory,
			ExecuteParameters.FileData.ModificationDateUniversal,
			ExecuteParameters.ForRead,
			ExecuteParameters.FormID,
			ExecuteParameters.AdditionalParameters);
		Return;
	EndIf;

	// Get file path in working directory - with the check on uniqueness.
	If ExecuteParameters.FullFileName = "" Then
		CommonUseClientServer.MessageToUser(
			NStr("en='An error occurred when receiving
		|the file from files storage in working directory.';ru='Ошибка получения
		|файла из хранилища файлов в рабочий каталог.'"));
		ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
		Return;
	EndIf;
	
	// It was found out that the File exists in the working directory.
	// Date change checking and decision making, what is the next step.
	Handler = New NotifyDescription("GetFromServerAndRegisterInFolderWorkingDirectoryAfterChoosingAction", ThisObject, ExecuteParameters);
	
	FileFunctionsServiceClient.ActionOnFileOpeningInWorkingDirectory(
		Handler,
		ExecuteParameters.FullFileName,
		ExecuteParameters.FileData);
	
EndProcedure

// Procedure continued (see above).
Procedure GetFromServerAndRegisterInFolderWorkingDirectoryAfterChoosingAction(Result, ExecuteParameters) Export
	
	If Result = "TakeFromStorageAndOpen" Then
		
		// IN working directory of the folder the setting for confirmation at deletion is not used.
		DeleteFileWithoutConfirmation(ExecuteParameters.FullFileName);
		
		GetFromServerAndRegisterInFilesLocalCache(
			ExecuteParameters.ResultHandler,
			ExecuteParameters.FileData,
			ExecuteParameters.FullFileName,
			ExecuteParameters.FileData.ModificationDateUniversal,
			ExecuteParameters.ForRead,
			ExecuteParameters.FormID,
			ExecuteParameters.AdditionalParameters);
		
	ElsIf Result = "OpenExisting" Then
		
		If ExecuteParameters.FileData.InWorkingDirectoryForRead <> ExecuteParameters.ForRead Then
			InOwnerWorkingDirectory = ExecuteParameters.FileData.OwnerWorkingDirectory <> "";
			
			ReregisterInWorkingDirectory(
				ExecuteParameters.FileData.Version,
				ExecuteParameters.FullFileName,
				ExecuteParameters.ForRead,
				InOwnerWorkingDirectory);
		EndIf;
		
		ExecuteParameters.FileReceived = True;
		ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
		
	Else // Result = "Cancel".
		ExecuteParameters.FullFileName = "";
		ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Check maximum length of working directory with replacement and transfer of files.

// Checks maximum length if necessary - changes working directory and migrates files.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FileData  - structure with file data.
//  FullFileName - String - full attachment file name.
//  NormalFileName - String - attachment file name (without path).
//
// Returns:
//   Boolean - Whether the operation was completed successfully.
//       * True if the length of full attachment file name does not exceed 260.
//
Procedure CheckFullPathMaxLengthInWorkingDirectory(ResultHandler,
		FileData, FullFileName, NormalFileName)
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("FileData", FileData);
	ExecuteParameters.Insert("FullFileName", FullFileName);
	ExecuteParameters.Insert("NormalFileName", NormalFileName);
	
	CheckFullPathMaxLengthInWorkingDirectoryStart(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure CheckFullPathMaxLengthInWorkingDirectoryStart(ExecuteParameters)
	
	#If WebClient Then
		ReturnResult(ExecuteParameters.ResultHandler, True);
		Return;
	#EndIf
	
	ExecuteParameters.Insert("DirectoryNameFormerValue", ExecuteParameters.FileData.OwnerWorkingDirectory);
	ExecuteParameters.Insert("FullPathMaxLength", 260);
	If Lower(ExecuteParameters.FileData.Extension) = "xls" Or Lower(ExecuteParameters.FileData.Extension) = "xlsx" Then
		// Excel Length of attachment file name together with path should not exceed 218 characters.
		ExecuteParameters.FullPathMaxLength = 218;
	EndIf;
	
	FileNameMaxLength = ExecuteParameters.FullPathMaxLength - 5; // 5 - minimum for "C:\1\"
	
	If StrLen(ExecuteParameters.FullFileName) <= ExecuteParameters.FullPathMaxLength Then
		ReturnResult(ExecuteParameters.ResultHandler, True);
		Return;
	EndIf;
	
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Length of full path to file (working directory plus attachment file name) exceeds
		|%1 characters ""%2"".';ru='Длина полного пути к файлу (рабочий каталог плюс имя файла)
		|превышает %1 символов ""%2"".'"),
		ExecuteParameters.FullPathMaxLength,
		ExecuteParameters.FullFileName);
	
	UserDirectoryPath = DirectoryDataUser();
	FileNameMaxLength = ExecuteParameters.FullPathMaxLength - StrLen(UserDirectoryPath);
	
	// If  file  name plus 5 exceeds 260 - write "Change attachment file name to a shorter one. OK" and exit.
	If StrLen(ExecuteParameters.NormalFileName) > FileNameMaxLength Then
		MessageText = MessageText + Chars.CR + Chars.CR
			+ NStr("en='Replace the file name with a shorter one.';ru='Измените имя файла на более короткое.'");
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, MessageText, False);
		Return;
	EndIf;
	
	// If the structure of folders (path to working directory of current folder) exceeds 260-5 (1.txt), write "Change the
	// names of folders or move current folder into another folder".
	If StrLen(ExecuteParameters.FileData.OwnerWorkingDirectory) > ExecuteParameters.FullPathMaxLength - 5 Then
		MessageText = MessageText + Chars.CR + Chars.CR
			+ NStr("en='Change folder names or move this folder to another one.';ru='Измените имена папок или перенесите текущую папку в другую папку.'");
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, MessageText, False);
		Return;
	EndIf;
	
	CheckFullPathMaxLengthInWorkingDirectoryOfferToSelectDirectory(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure CheckFullPathMaxLengthInWorkingDirectoryOfferToSelectDirectory(ExecuteParameters)
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Length of full path to file (working directory plus attachment file name) exceeds
		|%1 characters ""%2"".
		|
		|Do you want to
		|select another default working directory? (The contents of working directory will be transferred to selected directory).';ru='Длина полного пути к файлу (рабочий каталог плюс имя файла) превышает %1 символов
		|""%2"".
		|
		|Выбрать другой основной рабочий каталог?
		|(Содержимое рабочего каталога будет перенесено в выбранный каталог).'"),
		ExecuteParameters.FullPathMaxLength, ExecuteParameters.FullFileName);
	Handler = New NotifyDescription("CheckFullPathMaxLengthInWorkingDirectoryStartDirectorySelection", ThisObject, ExecuteParameters);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

// Procedure continued (see above).
Procedure CheckFullPathMaxLengthInWorkingDirectoryStartDirectorySelection(Response, ExecuteParameters) Export
	
	If Response = DialogReturnCode.No Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	// Choose another path to the working directory.
	Title = NStr("en='Select another working directory';ru='Выберите другой рабочий каталог'");
	DirectorySelected = ChoosePathToWorkingDirectory(ExecuteParameters.FileData.OwnerWorkingDirectory, Title, True);
	If Not DirectorySelected Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	ExecuteParameters.FullFileName = ExecuteParameters.FileData.OwnerWorkingDirectory + ExecuteParameters.NormalFileName;
	
	// within 260 characters
	If StrLen(ExecuteParameters.FullFileName) <= ExecuteParameters.FullPathMaxLength Then
		Handler = New NotifyDescription("CheckFullPathMaxLengthInWorkingDirectoryAfterTransferringWorkingDirectoryContent", ThisObject, ExecuteParameters);
		TransferWorkingDirectoryContents(Handler, ExecuteParameters.DirectoryNameFormerValue, ExecuteParameters.FileData.OwnerWorkingDirectory);
	Else
		CheckFullPathMaxLengthInWorkingDirectoryOfferToSelectDirectory(ExecuteParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure CheckFullPathMaxLengthInWorkingDirectoryAfterTransferringWorkingDirectoryContent(ContentMoved, ExecuteParameters) Export
	
	If ContentMoved Then
		// Information register FilesInWorkingDirectory - now there is a full path to the file -
		// it shall be changed - select general part and replace. -just SQL query -
		// for current user.
		FileOperationsServiceServerCall.SaveFolderWorkingDirectoryAndChangePathesInRegister(
			ExecuteParameters.FileData.Owner,
			ExecuteParameters.FileData.OwnerWorkingDirectory,
			ExecuteParameters.DirectoryNameFormerValue);
	EndIf;
	ReturnResult(ExecuteParameters.ResultHandler, ContentMoved);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Copying the contents from one directory to another.

// Copies all files in specified directory to another directory.
//
// Parameters:
//   ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//   SourceDirectory  - String - former name of the directory.
//   ReceiverDirectory  - String - new directory name.
//
// Returns:
//   Structure - Result of copying.
//       * ErrorOccurred           - Boolean - True when all files are copied.
//       * InformationAboutError       - ErrorInfo - Error information.
//       * FailingFileFullName   - String - Full name of the file during copying of which an error occurred.
//       * CopiedFilesAndFolders - Array - Full names of receiver files and folders.
//       * OriginalFilesAndFolders  - Array - Full names of source files and folders.
//
Procedure DoCopyDirectoryContent(ResultHandler, Val SourceDirectory, Val ReceiverDirectory)
	
	Result = New Structure;
	Result.Insert("ErrorOccurred",           False);
	Result.Insert("FailingFileFullName",   "");
	Result.Insert("ErrorInfo",       "");
	Result.Insert("CopiedFilesAndFolders", New Array);
	Result.Insert("OriginalFilesAndFolders",  New Array);
	
	CopyDirectoryContent(Result, SourceDirectory, ReceiverDirectory);
	
	If Result.ErrorOccurred Then
		
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to copy
		|the ""%1"" file.
		|It may be locked by another application.
		|
		|Repeat operation?';ru='Не удалось
		|скопировать файл ""%1"".
		|Возможно он занят другим приложением.
		|
		|Повторить операцию?'"),
			Result.FailingFileFullName);
		
		ExecuteParameters = New Structure;
		ExecuteParameters.Insert("ResultHandler", ResultHandler);
		ExecuteParameters.Insert("SourceDirectory", SourceDirectory);
		ExecuteParameters.Insert("ReceiverDirectory", ReceiverDirectory);
		ExecuteParameters.Insert("Result", Result);
		
		Handler = New NotifyDescription(
			"DoCopyDirectoryContentAfterAnsweringQuestion", ThisObject, ExecuteParameters);
		
		ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo);
	Else
		ReturnResult(ResultHandler, Result);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure DoCopyDirectoryContentAfterAnsweringQuestion(Response, ExecuteParameters)
	
	If Response = DialogReturnCode.No Then
		ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters.Result);
	Else
		DoCopyDirectoryContent(
			ExecuteParameters.ResultHandler,
			ExecuteParameters.SourceDirectory,
			ExecuteParameters.ReceiverDirectory);
	EndIf;
	
EndProcedure

// Copies all files in specified directory to another directory.
//
// Parameters:
//   Result - Structure - Result of copying. See DoCopyDirectoryContent(), return value.
//   SourceDirectory  - String - former name of the directory.
//   ReceiverDirectory  - String - new directory name.
//
Procedure CopyDirectoryContent(Result, SourceDirectory, ReceiverDirectory)
	
	ReceiverDirectory = CommonUseClientServer.AddFinalPathSeparator(ReceiverDirectory);
	SourceDirectory = CommonUseClientServer.AddFinalPathSeparator(SourceDirectory);
	
	CreateDirectory(ReceiverDirectory);
	
	Result.CopiedFilesAndFolders.Add(ReceiverDirectory);
	Result.OriginalFilesAndFolders.Add(SourceDirectory);
	
	SourceFiles = FindFiles(SourceDirectory, "*");
	
	For Each SourceFile IN SourceFiles Do
		
		SourceFileFullName = SourceFile.FullName;
		SourceFileName       = SourceFile.Name;
		ReceiverFileFullName = ReceiverDirectory + SourceFileName;
		
		If SourceFile.IsDirectory() Then
			
			CopyDirectoryContent(Result, SourceFileFullName, ReceiverFileFullName);
			If Result.ErrorOccurred Then
				Return;
			EndIf;
			
		Else
			
			Result.OriginalFilesAndFolders.Add(SourceFileFullName);
			
			ReceiverFile = New File(ReceiverFileFullName);
			If ReceiverFile.Exist() Then
				// It is necessary for reverse copying - in this case the files can already exist.
				Result.CopiedFilesAndFolders.Add(ReceiverFileFullName);
			Else
				Try
					FileCopy(SourceFileFullName, ReceiverFileFullName);
				Except
					Result.ErrorOccurred         = True;
					Result.ErrorInfo     = ErrorInfo();
					Result.FailingFileFullName = SourceFileFullName;
					Return;
				EndTry;
				Result.CopiedFilesAndFolders.Add(ReceiverFileFullName);
			EndIf;
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Transfer of working directory content to a new one.

// Transfers all files in working directory to another directory (including those taken for editing).
//
// Parameters:
//   ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//   SourceDirectory - String - former name of the directory.
//   ReceiverDirectory - String - New directory name.
//
// Returns:
//   Boolean - Whether the operation was completed successfully.
//
Procedure TransferWorkingDirectoryContents(ResultHandler, SourceDirectory, ReceiverDirectory) Export
	
	// New path is a subset of the old one. It is prohibited as can lead to the loop.
	If Find(Lower(ReceiverDirectory), Lower(SourceDirectory)) <> 0 Then
		WarningText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Selected working
		|directory
		|""%1"" is included in
		|old working directory ""%2"".';ru='Выбранный
		|рабочий
		|каталог ""%1""
		|входит в старый рабочий каталог ""%2"".'"),
			ReceiverDirectory,
			SourceDirectory);
		ReturnResultAfterShowWarning(ResultHandler, WarningText, False);
		Return;
	EndIf;
	
	// Copying files from old directory to a new one.
	HandlerParameters = New Structure;
	HandlerParameters.Insert("ResultHandler", ResultHandler);
	HandlerParameters.Insert("SourceDirectory", SourceDirectory);
	HandlerParameters.Insert("ReceiverDirectory", ReceiverDirectory);
	Handler = New NotifyDescription("TransferWorkingDirectoryContentAfterCopyingToNewDirectory", ThisObject, HandlerParameters);
	
	DoCopyDirectoryContent(Handler, SourceDirectory, ReceiverDirectory);
	
EndProcedure

// Procedure continued (see above).
Procedure TransferWorkingDirectoryContentAfterCopyingToNewDirectory(Result, ExecuteParameters) Export
	
	If Result.ErrorOccurred Then
		// An error occurred when copying, then the user cancelled the operation.
		
		Handler = New NotifyDescription(
			"TransferWorkingDirectoryContentsAfterCancellingAndClearingReceiver",
			ThisObject,
			ExecuteParameters);
		
		DeleteDirectoryContent(Handler, Result.CopiedFilesAndFolders); // Clearing receiver folder.
	Else
		// Copying succeeded. Clearing old directory.
		Handler = New NotifyDescription(
			"TransferWorkingDirectoryContentAfterSuccessAndSourceClearing",
			ThisObject,
			ExecuteParameters);
		
		DeleteDirectoryContent(Handler, Result.OriginalFilesAndFolders);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure TransferWorkingDirectoryContentsAfterCancellingAndClearingReceiver(ReceiverDirectoryCleared, ExecuteParameters) Export
	
	ReturnResult(ExecuteParameters.ResultHandler, False);
	
EndProcedure

// Procedure continued (see above).
Procedure TransferWorkingDirectoryContentAfterSuccessAndSourceClearing(SourceDirectoryCleared, ExecuteParameters) Export
	
	If SourceDirectoryCleared Then
		// Old directory is cleared. All steps of the operation were successfully completed.
		ReturnResult(ExecuteParameters.ResultHandler, True);
	Else
		// Old directory is not cleared. Rollback of the whole operation.
		Handler = New NotifyDescription("TransferWorkingDirectoryContentAfterSuccessAndClearingCancel", ThisObject, ExecuteParameters);
		DoCopyDirectoryContent(Handler, ExecuteParameters.ReceiverDirectory, ExecuteParameters.SourceDirectory);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure TransferWorkingDirectoryContentAfterSuccessAndClearingCancel(Result, ExecuteParameters) Export
	
	// Operation rollback.
	If Result.ErrorOccurred Then
		// It is necessary to warn that even during operation rollback an error occurred.
		WarningText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to copy back the
		|content
		|of directory
		|""%1"" to directory ""%2"".';ru='Не удалось скопировать
		|обратно
		|содержимое
		|каталога ""%1"" в каталог ""%2"".'"),
			ExecuteParameters.ReceiverDirectory,
			ExecuteParameters.SourceDirectory);
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, WarningText, False);
	Else
		// Operation rollback was successful.
		ReturnResult(ExecuteParameters.ResultHandler, False);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Deleting the array of paths of transferred folders and files.

// Deletes all files and folders from passed array.
//   Bypass from end.
//
// Parameters:
//   ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//   CopiedFilesAndFolders - Array - (String) Array of files and folders paths.
//
// Returns:
//   Boolean - Whether the operation was completed successfully.
//
Procedure DeleteDirectoryContent(ResultHandler, CopiedFilesAndFolders)
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("CopiedFilesAndFolders", CopiedFilesAndFolders);
	ExecuteParameters.Insert("UBound", CopiedFilesAndFolders.Count() - 1);
	ExecuteParameters.Insert("IndexOf", 0);
	
	DeleteDirectoryContentStart(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure DeleteDirectoryContentStart(ExecuteParameters)
	
	For IndexOf = ExecuteParameters.IndexOf To ExecuteParameters.UBound Do
		Path = ExecuteParameters.CopiedFilesAndFolders[ExecuteParameters.UBound - IndexOf];
		File = New File(Path);
		If Not File.Exist() Then
			Continue; // For example, temporary file Word ~aaa.doc could have been deleted when closing Word.
		EndIf;
		
		Try
			If File.IsFile() AND File.GetReadOnly() Then
				File.SetReadOnly(False);
			EndIf;
			DeleteFiles(Path);
			FileRemoved = True;
		Except
			FileRemoved = False;
		EndTry;
		
		If Not FileRemoved Then
			QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Failed to delete
		|the ""%1"" file.
		|It may be locked by another application.
		|
		|Repeat operation?';ru='Не удалось
		|удалить файл ""%1"".
		|Возможно он занят другим приложением.
		|
		|Повторить операцию?'"),
				Path);
			ExecuteParameters.IndexOf = IndexOf;
			Handler = New NotifyDescription("DeleteDirectoryContentAfterAnswerToQuestionRepeat", ThisObject, ExecuteParameters);
			ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo);
			Return;
		EndIf;
	EndDo;
	
	ReturnResult(ExecuteParameters.ResultHandler, True);
	
EndProcedure

// Procedure continued (see above).
Procedure DeleteDirectoryContentAfterAnswerToQuestionRepeat(Response, ExecuteParameters) Export
	
	If Response = DialogReturnCode.No Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
	Else
		DeleteDirectoryContentStart(ExecuteParameters);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Files import with size check.

// Import - with support operations of limit size check type and subsequent deletion of
//          files and display of errors when you import only one folder - returns the reference to it.
//
// Parameters:
//  ExecuteParameters - Structure - see FileImportParameters.
//
// Returns:
//   Undefined - If import failed.
//   Structure - If import is executed.
//       * FolderForAddingCurrent - CatalogRef.FileFolders - Folder for adding.
//
Procedure ImportFilesExecute(Val ExecuteParameters) Export
	
	OfficeParameters = CommonUseClientServer.CopyStructure(ExecuteParameters);
	Handler = New NotifyDescription("FilesImportAfterSizesCheck", ThisObject, OfficeParameters);
	CheckFilesLimitSize(Handler, OfficeParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure FilesImportAfterSizesCheck(Result, ExecuteParameters) Export
	
	Status();
	
	If Result.Success = False Then
		ReturnResult(ExecuteParameters.ResultHandler, Undefined);
		Return;
	EndIf;
	
	ExecuteParameters.Insert("QuantitySummary", Result.QuantitySummary);
	If ExecuteParameters.QuantitySummary = 0 Then
		If ExecuteParameters.ImportMode Then
			ReturnResult(ExecuteParameters.ResultHandler, Undefined);
		Else
			ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, NStr("en='There are no files to add';ru='Нет файлов для добавления'"), Undefined);
		EndIf;
		Return;
	EndIf;
	
	ExecuteParameters.Insert("FirstFolderWithSameName", Undefined);
	ExecuteParameters.Insert("FolderForAddCurrent", Undefined);
	ExecuteParameters.Insert("SelectedFilesInBorder", ExecuteParameters.SelectedFiles.Count()-1);
	ExecuteParameters.Insert("SelectedFilesIndex", -1);
	ExecuteParameters.Insert("ProgressBar", 0);
	ExecuteParameters.Insert("Counter", 0);
	ExecuteParameters.Insert("FilesArray", New Array);
	ExecuteParameters.Insert("FilenamesWithErrorsArray", New Array);
	ExecuteParameters.Insert("AllFilesStructuresArray", New Array);
	ExecuteParameters.Insert("AllFoldersArray", New Array);
	ExecuteParameters.Insert("FileArrayThisDirectory", Undefined);
	ExecuteParameters.Insert("FolderName", Undefined);
	ExecuteParameters.Insert("Path", Undefined);
	ExecuteParameters.Insert("FolderAlreadyFound", Undefined);
	RegisterHandlerDescription(ExecuteParameters, ThisObject, "FilesImportCycleContinueImportAfterQuestionsInRecursion");
	FilesImportCycle(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure FilesImportCycle(ExecuteParameters)
	
	ExecuteParameters.SelectedFilesIndex = ExecuteParameters.SelectedFilesIndex + 1;
	For IndexOf = ExecuteParameters.SelectedFilesIndex To ExecuteParameters.SelectedFilesInBorder Do
		ExecuteParameters.SelectedFilesIndex = IndexOf;
		FileName = ExecuteParameters.SelectedFiles[IndexOf];
		
		SelectedFile = New File(FileName.Value);
		
		SelectedDirectory = False;
		If SelectedFile.Exist() Then
			SelectedDirectory = SelectedFile.IsDirectory();
		EndIf;
		
		If SelectedDirectory Then
			ExecuteParameters.Path = FileName.Value;
			ExecuteParameters.FileArrayThisDirectory = FileFunctionsServiceClientServer.FindFilesPseudo(ExecuteParameters.PseudoFileSystem, ExecuteParameters.Path);
			
			ExecuteParameters.FolderName = SelectedFile.Name;
			
			ExecuteParameters.FolderAlreadyFound = False;
			
			If FileOperationsServiceServerCall.IsFolderWithSuchName(ExecuteParameters.FolderName, ExecuteParameters.Owner, ExecuteParameters.FirstFolderWithSameName) Then
				If ExecuteParameters.ImportMode Then
					ExecuteParameters.FolderAlreadyFound = True;   
					ExecuteParameters.FolderForAddCurrent = ExecuteParameters.FirstFolderWithSameName;
				Else
					QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='Folder ""% 1"" already exists.
		|
		|Continue folder import?';ru='Папка ""%1"" уже существует.
		|
		|Продолжить импорт папки?'"),
						ExecuteParameters.FolderName);
					Handler = New NotifyDescription("FilesImportCycleAfterResponseToQuestionContinue", ThisObject, ExecuteParameters);
					ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo);
					Return;
				EndIf;
			EndIf;
			FilesImportCycleContinueImport(ExecuteParameters);
			If ExecuteParameters.AsynchronousDialog.Open = True Then
				Return;
			EndIf;
		Else
			ExecuteParameters.FilesArray.Add(SelectedFile);
		EndIf;
	EndDo;
	
	If ExecuteParameters.FilesArray.Count() <> 0 Then
		// Actual import 
		RegisterHandlerDescription(ExecuteParameters, ThisObject, "FilesImportAfterCycleAfterQuestionsInRecursion");
		FilesImportRecursively(ExecuteParameters.Owner, ExecuteParameters.FilesArray, ExecuteParameters);
		
		If ExecuteParameters.AsynchronousDialog.Open = True Then
			Return;
		EndIf;
	EndIf;
	
	FilesImportAfterCycleContinued(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure FilesImportCycleAfterResponseToQuestionContinue(Response, ExecuteParameters) Export
	
	If Response <> DialogReturnCode.No Then
		FilesImportCycleContinueImport(ExecuteParameters);
	EndIf;
	
	FilesImportCycle(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure FilesImportCycleContinueImport(ExecuteParameters)
	
	If Not ExecuteParameters.FolderAlreadyFound Then
		ExecuteParameters.FolderForAddCurrent = FileOperationsServiceServerCall.CatalogsFoldersCreateItem(
			ExecuteParameters.FolderName, ExecuteParameters.Owner);
	EndIf;
	
	// Actual import
	FilesImportRecursively(ExecuteParameters.FolderForAddCurrent, ExecuteParameters.FileArrayThisDirectory, ExecuteParameters);
	If ExecuteParameters.AsynchronousDialog.Open = True Then
		Return;
	EndIf;
	
	ExecuteParameters.AllFoldersArray.Add(ExecuteParameters.Path);
	
EndProcedure

// Procedure continued (see above).
Procedure FilesImportCycleContinueImportAfterQuestionsInRecursion(Result, ExecuteParameters) Export
	
	ExecuteParameters.AsynchronousDialog.Open = False;
	ExecuteParameters.AllFoldersArray.Add(ExecuteParameters.Path);
	FilesImportCycle(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure FilesImportAfterCycleAfterQuestionsInRecursion(Result, ExecuteParameters) Export
	
	FilesImportAfterCycleContinued(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure FilesImportAfterCycleContinued(ExecuteParameters)
	
	If ExecuteParameters.AllFilesStructuresArray.Count() > 1 Then
		
		StatusText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='File are imported. Imported files: %1';ru='Импорт файлов завершен. Загружено файлов: %1'"), String(ExecuteParameters.AllFilesStructuresArray.Count()) );
			
		If ExecuteParameters.ImportMode Then
			StatusText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Files have been imported. Files imported: %1';ru='Загрузка файлов завершена. Загружено файлов: %1'"), String(ExecuteParameters.AllFilesStructuresArray.Count()) );
		EndIf;
		
		Status(StatusText);
	Else
		Status();
	EndIf;
	
	If ExecuteParameters.DeleteFilesAfterAdd = True Then
		FileFunctionsServiceClientServer.DeleteFilesAfterAdd1(
			ExecuteParameters.AllFilesStructuresArray, ExecuteParameters.AllFoldersArray, ExecuteParameters.ImportMode);
	EndIf;
	
	If ExecuteParameters.AllFilesStructuresArray.Count() = 1 Then
		item0 = ExecuteParameters.AllFilesStructuresArray[0];
		Ref = GetURL(item0.File);
		ShowUserNotification(
			NStr("en='Change';ru='Изменение:'"),
			Ref,
			item0.File,
			PictureLib.Information32);
	EndIf;
	
	// Output error messages
	If ExecuteParameters.FilenamesWithErrorsArray.Count() <> 0 Then
		Parameters = New Structure;
		Parameters.Insert("FilenamesWithErrorsArray", ExecuteParameters.FilenamesWithErrorsArray);
		If ExecuteParameters.ImportMode Then
			Parameters.Insert("Title", NStr("en='Report on file import';ru='Отчет о загрузке файлов'"));
		EndIf;
		
		OpenForm("Catalog.Files.Form.ReportForm", Parameters);
	EndIf;
	
	If ExecuteParameters.SelectedFiles.Count() <> 1 Then
		ExecuteParameters.FolderForAddCurrent = Undefined;
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Saving File on disk

// Save to File disk
// 
// Parameters:
//   ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//   FileData  - structure with file data.
//   UUID - form unique ID.
//
// Returns:
//   String - selected full path of the file.
//
Procedure SaveAs(ResultHandler, FileData, UUID) Export
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("FileData", FileData);
	ExecuteParameters.Insert("UUID", UUID);
	
	If FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		SaveAsWithExtension(ExecuteParameters);
	Else
		SaveAsWithoutExtension(ExecuteParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure SaveAsWithExtension(ExecuteParameters) Export
	
	// Check - if the file is already in the cache and it is newer than in the base - will give the dialog with the choice.
	ExecuteParameters.Insert("PathToFileInCache", "");
	If ExecuteParameters.FileData.CurrentUserIsEditing Then
		InWorkingDirectoryForRead = True;
		InOwnerWorkingDirectory = False;
		ExecuteParameters.Insert("FullFileName", "");
		FileInWorkingDirectory = FileIsInFilesLocalCache(ExecuteParameters.FileData, ExecuteParameters.FileData.Version, ExecuteParameters.FullFileName, InWorkingDirectoryForRead, InOwnerWorkingDirectory);
		
		If FileInWorkingDirectory = True Then
			
			DateFileInBase = ExecuteParameters.FileData.ModificationDateUniversal;
			
			VersionFile = New File(ExecuteParameters.FullFileName);
			DateFileOnHardDrive = VersionFile.GetModificationUniversalTime();
			
			If DateFileOnHardDrive > DateFileInBase Then // There is a newer file in working directory (modified by user from the outside).
				FormOpenParameters = New Structure;
				FormOpenParameters.Insert("File", ExecuteParameters.FullFileName);
				
				Message = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Date of the
		|""%1"" file modification in working directory is later (newer) than in file storage.
		|Probably, the file was changed.';ru='Дата
		|изменения файла ""%1"" в рабочем каталоге более поздняя (новее), чем в хранилище файлов.
		|Возможно, файл был изменен.'"),
					String(ExecuteParameters.FileData.Ref));
				
				FormOpenParameters.Insert("Message", Message);
				
				Handler = New NotifyDescription("SaveAsWithExtensionAfterAnsweringQuestionDateLater", ThisObject, ExecuteParameters);
				OpenForm("Catalog.Files.Form.FileCreationModeForSaveAs", FormOpenParameters, , , , , Handler, FormWindowOpeningMode.LockWholeInterface);
				Return;
			EndIf;
		EndIf;
	EndIf;
	
	SaveAsWithExtensionContinued(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure SaveAsWithExtensionAfterAnsweringQuestionDateLater(Response, ExecuteParameters) Export
	
	If Response = DialogReturnCode.Cancel Or Response = Undefined Then
		ReturnResult(ExecuteParameters.ResultHandler, "");
		Return;
	EndIf;
	
	If Response = 1 Then // On the basis of file on local computer.
		ExecuteParameters.PathToFileInCache = ExecuteParameters.FullFileName;
	EndIf;
	
	SaveAsWithExtensionContinued(ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure SaveAsWithExtensionContinued(ExecuteParameters)
	
	ExecuteParameters.Insert("ChoicePath", ExecuteParameters.FileData.FolderForSaveAs);
	If ExecuteParameters.ChoicePath = Undefined Or ExecuteParameters.ChoicePath = "" Then
		#If Not WebClient Then
			If StandardSubsystemsClientReUse.ClientWorkParameters().ThisIsBasicConfigurationVersion Then
				CommonUseClientServer.MessageToUser(
					NStr("en='This command is not supported in base version.';ru='Данная команда не поддерживается в базовой версии.'"));
				ReturnResult(ExecuteParameters.ResultHandler, "");
				Return;
			EndIf;
		#EndIf
		
		ExecuteParameters.ChoicePath = FileFunctionsServiceClient.MyDocumentsDir();
	EndIf;
	
	ExecuteParameters.Insert("SaveDecrypted", False);
	ExecuteParameters.Insert("ExtensionForEncryptedFiles", "");
	
	If ExecuteParameters.FileData.Encrypted Then
		Handler = New NotifyDescription("SaveAsWithExtensionAfterSelectingSaveMode",
			ThisObject, ExecuteParameters);
		
		OpenForm("Catalog.Files.Form.EncryptedFileSaveSelection", , , , , ,
			Handler, FormWindowOpeningMode.LockWholeInterface);
	Else
		SaveAsWithExtensionAfterSelectingSaveMode(-1, ExecuteParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure SaveAsWithExtensionAfterSelectingSaveMode(Result, ExecuteParameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		ExecuteParameters.ExtensionForEncryptedFiles = Result.ExtensionForEncryptedFiles;
		
		If Result.SaveDecrypted = 1 Then
			ExecuteParameters.SaveDecrypted = True;
		Else
			ExecuteParameters.SaveDecrypted = False;
		EndIf;
		
	ElsIf Result <> -1 Then
		ReturnResult(ExecuteParameters.ResultHandler, "");
		Return;
	EndIf;
	
	If Not ExecuteParameters.SaveDecrypted Then
		SaveAsWithExtensionAfterDecryption(-1, ExecuteParameters);
		Return;
	EndIf;
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ReturnStructure = FileOperationsServiceServerCall.FileDataAndBinaryData(ExecuteParameters.FileData.Version,, 
		ExecuteParameters.UUID);
	
	DataDescription = New Structure;
	DataDescription.Insert("Operation",              NStr("en='File decryption';ru='Расшифровка файла'"));
	DataDescription.Insert("DataTitle",       NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("Data",                ReturnStructure.BinaryData);
	DataDescription.Insert("Presentation",         ExecuteParameters.FileData.Ref);
	DataDescription.Insert("EncryptionCertificates", ExecuteParameters.FileData.Ref);
	DataDescription.Insert("NotifyAboutCompletion",   False);
	
	ContinuationHandler = New NotifyDescription("SaveAsWithExtensionAfterDecryption", ThisObject, ExecuteParameters);
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.Decrypt(DataDescription, , ContinuationHandler);
	
EndProcedure

// Procedure continued (see above).
Procedure SaveAsWithExtensionAfterDecryption(DataDescription, ExecuteParameters) Export
	
	If DataDescription <> -1 Then
		If Not DataDescription.Success Then
			ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
			Return;
		EndIf;
	
		If TypeOf(DataDescription.DecryptedData) = Type("BinaryData") Then
			FileURL = PutToTempStorage(DataDescription.DecryptedData,
				ExecuteParameters.UUID);
		Else
			FileURL = DataDescription.DecryptedData;
		EndIf;
	Else
		FileURL = ExecuteParameters.FileData.CurrentVersionURL;
		
		If ExecuteParameters.FileData.CurrentVersion <> ExecuteParameters.FileData.Version Then
			FileURL = FileOperationsServiceServerCall.GetURLForOpening(
				ExecuteParameters.FileData.Version, ExecuteParameters.UUID);
		EndIf;
	EndIf;
	
	NameWithExtension = CommonUseClientServer.GetNameWithExtention(
		ExecuteParameters.FileData.FullDescrOfVersion, ExecuteParameters.FileData.Extension);
	
	Extension = ExecuteParameters.FileData.Extension;
	
	If ExecuteParameters.FileData.Encrypted
	   AND Not ExecuteParameters.SaveDecrypted Then
		
		If Not IsBlankString(ExecuteParameters.ExtensionForEncryptedFiles) Then
			NameWithExtension = NameWithExtension + "." + ExecuteParameters.ExtensionForEncryptedFiles;
			Extension = ExecuteParameters.ExtensionForEncryptedFiles;
		EndIf;
	EndIf;
	
	// Select path to file on disk.
	FileChoice = New FileDialog(FileDialogMode.Save);
	FileChoice.Multiselect = False;
	FileChoice.FullFileName = NameWithExtension;
	FileChoice.Extension = Extension;
	Filter = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='All files (*.%1)|*.%1';ru='Все файлы (*.%1)|*.%1'"), Extension, Extension);
	FileChoice.Filter = Filter;
	FileChoice.Directory = ExecuteParameters.ChoicePath;
	
	If Not FileChoice.Choose() Then
		ReturnResult(ExecuteParameters.ResultHandler, New Structure);
		Return;
	EndIf;
	
	FullFileName = FileChoice.FullFileName;
	
	File = New File(FullFileName);
	
	FileName = CommonUseClientServer.GetNameWithExtention(
		ExecuteParameters.FileData.FullDescrOfVersion, ExecuteParameters.FileData.Extension);
	
	SizeInMB = ExecuteParameters.FileData.Size / (1024 * 1024);
	
	ExplanationText =
	StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='The ""%1"" file saving in progress (%2 Mb)...
		|Please, wait.';ru='Выполняется сохранение файла ""%1"" (%2 Мб)...
		|Пожалуйста, подождите.'"),
		FileName, 
		FileFunctionsServiceClientServer.GetStringWithFileSize(SizeInMB));
		
	Status(ExplanationText);
	
	If File.Exist() Then
		If ExecuteParameters.PathToFileInCache <> FullFileName Then
			File.SetReadOnly(False);
			DeleteFiles(FileChoice.FullFileName);
		EndIf;
	EndIf;
	
	If ExecuteParameters.PathToFileInCache <> "" Then
		If ExecuteParameters.PathToFileInCache <> FullFileName Then
			FileCopy(ExecuteParameters.PathToFileInCache, FileChoice.FullFileName);
		EndIf;
	Else
		FilesToTransfer = New Array;
		Definition = New TransferableFileDescription(FullFileName, FileURL);
		FilesToTransfer.Add(Definition);
		
		PathToFile = File.Path;
		PathToFile = CommonUseClientServer.AddFinalPathSeparator(PathToFile);
		
		// Save File from the database on disk.
		If GetFiles(FilesToTransfer,, PathToFile, False) Then
			
			// For variant with file storage on the disk (on the server) we remove File from the temporary storage after its reception.
			If IsTempStorageURL(FileURL) Then
				DeleteFromTempStorage(FileURL);
			EndIf;
			
			NewFile = New File(FullFileName);
			
			NewFile.SetModificationUniversalTime(
				ExecuteParameters.FileData.ModificationDateUniversal);
			
		EndIf;
	EndIf;
	
	Status(NStr("en='File successfully saved';ru='Файл успешно сохранен'"), , FullFileName);
	
	ChoicePathFormer = ExecuteParameters.ChoicePath;
	ExecuteParameters.ChoicePath = File.Path;
	If ChoicePathFormer <> ExecuteParameters.ChoicePath Then
		CommonUseServerCall.CommonSettingsStorageSave("ApplicationSettings", "FolderForSaveAs", ExecuteParameters.ChoicePath);
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, New Structure("FullFileName", FullFileName));
	
EndProcedure

// Procedure continued (see above).
Procedure SaveAsWithoutExtension(ExecuteParameters) Export
	
	ExecuteParameters.Insert("SaveDecrypted", False);
	ExecuteParameters.Insert("ExtensionForEncryptedFiles", "");
	
	If ExecuteParameters.FileData.Encrypted Then
		Handler = New NotifyDescription("SaveAsWithoutExtensionAfterSelectingSaveMode",
			ThisObject, ExecuteParameters);
		
		OpenForm("Catalog.Files.Form.EncryptedFileSaveSelection", , , , , ,
			Handler, FormWindowOpeningMode.LockWholeInterface);
	Else
		SaveAsWithoutExtensionAfterSelectingSaveMode(-1, ExecuteParameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure SaveAsWithoutExtensionAfterSelectingSaveMode(Result, ExecuteParameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		ExecuteParameters.ExtensionForEncryptedFiles = Result.ExtensionForEncryptedFiles;
		
		If Result.SaveDecrypted = 1 Then
			ExecuteParameters.SaveDecrypted = True;
		Else
			ExecuteParameters.SaveDecrypted = False;
		EndIf;
		
	ElsIf Result <> -1 Then
		ReturnResult(ExecuteParameters.ResultHandler, "");
		Return;
	EndIf;
	
	FillInTemporaryFormIdentifier(ExecuteParameters.UUID, ExecuteParameters);
	
	Handler = New NotifyDescription("SaveAsWithoutExtensionEnd", ThisObject, ExecuteParameters);
	OpenFileWithoutExtension(Handler, ExecuteParameters.FileData, ExecuteParameters.UUID,
		False, ExecuteParameters.SaveDecrypted, ExecuteParameters.ExtensionForEncryptedFiles);
	
EndProcedure

// Procedure continued (see above).
Procedure SaveAsWithoutExtensionEnd(Result, ExecuteParameters) Export
	
	ClearTemporaryFormIdentifier(ExecuteParameters);
	
	If Result <> True Then
		Return;
	EndIf;
	
	If Not ExecuteParameters.SaveDecrypted
	   AND ExecuteParameters.FileData.Encrypted
	   AND ValueIsFilled(ExecuteParameters.ExtensionForEncryptedFiles) Then
		
		Extension = ExecuteParameters.ExtensionForEncryptedFiles;
	Else
		Extension = ExecuteParameters.FileData.Extension;
	EndIf;
	
	FileName = CommonUseClientServer.GetNameWithExtention(
		ExecuteParameters.FileData.FullDescrOfVersion, Extension);
	
	ReturnResult(ExecuteParameters.ResultHandler, New Structure("FullFileName", FileName));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Displays the reminder before file placing if it is configured.

// Will show the reminder - if the setting is configured.
//
// Parameters:
//   ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//
Procedure ShowReminderBeforePutFile(ResultHandler)
	
	PersonalSettings = FileFunctionsServiceClientServer.PersonalFileOperationsSettings();
	If PersonalSettings.ShowFileEditTips = True Then
		If Not FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
			// Cache the form on client
			Form = FileOperationsServiceClientReUse.ReminderFormBeforePlacingFile();
			SetFormAlert(Form, ResultHandler);
			Form.Open();
			Return;
		EndIf;
	EndIf;
	ReturnResult(ResultHandler, Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Checks files size.

// Check Files Limit Size - returns False if there are files
//   that exceed limit size and user selected "Cancel" in the dialog of warning about the existence of such files.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  CheckParameters - Structure - with properties:
//    * SelectedFiles - Array - array of objects "File".
//    * Recursively - Boolean - Recursively bypass subdirectories.
//    * PseudoFileSystem - Map - emulation of file system - for string (directory) returns
//                                             the array of strings (subdirectories and files).
//    * ImportMode - Boolean - Import mode (from background job FilesImport).
//
// Returns:
//   Structure - Result:
//       * Success               - Boolean - Whether the operation was completed successfully.
//       * NumberTotal - Number  - Number of imported files.
//
Procedure CheckFilesLimitSize(ResultHandler, CheckParameters)
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("QuantitySummary", 0);
	ExecuteParameters.Insert("Success", False);
	
	ArrayTooLargeFiles = New Array;
	
	Path = "";
	
	FilesArray = New Array;
	
	For Each FileName IN CheckParameters.SelectedFiles Do
		
		Path = FileName.Value;
		SelectedFile = New File(Path);
		
		SelectedFile = New File(FileName.Value);
		SelectedDirectory = False;
		
		If SelectedFile.Exist() Then
			SelectedDirectory = SelectedFile.IsDirectory();
		EndIf;
		
		If SelectedDirectory Then
			Status(StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='There is a collection
		|of directory information ""%1"".
		|Please, wait.';ru='Идет
		|сбор информации о каталоге ""%1"".
		|Пожалуйста, подождите.'"),
				Path));
			
			FileArrayThisDirectory = FileFunctionsServiceClientServer.FindFilesPseudo(CheckParameters.PseudoFileSystem, Path);
			FindOversizedFiles(FileArrayThisDirectory, ArrayTooLargeFiles, CheckParameters.Recursively, 
				ExecuteParameters.QuantitySummary, CheckParameters.PseudoFileSystem);
		Else
			FilesArray.Add(SelectedFile);
		EndIf;
	EndDo;
	
	If FilesArray.Count() <> 0 Then
		FindOversizedFiles(FilesArray, ArrayTooLargeFiles, CheckParameters.Recursively, 
			ExecuteParameters.QuantitySummary, CheckParameters.PseudoFileSystem);
	EndIf;
	
	// At least one file was too large.
	If ArrayTooLargeFiles.Count() <> 0 Then 
		BigFiles = New ValueList;
		Parameters = New Structure;
		
		For Each File IN ArrayTooLargeFiles Do
			LargeFile = New File(File);
			FileSizeInMb = Int(LargeFile.Size() / (1024 * 1024));
			StringText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='%1 (%2 MB)';ru='%1 (%2 МБ)'"), String(File), String(FileSizeInMb));
			BigFiles.Add(StringText);
		EndDo;
		
		Parameters.Insert("BigFiles", BigFiles);
		Parameters.Insert("ImportMode", CheckParameters.ImportMode);
		Parameters.Insert("Title", NStr("en='File import warning';ru='Предупреждение при загрузке файлов'"));
		
		Handler = New NotifyDescription("CheckFilesLimitSizeAfterAnswerToQuestion", ThisObject, ExecuteParameters);
		OpenForm("Catalog.Files.Form.FileImportQuestion", Parameters, , , , , Handler, FormWindowOpeningMode.LockWholeInterface);
		Return;
	EndIf;
	
	ExecuteParameters.Success = True;
	ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure CheckFilesLimitSizeAfterAnswerToQuestion(Response, ExecuteParameters) Export
	
	ExecuteParameters.Success = (Response = DialogReturnCode.OK);
	ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Displays the information that the file was not changed.

// Will show the reminder - if the setting is configured.
//
// Parameters:
//   ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//
Procedure ShowInformationFileWasNotChanged(ResultHandler)
	
	PersonalSettings = FileFunctionsServiceClientServer.PersonalFileOperationsSettings();
	If PersonalSettings.ShowFileNotChangedMessage = True Then
		OpenForm("Catalog.Files.Form.InformationFileWasNotModified", , , , , , ResultHandler, FormWindowOpeningMode.LockWholeInterface);
	Else
		ReturnResult(ResultHandler, Undefined);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Imports an edited file into the application, removes the lock and sends a notification.

// Saves edited file in the IB and unlocks it.
//
// Parameters:
//   Parameters - Structure - see FileUpdateParameters.
//
Procedure EndEditingWithAlert(Parameters) Export
	
	If Parameters.ObjectRef = Undefined Then
		ReturnResult(Parameters.ResultHandler, Undefined);
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", Parameters.ResultHandler);
	ExecuteParameters.Insert("CommandParameter", Parameters.ObjectRef);
	Handler = New NotifyDescription("EndEditingWithAlertEnd", ThisObject, ExecuteParameters);
	
	HandlerParameters = FileUpdateParameters(Handler, Parameters.ObjectRef, Parameters.FormID);
	HandlerParameters.StoreVersions = Parameters.StoreVersions;
	HandlerParameters.CurrentUserIsEditing = Parameters.CurrentUserIsEditing;
	HandlerParameters.IsEditing = Parameters.IsEditing;
	HandlerParameters.CurrentVersionAuthor = Parameters.CurrentVersionAuthor;
	HandlerParameters.Encoding = Parameters.Encoding;
	EndEdit(HandlerParameters);

EndProcedure

// Procedure continued (see above).
Procedure EndEditingWithAlertEnd(Result, ExecuteParameters) Export
	
	If Result = True Then
		Notify("Record_File", New Structure("Event", "EditFinished"), ExecuteParameters.CommandParameter);
		NotifyChanged(ExecuteParameters.CommandParameter);
		Notify("Record_File", New Structure("Event", "FileDataChanged"), ExecuteParameters.CommandParameter);
		Notify("Record_File", New Structure("Event", "VersionSaved"), ExecuteParameters.CommandParameter);
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Captures the file, opens editing dialog and sends the notification.

// Locks the file for editing and opens it.
Procedure EditWithAlert(
	ResultHandler,
	ObjectRef,
	UUID = Undefined,
	OwnerWorkingDirectory = Undefined) Export
	
	If ObjectRef = Undefined Then
		ReturnResult(ResultHandler, Undefined);
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("ObjectRef", ObjectRef);
	Handler = New NotifyDescription("EditWithAlertEnd", ThisObject, ExecuteParameters);
	EditFileByRef(Handler, ObjectRef, UUID, OwnerWorkingDirectory);
	
EndProcedure

// Procedure continued (see above).
Procedure EditWithAlertEnd(FileEdited, ExecuteParameters) Export
	
	If FileEdited Then
		NotifyChanged(ExecuteParameters.ObjectRef);
		Notify("Record_File", New Structure("Event", "FileDataChanged"), ExecuteParameters.ObjectRef);
		Notify("Record_File", New Structure("Event", "FileEdited"), ExecuteParameters.ObjectRef);
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Captures a file or several files and sends a notification.

// Locks a file or several files.
//
// Parameters:
//   ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//   CommandParameter - either reference to file or array of references to files.
//   UUID
//
Procedure TakeWithAlarm(ResultHandler, CommandParameter, UUID = Undefined) Export
	
	If CommandParameter = Undefined Then
		ReturnResult(ResultHandler, Undefined);
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("CommandParameter", CommandParameter);
	If TypeOf(CommandParameter) = Type("Array") Then
		Handler = New NotifyDescription("LockWithAlertFilesArrayEnd", ThisObject, ExecuteParameters);
		LockFilesByRefs(Handler, CommandParameter);
	Else
		Handler = New NotifyDescription("TakeWithAlertOneFileEnd", ThisObject, ExecuteParameters);
		LockFileByRef(Handler, CommandParameter, UUID)
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure LockWithAlertFilesArrayEnd(Result, ExecuteParameters) Export
	
	NotifyChanged(Type("CatalogRef.Files"));
	For Each FileRef IN ExecuteParameters.CommandParameter Do
		Notify("Record_File", New Structure("Event", "FileDataChanged"), FileRef);
	EndDo;
	ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	
EndProcedure

// Procedure continued (see above).
Procedure TakeWithAlertOneFileEnd(Result, ExecuteParameters) Export
	
	If Result = True Then
		NotifyChanged(ExecuteParameters.CommandParameter);
		Notify("Record_File", New Structure("Event", "FileDataChanged"), ExecuteParameters.CommandParameter);
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Unlocks the file and sends an alert.

// Unlocks previously occupied file.
//
// Parameters:
//   Parameters - Structure - see FileUnlockingParameters.
//
Procedure ReleaseFileWithAlert(Parameters) Export
	
	If Parameters.ObjectRef = Undefined Then
		ReturnResult(Parameters.ResultHandler, Undefined);
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", Parameters.ResultHandler);
	ExecuteParameters.Insert("CommandParameter", Parameters.ObjectRef);
	If TypeOf(Parameters.ObjectRef) = Type("Array") Then
		Handler = New NotifyDescription("UnlockFileWithAlertFilesArrayEnd", ThisObject, ExecuteParameters);
		ReleaseFilesByRefs(Handler, Parameters.ObjectRef);
	Else
		Handler = New NotifyDescription("UnlockFileWithAlertOneFileEnd", ThisObject, ExecuteParameters);
		Parameters = FileReleaseParameters(Handler, Parameters.ObjectRef);
		Parameters.StoreVersions = Parameters.StoreVersions;
		Parameters.CurrentUserIsEditing = Parameters.CurrentUserIsEditing;
		Parameters.IsEditing = Parameters.IsEditing;
		Parameters.UUID = Parameters.UUID;
		ReleaseFile(Parameters);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure UnlockFileWithAlertFilesArrayEnd(Result, ExecuteParameters) Export
	
	NotifyChanged(Type("CatalogRef.Files"));
	For Each FileRef IN ExecuteParameters.CommandParameter Do
		Notify("Record_File", New Structure("Event", "FileDataChanged"), FileRef);
	EndDo;
	ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	
EndProcedure

// Procedure continued (see above).
Procedure UnlockFileWithAlertOneFileEnd(Result, ExecuteParameters) Export
	
	If Result = True Then
		NotifyChanged(ExecuteParameters.CommandParameter);
		Notify("Record_File", New Structure("Event", "FileDataChanged"), ExecuteParameters.CommandParameter);
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Opens the file and sends notification.

// Opens the file.
//
// Parameters:
//   ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//   FileData             - Structure with file data.
//   UUID - UUID - Forms.
//
Procedure OpenFileWithAlert(ResultHandler, FileData, UUID = Undefined) Export
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("FileData", FileData);
	ExecuteParameters.Insert("UUID", UUID);
	
	// If File without file, then open the card.
	If ExecuteParameters.FileData.Version.IsEmpty() Then
		Handler = New NotifyDescription("OpenFileWithAlertEnd", ThisObject, ExecuteParameters);
		ShowValue(Handler, ExecuteParameters.FileData.Ref);
		Return;
	EndIf;
	
	Handler = New NotifyDescription("OpenFileWithAlertAfterInstallingExtension", ThisObject, ExecuteParameters);
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(Handler);
	
EndProcedure

// Procedure continued (see above).
Procedure OpenFileWithAlertAfterInstallingExtension(ExtensionIsSet, ExecuteParameters) Export
	
	If FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		Handler = New NotifyDescription("OpenFileWithAlertWithExtensionAfterReceivingVersionInWorkingDirectory", ThisObject, ExecuteParameters);
		GetVersionFileToWorkingDirectory(
			Handler,
			ExecuteParameters.FileData,
			"",
			ExecuteParameters.UUID,
			New Structure("OpenFile", True));
	Else
		FillInTemporaryFormIdentifier(ExecuteParameters.UUID, ExecuteParameters);
		
		Handler = New NotifyDescription("OpenFileWithAlertEnd", ThisObject, ExecuteParameters);
		OpenFileWithoutExtension(Handler, ExecuteParameters.FileData, ExecuteParameters.UUID);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure OpenFileWithAlertWithExtensionAfterReceivingVersionInWorkingDirectory(Result, ExecuteParameters) Export
	
	If Result.FileReceived = True Then
		OpenFileByApplication(ExecuteParameters.FileData, Result.FullFileName);
	EndIf;
	
	OpenFileWithAlertEnd(Result.FileReceived = True, ExecuteParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure OpenFileWithAlertEnd(Result, ExecuteParameters) Export
	
	ClearTemporaryFormIdentifier(ExecuteParameters);
	
	If Result <> True Then
		Return;
	EndIf;
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("Event", "FileOpened");
	Notify("FileOpened", NotificationParameters, ExecuteParameters.FileData.Ref);
	
EndProcedure


Procedure OpenFileWithoutExtension(Notification, FileData, FormID,
		WithWarning = True, SaveDecrypted = True, ExtensionForEncryptedFiles = "")
	
	Context = New Structure;
	Context.Insert("Notification",             Notification);
	Context.Insert("FileData",            FileData);
	Context.Insert("FormID",     FormID);
	Context.Insert("WithWarning",       WithWarning);
	Context.Insert("SaveDecrypted", SaveDecrypted);
	Context.Insert("ExtensionForEncryptedFiles", ExtensionForEncryptedFiles);
	
	If Context.SaveDecrypted
	   AND FileData.Encrypted Then
		
		If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
			ExecuteNotifyProcessing(Context.Notification, False);
			Return;
		EndIf;
		
		ReturnStructure = FileOperationsServiceServerCall.FileDataAndBinaryData(
			FileData.Version,, FormID);
		
		DataDescription = New Structure;
		DataDescription.Insert("Operation",              NStr("en='File decryption';ru='Расшифровка файла'"));
		DataDescription.Insert("DataTitle",       NStr("en='File';ru='Файловый'"));
		DataDescription.Insert("Data",                ReturnStructure.BinaryData);
		DataDescription.Insert("Presentation",         FileData.Ref);
		DataDescription.Insert("EncryptionCertificates", FileData.Ref);
		DataDescription.Insert("NotifyAboutCompletion",   False);
		
		ContinuationHandler = New NotifyDescription(
			"OpenFileWithoutExtensionAfterDecryption", ThisObject, Context);
		
		ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
		ModuleDigitalSignatureClient.Decrypt(DataDescription, , ContinuationHandler);
		
		Return;
	EndIf;
	
	Context.Insert("FileURL", FileData.CurrentVersionURL);
	
	OpenFileWithoutExtensionReminder(Context);
	
EndProcedure

// Procedure continued (see above).
Procedure OpenFileWithoutExtensionAfterDecryption(DataDescription, Context) Export
	
	If Not DataDescription.Success Then
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	If TypeOf(DataDescription.DecryptedData) = Type("BinaryData") Then
		FileURL = PutToTempStorage(DataDescription.DecryptedData,
			Context.FormID);
	Else
		FileURL = DataDescription.DecryptedData;
	EndIf;
	
	Context.Insert("FileURL", FileURL);
	
	OpenFileWithoutExtensionReminder(Context);
	
EndProcedure

// Procedure continued (see above).
Procedure OpenFileWithoutExtensionReminder(Context)
	
	If Context.WithWarning
	   AND Context.FileData.CurrentUserIsEditing Then
		
		FileFunctionsServiceClient.DisplayReminderOnEditing(New NotifyDescription(
			"OpenFileWithoutExtensionFileTransfer", ThisObject, Context));
	Else
		OpenFileWithoutExtensionFileTransfer(, Context);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure OpenFileWithoutExtensionFileTransfer(Result, Context) Export
	
	If Not Context.SaveDecrypted
	   AND Context.FileData.Encrypted
	   AND ValueIsFilled(Context.ExtensionForEncryptedFiles) Then
		
		Extension = Context.ExtensionForEncryptedFiles;
	Else
		Extension = Context.FileData.Extension;
	EndIf;
	
	FileName = CommonUseClientServer.GetNameWithExtention(
		Context.FileData.FullDescrOfVersion, Extension);
	
	GetFile(Context.FileURL, FileName, True);
	
	ExecuteNotifyProcessing(Context.Notification, True);
	
EndProcedure

// Fills out temporary form identifier for cases when
// it is not required to return data in temporary
// storage to calling code, for example, as in procedures Open, OpenFileDirectory in general module FileOperationsClient.
//
Procedure FillInTemporaryFormIdentifier(FormID, ExecuteParameters)
	
	If ValueIsFilled(FormID) Then
		Return;
	EndIf;
	
	ExecuteParameters.Insert("TemporaryForm", GetForm("Catalog.Files.Form.QuestionForm"));
	FormID = ExecuteParameters.TemporaryForm.UUID;
	StandardSubsystemsClient.SetFormStorage(ExecuteParameters.TemporaryForm, True);
	
EndProcedure

// Cancels the storage of temporary identifier filled out previously.
Procedure ClearTemporaryFormIdentifier(ExecuteParameters)
	
	If ExecuteParameters.Property("TemporaryForm") Then
		StandardSubsystemsClient.SetFormStorage(ExecuteParameters.TemporaryForm, False);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Imports the file into the application and sends an alert.

// Saves the file in infobase but does not unlock it.
Procedure SaveFileChangesWithAlert(ResultHandler, CommandParameter, FormID) Export
	
	If CommandParameter = Undefined Then
		ReturnResult(ResultHandler, Undefined);
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("CommandParameter", CommandParameter);
	
	Handler = New NotifyDescription("SaveFileChangesWithAlertEnd", ThisObject, ExecuteParameters);
	HandlerParameters = FileUpdateParameters(Handler, CommandParameter, FormID);
	SaveFileChanges(HandlerParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure SaveFileChangesWithAlertEnd(Result, ExecuteParameters) Export
	
	If Result = True Then
		Notify("Record_File", New Structure("Event", "FileDataChanged"), ExecuteParameters.CommandParameter);
		Notify("Record_File", New Structure("Event", "VersionSaved"), ExecuteParameters.CommandParameter);
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Shows the dialog for file selection on disk, imports selected file into the application as a version and sends a notification.

// Selects a file on disk and creates a new version from it.
Procedure UpdateFromFileOnDiskWithAlert(ResultHandler, FileData, FormID) Export
	
	If Not FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		FileFunctionsServiceClient.ShowWarningAboutNeedToFileOperationsExpansion(ResultHandler);
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("FileData", FileData);
	Handler = New NotifyDescription("UpdateFromFileOnDiskWithAlertEnd", ThisObject, ExecuteParameters);
	UpdateFromFileOnDrive(Handler, FileData, FormID);
	
EndProcedure

// Procedure continued (see above).
Procedure UpdateFromFileOnDiskWithAlertEnd(Result, ExecuteParameters) Export
	
	If Result = True Then
		NotifyChanged(ExecuteParameters.FileData.Ref);
		Notify("Record_File", New Structure("Event", "FileDataChanged"), ExecuteParameters.FileData.Ref);
		Notify("Record_File", New Structure("Event", "VersionSaved"), ExecuteParameters.FileData.Ref);
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// File encryption.

// Encrypt the file.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FileData - Structure with file data.
//  UUID - UUID of the form.
//
// Returns:
//   Structure - Result.
//       * Success - Boolean - whether the operation is successfully completed.
//       * DataArrayForImportingToBase - Array - Array of data for recording in the application.
//       * ThumbprintsArray - Array - Thumbprints array.
//
Procedure Encrypt(ResultHandler, FileData, UUID) Export
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("FileData", FileData);
	ExecuteParameters.Insert("UUID", UUID);
	ExecuteParameters.Insert("Success", False);
	ExecuteParameters.Insert("ArrayDataForPlacingToBase", New Array);
	ExecuteParameters.Insert("ThumbprintArray", New Array);
	
	If ExecuteParameters.FileData.Encrypted Then
		WarningText = NStr("en='File ""%1"" is already encrypted.';ru='Файл ""%1"" уже зашифрован.'");
		WarningText = StrReplace(WarningText, "%1", String(ExecuteParameters.FileData.Ref));
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, WarningText, ExecuteParameters);
		Return;
	EndIf;
	
	If Not ExecuteParameters.FileData.IsEditing.IsEmpty() Then
		WarningText = NStr("en='Cannot encrypt locked file.';ru='Нельзя зашифровать занятый файл.'");
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, WarningText, ExecuteParameters);
		Return;
	EndIf;
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	// No need to OfferSettingFileOperationsExtension() as all is done in memory through BinaryData.
	
	VersionArray = FileOperationsServiceServerCall.FileDataAndURLForAllFileVersions(ExecuteParameters.FileData.Ref,
		ExecuteParameters.UUID);
	
	If VersionArray.Count() = 0 Then
		ReturnResult(ExecuteParameters.ResultHandler, False);
		Return;
	EndIf;
	
	ExecuteParameters.ArrayDataForPlacingToBase = New Array;
	
	FilePresentation = String(ExecuteParameters.FileData.Ref);
	If ExecuteParameters.FileData.CountVersions > 1 Then
		FilePresentation = FilePresentation + " (" + StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Versions: %1';ru='Версий: %1'"), ExecuteParameters.FileData.CountVersions) + ")";
	EndIf;
	PresentationsList = New ValueList;
	PresentationsList.Add(ExecuteParameters.FileData.Ref, FilePresentation);
	
	DataSet = New Array;
	
	For Each VersionProperties IN VersionArray Do
		
		CurrentExecutionParameters = New Structure;
		CurrentExecutionParameters.Insert("ExecuteParameters", ExecuteParameters);
		CurrentExecutionParameters.Insert("VersionRef", VersionProperties.VersionRef);
		CurrentExecutionParameters.Insert("FileURL",   VersionProperties.VersionURL);
		
		DataItem = New Structure;
		DataItem.Insert("Data", VersionProperties.VersionURL);
		
		DataItem.Insert("ResultPlacement", New NotifyDescription(
			"WhenReceivingEncryptedData", ThisObject, CurrentExecutionParameters));
		
		DataSet.Add(DataItem);
	EndDo;
	
	DataDescription = New Structure;
	DataDescription.Insert("Operation",            NStr("en='File encryption';ru='Шифрование файла'"));
	DataDescription.Insert("DataTitle",     NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("DataSet",         DataSet);
	DataDescription.Insert("SetPresentation", NStr("en='Files (%1)';ru='Файлы (%1)'"));
	DataDescription.Insert("PresentationsList", PresentationsList);
	DataDescription.Insert("NotifyAboutCompletion", False);
	
	ContinuationHandler = New NotifyDescription("AfterEncryptingFile", ThisObject, ExecuteParameters);
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.Encrypt(DataDescription, , ContinuationHandler);
	
EndProcedure

// Continue the procedure Encrypt. Called from the DigitalSignature subsystem.
Procedure WhenReceivingEncryptedData(Parameters, CurrentExecutionParameters) Export
	
	ExecuteParameters = CurrentExecutionParameters.ExecuteParameters;
	
	EncryptedData = Parameters.DataDescription.CurrentDataSetItem.EncryptedData;
	If TypeOf(EncryptedData) = Type("BinaryData") Then
		TemporaryStorageAddress = PutToTempStorage(EncryptedData,
			ExecuteParameters.UUID);
	Else
		TemporaryStorageAddress = EncryptedData;
	EndIf;
	
	DataForRecordsAtServer = New Structure;
	DataForRecordsAtServer.Insert("TemporaryStorageAddress", TemporaryStorageAddress);
	DataForRecordsAtServer.Insert("VersionRef", CurrentExecutionParameters.VersionRef);
	DataForRecordsAtServer.Insert("FileURL",   CurrentExecutionParameters.FileURL);
	DataForRecordsAtServer.Insert("TextTemporaryStorageAddress", "");
	
	ExecuteParameters.ArrayDataForPlacingToBase.Add(DataForRecordsAtServer);
	
	ExecuteNotifyProcessing(Parameters.Notification, New Structure);
	
EndProcedure

// Ending the Encrypt procedure. Called from the DigitalSignature subsystem.
Procedure AfterEncryptingFile(DataDescription, ExecuteParameters) Export
	
	ExecuteParameters.Success = DataDescription.Success;
	
	If DataDescription.Success Then
		If TypeOf(DataDescription.EncryptionCertificates) = Type("String") Then
			ExecuteParameters.Insert("ThumbprintArray", GetFromTempStorage(
				DataDescription.EncryptionCertificates));
		Else
			ExecuteParameters.Insert("ThumbprintArray", DataDescription.EncryptionCertificates);
		EndIf;
		NotifyOnFileChange(ExecuteParameters.FileData);
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// File decryption.

// Will decrypt the object - File, Version.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//  FileRef  - CatalogRef.Files - file.
//  UUID - form unique ID.
//  FileData  - structure with file data.
//
// Returns:
//   Structure - Result.
//       * Success - Boolean - whether the operation is successfully completed.
//       * DataArrayForImportingToBase - Array of structures.
//
Procedure Decrypt(ResultHandler, FileRef, UUID, FileData) Export
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("FileRef", FileRef);
	ExecuteParameters.Insert("UUID", UUID);
	ExecuteParameters.Insert("FileData", FileData);
	ExecuteParameters.Insert("Success", False);
	ExecuteParameters.Insert("ArrayDataForPlacingToBase", New Array);
	
	// No need to OfferSettingFileOperationsExtension() as all is done in memory through BinaryData.
	
	VersionArray = FileOperationsServiceServerCall.FileDataAndURLForAllFileVersions(
		ExecuteParameters.FileRef, ExecuteParameters.UUID);
	
	ExecuteParameters.ArrayDataForPlacingToBase = New Array;
	
	ExecuteParameters.Insert("ExtractFileTextsAtServer",
		FileFunctionsServiceClientServer.FileOperationsCommonSettings().ExtractFileTextsAtServer);
	
	FilePresentation = String(ExecuteParameters.FileData.Ref);
	If ExecuteParameters.FileData.CountVersions > 1 Then
		FilePresentation = FilePresentation + " (" + StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Versions: %1';ru='Версий: %1'"), ExecuteParameters.FileData.CountVersions) + ")";
	EndIf;
	PresentationsList = New ValueList;
	PresentationsList.Add(ExecuteParameters.FileData.Ref, FilePresentation);
	
	EncryptionCertificates = New Array;
	EncryptionCertificates.Add(ExecuteParameters.FileData.Ref);
	
	DataSet = New Array;
	
	For Each VersionProperties IN VersionArray Do
		
		CurrentExecutionParameters = New Structure;
		CurrentExecutionParameters.Insert("ExecuteParameters", ExecuteParameters);
		CurrentExecutionParameters.Insert("VersionRef", VersionProperties.VersionRef);
		CurrentExecutionParameters.Insert("FileURL",   VersionProperties.VersionURL);
		
		DataItem = New Structure;
		DataItem.Insert("Data", VersionProperties.VersionURL);
		
		DataItem.Insert("ResultPlacement", New NotifyDescription(
			"WhenReceivingDecryptedData", ThisObject, CurrentExecutionParameters));
		
		DataSet.Add(DataItem);
	EndDo;
	
	DataDescription = New Structure;
	DataDescription.Insert("Operation",              NStr("en='File decryption';ru='Расшифровка файла'"));
	DataDescription.Insert("DataTitle",       NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("DataSet",           DataSet);
	DataDescription.Insert("SetPresentation",   NStr("en='Files (%1)';ru='Файлы (%1)'"));
	DataDescription.Insert("PresentationsList",   PresentationsList);
	DataDescription.Insert("EncryptionCertificates", EncryptionCertificates);
	DataDescription.Insert("NotifyAboutCompletion",   False);
	
	ContinuationHandler = New NotifyDescription("AfterFileDecryption", ThisObject, ExecuteParameters);
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.Decrypt(DataDescription, , ContinuationHandler);
	
EndProcedure

// Continue the procedure Decrypt. Called from the DigitalSignature subsystem.
Procedure WhenReceivingDecryptedData(Parameters, CurrentExecutionParameters) Export
	
	ExecuteParameters = CurrentExecutionParameters.ExecuteParameters;
	
	DecryptedData = Parameters.DataDescription.CurrentDataSetItem.DecryptedData;
	If TypeOf(DecryptedData) = Type("BinaryData") Then
		TemporaryStorageAddress = PutToTempStorage(DecryptedData,
			ExecuteParameters.UUID);
		#If Not WebClient Then
			BinaryDataDecrypted = DecryptedData;
		#EndIf
	Else
		TemporaryStorageAddress = DecryptedData;
		#If Not WebClient Then
			BinaryDataDecrypted = GetFromTempStorage(TemporaryStorageAddress);
		#EndIf
	EndIf;
	
	TextTemporaryStorageAddress = "";
	#If Not WebClient Then
		If Not ExecuteParameters.ExtractFileTextsAtServer Then
			FullPathToFile = GetTempFileName(ExecuteParameters.FileData.Extension);
			BinaryDataDecrypted.Write(FullPathToFile);
			
			TextTemporaryStorageAddress = FileFunctionsServiceClientServer.ExtractTextToTemporaryStorage(
				FullPathToFile, ExecuteParameters.UUID);
				
			DeleteFiles(FullPathToFile);
		Else
			TextTemporaryStorageAddress = "";
		EndIf;
	#EndIf
	
	DataForRecordsAtServer = New Structure;
	DataForRecordsAtServer.Insert("TemporaryStorageAddress", TemporaryStorageAddress);
	DataForRecordsAtServer.Insert("VersionRef", CurrentExecutionParameters.VersionRef);
	DataForRecordsAtServer.Insert("FileURL",   CurrentExecutionParameters.FileURL);
	DataForRecordsAtServer.Insert("TextTemporaryStorageAddress", TextTemporaryStorageAddress);
	
	ExecuteParameters.ArrayDataForPlacingToBase.Add(DataForRecordsAtServer);
	
	ExecuteNotifyProcessing(Parameters.Notification, New Structure);
	
EndProcedure

// Ending the Decrypt procedure. Called from the DigitalSignature subsystem.
Procedure AfterFileDecryption(DataDescription, ExecuteParameters) Export
	
	ExecuteParameters.Success = DataDescription.Success;
	
	If DataDescription.Success Then
		NotifyOnFileChange(ExecuteParameters.FileData);
	EndIf;
	
	ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Creates a new file.

// Creates a new file interactively with a call of dialog for selection of file creation mode.
//
// Parameters:
//  see FileOperationsClient.AddFile().
//
Procedure AddFile(
	ResultHandler,
	FileOwner,
	OwnerForm,
	CreationMode = 1,
	DoNotOpenCardAfterCreateFromFile = Undefined) Export
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("FileOwner", FileOwner);
	ExecuteParameters.Insert("OwnerForm", OwnerForm);
	ExecuteParameters.Insert("DoNotOpenCardAfterCreateFromFile", DoNotOpenCardAfterCreateFromFile);
	
	ReturnForm = FileOperationsServiceClientReUse.NewFileCreatingOptionChoiceForm();
	ReturnForm.SetUsageParameters(CreationMode);
	
	Handler = New NotifyDescription("AddAfterCreateModeSelection", ThisObject, ExecuteParameters);
	SetFormAlert(ReturnForm, Handler);
	
	ReturnForm.Open();
	
EndProcedure

// Creates a new file interactively in specified way.
//
// Parameters:
//   CreationMode - Number - File creation mode.
//       I 1 - from pattern (by copying
//       another file), * 2 - from disk (from the file
//       client system), * 3 - from scanner.
//   ExecuteParameters - Structure - types values and description cm. in FileOperationsClient.AddFile().
//       * ResultHandler.
//       * FileOwner.
//       * OwnerForm
//       * DoNotOpenCardAfterCreateFromFile.
//
Procedure AddAfterCreateModeSelection(CreationMode, ExecuteParameters) Export
	
	If CreationMode = 1 Then // Copy another file.
		AddBasedOnTemplate(ExecuteParameters);
	ElsIf CreationMode = 2 Then // Import from file system.
		If FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
			AddFromFileSystemWithExtension(ExecuteParameters);
		Else
			AddFromFileSystemWithoutExpansion(ExecuteParameters);
		EndIf;
	ElsIf CreationMode = 3 Then // Read from scanner.
		AddFromScanner(ExecuteParameters);
	Else
		ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure AddBasedOnTemplate(ExecuteParameters) Export
	
	// Copy another file.
	FormParameters = New Structure;
	FormParameters.Insert("ChoosingTemplate", True);
	FormParameters.Insert("CurrentRow", PredefinedValue("Catalog.FileFolders.Patterns"));
	Handler = New NotifyDescription("AddBasedOnTemplateAfterSelectingTemplate", ThisObject, ExecuteParameters);
	OpeningMode = FormWindowOpeningMode.LockWholeInterface;
	OpenForm("Catalog.Files.Form.ChoiceForm", FormParameters, , , , , Handler, OpeningMode);
	
EndProcedure

// Procedure continued (see above).
Procedure AddBasedOnTemplateAfterSelectingTemplate(Result, ExecuteParameters) Export
	
	If Result = Undefined Then
		ReturnResult(ExecuteParameters.ResultHandler, Undefined);
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("BasisFile", Result);
	FormParameters.Insert("FileOwner", ExecuteParameters.FileOwner);
	FormParameters.Insert("CreationMode", "FromTemplate");
	ResultHandler = PrepareHandlerForDialog(ExecuteParameters.ResultHandler);
	OpenForm("Catalog.Files.ObjectForm", FormParameters, ExecuteParameters.OwnerForm, , , , ResultHandler);
	
EndProcedure

// Based on passed path to file on disk creates a File and opens a card.
//
//  AddingParameters - Structure:
//       * ResultHandler - NotifyDescription, Undefined.
//             - Description of the procedure that receives the result of method work.
//       * FileFullName - String - Optional. Full path and attachment file name on the client.
//             If it is not specified, the dialog for file selection will open.
//       * FileOwner - AnyRef - file owner.
//       * FormOwner - ManagedForm from which the file was created.
//       * DoNotOpenCardAfterCreatingFromFile - Boolean.
//             - True when file card does not open after creation.
//       * CreatedFileName - String - Optional. New attachment file name.
//
Procedure AddFromFileSystemWithExtension(ExecuteParameters) Export
	
	Result = AddFromFileSystemWithExtensionSynchronously(ExecuteParameters);
	If Not Result.FileAdded Then
		If ValueIsFilled(Result.ErrorText) Then
			ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, Result.ErrorText, Undefined);
		Else
			ReturnResult(ExecuteParameters.ResultHandler, Undefined);
		EndIf;
		Return;
	EndIf;
	
	If ExecuteParameters.DoNotOpenCardAfterCreateFromFile <> True Then
		FormParameters = New Structure;
		FormParameters.Insert("Key", Result.FileRef);
		FormParameters.Insert("CardIsOpenAfterFileCreate", True);
		
		DialogHandler = PrepareHandlerForDialog(ExecuteParameters.ResultHandler);
		OpenForm("Catalog.Files.ObjectForm", FormParameters, ExecuteParameters.OwnerForm, , , , DialogHandler);
	Else
		ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	EndIf;
	
EndProcedure

// Based on passed path to file on disk creates a File and opens a card.
//
//  AddingParameters - Structure:
//       * FileFullName - String - Optional. Full path and attachment file name on the client.
//             If it is not specified, then a synchronous dialog for file selection will be opened.
//       * FileOwner - AnyRef - file owner.
//       *UUID - UUID - Identifier of the form for file storage.
//       * CreatedFileName - String - Optional. New attachment file name.
//
// Returns:
//   Structure - Result.
//       * FileAdded - Boolean - whether the operation is successfully completed.
//       * FileRef - CatalogRef.Files
//       * ErrorText - String.
//
Function AddFromFileSystemWithExtensionSynchronously(ExecuteParameters) Export
	
	Result = New Structure;
	Result.Insert("FileAdded", False);
	Result.Insert("FileRef",   Undefined);
	Result.Insert("ErrorText",  "");
	
	If Not ExecuteParameters.Property("FullFileName") Then
		// Import from file system with extension for work with files.
		FileDialog = New FileDialog(FileDialogMode.Open);
		FileDialog.Multiselect = False;
		FileDialog.Title = NStr("en='Select file';ru='Выбор файла'");
		FileDialog.Filter = NStr("en='All files (*.*)|*.*';ru='Все файлы (*.*)|*.*'");
		FileDialog.Directory = FileOperationsServiceServerCall.FolderWorkingDirectory(ExecuteParameters.FileOwner);
		If Not FileDialog.Choose() Then
			Return Result;
		EndIf;
		ExecuteParameters.Insert("FullFileName", FileDialog.FullFileName);
	EndIf;
	
	If Not ExecuteParameters.Property("CreatedFileName") Then
		ExecuteParameters.Insert("CreatedFileName", Undefined);
	EndIf;
	
	ClientFile = New File(ExecuteParameters.FullFileName);
	
	FileFunctionsServiceClientServer.CheckFileImportingPossibility(ClientFile);
	
	CommonSettings = FileFunctionsServiceClientServer.FileOperationsCommonSettings();
	RetrieveFilesTextsOnClient = Not CommonSettings.ExtractFileTextsAtServer;
	If RetrieveFilesTextsOnClient Then
		TextTemporaryStorageAddress = FileFunctionsServiceClientServer.ExtractTextToTemporaryStorage(
			ClientFile.FullName,
			ExecuteParameters.OwnerForm.UUID);
	Else
		TextTemporaryStorageAddress = "";
	EndIf;
	
	If ExecuteParameters.CreatedFileName <> Undefined Then
		NameCreation = ExecuteParameters.CreatedFileName;
	Else
		NameCreation = ClientFile.BaseName;
	EndIf;
	
	FileName  = NameCreation + ClientFile.Extension;
	SizeInMB = ClientFile.Size() / (1024 * 1024);
	
	StatusText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Saving the ""%1"" file (%2 Mb).
		|Please wait...';ru='Идет сохранение файла ""%1"" (%2 Мб).
		|Пожалуйста, подождите..'"),
		FileName,
		FileFunctionsServiceClientServer.GetStringWithFileSize(SizeInMB));
	Status(StatusText);
	
	// Placing the file in temporary storage.
	FileTemporaryStorageAddress = "";
	
	FilesToPlace = New Array;
	Definition = New TransferableFileDescription(ClientFile.FullName, "");
	FilesToPlace.Add(Definition);
	
	PlacedFiles = New Array;
	FilesPlaced = PutFiles(FilesToPlace, PlacedFiles, , False, ExecuteParameters.OwnerForm.UUID);
	If Not FilesPlaced Then
		Return Result;
	EndIf;
	
	If PlacedFiles.Count() = 1 Then
		FileTemporaryStorageAddress = PlacedFiles[0].Location;
	EndIf;
	
	// Creating File card in DB.
	Try
		FileInformation = FileOperationsClientServer.FileInformation("FileWithVersion", ClientFile);
		FileInformation.FileTemporaryStorageAddress = FileTemporaryStorageAddress;
		FileInformation.TextTemporaryStorageAddress = TextTemporaryStorageAddress;
		FileInformation.WriteIntoHistory = True;
		FileInformation.BaseName = NameCreation;
		Result.FileRef = FileOperationsServiceServerCall.CreateFileWithVersion(ExecuteParameters.FileOwner, FileInformation);
		Result.FileAdded = True;
	Except
		Result.ErrorText = FileFunctionsServiceClientServer.NewFileCreationError(ErrorInfo());
	EndTry;
	Status();
	
	If Result.ErrorText <> "" Then
		Return Result;
	EndIf;
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("Owner", ExecuteParameters.FileOwner);
	NotificationParameters.Insert("File",     Result.FileRef);
	NotificationParameters.Insert("Event",  "FileCreated");
	Notify("Record_File", NotificationParameters);
	
	ShowUserNotification(
		NStr("en='Created:';ru='Создание:'"),
		GetURL(Result.FileRef),
		Result.FileRef,
		PictureLib.Information32);
	
	Return Result;
	
EndFunction

// Procedure continued (see above).
Procedure AddFromFileSystemWithoutExpansion(ExecuteParameters) Export
	
	// Import from file system without the extension for work with files (web client).
	Handler = New NotifyDescription("AddFromFileSystemWithoutExtensionAfterFileImport", ThisObject, ExecuteParameters);
	BeginPutFile(Handler, , , , ExecuteParameters.OwnerForm.UUID);
	
EndProcedure

// Procedure continued (see above).
Procedure AddFromFileSystemWithoutExtensionAfterFileImport(Placed, Address, SelectedFileName, ExecuteParameters) Export
	
	If Not Placed Then
		ReturnResult(ExecuteParameters.ResultHandler, Undefined);
		Return;
	EndIf;
	
	PathStrings = CommonUseClientServer.SortStringByPointsAndSlashes(SelectedFileName);
	If PathStrings.Count() < 2 Then
		QuestionText = NStr("en='Specify file with extension.';ru='Необходимо указать файл с расширением.'");
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Retry, NStr("en='Select another file';ru='Выбрать другой файл'"));
		Buttons.Add(DialogReturnCode.Cancel);
		Handler = New NotifyDescription("AddFromFileSystemWithoutExtensionAfterAnswerToQuestionRepeat", ThisObject, ExecuteParameters);
		ShowQueryBox(Handler, QuestionText, Buttons);
		Return;
	EndIf;
	
	// Creating file card in DB.
	ErrorText = "";
	Try
		FileInformation = FileOperationsClientServer.FileInformation("FileWithVersion");
		FileInformation.FileTemporaryStorageAddress = Address;
		FileInformation.BaseName = PathStrings[PathStrings.Count() - 2];
		FileInformation.ExtensionWithoutDot = CommonUseClientServer.ExtensionWithoutDot(PathStrings[PathStrings.Count() - 1]);
		FileRef = FileOperationsServiceServerCall.CreateFileWithVersion(ExecuteParameters.FileOwner, FileInformation);
	Except
		ErrorText = FileFunctionsServiceClientServer.NewFileCreationError(ErrorInfo());
	EndTry;
	If ErrorText <> "" Then
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, ErrorText, Undefined);
		Return;
	EndIf;
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("Owner", ExecuteParameters.FileOwner);
	NotificationParameters.Insert("File", FileRef);
	NotificationParameters.Insert("Event", "FileCreated");
	Notify("Record_File", NotificationParameters);
	
	ShowUserNotification(
		NStr("en='Created:';ru='Создание:'"),
		GetURL(FileRef),
		FileRef,
		PictureLib.Information32);
	
	If ExecuteParameters.DoNotOpenCardAfterCreateFromFile <> True Then
		FormParameters = New Structure;
		FormParameters.Insert("Key", FileRef);
		FormParameters.Insert("CardIsOpenAfterFileCreate", True);
		
		ResultHandler = PrepareHandlerForDialog(ExecuteParameters.ResultHandler);
		OpenForm("Catalog.Files.ObjectForm", FormParameters, ExecuteParameters.OwnerForm, , , , ResultHandler);
	Else
		ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure AddFromFileSystemWithoutExtensionAfterAnswerToQuestionRepeat(Response, ExecuteParameters) Export
	
	If Response = DialogReturnCode.Retry Then
		AddFromFileSystemWithoutExpansion(ExecuteParameters);
	Else
		ReturnResult(ExecuteParameters.ResultHandler, Undefined);
	EndIf;
	
EndProcedure

// Opens the dialog for scanning and image viewing.
Procedure AddFromScanner(ExecuteParameters) Export
	
	If CommonUseClientServer.IsLinuxClient() Then
		ReturnResult(ExecuteParameters.ResultHandler, Undefined);
		Return;
	EndIf;
	
	SystemInfo = New SystemInfo();
	ClientID = SystemInfo.ClientID;
	
	FormParameters = New Structure;
	FormParameters.Insert("FileOwner", ExecuteParameters.FileOwner);
	FormParameters.Insert("ClientID", ClientID);
	FormParameters.Insert("DoNotOpenCardAfterCreateFromFile", ExecuteParameters.DoNotOpenCardAfterCreateFromFile);
	
	ResultHandler = PrepareHandlerForDialog(ExecuteParameters.ResultHandler);
	OpenForm("Catalog.Files.Form.ScanningResult", FormParameters, ExecuteParameters.OwnerForm, , , , ResultHandler);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Sends the notification about the end of file encryption or decryption.

// At the end of the Encrypt notifies.
// Parameters:
//  FilesArrayInWorkingDirectoryForDelete - Array - String array - paths to files.
//  FileOwner  - AnyRef - file owner.
//  FileRef  - CatalogRef.Files - file.
Procedure InformAboutEncryption(FilesArrayInWorkingDirectoryForDelete,
                                   FileOwner,
                                   FileRef) Export
	
	NotifyChanged(FileRef);
	Notify("Record_File", New Structure("Event", "AttachedFileEncrypted"), FileOwner);
	Notify("Record_File", New Structure("Event", "FileDataChanged"), FileRef);
	
	// Delete all versions of the file from working directory.
	For Each FullFileName IN FilesArrayInWorkingDirectoryForDelete Do
		DeleteFileWithoutConfirmation(FullFileName);
	EndDo;
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.InformAboutObjectEncryption(
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='File: %1';ru='Файл: %1'"), FileRef));
	
EndProcedure

// At the end of Decrypt notifies.
// Parameters:
//  FileOwner  - AnyRef - file owner.
//  FileRef  - CatalogRef.Files - file.
Procedure InformAboutDescripting(FileOwner, FileRef) Export
	
	NotifyChanged(FileRef);
	Notify("Record_File", New Structure("Event", "AttachedFileEncrypted"), FileOwner);
	Notify("Record_File", New Structure("Event", "FileDataChanged"), FileRef);
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.InformAboutObjectDecryption(
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='File: %1';ru='Файл: %1'"), FileRef));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Working with digital signatures.

// Signs current file version using the DigitalSignature subsystem.
Procedure SignFile(FilesArray, FormID, EndProcessor) Export
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	DataSet = New Array;
	FilesDataArray = New Array;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("EndProcessor", EndProcessor);
	ExecuteParameters.Insert("FormID", FormID);
	ExecuteParameters.Insert("FilesDataArray", FilesDataArray);
	
	For Each File IN FilesArray Do
		FileData = FileOperationsServiceServerCall.FileDataAndWorkingDirectory(File);
	
		If Not FileData.IsEditing.IsEmpty() Then
			WarningText = FileFunctionsServiceClientServer.MessageStringAboutImpossibilityOfLockedFileSigning(File);
			ReturnResultAfterShowWarning(EndProcessor, WarningText, ExecuteParameters);
			Return;
		EndIf;
		
		If FileData.Encrypted Then
			WarningText = FileFunctionsServiceClientServer.MessageStringAboutImpossibilityOfEncryptedFileSigning(File);
			ReturnResultAfterShowWarning(EndProcessor, WarningText, ExecuteParameters);
			Return;
		EndIf;
		
		FilesDataArray.Add(FileData);
		
		CurrentExecutionParameters = New Structure;
		CurrentExecutionParameters.Insert("FormID", FormID);
		CurrentExecutionParameters.Insert("FileData", FileData);
		
		DataItem = New Structure;
		DataItem.Insert("Presentation", FileData.Ref);
		DataItem.Insert("Data",
			New NotifyDescription("WhenRequestingFileBinaryData", ThisObject, CurrentExecutionParameters));
		DataItem.Insert("Object",
			New NotifyDescription("OnReceiveSignature", ThisObject, CurrentExecutionParameters));
		DataSet.Add(DataItem);
		
	EndDo;
	
	DataDescription = New Structure;
	DataDescription.Insert("ShowComment", True);
	DataDescription.Insert("Operation",            NStr("en='File signing';ru='Подписание файла'"));
	DataDescription.Insert("DataTitle",     NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("DataSet",         DataSet);
	DataDescription.Insert("SetPresentation", NStr("en='Files (%1)';ru='Файлы (%1)'"));
	
	ContinuationHandler = New NotifyDescription("AfterSigningFiles", ThisObject, ExecuteParameters);
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.Sign(DataDescription, , ContinuationHandler);
	
EndProcedure

// Continue SignFile procedure.
// Called from the DigitalSignature subsystem when data for signing is requested.
//
Procedure WhenRequestingFileBinaryData(Parameters, Context) Export
	
	Data = FileOperationsServiceServerCall.FileDataAndBinaryData(
		Context.FileData.Ref).BinaryData;
	
	ExecuteNotifyProcessing(Parameters.Notification, New Structure("Data", Data));
	
EndProcedure

// Continue SignFile procedure.
// Called out of subsystem DigitalSignature after data
// signing for method of nonstandard signature addition to item.
//
Procedure OnReceiveSignature(Parameters, Context) Export
	
	FileOperationsServiceServerCall.AddFileSignature(
		Context.FileData.Ref,
		Parameters.DataDescription.CurrentDataSetItem.SignatureProperties,
		Context.FormID);
	
	ExecuteNotifyProcessing(Parameters.Notification, New Structure);
	
EndProcedure

// End of procedure SignFile.
Procedure AfterSigningFiles(DataDescription, ExecuteParameters) Export
	
	If DataDescription.Success Then
		For Each FileData IN ExecuteParameters.FilesDataArray Do
			NotifyOnFileChange(FileData);
		EndDo;
	EndIf;
	
	ReturnResult(ExecuteParameters.EndProcessor, DataDescription.Success);
	
EndProcedure


// Adds digital signatures to a file-object from the file-signatures on drive.
Procedure AddSignatureFromFile(File, FormID, EndProcessor) Export
	
	FileData = FileOperationsServiceServerCall.FileDataAndWorkingDirectory(File);
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("EndProcessor", EndProcessor);
	ExecuteParameters.Insert("FileData", FileData);
	ExecuteParameters.Insert("FormID", FormID);
	
	If Not ExecuteParameters.FileData.IsEditing.IsEmpty() Then
		WarningText = FileFunctionsServiceClientServer.MessageStringAboutImpossibilityOfLockedFileSigning();
		ReturnResultAfterShowWarning(ExecuteParameters.ResultHandler, WarningText, ExecuteParameters);
		Return;
	EndIf;
	
	If ExecuteParameters.FileData.Encrypted Then
		WarningText = FileFunctionsServiceClientServer.MessageStringAboutImpossibilityOfEncryptedFileSigning();
		ReturnResultAfterShowWarning(ExecuteParameters.EndProcessor, WarningText, ExecuteParameters);
		Return;
	EndIf;
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	DataDescription = New Structure;
	DataDescription.Insert("DataTitle",     NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("Presentation",       ExecuteParameters.FileData.Ref);
	DataDescription.Insert("ShowComment", True);
	
	DataDescription.Insert("Object",
		New NotifyDescription("SignaturesOnReceive", ThisObject, ExecuteParameters));
	
	ContinuationHandler = New NotifyDescription("AfterSigningFile",
		ThisObject, ExecuteParameters);
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.AddSignatureFromFile(DataDescription,, ContinuationHandler);
	
EndProcedure

// Continue procedure AddSignatureFromFile.
// Called out of subsystem DigitalSignature after signature preparation from
// files for method of nonstandard signature addition to item.
//
Procedure SignaturesOnReceive(Parameters, Context) Export
	
	FileOperationsServiceServerCall.AddFileSignature(
		Context.FileData.Ref,
		Parameters.DataDescription.Signatures,
		Context.FormID);
	
	ExecuteNotifyProcessing(Parameters.Notification, New Structure);
	
EndProcedure

// End procedure AddSignatureFromFile.
Procedure AfterSigningFile(DataDescription, ExecuteParameters) Export
	
	If DataDescription.Success Then
		NotifyOnFileChange(ExecuteParameters.FileData);
	EndIf;
	
	ReturnResult(ExecuteParameters.EndProcessor, DataDescription.Success);
	
EndProcedure

// For procedures AfterSigningFile, AfterSigningFiles.
Procedure NotifyOnFileChange(FileData)
	
	NotifyChanged(FileData.Ref);
	NotifyChanged(FileData.CurrentVersion);
	
	NotificationParameter = New Structure("Event", "AttachedFileDigitallySigned");
	Notify("Record_File", NotificationParameter, FileData.Owner);
	
EndProcedure


// Saves file with digital signature.
Procedure SaveFileTogetherWithSignature(File, FormID) Export
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForSave(File);
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("FileData", FileData);
	ExecuteParameters.Insert("FormID", FormID);
	
	DataDescription = New Structure;
	DataDescription.Insert("DataTitle",     NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("Presentation",       ExecuteParameters.FileData.Ref);
	DataDescription.Insert("ShowComment", True);
	DataDescription.Insert("Object",              ExecuteParameters.FileData.CurrentVersion);
	
	DataDescription.Insert("Data",
		New NotifyDescription("WhenYouSaveDataFile", ThisObject, ExecuteParameters));
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.SaveDataWithSignature(DataDescription);
	
EndProcedure

// Continue procedure SaveFileTogetherWithSignatures.
// It is called from the DigitalSignature subsystem after selection of the signature for saving.
//
Procedure WhenYouSaveDataFile(Parameters, Context) Export
	
	SaveAs(Parameters.Notification, Context.FileData, Context.FormID);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Imports the structure of files and directories from disk into the application.

// Returns:
//  Structure - with properties:
//    * ResultHandler      - NotifyDescription - handler to which the result of import is transferred.
//    * Owner                  - AnyRef - object-owner to which imported files are added.
//    * SelectedFiles            - ValueList - imported objects File.
//    * Indicator                 - Number - number from 0 to 100 - execution progress.
//    * Comment               - String - Comment.
//    * StoreVersions             - Boolean - Store versions.
//    * DeleteFilesAfterAdding - Boolean - Delete files SelectedFiles after completing import.
//    * Recursively                - Boolean - Recursively bypass subdirectories.
//    * FormIdentifier        - UUID - form identifiers.
//    * PseudoFileSystem     - Map - emulation of file system - for string (directory) returns
//                                                 the array of strings (subdirectories and files).
//    * ImportMode             - Boolean - Import mode (from background job FilesImport).
//    * Encoding                 - String - encoding for text files.
//    * AddedFiles          - Array - Added files output parameter.
//
Function FileImportParameters() Export
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler");
	ExecuteParameters.Insert("Owner");      
	ExecuteParameters.Insert("SelectedFiles"); 
	ExecuteParameters.Insert("Comment");
	ExecuteParameters.Insert("StoreVersions");
	ExecuteParameters.Insert("DeleteFilesAfterAdd");
	ExecuteParameters.Insert("Recursively");
	ExecuteParameters.Insert("FormID");
	ExecuteParameters.Insert("PseudoFileSystem", New Map);
	ExecuteParameters.Insert("ImportMode", False);
	ExecuteParameters.Insert("Encoding");
	ExecuteParameters.Insert("AddedFiles", New Array);
	Return ExecuteParameters;
EndFunction

// Recursive function of files import from disk - accepts array of files (or directories)
// - if a file, just add it if a directory - creates a group and recursively calls itself.
//
// Parameters:
//  ExecuteParameters   - Structure - with properties:
//    * ResultHandler      - NotificationDescription, Structure - handler to which the
//                                  result of import is transferred.
//    * Owner                  - AnyRef - file owner.
//    * SelectedFiles            - Array, ValuesList - objects File.
//    * Indicator                 - Number - number from 0 to 100 - execution progress.
//    * FileNamesWithErrorsArray - Array - Array of names of files with errors.
//    * AllFilesStructuresArray  - Array - Array of all files structures.
//    * Comment               - String - Comment.
//    * StoreVersions             - Boolean - Store versions.
//    * DeleteFilesAfterAdding - Boolean - Delete files SelectedFiles after completing import.
//    * Recursively                - Boolean - Recursively bypass subdirectories.
//    * NumberTotal       - Number - Total quantity of imported files.
//    * Counter                   - Number - Counter of processed files (not necessarily the file will be imported).
//    * FormIdentifier        - UUID - form identifiers.
//    * PseudoFileSystem     - Map - emulation of file system - for string (directory) returns
//                                                 the array of strings (subdirectories and files).
//    * AddedFiles          - Array - Added files output parameter.
//    * AllFoldersArray           - Array - All folders array.
//    * ImportMode             - Boolean - Import mode (from background job FilesImport).
//    * Encoding                 - String - encoding for text files.
//
Procedure FilesImportRecursively(Owner, SelectedFiles, ExecuteParameters)
	
	OfficeParameters = New Structure;
	For Each KeyAndValue IN ExecuteParameters Do
		OfficeParameters.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	OfficeParameters.ResultHandler = ExecuteParameters;
	OfficeParameters.Owner = Owner;
	OfficeParameters.SelectedFiles = SelectedFiles;
	
	OfficeParameters.Insert("FoldersArrayForQuestionFolderAlreadyExists", New Array);
	FilesImportRecursivelyWithoutDialogs(OfficeParameters.Owner, OfficeParameters.SelectedFiles, OfficeParameters, True); 
	If OfficeParameters.FoldersArrayForQuestionFolderAlreadyExists.Count() = 0 Then
		// Not required to ask the question.
		ReturnResult(OfficeParameters.ResultHandler, Undefined);
		Return;
	EndIf;
	
	// With the answers to questions from ExecuteParameters folder.FoldersArrayForQuestionFolderAlreadyExists 
	// is written in ExecuteParameters.SelectedFiles.
	// Then the recursion is restarted.
	OfficeParameters.SelectedFiles = New Array;
	OfficeParameters.Insert("FolderForAddingToSelectedFiles", Undefined);
	FilesImportRecursivelyAskNextQuestion(OfficeParameters);
	
EndProcedure

// Procedure continued (see above).
Procedure FilesImportRecursivelyAskNextQuestion(ExecuteParameters)
	
	ExecuteParameters.ResultHandler = PrepareHandlerForDialog(ExecuteParameters.ResultHandler);
	ExecuteParameters.FolderForAddingToSelectedFiles = ExecuteParameters.FoldersArrayForQuestionFolderAlreadyExists[0];
	ExecuteParameters.FoldersArrayForQuestionFolderAlreadyExists.Delete(0);
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Folder ""% 1"" already exists.
		|Continue folder import?';ru='Папка ""%1"" уже существует.
		|Продолжить импорт папки?'"),
		ExecuteParameters.FolderForAddingToSelectedFiles.Name);
	
	Handler = New NotifyDescription("FilesImportRecursivelyAfterAnswerToQuestion", ThisObject, ExecuteParameters);
	
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

// Procedure continued (see above).
Procedure FilesImportRecursivelyAfterAnswerToQuestion(Response, ExecuteParameters) Export
	
	If Response <> DialogReturnCode.No Then
		ExecuteParameters.SelectedFiles.Add(ExecuteParameters.FolderForAddingToSelectedFiles);
	EndIf;
	
	// After answers to all questions the recursion restarts.
	If ExecuteParameters.FoldersArrayForQuestionFolderAlreadyExists.Count() = 0 Then
		FilesImportRecursivelyWithoutDialogs(ExecuteParameters.Owner,	ExecuteParameters.SelectedFiles, ExecuteParameters,
			False); // AskQuestionFolderAlreadyExists (used only for first level recursion).
		
		If ExecuteParameters.FoldersArrayForQuestionFolderAlreadyExists.Count() = 0 Then
			// No more questions arose.
			ReturnResult(ExecuteParameters.ResultHandler, Undefined);
			Return;
		Else
			// More questions occurred.
			ExecuteParameters.SelectedFiles = New Array;
		EndIf;
	EndIf;
	
	FilesImportRecursivelyAskNextQuestion(ExecuteParameters);
	
EndProcedure

// Recursive function of files import from disk - accepts array of files (or directories)
// - if a file, just add it if a directory - creates a group and recursively calls itself.
//
// Parameters:
//  Owner            - AnyRef - file owner.
//  SelectedFiles      - Array - array of objects File.
//  ExecuteParameters - Structure - see eponymous parameter in FilesImportRecursively.
//  AskQuestionFolderAlreadyExists - Boolean - True only for first level of recursion.
//
Procedure FilesImportRecursivelyWithoutDialogs(Val Owner, Val SelectedFiles, Val ExecuteParameters, Val AskQuestionFolderAlreadyExists)
	
	Var FirstFolderWithSameName;
	
	For Each SelectedFile IN SelectedFiles Do
		
		If Not SelectedFile.Exist() Then
			Record = New Structure;
			Record.Insert("FileName", SelectedFile.FullName);
			Record.Insert("Error", NStr("en='File is not present on disk.';ru='Файл отсутствует на диске.'"));
			ExecuteParameters.FilenamesWithErrorsArray.Add(Record);
			Continue;
		EndIf;
		
		Try
			
			If SelectedFile.Extension = ".lnk" Then
				SelectedFile = DenameLnkFile(SelectedFile);
			EndIf;
			
			If SelectedFile.IsDirectory() Then
				
				If ExecuteParameters.Recursively = True Then
					NewPath = String(SelectedFile.Path);
					NewPath = CommonUseClientServer.AddFinalPathSeparator(NewPath);
					NewPath = NewPath + String(SelectedFile.Name);
					FilesArray = FileFunctionsServiceClientServer.FindFilesPseudo(ExecuteParameters.PseudoFileSystem, NewPath);
					
					// Creating a group in the catalog - folder equivalent on disk.
					If FilesArray.Count() <> 0 Then
						FileName = SelectedFile.Name;
						
						FolderAlreadyFound = False;
						
						If FileOperationsServiceServerCall.IsFolderWithSuchName(FileName, Owner, FirstFolderWithSameName) Then
							
							If ExecuteParameters.ImportMode Then
								FolderAlreadyFound = True;
								FilesFolderRef = FirstFolderWithSameName;
							Else
								If AskQuestionFolderAlreadyExists Then
									ExecuteParameters.FoldersArrayForQuestionFolderAlreadyExists.Add(SelectedFile);
									Continue;
								EndIf;
							EndIf;
						EndIf;
						
						If Not FolderAlreadyFound Then
							FilesFolderRef = FileOperationsServiceServerCall.CatalogsFoldersCreateItem(FileName, Owner);
						EndIf;
						
						// Parameter AskQuestionFolderAlreadyExists is necessary in order not to ask the
						// question on 1 level of recursion when the folders for which positive answer is already received are bypassed.
						FilesImportRecursivelyWithoutDialogs(FilesFolderRef, FilesArray, ExecuteParameters, True); 
						ExecuteParameters.AllFoldersArray.Add(NewPath);
					EndIf;
				EndIf;
				
				Continue;
			EndIf;
			
			If Not FileFunctionsServiceClientServer.CheckFileImportingPossibility(
			          SelectedFile, False, ExecuteParameters.FilenamesWithErrorsArray) Then
				Continue;
			EndIf;
			
			// Update progress bar.
			ExecuteParameters.Counter = ExecuteParameters.Counter + 1;
			// Calculate interest
			ExecuteParameters.ProgressBar = ExecuteParameters.Counter * 100 / ExecuteParameters.QuantitySummary;
			SizeInMB = SelectedFile.Size() / (1024 * 1024);
			LabelMore = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='IsProcessed file ""%1"" (%2 MB)...';ru='IsProcessed file ""%1"" (%2 MB)...'"),
				SelectedFile.Name, 
				FileFunctionsServiceClientServer.GetStringWithFileSize(SizeInMB));
				
			StatusText = NStr("en='Importing files from disk...';ru='Импорт файлов с диска...'");
			If ExecuteParameters.ImportMode Then
				StatusText = NStr("en='Importing files from disk...';ru='Импорт файлов с диска...'");
			EndIf;
			
			Status(StatusText,
				ExecuteParameters.ProgressBar,
				LabelMore,
				PictureLib.Information32);
			
			// Creating Catalog item Files.
			BaseName = SelectedFile.BaseName;
			Extension = SelectedFile.Extension;
			
			If ExecuteParameters.ImportMode Then
				If FileOperationsServiceServerCall.IsFileWithSuchName(BaseName, Owner) Then
					Record = New Structure;
					Record.Insert("FileName", SelectedFile.FullName);
					Record.Insert("Error", NStr("en='A file with this name already exists in the file storage.';ru='Файл с таким именем уже есть в хранилище файлов.'"));
					ExecuteParameters.FilenamesWithErrorsArray.Add(Record);
					Continue;
				EndIf;
			EndIf;
			
			FileTemporaryStorageAddress = "";
			
			FilesToPlace = New Array;
			Definition = New TransferableFileDescription(SelectedFile.FullName, "");
			FilesToPlace.Add(Definition);
			
			PlacedFiles = New Array;
			
			If Not PutFiles(FilesToPlace, PlacedFiles, , False, ExecuteParameters.FormID) Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Error when
		|placing
		|file ""%1"" into temporary storage.';ru='Ошибка
		|помещения
		|файла ""%1"" во временное хранилище.'"),
					SelectedFile.FullName);
			EndIf;
			
			If PlacedFiles.Count() = 1 Then
				FileTemporaryStorageAddress = PlacedFiles[0].Location;
			EndIf;
			
			If Not FileFunctionsServiceClientServer.FileOperationsCommonSettings().ExtractFileTextsAtServer Then
				TextTemporaryStorageAddress =
					FileFunctionsServiceClientServer.ExtractTextToTemporaryStorage(
						SelectedFile.FullName, ExecuteParameters.FormID, , ExecuteParameters.Encoding);
			Else
				TextTemporaryStorageAddress = "";
			EndIf;
			
			// Creating catalog item Files.
			ImportFile(SelectedFile, Owner, ExecuteParameters, FileTemporaryStorageAddress, TextTemporaryStorageAddress);
				
		Except
			ErrorInfo = ErrorInfo();
			
			ErrorInfo = BriefErrorDescription(ErrorInfo);
			CommonUseClientServer.MessageToUser(ErrorInfo);
			EventLogMonitorClient.AddMessageForEventLogMonitor(FileOperationsClientServer.EventLogMonitorEvent(),
				"Error", DetailErrorDescription(ErrorInfo),,True);
			
			Record = New Structure;
			Record.Insert("FileName", SelectedFile.FullName);
			Record.Insert("Error", ErrorInfo);
			ExecuteParameters.FilenamesWithErrorsArray.Add(Record);
			
		EndTry;
	EndDo;
	
EndProcedure

Procedure ImportFile(Val SelectedFile, Val Owner, Val ExecuteParameters, Val FileTemporaryStorageAddress, Val TextTemporaryStorageAddress) 
	
	FileInformation = FileOperationsClientServer.FileInformation("FileWithVersion", SelectedFile);
	FileInformation.FileTemporaryStorageAddress = FileTemporaryStorageAddress;
	FileInformation.TextTemporaryStorageAddress = TextTemporaryStorageAddress;
	FileInformation.Comment = ExecuteParameters.Comment;
	FileInformation.Encoding = ExecuteParameters.Encoding;

	FileRef = FileOperationsServiceServerCall.CreateFileWithVersion(Owner, FileInformation);
	
	DeleteFromTempStorage(FileTemporaryStorageAddress);
	If Not IsBlankString(TextTemporaryStorageAddress) Then
		DeleteFromTempStorage(TextTemporaryStorageAddress);
	EndIf;
	
	AddedFileAndPath = New Structure("FileRef, Path", FileRef, SelectedFile.Path);	
	ExecuteParameters.AddedFiles.Add(AddedFileAndPath);
	
	Record = New Structure;
	Record.Insert("FileName", SelectedFile.FullName);
	Record.Insert("File", FileRef);
	ExecuteParameters.AllFilesStructuresArray.Add(Record);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other service procedures and functions.

// When renamed, File and FileVersion update
// the information in working directory (name of file on disk and in register).
//
// Parameters:
//  CurrentVersion  - CatalogRef.FileVersions - file version.
//  NewName       - String - New attachment file name.
//
Procedure UpdateInformationInWorkingDirectory(CurrentVersion, NewName) Export
	
	DirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	FullFileName = "";
	
	InWorkingDirectoryForRead = True;
	InOwnerWorkingDirectory = False;
	
	FileInWorkingDirectory = FileIsInFilesLocalCache(
		Undefined,
		CurrentVersion,
		FullFileName,
		InWorkingDirectoryForRead,
		InOwnerWorkingDirectory);
	
	If FileInWorkingDirectory = False Then
		Return;
	EndIf;
	
	File = New File(FullFileName);
	NameOnly = File.Name;
	FileSize = File.Size();
	PathWithoutName = Left(FullFileName, StrLen(FullFileName) - StrLen(NameOnly));
	NewFullName = PathWithoutName + NewName + File.Extension;
	MoveFile(FullFileName, NewFullName);
	
	FileOperationsServiceServerCall.DeleteFromRegister(CurrentVersion);
	FileOperationsServiceServerCall.AddFileInformationToRegister(CurrentVersion,
		NewFullName, DirectoryName, InWorkingDirectoryForRead, FileSize, InOwnerWorkingDirectory);
	
EndProcedure

// Reregister IN working directory with another flag ForRead - if there is such File.
// Parameters:
//  FileData  - structure with file data.
//  ForRead - Boolean - File is placed for reading.
//  InOwnerWorkingDirectory - Boolean - file in the owner working directory (not in the home working directory).
Procedure ReregisterFileInWorkingDirectory(FileData, ForRead, InOwnerWorkingDirectory)
	
	// If File without file - do not do anything in working directory.
	If FileData.Version.IsEmpty() Then 
		Return;
	EndIf;

	DirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	FullFileName = "";
	
	InWorkingDirectoryForRead = True;
	FileInWorkingDirectory = FileIsInFilesLocalCache(FileData, FileData.CurrentVersion, FullFileName, InWorkingDirectoryForRead, InOwnerWorkingDirectory);
	If FileInWorkingDirectory = False Then
		Return;
	EndIf;
	
	FileOperationsServiceServerCall.AddFileInformationToRegister(FileData.CurrentVersion, FullFileName, DirectoryName, ForRead, 0, InOwnerWorkingDirectory);
	File = New File(FullFileName);
	File.SetReadOnly(ForRead);
	
EndProcedure

// Function is for opening the file with appropriate application.
//
// Parameters:
//  FileData  - structure with file data.
//  FileNameToOpen - String - full attachment file name.
Procedure OpenFileByApplication(FileData, FileNameToOpen, ResultHandler = Undefined) Export
	
	ExtensionAttached = FileFunctionsServiceClient.FileOperationsExtensionConnected();
	If ExtensionAttached Then
		
		PersonalFileOperationsSettings =
			FileFunctionsServiceClientServer.PersonalFileOperationsSettings();
		
		TextFilesOpeningMethod = PersonalFileOperationsSettings.TextFilesOpeningMethod;
		If TextFilesOpeningMethod = PredefinedValue("Enum.OpenFileForViewingVariants.InEmbeddedEditor") Then
			
			TextFilesExtension = PersonalFileOperationsSettings.TextFilesExtension;
			If FileFunctionsServiceClientServer.FileExtensionInList(TextFilesExtension, FileData.Extension) Then
				
				FormParameters = New Structure("File, FileData, OpenedFileName", 
					FileData.Ref, FileData, FileNameToOpen);
					
				OpenForm("Catalog.Files.Form.EditTextFile", 
					FormParameters, , FileData.FileCode);
				Return;
				
			EndIf;
			
		EndIf;
		
		If Lower(FileData.Extension) = Lower("grs") Then
			
			Schema = New GraphicalSchema; 
			Schema.Read(FileNameToOpen);
			
			TitleString = CommonUseClientServer.GetNameWithExtention(
				FileData.FullDescrOfVersion, FileData.Extension);
			
			Schema.Show(TitleString, FileNameToOpen);
			Return;
			
		EndIf;
		
		If Lower(FileData.Extension) = Lower("mxl") Then
			
			FilesToPlace = New Array;
			FilesToPlace.Add(New TransferableFileDescription(FileNameToOpen));
			PlacedFiles = New Array;
			If Not PutFiles(FilesToPlace, PlacedFiles, , False) Then
				Return;
			EndIf;
			SpreadsheetDocument = PlacedFiles[0].Location;
			
			TitleString = CommonUseClientServer.GetNameWithExtention(
				FileData.FullDescrOfVersion, FileData.Extension);
				
			OpenParameters = New Structure;
			OpenParameters.Insert("DocumentName", TitleString);
			OpenParameters.Insert("PathToFile", FileNameToOpen);
			OpenParameters.Insert("SpreadsheetDocument", SpreadsheetDocument);
			
			OpenForm("CommonForm.EditSpreadsheetDocument", OpenParameters);
			
			Return;
			
		EndIf;
		
		// Open file
		RunApp(FileNameToOpen);
	EndIf;
	
EndProcedure

// Transfers the file from one list of attached files to another.
// Parameters:
//  FileRef  - CatalogRef.Files - file.
//  FileOwner  - AnyRef - file owner.
Procedure MoveFileToAttachedFiles(FileRef, FileOwner) Export

	Result = FileOperationsServiceServerCall.GetDataForTransferToAttachedFiles(FileRef, FileOwner).Get(FileRef);
	
	If Result = "Copy" Then
		
		FileCreated = FileOperationsServiceServerCall.CopyFileInAttached(
			FileRef, FileOwner);
		
		Notify("Record_File", New Structure("Owner, File, Event", FileOwner, FileCreated, "FileCreated"));
		
		ShowUserNotification(
				"Creating:", 
				GetURL(FileCreated),
				String(FileCreated),
				PictureLib.Information32);
		
	ElsIf Result = "Refresh" Then
		
		UpdatedFile = FileOperationsServiceServerCall.RefreshFileInAttached(FileRef, FileOwner);
			
		ShowUserNotification(
				"Update:", 
				GetURL(UpdatedFile),
				String(UpdatedFile),
				PictureLib.Information32);
		
	EndIf;
	
EndProcedure

// Transfers files from one list of attached files to another.
// Parameters:
//  FilesArray - Array - file array.
//  FileOwner  - AnyRef - file owner.
Procedure MoveFilesToAttachedFiles(FilesArray, FileOwner) Export
	
	If FilesArray.Count() = 1 Then 
		MoveFileToAttachedFiles(FilesArray[0], FileOwner);
	Else
		
		Result = FileOperationsServiceServerCall.GetDataForTransferToAttachedFiles(FilesArray, FileOwner);
		
		ArrayRefresh = New Array;
		ArrayCopy = New Array;
		For Each FileRef IN FilesArray Do
			If Result.Get(FileRef) = "Copy" Then
				ArrayCopy.Add(FileRef);
			ElsIf Result.Get(FileRef) = "Refresh" Then
				ArrayRefresh.Add(FileRef);
			EndIf;
		EndDo;
		
		If ArrayCopy.Count() > 0 Then 
			FileOperationsServiceServerCall.CopyFileInAttached(
				ArrayCopy, FileOwner);
		EndIf;
		
		If ArrayRefresh.Count() > 0 Then 
			FileOperationsServiceServerCall.RefreshFileInAttached(ArrayRefresh, FileOwner);
		EndIf;
		
		CountTotal = ArrayCopy.Count() + ArrayRefresh.Count();
		If CountTotal > 0 Then 
			
			FullDetails = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Files (%1 pcs) are transferred to %2';ru='Файлы (%1 шт) перенесены в %2'"),
				CountTotal,
				FileOwner);
			
			ShowUserNotification(
				NStr("en='Files are moved';ru='Файлы перенесены'"),
				,
				FullDetails,
				PictureLib.Information32);
				
		EndIf;
			
	EndIf;
	
EndProcedure

// Returns the parameters for work with locked files.
// Returns:
// Undefined - if there are no editable files or it is not required to work with them.
// Structure - structure with passed parameters.
// 
Function CheckLockedFilesOnExit()
	
	If UsersClientServer.IsExternalUserSession() Then
		Return Undefined;
	EndIf;
	
	ShowLockedFilesOnExit =
		FileFunctionsServiceClientServer.PersonalFileOperationsSettings(
			).ShowLockedFilesOnExit;
	
	If Not ShowLockedFilesOnExit Then
		Return Undefined;
	EndIf;
	
	CurrentUser = UsersClientServer.CurrentUser();
	
	CountEmployedFiles = StandardSubsystemsClient.ClientWorkParametersOnComplete().FileOperations.CountEmployedFiles;
	If CountEmployedFiles = 0 Then
		Return Undefined;
	EndIf;
	
	ApplicationWarningFormParameters = New Structure;
	ApplicationWarningFormParameters.Insert("MessageQuestion",      NStr("en='Exit the application?';ru='Завершить работу с программой?'"));
	ApplicationWarningFormParameters.Insert("MessageTitle",   NStr("en='You have locked the following files for editing:';ru='Следующие файлы заняты вами для редактирования:'"));
	ApplicationWarningFormParameters.Insert("Title",            NStr("en='Exit';ru='Завершить'"));
	ApplicationWarningFormParameters.Insert("IsEditing",          CurrentUser);
	
	ApplicationWarningForm = "Catalog.Files.Form.ListOfLockedWithQuestion";
	Form                         = "Catalog.Files.Form.EditableFiles";
	
	ReturnParameters = New Structure;
	ReturnParameters.Insert("ApplicationWarningForm", ApplicationWarningForm);
	ReturnParameters.Insert("ApplicationWarningFormParameters", ApplicationWarningFormParameters);
	ReturnParameters.Insert("Form", Form);
	ReturnParameters.Insert("ApplicationWarningForm", ApplicationWarningForm);
	ReturnParameters.Insert("CountEmployedFiles", CountEmployedFiles);
	
	Return ReturnParameters;
	
EndFunction

// Recursive bypass of files in working directory and collection of information about them.
// Parameters:
//  Path - String - working directory path.
//  FilesArray - Array - array of objects "File".
//  FileTable - Array - array of files structures.
Procedure BypassFilesTable(Path, FilesArray, FileTable)
	
#If Not WebClient Then
	Var Version;
	Var DateSpaces;
	
	DirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	
	For Each SelectedFile IN FilesArray Do
		
		If SelectedFile.IsDirectory() Then
			NewPath = String(Path);
			NewPath = NewPath + CommonUseClientServer.PathSeparator();
			NewPath = NewPath + String(SelectedFile.Name);
			FileArrayInDirectory = FindFiles(NewPath, "*.*");
			
			If FileArrayInDirectory.Count() <> 0 Then
				BypassFilesTable(NewPath, FileArrayInDirectory, FileTable);
			EndIf;
		
			Continue;
		EndIf;
		
		// Do not delete temporary Word files from working directory.
		If Left(SelectedFile.Name, 1) = "~" AND SelectedFile.GetHidden() = True Then
			Continue;
		EndIf;
		
		RelativePath = Mid(SelectedFile.FullName, StrLen(DirectoryName) + 1);
		
		// If you don't find on disk - then minimum date will be the oldest - and it will be deleted from working directory during clearing of the oldest files.
		DateSpaces = Date('00010101');
		
		FoundProperties = FileOperationsServiceServerCall.FindInRegisterByPath(RelativePath);
		FileIsInRegister = FoundProperties.FileIsInRegister;
		Version            = FoundProperties.Version;
		DateSpaces     = ?(FileIsInRegister, FoundProperties.DateSpaces, DateSpaces);
		Owner          = FoundProperties.Owner;
		VersionNumber       = FoundProperties.VersionNumber;
		RegisterForRead = FoundProperties.RegisterForRead;
		InRegisterFileCode = FoundProperties.InRegisterFileCode;
		InFolder    = FoundProperties.InFolder;
		
		If FileIsInRegister Then
			CurrentUserIsEditing = FileOperationsServiceServerCall.GetCurrentUserIsEditing(Version);
			
			// If it is not locked by current user, you can delete it.
			If Not CurrentUserIsEditing Then
				Record = New Structure;
				Record.Insert("Path", RelativePath);
				Record.Insert("Size", SelectedFile.Size());
				Record.Insert("Version", Version);
				Record.Insert("PlacementDateIntoWorkingDirectory", DateSpaces);
				FileTable.Add(Record);
			EndIf;
		Else
			Record = New Structure;
			Record.Insert("Path", RelativePath);
			Record.Insert("Size", SelectedFile.Size());
			Record.Insert("Version", Version);
			Record.Insert("PlacementDateIntoWorkingDirectory", DateSpaces);
			FileTable.Add(Record);
		EndIf;
		
	EndDo;
#EndIf
	
EndProcedure

// Receives relative path to file in working directory - if any in information register - from
// there if not - generate - and write in information register.
//
// Parameters:
//  FileData  - structure with file data.
//
// Returns:
//   String  - file path
Function GetFilePathInWorkingDirectory(FileData)
	
	PathForReturn = "";
	FullFileName = "";
	DirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	
	// First try to find such record in information register.
	FullFileName = FileData.FullFileNameInWorkingDirectory;
	InWorkingDirectoryForRead = FileData.InWorkingDirectoryForRead;
	
	If FullFileName <> "" Then
		// You should check the existence on disk as well.
		FileOnDrive = New File(FullFileName);
		If FileOnDrive.Exist() Then
			Return FullFileName;
		EndIf;
	EndIf;
	
	// Generating attachment file name with extension.
	FileName = FileData.FullDescrOfVersion;
	Extension = FileData.Extension;
	If Not IsBlankString(Extension) Then 
		FileName = CommonUseClientServer.GetNameWithExtention(FileName, Extension);
	EndIf;
	
	FullFileName = "";
	If Not IsBlankString(FileName) Then
		If Not IsBlankString(FileData.OwnerWorkingDirectory) Then
			FullFileName = FileData.OwnerWorkingDirectory + FileData.FullDescrOfVersion + "." + FileData.Extension;
		Else
			FullFileName = FileFunctionsServiceClientServer.GetUniqueNameWithPath(DirectoryName, FileName);
		EndIf;
	EndIf;
	
	If IsBlankString(FileName) Then
		Return "";
	EndIf;
	
	// Write attachment file name to the register.
	ForRead = True;
	InOwnerWorkingDirectory = FileData.OwnerWorkingDirectory <> "";
	FileOperationsServiceServerCall.WriteFullFileNameToRegister(FileData.Version, FullFileName, ForRead, InOwnerWorkingDirectory);
	
	If FileData.OwnerWorkingDirectory = "" Then
		PathForReturn = DirectoryName + FullFileName;
	Else
		PathForReturn = FullFileName;
	EndIf;
	
	Return PathForReturn;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of SSL subsystems internal events.

// Defines the list of warnings to the user before the completion of the system work.
//
// Parameters:
//  Warnings - Array - you can add items of the
//                            Structure type to the array, for its properties, see  StandardSubsystemsClient.WarningOnWorkEnd.
//
Procedure OnGetListOfWarningsToCompleteJobs(Warnings) Export
	
	OnExit(Warnings);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and function for work with scanner.

// Initialization of scanning component.
Function InitializeComponent() Export
	
	If CommonUseClientServer.IsLinuxClient() Then
		Return False;
	EndIf;
	
	ParameterName = "StandardSubsystems.TwainAddIn";
	If ApplicationParameters[ParameterName] = Undefined Then
		ReturnCode = AttachAddIn("CommonTemplate.TWAINComponent", "twain", AddInType.Native);
		If Not ReturnCode Then
			Return False;
		EndIf;
		
		ApplicationParameters.Insert(ParameterName, New("AddIn.twain.AddInNativeExtension"));
	EndIf;
	
	Return True;
	
EndFunction

// Setting scanning component.
//
// Parameters:
//  ResultHandler - AlertDescription, Undefined - Description of the procedure that receives the result of method work.
//
// Returns:
//   Boolean - Whether the operation was completed successfully.
//
// See also:
//   Variable of TwainAddIn global context.
//
Procedure SetComponent(ResultHandler) Export
	
	If CommonUseClientServer.IsLinuxClient() Then
		ReturnResult(ResultHandler, False);
		Return;
	EndIf;
	
	If InitializeComponent() Then
		Status(NStr("en='Scan component already installed.';ru='Компонента сканирования уже установлена.'"));
		ReturnResult(ResultHandler, True);
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	Handler = New NotifyDescription("SetComponentEnd", ThisObject, ExecuteParameters);
	BeginInstallAddIn(Handler, "CommonTemplate.TWAINComponent");
	
EndProcedure

// Procedure continued (see above).
Procedure SetComponentEnd(ExecuteParameters) Export
	
	ComponentIsMounted = InitializeComponent();
	ReturnResult(ExecuteParameters.ResultHandler, ComponentIsMounted);
	
EndProcedure

// Returns scanning component version.
Function ScanComponentVersion() Export
	
	If Not InitializeComponent() Then
		Return NStr("en='Scan component is not installed';ru='Компонента сканирования не установлена'");
	EndIf;
	
	Return ApplicationParameters["StandardSubsystems.TwainAddIn"].Version();
	
EndFunction

// Returns the TWAIN devices (array of strings).
Function GetDevices() Export
	
	Array = New Array;
	
	If Not InitializeComponent() Then
		Return Array;
	EndIf;
	
	DevicesString = ApplicationParameters["StandardSubsystems.TwainAddIn"].GetDevices();
	
	For IndexOf = 1 To StrLineCount(DevicesString) Do
		String = StrGetLine(DevicesString, IndexOf);
		Array.Add(String);
	EndDo;
	
	Return Array;
	
EndFunction

// Checks whether scanning component is installed and if there is at least one scanner.
Function CommandScanAvailable() Export
	
	If CommonUseClientServer.IsLinuxClient() Then
		Return False;
	EndIf;
	
	If Not InitializeComponent() Then
		Return False;
	EndIf;
	
	If ApplicationParameters["StandardSubsystems.TwainAddIn"].AreDevices() Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// It returns scanner setting by name.
//
// Parameters:
//   DeviceName - String - Scanner name.
//   SettingName  - String - Name settings,
//       for example "XRESOLUTION", or "PIXELTYPE", or "ROTATION", or "SUPPORTEDSIZES".
//
// Returns:
//   Number - Scanner setting value.
//
Function GetSetting(DeviceName, SettingName) Export
	
	If CommonUseClientServer.IsLinuxClient() Then
		Return -1;
	EndIf;
	
	Try
		Return ApplicationParameters["StandardSubsystems.TwainAddIn"].GetSetting(DeviceName, SettingName);
	Except
		Return -1;
	EndTry;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

// Whether File for this version is located in working directory.
// Parameters:
//  FileData  - structure with file data.
//
// Returns:
//  Boolean  - file is located in working directory.
//  CurrentVersion  - CatalogRef.FileVersions - file version.
//  FullFileName - String - attachment file name with path.
//  InWorkingDirectoryForRead - Boolean - File is placed for reading.
//  InOwnerWorkingDirectory - Boolean - file in the owner working directory (not in the home working directory).
Function FileIsInFilesLocalCache(FileData, CurrentVersion, FullFileName, InWorkingDirectoryForRead, InOwnerWorkingDirectory)
	FullFileName = "";
	
	// If it is an active version - take from FileData.
	If FileData <> Undefined AND FileData.CurrentVersion = CurrentVersion Then
		FullFileName = FileData.FullFileNameInWorkingDirectory;
		InWorkingDirectoryForRead = FileData.InWorkingDirectoryForRead;
	Else
		InWorkingDirectoryForRead = True;
		DirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
		// Trying to find this record in information register.
		FullFileName = FileOperationsServiceServerCall.GetFullFileNameFromRegister(CurrentVersion, DirectoryName, InWorkingDirectoryForRead, InOwnerWorkingDirectory);
	EndIf;
	
	If FullFileName <> "" Then
		// You should check the existence on disk as well.
		FileOnDrive = New File(FullFileName);
		If FileOnDrive.Exist() Then
			Return True;
		Else
			FullFileName = "";
			// Immediately remove from the register - T.k. it exists in the register and absent on the disk.
			FileOperationsServiceServerCall.DeleteFromRegister(CurrentVersion);
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// Choose path to working directory.
// Parameters:
//  DirectoryName  - String - former name of the directory.
//  Title  - String - header of path directory selection form.
//  OwnerWorkingDirectory - String-  owner working directory.
//
// Returns:
//   Boolean  - whether the operation is successfully completed.
Function ChoosePathToWorkingDirectory(DirectoryName, Title, OwnerWorkingDirectory) Export
	
	Mode = FileDialogMode.ChooseDirectory;
	FileOpeningDialog = New FileDialog(Mode);
	FileOpeningDialog.FullFileName = "";
	FileOpeningDialog.Directory = DirectoryName;
	FileOpeningDialog.Multiselect = False;
	FileOpeningDialog.Title = Title;
	
	If FileOpeningDialog.Choose() Then
		
		DirectoryName = FileOpeningDialog.Directory;
		DirectoryName = CommonUseClientServer.AddFinalPathSeparator(DirectoryName);
		
		// Create the file directory
		Try
			CreateDirectory(DirectoryName);
			TestDirectoryName = DirectoryName + "CheckAccess\";
			CreateDirectory(TestDirectoryName);
			DeleteFiles(TestDirectoryName);
		Except
			// You are not authorized to create a directory or such path is absent.
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Incorrect path or insufficient rights to record
		|in directory ""%1"".';ru='Неверный путь или отсутствуют
		|права на запись в каталог ""%1"".'"),
				DirectoryName);
			ShowMessageBox(, ErrorText);
			Return False;
		EndTry;
		
		If OwnerWorkingDirectory = False Then
#If Not WebClient Then
			FileArrayInDirectory = FindFiles(DirectoryName, "*.*");
			If FileArrayInDirectory.Count() <> 0 Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='There are already
		|files
		|in selected work directory ""%1"".
		|
		|Choose other catalog.';ru='В выбранном
		|рабочем
		|каталоге ""%1"" уже есть файлы.
		|
		|Выберите другой каталог.'"),
					DirectoryName);
				ShowMessageBox(, ErrorText);
				Return False;
			EndIf;
#EndIf
		EndIf;
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Reregister IN working directory with another flag ForReading.
// Parameters:
//  CurrentVersion  - CatalogRef.FileVersions - file version.
//  FullFileName - String - full attachment file name.
//  ForRead - Boolean - File is placed for reading.
//  InOwnerWorkingDirectory - Boolean - file in the owner working directory (not in the home working directory).
Procedure ReregisterInWorkingDirectory(CurrentVersion, FullFileName, ForRead, InOwnerWorkingDirectory)
	
	DirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	
	FileOperationsServiceServerCall.AddFileInformationToRegister(CurrentVersion, FullFileName, DirectoryName, ForRead, 0, InOwnerWorkingDirectory);
	File = New File(FullFileName);
	File.SetReadOnly(ForRead);
	
EndProcedure

// Files Bypass recursive - for determining files size.
// Parameters:
//  FilesArray - Array - array of objects "File".
//  ArrayTooLargeFiles - Array - file array.
//  Recursively - Boolean - Recursively bypass subdirectories.
//  QuantitySummary - Number - Total quantity of imported files.
//  PseudoFileSystem - Map - emulation of file system - for string (directory) returns the
//                                         array of strings (subdirectories and files).
//
Procedure FindOversizedFiles(
				FilesArray,
				ArrayTooLargeFiles,
				Recursively,
				QuantitySummary,
				Val PseudoFileSystem) 
	
	MaxFileSize = FileFunctionsServiceClientServer.FileOperationsCommonSettings().MaximumFileSize;
	
	For Each SelectedFile IN FilesArray Do
		
		If SelectedFile.Exist() Then
			
			If SelectedFile.Extension = ".lnk" Then
				SelectedFile = DenameLnkFile(SelectedFile);
			EndIf;
			
			If SelectedFile.IsDirectory() Then
				
				If Recursively Then
					NewPath = String(SelectedFile.Path);
					NewPath = CommonUseClientServer.AddFinalPathSeparator(NewPath);
					NewPath = NewPath + String(SelectedFile.Name);
					FileArrayInDirectory = FileFunctionsServiceClientServer.FindFilesPseudo(PseudoFileSystem, NewPath);
					
					// Recursion
					If FileArrayInDirectory.Count() <> 0 Then
						FindOversizedFiles(FileArrayInDirectory, ArrayTooLargeFiles, Recursively, QuantitySummary, PseudoFileSystem);
					EndIf;
				EndIf;
			
				Continue;
			EndIf;
			
			QuantitySummary = QuantitySummary + 1;
			
			// The file size is too big.
			If SelectedFile.Size() > MaxFileSize Then
				ArrayTooLargeFiles.Add(SelectedFile.FullName);
				Continue;
			EndIf;
		
		EndIf;
	EndDo;
	
EndProcedure

// Dereference
// lnk file Parameters:
//  SelectedFile - File - object of File type.
//
// Returns:
//   String - on what lnk file refers.
Function DenameLnkFile(SelectedFile) Export
	
#If Not WebClient Then
	If Not StandardSubsystemsClientReUse.ClientWorkParameters().ThisIsBasicConfigurationVersion Then
		ShellApp = New COMObject("shell.application");
		FolderObj = ShellApp.NameSpace(SelectedFile.Path);// Full (only) path to lnk file.
		ObjFolderItem = FolderObj.items().item(SelectedFile.Name); 	// only lnk attachment file name
		Link = ObjFolderItem.GetLink();
		Return New File(Link.path);
	EndIf;
#EndIf
	
	Return SelectedFile;
	
EndFunction

// Function is for opening the file with appropriate application.
//
// Parameters:
//  FileNameToOpen - String - full attachment file name.
Procedure RunApplicationStart(FileNameToOpen) Export
	
	ExtensionAttached = FileFunctionsServiceClient.FileOperationsExtensionConnected();
	If ExtensionAttached Then
		// Open file
		SystemInfo = New SystemInfo;
		If SystemInfo.PlatformType = PlatformType.Windows_x86 Or SystemInfo.PlatformType = PlatformType.Windows_x86_64 Then
			FileNameToOpen = StrReplace(FileNameToOpen, "/", "\");
		EndIf;
		
		RunApp(FileNameToOpen);
	EndIf;
	
EndProcedure

// Compares 2 files (txt doc doc odt) using MS Office or OpenOffice.
Procedure CompareFiles(File1Path, File2Path, FileVersionComparisonMethod) Export
	
	Try
		If FileVersionComparisonMethod = "MicrosoftOfficeWord" Then
			ObjectWord = New COMObject("Word.Application");
			ObjectWord.Visible = 0;
			
			Document = ObjectWord.Documents.Open(File1Path);
			
			Document.Merge(File2Path, 0, 0, 0); // MergeTarget:=wdMergeTargetSelected, DetectFormatChanges:=False, UseFormattingFrom:=wdFormattingFromCurrent
			
			ObjectWord.Visible = 1;
			ObjectWord.Activate(); 	
			
			Document.Close();
		ElsIf FileVersionComparisonMethod = "OpenOfficeOrgWriter" Then 
			
			// Remove readonly - otherwise, it will not work.
			File1 = New File(File1Path);
			File1.SetReadOnly(False);
			
			File2 = New File(File2Path);
			File2.SetReadOnly(False);
			
			// Open OpenOffice
			ServiceManager = New COMObject("com.sun.star.ServiceManager");
			Reflection = ServiceManager.CreateInstance("com.sun.star.reflection.CoreReflection");
			Desktop = ServiceManager.CreateInstance("com.sun.star.frame.Desktop");
			Dispatcher = ServiceManager.CreateInstance("com.sun.star.frame.DispatchHelper");
			
			// Open document OpenOffice.
			Args = New COMSafeArray("VT_DISPATCH", 1);
			OODocument = Desktop.loadComponentFromURL(ConvertToURL(File2Path), "_blank", 0, Args);
			
			frame = Desktop.getCurrentFrame();
			
			// set changes display
			ComparisonParameters = New COMSafeArray("VT_VARIANT", 1);
			ComparisonParameters.SetValue(0, AssignValueToProperty(ServiceManager, "ShowTrackedChanges", True));
			dispatcher.executeDispatch(frame, ".uno:ShowTrackedChanges", "", 0, ComparisonParameters);
			
			// compare with document
			CallParameters = New COMSafeArray("VT_VARIANT", 1);
			CallParameters.SetValue(0, AssignValueToProperty(ServiceManager, "URL", ConvertToURL(File1Path)));
			dispatcher.executeDispatch(frame, ".uno:CompareDocuments", "", 0, CallParameters);
			
			OODocument = Undefined;
		EndIf;
		
	Except
		CommonUseClientServer.MessageToUser(
			BriefErrorDescription(ErrorInfo() ));
	EndTry;
	
EndProcedure

// Function converts Windows attachment file name in URL OpenOffice.
Function ConvertToURL(FileName)
	
	Return "file:///" + StrReplace(FileName, "\", "/");
	
EndFunction

// Creating the structure for OpenOffice parameters.
Function AssignValueToProperty(Object, PropertyName, PropertyValue)
	
	Properties = Object.Bridge_GetStruct("com.sun.star.beans.PropertyValue");
	Properties.Name = PropertyName;
	Properties.Value = PropertyValue;
	
	Return Properties;
	
EndFunction

// Returns user data directory inside standard directory of application data.
// This directory can be used for storage of files captured by current user.
// For the method to work on web client the extension for work with files shall be enabled beforehand.
//
Function DirectoryDataUser()
	
	#If WebClient Then
		Return UserDataWorkDir();
	#Else
		If CommonUseClientServer.IsLinuxClient() Then
			Return UserDataWorkDir();
		Else
			Shell = New COMObject("WScript.Shell");
			DirectoryDataUser = Shell.ExpandEnvironmentStrings("%APPDATA%");
			Return CommonUseClientServer.AddFinalPathSeparator(DirectoryDataUser);
		EndIf;
	#EndIf
	
EndFunction

// Opens drag and drop form.
Procedure OpenFormDragFromOutside(FolderForAdding, FileNameArray) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("FolderForAdding", FolderForAdding);
	FormParameters.Insert("FileNameArray",   FileNameArray);
	
	OpenForm("Catalog.Files.Form.DragForm", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Service procedures and functions for asynchronous methods.
//
// Common description of parameters:
//   Handler - NotifyDescription, Undefined, Structure - Procedure-handler of asynchronous method.
//       * Undefined       - No processing is required.
//       * AlertDescription - Description of procedure-handler.
//     IN rare cases it may be required to interrupt
//     code execution only when asynchronous dialog shall be displayed (for example, in cycles).
//     IN such cases Structure of calling code parameters is
//     passed to Handler with
//     mandatory key AsynchronousDialog that is used when the code is interrupted and asynchronous dialog is opened:
//       * Structure - Structure of calling code parameters.
//           ** AsynchronousDialog - Structure - 
//               *** Open       - Boolean - True if dialog was open.
//               *** ProcedureName - String - Name procedure handler calling code.
//               *** Module       - CommonModule, ManagedForm - Module of calling code handler.
//             IN this case NotificationDescription is formed from keys "ProcedureName" and "Module".
//             Attention. Not all asynchronous procedures support the transfer of Structure type. Read types content.
//
//   Result - Arbitrary - Result to be returned to Handler.
//

// Shows a warning dialog, once it is closed, calls a handler with the set result.
Procedure ReturnResultAfterShowWarning(Handler, WarningText, Result) Export
	
	If Handler <> Undefined Then
		HandlerParameters = New Structure;
		HandlerParameters.Insert("Handler", PrepareHandlerForDialog(Handler));
		HandlerParameters.Insert("Result", Result);
		Handler = New NotifyDescription("ReturnResultAfterSimpleDialogClosing", ThisObject, HandlerParameters);
		ShowMessageBox(Handler, WarningText);
	Else
		ShowMessageBox(, WarningText);
	EndIf;
	
EndProcedure

// Shows the window to view the value and after closing it calls the handler with set result.
Procedure ReturnResultAfterDisplayValues(Handler, Value, Result) Export
	
	If Handler <> Undefined Then
		HandlerParameters = New Structure;
		HandlerParameters.Insert("Handler", PrepareHandlerForDialog(Handler));
		HandlerParameters.Insert("Result", Result);
		Handler = New NotifyDescription("ReturnResultAfterSimpleDialogClosing", ThisObject, HandlerParameters);
		ShowValue(Handler, Value);
	Else
		ShowValue(, Value);
	EndIf;
	
EndProcedure

// Procedure continued (see above).
Procedure ReturnResultAfterSimpleDialogClosing(Structure) Export
	
	If TypeOf(Structure.Handler) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(Structure.Handler, Structure.Result);
	EndIf;
	
EndProcedure

// Returns the result of direct call when there were no open dialogs.
Procedure ReturnResult(Handler, Result) Export
	
	Handler = PrepareHandlerForDirectCall(Handler, Result);
	If TypeOf(Handler) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(Handler, Result);
	EndIf;
	
EndProcedure

// Writes the information required for the preparation of asynchronous dialog handler.
Procedure RegisterHandlerDescription(ExecuteParameters, Module, ProcedureName) Export
	
	ExecuteParameters.Insert("AsynchronousDialog", New Structure);
	ExecuteParameters.AsynchronousDialog.Insert("Module",                 Module);
	ExecuteParameters.AsynchronousDialog.Insert("ProcedureName",           ProcedureName);
	ExecuteParameters.AsynchronousDialog.Insert("Open",                 False);
	ExecuteParameters.AsynchronousDialog.Insert("ResultWhenNotOpen", Undefined);
	
EndProcedure

// Asynchronous dialog handler preparation.
Function PrepareHandlerForDialog(HandlerOrStructure) Export
	
	If TypeOf(HandlerOrStructure) = Type("Structure") Then
		// Recursive registration of all calling code handlers.
		If HandlerOrStructure.Property("ResultHandler") Then
			HandlerOrStructure.ResultHandler = PrepareHandlerForDialog(HandlerOrStructure.ResultHandler);
		EndIf;
		If HandlerOrStructure.Property("AsynchronousDialog") Then
			// Open dialog registration.
			HandlerOrStructure.AsynchronousDialog.Open = True;
			// Creation of handler (during this the whole parameters structure is being fixed).
			Handler = New NotifyDescription(
				HandlerOrStructure.AsynchronousDialog.ProcedureName,
				HandlerOrStructure.AsynchronousDialog.Module,
				HandlerOrStructure);
		Else
			Handler = Undefined;
		EndIf;
	Else
		Handler = HandlerOrStructure;
	EndIf;
	
	Return Handler;
	
EndFunction

// Preparing direct call handler without opening the dialog.
Function PrepareHandlerForDirectCall(HandlerOrStructure, Result) Export
	
	If TypeOf(HandlerOrStructure) = Type("Structure") Then
		If HandlerOrStructure.Property("AsynchronousDialog") Then
			HandlerOrStructure.AsynchronousDialog.ResultWhenNotOpen = Result;
		EndIf;
		Return Undefined; // Handler was not prepared for dialog = > Calling code did not stop.
	Else
		Return HandlerOrStructure;
	EndIf;
	
EndFunction

// Sets the handler of form closing received with the use of GetForm().
Procedure SetFormAlert(Form, Handler) Export
	
	If Handler <> Undefined Then
		// Setting the form closing handler.
		Form.OnCloseNotifyDescription = Handler;
		// A form returning the value should:
		If Form.FormOwner = Undefined Then
			// Without set owner - lock whole interface.
			Form.WindowOpeningMode = FormWindowOpeningMode.LockWholeInterface;
		Else
			// With specified owner - block owner window or entire interface.
			If Form.WindowOpeningMode = FormWindowOpeningMode.Independent Then
				Form.WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
