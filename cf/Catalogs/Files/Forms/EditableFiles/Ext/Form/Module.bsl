
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	If Not CommonUse.OnCreateAtServer(ThisObject, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	User = Users.CurrentUser();
	List.Parameters.SetParameterValue("IsEditing", User);
	
	ShowColumnSize = FileOperationsServiceServerCall.GetShowColumnSize();
	If ShowColumnSize = False Then
		Items.ListCurrentVersionSize.Visible = False;
	EndIf;
	
	ExitApplication = Undefined;
	If Parameters.Property("ExitApplication", ExitApplication) Then 
		Response = ExitApplication;
		If Response = True Then
			Items.ShowLockedFilesOnExit.Visible = Response;
			Items.CommandBarGroup.Visible                     = Response;
		EndIf;
	EndIf;
	
	ShowLockedFilesOnExit = CommonUse.CommonSettingsStorageImport(
		"ApplicationSettings", 
		"ShowLockedFilesOnExit", True);
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

// Event DataProcessor Selection from the list.
//
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

&AtClient
Procedure ListOnActivateRow(Item)
	
	SetCommandsEnabled();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure EndEdit(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FileUpdateParameters = FileOperationsServiceClient.FileUpdateParameters(Undefined, CurrentData.Ref, UUID);
	FileUpdateParameters.StoreVersions = CurrentData.StoreVersions;
	FileUpdateParameters.CurrentUserIsEditing = True;
	FileUpdateParameters.IsEditing = CurrentData.IsEditing;
	FileUpdateParameters.CurrentVersionAuthor = CurrentData.CurrentVersionAuthor;
	FileOperationsServiceClient.EndEditingWithAlert(FileUpdateParameters);
	
EndProcedure

&AtClient
Procedure OpenFile(Command)
	
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(Items.List.CurrentRow, UUID);
	FileOperationsClient.Open(FileData);
	
EndProcedure

&AtClient
Procedure Release(Command)
	
	TableRow = Items.List.CurrentRow;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	FileReleaseParameters = FileOperationsServiceClient.FileReleaseParameters(Undefined, TableRow);
	FileReleaseParameters.StoreVersions = CurrentData.StoreVersions;	
	FileReleaseParameters.CurrentUserIsEditing = True;	
	FileReleaseParameters.IsEditing = CurrentData.IsEditing;	
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
	
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(Items.List.CurrentRow, UUID);
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
		
	CommonUseServerCall.CommonSettingsStorageSaveArrayAndUpdateReUseValues(StructuresArray);
	Close();	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	Items.List.Refresh();
	
	AttachIdleHandler("SetCommandsEnabled", 0.1, True);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetCommandsEnabled()
	
	Enabled = Items.List.CurrentRow <> Undefined;
	
	Items.FormEndEdit.Enabled = Enabled;
	Items.ListContextMenuEndEditing.Enabled = Enabled;
	
	Items.FormOpen.Enabled = Enabled;
	Items.ListContextMenuOpen.Enabled = Enabled;
	
	Items.FormChange.Enabled = Enabled;
	
	Items.ListContextMenuSaveChanges.Enabled = Enabled;
	Items.ListContextMenuOpenFileCatalog.Enabled = Enabled;
	Items.ListContextMenuSaveAs.Enabled = Enabled;
	Items.ListContextMenuExtend.Enabled = Enabled;
	Items.ListContextMenuUpdateFromFileOnDisc.Enabled = Enabled;
	
EndProcedure

Function SettingDetails(Object, Setup, Value)
	
	Item = New Structure;
	Item.Insert("Object", Object);
	Item.Insert("Setting", Setup);
	Item.Insert("Value", Value);
	
	Return Item;
	
EndFunction

#EndRegion














