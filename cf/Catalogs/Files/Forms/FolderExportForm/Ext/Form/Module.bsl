
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.ExportFolder <> Undefined Then
		WhatSaving = Parameters.ExportFolder;
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureClientServer =
			CommonUse.CommonModule("DigitalSignatureClientServer");
		
		ExtensionForEncryptedFiles = ModuleDigitalSignatureClientServer.PersonalSettings(
			).ExtensionForEncryptedFiles;
	Else
		ExtensionForEncryptedFiles = "p7m";
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	#If WebClient Then
		ShowMessageBox(, NStr("en='Folder export is not supported in Web-client.';ru='В Веб-клиенте экспорт каталогов не поддерживается.'"));
		Cancel = True;
		Return;
	#EndIf
	
	// Set a folder used for
	// exporting last time as export folder "My documents".
	ExportDirectory = FileFunctionsServiceClient.ExportDirectory();
	
	FullExportPath = ExportDirectory
	                       + String(WhatSaving)
	                       + CommonUseClientServer.PathSeparator();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure FolderForExportOpen(Item, StandardProcessing)
	#If WebClient Then
		Return;
	#EndIf
	
	// Open the folder read-only - if any action is required.
	StandardProcessing = False;
	If Not IsBlankString(ExportDirectory) Then
		File = New File(ExportDirectory);
		If Not File.Exist() Then
			WarningText = NStr("en='Cannot open the export folder.
		|Perhaps, the folder is not created yet.';ru='Невозможно открыть папку выгрузки.
		|Возможно, папка еще не создана.'");
			ShowMessageBox(, WarningText);
			Return;
		EndIf;
		RunApp(ExportDirectory);
	EndIf;
	
EndProcedure

&AtClient
Procedure FolderForExportOnChange(Item)
	
	ExportDirectory = FileFunctionsServiceClient.NormalizeDirectory(
		ExportDirectory);
	
	FullExportPath = FileFunctionsServiceClient.NormalizeDirectory(
		FullExportPath);
	
EndProcedure

&AtClient
Procedure FolderForExportStartChoice(Item, ChoiceData, StandardProcessing)
	#If WebClient Then
		Return;
	#EndIf
	
	// Open a dialog box to select a folder to save.
	StandardProcessing = False;
	FileChoice = New FileDialog(FileDialogMode.ChooseDirectory);
	FileChoice.Multiselect = False;
	FileChoice.Directory = ExportDirectory;
	If FileChoice.Choose() Then
		
		ExportDirectory = FileFunctionsServiceClient.NormalizeDirectory(
			FileChoice.Directory);
		
		FullExportPath = ExportDirectory
		                       + String(WhatSaving)
		                       + CommonUseClientServer.PathSeparator();
		
	EndIf;

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SaveFolder()
	#If WebClient Then
		Return;
	#EndIf
	
	// Check - the export directory exists? if no - create.
	ExportDirectory = New File(FullExportPath);
	
	If Not ExportDirectory.Exist() Then
		
		ErrorText = "";
		Try
			CreateDirectory(FullExportPath);
		Except
			ErrorText = NStr("en='Cannot create a export folder:';ru='Не удалось создать папку выгрузки:'");
			ErrorText = ErrorText + Chars.LF + Chars.LF + DetailErrorDescription(ErrorInfo());
		EndTry;
		If ErrorText <> "" Then
			ShowMessageBox(, ErrorText);
			Return;
		EndIf;
		
	EndIf;
	
	Status(StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Folder ""%1"" is being exported...
		|Please, wait.';ru='Выполняется экспорт папки ""%1""...
		|Пожалуйста, подождите.'"),
		String(WhatSaving) ));
	
	// Get a list of exported files.
	GenerateFileTree(WhatSaving);
	
	// Start exporting
	Handler = New NotifyDescription("ExportEnd", ThisObject);
	BypassFileTree(Handler, FileTree, FullExportPath, WhatSaving, Undefined);
EndProcedure

&AtClient
Procedure ExportEnd(Result, ExecuteParameters) Export
	If Result.Success = True Then
		PathToSave = ExportDirectory;
		CommonUseServerCall.CommonSettingsStorageSave("ExportFolderName", "ExportFolderName",  PathToSave);
		
		Status(StringFunctionsClientServer.PlaceParametersIntoString(
		             NStr("en='Folder ""%1"" has been
		|successfully exported into a directory on disk ""%2"".';ru='Успешно завершен
		|экспорт папки ""%1"" в каталог на диске ""%2"".'"),
		             String(WhatSaving), String(ExportDirectory) ) );
		
		Close();
	EndIf;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure GenerateFileTree(FolderParent)
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	               |	Files.FileOwner AS Folder,
	               |	Files.FileOwner.Description AS FolderDescription,
	               |	Files.CurrentVersion,
	               |	Files.FullDescr AS FullDescr,
	               |	Files.CurrentVersion.Extension AS Extension,
	               |	Files.CurrentVersion.Size AS Size,
	               |	Files.CurrentVersion.ModificationDateUniversal AS ModificationDateUniversal,
	               |	Files.Ref,
	               |	Files.DeletionMark,
	               |	Files.Encrypted
	               |FROM
	               |	Catalog.Files AS Files
	               |WHERE
	               |	Files.FileOwner IN HIERARCHY(&Ref)
	               |	AND Files.CurrentVersion <> VALUE(Catalog.FileVersions.EmptyRef)
	               |	AND Files.DeletionMark = FALSE
	               |TOTALS BY
	               |	Folder HIERARCHY";
	Query.Parameters.Insert("Ref", FolderParent);
	Result = Query.Execute();
	ExportingTable = Result.Unload(QueryResultIteration.ByGroupsWithHierarchy);
	ValueToFormAttribute(ExportingTable, "FileTree");
EndProcedure

&AtClient
Procedure BypassFileTree(ResultHandler, FileTable, BaseSaveDirectory, ParentFolder, CommonParameters)
	// Recursive function that exports files to a local disk.
	//
	// Parameters:
	//   ResultHandler - NotifyDescription, Structure, Undefined - Description of the
	//                   procedure that receives the result of method work.
	//   FileTable - FormDataTree, FormDataTreeItem - value tree with exported files.
	//   BaseSaveDirectory - String - a string with a folder name to which files are saved.
	//                 If required, a folder structure is created in
	//                 it (as in the file tree).
	//   ParentFolder - CatalogRef.FileFolders - what to save.
	//   CommonParameters - Structure -
	//       * QuestionForm - Managed Form-Object that contains a
	//                 ref to the question form created in the memory. The
	//                 question is about whether to rewrite a file with check box "For all". It is created not to spend
	//                 time on regular form creation within a recursive cycle.
	//       * ForAllFiles - Boolean -
	//                 True: the user selected an action when
	//                 rewriting a file and selected check box "For all". Do not ask again.
	//                 False: in each case, prompt a user if a
	//                 file with the same name as in the infobase exists on the disk.
	//       * BaseAction - DialogReturnCode -
	//                 when performing the same action for all
	//                 conflicts when writing a file (parameter ForAllFiles
	//                 = True), an action set by this parameter is performed).
	//                 .Yes - Rewrite.
	//                 .Skip - skip file.
	//                 .Break - abort exporting.
	//
	// Returns: 
	//   Structure - Result.
	//       * Success - Boolean - True - exporting can be continued / data is successfully exported.
	//                         False   - the action is complete with errors / data is exported with errors.
	//
	
	If CommonParameters = Undefined Then
		CommonParameters = New Structure;
		CommonParameters.Insert("QuestionForm", FileOperationsServiceClientReUse.FolderExportFormFileExists());
		CommonParameters.Insert("BaseAction", DialogReturnCode.Ignore);
		CommonParameters.Insert("ForAllFiles", False);
		CommonParameters.Insert("HaveNotMetExportedFolder", True);
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("ResultHandler", ResultHandler);
	ExecuteParameters.Insert("FileTable", FileTable);
	ExecuteParameters.Insert("BaseSaveDirectory", BaseSaveDirectory);
	ExecuteParameters.Insert("ParentFolder", ParentFolder);
	ExecuteParameters.Insert("CommonParameters", CommonParameters);
	
	// Result parameters.
	ExecuteParameters.Insert("Success", False);
	
	// Parameters for a cycle.
	ExecuteParameters.Insert("Items", ExecuteParameters.FileTable.GetItems());
	ExecuteParameters.Insert("UBound", ExecuteParameters.Items.Count()-1);
	ExecuteParameters.Insert("IndexOf",   -1);
	ExecuteParameters.Insert("RequiredStartCycle", True);
	FileOperationsServiceClient.RegisterHandlerDescription(
		ExecuteParameters,
		ThisObject,
		"BypassFileTree2");
	
	// Variables.
	ExecuteParameters.Insert("WritingFile", Undefined);
	
	// Start cycle.
	BypassFileTreeStartCycle(ExecuteParameters);
EndProcedure

&AtClient
Procedure BypassFileTreeStartCycle(ExecuteParameters)
	If ExecuteParameters.RequiredStartCycle Then
		If ExecuteParameters.AsynchronousDialog.Open Then
			Return; // One more dialog has been opened - cycle does not need to be restarted.
		EndIf;
		ExecuteParameters.IndexOf = ExecuteParameters.IndexOf + 1;
		ExecuteParameters.RequiredStartCycle = False;
	Else
		Return; // Cycle has already run.
	EndIf;
	
	For IndexOf = ExecuteParameters.IndexOf To ExecuteParameters.UBound Do
		ExecuteParameters.WritingFile = ExecuteParameters.Items[IndexOf];
		ExecuteParameters.IndexOf = IndexOf;
		BypassFileTree1(ExecuteParameters);
		If ExecuteParameters.AsynchronousDialog.Open Then
			Return; // Cycle pause. Stack clearing in progress.
		EndIf;
	EndDo;
	
	ExecuteParameters.Success = True;
	FileOperationsServiceClient.ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
EndProcedure

&AtClient
Procedure BypassFileTree1(ExecuteParameters)
	If ExecuteParameters.CommonParameters.HaveNotMetExportedFolder = True Then
		If ExecuteParameters.WritingFile.Directory = WhatSaving Then
			ExecuteParameters.CommonParameters.HaveNotMetExportedFolder = False;
		EndIf;
	EndIf;
	
	If ExecuteParameters.CommonParameters.HaveNotMetExportedFolder = True Then
		
		FileOperationsServiceClient.RegisterHandlerDescription(
			ExecuteParameters,
			ThisObject,
			"BypassFileTree2");
		
		BypassFileTree(
			ExecuteParameters,
			ExecuteParameters.WritingFile,
			ExecuteParameters.BaseSaveDirectory,
			ExecuteParameters.WritingFile.Folder,
			ExecuteParameters.CommonParameters);
		
		If ExecuteParameters.AsynchronousDialog.Open Then
			Return; // Cycle pause. Stack clearing in progress.
		EndIf;
		
		BypassFileTree2(ExecuteParameters.AsynchronousDialog.ResultWhenNotOpen, ExecuteParameters);
		Return;
	EndIf;
	
	BypassFileTree3(ExecuteParameters);
EndProcedure

&AtClient
Procedure BypassFileTree2(Result, ExecuteParameters) Export
	If ExecuteParameters.AsynchronousDialog.Open Then
		ExecuteParameters.RequiredStartCycle = True;
		ExecuteParameters.AsynchronousDialog.Open = False;
	EndIf;
	
	If Result.Success <> True Then
		ExecuteParameters.Success = False;
		ExecuteParameters.RequiredStartCycle = False; // It is not required to restart the cycle.
		FileOperationsServiceClient.ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
		Return;
	EndIf;
	
	BypassFileTreeStartCycle(ExecuteParameters);
EndProcedure

&AtClient
Procedure BypassFileTree3(ExecuteParameters)
	// Generate a directory path and move on. Create directories.
	ExecuteParameters.Insert("BaseSaveDirectoryFile", ExecuteParameters.BaseSaveDirectory);
	If  ExecuteParameters.WritingFile.Folder <> WhatSaving
		AND ExecuteParameters.WritingFile.CurrentVersion.IsEmpty()
		AND ExecuteParameters.WritingFile.Folder <> ExecuteParameters.ParentFolder Then
		ExecuteParameters.BaseSaveDirectoryFile = (
			ExecuteParameters.BaseSaveDirectoryFile
			+ ExecuteParameters.WritingFile.FolderDescription
			+ CommonUseClientServer.PathSeparator());
	EndIf;
	
	// Check if a basic directory exists: if no - create.
	Folder = New File(ExecuteParameters.BaseSaveDirectoryFile);
	If Not Folder.Exist() Then
		BypassFileTree4(ExecuteParameters);
		Return;
	EndIf;
	
	BypassFileTree6(ExecuteParameters);
EndProcedure

&AtClient
Procedure BypassFileTree4(ExecuteParameters)
	ErrorText = "";
	Try
		CreateDirectory(ExecuteParameters.BaseSaveDirectoryFile);
	Except
		ErrorText = NStr("en='An error occurred when creating folder ""%1"":';ru='Ошибка создания папки ""%1"":'");
		ErrorText = StrReplace(ErrorText, "%1", ExecuteParameters.BaseSaveDirectoryFile);
		ErrorText = ErrorText + Chars.LF + Chars.LF + BriefErrorDescription(ErrorInfo());
	EndTry;
	
	If ErrorText <> "" Then
		FileOperationsServiceClient.PrepareHandlerForDialog(ExecuteParameters);
		Handler = New NotifyDescription("BypassFileTree5", ThisObject, ExecuteParameters);
		ShowQueryBox(Handler, ErrorText, QuestionDialogMode.AbortRetryIgnore, , DialogReturnCode.Retry);
		Return;
	EndIf;
	
	BypassFileTree6(ExecuteParameters);
EndProcedure

&AtClient
Procedure BypassFileTree5(Response, ExecuteParameters) Export
	If ExecuteParameters.AsynchronousDialog.Open Then
		ExecuteParameters.RequiredStartCycle = True;
		ExecuteParameters.AsynchronousDialog.Open = False;
	EndIf;
	
	If Response = DialogReturnCode.Abort Then
		// Exit with an error
		ExecuteParameters.Success = False;
		ExecuteParameters.RequiredStartCycle = False; // It is not required to restart the cycle.
		FileOperationsServiceClient.ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
		Return;
	ElsIf Response = DialogReturnCode.Ignore Then
		// Skip this tree branch and go further.
		ExecuteParameters.Success = True;
		ExecuteParameters.RequiredStartCycle = False; // It is not required to restart the cycle.
		FileOperationsServiceClient.ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
		Return;
	EndIf;
	
	// Try to recreate the folder.
	BypassFileTree4(ExecuteParameters);
EndProcedure

&AtClient
Procedure BypassFileTree6(ExecuteParameters)
	// Only if there is at least one file in the folder.
	ChildItems = ExecuteParameters.WritingFile.GetItems();
	If ChildItems.Count() > 0 Then
		
		FileOperationsServiceClient.RegisterHandlerDescription(
			ExecuteParameters,
			ThisObject,
			"BypassFileTree7");
		
		BypassFileTree(
			ExecuteParameters,
			ExecuteParameters.WritingFile,
			ExecuteParameters.BaseSaveDirectoryFile,
			ExecuteParameters.WritingFile.Folder,
			ExecuteParameters.CommonParameters);
		
		If ExecuteParameters.AsynchronousDialog.Open Then
			Return; // Cycle pause. Stack clearing in progress.
		EndIf;
		
		BypassFileTree7(ExecuteParameters.AsynchronousDialog.ResultWhenNotOpen, ExecuteParameters);
		Return;
	EndIf;
	
	BypassFileTree8(ExecuteParameters);
EndProcedure

&AtClient
Procedure BypassFileTree7(Result, ExecuteParameters) Export
	If ExecuteParameters.AsynchronousDialog.Open Then
		ExecuteParameters.RequiredStartCycle = True;
		ExecuteParameters.AsynchronousDialog.Open = False;
	EndIf;
	
	If Result.Success <> True Then
		ExecuteParameters.Success = False;
		ExecuteParameters.RequiredStartCycle = False;
		FileOperationsServiceClient.ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
		Return;
	EndIf;
	
	// Continue processing an item.
	BypassFileTree8(ExecuteParameters);
	
	// Restart a cycle if an asynchronous dialog was opened.
	BypassFileTreeStartCycle(ExecuteParameters);
EndProcedure

&AtClient
Procedure BypassFileTree8(ExecuteParameters)
	If  ExecuteParameters.WritingFile.CurrentVersion <> NULL
		AND ExecuteParameters.WritingFile.CurrentVersion.IsEmpty() Then
		// This is an item of the Files catalog without a file - skip.
		Return;
	EndIf;
	
	// Write a file into a base directory.
	ExecuteParameters.Insert("FileNameWithExtension", Undefined);
	ExecuteParameters.FileNameWithExtension = CommonUseClientServer.GetNameWithExtention(
		ExecuteParameters.WritingFile.FullDescr,
		ExecuteParameters.WritingFile.Extension);
	
	If ExecuteParameters.WritingFile.Encrypted Then
		ExecuteParameters.FileNameWithExtension = ExecuteParameters.FileNameWithExtension + "." + ExtensionForEncryptedFiles;
	EndIf;
	ExecuteParameters.Insert("FullFileName", ExecuteParameters.BaseSaveDirectoryFile + ExecuteParameters.FileNameWithExtension);
	
	ExecuteParameters.Insert("Result", Undefined);
	BypassFileTree9(ExecuteParameters);
EndProcedure

&AtClient
Procedure BypassFileTree9(ExecuteParameters)
	ExecuteParameters.Insert("FileOnDrive", New File(ExecuteParameters.FullFileName));
	If ExecuteParameters.FileOnDrive.Exist() AND ExecuteParameters.FileOnDrive.IsDirectory() Then
		QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Folder
		|with
		|the same name exists instead of file ""%1"".
		|
		|Reexport the file?';ru='Вместо
		|файла
		|""%1"" существует папка с таким же именем.
		|
		|Повторить экспорт этого файла?'"),
			ExecuteParameters.FullFileName);
		FileOperationsServiceClient.PrepareHandlerForDialog(ExecuteParameters);
		Handler = New NotifyDescription("BypassFileTree10", ThisObject, ExecuteParameters);
		ShowQueryBox(Handler, QuestionText, QuestionDialogMode.RetryCancel, , DialogReturnCode.Cancel);
		Return;
	EndIf;
	
	// No file - go further
	ExecuteParameters.Result = DialogReturnCode.Retry;
	BypassFileTree11(ExecuteParameters);
EndProcedure

&AtClient
Procedure BypassFileTree10(Response, ExecuteParameters) Export
	If ExecuteParameters.AsynchronousDialog.Open Then
		ExecuteParameters.RequiredStartCycle = True;
		ExecuteParameters.AsynchronousDialog.Open = False;
	EndIf;
	
	If Response = DialogReturnCode.Retry Then
		// Ignore the file
		BypassFileTree9(ExecuteParameters);
		Return;
	EndIf;
	
	// Continue processing an item.
	ExecuteParameters.Result = DialogReturnCode.Cancel;
	BypassFileTree11(ExecuteParameters);
	
	// Restart a cycle if an asynchronous dialog was opened.
	BypassFileTreeStartCycle(ExecuteParameters);
EndProcedure

&AtClient
Procedure BypassFileTree11(ExecuteParameters)
	If ExecuteParameters.Result = DialogReturnCode.Cancel Then
		// Ignore a file with the same name as the folder has
		Return;
	EndIf;
	
	ExecuteParameters.Result = DialogReturnCode.No;
	
	// Ask what to do with the current file.
	If ExecuteParameters.FileOnDrive.Exist() Then
		
		// If R|O and modification time of the file is less than the one in the infobase, - just rewrite.
		If  ExecuteParameters.FileOnDrive.GetReadOnly()
			AND ExecuteParameters.FileOnDrive.GetModificationUniversalTime() <= ExecuteParameters.WritingFile.ModificationDateUniversal Then
			ExecuteParameters.Result = DialogReturnCode.Yes;
		Else
			If Not ExecuteParameters.CommonParameters.ForAllFiles Then
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Folder ""%1""
		|already contains file
		|""%2"", size of the existing file = %3 bytes, date modified is %4.
		|size of the saved file = %5 bytes, date modified is %6.
		|
		|Replace the existing file with a file from the file storage?';ru='В
		|папке ""%1"" существует
		|файл ""%2"" размер существующего файла = %3 байт, дата изменения %4.
		|размер сохраняемого файла = %5 байт, дата изменения %6.
		|
		|Заменить существующий файл файлом из хранилища файлов?'"),
					ExecuteParameters.BaseSaveDirectoryFile,
					ExecuteParameters.FileNameWithExtension,
					ExecuteParameters.FileOnDrive.Size(),
					ToLocalTime(ExecuteParameters.FileOnDrive.GetModificationUniversalTime()),
					ExecuteParameters.WritingFile.Size,
					ToLocalTime(ExecuteParameters.WritingFile.ModificationDateUniversal));
				
				ParametersStructure = New Structure;
				ParametersStructure.Insert("MessageText",   MessageText);
				ParametersStructure.Insert("ApplyToAll", ExecuteParameters.CommonParameters.ForAllFiles);
				ParametersStructure.Insert("BaseAction",  ExecuteParameters.CommonParameters.BaseAction);
				
				QuestionForm = ExecuteParameters.CommonParameters.QuestionForm;
				QuestionForm.SetUsageParameters(ParametersStructure);
				
				FileOperationsServiceClient.PrepareHandlerForDialog(ExecuteParameters);
				Handler = New NotifyDescription("BypassFileTree12", ThisObject, ExecuteParameters);
				
				FileOperationsServiceClient.SetFormAlert(QuestionForm, Handler);
				
				QuestionForm.Open();
				Return;
			EndIf;
			
			ExecuteParameters.Result = ExecuteParameters.CommonParameters.BaseAction;
			BypassFileTree13(ExecuteParameters);
			Return;
		EndIf;
	EndIf;
	
	// File does not exist, do not ask.
	ExecuteParameters.Result = DialogReturnCode.Yes;
	BypassFileTree14(ExecuteParameters);
EndProcedure

&AtClient
Procedure BypassFileTree12(Result, ExecuteParameters) Export
	If ExecuteParameters.AsynchronousDialog.Open Then
		ExecuteParameters.RequiredStartCycle = True;
		ExecuteParameters.AsynchronousDialog.Open = False;
	EndIf;
	
	ExecuteParameters.Result = Result.ReturnCode;
	ExecuteParameters.CommonParameters.ForAllFiles = Result.ApplyToAll;
	ExecuteParameters.CommonParameters.BaseAction = ExecuteParameters.Result;
	
	// Continue processing an item.
	BypassFileTree13(ExecuteParameters);
	
	// Restart a cycle if an asynchronous dialog was opened.
	BypassFileTreeStartCycle(ExecuteParameters);
EndProcedure

&AtClient
Procedure BypassFileTree13(ExecuteParameters)
	If ExecuteParameters.Result = DialogReturnCode.Abort Then
		// Abort exporting
		ExecuteParameters.Success = False;
		ExecuteParameters.RequiredStartCycle = False; // It is not required to restart the cycle.
		FileOperationsServiceClient.ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
		Return;
	ElsIf ExecuteParameters.Result = DialogReturnCode.Ignore Then
		// Skip this file
		Return;
	EndIf;
	
	// If it is possible - write a file to the file system.
	If ExecuteParameters.Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	BypassFileTree14(ExecuteParameters);
EndProcedure

&AtClient
Procedure BypassFileTree14(ExecuteParameters)
	ExecuteParameters.FileOnDrive = New File(ExecuteParameters.FullFileName);
	If ExecuteParameters.FileOnDrive.Exist() Then
		// Clear checkbox R|O to enable deletion.
		ExecuteParameters.FileOnDrive.SetReadOnly(False);
	EndIf;
	
	// Always delete and then create again.
	ErrorInfo = Undefined;
	Try
		DeleteFiles(ExecuteParameters.FullFileName);
	Except
		ErrorInfo = ErrorInfo();
	EndTry;
	If ErrorInfo <> Undefined Then
		BypassFileTree15(ErrorInfo, ExecuteParameters);
		Return;
	EndIf;
	
	SizeInMB = ExecuteParameters.WritingFile.Size / (1024 * 1024);
	
	// Update progress bar.
	TitleState = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Export Folders ""%1""';ru='Экспорт папки ""%1""'"),
		ExecuteParameters.WritingFile.FolderDescription);
	StateText = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='File ""%1""
		|is being saved on the disk (%2 Mb)...';ru='Сохраняется
		|на диск файл ""%1"" (%2 Мб)...'"),
		ExecuteParameters.FileOnDrive.Name,
		FileFunctionsServiceClientServer.GetStringWithFileSize(SizeInMB));
	Status(TitleState, , StateText, PictureLib.Information32);
	
	// Rewrite the file
	FileURLForOpening = FileOperationsServiceServerCall.GetURLForOpening(
		ExecuteParameters.WritingFile.CurrentVersion,
		UUID);
	
	Try
		GetFile(FileURLForOpening, ExecuteParameters.FullFileName, False);
	Except
		ErrorInfo = ErrorInfo();
	EndTry;
	If ErrorInfo <> Undefined Then
		BypassFileTree15(ErrorInfo, ExecuteParameters);
		Return;
	EndIf;
	
	// For an option with storing files on the disk (on the server), delete a file from the temporary storage once it is received.
	If IsTempStorageURL(FileURLForOpening) Then
		DeleteFromTempStorage(FileURLForOpening);
	EndIf;
	
	ExecuteParameters.FileOnDrive = New File(ExecuteParameters.FullFileName);
	
	Try
		// Create a read-only file.
		ExecuteParameters.FileOnDrive.SetReadOnly(True);
		// Specify modification time - as in the infobase.
		ExecuteParameters.FileOnDrive.SetModificationUniversalTime(
			ExecuteParameters.WritingFile.ModificationDateUniversal);
	Except
		ErrorInfo = ErrorInfo();
	EndTry;
	If ErrorInfo <> Undefined Then
		BypassFileTree15(ErrorInfo, ExecuteParameters);
		Return;
	EndIf;
EndProcedure

&AtClient
Procedure BypassFileTree15(ErrorInfo, ExecuteParameters)
	// A file error occurred when writing the file
	// and changing its attributes.
	QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='An error
		|occurred while writing file ""%1"".
		|
		|%2.';ru='Ошибка
		|записи файла ""%1"".
		|
		|%2.'"),
		ExecuteParameters.FullFileName,
		BriefErrorDescription(ErrorInfo));
	
	FileOperationsServiceClient.PrepareHandlerForDialog(ExecuteParameters);
	Handler = New NotifyDescription("BypassFileTree16", ThisObject, ExecuteParameters);
	
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.AbortRetryIgnore, , DialogReturnCode.Retry);
EndProcedure

&AtClient
Procedure BypassFileTree16(Response, ExecuteParameters) Export
	If Response = DialogReturnCode.Abort Then
		// Exit with an error
		ExecuteParameters.Success = False;
		ExecuteParameters.RequiredStartCycle = False; // It is not required to restart the cycle.
		// False.
		FileOperationsServiceClient.ReturnResult(ExecuteParameters.ResultHandler, ExecuteParameters);
		Return;
	ElsIf Response = DialogReturnCode.Ignore Then
		// Skip this file and go forward.
		Return;
	EndIf;
	
	// Try to recreate the folder.
	BypassFileTree14(ExecuteParameters);
EndProcedure

#EndRegion














