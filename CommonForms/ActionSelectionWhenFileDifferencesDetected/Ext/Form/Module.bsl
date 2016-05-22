
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	FillPropertyValues(
		ThisObject,
		Parameters,
		"ChangingDateInWorkingDirectory,
		|ChangingDateInFileStore,
		|FullFileNameInWorkingDirectory,
		|SizeInWorkingDirectory,
		|SizeInFileStorage,
		|Message,
		|Title");
	
	If Parameters.ActionWithFile = "PlacementInFileStore" Then
		
		Items.FormOpenExisting.Visible = False;
		Items.FormTakeFromStore.Visible    = False;
		Items.FormPutInto.DefaultButton   = True;
		
	ElsIf Parameters.ActionWithFile = "OpeningInWorkingDirectory" Then
		
		Items.FormPutInto.Visible  = False;
		Items.FormNotPlace.Visible = False;
		Items.FormOpenExisting.DefaultButton = True;
	Else
		Raise NStr("en = 'Unknown action with file'");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OpenExisting(Command)
	
	Close("OpenExisting");
	
EndProcedure

&AtClient
Procedure Place(Command)
	
	Close("INTO");
	
EndProcedure

&AtClient
Procedure TakeFromStore(Command)
	
	Close("TakeFromStorageAndOpen");
	
EndProcedure

&AtClient
Procedure NotPlace(Command)
	
	Close("NotPlace");
	
EndProcedure

&AtClient
Procedure OpenDirectory(Command)
	
	FileFunctionsServiceClient.OpenExplorerWithFile(FullFileNameInWorkingDirectory);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close("Cancel");
	
EndProcedure

#EndRegion
