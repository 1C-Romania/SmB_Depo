
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	List.Parameters.SetParameterValue(
		"CurrentUser", Users.CurrentUser());
	
	FileOperationsServiceServerCall.FillFileListConditionalAppearance(List);
	
	OnChangeSigningOrEncryptionUsageAtServer();
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.FormChange.Visible = False;
		Items.ChangeForm82.Visible = True;
	EndIf;
	
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
		Items.List.Refresh();
	EndIf;

	If EventName = "Record_File" AND Parameter.Event = "FileCreated" Then
		Items.List.Refresh();
		If Parameter <> Undefined AND Parameter.File <> Undefined Then
			Items.List.CurrentRow = Parameter.File;
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
	
	StandardProcessing = False;
	FileData = FileOperationsServiceServerCall.FileDataForOpening(Items.List.CurrentRow, UUID);
	FileOperationsServiceClient.OpenFileWithAlert(Undefined, FileData);
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	SetFileCommandsEnabled();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure View(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForOpening(Items.List.CurrentRow, UUID);
	FileOperationsClient.Open(FileData);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FileOperationsServiceServerCall.FileDataForSave(Items.List.CurrentRow, UUID);
	FileOperationsServiceClient.SaveAs(Undefined, FileData, Undefined);
	
EndProcedure

&AtClient
Procedure Release(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	Handler = New NotifyDescription("ReleaseEnd", ThisObject);
	CurrentData = Items.List.CurrentData;
	FileReleaseParameters = FileOperationsServiceClient.FileReleaseParameters(Handler, Items.List.CurrentRow);
	FileReleaseParameters.StoreVersions = CurrentData.StoreVersions;	
	FileReleaseParameters.CurrentUserIsEditing = CurrentData.CurrentUserIsEditing;	
	FileReleaseParameters.IsEditing = CurrentData.IsEditing;	
	FileOperationsServiceClient.ReleaseFileWithAlert(FileReleaseParameters);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	Items.List.Refresh();
	AttachIdleHandler("SetFileCommandsEnabled", 0.1, True);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ReleaseEnd(Result, ExecuteParameters) Export
	SetFileCommandsEnabled();
EndProcedure

// File commands are available - there is at least one row in the list and no grouping is highlighted.
&AtClient
Function FileCommandsAvailable()
	
	If Items.List.CurrentRow = Undefined Then 
		Return False;
	EndIf;
	
	If TypeOf(Items.List.CurrentRow) = Type("DynamicalListGroupRow") Then
		Return False;
	EndIf;	
	
	Return True;
	
EndFunction

&AtClient
Procedure SetFileCommandsEnabled()
	
	If Items.List.CurrentData <> Undefined Then
		
		If TypeOf(Items.List.CurrentRow) <> Type("DynamicalListGroupRow") Then
			
			SetCommandsEnabled(Items.List.CurrentData.CurrentUserIsEditing,
				Items.List.CurrentData.IsEditing);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetCommandsEnabled(CurrentUserIsEditing, IsEditing)
	
	Items.FormRelease.Enabled = Not IsEditing.IsEmpty();
	Items.ListContextMenuExtend.Enabled = Not IsEditing.IsEmpty();
	
EndProcedure

&AtClient
Procedure OnChangeSigningOrEncryptionUsage()
	
	OnChangeSigningOrEncryptionUsageAtServer();
	
EndProcedure

&AtServer
Procedure OnChangeSigningOrEncryptionUsageAtServer()
	
	FileFunctionsService.CryptographyOnCreateFormAtServer(ThisObject,, True);
	
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
