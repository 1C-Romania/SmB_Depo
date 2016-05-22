
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	FillList();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FillListInForm();
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Items.List.CurrentData = Undefined Then
		CommandsEnabled = False;
	Else
		CommandsEnabled = True;
	EndIf;
	
	Items.FormDeleteFromLocalFileCache.Enabled = CommandsEnabled;
	Items.ListContextMenuDeleteFromLocalFileCache.Enabled = CommandsEnabled;
	
	Items.FormEndEdit.Enabled = CommandsEnabled;
	Items.ListContextMenuEndEditing.Enabled = CommandsEnabled;
	
	Items.FormRelease.Enabled = CommandsEnabled;
	Items.ListContextMenuExtend.Enabled = CommandsEnabled;
	
	Items.FormOpenFileDirectory.Enabled = CommandsEnabled;
	Items.ListContextMenuOpenFileCatalog.Enabled = CommandsEnabled;
	
	Items.FormOpenCard.Enabled = CommandsEnabled;
	Items.ListContextMenuOpenCard.Enabled = CommandsEnabled;
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	Cancel = True;
	OpenCardExecute();
EndProcedure

&AtClient
Procedure ListBeforeDelete(Item, Cancel)
	Cancel = True;
	DeleteFromLocalFilesCacheExecute();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure DeleteFromFilesLocalCache(Command)
	DeleteFromLocalFilesCacheExecute();
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	TableRow = Items.List.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileData(TableRow.Version);
	Handler = New NotifyDescription("FinishEditEnd", ThisObject);
	FileUpdateParameters = FileOperationsServiceClient.FileUpdateParameters(Handler, FileData.Ref, UUID);
	FileOperationsServiceClient.EndEditingWithAlert(FileUpdateParameters);
	
EndProcedure

&AtClient
Procedure OpenCard(Command)
	OpenCardExecute();
EndProcedure

&AtClient
Procedure ReleaseExecute()
	
	Handler = New NotifyDescription("ReleaseAfterExpansionInstallation", ThisObject);
	FileFunctionsServiceClient.ShowQuestionAboutFileOperationsExtensionSetting(Handler);
	
EndProcedure

&AtClient
Procedure OpenFileDirectoryExecute()
	
	TableRow = Items.List.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileData(TableRow.Version);
	FileOperationsServiceClient.FileDir(Undefined, FileData);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure FinishEditEnd(Result, ExecuteParameters) Export
	
	FillList();
	FillListInForm();
	
EndProcedure

&AtClient
Procedure ReleaseAfterExpansionInstallation(Result, ExecuteParameters) Export
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("RefArray", New Array);
	
	For Each Item IN Items.List.SelectedRows Do
		RowData = Items.List.RowData(Item);
		Ref = RowData.Version;
		ExecuteParameters.RefArray.Add(Ref);
	EndDo;
	
	ExecuteParameters.Insert("IndexOf", 0);
	ExecuteParameters.Insert("UBound", ExecuteParameters.RefArray.UBound());
	
	ReleaseInCycle(ExecuteParameters);
	
EndProcedure

&AtClient
Procedure ReleaseInCycle(ExecuteParameters)
	
	FileOperationsServiceClient.RegisterHandlerDescription(
		ExecuteParameters, ThisObject, "ReleaseInCycleContinue");
	
	CallParameters = New Structure;
	CallParameters.Insert("ResultHandler",           ExecuteParameters);
	CallParameters.Insert("ObjectRef",               Undefined);
	CallParameters.Insert("Version",                 Undefined);
	CallParameters.Insert("StoreVersions",           Undefined);
	CallParameters.Insert("CurrentUserIsEditing",    Undefined);
	CallParameters.Insert("IsEditing",               Undefined);
	CallParameters.Insert("UUID",                    Undefined);
	CallParameters.Insert("DoNotAskQuestion",        False);
	
	For IndexOf = ExecuteParameters.IndexOf To ExecuteParameters.UBound Do
		ExecuteParameters.IndexOf = IndexOf;
		CallParameters.Version = ExecuteParameters.RefArray[IndexOf];
		
		FileOperationsServiceClient.UnlockFileAfterExtensionInstallation(
			Undefined, CallParameters);
		
		If ExecuteParameters.AsynchronousDialog.Open = True Then
			Return;
		EndIf;
	EndDo;
	
	FillList();
	FillListInForm();
	
EndProcedure

&AtClient
Procedure ReleaseInCycleContinue(Result, ExecuteParameters) Export
	
	ExecuteParameters.AsynchronousDialog.Open = False;
	ExecuteParameters.IndexOf = ExecuteParameters.IndexOf + 1;
	ReleaseInCycle(ExecuteParameters);
	
EndProcedure

&AtClient
Procedure FillListInForm()
	
	UserWorkingDirectory = FileFunctionsServiceClient.UserWorkingDirectory();
	
	List.Clear();
	
	For Each String IN ListOfFileValuesInRegister Do
		
		FullPath = UserWorkingDirectory + String.Value.PartialPath;
		File = New File(FullPath);
		If File.Exist() Then
			NewRow = List.Add();
			NewRow.ChangeDate    = ToLocalTime(String.Value.ModificationDateUniversal);
			NewRow.FileName      = String.Value.FullDescr;
			NewRow.PictureIndex  = String.Value.PictureIndex;
			NewRow.Size          = Format(String.Value.Size / 1024, "ND=10; NZ=0"); // in Kb
			NewRow.Version       = String.Value.Ref;
			NewRow.IsEditing     = String.Value.IsEditing;
			NewRow.ToEdit        = ValueIsFilled(String.Value.IsEditing);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure DeleteByRef(RefToDelete)
	
	ItemCount = List.Count();
	
	For Number = 0 To ItemCount - 1 Do
		String = List[Number];
		Ref = String.Version;
		If Ref = RefToDelete Then
			List.Delete(Number);
			Return;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillList()
	
	ListInRegister = ListInRegister();
	ListOfFileValuesInRegister.Clear();
	
	For Each String IN ListInRegister Do
		ListOfFileValuesInRegister.Add(String);
	EndDo;

EndProcedure

&AtClient
Procedure DeleteFromLocalFilesCacheExecute()
	
	QuestionText = NStr("en = 'Do you want to delete the selected files out of the main work directory?'");
	Handler = New NotifyDescription("DeleteFromLocalCacheAfterAnsweringQuestion", ThisObject);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure DeleteFromLocalCacheAfterAnsweringQuestion(Response, ExecuteParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("RefArray", New Array);
	For Each LoopNumber IN Items.List.SelectedRows Do
		RowData = Items.List.RowData(LoopNumber);
		ExecuteParameters.RefArray.Add(RowData.Version);
	EndDo;
	
	ExecuteParameters.Insert("IndexOf", 0);
	ExecuteParameters.Insert("UBound", ExecuteParameters.RefArray.UBound());
	ExecuteParameters.Insert("Ref", Undefined);
	ExecuteParameters.Insert("IsLockedFiles", False);
	ExecuteParameters.Insert("DirectoryName", FileFunctionsServiceClient.UserWorkingDirectory());

	DeleteFromLocalCacheFilesInCycle(ExecuteParameters);
	
EndProcedure

&AtClient
Procedure DeleteFromLocalCacheFilesInCycle(ExecuteParameters)
	
	FileOperationsServiceClient.RegisterHandlerDescription(ExecuteParameters, ThisObject, "DeleteFromLocalCacheFilesInCycleContinue");
	
	For IndexOf = ExecuteParameters.IndexOf To ExecuteParameters.UBound Do
		ExecuteParameters.IndexOf = IndexOf;
		ExecuteParameters.Ref = ExecuteParameters.RefArray[IndexOf];
		
		If FileIsBusy(ExecuteParameters.Ref) Then
			Rows = List.FindRows(New Structure("Version", ExecuteParameters.Ref));
			Rows[0].ToEdit = True;
			ExecuteParameters.IsLockedFiles = True;
			ExecuteParameters.AsynchronousDialog.Open = False;
			ExecuteParameters.IndexOf = ExecuteParameters.IndexOf + 1;
			Continue;
		EndIf;
		
		ExecuteParameters.Insert("FileNameWithPath",
			FileOperationsServiceServerCall.GetFullFileNameFromRegister(
				ExecuteParameters.Ref, ExecuteParameters.DirectoryName, False, False));
		
		FileOperationsServiceClient.DeleteFileFromWorkingDirectory(
			ExecuteParameters, ExecuteParameters.Ref);
		
		If ExecuteParameters.AsynchronousDialog.Open = True Then
			Return;
		EndIf;
		
		If ExecuteParameters.FileNameWithPath <> "" Then
			FileOnDrive = New File(ExecuteParameters.FileNameWithPath);
			If Not FileOnDrive.Exist() Then
				DeleteByRef(ExecuteParameters.Ref);
			EndIf;
		Else
			DeleteByRef(ExecuteParameters.Ref);
		EndIf;
	EndDo;
	
	If ExecuteParameters.IsLockedFiles Then
		ShowMessageBox(,
			NStr("en = 'You can not delete files from
			           |main working directory held for editing.'"));
	EndIf;
	
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure DeleteFromLocalCacheFilesInCycleContinue(Result, ExecuteParameters) Export
	
	// Ending operations with file.
	If ExecuteParameters.FileNameWithPath <> "" Then
		FileOnDrive = New File(ExecuteParameters.FileNameWithPath);
		If Not FileOnDrive.Exist() Then
			DeleteByRef(ExecuteParameters.Ref);
		EndIf;
	Else
		DeleteByRef(ExecuteParameters.Ref);
	EndIf;
	
	// Continue the cycle.
	ExecuteParameters.AsynchronousDialog.Open = False;
	ExecuteParameters.IndexOf = ExecuteParameters.IndexOf + 1;
	DeleteFromLocalCacheFilesInCycle(ExecuteParameters);
	
EndProcedure

&AtClient
Procedure OpenCardExecute()
	
	TableRow = Items.List.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileData(TableRow.Version);
	ShowValue(, FileData.Ref);
	
EndProcedure

&AtServer
Function ListInRegister()
	
	SetPrivilegedMode(True);
	
	ValueList = New Array;
	CurrentUser = Users.CurrentUser();
	
	// We find record in the info register for our each record - we take the Version and IsEditing fields from there.
	QueryOnTable = New Query;
	QueryOnTable.SetParameter("User", CurrentUser);
	QueryOnTable.Text =
	"SELECT
	|	FilesInWorkingDirectory.Version AS Ref,
	|	FilesInWorkingDirectory.ForRead AS ForRead,
	|	FilesInWorkingDirectory.Size AS Size,
	|	FilesInWorkingDirectory.Path AS Path,
	|	FilesInWorkingDirectory.Version.ModificationDateUniversal AS ModificationDateUniversal,
	|	FilesInWorkingDirectory.Version.FullDescr AS FullDescr,
	|	FilesInWorkingDirectory.Version.PictureIndex AS PictureIndex,
	|	FilesInWorkingDirectory.Version.Owner.IsEditing AS IsEditing,
	|	FilesInWorkingDirectory.Version.Owner AS File
	|FROM
	|	InformationRegister.FilesInWorkingDirectory AS FilesInWorkingDirectory
	|WHERE
	|	FilesInWorkingDirectory.User = &User
	|	AND FilesInWorkingDirectory.InOwnerWorkingDirectory = FALSE";
	
	QueryResult = QueryOnTable.Execute(); 
	
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		
		While Selection.Next() Do
			Record = New Structure;
			Record.Insert("ModificationDateUniversal", Selection.ModificationDateUniversal);
			Record.Insert("FullDescr",           Selection.FullDescr);
			Record.Insert("PictureIndex",               Selection.PictureIndex);
			Record.Insert("Size",                       Selection.Size);
			Record.Insert("Ref",                       Selection.Ref);
			Record.Insert("IsEditing",                  Selection.IsEditing);
			Record.Insert("ForRead",                     Selection.ForRead);
			Record.Insert("PartialPath",                Selection.Path);
			
			ValueList.Add(Record);
		EndDo;
	EndIf;
	
	Return ValueList;
	
EndFunction

&AtServerNoContext
Function FileIsBusy(Ref)
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	
	Query.Text = 
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.FileVersions AS FileVersions
	|WHERE
	|	FileVersions.Ref = &Ref
	|	AND FileVersions.Owner.IsEditing <> VALUE(Catalog.Users.EmptyRef)";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

#EndRegion
