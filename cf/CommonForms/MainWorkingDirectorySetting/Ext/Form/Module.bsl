
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If CommonUseClientServer.ThisIsWebClient() Then
		Items.NowAtLocalFilesCache.Visible = False;
		Items.ClearWorkingDirectory.Visible = False;
	EndIf;
	
	FillParametersAtServer();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		AttachIdleHandler("ShowWarningAboutNeedToFileOperationsExpansion", 0.1, True);
		Cancel = True;
		Return;
	EndIf;
	
	UserWorkingDirectory = FileFunctionsServiceClient.UserWorkingDirectory();
	
	RefreshCurrentStateBusinessDirectory();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure UserWorkingDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		Return;
	EndIf;
	
	// Choose another path to the working directory.
	DirectoryName = UserWorkingDirectory;
	Title = NStr("en='Select the main work directory';ru='Выберите основной рабочий каталог'");
	If Not FileOperationsServiceClient.ChoosePathToWorkingDirectory(DirectoryName, Title, False) Then
		Return;
	EndIf;
	
	SetNewWorkingDirectory(DirectoryName);
	
EndProcedure

&AtClient
Procedure LocalFilesCacheMaximumSizeOnChange(Item)
	
	SaveParameters();
	
EndProcedure

&AtClient
Procedure ConfirmWhenDeletingFilesFormLocalCacheOnChange(Item)
	
	SaveParameters();
	
EndProcedure

&AtClient
Procedure DeleteFileFromFilesLocalCacheOnEditEndOnChange(Item)
	
	SaveParameters();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ShowWarningAboutNeedToFileOperationsExpansion()
	
	FileFunctionsServiceClient.ShowWarningAboutNeedToFileOperationsExpansion(Undefined);
	
EndProcedure

&AtClient
Procedure FileListExecute()
	
	OpenForm("Catalog.Files.Form.FilesInMainWorkingDirectory", , ThisObject,,,,
		New NotifyDescription("FileListClosing", ThisObject));
	
EndProcedure

&AtClient
Procedure ClearLocalFilesCache(Command)
	
	QuestionText =
		NStr("en='From the main working directory all files
		|will be deleted, except those borrowed by you for editing.
		|
		|Continue?';ru='Из основного рабочего каталога будут удалены все файлы,
		|кроме занятых вами для редактирования.
		|
		|Продолжить?'");
	Handler = New NotifyDescription("ClearLocalFilesCacheAfterAnswerQuestionToContinue", ThisObject);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure PathToWorkingDirectoryByDefault(Command)
	
	SetNewWorkingDirectory(FileFunctionsServiceClient.SelectPathToUserDataDirectory());
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SaveParameters()
	
	StructuresArray = New Array;
	
	Item = New Structure;
	Item.Insert("Object",    "LocalFilesCache");
	Item.Insert("Setting", "PathToFilesLocalCache");
	Item.Insert("Value",  UserWorkingDirectory);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "LocalFilesCache");
	Item.Insert("Setting", "LocalFilesCacheMaximumSize");
	Item.Insert("Value", LocalFilesCacheMaximumSize * 1048576);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "LocalFilesCache");
	Item.Insert("Setting", "DeleteFileFromFilesLocalCacheOnEditEnd");
	Item.Insert("Value", DeleteFileFromFilesLocalCacheOnEditEnd);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "LocalFilesCache");
	Item.Insert("Setting", "ConfirmWhenDeletingFromLocalFilesCache");
	Item.Insert("Value", ConfirmWhenDeletingFromLocalFilesCache);
	StructuresArray.Add(Item);
	
	CommonUseServerCall.CommonSettingsStorageSaveArrayAndUpdateReUseValues(
		StructuresArray);
	
EndProcedure

&AtClient
Procedure ClearLocalFilesCacheAfterAnswerQuestionToContinue(Response, ExecuteParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Status(NStr("en='Main working directory is being cleared...
		|Please, wait.';ru='Выполняется очистка основного рабочего каталога...
		|Пожалуйста, подождите.'"));
	
	Handler = New NotifyDescription("ClearLocalFilesCacheEnd", ThisObject);
	// ClearAll = True.
	FileOperationsServiceClient.ClearWorkingDirectory(Handler, FilesSizeInWorkingDirectory, 0, True);
	
EndProcedure

&AtClient
Procedure ClearLocalFilesCacheEnd(Result, ExecuteParameters) Export
	
	RefreshCurrentStateBusinessDirectory();
	
	Status(NStr("en='Main working directory has been cleared successfully.';ru='Очистка основного рабочего каталога успешно завершена.'"));
	
EndProcedure

&AtClient
Procedure FileListClosing(Result, AdditionalParameters) Export
	
	RefreshCurrentStateBusinessDirectory();
	
EndProcedure

&AtServer
Procedure FillParametersAtServer()
	
	DeleteFileFromFilesLocalCacheOnEditEnd = CommonUse.CommonSettingsStorageImport(
		"LocalFilesCache", "DeleteFileFromFilesLocalCacheOnEditEnd");
	
	If DeleteFileFromFilesLocalCacheOnEditEnd = Undefined Then
		DeleteFileFromFilesLocalCacheOnEditEnd = False;
	EndIf;
	
	ConfirmWhenDeletingFromLocalFilesCache = CommonUse.CommonSettingsStorageImport(
		"LocalFilesCache", "ConfirmWhenDeletingFromLocalFilesCache");
	
	If ConfirmWhenDeletingFromLocalFilesCache = Undefined Then
		ConfirmWhenDeletingFromLocalFilesCache = False;
	EndIf;
	
	MaxSize = CommonUse.CommonSettingsStorageImport(
		"LocalFilesCache", "LocalFilesCacheMaximumSize");
	
	If MaxSize = Undefined Then
		MaxSize = 100*1024*1024; // 100 mb
		CommonUse.CommonSettingsStorageSave(
			"LocalFilesCache", "LocalFilesCacheMaximumSize", MaxSize);
	EndIf;
	LocalFilesCacheMaximumSize = MaxSize / 1048576;

EndProcedure

&AtClient
Procedure RefreshCurrentStateBusinessDirectory()
	
#If Not WebClient Then
	FilesArray = FindFiles(UserWorkingDirectory, "*.*");
	FilesSizeInWorkingDirectory = 0;
	QuantitySummary = 0;
	
	FileFunctionsServiceClient.BypassFilesSize(
		UserWorkingDirectory,
		FilesArray,
		FilesSizeInWorkingDirectory,
		QuantitySummary); 
	
	FilesSizeInWorkingDirectory = FilesSizeInWorkingDirectory / 1048576;
#EndIf
	
EndProcedure

&AtClient
Procedure SetNewWorkingDirectory(NewDirectory)
	
	If NewDirectory = UserWorkingDirectory Then
		Return;
	EndIf;
	
#If Not WebClient Then
	Handler = New NotifyDescription(
		"SetNewWorkingDirectoryEnd", ThisObject, NewDirectory);
	
	FileOperationsServiceClient.TransferWorkingDirectoryContents(
		Handler, UserWorkingDirectory, NewDirectory);
#Else
	SetNewWorkingDirectoryEnd(-1, NewDirectory);
#EndIf
	
EndProcedure

&AtClient
Procedure SetNewWorkingDirectoryEnd(Result, NewDirectory) Export
	
	If Result <> -1 Then
		If Result <> True Then
			Return;
		EndIf;
	EndIf;
	
	UserWorkingDirectory = NewDirectory;
	
	SaveParameters();
	
EndProcedure

#EndRegion














