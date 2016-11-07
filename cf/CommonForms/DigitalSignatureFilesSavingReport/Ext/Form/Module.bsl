#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Text = Parameters.Text;
	FolderWithFiles = Parameters.FolderWithFiles;
	
	Items.FormOpenFolderWithFiles.Visible = ValueIsFilled(FolderWithFiles);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OpenFolderWithFiles(Command)
	
	BeginRunningApplication(New NotifyDescription("OpenFolderWithFilesEnd", ThisObject), FolderWithFiles);
	
EndProcedure

// End of OpenFolderWithFiles procedure.
&AtClient
Procedure OpenFolderWithFilesEnd(ReturnCode, Context) Export
	
	Return;
	
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
