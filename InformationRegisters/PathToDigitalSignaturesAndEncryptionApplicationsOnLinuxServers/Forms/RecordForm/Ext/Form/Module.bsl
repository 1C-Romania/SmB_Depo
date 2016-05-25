#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.FillingValues.Property("Application")
	   AND ValueIsFilled(Parameters.FillingValues.Application) Then
		
		AutoTitle = False;
		Title = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Path to the application %1 on Linux server'"), Parameters.FillingValues.Application);
		
		Items.Application.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// It is needed to update the list of applications
	// and their parameters on the server and on the client.
	RefreshReusableValues();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_PathsToDigitalSignatureAndEncryptionFilesAtServersLinux",
		New Structure("Application", Record.Application), Record.SourceRecordKey);
	
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
