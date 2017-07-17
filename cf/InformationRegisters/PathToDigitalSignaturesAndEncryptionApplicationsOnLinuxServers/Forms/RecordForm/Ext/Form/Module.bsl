#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.FillingValues.Property("Application")
	   AND ValueIsFilled(Parameters.FillingValues.Application) Then
		
		AutoTitle = False;
		Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Path to application %1 on Linux server';ru='Путь к программе %1 на сервере Linux'"), Parameters.FillingValues.Application);
		
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
