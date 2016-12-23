
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.Property("FileOwner") Then 
		List.Parameters.SetParameterValue(
			"Owner", Parameters.FileOwner);
	
		If TypeOf(Parameters.FileOwner) = Type("CatalogRef.FileFolders") Then
			Items.Folders.CurrentRow = Parameters.FileOwner;
			Items.Folders.SelectedRows.Clear();
			Items.Folders.SelectedRows.Add(Items.Folders.CurrentRow);
		Else
			Items.Folders.Visible = False;
		EndIf;
	Else
		If Parameters.Property("ChoosingTemplate") AND Parameters.ChoosingTemplate Then
			
			CommonUseClientServer.SetFilterDynamicListItem(
				Folders, "Ref", Catalogs.FileFolders.Patterns,
				DataCompositionComparisonType.InHierarchy, , True);
			
			Items.Folders.CurrentRow = Catalogs.FileFolders.Patterns;
			Items.Folders.SelectedRows.Clear();
			Items.Folders.SelectedRows.Add(Items.Folders.CurrentRow);
		EndIf;
		
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;
	
	If Parameters.Property("CurrentRow") Then 
		Items.Folders.CurrentRow = Parameters.CurrentRow;
	EndIf;
	
	OnChangeSigningOrEncryptionUsageAtServer();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
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
	
	If Upper(EventName) = Upper("Record_ConstantsSet")
	   AND (    Upper(Source) = Upper("UseDigitalSignatures")
		  Or Upper(Source) = Upper("UseEncryption")) Then
			
		AttachIdleHandler("OnChangeSigningOrEncryptionUsage", 0.3, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersFolders

&AtClient
Procedure FoldersOnActivateRow(Item)
	AttachIdleHandler("IdleProcessing", 0.2, True);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure AddFile(Command)
	DCParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
	If DCParameterValue = Undefined Then
		FileOwner = Undefined;
	Else
		FileOwner = DCParameterValue.Value;
	EndIf;
	FileOperationsServiceClient.AddFile(Undefined, FileOwner, ThisObject);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure updates File list.
&AtClient
Procedure IdleProcessing()
	
	If Items.Folders.CurrentRow <> Undefined Then
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;
	
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














