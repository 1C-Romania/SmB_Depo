
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ConditionalAppearance.Items.Clear();
	FileOperationsServiceServerCall.FillFileListConditionalAppearance(List);
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.Property("Folder") = True AND Parameters.Folder <> Undefined Then
		InitialFolder = Parameters.Folder;
	Else
		InitialFolder = CommonUse.FormDataSettingsStorageImport("Files", "CurrentFolder");
		If InitialFolder = Undefined Then // Attempt to load settings saved in the previous versions.
			InitialFolder = CommonUse.FormDataSettingsStorageImport("StorageOfFiles", "CurrentFolder");
		EndIf;
	EndIf;
	
	If InitialFolder = Catalogs.FileFolders.EmptyRef() Or InitialFolder = Undefined Then
		InitialFolder = Catalogs.FileFolders.Patterns;
	EndIf;
	
	Items.Folders.CurrentRow = InitialFolder;
	
	List.Parameters.SetParameterValue(
		"Owner", InitialFolder);
	List.Parameters.SetParameterValue(
		"CurrentUser", Users.CurrentUser());
	
	ShowColumnSize = FileOperationsServiceServerCall.GetShowColumnSize();
	If ShowColumnSize = False Then
		Items.ListCurrentVersionSize.Visible = False;
	EndIf;
	
	UseHierarchy = True;
	SetHierarchy(UseHierarchy);
	
	OnChangeSigningOrEncryptionUsageAtServer();
	
	FillPropertyValues(ThisObject, FolderRightSettings(Items.Folders.CurrentRow));
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.FormChange.Visible = False;
		Items.ChangeForm82.Visible = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.FormCreateFromScanner.Visible = FileOperationsServiceClient.CommandScanAvailable();
	
EndProcedure

&AtClient
Procedure OnClose()
	If InitialFolder <> Items.Folders.CurrentRow Then
		OnCloseAtServer();
	EndIf;
EndProcedure

&AtServer
Procedure OnCloseAtServer()
	CommonUse.FormDataSettingsStorageSave(
		"Files", 
		"CurrentFolder", 
		Items.Folders.CurrentRow);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "FileImportCompleted" Then
		Items.List.Refresh();
		
		If Parameter <> Undefined Then
			Items.List.CurrentRow = Parameter;
		EndIf;
	EndIf;
	
	If EventName = "DirectoryImportCompleted" Then
		Items.Folders.Refresh();
		Items.List.Refresh();
		
		If Source <> Undefined Then
			Items.Folders.CurrentRow = Source;
		EndIf;
	EndIf;

	If EventName = "Record_File" AND Parameter.Event = "FileCreated" Then
		
		If Parameter <> Undefined Then
			FileOwner = Undefined;
			If Parameter.Property("Owner", FileOwner) Then
				If FileOwner = Items.Folders.CurrentRow Then
					Items.List.Refresh();
					
					CreatedFile = Undefined;
					If Parameter.Property("File", CreatedFile) Then
						Items.List.CurrentRow = CreatedFile;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
	EndIf;
	
	If EventName = "Record_File" AND Parameter.Event = "FileDataChanged" Then
		SetFileCommandsEnabled();
	EndIf;
	
	If Upper(EventName) = Upper("Record_ConstantsSet")
	   AND (    Upper(Source) = Upper("UseDigitalSignatures")
		  Or Upper(Source) = Upper("UseEncryption")) Then
			
		AttachIdleHandler("OnChangeSigningOrEncryptionUsage", 0.3, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("Catalog.FileFolders.Form.ChoiceForm") Then
		
		If ValueSelected = Undefined Then
			Return;
		EndIf;
		
		SelectedRows = Items.List.SelectedRows;
		FileOperationsServiceClient.MoveFilesToFolder(SelectedRows, ValueSelected);
		
		For Each SelectedRow IN SelectedRows Do
			Notify("Record_File", New Structure("Event", "FileDataChanged"), SelectedRow);
		EndDo;
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	SetHierarchy(Settings["UseHierarchy"]);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure SearchOnChange(Item)
	FindFilesOrFolders();
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	If TypeOf(SelectedRow) = Type("DynamicalListGroupRow") Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	HowToOpen = FileFunctionsServiceClientServer.PersonalFileOperationsSettings().DoubleClickAction;
	
	If HowToOpen = "ToOpenCard" Then
		ShowValue(, SelectedRow);
		Return;
	EndIf;
	
	DirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	If DirectoryName = Undefined Or IsBlankString(DirectoryName) Then
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(SelectedRow,
		UUID, Undefined, PreviousFileURL);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData", FileData);
	Handler = New NotifyDescription("ListSelectionAfterEditModeSelection", ThisObject, HandlerParameters);
	
	ChooseModeAndEditFile(Handler, FileData, True);
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Items.Folders.CurrentRow = Undefined Then
		Cancel = True;
		Return;
	EndIf; 
	
	If Items.Folders.CurrentRow.IsEmpty() Then
		Cancel = True;
		Return;
	EndIf; 
	
	FileOwner = Items.Folders.CurrentRow;
	BasisFile = Items.List.CurrentRow;
	
	Cancel = True;
	
	If Copy Then
		FileOperationsClient.CopyFile(FileOwner, BasisFile);
	Else
		FileOperationsServiceClient.AddFile(Undefined, FileOwner, ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure ListDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ListDrag(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
	DraggingToFolder(Undefined, DragParameters.Value, DragParameters.Action);
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	SetFileCommandsEnabled();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersFolders

&AtClient
Procedure FoldersOnActivateRow(Item)
	
	SetCommandsOnChangeFolderAvailability();
	
EndProcedure

&AtClient
Procedure FoldersDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure FoldersDrag(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
	DraggingToFolder(String, DragParameters.Value, DragParameters.Action);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure FilesImportExecute()
	
	Handler = New NotifyDescription("ImportFilesAfterExpansionSetting", ThisObject);
	
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(Handler);
	
EndProcedure

&AtClient
Procedure ImportFilesAfterExpansionSetting(Result, ExecuteParameters) Export
	If Not Result Then
		FileFunctionsServiceClient.ShowWarningAboutNeedToFileOperationsExpansion(Undefined);
		Return;
	EndIf;
	
	FileOpeningDialog = New FileDialog(FileDialogMode.Open);
	FileOpeningDialog.FullFileName = "";
	FileOpeningDialog.Filter = NStr("en='All files(*.*)|*.*';ru='Все файлы(*.*)|*.*'");
	FileOpeningDialog.Multiselect = True;
	FileOpeningDialog.Title = NStr("en='Select files';ru='Выбрать файлы'");
	If Not FileOpeningDialog.Choose() Then
		Return;
	EndIf;
	
	FileNameArray = New Array;
	For Each FileName IN FileOpeningDialog.SelectedFiles Do
		FileNameArray.Add(FileName);
	EndDo;
	
	FormParameters = New Structure;
	FormParameters.Insert("FolderForAdding", Items.Folders.CurrentRow);
	FormParameters.Insert("FileNameArray",   FileNameArray);
	
	OpenForm("Catalog.Files.Form.FileImportForm", FormParameters);
EndProcedure

&AtClient
Procedure FolderImport(Command)
	#If WebClient Then
		WarningText = NStr("en='Import of folders is unavailable in the web client.
		|Use the Create command in files list.';ru='В веб-клиенте импорт папок недоступен.
		|Используйте команду ""Создать"" в списке файлов.'");
		ShowMessageBox(, WarningText);
		Return;
	#EndIf
	
	FileOpeningDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	FileOpeningDialog.FullFileName = "";
	FileOpeningDialog.Filter = NStr("en='All files(*.*)|*.*';ru='Все файлы(*.*)|*.*'");
	FileOpeningDialog.Multiselect = False;
	FileOpeningDialog.Title = NStr("en='Select the folder';ru='Выберите каталог'");
	If Not FileOpeningDialog.Choose() Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("FolderForAdding", Items.Folders.CurrentRow);
	FormParameters.Insert("DirectoryOnHardDisk",     FileOpeningDialog.Folder);
	
	OpenForm("Catalog.Files.Form.FolderImportForm", FormParameters);
EndProcedure

&AtClient
Procedure ExportFoldersExecute()
	
	FormParameters = New Structure;
	FormParameters.Insert("ExportFolder", Items.Folders.CurrentRow);
	OpenForm("Catalog.Files.Form.FolderExportForm", FormParameters);
	
EndProcedure

&AtClient
Procedure FindExecute()
	
	If SearchString = "" Then
		CommonUseClientServer.MessageToUser(
			NStr("en='Search text not specified.';ru='Не указан текст для поиска.'"), , "SearchString");
		Return;
	EndIf;
	
	FindFilesOrFolders();
	
EndProcedure

&AtClient
Procedure FindFilesOrFolders()
	
	If SearchString = "" Then
		Return;
	EndIf;
	
	Result = FindFilesOrFoldersServer();
	
	If Result = "FoundNothing" Then
		WarningText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='File or folder with
		|%1 in the name or code is not found';ru='Не удалось найти
		|файл или папку, наименование или код которых содержит ""%1"".'"),
			SearchString);
		ShowMessageBox(, WarningText);
	Else
		If Result = "FileFound" Then
			CurrentItem = Items.List;
		Else 
			If Result = "FolderFound" Then
				CurrentItem = Items.Folders;
			EndIf;
		EndIf;
	EndIf;
	
	Items.Folders.Refresh();
	Items.List.Refresh();
EndProcedure

&AtServer
Function PageReplaceWithSpecialSymbol(String, Char, ESCAPE)
	RowNew = StrReplace(String, Char, ESCAPE + Char);
	Return RowNew;
EndFunction

&AtServer
Function FindFilesOrFoldersServer()
	
	Var FoundFile;
	Var FoundFolder;
	
	Found = False;
	
	Query = New Query;
	
	NewSearchString = SearchString;
	
	ESCAPE = "|";
	NewSearchString = PageReplaceWithSpecialSymbol(NewSearchString, "[", ESCAPE);
	NewSearchString = PageReplaceWithSpecialSymbol(NewSearchString, "]", ESCAPE);
	
	Query.Parameters.Insert("String", "%" + NewSearchString + "%");
	
	Query.Text = "SELECT ALLOWED TOP 1
				   |	Files.Ref
				   |FROM
				   |	Catalog.Files AS Files
				   |WHERE
				   |	Files.FullDescr LIKE &String ESCAPE ""|""";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FoundFile = Selection.Ref;
		Found = True;
	EndIf;
	
	If Not Found Then
		Query.Text = "SELECT ALLOWED TOP 1
					   |	Files.Ref
					   |FROM
					   |	Catalog.Files AS Files
					   |WHERE
					   |	Files.Code LIKE &String";
						
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			FoundFile = Selection.Ref;
			Found = True;
		EndIf;	
	EndIf;	
	
	If Not Found Then
		Query.Text = "SELECT ALLOWED TOP 1
					   |	FileFolders.Ref
					   |FROM
					   |	Catalog.FileFolders AS FileFolders
					   |WHERE
					   |	FileFolders.Description LIKE &String";
						
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			FoundFolder = Selection.Ref;
			Found = True;
		EndIf;
	EndIf;
	
	If Not Found Then
		Query.Text = "SELECT ALLOWED TOP 1
					   |	FileFolders.Ref
					   |FROM
					   |	Catalog.FileFolders AS FileFolders
					   |WHERE
					   |	FileFolders.Code LIKE &String";
						
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			FoundFolder = Selection.Ref;
			Found = True;
		EndIf;
	EndIf;
	
	If FoundFile <> Undefined Then 
		Items.Folders.CurrentRow = FoundFile.FileOwner;
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
		Items.List.CurrentRow = FoundFile.Ref;
		Return "FileFound";
	EndIf;
	
	If FoundFolder <> Undefined Then
		Items.Folders.CurrentRow = FoundFolder;
		Return "FolderFound";
	EndIf;
	
	Return "FoundNothing";
EndFunction

&AtClient
Procedure CreateFileExecute(Command)
	
	AddingParameters = New Structure;
	AddingParameters.Insert("ResultHandler", Undefined);
	AddingParameters.Insert("FileOwner", Items.Folders.CurrentRow);
	AddingParameters.Insert("OwnerForm", ThisObject);
	AddingParameters.Insert("DoNotOpenCardAfterCreateFromFile", Undefined);
	If FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		FileOperationsServiceClient.AddFromFileSystemWithExtension(AddingParameters);
	Else
		FileOperationsServiceClient.AddFromFileSystemWithoutExpansion(AddingParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateFileFromTemplateExecute(Command)
	
	AddingParameters = New Structure;
	AddingParameters.Insert("ResultHandler", Undefined);
	AddingParameters.Insert("FileOwner", Items.Folders.CurrentRow);
	AddingParameters.Insert("OwnerForm", ThisObject);
	AddingParameters.Insert("DoNotOpenCardAfterCreateFromFile", Undefined);
	FileOperationsServiceClient.AddBasedOnTemplate(AddingParameters);
	
EndProcedure

&AtClient
Procedure CreateFileFromScannerExecute(Command)
	
	AddingParameters = New Structure;
	AddingParameters.Insert("ResultHandler", Undefined);
	AddingParameters.Insert("FileOwner", Items.Folders.CurrentRow);
	AddingParameters.Insert("OwnerForm", ThisObject);
	AddingParameters.Insert("DoNotOpenCardAfterCreateFromFile", Undefined);
	FileOperationsServiceClient.AddFromScanner(AddingParameters);
	
EndProcedure

&AtClient
Procedure CreateFolderExecute()
	
	NewFolderParameters = New Structure("Parent", Items.Folders.CurrentRow);
	OpenForm("Catalog.FileFolders.ObjectForm", NewFolderParameters, Items.Folders);
	
EndProcedure

&AtClient
Procedure UseHierarchy(Command)
	
	UseHierarchy = Not UseHierarchy;
	If UseHierarchy AND (Items.List.CurrentData <> Undefined) Then 
		
		If Items.List.CurrentData.Property("FileOwner") Then 
			Items.Folders.CurrentRow = Items.List.CurrentData.FileOwner;
		Else
			Items.Folders.CurrentRow = Undefined;
		EndIf;	
		
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;	
	SetHierarchy(UseHierarchy);
	
EndProcedure

&AtClient
Procedure OpenFileExecute()
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(Items.List.CurrentRow,
		UUID, Undefined, PreviousFileURL);
	FileOperationsClient.Open(FileData);
	
EndProcedure

&AtClient
Procedure Edit(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	Handler = New NotifyDescription("SetFileCommandsEnabled", ThisObject);
	FileOperationsServiceClient.EditWithAlert(Handler, Items.List.CurrentRow);
	
EndProcedure

&AtClient
Function FileCommandsAvailable(FileRef = Undefined)
	// File commands are available - there is at least one row in the list and not grouping is highlighted.
	
	If FileRef = Undefined Then 
		FileRef = Items.List.CurrentRow;
	EndIf;
	
	If FileRef = Undefined Then 
		Return False;
	EndIf;
	
	If TypeOf(Items.List.CurrentRow) = Type("DynamicalListGroupRow") Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtClient
Procedure EndEdit(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	TableRow = Items.List.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	Handler = New NotifyDescription("SetFileCommandsEnabled", ThisObject);
	FileUpdateParameters = FileOperationsServiceClient.FileUpdateParameters(Handler, TableRow.Ref, UUID);
	FileUpdateParameters.StoreVersions = TableRow.StoreVersions;
	FileUpdateParameters.CurrentUserIsEditing = TableRow.CurrentUserIsEditing;
	FileUpdateParameters.IsEditing = TableRow.IsEditing;
	FileUpdateParameters.CurrentVersionAuthor = TableRow.Author;
	FileUpdateParameters.Encoding = TableRow.Encoding;
	FileOperationsServiceClient.EndEditingWithAlert(FileUpdateParameters);
	
EndProcedure

&AtClient
Procedure Lock(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	Handler = New NotifyDescription("SetFileCommandsEnabled", ThisObject);
	FileOperationsServiceClient.TakeWithAlarm(Handler, Items.List.CurrentRow);
	
EndProcedure

&AtClient
Procedure Release(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	Handler = New NotifyDescription("SetFileCommandsEnabled", ThisObject);
	CurrentData = Items.List.CurrentData;
	FileReleaseParameters = FileOperationsServiceClient.FileReleaseParameters(Handler, Items.List.CurrentRow);
	FileReleaseParameters.StoreVersions = CurrentData.StoreVersions;	
	FileReleaseParameters.CurrentUserIsEditing = CurrentData.CurrentUserIsEditing;	
	FileReleaseParameters.IsEditing = CurrentData.IsEditing;	
	FileOperationsServiceClient.ReleaseFileWithAlert(FileReleaseParameters);
	
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	Handler = New NotifyDescription("SetFileCommandsEnabled", ThisObject);
	
	FileOperationsServiceClient.SaveFileChangesWithAlert(
		Handler,
		Items.List.CurrentRow,
		UUID);
	
EndProcedure

&AtClient
Procedure OpenFileDirectory(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(Items.List.CurrentRow,
		UUID, Undefined, PreviousFileURL);
	FileOperationsClient.OpenFileDirectory(FileData);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForSave(Items.List.CurrentRow, UUID);
	FileOperationsServiceClient.SaveAs(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnDrive(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataAndWorkingDirectory(Items.List.CurrentRow);
	FileOperationsServiceClient.UpdateFromFileOnDiskWithAlert(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	Cancel = True;
	
	FormOpenParameters = New Structure("Key", Item.CurrentRow);
	OpenForm("Catalog.Files.ObjectForm", FormOpenParameters);
EndProcedure

&AtClient
Procedure MoveToFolder(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Title",    NStr("en='Select folder';ru='Установить каталог'"));
	FormParameters.Insert("CurrentFolder", Items.Folders.CurrentRow);
	FormParameters.Insert("ChoiceMode",  True);
	
	OpenForm("Catalog.FileFolders.ChoiceForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure Sign(Command)
	
	FilesArray = New Array;
	FilesArray.Add(Items.List.CurrentRow);
	
	FileOperationsServiceClient.SignFile(FilesArray, UUID,
		New NotifyDescription("SignEnding", ThisObject));
	
EndProcedure

&AtClient
Procedure Encrypt(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	ObjectRef = Items.List.CurrentRow;
	FileData = FileOperationsServiceServerCall.GetFileDataAndNumberOfVersions(ObjectRef);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData", FileData);
	HandlerParameters.Insert("ObjectRef", ObjectRef);
	Handler = New NotifyDescription("EncryptAfterEncryptionAtClient", ThisObject, HandlerParameters);
	
	FileOperationsServiceClient.Encrypt(Handler, FileData, UUID);
	
EndProcedure

&AtClient
Procedure Decrypt(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	ObjectRef = Items.List.CurrentRow;
	FileData = FileOperationsServiceServerCall.GetFileDataAndNumberOfVersions(ObjectRef);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData", FileData);
	HandlerParameters.Insert("ObjectRef", ObjectRef);
	Handler = New NotifyDescription("DecryptAfterDecryptionAtClient", ThisObject, HandlerParameters);
	
	FileOperationsServiceClient.Decrypt(
		Handler,
		FileData.Ref,
		UUID,
		FileData);
	
EndProcedure

&AtClient
Procedure AddSignatureFromFile(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileOperationsServiceClient.AddSignatureFromFile(
		Items.List.CurrentRow,
		UUID,
		New NotifyDescription("SetFileCommandsEnabled", ThisObject));
	
EndProcedure

&AtClient
Procedure SaveTogetherWithSignature(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileOperationsServiceClient.SaveFileTogetherWithSignature(
		Items.List.CurrentRow, UUID);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	Items.Folders.Refresh();
	Items.List.Refresh();
	
	AttachIdleHandler("SetCommandsOnChangeFolderAvailability", 0.1, True);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure DraggingToFolder(FolderForAdding, DraggingValue, Action)
	If FolderForAdding = Undefined Then
		FolderForAdding = Items.Folders.CurrentRow;
		If FolderForAdding = Undefined Then
			Return;
		EndIf;
	EndIf;
	
	If FolderForAdding.IsEmpty() Then
		Return;
	EndIf;
	
	ValueType = TypeOf(DraggingValue);
	If ValueType = Type("File") Then
		If DraggingValue.IsFile() Then
			AddingParameters = New Structure;
			AddingParameters.Insert("ResultHandler", Undefined);
			AddingParameters.Insert("FullFileName", DraggingValue.DescriptionFull);
			AddingParameters.Insert("FileOwner", FolderForAdding);
			AddingParameters.Insert("OwnerForm", ThisObject);
			AddingParameters.Insert("CreatedFileName", Undefined);
			AddingParameters.Insert("DoNotOpenCardAfterCreateFromFile", Undefined);
			FileOperationsServiceClient.AddFromFileSystemWithExtension(AddingParameters);
		Else
			FileNameArray = New Array;
			FileNameArray.Add(DraggingValue.DescriptionFull);
			FileOperationsServiceClient.OpenFormDragFromOutside(FolderForAdding, FileNameArray);
		EndIf;
	ElsIf TypeOf(DraggingValue) = Type("Array") Then
		FolderIndex = DraggingValue.Find(FolderForAdding);
		If FolderIndex <> Undefined Then
			DraggingValue.Delete(FolderIndex);
		EndIf;
		
		If DraggingValue.Count() = 0 Then
			Return;
		EndIf;
		
		ValueType = TypeOf(DraggingValue[0]);
		If ValueType = Type("File") Then
			
			FileNameArray = New Array;
			For Each AcceptedFile IN DraggingValue Do
				FileNameArray.Add(AcceptedFile.DescriptionFull);
			EndDo;
			FileOperationsServiceClient.OpenFormDragFromOutside(FolderForAdding, FileNameArray);
			
		ElsIf ValueType = Type("CatalogRef.Files") Then
			
			If Action = DragAction.Copy Then
				
				FileOperationsServiceServerCall.CopyFiles(
					DraggingValue,
					FolderForAdding);
				
				Items.Folders.Refresh();
				Items.List.Refresh();
				
				If DraggingValue.Count() = 1 Then
					NotificationTitle = NStr("en='File copied.';ru='Файл скопирован.'");
					NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='%1
		|file has been copied to the %2 folder';ru='Файл
		|""%1"" скопирован в папку ""%2""'"),
						DraggingValue[0],
						String(FolderForAdding));
				Else
					NotificationTitle = NStr("en='Files are copied.';ru='Файлы скопированы.'");
					NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='Files (%1 units) have been copied to the %2 folder';ru='Файлы (%1 шт.) скопированы в папку ""%2""'"),
						DraggingValue.Count(),
						String(FolderForAdding));
				EndIf;
				ShowUserNotification(NotificationTitle, , NotificationText, PictureLib.Information32);
			Else
				
				OwnerDetermined = FileOperationsServiceServerCall.SetFileOwner(DraggingValue, FolderForAdding);
				If OwnerDetermined <> True Then
					Return;
				EndIf;
				
				Items.Folders.Refresh();
				Items.List.Refresh();
				
				If DraggingValue.Count() = 1 Then
					NotificationTitle = NStr("en='File has been moved';ru='Файл перенесен.'");
					NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='The
		|file ""%1"" was moved to the folder ""%2""';ru='Файл
		|""%1"" перенесен в папку ""%2""'"),
						String(DraggingValue[0]),
						String(FolderForAdding));
				Else
					NotificationTitle = NStr("en='Files have been moved.';ru='Файлы перенесены.'");
					NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en='Files (%1) moved to folder %2';ru='Файлы (%1 шт.) перенесены в папку ""%2""'"),
						String(DraggingValue.Count()),
						String(FolderForAdding));
				EndIf;
				ShowUserNotification(NotificationTitle, , NotificationText, PictureLib.Information32);
			EndIf;
			
		ElsIf ValueType = Type("CatalogRef.FileFolders") Then
			InfiniteLoopFound = False;
			ParentChanged = FileOperationsServiceServerCall.ChangeParentOfFolders(DraggingValue, FolderForAdding, InfiniteLoopFound);
			If ParentChanged <> True Then
				If InfiniteLoopFound = True Then
					ShowMessageBox(, NStr("en='Levels looping.';ru='Зацикливание уровней.'"));
				EndIf;
				Return;
			EndIf;
			
			Items.Folders.Refresh();
			Items.List.Refresh();
			
			If DraggingValue.Count() = 1 Then
				Items.Folders.CurrentRow = DraggingValue[0];
				NotificationTitle = NStr("en='Folder has been moved.';ru='Папка перенесена.'");
				NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Folder
		|""%1"" moved to ""%2""';ru='Папка
		|""%1"" перенесена в папку ""%2""'"),
					String(DraggingValue[0]),
					String(FolderForAdding));
			Else
				NotificationTitle = NStr("en='Folders have been moved.';ru='Папки перенесены.'");
				NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Folders (%1 pcs.)  moved to folder ""%2""';ru='Папки (%1 шт.) перенесены в папку ""%2""'"),
					String(DraggingValue.Count()),
					String(FolderForAdding));
			EndIf;
			ShowUserNotification(NotificationTitle, , NotificationText, PictureLib.Information32);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure EncryptAfterEncryptionAtClient(Result, ExecuteParameters) Export
	If Not Result.Success Then
		Return;
	EndIf;
	
	WorkingDirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	
	FilesArrayInWorkingDirectoryForDelete = New Array;
	
	EncryptServer(
		Result.ArrayDataForPlacingToBase,
		Result.ThumbprintArray,
		FilesArrayInWorkingDirectoryForDelete,
		WorkingDirectoryName,
		ExecuteParameters.ObjectRef);
	
	FileOperationsServiceClient.InformAboutEncryption(
		FilesArrayInWorkingDirectoryForDelete,
		ExecuteParameters.FileData.Owner,
		ExecuteParameters.ObjectRef);
	
	SetFileCommandsEnabled();
	
EndProcedure

&AtServer
Procedure EncryptServer(ArrayDataForPlacingToBase, ThumbprintArray, 
	FilesArrayInWorkingDirectoryForDelete,
	WorkingDirectoryName, ObjectRef)
	
	Encrypt = True;
	FileOperationsServiceServerCall.AddInformationAboutEncryption(
		ObjectRef,
		Encrypt,
		ArrayDataForPlacingToBase,
		Undefined,  // UUID
		WorkingDirectoryName,
		FilesArrayInWorkingDirectoryForDelete,
		ThumbprintArray);
	
EndProcedure

&AtClient
Procedure DecryptAfterDecryptionAtClient(Result, ExecuteParameters) Export
	
	If Result = False Or Not Result.Success Then
		Return;
	EndIf;
	
	WorkingDirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	
	DrillDownServer(
		Result.ArrayDataForPlacingToBase,
		WorkingDirectoryName,
		ExecuteParameters.ObjectRef);
	
	FileOperationsServiceClient.InformAboutDescripting(
		ExecuteParameters.FileData.Owner,
		ExecuteParameters.ObjectRef);
	
	SetFileCommandsEnabled();
	
EndProcedure

&AtServer
Procedure DrillDownServer(ArrayDataForPlacingToBase, 
	WorkingDirectoryName, ObjectRef)
	
	Encrypt = False;
	ThumbprintArray = New Array;
	FilesArrayInWorkingDirectoryForDelete = New Array;
	
	FileOperationsServiceServerCall.AddInformationAboutEncryption(
		ObjectRef,
		Encrypt,
		ArrayDataForPlacingToBase,
		Undefined,  // UUID
		WorkingDirectoryName,
		FilesArrayInWorkingDirectoryForDelete,
		ThumbprintArray);
	
EndProcedure

&AtClient
Procedure SignEnding(Result, ExecuteParameters) Export
	
	SetFileCommandsEnabled();
	
EndProcedure

&AtClient
Procedure SetCommandsOnChangeFolderAvailability()
	
	If Items.Folders.CurrentRow <> CurrentFolder Then
		CurrentFolder = Items.Folders.CurrentRow;
		FillPropertyValues(ThisObject, FolderRightSettings(Items.Folders.CurrentRow));
		Items.FormCreateFolder.Enabled = FoldersUpdate;
		Items.FoldersContextMenuCreate.Enabled = FoldersUpdate;
		Items.FoldersContextMenuCopy.Enabled = FoldersUpdate;
		Items.FoldersContextMenuSetDeletionMark.Enabled = FoldersUpdate;
		Items.FoldersContextMenuTransferItem.Enabled = FoldersUpdate;
	EndIf;
	
	If Items.Folders.CurrentRow = Undefined Or Items.Folders.CurrentRow.IsEmpty() Then
		
		Items.FormCreatePopup.Enabled = False;
		
		Items.FormCreateFromFile.Enabled = False;
		Items.FormCreateFromTemplate.Enabled = False;
		Items.FormCreateFromScanner.Enabled = False;
		
		Items.FormCopy.Enabled = False;
		Items.ListContextMenuCopy.Enabled = False;
		
		Items.FormSetDeletionMark.Enabled = False;
		Items.ListContextMenuSetDeletionMark.Enabled = False;
		
		Items.ListContextMenuCreate.Enabled = False;
		
		Items.FormFilesImport.Enabled = False;
		Items.ListContextMenuFilesImport.Enabled = False;
		
		Items.FoldersContextMenuFolderImport.Enabled = False;
	Else
		Items.FormCreatePopup.Enabled = FilesAdd;
		Items.FormCreateFromFile.Enabled = FilesAdd;
		Items.FormCreateFromTemplate.Enabled = FilesAdd;
		Items.FormCreateFromScanner.Enabled = FilesAdd;
		Items.ListContextMenuCreate.Enabled = FilesAdd;
		
		Items.FormCopy.Enabled = FilesAdd;
		Items.ListContextMenuCopy.Enabled = FilesAdd;
		
		Items.FormSetDeletionMark.Enabled = FileDeletionMark;
		Items.ListContextMenuSetDeletionMark.Enabled = FileDeletionMark;
		
		Items.FormFilesImport.Enabled = FilesAdd;
		Items.ListContextMenuFilesImport.Enabled = FilesAdd;
		
		Items.FoldersContextMenuFolderImport.Enabled = FilesAdd;
	EndIf;
	
	If Items.Folders.CurrentRow <> Undefined Then
		AttachIdleHandler("FolderIdleProcessingOnActivateRow", 0.2, True);
	EndIf; 
	
EndProcedure

&AtClient
Procedure FolderIdleProcessingOnActivateRow()
	
	If Items.Folders.CurrentRow <> List.Parameters.Items.Find("Owner").Value Then
		// Right list and commands availability are being refreshed.
		// OnActivateRow handler procedure call of the List table is run by the platform.
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	Else
		// OnActivateRow handler procedure call of the List table is run applicationmatically.
		AttachIdleHandler("IdleProcessingSetFileCommandsEnabled", 0.1, True);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function FolderRightSettings(Folder)
	
	RightSettings = New Structure;
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Value = ValueIsFilled(Folder);
		RightSettings.Insert("FoldersUpdate", True);
		RightSettings.Insert("FilesUpdate", Value);
		RightSettings.Insert("FilesAdd", Value);
		RightSettings.Insert("FileDeletionMark", Value);
		Return RightSettings;
	EndIf;
	
	AccessControlModule = CommonUse.CommonModule("AccessManagement");
	
	RightSettings.Insert("FoldersUpdate",
		AccessControlModule.IsRight("FoldersUpdate", Folder));
	
	RightSettings.Insert("FilesUpdate",
		AccessControlModule.IsRight("FilesUpdate", Folder));
	
	RightSettings.Insert("FilesAdd",
		AccessControlModule.IsRight("FilesAdd", Folder));
	
	RightSettings.Insert("FileDeletionMark",
		AccessControlModule.IsRight("FileDeletionMark", Folder));
	
	Return RightSettings;
	
EndFunction

&AtClient
Procedure IdleProcessingSetFileCommandsEnabled()
	
	SetFileCommandsEnabled();
	
EndProcedure

&AtClient
Procedure SetFileCommandsEnabled(Result = Undefined, ExecuteParameters = Undefined) Export
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData <> Undefined
	   AND TypeOf(Items.List.CurrentRow) <> Type("DynamicalListGroupRow") Then
		
		SetCommandsEnabled(
			CurrentData.CurrentUserIsEditing,
			CurrentData.IsEditing,
			CurrentData.DigitallySigned,
			CurrentData.Encrypted);
	Else
		MakeCommandsUnavailable();
	EndIf;
	
EndProcedure

&AtClient
Procedure MakeCommandsUnavailable()
	
	Items.FormEndEdit.Enabled = False;
	Items.ListContextMenuEndEditing.Enabled = False;
	
	Items.FormSaveChanges.Enabled = False;
	Items.ListContextMenuSaveChanges.Enabled = False;
	
	Items.FormRelease.Enabled = False;
	Items.ListContextMenuExtend.Enabled = False;
	
	Items.FormLock.Enabled = False;
	Items.ListContextMenuLock.Enabled = False;
	
	Items.FormEdit.Enabled = False;
	Items.ListContextMenuEdit.Enabled = False;
	
	Items.FormMoveToFolder.Enabled = False;
	Items.ListContextMenuMoveToFolder.Enabled = False;
	
	Items.FormSign.Enabled = False;
	Items.ListContextMenuSign.Enabled = False;
	
	Items.FormSaveWithSignature.Enabled = False;
	Items.ListContextMenuSaveWithSignature.Enabled = False;
	
	Items.FormEncrypt.Enabled = False;
	Items.ListContextMenuEncrypt.Enabled = False;
	
	Items.FormDrillDown.Enabled = False;
	Items.ListContextMenuDecrypt.Enabled = False;
	
	Items.FormAddSignatureFromFile.Enabled = False;
	Items.ListContextMenuAddSignatureFromFile.Enabled = False;
	
	Items.FormUpdateFromFileOnDrive.Enabled = False;
	Items.ListContextMenuUpdateFromFileOnDisc.Enabled = False;
	
	Items.FormSaveAs.Enabled = False;
	Items.ListContextMenuSaveAs.Enabled = False;
	
	Items.FormOpenFileDirectory.Enabled = False;
	Items.ListContextMenuOpenFileCatalog.Enabled = False;
	
	Items.FormOpen.Enabled = False;
	Items.ListContextMenuOpen.Enabled = False;
	
EndProcedure

&AtClient
Procedure SetCommandsEnabled(CurrentUserIsEditing, IsEditing, DigitallySigned, Encrypted)
	
	EditedByAnother = Not IsEditing.IsEmpty() AND Not CurrentUserIsEditing;
	
	Items.FormEndEdit.Enabled = FilesUpdate AND CurrentUserIsEditing;
	Items.ListContextMenuEndEditing.Enabled = FilesUpdate AND CurrentUserIsEditing;
	
	Items.FormSaveChanges.Enabled = FilesUpdate AND CurrentUserIsEditing;
	Items.ListContextMenuSaveChanges.Enabled = FilesUpdate AND CurrentUserIsEditing;
	
	Items.FormRelease.Enabled = FilesUpdate AND Not IsEditing.IsEmpty();
	Items.ListContextMenuExtend.Enabled = FilesUpdate AND Not IsEditing.IsEmpty();
	
	Items.FormLock.Enabled = FilesUpdate AND IsEditing.IsEmpty() AND Not DigitallySigned;
	Items.ListContextMenuLock.Enabled = FilesUpdate AND IsEditing.IsEmpty() AND Not DigitallySigned;
	
	Items.FormEdit.Enabled = FilesUpdate AND Not DigitallySigned AND Not EditedByAnother;
	Items.ListContextMenuEdit.Enabled = FilesUpdate AND Not DigitallySigned AND Not EditedByAnother;
	
	Items.FormMoveToFolder.Enabled = FilesUpdate AND Not DigitallySigned;
	Items.ListContextMenuMoveToFolder.Enabled = FilesUpdate AND Not DigitallySigned;
	
	Items.FormSign.Enabled = FilesUpdate AND IsEditing.IsEmpty();
	Items.ListContextMenuSign.Enabled = FilesUpdate AND IsEditing.IsEmpty();
	
	Items.FormSaveWithSignature.Enabled = DigitallySigned;
	Items.ListContextMenuSaveWithSignature.Enabled = DigitallySigned;
	
	Items.FormEncrypt.Enabled = FilesUpdate AND IsEditing.IsEmpty() AND Not Encrypted;
	Items.ListContextMenuEncrypt.Enabled = FilesUpdate AND IsEditing.IsEmpty() AND Not Encrypted;
	
	Items.FormDrillDown.Enabled = FilesUpdate AND Encrypted;
	Items.ListContextMenuDecrypt.Enabled = FilesUpdate AND Encrypted;
	
	Items.FormAddSignatureFromFile.Enabled = FilesUpdate AND IsEditing.IsEmpty();
	Items.ListContextMenuAddSignatureFromFile.Enabled = FilesUpdate AND IsEditing.IsEmpty();
	
	Items.FormUpdateFromFileOnDrive.Enabled = FilesUpdate AND Not DigitallySigned;
	Items.ListContextMenuUpdateFromFileOnDisc.Enabled = FilesUpdate AND Not DigitallySigned;
	
	Items.FormSaveAs.Enabled = True;
	Items.ListContextMenuSaveAs.Enabled = True;
	
	Items.FormOpenFileDirectory.Enabled = True;
	Items.ListContextMenuOpenFileCatalog.Enabled = True;
	
	Items.FormOpen.Enabled = True;
	Items.ListContextMenuOpen.Enabled = True;
	
EndProcedure

&AtServer
Procedure SetHierarchy(Mark)
	
	If Mark = Undefined Then 
		Return;
	EndIf;
	
	Items.FormUseHierarchy.Check = Mark;
	If Mark = True Then 
		Items.Folders.Visible = True;
	Else
		Items.Folders.Visible = False;
	EndIf;
	List.Parameters.SetParameterValue("UseHierarchy", Mark);
	
EndProcedure

&AtClient
Procedure ChooseModeAndEditFile(ResultHandler, FileData, EditCommandEnabled) Export
	// Select file opening mode and start editing.
	OpenResult = "Open";
	ResultEdit = "Edit";
	ResultCancel = "Cancel";
	
	PersonalSettings = FileFunctionsServiceClientServer.PersonalFileOperationsSettings();
	
	OpeningMethod = PersonalSettings.TextFilesOpeningMethod;
	If OpeningMethod = PredefinedValue("Enum.OpenFileForViewingVariants.InEmbeddedEditor") Then
		
		ExtensionInList = FileFunctionsServiceClientServer.FileExtensionInList(
			PersonalSettings.TextFilesExtension,
			FileData.Extension);
		
		If ExtensionInList Then
			FileOperationsServiceClient.ReturnResult(ResultHandler, OpenResult);
			Return;
		EndIf;
		
	EndIf;
	
	OpeningMethod = PersonalSettings.GraphicSchemesOpeningMethod;
	If OpeningMethod = PredefinedValue("Enum.OpenFileForViewingVariants.InEmbeddedEditor") Then
		
		ExtensionInList = FileFunctionsServiceClientServer.FileExtensionInList(
			PersonalSettings.GraphicalSchemaExtension,
			FileData.Extension);
		
		If ExtensionInList Then
			FileOperationsServiceClient.ReturnResult(ResultHandler, OpenResult);
			Return;
		EndIf;
		
	EndIf;
	
	// If it is already being edited, then do not ask. - open at once.
	If FileData.IsEditing.IsEmpty()
		AND PersonalSettings.PromptForEditModeOnOpenFile = True
		AND EditCommandEnabled Then
		
		ExecuteParameters = New Structure;
		ExecuteParameters.Insert("ResultHandler", ResultHandler);
		Handler = New NotifyDescription("SelectModeAndEditFileEnd", ThisObject, ExecuteParameters);
		
		OpenForm("Catalog.Files.Form.OpenModeChoiceForm", , , , , , Handler, FormWindowOpeningMode.LockWholeInterface);
		Return;
	EndIf;
	
	FileOperationsServiceClient.ReturnResult(ResultHandler, OpenResult);
	
EndProcedure

&AtClient
Procedure SelectModeAndEditFileEnd(Result, ExecuteParameters) Export
	OpenResult = "Open";
	ResultEdit = "Edit";
	ResultCancel = "Cancel";
	
	If TypeOf(Result) <> Type("Structure") Then
		FileOperationsServiceClient.ReturnResult(ExecuteParameters.ResultHandler, ResultCancel);
		Return;
	EndIf;
	
	If Result.HowToOpen = 1 Then
		FileOperationsServiceClient.ReturnResult(ExecuteParameters.ResultHandler, ResultEdit);
		Return;
	EndIf;
	
	FileOperationsServiceClient.ReturnResult(ExecuteParameters.ResultHandler, OpenResult);
EndProcedure

&AtClient
Procedure ListSelectionAfterEditModeSelection(Result, ExecuteParameters) Export
	OpenResult = "Open";
	ResultEdit = "Edit";
	
	If Result = ResultEdit Then
		Handler = New NotifyDescription("ListSelectionAfterFileEditing", ThisObject, ExecuteParameters);
		FileOperationsServiceClient.EditFile(Handler, ExecuteParameters.FileData);
	ElsIf Result = OpenResult Then
		FileOperationsServiceClient.OpenFileWithAlert(Undefined, ExecuteParameters.FileData, UUID); 
	EndIf;
EndProcedure

&AtClient
Procedure ListSelectionAfterFileEditing(Result, ExecuteParameters) Export
	
	NotifyChanged(ExecuteParameters.FileData.Ref);
	
	SetFileCommandsEnabled();
	
EndProcedure

&AtClient
Procedure OnChangeSigningOrEncryptionUsage()
	
	OnChangeSigningOrEncryptionUsageAtServer();
	
EndProcedure

&AtServer
Procedure OnChangeSigningOrEncryptionUsageAtServer()
	
	FileFunctionsService.CryptographyOnCreateFormAtServer(ThisObject);
	
EndProcedure

#EndRegion














