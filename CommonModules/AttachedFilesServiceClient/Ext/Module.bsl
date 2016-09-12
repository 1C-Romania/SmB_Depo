////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// See the function with the same name in the AttachedFilesClient common module.
Function GetFileIntoWorkingDirectory(Val FileBinaryDataAddress,
                                    Val RelativePath,
                                    Val ModificationDateUniversal,
                                    Val FileName,
                                    Val UserWorkingDirectory,
                                    FullFileNameAtClient) Export
	
	If UserWorkingDirectory = Undefined
	 OR IsBlankString(UserWorkingDirectory) Then
		
		Return False;
	EndIf;
	
	DirectorySave = UserWorkingDirectory + RelativePath;
	
	Try
		CreateDirectory(DirectorySave);
	Except
		ErrorInfo = BriefErrorDescription(ErrorInfo());
		ErrorInfo = NStr("en='Error of directory creation on the disk:';ru='Ошибка создания каталога на диске:'") + " " + ErrorInfo;
		CommonUseClientServer.MessageToUser(ErrorInfo);
		Return False;
	EndTry;
	
	File = New File(DirectorySave + FileName);
	If File.Exist() Then
		File.SetReadOnly(False);
		DeleteFiles(DirectorySave + FileName);
	EndIf;
	
	ReceivedFile = New TransferableFileDescription(DirectorySave + FileName, FileBinaryDataAddress);
	FilesToReceive = New Array;
	FilesToReceive.Add(ReceivedFile);
	
	ReceivedFiles = New Array;
	
	If GetFiles(FilesToReceive, ReceivedFiles, , False) Then
		FullFileNameAtClient = ReceivedFiles[0].Name;
		File = New File(FullFileNameAtClient);
		File.SetModificationUniversalTime(ModificationDateUniversal);
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// See the function with the same name in the AttachedFilesClient common module.
Function PutFileToStorage(Val PathToFile, Val FormID) Export
	
	Result = New Structure;
	Result.Insert("FilePlacedToStorage", False);
	
	File = New File(PathToFile);
	FileFunctionsServiceClientServer.CheckFileImportingPossibility(File);
	
	TextTemporaryStorageAddress = "";
	If Not FileFunctionsServiceClientServer.FileOperationsCommonSettings().ExtractFileTextsAtServer Then
		TextTemporaryStorageAddress = FileFunctionsServiceClientServer.ExtractTextToTemporaryStorage(PathToFile, FormID);
	EndIf;
	
	FilesToPlace = New Array;
	FilesToPlace.Add(New TransferableFileDescription(PathToFile));
	PlacedFiles = New Array;
	
	If Not PutFiles(FilesToPlace, PlacedFiles, , False, FormID) Then
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Error when"
"placing"
"the %1 file into a temporary storage.';ru='Ошибка"
"при"
"помещении файла ""%1"" во временное хранилище.'"),
				PathToFile) );
		Return Result;
	EndIf;
	
	Result.Insert("FilePlacedToStorage", True);
	Result.Insert("ModificationDateUniversal",   File.GetModificationUniversalTime());
	Result.Insert("FileAddressInTemporaryStorage", PlacedFiles[0].Location);
	Result.Insert("TextTemporaryStorageAddress", TextTemporaryStorageAddress);
	Result.Insert("Extension",                     Right(File.Extension, StrLen(File.Extension)-1));
	
	Return Result;
	
EndFunction

// Adds files by dragging them into the file list.
//
// Parameters:
//  FileOwner      - Ref - file owner.
//  FormID - UUID of the form.
//  FileNameArray   - Array of strings - paths to files.
//
Procedure AddFilesByDragging(Val FileOwner, Val FormID, Val FileNameArray) Export
	
	AttachedFilesArray = New Array;
	PlaceSelectedFilesToStorage(
		FileNameArray,
		FileOwner,
		AttachedFilesArray,
		FormID);
	
	If AttachedFilesArray.Count() = 1 Then
		AttachedFile = AttachedFilesArray[0];
		
		ShowUserNotification(
			NStr("en='Creating';ru='Создание'"),
			GetURL(AttachedFile),
			AttachedFile,
			PictureLib.Information32);
		
		FormParameters = New Structure("AttachedFile, IsNew", AttachedFile, True);
		OpenForm("CommonForm.AttachedFile", FormParameters, , AttachedFile);
	EndIf;
	
	If AttachedFilesArray.Count() > 0 Then
		NotifyChanged(AttachedFilesArray[0]);
		Notify("Record_AttachedFile", New Structure("IsNew", True), AttachedFilesArray);
	EndIf;
	
EndProcedure

// Places a file from drive into storage of attached files (Web client).
// 
// Parameters:
//  ResultHandler    - NotifyDescription - procedure in which it is necessary to delegate control upon completion.
//                            Parameters of called procedure:
//                             AttachedFile      - Refs, Undefined - ref to the
//                                                       added file or Undefined if the file was not placed;
//                             AdditionalParameters - Arbitrary - value that was specified when
//                                                                      notification object was created.
//  FileOwner           - Ref to the file owner.
//  FileOperationsSettings - Structure.
//  FormID      - UUID of the form.
//
Procedure PlaceSelectedFilesIntoWebStorage(ResultHandler, Val FileOwner, Val FormID)
	
	Parameters = New Structure;
	Parameters.Insert("FileOwner", FileOwner);
	Parameters.Insert("ResultHandler", ResultHandler);
	
	NotifyDescription = New NotifyDescription("PlaceSelectedFilesIntoWebStorageEnd", ThisObject, Parameters);
	BeginPutFile(NOTifyDescription, , ,True, FormID);
	
EndProcedure

// Continuation of the PlaceSelectedFilesIntoWebStorage procedure.
Procedure PlaceSelectedFilesIntoWebStorageEnd(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Not Result Then
		ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, Undefined);
		Return;
	EndIf;
	
	FileTemporaryStorageAddress = Address;
	FileName = SelectedFileName;
	FileOwner = AdditionalParameters.FileOwner;
	
	PathStrings = CommonUseClientServer.SortStringByPointsAndSlashes(FileName);
	
	If PathStrings.Count() >= 2 Then
		Extension = PathStrings[PathStrings.Count()-1];
		BaseName = PathStrings[PathStrings.Count()-2];
	Else
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Error when"
"placing"
"the %1 file into a temporary storage.';ru='Ошибка"
"при"
"помещении файла ""%1"" во временное хранилище.'"),
			FileName);
	EndIf;
	
	FileFunctionsServiceClientServer.CheckFileExtensionForImporting(Extension);
	
	// Creating of the File card in database.
	AttachedFile = AttachedFilesServiceServerCall.AddFile(
		FileOwner,
		BaseName,
		Extension,
		,
		,
		FileTemporaryStorageAddress,
		"");
		
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, AttachedFile);
	
EndProcedure

// Puts the edited files into storage.
// It is used as files editing end command handler.
//
// Parameters:
//  ResultHandler    - NotifyDescription - procedure in which it is necessary to delegate control upon completion.
//                            Parameters of called procedure:
//                             InformationAboutFile - Structure, Undefined - information about the placed file. If
//                                                placing has not been completed, it returns Undefined;
//                             AdditionalParameters - Arbitrary - value that was specified when
//                                                                      notification object was created.
//  FileData        - Structure with file data.
//  FormID - UUID of the form.
//
Procedure PlaceEditedFileOnDriveIntoStorage(ResultHandler, Val FileData, Val FormID) Export
	
	Parameters = New Structure;
	Parameters.Insert("ResultHandler", ResultHandler);
	Parameters.Insert("FileData", FileData);
	Parameters.Insert("FormID", FormID);
	
	NotifyDescription = New NotifyDescription("PlaceEditedFileOnDriveIntoStorageExtensionRequested", ThisObject, Parameters);
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(NOTifyDescription);
	
EndProcedure

// Continuation of the PlaceEditedFileOnDriveIntoStorage procedure.
Procedure PlaceEditedFileOnDriveIntoStorageExtensionRequested(FileOperationsExtensionConnected, AdditionalParameters) Export
	
	FileData = AdditionalParameters.FileData;
	FormID = AdditionalParameters.FormID;
	
	If FileOperationsExtensionConnected Then
		UserWorkingDirectory = FileFunctionsServiceClient.UserWorkingDirectory();
		FullFileNameAtClient = UserWorkingDirectory + FileData.RelativePath + FileData.FileName;
		
		InformationAboutFile = Undefined;
		File = New File(FullFileNameAtClient);
		If File.Exist() Then
			InformationAboutFile = PutFileToStorage(FullFileNameAtClient, FormID);
		Else
			CommonUseClientServer.MessageToUser(
				NStr("en='File is not found in the work directory.';ru='Файл не найден в рабочем каталоге.'"));
		EndIf;
		
		ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, InformationAboutFile);
	Else
		NotifyDescription = New NotifyDescription("PlaceEditedFileOnDriveIntoCompletedStorageRoom", ThisObject, AdditionalParameters);
		PlaceFileOnDriveIntoWebStorage(NOTifyDescription, FileData, FormID);
	EndIf;
	
EndProcedure

// Continuation of the PlaceEditedFileOnDriveIntoStorage procedure.
Procedure PlaceEditedFileOnDriveIntoCompletedStorageRoom(InformationAboutFile, AdditionalParameters) Export
	FileData = AdditionalParameters.FileData;
	If InformationAboutFile = Undefined Or FileData.FileName = InformationAboutFile.FileName Then
		ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, InformationAboutFile);
		Return;
	EndIf;
	
	QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Name of"
"the"
"selected file ""%1"" differs from the"
"name of the file in the %2 storage."
""
"Continue?';ru='Имя выбранного файла"
"""%1"""
"отличается от имени файла в хранилище"
"""%2""."
""
"Продолжить?'"),
		InformationAboutFile.FileName,
		FileData.FileName);
		
	AdditionalParameters.Insert("InformationAboutFile", InformationAboutFile);
	NotifyDescription = New NotifyDescription("PlaceEditedFileOnDriveIntoStorageResponseReceived", ThisObject, AdditionalParameters);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.OKCancel);
EndProcedure

// Continuation of the PlaceEditedFileOnDriveIntoStorage procedure.
Procedure PlaceEditedFileOnDriveIntoStorageResponseReceived(QuestionResult, AdditionalParameters) Export
	Result = Undefined;
	If QuestionResult = DialogReturnCode.OK Then
		Result = AdditionalParameters.InformationAboutFile;
	EndIf;
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, Result);
EndProcedure

// Selects a file from drive and puts it into temporary storage on server.
//
// Parameters:
//  ResultHandler    - NotifyDescription - procedure in which it is necessary to delegate control upon completion.
//                            Parameters of called procedure:
//                             InformationAboutFile - Structure, Undefined - information about the placed file. If
//                                                placing has not been completed, it returns Undefined;
//                             AdditionalParameters - Arbitrary - value that was specified when
//                                                                      notification object was created.
//  FileData        - Structure with file data.
//  InformationAboutFile   - Structure (return value) - File information.
//  FormID - UUID of the form.
//
Procedure SelectFileOnDriveAndPlaceIntoStorage(ResultHandler, Val FileData, Val FormID) Export
	
	Parameters = New Structure;
	Parameters.Insert("ResultHandler", ResultHandler);
	Parameters.Insert("FileData", FileData);
	Parameters.Insert("FormID", FormID);
	
	NotifyDescription = New NotifyDescription("SelectFileOnDriveAndPlaceIntoStorageExtensionRequested", ThisObject, Parameters);
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(NOTifyDescription);
	
EndProcedure

// Continuation of the SelectFileOnDriveAndPlaceIntoStorage procedure.
Procedure SelectFileOnDriveAndPlaceIntoStorageExtensionRequested(FileOperationsExtensionConnected, AdditionalParameters) Export
	
	FileData = AdditionalParameters.FileData;
	FormID = AdditionalParameters.FormID;
	
	If FileOperationsExtensionConnected Then
		FileChoice = New FileDialog(FileDialogMode.Open);
		FileChoice.Multiselect = False;
		FileChoice.FullFileName = FileData.Description + "." + FileData.Extension;
		FileChoice.Extension = FileData.Extension;
		FileChoice.Filter = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='All files (*.%1)|*.%1';ru='Все файлы (*.%1)|*.%1'"), FileData.Extension);
		
		InformationAboutFile = Undefined;
		If FileChoice.Choose() Then
			InformationAboutFile = PutFileToStorage(FileChoice.FullFileName, FormID);
		EndIf;
		
		ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, InformationAboutFile);
	Else
		NotifyDescription = New NotifyDescription("SelectFileOnDriveAndPlaceIntoStoragePlacingCompleted", ThisObject, AdditionalParameters);
		PlaceFileOnDriveIntoWebStorage(NOTifyDescription, FileData, FormID);
	EndIf;
	
EndProcedure

// Continuation of the SelectFileOnDriveAndPlaceIntoStorage procedure.
Procedure SelectFileOnDriveAndPlaceIntoStoragePlacingCompleted(InformationAboutFile, AdditionalParameters) Export
	
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, InformationAboutFile);
	
EndProcedure

// Places a file from client drive into temporary storage.
//  Analogue of
// the PlaceFileOnDriveIntoStorage function for web client without extension for work with files.
//
// Parameters:
//  ResultHandler    - NotifyDescription - procedure in which it is necessary to delegate control upon completion.
//                            Parameters of called procedure:
//                             InformationAboutFile - Structure, Undefined - information about the placed file. If
//                                                placing has not been completed, it returns Undefined;
//                             AdditionalParameters - Arbitrary - value that was specified when
//                                                                      notification object was created.
//  FileData             - Structure with file data.
//  InformationAboutFile        - Structure (return value) with file information.
//  FormID      - UUID of the form.
//
Procedure PlaceFileOnDriveIntoWebStorage(ResultHandler, Val FileData, Val FormID)
	
	Parameters = New Structure;
	Parameters.Insert("ResultHandler", ResultHandler);
	
	NotifyDescription = New NotifyDescription("PlaceFileOnDriveIntoWebStoragePlacingCompleted", ThisObject, Parameters);
	BeginPutFile(NOTifyDescription, , FileData.FileName, True, FormID);
	
EndProcedure

// Continuation of the PlaceFileOnDriveIntoWebStorage procedure.
Procedure PlaceFileOnDriveIntoWebStoragePlacingCompleted(Result, FileTemporaryStorageAddress, SelectedFileName, AdditionalParameters) Export
	
	If Not Result Then
		ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, Undefined);
		Return;
	EndIf;
	
	PathStrings = CommonUseClientServer.SortStringByPointsAndSlashes(SelectedFileName);
	
	If PathStrings.Count() >= 2 Then
		NewName = PathStrings[PathStrings.Count()-2];
		NewExtension = PathStrings[PathStrings.Count()-1];
		FileName = NewName + "." + NewExtension;
	ElsIf PathStrings.Count() = 1 Then
		NewName = PathStrings[0];
		NewExtension = "";
		FileName = NewName;
	EndIf;
	
	FileFunctionsServiceClientServer.CheckFileExtensionForImporting(NewExtension);
	
	InformationAboutFile = New Structure;
	InformationAboutFile.Insert("FilePlacedToStorage", True);
	InformationAboutFile.Insert("ModificationDateUniversal",   Undefined);
	InformationAboutFile.Insert("FileAddressInTemporaryStorage", FileTemporaryStorageAddress);
	InformationAboutFile.Insert("TextTemporaryStorageAddress", "");
	InformationAboutFile.Insert("FileName",                       FileName);
	InformationAboutFile.Insert("Extension",                     NewExtension);
	
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, InformationAboutFile);
	
EndProcedure

// Opens directory with the file (receives file from storage if needed).
// It is used as a command handler for opening a directory with file.
//
// Parameters:
//  FileData - Structure with file data.
//
Procedure OpenDirectoryWithFile(Val FileData) Export
	
	Parameters = New Structure;
	Parameters.Insert("FileData", FileData);
	
	NotifyDescription = New NotifyDescription("OpenDirectoryWithFileExtensionRequested", ThisObject, Parameters);
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(NOTifyDescription);
	
EndProcedure

// Continuation of the OpenDirectoryWithFile procedure.
Procedure OpenDirectoryWithFileExtensionRequested(FileOperationsExtensionConnected, AdditionalParameters) Export
	Var FullFileName;
	
	FileData = AdditionalParameters.FileData;

	If FileOperationsExtensionConnected Then
		UserWorkingDirectory = FileFunctionsServiceClient.UserWorkingDirectory();
		If IsBlankString(UserWorkingDirectory) Then
			ShowMessageBox(, NStr("en='The working directory is not set';ru='Не задан рабочий каталог'"));
			Return;
		EndIf;
		
		FullPath = UserWorkingDirectory + FileData.RelativePath + FileData.FileName;
		File = New File(FullPath);
		If Not File.Exist() Then
			QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='File"
"""%1"" is absent in the working directory."
""
"Do you want to receive the file from the file storage?';ru='Файл"
"""%1"" отсутствует в рабочем каталоге."
""
"Получить файл из хранилища файлов?'"),
				File.Name);
			AdditionalParameters.Insert("UserWorkingDirectory", UserWorkingDirectory);
			AdditionalParameters.Insert("FullPath", FullPath);
			NotifyDescription = New NotifyDescription("OpenDirectoryWithFileResponseReceived", ThisObject, AdditionalParameters);
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
		EndIf;
		
		FileFunctionsServiceClient.OpenExplorerWithFile(FullPath);
	Else
		FileFunctionsServiceClient.ShowWarningAboutNeedToFileOperationsExpansion(Undefined);
	EndIf;
	
EndProcedure

// Continuation of the OpenDirectoryWithFile procedure.
Procedure OpenDirectoryWithFileResponseReceived(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	FileData = AdditionalParameters.FileData;
	UserWorkingDirectory = AdditionalParameters.UserWorkingDirectory;
	FullPath = AdditionalParameters.FullPath;
	
	FullFileNameAtClient = "";
	GetFileIntoWorkingDirectory(
		FileData.FileBinaryDataRef,
		FileData.RelativePath,
		FileData.ModificationDateUniversal,
		FileData.FileName,
		UserWorkingDirectory,
		FullFileNameAtClient);
		
	FileFunctionsServiceClient.OpenExplorerWithFile(FullPath);
	
EndProcedure


// See the procedure with the same name in the AttachedFilesClient common module.
Procedure PlaceAttachedFile(Notification, AttachedFile, FormID, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = New Structure;
	EndIf;
	
	Context = New Structure;
	Context.Insert("Notification",                Notification);
	Context.Insert("AttachedFile",        AttachedFile);
	Context.Insert("FormID",        FormID);
	Context.Insert("FileData",               Undefined);
	Context.Insert("FullNameOfThePlacedFile", Undefined);
	AdditionalParameters.Property("FileData",    Context.FileData);
	AdditionalParameters.Property("FullFileName", Context.FullNameOfThePlacedFile);
	
	If TypeOf(Context.FileData) <> Type("Structure") Then
		Context.Insert("FileData", AttachedFilesServiceServerCall.GetFileData(
			Context.AttachedFile, Context.FormID, False));
	EndIf;
	
	Context.Insert("ErrorTitle",
		NStr("en='Failed to place the file from your computer into storage due to:';ru='Не удалось поместить файл с компьютера в хранилище файлов по причине:'") + Chars.LF);
	
	CommonUseClient.ShowQuestionAboutFileOperationsExtensionSetting(New NotifyDescription(
		"PlaceAttachedFileAfterConnectionExpansions", ThisObject, Context),, False);
	
EndProcedure

// Continuation of the PlaceAttachedFile procedure.
Procedure PlaceAttachedFileAfterConnectionExpansions(ExtensionAttached, Context) Export
	
	If Not ExtensionAttached Then
		Result = New Structure;
		Result.Insert("ErrorDescription", Context.ErrorTitle +
			NStr("en='The extension for work with files is not installed in the Internet browser.';ru='В обозреватель интернет не установлено расширение для работы с файлами.'"));
		ExecuteNotifyProcessing(Context.Notification, Result);
		Return;
	EndIf;
	
	FileFunctionsServiceClient.GetUserWorkingDirectory(New NotifyDescription(
		"PlaceAttachedFileAfterGettingWorkingDirectory", ThisObject, Context));
	
EndProcedure

// Continuation of the PlaceAttachedFile procedure.
Procedure PlaceAttachedFileAfterGettingWorkingDirectory(Result, Context) Export
	
	If ValueIsFilled(Result.ErrorDescription) Then
		Result = New Structure;
		Result.Insert("ErrorDescription", Context.ErrorTitle + Result.ErrorDescription);
		ExecuteNotifyProcessing(Context.Notification, Result);
		Return;
	EndIf;
	
	Context.Insert("UserWorkingDirectory", Result.Directory);
	Context.Insert("FileDir", Context.UserWorkingDirectory + Context.FileData.RelativePath);
	Context.Insert("FullFileName", Context.FileDir + Context.FileData.FileName);
	
	If Not ValueIsFilled(Context.FullNameOfThePlacedFile) Then
		Context.FullNameOfThePlacedFile = Context.FullFileName;
	EndIf;
	
	ActionsWithFile = New Array;
	
	If Context.FullFileName <> Context.FullNameOfThePlacedFile Then
		Action = New Structure;
		Action.Insert("Action", "CreateDirectory");
		Action.Insert("File", Context.FileDir);
		Action.Insert("ErrorTitle", Context.ErrorTitle +
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Directory is not created due to:';ru='Создание каталога не выполнено по причине:'"), Context.FileDir));
		ActionsWithFile.Add(Action);
		
		Action = New Structure;
		Action.Insert("Action", "SetProperties");
		Action.Insert("File",  Context.FullFileName);
		Action.Insert("Properties", New Structure("ReadOnly", False));
		Action.Insert("ErrorTitle", Context.ErrorTitle +
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='The ""View only"" property of the file is not changed due to:';ru='Изменение свойства файла ""Только просмотр"" не выполнено по причине:'"), Context.FullFileName));
		ActionsWithFile.Add(Action);
		
		Action = New Structure;
		Action.Insert("Action", "Delete");
		Action.Insert("File", Context.FullFileName);
		Action.Insert("ErrorTitle", Context.ErrorTitle +
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='File is not deleted due to:';ru='Удаление файла не выполнено по причине:'"), Context.FullFileName));
		ActionsWithFile.Add(Action);
		
		Action = New Structure;
		Action.Insert("Action", "CopyFromSource");
		Action.Insert("File",     Context.FullFileName);
		Action.Insert("Source", Context.FullNameOfThePlacedFile);
		Action.Insert("ErrorTitle", Context.ErrorTitle +
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='File is not copied due to:';ru='Копирование файла не выполнено по причине:'"), Context.FullFileName));
		ActionsWithFile.Add(Action);
	EndIf;
	
	Action = New Structure;
	Action.Insert("Action", "SetProperties");
	Action.Insert("File",  Context.FullFileName);
	Action.Insert("Properties", New Structure("ReadOnly", True));
	Action.Insert("ErrorTitle", Context.ErrorTitle +
		StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='The ""View only"" property of the file is not changed due to:';ru='Изменение свойства файла ""Только просмотр"" не выполнено по причине:'"), Context.FullFileName));
	ActionsWithFile.Add(Action);
	
	Context.Insert("FileProperties", New Structure);
	Context.FileProperties.Insert("UniversalModificationTime");
	Context.FileProperties.Insert("BaseName");
	Context.FileProperties.Insert("Extension");
	
	Action = New Structure;
	Action.Insert("Action", "GetProperties");
	Action.Insert("File",  Context.FullFileName);
	Action.Insert("Properties", Context.FileProperties);
	Action.Insert("ErrorTitle", Context.ErrorTitle +
		StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='File property is not got due to:';ru='Получение свойств файла не выполнено по причине:'"), Context.FullFileName));
	ActionsWithFile.Add(Action);
	
	Context.Insert("PlacingAction", New Structure);
	Context.PlacingAction.Insert("Action", "Place");
	Context.PlacingAction.Insert("File",  Context.FullFileName);
	Context.PlacingAction.Insert("ErrorTitle", Context.ErrorTitle);
	ActionsWithFile.Add(Context.PlacingAction);
	
	FileFunctionsServiceClient.HandleFile(New NotifyDescription(
			"PlaceAttachedFileAfterProcessingFile", ThisObject, Context),
		ActionsWithFile, Context.FormID);
	
EndProcedure

// Continuation of the PlaceAttachedFile procedure.
Procedure PlaceAttachedFileAfterProcessingFile(ActionsResult, Context) Export
	
	Result = New Structure;
	
	If ValueIsFilled(ActionsResult.ErrorDescription) Then
		Result.Insert("ErrorDescription", ActionsResult.ErrorDescription);
		ExecuteNotifyProcessing(Context.Notification, Result);
		Return;
	EndIf;
	
	Result.Insert("ErrorDescription", "");
	
	Extension = Context.FileProperties.Extension;
	
	InformationAboutFile = New Structure;
	InformationAboutFile.Insert("ModificationDateUniversal",   Context.FileProperties.UniversalModificationTime);
	InformationAboutFile.Insert("FileAddressInTemporaryStorage", Context.PlacingAction.Address);
	InformationAboutFile.Insert("TextTemporaryStorageAddress", "");
	InformationAboutFile.Insert("BaseName",               Context.FileProperties.BaseName);
	InformationAboutFile.Insert("Extension",                     Right(Extension, StrLen(Extension)-1));
	InformationAboutFile.Insert("IsEditing",                    Undefined);
	
	Try
		AttachedFilesServiceServerCall.UpdateAttachedFile(
			Context.AttachedFile, InformationAboutFile);
	Except
		ErrorInfo = ErrorInfo();
		Result.Insert("ErrorDescription", Context.ErrorTitle + Chars.LF
			+ BriefErrorDescription(ErrorInfo));
	EndTry;
	
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure


// See the procedure with the same name in the AttachedFilesClient common module.
Procedure GetAttachedFile(Notification, AttachedFile, FormID, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = New Structure;
	EndIf;
	
	Context = New Structure;
	Context.Insert("Notification",         Notification);
	Context.Insert("AttachedFile", AttachedFile);
	Context.Insert("FormID", FormID);
	Context.Insert("ForEditing",  False);
	Context.Insert("FileData",        Undefined);
	AdditionalParameters.Property("ForEditing", Context.ForEditing);
	AdditionalParameters.Property("FileData",       Context.FileData);
	
	If TypeOf(Context.FileData) <> Type("Structure")
	 Or Not ValueIsFilled(Context.FileData.FileBinaryDataRef) Then
		
		Context.Insert("FileData", AttachedFilesServiceServerCall.GetFileData(
			Context.AttachedFile, Context.FormID, True, Context.ForEditing));
	EndIf;
	
	Context.Insert("ErrorTitle",
		NStr("en='Failed to get the file onto your computer from the storage due to:';ru='Не удалось получить файл на компьютер из хранилища файлов по причине:'") + Chars.LF);
	
	If Context.ForEditing
	   AND Context.FileData.IsEditing <> UsersClientServer.AuthorizedUser() Then
		
		Result = New Structure;
		Result.Insert("FullFileName", "");
		Result.Insert("ErrorDescription", Context.ErrorTitle + StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='The %1 user is already editing the file.';ru='Файл уже редактирует пользователь %1.'"), String(Context.FileData.IsEditing)));
		ExecuteNotifyProcessing(Context.Notification, Result);
		Return;
	EndIf;
	
	Context.Insert("ForEditing", ValueIsFilled(Context.FileData.IsEditing));
	
	CommonUseClient.ShowQuestionAboutFileOperationsExtensionSetting(New NotifyDescription(
		"GetAttachedFileAfterConnectionExpansions", ThisObject, Context),, False);
	
EndProcedure

// Continuation of the GetAttachedFile procedure.
Procedure GetAttachedFileAfterConnectionExpansions(ExtensionAttached, Context) Export
	
	If Not ExtensionAttached Then
		Result = New Structure;
		Result.Insert("FullFileName", "");
		Result.Insert("ErrorDescription", Context.ErrorTitle +
			NStr("en='The extension for work with files is not installed in the Internet browser.';ru='В обозреватель интернет не установлено расширение для работы с файлами.'"));
		ExecuteNotifyProcessing(Context.Notification, Result);
		Return;
	EndIf;
	
	FileFunctionsServiceClient.GetUserWorkingDirectory(New NotifyDescription(
		"GetAttachedFileAfterGettingWorkingDirectory", ThisObject, Context));
	
EndProcedure

// Continuation of the GetAttachedFile procedure.
Procedure GetAttachedFileAfterGettingWorkingDirectory(Result, Context) Export
	
	If ValueIsFilled(Result.ErrorDescription) Then
		Result = New Structure;
		Result.Insert("FullFileName", "");
		Result.Insert("ErrorDescription", Context.ErrorTitle + Result.ErrorDescription);
		ExecuteNotifyProcessing(Context.Notification, Result);
		Return;
	EndIf;
	
	Context.Insert("UserWorkingDirectory", Result.Directory);
	Context.Insert("FileDir", Context.UserWorkingDirectory + Context.FileData.RelativePath);
	Context.Insert("FullFileName", Context.FileDir + Context.FileData.FileName);
	
	ActionsWithFile = New Array;
	
	Action = New Structure;
	Action.Insert("Action", "CreateDirectory");
	Action.Insert("File", Context.FileDir);
	Action.Insert("ErrorTitle", Context.ErrorTitle +
		StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Directory is not created due to:';ru='Создание каталога не выполнено по причине:'"), Context.FileDir));
	ActionsWithFile.Add(Action);
	
	Action = New Structure;
	Action.Insert("Action", "SetProperties");
	Action.Insert("File",  Context.FullFileName);
	Action.Insert("Properties", New Structure("ReadOnly", False));
	Action.Insert("ErrorTitle", Context.ErrorTitle +
		StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='The ""View only"" property of the file is not changed due to:';ru='Изменение свойства файла ""Только просмотр"" не выполнено по причине:'"), Context.FullFileName));
	ActionsWithFile.Add(Action);
	
	Action = New Structure;
	Action.Insert("Action", "Delete");
	Action.Insert("File", Context.FullFileName);
	Action.Insert("ErrorTitle", Context.ErrorTitle +
		StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='File is not deleted due to:';ru='Удаление файла не выполнено по причине:'"), Context.FullFileName));
	ActionsWithFile.Add(Action);
	
	Action = New Structure;
	Action.Insert("Action", "Get");
	Action.Insert("File",  Context.FullFileName);
	Action.Insert("Address", Context.FileData.FileBinaryDataRef);
	Action.Insert("ErrorTitle", Context.ErrorTitle);
	ActionsWithFile.Add(Action);
	
	FileProperties = New Structure;
	FileProperties.Insert("ReadOnly", Not Context.ForEditing);
	FileProperties.Insert("UniversalModificationTime", Context.FileData.ModificationDateUniversal);
	
	Action = New Structure;
	Action.Insert("Action", "SetProperties");
	Action.Insert("File",  Context.FullFileName);
	Action.Insert("Properties", FileProperties);
	Action.Insert("ErrorTitle", Context.ErrorTitle +
		StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='File property is not set due to:';ru='Установка свойств файла не выполнено по причине:'"), Context.FullFileName));
	ActionsWithFile.Add(Action);
	
	FileFunctionsServiceClient.HandleFile(New NotifyDescription(
			"GetAttachedFileAfterProcessingFile", ThisObject, Context),
		ActionsWithFile, Context.FormID);
	
EndProcedure

// Continuation of the GetAttachedFile procedure.
Procedure GetAttachedFileAfterProcessingFile(ActionsResult, Context) Export
	
	Result = New Structure;
	
	If ValueIsFilled(ActionsResult.ErrorDescription) Then
		Result.Insert("FullFileName", "");
		Result.Insert("ErrorDescription", ActionsResult.ErrorDescription);
	Else
		Result.Insert("FullFileName", Context.FullFileName);
		Result.Insert("ErrorDescription", "");
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Working with digital signatures.

// Signs file using the DigitalSignature subsystem.
Procedure SignFile(AttachedFile, FileData, FormID, EndProcessor, HandlerOnReceiveSignature = Undefined) Export
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("EndProcessor", EndProcessor);
	ExecuteParameters.Insert("AttachedFile", AttachedFile);
	ExecuteParameters.Insert("FileData",        FileData);
	ExecuteParameters.Insert("FormID", FormID);
	
	DataDescription = New Structure;
	DataDescription.Insert("Operation",            NStr("en='Signing file';ru='Подписание файла'"));
	DataDescription.Insert("DataTitle",     NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("Presentation",       AttachedFile);
	DataDescription.Insert("ShowComment", True);
	
	DataDescription.Insert("Data", ExecuteParameters.FileData.FileBinaryDataRef);
	
	If HandlerOnReceiveSignature = Undefined Then
		DataDescription.Insert("Object", AttachedFile);
	Else
		DataDescription.Insert("Object", HandlerOnReceiveSignature);
	EndIf;
	
	ContinuationHandler = New NotifyDescription("AfterAddingSignatures", ThisObject, ExecuteParameters);
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.Sign(DataDescription, , ContinuationHandler);
	
EndProcedure

// Adds digital signatures to a file-object from the file-signatures on drive.
Procedure AddSignatureFromFile(AttachedFile, FormID, EndProcessor, HandlerOnReceiveSignature = Undefined) Export
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("EndProcessor", EndProcessor);
	ExecuteParameters.Insert("AttachedFile",   AttachedFile);
	
	DataDescription = New Structure;
	DataDescription.Insert("DataTitle",     NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("Presentation",       AttachedFile);
	DataDescription.Insert("ShowComment", True);
	
	If HandlerOnReceiveSignature = Undefined Then
		DataDescription.Insert("Object", AttachedFile);
	Else
		DataDescription.Insert("Object", HandlerOnReceiveSignature);
	EndIf;
	
	ContinuationHandler = New NotifyDescription("AfterAddingSignatures",
		ThisObject, ExecuteParameters);
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.AddSignatureFromFile(DataDescription,, ContinuationHandler);
	
EndProcedure

// End procedures SignFile, AddSignatureFromFile.
Procedure AfterAddingSignatures(DataDescription, ExecuteParameters) Export
	
	If DataDescription.Success Then
		NotifyChanged(ExecuteParameters.AttachedFile);
		Notify("Record_AttachedFile", New Structure, ExecuteParameters.AttachedFile);
	EndIf;
	
	If ExecuteParameters.EndProcessor <> Undefined Then
		ExecuteNotifyProcessing(ExecuteParameters.EndProcessor, DataDescription.Success);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Encryption.

// Encrypts file in the storage:
// - offers the user to select certificates for encryption,
// - performs file encryption,
// - writes the encrypted data along with the thumbprints into storage,
// - notifies the user and the system about changes.
// It is used in the file encryption command handler.
//
// Parameters:
//  AttachedFile - Ref to the file required to encrypt.
//  FileData        - Structure with file data.
//  FormID - UUID of the form.
// 
Procedure Encrypt(Val AttachedFile, Val FileData, Val FormID) Export
	
	Parameters = New Structure;
	Parameters.Insert("AttachedFile", AttachedFile);
	Parameters.Insert("FileData", FileData);
	NotifyDescription = New NotifyDescription("EncryptDataReceived", ThisObject, Parameters);
	GetEncryptedData(NOTifyDescription, AttachedFile, FileData, FormID);
	
EndProcedure

// Continue the procedure Encrypt.
Procedure EncryptDataReceived(ReceiptResult, AdditionalParameters) Export
	
	If ReceiptResult = Undefined Then
		Return;
	EndIf;
	
	EncryptedData = ReceiptResult.EncryptedData;
	ThumbprintArray = ReceiptResult.ThumbprintArray;
	FileData = AdditionalParameters.FileData;
	AttachedFile = AdditionalParameters.AttachedFile;
	
	AttachedFilesServiceServerCall.Encrypt(AttachedFile, EncryptedData, ThumbprintArray);
	NotifyAboutChangeAndDeleteFileInWorkDirectory(AttachedFile, FileData);
	
EndProcedure

// Encrypts binary data of the file with the certificates selected by user.
//
// Parameters:
//  ResultHandler - NotifyDescription - procedure in which it is necessary to delegate control upon completion.
//                         Parameters of called procedure:
//                          Result - Structure, Undefined - if data is not encrypted, it
//                                      is undefined, else it is structure:
//                           EncryptedData - Structure  - contains the encrypted file data (for recording).
//                           ThumbprintArray    - Array     - contains thumbprints.
//                          AdditionalParameters - Arbitrary - value that was specified when
//                                                                   notification object was created.
//  AttachedFile  - Ref to the file.
//  FileData         - Structure with file data.
//  FormID  - UUID of the form.
//
Procedure GetEncryptedData(ResultHandler, Val AttachedFile, Val FileData, Val FormID) Export
	
	If FileData.Encrypted Then
		ShowMessageBox(, StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='The"
"file ""%1"" is already encrypted.';ru='Файл"
"""%1"" уже зашифрован.'"), String(AttachedFile)));
		ExecuteNotifyProcessing(ResultHandler, Undefined);
		Return;
	EndIf;
	
	If ValueIsFilled(FileData.IsEditing) Then
		ShowMessageBox(, NStr("en='File locked for editing can not be encrypted.';ru='Нельзя зашифровать занятый файл.'"));
		ExecuteNotifyProcessing(ResultHandler, Undefined);
		Return;
	EndIf;
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ResultHandler", ResultHandler);
	AdditionalParameters.Insert("AttachedFile", AttachedFile);
	AdditionalParameters.Insert("FileData", FileData);
	AdditionalParameters.Insert("FormID", FormID);
	
	DataDescription = New Structure;
	DataDescription.Insert("Operation",            NStr("en='File encryption';ru='Шифрование файла'"));
	DataDescription.Insert("DataTitle",     NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("Data",              FileData.FileBinaryDataRef);
	DataDescription.Insert("Presentation",       AdditionalParameters.AttachedFile);
	DataDescription.Insert("NotifyAboutCompletion", False);
	
	ContinuationHandler = New NotifyDescription("AfterEncryptingFile", ThisObject, AdditionalParameters);
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.Encrypt(DataDescription, , ContinuationHandler);
	
EndProcedure

// Ending the Encrypt procedure. Called from the DigitalSignature subsystem.
Procedure AfterEncryptingFile(DataDescription, AdditionalParameters) Export
	
	Result = Undefined;
	
	If DataDescription.Success Then
		Result = New Structure;
		
		If TypeOf(DataDescription.EncryptionCertificates) = Type("String") Then
			Result.Insert("ThumbprintArray", GetFromTempStorage(
				DataDescription.EncryptionCertificates));
		Else
			Result.Insert("ThumbprintArray", DataDescription.EncryptionCertificates);
		EndIf;
		
		EncryptedData = DataDescription.EncryptedData;
		If TypeOf(EncryptedData) = Type("BinaryData") Then
			TemporaryStorageAddress = PutToTempStorage(EncryptedData,
				AdditionalParameters.FormID);
		Else
			TemporaryStorageAddress = EncryptedData;
		EndIf;
		EncryptedData = New Structure;
		EncryptedData.Insert("TemporaryStorageAddress", TemporaryStorageAddress);
		Result.Insert("EncryptedData", EncryptedData);
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, Result);
	
EndProcedure


// Deletes the file from the working directory, notifies the open forms about changes.
Procedure NotifyAboutChangeAndDeleteFileInWorkDirectory(Val AttachedFile, Val FileData) Export
	
	NotifyChanged(AttachedFile);
	Notify("Record_AttachedFile", New Structure, AttachedFile);
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
		ModuleDigitalSignatureClient.InformAboutObjectEncryption(
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='File: %1';ru='Файл: %1'"), AttachedFile));
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("AttachedFile", AttachedFile);
	Parameters.Insert("FileData", FileData);
	
	NotifyDescription = New NotifyDescription("NotifyAboutChangeAndDeleteFileInWorkDirectoryExtensionRequested", ThisObject, Parameters);
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(NOTifyDescription);
	
EndProcedure

Procedure NotifyAboutChangeAndDeleteFileInWorkDirectoryExtensionRequested(FileOperationsExtensionConnected, AdditionalParameters) Export
	
	AttachedFile = AdditionalParameters.AttachedFile;
	FileData = AdditionalParameters.FileData;
	
	If FileOperationsExtensionConnected Then
		UserWorkingDirectory = FileFunctionsServiceClient.UserWorkingDirectory();
		FullPathToFile = UserWorkingDirectory + FileData.FileName;
		
		File = New File(FullPathToFile);
		If File.Exist() Then
			Try
				File.SetReadOnly(False);
				DeleteFiles(FullPathToFile);
			Except
				// Trying to delete file from drive.
			EndTry;
		EndIf;
	EndIf;
	
EndProcedure

// Decrypts file in the storage:
// - shows user a dialog prompting to decrypt the file,
// - receives binary data and array of thumbprints,
// - performs decryption
// - writes the decrypted file data into storage.
// It is used as the file decryption command handler.
//
// Parameters:
//  AttachedFile - Ref to the file.
//  FileData        - Structure with file data.
//  FormID - UUID of the form.
//
Procedure Decrypt(Val AttachedFile, Val FileData, Val FormID) Export
	
	NotifyDescription = New NotifyDescription("DecryptDataReceived", ThisObject, AttachedFile);
	GetDecryptedData(NOTifyDescription, AttachedFile, FileData, FormID);
	
EndProcedure

// Continue the procedure Decrypt.
Procedure DecryptDataReceived(DecryptedData, AttachedFile) Export
	If DecryptedData = Undefined Then
		Return;
	EndIf;
	
	AttachedFilesServiceServerCall.Decrypt(AttachedFile, DecryptedData);
	NotifyAboutFileDecrypting(AttachedFile);
EndProcedure

// Receives the decrypted file data.
//
// Parameters:
//  ResultHandler - NotifyDescription - procedure in which it is necessary to delegate control upon completion.
//                         Parameters of called procedure:
//                          DecryptedData - Structure, Undefined - contains the decrypted
//                                                 data, or Undefined if decrypton was not performed.
//                          AdditionalParameters - Arbitrary - value that was specified when
//                                                                   notification object was created.
//  AttachedFile   - Ref to the file.
//  FileData          - Structure with file data.
//  FormID   - UUID of the form.
// 
Procedure GetDecryptedData(ResultHandler, Val AttachedFile, Val FileData, Val FormID) Export
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ResultHandler", ResultHandler);
	AdditionalParameters.Insert("AttachedFile", AttachedFile);
	AdditionalParameters.Insert("FileData", FileData);
	AdditionalParameters.Insert("FormID", FormID);
	
	DataDescription = New Structure;
	DataDescription.Insert("Operation",              NStr("en='File decryption';ru='Расшифровка файла'"));
	DataDescription.Insert("DataTitle",       NStr("en='File';ru='Файловый'"));
	DataDescription.Insert("Data",                FileData.FileBinaryDataRef);
	DataDescription.Insert("Presentation",         AdditionalParameters.AttachedFile);
	DataDescription.Insert("EncryptionCertificates", AdditionalParameters.AttachedFile);
	DataDescription.Insert("NotifyAboutCompletion",   False);
	
	ContinuationHandler = New NotifyDescription("AfterFileDecryption", ThisObject, AdditionalParameters);
	
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.Decrypt(DataDescription, , ContinuationHandler);
	
EndProcedure

// Ending the Decrypt procedure. Called from the DigitalSignature subsystem.
Procedure AfterFileDecryption(DataDescription, AdditionalParameters) Export
	
	Result = Undefined;
	
	If DataDescription.Success Then
		
		DecryptedData = DataDescription.DecryptedData;
		If TypeOf(DecryptedData) = Type("BinaryData") Then
			TemporaryStorageAddress = PutToTempStorage(DecryptedData,
				AdditionalParameters.FormID);
		Else
			TemporaryStorageAddress = DecryptedData;
		#If Not WebClient Then
			DecryptedData = GetFromTempStorage(DecryptedData);
		#EndIf
		EndIf;
		
	#If WebClient Then
		TextTemporaryStorageAddress = "";
	#Else
		ExtractFileTextsAtServer =
			FileFunctionsServiceClientServer.FileOperationsCommonSettings().ExtractFileTextsAtServer;
		
		If Not ExtractFileTextsAtServer Then
			
			FullPathToFile = GetTempFileName(AdditionalParameters.FileData.Extension);
			DecryptedData.Write(FullPathToFile);
			
			TextTemporaryStorageAddress =
				FileFunctionsServiceClientServer.ExtractTextToTemporaryStorage(
					FullPathToFile, AdditionalParameters.FormID);
			
			DeleteFiles(FullPathToFile);
		Else
			TextTemporaryStorageAddress = "";
		EndIf;
	#EndIf
		
		Result = New Structure;
		Result.Insert("TemporaryStorageAddress", TemporaryStorageAddress);
		Result.Insert("TextTemporaryStorageAddress", TextTemporaryStorageAddress);
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, Result);
	
EndProcedure

// Notifies the user and the system about the file decryption.
// 
// Parameters:
//  AttachedFile - Ref to the file.
//
Procedure NotifyAboutFileDecrypting(Val AttachedFile) Export
	
	NotifyChanged(AttachedFile);
	Notify("Record_AttachedFile", New Structure, AttachedFile);
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	ModuleDigitalSignatureClient = CommonUseClient.CommonModule("DigitalSignatureClient");
	ModuleDigitalSignatureClient.InformAboutObjectDecryption(
		StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='File: %1';ru='Файл: %1'"), AttachedFile));
	
EndProcedure

// Places the files from drive into storage of attached files.
// 
// Parameters:
//  SelectedFiles                 - Array - paths to files on the drive.
//  FileOwner                  - Ref to the file owner.
//  FileOperationsSettings        - Structure.
//  AttachedFilesArray      - Array (return value) - filled
//                                   with refs to added files.
//  FormID             - UUID of the form.
//
Procedure PlaceSelectedFilesToStorage(Val SelectedFiles,
                                            Val FileOwner,
                                            AttachedFilesArray,
                                            Val FormID) Export
	
	CommonSettings = FileFunctionsServiceClientServer.FileOperationsCommonSettings();
	
	CurrentPosition = 0;
	
	LastSavedFile = Undefined;
	
	For Each FullFileName IN SelectedFiles Do
		
		CurrentPosition = CurrentPosition + 1;
		
		File = New File(FullFileName);
		
		FileFunctionsServiceClientServer.CheckFileImportingPossibility(File);
		
		If CommonSettings.ExtractFileTextsAtServer Then
			TextTemporaryStorageAddress = "";
		Else
			TextTemporaryStorageAddress =
				FileFunctionsServiceClientServer.ExtractTextToTemporaryStorage(
					FullFileName, FormID);
		EndIf;
	
		ModificationTimeUniversal = File.GetModificationUniversalTime();
		
		UpdateStateAboutFileSaving(SelectedFiles, File, CurrentPosition);
		LastSavedFile = File;
		
		FilesToPlace = New Array;
		Definition = New TransferableFileDescription(File.FullName, "");
		FilesToPlace.Add(Definition);
		
		PlacedFiles = New Array;
		
		If Not PutFiles(FilesToPlace, PlacedFiles, , False, FormID) Then
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Error when"
"placing"
"the %1 file into a temporary storage.';ru='Ошибка"
"при"
"помещении файла ""%1"" во временное хранилище.'"),
					File.FullName) );
			Continue;
		EndIf;
		
		FileTemporaryStorageAddress = PlacedFiles[0].Location;
		
		// Creating of the File card in database.
		AttachedFile = AttachedFilesServiceServerCall.AddFile(
			FileOwner,
			File.BaseName,
			CommonUseClientServer.ExtensionWithoutDot(File.Extension),
			,
			ModificationTimeUniversal,
			FileTemporaryStorageAddress,
			TextTemporaryStorageAddress);
		
		If AttachedFile = Undefined Then
			Continue;
		EndIf;
		
		AttachedFilesArray.Add(AttachedFile);
		
	EndDo;
	
	UpdateStateAboutFileSaving(SelectedFiles, LastSavedFile);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

Procedure UpdateStateAboutFileSaving(Val SelectedFiles, Val File, Val CurrentPosition = Undefined);
	
	If File = Undefined Then
		Return;
	EndIf;
	
	SizeInMB = FileFunctionsServiceClientServer.GetStringWithFileSize(File.Size() / (1024 * 1024));
	
	If SelectedFiles.Count() > 1 Then
		
		If CurrentPosition = Undefined Then
			Status(NStr("en='File saving has been completed.';ru='Сохранение файлов завершено.'"));
		Else
			IndicatorPercent = CurrentPosition * 100 / SelectedFiles.Count();
			
			LabelMore = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='The %1 file is being saved (%2 Mb)...';ru='Сохраняется файл ""%1"" (%2 Мб) ...'"), File.Name, SizeInMB);
				
			StatusText = NStr("en='Several files saving.';ru='Сохранение нескольких файлов.'");
			
			Status(StatusText, IndicatorPercent, LabelMore, PictureLib.Information32);
		EndIf;
	Else
		If CurrentPosition = Undefined Then
			ExplanationText = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='The %1 file"
"(%2 Mb) is saved.';ru='Сохранение"
"файла ""%1"" (%2 Мб) завершено.'"), File.Name, SizeInMB);
		Else
			ExplanationText = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Is Saved file ""%1"" (%2 MB)."
"You Are Welcome, please wait...';ru='Сохраняется файл ""%1"" (%2 Мб)."
"Пожалуйста, подождите...'"), File.Name, SizeInMB);
		EndIf;
		Status(ExplanationText);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Continuations of asynchronous procedures.

// Continuation of the AttachedFilesClient procedure.OpenFile.
Procedure OpenFileExtensionRequested(FileOperationsExtensionConnected, AdditionalParameters) Export
	
	FileData = AdditionalParameters.FileData;
	ForEditing = AdditionalParameters.ForEditing;
	
	If FileOperationsExtensionConnected Then
		UserWorkingDirectory = FileFunctionsServiceClient.UserWorkingDirectory();
		FullFileNameAtClient = UserWorkingDirectory + FileData.RelativePath + FileData.FileName;
		FileOnDrive = New File(FullFileNameAtClient);
		
		AdditionalParameters.Insert("ForEditing", ForEditing);
		AdditionalParameters.Insert("UserWorkingDirectory", UserWorkingDirectory);
		AdditionalParameters.Insert("FileOnDrive", FileOnDrive);
		AdditionalParameters.Insert("FullFileNameAtClient", FullFileNameAtClient);
		
		If ValueIsFilled(FileData.IsEditing) AND ForEditing AND FileOnDrive.Exist() Then
			FileOnDrive.SetReadOnly(False);
			GetFile = False;
		ElsIf FileOnDrive.Exist() Then
			NotifyDescription = New NotifyDescription("OpenFileDialogIsShown", ThisObject, AdditionalParameters);
			ShowDialogNeedToGetFileFromServer(NOTifyDescription, FullFileNameAtClient, FileData, ForEditing);
			Return;
		Else
			GetFile = True;
		EndIf;
		
		OpenFileDialogIsShown(GetFile, AdditionalParameters);
	Else
		NotifyDescription = New NotifyDescription("OpenFileReminderShows", ThisObject, AdditionalParameters);
		FileFunctionsServiceClient.DisplayReminderOnEditing(NOTifyDescription);
	EndIf;
	
EndProcedure

// Continuation of the AttachedFilesClient procedure.OpenFile.
Procedure OpenFileDialogIsShown(GetFile, AdditionalParameters) Export
	If GetFile = Undefined Then
		Return;
	EndIf;
	
	FileData = AdditionalParameters.FileData;
	ForEditing = AdditionalParameters.ForEditing;
	UserWorkingDirectory = AdditionalParameters.UserWorkingDirectory;
	FileOnDrive = AdditionalParameters.FileOnDrive;
	FullFileNameAtClient = AdditionalParameters.FullFileNameAtClient;
	
	FileCanBeOpened = True;
	If GetFile Then
		FullFileNameAtClient = "";
		FileCanBeOpened = GetFileIntoWorkingDirectory(
			FileData.FileBinaryDataRef,
			FileData.RelativePath,
			FileData.ModificationDateUniversal,
			FileData.FileName,
			UserWorkingDirectory,
			FullFileNameAtClient);
	EndIf;
		
	If FileCanBeOpened Then
		If ForEditing Then
			FileOnDrive.SetReadOnly(False);
		Else
			FileOnDrive.SetReadOnly(True);
		EndIf;
		OpenFileByApplication(FullFileNameAtClient, FileData);
	EndIf;
		
EndProcedure

// Continuation of the AttachedFilesClient procedure.OpenFile.
Procedure OpenFileReminderShows(ResultReminders, AdditionalParameters) Export
	
	If ResultReminders = Undefined Then
		Return;
	EndIf;
	
	FileData = AdditionalParameters.FileData;
	GetFile(FileData.FileBinaryDataRef, FileData.FileName, True);
	
EndProcedure

// Continuation of the AttachedFilesClient procedure.AddFiles.
Procedure AddFilesExtensionRequested(FileOperationsExtensionConnected, AdditionalParameters) Export
	
	FileOwner = AdditionalParameters.FileOwner;
	FormID = AdditionalParameters.FormID;
	Filter = AdditionalParameters.Filter;
	
	If FileOperationsExtensionConnected Then
		
		FileChoice = New FileDialog(FileDialogMode.Open);
		FileChoice.Multiselect = True;
		FileChoice.Title = NStr("en='Select file';ru='Выбор файла'");
		FileChoice.Filter = ?(ValueIsFilled(Filter), Filter, NStr("en='All files';ru='Все файлы'") + " (*.*)|*.*");
		
		If FileChoice.Choose() Then
			AttachedFilesArray = New Array;
			PlaceSelectedFilesToStorage(
				FileChoice.SelectedFiles,
				FileOwner,
				AttachedFilesArray,
				FormID);
			
			If AttachedFilesArray.Count() = 1 Then
				AttachedFile = AttachedFilesArray[0];
				
				ShowUserNotification(
					NStr("en='Creating:';ru='Создание:'"),
					GetURL(AttachedFile),
					AttachedFile,
					PictureLib.Information32);
				
				FormParameters = New Structure("AttachedFile, IsNew", AttachedFile, True);
				OpenForm("CommonForm.AttachedFile", FormParameters, , AttachedFile);
			EndIf;
			
			If AttachedFilesArray.Count() > 0 Then
				NotifyChanged(AttachedFilesArray[0]);
				Notify("Record_AttachedFile", New Structure("IsNew", True), AttachedFilesArray);
			EndIf;
		
		EndIf;
		
	Else // If the web client has no extension installed.
		NotifyDescription = New NotifyDescription("AddFilesEnd", ThisObject);
		PlaceSelectedFilesIntoWebStorage(NOTifyDescription, FileOwner, FormID);
	EndIf;
	
EndProcedure

// Continuation of the AttachedFilesClient procedure.AddFiles.
Procedure AddFilesEnd(AttachedFile, AdditionalParameters) Export
	
	If AttachedFile = Undefined Then
		Return;
	EndIf;
	
	ShowUserNotification(
		NStr("en='Creating';ru='Создание'"),
		GetURL(AttachedFile),
		AttachedFile,
		PictureLib.Information32);
		
	NotifyChanged(AttachedFile);
		
	FormParameters = New Structure("AttachedFile", AttachedFile);
	OpenForm("CommonForm.AttachedFile", FormParameters, , AttachedFile);
	
EndProcedure

// Continuation of the AttachedFilesClient.SaveWithDS procedure.
// It is called from the DigitalSignature subsystem after selection of the signature for saving.
//
Procedure WhenYouSaveDataFile(Parameters, ExecuteParameters) Export
	
	ExtensionAttached = FileFunctionsServiceClient.FileOperationsExtensionConnected();
	
	ExecuteParameters.Insert("EndProcessor", Parameters.Notification);
	SaveFileAsExtensionRequested(ExtensionAttached, ExecuteParameters);
	
EndProcedure

// Continuation of the AttachedFilesClient procedure.SaveFileAs.
Procedure SaveFileAsExtensionRequested(FileOperationsExtensionConnected, AdditionalParameters) Export
	
	FileData = AdditionalParameters.FileData;
	FullFileName = "";
	If FileOperationsExtensionConnected Then
		
		FileChoice = New FileDialog(FileDialogMode.Save);
		FileChoice.Multiselect = False;
		FileChoice.FullFileName = FileData.FileName;
		FileChoice.Extension = FileData.Extension;
		FileChoice.Filter = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='All files (*.%1)|*.%1';ru='Все файлы (*.%1)|*.%1'"), FileData.Extension);
		
		If Not FileChoice.Choose() Then
			Return;
		EndIf;
		
		SizeInMB = FileData.Size / (1024 * 1024);
		
		ExplanationText =
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='The %1 file (%2"
"Mb) is being saved. Please wait...';ru='Сохраняется файл ""%1"" (%2 Мб) Пожалуйста, подождите.'"),
				FileData.FileName, 
				FileFunctionsServiceClientServer.GetStringWithFileSize(SizeInMB) );
		
		Status(ExplanationText);
		
		ReceivedFile = New TransferableFileDescription(FileChoice.FullFileName, FileData.FileBinaryDataRef);
		FilesToReceive = New Array;
		FilesToReceive.Add(ReceivedFile);
		
		ReceivedFiles = New Array;
		
		If GetFiles(FilesToReceive, ReceivedFiles, , False) Then
			Status(NStr("en='The file is successfully saved.';ru='Файл успешно сохранен.'"), , FileChoice.FullFileName);
		EndIf;
		FullFileName = FileChoice.FullFileName;
	Else
		FullFileName = FileData.FileName;
		GetFile(FileData.FileBinaryDataRef, FullFileName, True);
	EndIf;
	
	If AdditionalParameters.Property("EndProcessor") Then
		ExecuteNotifyProcessing(AdditionalParameters.EndProcessor,
			New Structure("FullFileName", FullFileName));
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

Procedure ShowDialogNeedToGetFileFromServer(ResultHandler, Val FileNameWithPath, Val FileData, Val ForEditing)
	
	FileStandardData = New Structure;
	FileStandardData.Insert("ModificationDateUniversal", FileData.ModificationDateUniversal);
	FileStandardData.Insert("Size",                       FileData.Size);
	FileStandardData.Insert("InWorkingDirectoryForRead",     Not ForEditing);
	FileStandardData.Insert("IsEditing",                  FileData.IsEditing);
	
	// It was found out that the File exists in the working directory.
	// Date change checking and decision making, what is the next step.
	
	Parameters = New Structure;
	Parameters.Insert("ResultHandler", ResultHandler);
	Parameters.Insert("FileNameWithPath", FileNameWithPath);
	NotifyDescription = New NotifyDescription("ShowDialogNeedToGetFileFromServerActionDetermined", ThisObject, Parameters);
	FileFunctionsServiceClient.ActionOnFileOpeningInWorkingDirectory(
		NotifyDescription, FileNameWithPath, FileStandardData);
EndProcedure

// Continuation of the ShowDialogNeedToGetFileFromServer procedure.
Procedure ShowDialogNeedToGetFileFromServerActionDetermined(Action, AdditionalParameters) Export
	FileNameWithPath = AdditionalParameters.FileNameWithPath;
	
	If Action = "TakeFromStorageAndOpen" Then
		File = New File(FileNameWithPath);
		File.SetReadOnly(False);
		DeleteFiles(FileNameWithPath);
		Result = True;
	ElsIf Action = "OpenExisting" Then
		Result = False;
	Else // Action = "Cancel".
		Result = Undefined;
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, Result);
	
EndProcedure

Procedure OpenFileByApplication(Val FileNameToOpen, FileData)
	
	ExtensionAttached = FileFunctionsServiceClient.FileOperationsExtensionConnected();
	
	If ExtensionAttached Then
		TitleString = CommonUseClientServer.GetNameWithExtention(
			FileData.Description, FileData.Extension);
		
		If Lower(FileData.Extension) = Lower("grs") Then
			Schema = New GraphicalSchema; 
			Schema.Read(FileNameToOpen);
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
			
			OpenParameters = New Structure;
			OpenParameters.Insert("DocumentName", TitleString);
			OpenParameters.Insert("PathToFile", FileNameToOpen);
			OpenParameters.Insert("SpreadsheetDocument", SpreadsheetDocument);
			
			OpenForm("CommonForm.EditSpreadsheetDocument", OpenParameters);
			Return;
		EndIf;
		
		// File opening.
		Try
			RunApp(FileNameToOpen);
		Except
			ErrorInfo = ErrorInfo();
			ShowMessageBox(, StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='While opening"
"the"
"%1 file"
"the error occurred: ""%2"".';ru='При"
"открытии"
"файла"
"""%1"" произошла ошибка: ""%2"".'"),
				FileNameToOpen,
				ErrorInfo.Definition));
		EndTry;
	EndIf;
EndProcedure

// Updates file data from the file selected by user.
// It is used as a command handler for updating the attached file from another file.
//
// Parameters:
//  AttachedFile - Ref to the file.
//  FileData        - Structure - file data.
//  FormID - UUID of the form.
//
Procedure UpdateAttachedFile(Val AttachedFile, Val FileData, Val FormID) Export
	
	NotifyDescription = New NotifyDescription("UpdateAttachedFileRoomCompleted", ThisObject, AttachedFile);
	SelectFileOnDriveAndPlaceIntoStorage(NOTifyDescription, FileData, FormID);
	
EndProcedure

// Continuation of the UpdateAttachedFile procedure.
Procedure UpdateAttachedFileRoomCompleted(InformationAboutFile, AttachedFile) Export
	
	If InformationAboutFile = Undefined
		Or Not InformationAboutFile.FilePlacedToStorage Then
		Return;
	EndIf;
	
	AttachedFilesServiceServerCall.UpdateAttachedFile(AttachedFile, InformationAboutFile);
	NotifyChanged(AttachedFile);
	
EndProcedure

#EndRegion
