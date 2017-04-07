
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.Property("FormTitle") Then
		Title = Parameters.FormTitle;
	EndIf;
	
	If Parameters.Property("FileOwner") Then 
		List.Parameters.SetParameterValue("Owner", Parameters.FileOwner);
	EndIf;
	
	List.Parameters.SetParameterValue("CurrentUser", Users.CurrentUser());
	
	FileOperationsServiceServerCall.FillFileListConditionalAppearance(List);
	
	OnChangeSigningOrEncryptionUsageAtServer();
	
	ShowColumnSize = FileOperationsServiceServerCall.GetShowColumnSize();
	If ShowColumnSize = False Then
		Items.ListCurrentVersionSize.Visible = False;
	EndIf;
	
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
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "FileImportCompleted" Then
		Items.List.Refresh();
		
		If Parameter <> Undefined Then
			Items.List.CurrentRow = Parameter;
		EndIf;
	EndIf;
	
	If EventName = "Record_File" AND Parameter.Event = "FileCreated" Then
		
		If Parameter <> Undefined Then
			
			ListFileOwner = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
			
			FileOwner = Undefined;
			If Parameter.Property("Owner", FileOwner) Then
				If FileOwner = ListFileOwner.Value Then
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
		If Items.List.CurrentData <> Undefined Then
			SetFileCommandsEnabled();
		EndIf;
	EndIf;
	
	If Upper(EventName) = Upper("Record_ConstantsSet")
	   AND (    Upper(Source) = Upper("UseDigitalSignatures")
		  Or Upper(Source) = Upper("UseEncryption")) Then
			
		AttachIdleHandler("OnChangeSigningOrEncryptionUsage", 0.3, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	If TypeOf(SelectedRow) = Type("DynamicalListGroupRow") Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	PersonalSettings = FileFunctionsServiceClientServer.PersonalFileOperationsSettings();
	HowToOpen = PersonalSettings.DoubleClickAction;
	
	If HowToOpen = "ToOpenCard" Then
		ShowValue(, SelectedRow);
		Return;
	EndIf;
	
	DirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	If DirectoryName = Undefined OR IsBlankString(DirectoryName) Then
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(SelectedRow,
		UUID, Undefined, PreviousFileURL);
	
	// If it is already being edited, then do not ask. - open at once.
	If FileData.IsEditing.IsEmpty() Then
		PromptForEditModeOnOpenFile = PersonalSettings.PromptForEditModeOnOpenFile;
		If PromptForEditModeOnOpenFile = True Then
			HandlerParameters = New Structure;
			HandlerParameters.Insert("FileData", FileData);
			Handler = New NotifyDescription("ListSelectionAfterOpenModeSelection", ThisObject, HandlerParameters);
			OpenForm("Catalog.Files.Form.OpenModeChoiceForm", , ThisObject, , , , Handler, FormWindowOpeningMode.LockOwnerWindow);
			Return;
		EndIf;
	EndIf;
	
	// For view.
	FileOperationsServiceClient.OpenFileWithAlert(Undefined, FileData, UUID);
EndProcedure

&AtClient
Procedure ListDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ListDrag(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
	
	DCParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
	If DCParameterValue = Undefined Then
		FileOwner = Undefined;
	Else
		FileOwner = DCParameterValue.Value;
	EndIf;
	If Not ValueIsFilled(FileOwner) Then
		Return;
	EndIf;
	
	DraganddropProcessingToLinearList(DragParameters, FileOwner);
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	Cancel = True;
	BasisFile = Items.List.CurrentRow;
	
	DCParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
	If DCParameterValue = Undefined Then
		FileOwner = Undefined;
	Else
		FileOwner = DCParameterValue.Value;
	EndIf;
	
	If Copy Then
		FileOperationsClient.CopyFile(FileOwner, BasisFile);
	Else
		FileOperationsServiceClient.AddFile(Undefined, FileOwner, ThisObject);
	EndIf;
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	SetFileCommandsEnabled();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure EndEdit(Command)
	
	FileRef = Items.List.CurrentRow;
	If Not FileCommandsAvailable(FileRef) Then 
		Return;
	EndIf;
	FileData = Items.List.CurrentData;
	
	Handler = New NotifyDescription("FinishEditEnd", ThisObject);
	FileUpdateParameters = FileOperationsServiceClient.FileUpdateParameters(Handler, FileRef, UUID);
	FileUpdateParameters.StoreVersions = FileData.StoreVersions;
	FileUpdateParameters.CurrentUserIsEditing = FileData.CurrentUserIsEditing;
	FileUpdateParameters.IsEditing = FileData.IsEditing;
	FileOperationsServiceClient.EndEditingWithAlert(FileUpdateParameters);
	
EndProcedure

&AtClient
Procedure Lock(Command)
	
	FileRef = Items.List.CurrentRow;
	If Not FileCommandsAvailable(FileRef) Then 
		Return;
	EndIf;
	
	Handler = New NotifyDescription("LockEnd", ThisObject);
	FileOperationsServiceClient.TakeWithAlarm(
		Handler,
		FileRef);
	
EndProcedure

&AtClient
Procedure Release(Command)
	
	FileRef = Items.List.CurrentRow;
	If Not FileCommandsAvailable(FileRef) Then 
		Return;
	EndIf;
	FileData = Items.List.CurrentData;
	
	Handler = New NotifyDescription("ReleaseEnd", ThisObject);
	FileReleaseParameters = FileOperationsServiceClient.FileReleaseParameters(Handler, FileRef);
	FileReleaseParameters.StoreVersions = FileData.StoreVersions;	
	FileReleaseParameters.CurrentUserIsEditing = FileData.CurrentUserIsEditing;	
	FileReleaseParameters.IsEditing = FileData.IsEditing;	
	FileOperationsServiceClient.ReleaseFileWithAlert(FileReleaseParameters);
	
EndProcedure

&AtClient
Procedure OpenFileDirectory(Command)
	
	FileRef = Items.List.CurrentRow;
	If Not FileCommandsAvailable(FileRef) Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(FileRef,
		UUID, Undefined, PreviousFileURL);
	FileOperationsClient.OpenFileDirectory(FileData);
	
EndProcedure

&AtClient
Procedure OpenFile(Command)
	
	FileRef = Items.List.CurrentRow;
	If Not FileCommandsAvailable(FileRef) Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(FileRef,
		UUID, Undefined, PreviousFileURL);
	FileOperationsClient.Open(FileData);
	
EndProcedure

&AtClient
Procedure Edit(Command)
	
	FileRef = Items.List.CurrentRow;
	If Not FileCommandsAvailable(FileRef) Then 
		Return;
	EndIf;
	
	Handler = New NotifyDescription("EditingEnd", ThisObject);
	FileOperationsServiceClient.EditWithAlert(Handler, FileRef);
	
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	
	FileRef = Items.List.CurrentRow;
	If Not FileCommandsAvailable(FileRef) Then 
		Return;
	EndIf;
	
	FileOperationsServiceClient.SaveFileChangesWithAlert(
		Undefined,
		FileRef,
		UUID);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	FileRef = Items.List.CurrentRow;
	If Not FileCommandsAvailable(FileRef) Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForSave(FileRef, UUID);
	FileOperationsServiceClient.SaveAs(Undefined, FileData, Undefined);
	
EndProcedure

&AtClient
Procedure FilesImport(Command)
	#If WebClient Then
		WarningText =  NStr("en='File import is not supported in the Web client.
		|Use the Create command in files list.';ru='В Веб-клиенте импорт файлов не поддерживается.
		|Используйте команду ""Создать"" в списке файлов.'");
		ShowMessageBox(, WarningText);
		Return;
	#EndIf
	
	FileNameArray = FileFunctionsServiceClient.GetImportedFilesList();
	
	If FileNameArray.Count() = 0 Then
		Return;
	EndIf;
	
	DCParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
	If DCParameterValue = Undefined Then
		FileOwner = Undefined;
	Else
		FileOwner = DCParameterValue.Value;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("FolderForAdding", FileOwner);
	FormParameters.Insert("FileNameArray",   FileNameArray);
	
	OpenForm("Catalog.Files.Form.FileImportForm", FormParameters);
EndProcedure

&AtClient
Procedure Sign(Command)
	
	FilesArray = New Array;
	For Each FileRef IN Items.List.SelectedRows Do
		If Not FileCommandsAvailable(FileRef) Then 
			Continue;
		EndIf;
		FilesArray.Add(FileRef);
	EndDo;
	
	FileOperationsServiceClient.SignFile(FilesArray, UUID,
		New NotifyDescription("SignEnding", ThisObject));
	
EndProcedure

&AtClient
Procedure Encrypt(Command)
	
	FileRef = Items.List.CurrentRow;
	If Not FileCommandsAvailable(FileRef) Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.GetFileDataAndNumberOfVersions(FileRef);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileRef", FileRef);
	HandlerParameters.Insert("FileData", FileData);
	Handler = New NotifyDescription("EncryptEnd", ThisObject, HandlerParameters);
	
	FileOperationsServiceClient.Encrypt(Handler, FileData, UUID);
	
EndProcedure

&AtClient
Procedure Decrypt(Command)
	
	FileRef = Items.List.CurrentRow;
	If Not FileCommandsAvailable(FileRef) Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.GetFileDataAndNumberOfVersions(FileRef);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileRef", FileRef);
	HandlerParameters.Insert("FileData", FileData);
	Handler = New NotifyDescription("DecryptEnd", ThisObject, HandlerParameters);
	
	FileOperationsServiceClient.Decrypt(
		Handler,
		FileData.Ref,
		UUID,
		FileData);
	
EndProcedure

&AtClient
Procedure AddSignatureFromFile(Command)
	
	FileRef = Items.List.CurrentRow;
	If Not FileCommandsAvailable(FileRef) Then 
		Return;
	EndIf;
	
	FileOperationsServiceClient.AddSignatureFromFile(
		FileRef,
		UUID,
		New NotifyDescription("AddSignatureFromFileEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure SaveTogetherWithSignature(Command)
	
	FileRef = Items.List.CurrentRow;
	If Not FileCommandsAvailable(FileRef) Then 
		Return;
	EndIf;
	
	FileOperationsServiceClient.SaveFileTogetherWithSignature(FileRef, UUID);
	
EndProcedure

&AtClient
Procedure CreateFileExecute()
	
	DCParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
	If DCParameterValue = Undefined Then
		FileOwner = Undefined;
	Else
		FileOwner = DCParameterValue.Value;
	EndIf;
	
	AddingParameters = New Structure;
	AddingParameters.Insert("ResultHandler", Undefined);
	AddingParameters.Insert("FileOwner", FileOwner);
	AddingParameters.Insert("OwnerForm", ThisObject);
	AddingParameters.Insert("DoNotOpenCardAfterCreateFromFile", Undefined);
	If FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		FileOperationsServiceClient.AddFromFileSystemWithExtension(AddingParameters);
	Else
		FileOperationsServiceClient.AddFromFileSystemWithoutExpansion(AddingParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateFileFromTemplate(Command)
	
	DCParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
	If DCParameterValue = Undefined Then
		FileOwner = Undefined;
	Else
		FileOwner = DCParameterValue.Value;
	EndIf;
	
	AddingParameters = New Structure;
	AddingParameters.Insert("ResultHandler", Undefined);
	AddingParameters.Insert("FileOwner", FileOwner);
	AddingParameters.Insert("OwnerForm", ThisObject);
	AddingParameters.Insert("DoNotOpenCardAfterCreateFromFile", Undefined);
	FileOperationsServiceClient.AddBasedOnTemplate(AddingParameters);
	
EndProcedure

&AtClient
Procedure CreateFileFromScanner(Command)
	
	DCParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
	If DCParameterValue = Undefined Then
		FileOwner = Undefined;
	Else
		FileOwner = DCParameterValue.Value;
	EndIf;
	
	AddingParameters = New Structure;
	AddingParameters.Insert("ResultHandler", Undefined);
	AddingParameters.Insert("FileOwner", FileOwner);
	AddingParameters.Insert("OwnerForm", ThisObject);
	AddingParameters.Insert("DoNotOpenCardAfterCreateFromFile", Undefined);
	FileOperationsServiceClient.AddFromScanner(AddingParameters);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	Items.List.Refresh();
	AttachIdleHandler("SetFileCommandsEnabled", 0.1, True);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ListSelectionAfterOpenModeSelection(Result, ExecuteParameters) Export
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;
	
	If Result.HowToOpen = 1 Then
		// For editing.
		Handler = New NotifyDescription("ListSelectionAfterEditing", ThisObject, ExecuteParameters);
		FileOperationsServiceClient.EditFile(Handler, ExecuteParameters.FileData, UUID);
		Return;
	EndIf;
	
	// For view.
	FileOperationsServiceClient.OpenFileWithAlert(Undefined, ExecuteParameters.FileData, UUID);
EndProcedure

&AtClient
Procedure ListSelectionAfterEditing(Result, ExecuteParameters) Export
	NotifyChanged(ExecuteParameters.FileData.Ref);
	SetFileCommandsEnabled();
EndProcedure

&AtClient
Procedure LockEnd(Result, ExecuteParameters) Export
	SetFileCommandsEnabled();
EndProcedure

&AtClient
Procedure ReleaseEnd(Result, ExecuteParameters) Export
	SetFileCommandsEnabled();
EndProcedure

&AtClient
Procedure EditingEnd(Result, ExecuteParameters) Export
	SetFileCommandsEnabled();
EndProcedure

&AtClient
Procedure SignEnding(Result, ExecuteParameters) Export
	
	SetFileCommandsEnabled();
	
EndProcedure

&AtClient
Procedure EncryptEnd(Result, ExecuteParameters) Export
	If Result.Success <> True Then
		Return;
	EndIf;
	
	WorkingDirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	
	FilesArrayInWorkingDirectoryForDelete = New Array;
	
	FileOperationsServiceServerCall.AddInformationAboutEncryption(
		ExecuteParameters.FileRef,
		True, // Encrypt
		Result.ArrayDataForPlacingToBase,
		Undefined, // UUID
		WorkingDirectoryName,
		FilesArrayInWorkingDirectoryForDelete,
		Result.ThumbprintArray);
	
	FileOperationsServiceClient.InformAboutEncryption(
		FilesArrayInWorkingDirectoryForDelete, 
		ExecuteParameters.FileData.Owner,
		ExecuteParameters.FileRef);
	
	SetFileCommandsEnabled();
EndProcedure

&AtClient
Procedure DecryptEnd(Result, ExecuteParameters) Export
	If Result.Success <> True Then
		Return;
	EndIf;
	
	WorkingDirectoryName = FileFunctionsServiceClient.UserWorkingDirectory();
	
	FileOperationsServiceServerCall.AddInformationAboutEncryption(
		ExecuteParameters.FileRef,
		False,          // Encrypt
		Result.ArrayDataForPlacingToBase,
		Undefined,  // UUID
		WorkingDirectoryName,
		New Array,  // FilesArrayInWorkingDirectoryForDelete
		New Array); // ThumbprintsArray.
		
	FileOperationsServiceClient.InformAboutDescripting(
		ExecuteParameters.FileData.Owner,
		ExecuteParameters.FileRef);
	
	SetFileCommandsEnabled();
EndProcedure

&AtClient
Procedure AddSignatureFromFileEnd(Result, ExecuteParameters) Export
	SetFileCommandsEnabled();
EndProcedure

&AtClient
Procedure FinishEditEnd(Result, ExecuteParameters) Export
	SetFileCommandsEnabled();
EndProcedure

&AtClient
Procedure SetFileCommandsEnabled()
	
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	FileRef = Items.List.CurrentRow;
	If Not FileCommandsAvailable(FileRef) Then 
		Return;
	EndIf;
	FileData = Items.List.CurrentData;
	
	SetCommandsEnabled(
		FileData.CurrentUserIsEditing,
		FileData.IsEditing,
		FileData.DigitallySigned,
		FileData.Encrypted);
	
EndProcedure

&AtClient
Procedure SetCommandsEnabled(CurrentUserIsEditing, IsEditing, DigitallySigned, Encrypted)
	
	Items.FormEndEdit.Enabled = CurrentUserIsEditing;
	Items.ListContextMenuEndEditing.Enabled = CurrentUserIsEditing;
	
	Items.FormSaveChanges.Enabled = CurrentUserIsEditing;
	Items.ListContextMenuSaveChanges.Enabled = CurrentUserIsEditing;
	
	Items.FormRelease.Enabled = Not IsEditing.IsEmpty();
	Items.ListContextMenuExtend.Enabled = Not IsEditing.IsEmpty();
	
	Items.FormLock.Enabled = IsEditing.IsEmpty() AND Not (DigitallySigned OR Encrypted);
	Items.ListContextMenuLock.Enabled = IsEditing.IsEmpty() AND Not (DigitallySigned OR Encrypted);
	
	Items.FormEdit.Enabled = Not (DigitallySigned OR Encrypted);
	Items.ListContextMenuEdit.Enabled = Not (DigitallySigned OR Encrypted);
	
	Items.FormSign.Enabled = IsEditing.IsEmpty();
	Items.ListContextMenuSign.Enabled = IsEditing.IsEmpty();
	
	Items.FormSaveWithSignature.Enabled = DigitallySigned;
	Items.ListContextMenuSaveWithSignature.Enabled = DigitallySigned;
	
	Items.FormEncrypt.Enabled = IsEditing.IsEmpty() AND Not Encrypted;
	Items.ListContextMenuEncrypt.Enabled = IsEditing.IsEmpty() AND Not Encrypted;
	
	Items.FormDrillDown.Enabled = Encrypted;
	Items.ListContextMenuDecrypt.Enabled = Encrypted;
	
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
	
	If TypeOf(FileRef) = Type("DynamicalListGroupRow") Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtClient
Procedure DraganddropProcessingToLinearList(DragParameters, ListFileOwner)
	// Handler of event Drag in object forms - owners File (except for the Files form).
	//
// Parameters:
//   DragParameters - Drag-and-drop parameters.
	//  ListFileOwner     - AnyRef - file owner.
	
	If TypeOf(DragParameters.Value) = Type("File") AND DragParameters.Value.IsFile() = True Then
		
		AddingParameters = New Structure;
		AddingParameters.Insert("ResultHandler", Undefined);
		AddingParameters.Insert("FullFileName", DragParameters.Value.FullName);
		AddingParameters.Insert("FileOwner", ListFileOwner);
		AddingParameters.Insert("OwnerForm", ThisObject);
		AddingParameters.Insert("CreatedFileName", Undefined);
		AddingParameters.Insert("DoNotOpenCardAfterCreateFromFile", Undefined);
		FileOperationsServiceClient.AddFromFileSystemWithExtension(AddingParameters);
		
	ElsIf TypeOf(DragParameters.Value) = Type("File") AND DragParameters.Value.IsFile() = False Then
		
		ShowMessageBox(, NStr("en='Select only the files without directories.';ru='Выберите только файлы без каталогов.'"));
		Return;
		
	ElsIf TypeOf(DragParameters.Value) = Type("CatalogRef.Files") Then
		
		FileOperationsServiceClient.MoveFileToAttachedFiles(
			DragParameters.Value,
			ListFileOwner);
		
	ElsIf TypeOf(DragParameters.Value) = Type("Array") Then
		If DragParameters.Value.Count() = 0 Then
			Return;
		EndIf;
		
		TypeDragged = TypeOf(DragParameters.Value[0]);
		If TypeDragged = Type("CatalogRef.Files") Then
			FileOperationsServiceClient.MoveFilesToAttachedFiles(
				DragParameters.Value,
				ListFileOwner);
			Return;
		EndIf;
		
		If TypeDragged <> Type("File") Then
			ShowMessageBox(, NStr("en='Select files.';ru='Выберите файлы.'"));
			Return;
		EndIf;
		
		For Each AcceptedFile IN DragParameters.Value Do
			If Not AcceptedFile.IsFile() Then // Only files but not directories.
				ShowMessageBox(, NStr("en='Select only the files without directories.';ru='Выберите только файлы без каталогов.'"));
				Return;
			EndIf;
		EndDo;
		
		AddingParameters = New Structure;
		AddingParameters.Insert("ResultHandler", Undefined);
		AddingParameters.Insert("FullFileName", Undefined);
		AddingParameters.Insert("FileOwner", ListFileOwner);
		AddingParameters.Insert("OwnerForm", ThisObject);
		AddingParameters.Insert("CreatedFileName", Undefined);
		AddingParameters.Insert("DoNotOpenCardAfterCreateFromFile", True);
		
		ErrorsTexts = New Array;
		
		For Each AcceptedFile IN DragParameters.Value Do
			AddingParameters.FullFileName = AcceptedFile.FullName;
			Result = FileOperationsServiceClient.AddFromFileSystemWithExtensionSynchronously(AddingParameters);
			If Not Result.FileAdded AND ValueIsFilled(Result.ErrorText) Then
				ErrorsTexts.Add(Result.ErrorText);
			EndIf;
		EndDo;
		
		// Displaying the errors.
		ErrorsCount = ErrorsTexts.Count();
		If ErrorsCount > 0 Then
			Result = StandardSubsystemsClientServer.NewExecutionResult();
			Result.OutputWarning.Use = True;
			If ErrorsCount = 1 Then
				Result.OutputWarning.Text = ErrorsTexts[0];
			Else
				ShortAllTextErrors = StrReplace(NStr("en='During execution, errors occurred (%1).';ru='При выполнении возникли ошибки (%1).'"), "%1", String(ErrorsCount));
				FullAllTextErrors = "";
				For Each ErrorText IN ErrorsTexts Do
					If FullAllTextErrors <> "" Then
						FullAllTextErrors = FullAllTextErrors + Chars.LF + Chars.LF + "---" + Chars.LF + Chars.LF;
					EndIf;
					FullAllTextErrors = FullAllTextErrors + ErrorText;
				EndDo;
				Result.OutputWarning.Text = ShortAllTextErrors;
				Result.OutputWarning.ErrorsText = FullAllTextErrors;
			EndIf;
			StandardSubsystemsClient.ShowExecutionResult(ThisObject, Result);
		EndIf;
	EndIf;
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
