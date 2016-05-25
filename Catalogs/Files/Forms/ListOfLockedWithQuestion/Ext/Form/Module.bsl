
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	MessageQuestion = Parameters.MessageQuestion;
	MessageTitle = Parameters.MessageTitle;
	Title = Parameters.Title;
	
	YesButtonTitle = Undefined;
	If Parameters.Property("YesButtonTitle", YesButtonTitle) Then 
		Items.Yes.Title = YesButtonTitle;
	EndIf;
	
	TitleNoButton = Undefined;
	If Parameters.Property("TitleNoButton", TitleNoButton) Then 
		Items.No.Title = TitleNoButton;
	EndIf;
	
	If ValueIsFilled(Parameters.FileOwner) Then 
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "FileOwner", Parameters.FileOwner);
	EndIf;
		
	If ValueIsFilled(Parameters.IsEditing) Then 
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "IsEditing", Parameters.IsEditing);
	EndIf;
		
	ExitApplication = Undefined;
	If Parameters.Property("ExitApplication", ExitApplication) Then 
		Response = ExitApplication;
		If Response = True Then
			Items.ShowLockedFilesOnExit.Visible = Response;
			WindowOpeningMode = FormWindowOpeningMode.LockWholeInterface;
		EndIf;
	EndIf;
	
	ShowLockedFilesOnExit = CommonUse.CommonSettingsStorageImport(
		"ApplicationSettings", 
		"ShowLockedFilesOnExit", True);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_File" AND Parameter.Event = "EditFinished" Then
		Items.List.Refresh(); 
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	FileData = FileOperationsServiceServerCall.FileDataForOpening(SelectedRow, UUID);
	FileOperationsServiceClient.OpenFileWithAlert(Undefined, FileData);
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OpenFile(Command)
	
	TableRow = Items.List.CurrentRow;
	If TableRow = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(TableRow, UUID);
	FileOperationsClient.Open(FileData);
	
EndProcedure

&AtClient
Procedure Release(Command)
	
	TableRow = Items.List.CurrentRow;
	If TableRow = Undefined Then 
		Return;
	EndIf;
	
	FileReleaseParameters = FileOperationsServiceClient.FileReleaseParameters(Undefined, TableRow);
	FileReleaseParameters.StoreVersions = TableRow.StoreVersions;	
	FileReleaseParameters.CurrentUserIsEditing = True;	
	FileReleaseParameters.IsEditing = TableRow.IsEditing;	
	FileOperationsServiceClient.ReleaseFileWithAlert(FileReleaseParameters);
	
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	
	TableRow = Items.List.CurrentRow;
	If TableRow = Undefined Then 
		Return;
	EndIf;
	
	FileOperationsServiceClient.SaveFileChangesWithAlert(
		Undefined,
		TableRow,
		UUID);
	
EndProcedure

&AtClient
Procedure OpenFileDirectory(Command)
	
	TableRow = Items.List.CurrentRow;
	If TableRow = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(TableRow, UUID);
	FileOperationsClient.OpenFileDirectory(FileData);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	TableRow = Items.List.CurrentRow;
	If TableRow = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForSave(TableRow, UUID);
	FileOperationsServiceClient.SaveAs(Undefined, FileData, Undefined);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnDrive(Command)
	
	TableRow = Items.List.CurrentRow;
	If TableRow = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataAndWorkingDirectory(TableRow);
	FileOperationsServiceClient.UpdateFromFileOnDiskWithAlert(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	StructuresArray = New Array;
	
	StructuresArray.Add(SettingDetails(
	    "ApplicationSettings",
	    "ShowLockedFilesOnExit",
	    ShowLockedFilesOnExit));
		
	CommonUseServerCall.CommonSettingsStorageSaveArray(StructuresArray);
	
	Close(DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	TableRow = Items.List.CurrentData;
	If TableRow = Undefined Then 
		Return;
	EndIf;
	
	FileUpdateParameters = FileOperationsServiceClient.FileUpdateParameters(Undefined, TableRow.Ref, UUID);
	FileUpdateParameters.StoreVersions = TableRow.StoreVersions;
	FileUpdateParameters.CurrentUserIsEditing = True;
	FileUpdateParameters.IsEditing = TableRow.IsEditing;
	FileOperationsServiceClient.EndEditingWithAlert(FileUpdateParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Function SettingDetails(Object, Setup, Value)
	
	Item = New Structure;
	Item.Insert("Object", Object);
	Item.Insert("Settings", Setup);
	Item.Insert("Value", Value);
	
	Return Item;
	
EndFunction

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
