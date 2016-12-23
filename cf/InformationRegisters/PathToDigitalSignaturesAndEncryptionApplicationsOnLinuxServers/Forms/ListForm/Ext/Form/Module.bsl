#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Filter.Property("Application") 
	   AND ValueIsFilled(Parameters.Filter.Application) Then
		
		Application = Parameters.Filter.Application;
		
		AutoTitle = False;
		Title = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Paths to the application %1 on Linux servers';ru='Пути к программе %1 на серверах Linux'"), Application);
		
		Items.ListApplication.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	If Not ValueIsFilled(Application) Then
		Return;
	EndIf;
	
	Cancel = True;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key", Items.List.CurrentRow);
	FormParameters.Insert("FillingValues", New Structure("Application", Application));
	
	OpenForm("InformationRegister.PathToDigitalSignaturesAndEncryptionApplicationsOnLinuxServers.RecordForm",
		FormParameters, Items.List, ,,,, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ListBeforeDelete(Item, Cancel)
	
	RemovedRow          = Items.List.CurrentRow;
	RemovedStringApplication = Items.List.CurrentData.Application;
	
EndProcedure

&AtClient
Procedure ListAfterDeletion(Item)
	
	Notify("Write_PathsToDigitalSignatureAndEncryptionFilesAtServersLinux",
		New Structure("Application", RemovedStringApplication), RemovedRow);
	
EndProcedure

#EndRegion














