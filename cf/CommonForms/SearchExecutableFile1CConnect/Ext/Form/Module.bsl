#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SystemInfo = New SystemInfo;
	ClientID = SystemInfo.ClientID;
	PathToFile = IntegrationWith1CConnectServerCall.ExecutableFileLocation(ClientID);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If Not IntegrationWith1CConnectClient.IsWindowsClient() Then
		ShowMessageBox(,NStr("en = To work with the 1C-Connect application, you need to have Microsoft Windows operating system.'"));
		Cancel = True;
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure FilePathStartChoice(Item, ChoiceData, StandardProcessing)
	Notification = New NotifyDescription("PathToFileStartChoiceEnd", ThisObject);
	IntegrationWith1CConnectClient.Select1CConnectFile(Notification, PathToFile);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Save(Command)
	
	ClientID = IntegrationWith1CConnectClient.ClientID();
	// Writes the path to the executable file in the information register.
	NewPathToExecutableFile(ClientID, PathToFile); 
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure PathToFileStartChoiceEnd(NewPathToFile, AdditionalParameters) Export
	If NewPathToFile <> "" Then
		PathToFile = NewPathToFile;
	EndIf;
EndProcedure

&AtServerNoContext
Procedure NewPathToExecutableFile(ClientID, PathToFile)
	IntegrationWith1CConnect.Save1CConnectExecutableFileLocation(ClientID, PathToFile);
EndProcedure 

#EndRegion
 





