&AtClient
Var Ref1;

&AtClient
Var Ref2;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Items.FormCompare.Visible = Not CommonUseClientServer.IsLinuxClient();
	
	FileCardUUID = Parameters.FileCardUUID;
	
	FillList();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ActivateExecute()
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	FileData = FileOperationsServiceServerCall.FileData(CurrentData.Ref);
	
	If FileData.IsEditing.IsEmpty() Then
		ChangeActiveFileVersion(CurrentData.Ref);
		FillList();
		Notify("Record_File", New Structure("Event", "ActiveVersionChanged"), Parameters.File);
	Else
		ShowMessageBox(, NStr("en = 'Change of the active version is allowed only for the files that are not locked'"));
	EndIf;
	
EndProcedure

&AtClient
Function BypassAllTreeNodes(Items, CurrentVersion)
	
	For Each Version IN Items Do
		
		If Version.Ref = CurrentVersion Then
			ID = Version.GetID();
			Return ID;
		EndIf;
		
		ReturnCode = BypassAllTreeNodes(Version.GetItems(), CurrentVersion);
		If ReturnCode <> -1 Then
			Return ReturnCode;
		EndIf;
	EndDo;
	
	Return -1;
EndFunction

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_File" AND (Parameter.Event = "EditFinished" Or Parameter.Event = "VersionSaved") Then
		
		If Parameters.File = Source Then
			
			CurrentVersion = Items.List.CurrentData.Ref;
			FillList();
			
			ReturnCode = BypassAllTreeNodes(List.GetItems(), CurrentVersion);
			If ReturnCode <> -1 Then
				Items.List.CurrentRow = ReturnCode;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(CurrentData.Ref, UUID);
	FileOperationsServiceClient.OpenFileVersion(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure OpenCard(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then 
		
		Version = CurrentData.Ref;
		
		FormOpenParameters = New Structure("Key", Version);
		OpenForm("Catalog.FileVersions.ObjectForm", FormOpenParameters);
		
	EndIf;	
	
EndProcedure

&AtClient
Procedure ListBeforeDelete(Item, Cancel)
	
	Cancel = True;
	MarkToDeleteUnmark();
	
EndProcedure

&AtClient
Procedure MarkToDelete(Command)
	
	MarkToDeleteUnmark();
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then 
		
		Version = CurrentData.Ref;
		
		FormOpenParameters = New Structure("Key", Version);
		OpenForm("Catalog.FileVersions.ObjectForm", FormOpenParameters);
		
	EndIf;
	
EndProcedure

// Compare 2 selected versions. 
&AtClient
Procedure Compare(Command)
	
	#If WebClient Then
		ShowMessageBox(, NStr("en = 'Versions matching not supported in the web-client.'"));
		Return;
	#EndIf
	
	SelectedRowCount = Items.List.SelectedRows.Count();
	
	If SelectedRowCount = 2 OR SelectedRowCount = 1 Then
		If SelectedRowCount = 2 Then
			Ref1 = List.FindByID(Items.List.SelectedRows[0]).Ref;
			Ref2 = List.FindByID(Items.List.SelectedRows[1]).Ref;
		ElsIf SelectedRowCount = 1 Then
			
			Ref1 = Items.List.CurrentData.Ref;
			Ref2 = Items.List.CurrentData.ParentalVersion;
			
		EndIf;
		
		FileVersionComparisonMethod = Undefined;
		Extension = Lower(Items.List.CurrentData.Extension);
		
		ExtensionIsSupported = (
			    Extension = "txt"
			OR Extension = "doc"
			OR Extension = "docx"
			OR Extension = "rtf"
			OR Extension = "htm"
			OR Extension = "html"
			OR Extension = "odt");
		
		If Not ExtensionIsSupported Then
			WarningText =
				NStr("en = 'Versions matching is supported only for files
				           |   of the following
				           |   types: Text document (.txt) RTF
				           |   document (.rtf) Microsoft Word document (.doc,
				           |   .docx) HTML document (.html
				           |   .htm) Text document OpenDocument (.odt)'");
			ShowMessageBox(, WarningText);
			Return;
		EndIf;
		
		If StandardSubsystemsClientReUse.ClientWorkParameters().ThisIsBasicConfigurationVersion Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'This operation is not supported in the base version.'"));
			Return;
		EndIf;
		
		If Extension = "odt" Then
			FileVersionComparisonMethod = "OpenOfficeOrgWriter";
		ElsIf Extension = "htm" OR Extension = "html" Then
			FileVersionComparisonMethod = "MicrosoftOfficeWord";
		EndIf;
		
		ContinueComparingVersions(FileVersionComparisonMethod);
	EndIf;
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	SelectedRowCount = Items.List.SelectedRows.Count();
	
	CommandComparisonIsAvailable = False;
	
	If SelectedRowCount = 2 Then
		CommandComparisonIsAvailable = True;
	ElsIf SelectedRowCount = 1 Then
		
		If Not Items.List.CurrentData.ParentalVersion.IsEmpty() Then
			CommandComparisonIsAvailable = True;
		Else
			CommandComparisonIsAvailable = False;
		EndIf;
			
	Else
		CommandComparisonIsAvailable = False;
	EndIf;

	If CommandComparisonIsAvailable = True Then
		Items.FormCompare.Enabled = True;
		Items.ContextMenuListCompare.Enabled = True;
	Else
		Items.FormCompare.Enabled = False;
		Items.ContextMenuListCompare.Enabled = False;
	EndIf;
EndProcedure

&AtClient
Procedure OpenVersion(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(CurrentData.Ref, UUID);
	FileOperationsServiceClient.OpenFileVersion(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForSave(CurrentData.Ref, UUID);
	FileOperationsServiceClient.SaveAs(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	Cancel = True;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure ChangeActiveFileVersion(Version)
	
	FileObject = Version.Owner.GetObject();
	LockDataForEdit(FileObject.Ref, , FileCardUUID);
	FileObject.CurrentVersion = Version;
	FileObject.TextStorage = Version.TextStorage;
	FileObject.Write();
	UnlockDataForEdit(FileObject.Ref, FileCardUUID);
	
EndProcedure

&AtServer
Procedure FillList()
	
	Query = New Query(
	"SELECT ALLOWED
	|	FileVersions.Code AS Code,
	|	FileVersions.Size AS Size,
	|	FileVersions.Comment AS Comment,
	|	FileVersions.Author AS Author,
	|	FileVersions.CreationDate AS CreationDate,
	|	FileVersions.FullDescr AS FullDescr,
	|	FileVersions.ParentalVersion AS ParentalVersion,
	|	FileVersions.PictureIndex,
	|	CASE
	|		WHEN FileVersions.DeletionMark = TRUE
	|			THEN 1
	|		ELSE FileVersions.PictureIndex
	|	END AS IndexPictureCurrent,
	|	FileVersions.DeletionMark AS DeletionMark,
	|	FileVersions.Owner AS Owner,
	|	FileVersions.Ref AS Ref,
	|	CASE
	|		WHEN FileVersions.Owner.CurrentVersion = FileVersions.Ref
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS IsCurrent,
	|	FileVersions.Extension AS Extension,
	|	FileVersions.VersionNumber AS VersionNumber
	|FROM
	|	Catalog.FileVersions AS FileVersions
	|WHERE
	|	FileVersions.Owner = &Owner");
	
	Query.SetParameter("Owner", Parameters.File);
	Data = Query.Execute().Unload();
	
	Tree = FormAttributeToValue("List");
	Tree.Rows.Clear();
	
	AddPreviousVersion(Undefined, Tree, Data);
	ValueToFormAttribute(Tree, "List");
	
EndProcedure

&AtServer
Procedure AddPreviousVersion(CurrentBranch, Tree, Data)
	
	FoundString = Undefined;
	
	If CurrentBranch = Undefined Then
		For Each String IN Data Do
			If String.IsCurrent Then
				FoundString = String;
				Break;
			EndIf;
		EndDo;	
	Else
		For Each String IN Data Do
			If String.Ref = CurrentBranch.ParentalVersion Then 
				FoundString = String;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If FoundString <> Undefined Then 
		Branch = Tree.Rows.Add();
		FillPropertyValues(Branch, FoundString);
		Data.Delete(FoundString);
		
		AddSubordinateVersions(Branch, Data);
		AddPreviousVersion(Branch, Tree, Data);
	EndIf;		
	
EndProcedure

&AtServer
Procedure AddSubordinateVersions(Branch, Data)
	
	For Each String IN Data Do
		If Branch.Ref = String.ParentalVersion Then
			FillPropertyValues(Branch.Rows.Add(), String);
		EndIf;
	EndDo;
	
	For Each Sprig IN Branch.Rows Do
		AddSubordinateVersions(Sprig, Data);
	EndDo;
	
EndProcedure

&AtServer
Procedure SetDeletionMark(Version, Mark)
	VersionObject = Version.GetObject();
	VersionObject.Lock();
	VersionObject.SetDeletionMark(Mark);
EndProcedure

&AtClient
Procedure MarkToDeleteUnmark()
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	If CurrentData.DeletionMark Then 
		QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Unmark ""%1"" for deletion?'"),
			String(CurrentData.Ref));
	Else
		QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Mark ""%1"" for deletion?'"),
			String(CurrentData.Ref));
	EndIf;
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("CurrentData", CurrentData);
	Handler = New NotifyDescription("MarkToDeleteUnmarkEnd", ThisObject, HandlerParameters);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure MarkToDeleteUnmarkEnd(Response, ExecuteParameters) Export
	If Response <> DialogReturnCode.Yes Then 
		Return;
	EndIf;
	ExecuteParameters.CurrentData.DeletionMark = Not ExecuteParameters.CurrentData.DeletionMark;
	SetDeletionMark(ExecuteParameters.CurrentData.Ref, ExecuteParameters.CurrentData.DeletionMark);
	
	If ExecuteParameters.CurrentData.DeletionMark Then
		ExecuteParameters.CurrentData.IndexPictureCurrent = 1;
	Else
		ExecuteParameters.CurrentData.IndexPictureCurrent = ExecuteParameters.CurrentData.PictureIndex;
	EndIf;
EndProcedure

&AtClient
Procedure ContinueComparingVersions(FileVersionComparisonMethod)
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("FileVersionComparisonMethod", FileVersionComparisonMethod);
	ExecuteParameters.Insert("CurrentStep", 1);
	ExecuteParameters.Insert("File1Data", Undefined);
	ExecuteParameters.Insert("File2Data", Undefined);
	ExecuteParameters.Insert("Result1", Undefined);
	ExecuteParameters.Insert("Result2", Undefined);
	ExecuteParameters.Insert("FullFileName1", Undefined);
	ExecuteParameters.Insert("FullFileName2", Undefined);
	
	VersionsComparisonAutomatic(-1, ExecuteParameters);
	
EndProcedure

&AtClient
Procedure VersionsComparisonAutomatic(Result, ExecuteParameters) Export
	
	If Result <> -1 Then
		If ExecuteParameters.CurrentStep = 1 Then
			If Result <> DialogReturnCode.OK Then
				Return;
			EndIf;
			
			PersonalSettings = FileFunctionsServiceClientServer.PersonalFileOperationsSettings();
			ExecuteParameters.FileVersionComparisonMethod = PersonalSettings.FileVersionComparisonMethod;
			
			If ExecuteParameters.FileVersionComparisonMethod = Undefined Then
				Return;
			EndIf;
			ExecuteParameters.CurrentStep = 2;
			
		ElsIf ExecuteParameters.CurrentStep = 3 Then
			ExecuteParameters.Result1      = Result.FileReceived;
			ExecuteParameters.FullFileName1 = Result.FullFileName;
			ExecuteParameters.CurrentStep = 4;
			
		ElsIf ExecuteParameters.CurrentStep = 4 Then
			ExecuteParameters.Result2      = Result.FileReceived;
			ExecuteParameters.FullFileName2 = Result.FullFileName;
			ExecuteParameters.CurrentStep = 5;
		EndIf;
	EndIf;
	
	If ExecuteParameters.CurrentStep = 1 Then
		If ExecuteParameters.FileVersionComparisonMethod = Undefined Then
			
			PersonalSettings = FileFunctionsServiceClientServer.PersonalFileOperationsSettings();
			ExecuteParameters.FileVersionComparisonMethod = PersonalSettings.FileVersionComparisonMethod;
			
			If ExecuteParameters.FileVersionComparisonMethod = Undefined Then
				// First call - the setup is not initialized yet.
				Handler = New NotifyDescription("VersionsComparisonAutomatic", ThisObject, ExecuteParameters);
				OpenForm("Catalog.FileVersions.Form.SelectionOfVersionsComparisonMethod", ,
					ThisObject, , , , Handler);
				Return;
			EndIf;
		EndIf;
		ExecuteParameters.CurrentStep = 2;
	EndIf;
	
	If ExecuteParameters.CurrentStep = 2 Then
		
		ExecuteParameters.File1Data = FileOperationsServiceServerCall.FileDataForOpening(
			Ref1, UUID);
		ExecuteParameters.File2Data = FileOperationsServiceServerCall.FileDataForOpening(
			Ref2, UUID);
		
		StatusText = NStr("en = 'Matching of ""%1"" file versions in progress...'");
		StatusText = StrReplace(StatusText, "%1", String(ExecuteParameters.File1Data.Ref));
		Status(StatusText);
		ExecuteParameters.CurrentStep = 3;
	EndIf;
	
	If ExecuteParameters.CurrentStep = 3 Then
		Handler = New NotifyDescription("VersionsComparisonAutomatic", ThisObject, ExecuteParameters);
		FileOperationsServiceClient.GetVersionFileToWorkingDirectory(
			Handler, ExecuteParameters.File1Data, ExecuteParameters.FullFileName1);
		Return;
	EndIf;
	
	If ExecuteParameters.CurrentStep = 4 Then
		Handler = New NotifyDescription("VersionsComparisonAutomatic", ThisObject, ExecuteParameters);
		FileOperationsServiceClient.GetVersionFileToWorkingDirectory(
			Handler, ExecuteParameters.File2Data, ExecuteParameters.FullFileName2);
		Return;
	EndIf;
	
	If ExecuteParameters.CurrentStep = 5 Then
		If ExecuteParameters.Result1 AND ExecuteParameters.Result2 Then
			If ExecuteParameters.File1Data.VersionNumber < ExecuteParameters.File2Data.VersionNumber Then
				FullFileNameLeft  = ExecuteParameters.FullFileName1;
				FullFileNameRight = ExecuteParameters.FullFileName2;
			Else
				FullFileNameLeft  = ExecuteParameters.FullFileName2;
				FullFileNameRight = ExecuteParameters.FullFileName1;
			EndIf;
			FileOperationsServiceClient.CompareFiles(
				FullFileNameLeft,
				FullFileNameRight,
				ExecuteParameters.FileVersionComparisonMethod);
		EndIf;
		Status();
	EndIf;
	
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
