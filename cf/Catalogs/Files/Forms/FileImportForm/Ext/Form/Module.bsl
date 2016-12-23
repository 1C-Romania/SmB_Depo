
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Parameters.Property("FolderForAdding") Then
		CommonUseClientServer.MessageToUser(
			NStr("en='This data processor is called from the other configuration procedures.
		|Prohibited to call it manually.';ru='Данная обработка вызывается из других процедур конфигурации.
		|Вручную ее вызывать запрещено.'"));
		Cancel = True;
		Return;
	EndIf;
	
	If Parameters.FolderForAdding <> Undefined Then
		FilesOwner = Parameters.FolderForAdding;
		If TypeOf(FilesOwner) = Type("CatalogRef.FileFolders") Then
			FolderForAdding = FilesOwner;
		Else
			Items.FolderForAdding.Visible = False;
		EndIf;	
	EndIf;
	
	If Parameters.FileNameArray <> Undefined Then
		For Each FilePath IN Parameters.FileNameArray Do
			MovedFile = New File(FilePath);
			NewItem = SelectedFiles.Add();
			NewItem.Path = FilePath;
			NewItem.PictureIndex = FileFunctionsServiceClientServer.GetFileIconIndex(MovedFile.Extension);
		EndDo;
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	StoreVersions = True;
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	If Upper(ChoiceSource.FormName) = Upper("Catalog.Files.Form.EncodingChoice") Then
		If TypeOf(ValueSelected) <> Type("Structure") Then
			Return;
		EndIf;
		FileTextEncoding = ValueSelected.Value;
		EncodingPresentation = ValueSelected.Presentation;
		SetEncodingCommandPresentation(EncodingPresentation);
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersSelectedFiles

&AtClient
Procedure SelectedFilesBeforeAddRow(Item, Cancel, Copy)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure AddRun()
	
	ClearMessages();
	
	FieldsNotFilled = False;
	
	If SelectedFiles.Count() = 0 Then
		CommonUseClientServer.MessageToUser(
			NStr("en='There are no files for adding.';ru='Нет файлов для добавления.'"), , "SelectedFiles");
		FieldsNotFilled = True;
	EndIf;
	
	FilesOwnerForAdd = FilesOwner;
	If TypeOf(FilesOwner) = Type("CatalogRef.FileFolders") Then
		FilesOwnerForAdd = FolderForAdding;
	EndIf;

	If FilesOwnerForAdd.IsEmpty() Then
		CommonUseClientServer.MessageToUser(
			NStr("en='Specify the folder.';ru='Укажите папку.'"), , "FolderForAdding");
		FieldsNotFilled = True;
	EndIf;
	
	If FieldsNotFilled = True Then
		Return;
	EndIf;
	
	SelectedFilesValueList = New ValueList;
	For Each ListRow IN SelectedFiles Do
		SelectedFilesValueList.Add(ListRow.Path);
	EndDo;
	
	#If WebClient Then
		
		OperationArray = New Array;
		
		For Each ListRow IN SelectedFiles Do
			CallDetails = New Array;
			CallDetails.Add("PutFiles");
			
			FilesToPlace = New Array;
			Definition = New TransferableFileDescription(ListRow.Path, "");
			FilesToPlace.Add(Definition);
			CallDetails.Add(FilesToPlace);
			
			CallDetails.Add(Undefined);  // not used
			CallDetails.Add(Undefined);  // not used
			CallDetails.Add(False); 			// Interactively = False
			
			OperationArray.Add(CallDetails);
		EndDo;
		
		If Not RequestUserPermission(OperationArray) Then
			// User didn't permit.
			Close();
			Return;
		EndIf;	
	#EndIf	
	
	AddedFiles = New Array;
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("AddedFiles", AddedFiles);
	Handler = New NotifyDescription("AddRunEnd", ThisObject, HandlerParameters);
	
	ExecuteParameters = FileOperationsServiceClient.FileImportParameters();
	ExecuteParameters.ResultHandler = Handler;
	ExecuteParameters.Owner = FilesOwnerForAdd;
	ExecuteParameters.SelectedFiles = SelectedFilesValueList; 
	ExecuteParameters.Comment = Comment;
	ExecuteParameters.StoreVersions = StoreVersions;
	ExecuteParameters.DeleteFilesAfterAdd = DeleteFilesAfterAdd;
	ExecuteParameters.Recursively = False;
	ExecuteParameters.FormID = UUID;
	ExecuteParameters.AddedFiles = AddedFiles;
	ExecuteParameters.Encoding = FileTextEncoding;
	
	FileOperationsServiceClient.ImportFilesExecute(ExecuteParameters);
EndProcedure

&AtClient
Procedure ChooseFilesRun()
	
	Handler = New NotifyDescription("SelectFilesExecuteAfterExtensionInstallation", ThisObject);
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(Handler);
	
EndProcedure

&AtClient
Procedure SelectEncoding(Command)
	FormParameters = New Structure;
	FormParameters.Insert("CurrentEncoding", FileTextEncoding);
	OpenForm("Catalog.Files.Form.EncodingChoice", FormParameters, ThisObject);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetEncodingCommandPresentation(Presentation)
	
	Commands.SelectEncoding.Title = Presentation;
	
EndProcedure

&AtClient
Procedure AddRunEnd(Result, ExecuteParameters) Export
	Close();
	
	NotificationParameter = Undefined;
	If ExecuteParameters.AddedFiles.Count() > 0 Then
		IndexOf = ExecuteParameters.AddedFiles.Count() - 1;
		NotificationParameter = ExecuteParameters.AddedFiles[IndexOf].FileRef;
	EndIf;
	Notify("FileImportCompleted", NotificationParameter);
EndProcedure

&AtClient
Procedure SelectFilesExecuteAfterExtensionInstallation(ExtensionIsSet, ExecuteParameters) Export
	If Not ExtensionIsSet Then
		Return;
	EndIf;
	
	Mode = FileDialogMode.Open;
	
	FileOpeningDialog = New FileDialog(Mode);
	FileOpeningDialog.FullFileName = "";
	Filter = NStr("en='All files(*.*)|*.*';ru='Все файлы(*.*)|*.*'");
	FileOpeningDialog.Filter = Filter;
	FileOpeningDialog.Multiselect = True;
	FileOpeningDialog.Title = NStr("en='Select files';ru='Выбрать файлы'");
	If FileOpeningDialog.Choose() Then
		SelectedFiles.Clear();
		
		FilesArray = FileOpeningDialog.SelectedFiles;
		For Each FileName IN FilesArray Do
			MovedFile = New File(FileName);
			NewItem = SelectedFiles.Add();
			NewItem.Path = FileName;
			NewItem.PictureIndex = FileFunctionsServiceClientServer.GetFileIconIndex(MovedFile.Extension);
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion














