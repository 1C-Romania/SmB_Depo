
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	File = Parameters.File;
	Message = Parameters.Message;
	
	FileCreationMode = 1;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SaveFile(Command)
	
	Close(FileCreationMode);
	
EndProcedure

&AtClient
Procedure OpenDirectory(Command)
	
	FileFunctionsServiceClient.OpenExplorerWithFile(File);
	
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
