
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	FolderForAdding = Parameters.FolderForAdding;
	
	For Each FilePath IN Parameters.FileNameArray Do
		FileNameList.Add(FilePath);
	EndDo;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	#If WebClient Then
		WarningText =
			NStr("en='File import is not supported in the Web client.
		|Use the Create command in files list.';ru='В Веб-клиенте импорт файлов не поддерживается.
		|Используйте команду ""Создать"" в списке файлов.'");
		ShowMessageBox(, WarningText);
		Cancel = True;
		Return;
	#EndIf
	
	StoreVersions = True;
	DirectoriesOnly = True;
	
	For Each FilePath IN FileNameList Do
		FillFileList(FilePath, FileTree.GetItems(), True, DirectoriesOnly);
	EndDo;
	
	If DirectoriesOnly Then
		Title = NStr("en='folders Import';ru='Загрузка папок'");
	EndIf;
	
	Status();
	
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

#Region FormTableItemEventHandlersFileTree

&AtClient
Procedure FileTreeCheckOnChange(Item)
	DataItem = FileTree.FindByID(Items.FileTree.CurrentRow);
	SetMark(DataItem, DataItem.Check);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ImportFiles()
	
	ClearMessages();
	
	FieldsNotFilled = False;
	
	PseudoFileSystem = New Map; // Map path to the directory - files and folders in it.
	
	SelectedFiles = New ValueList;
	For Each AttachedFile IN FileTree.GetItems() Do
		If AttachedFile.Check = True Then
			SelectedFiles.Add(AttachedFile.FullPath);
		EndIf;
	EndDo;
	
	For Each AttachedFile IN FileTree.GetItems() Do
		FillFileSystem(PseudoFileSystem, AttachedFile);
	EndDo;
	
	If SelectedFiles.Count() = 0 Then
		CommonUseClientServer.MessageToUser(
			NStr("en='There are no files for adding.';ru='Нет файлов для добавления.'"), , "SelectedFiles");
		FieldsNotFilled = True;
	EndIf;
	
	If FolderForAdding.IsEmpty() Then
		CommonUseClientServer.MessageToUser(
			NStr("en='Specify the folder.';ru='Укажите папку.'"), , "FolderForAdding");
		FieldsNotFilled = True;
	EndIf;
	
	If FieldsNotFilled = True Then
		Return;
	EndIf;
	
	ExecuteParameters = FileOperationsServiceClient.FileImportParameters();
	ExecuteParameters.ResultHandler = New NotifyDescription("AddExecuteAfterImport", ThisObject);
	ExecuteParameters.Owner = FolderForAdding;
	ExecuteParameters.SelectedFiles = SelectedFiles; 
	ExecuteParameters.Comment = Comment;
	ExecuteParameters.StoreVersions = StoreVersions;
	ExecuteParameters.DeleteFilesAfterAdd = DeleteFilesAfterAdd;
	ExecuteParameters.Recursively = True;
	ExecuteParameters.FormID = UUID;
	ExecuteParameters.PseudoFileSystem = PseudoFileSystem;
	ExecuteParameters.Encoding = FileTextEncoding;
	FileOperationsServiceClient.ImportFilesExecute(ExecuteParameters);
	
EndProcedure

&AtClient
Procedure SelectEncoding(Command)
	FormParameters = New Structure;
	FormParameters.Insert("CurrentEncoding", FileTextEncoding);
	OpenForm("Catalog.Files.Form.EncodingChoice", FormParameters, ThisObject);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure AddExecuteAfterImport(Result, ExecuteParameters) Export
	Close();
	Notify("DirectoryImportCompleted", New Structure, Result.FolderForAddCurrent);
EndProcedure

&AtClient
Procedure FillFileList(FilePath, Val TreeItems, TopLevelItem, DirectoriesOnly = Undefined)
	
	MovedFile = New File(FilePath);
	
	NewItem = TreeItems.Add();
	NewItem.FullPath = MovedFile.FullName;
	NewItem.FileName = MovedFile.Name;
	NewItem.Check = True;
	
	If MovedFile.Extension = "" Then
		NewItem.PictureIndex = 2; // Folder
	Else
		NewItem.PictureIndex = FileFunctionsServiceClientServer.GetFileIconIndex(MovedFile.Extension);
	EndIf;
			
	If MovedFile.IsDirectory() Then
		
		Path = MovedFile.FullName + CommonUseClientServer.PathSeparator();
		
		If TopLevelItem = True Then
			Status(StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='There is a collection
		|of directory information ""%1"".
		|Please, wait.';ru='Идет
		|сбор информации о каталоге ""%1"".
		|Пожалуйста, подождите.'"),
				Path));
		EndIf;
		
		FoundFiles = FindFiles(Path, "*.*");
		
		FileSorted = New Array;
		
		// folders first
		For Each AttachedFile IN FoundFiles Do
			If AttachedFile.IsDirectory() Then
				FileSorted.Add(AttachedFile.FullName);
			EndIf;
		EndDo;
		
		// then files
		For Each AttachedFile IN FoundFiles Do
			If Not AttachedFile.IsDirectory() Then
				FileSorted.Add(AttachedFile.FullName);
			EndIf;
		EndDo;
		
		For Each AttachedFile IN FileSorted Do
			FillFileList(AttachedFile, NewItem.GetItems(), False);
		EndDo;
		
	Else
		
		If TopLevelItem Then
			DirectoriesOnly = False;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillFileSystem(PseudoFileSystem, TreeItem)
	If TreeItem.Check = True Then
		ChildItems = TreeItem.GetItems();
		If ChildItems.Count() <> 0 Then
			
			FilesAndSubdirectories = New Array;
			For Each AttachedFile IN ChildItems Do
				FillFileSystem(PseudoFileSystem, AttachedFile);
				
				If AttachedFile.Check = True Then
					FilesAndSubdirectories.Add(AttachedFile.FullPath);
				EndIf;
			EndDo;
			
			PseudoFileSystem.Insert(TreeItem.FullPath, FilesAndSubdirectories);
		EndIf;
	EndIf;
EndProcedure

// Marks all child items recursively.
&AtClient
Procedure SetMark(TreeItem, Check)
	ChildItems = TreeItem.GetItems();
	
	For Each AttachedFile IN ChildItems Do
		AttachedFile.Check = Check;
		SetMark(AttachedFile, Check);
	EndDo;
EndProcedure

&AtServer
Procedure SetEncodingCommandPresentation(Presentation)
	
	Commands.SelectEncoding.Title = Presentation;
	
EndProcedure

#EndRegion














