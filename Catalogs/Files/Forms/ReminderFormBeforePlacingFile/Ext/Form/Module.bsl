
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	DontShowAgain = False;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ContinueExecute(Command)
	
	If DontShowAgain = True Then
		CommonUseServerCall.CommonSettingsStorageSaveAndRefreshReusableValues("ApplicationSettings", "ShowFileEditTips", False);
	EndIf;
	
	Close();
	
EndProcedure

#EndRegion
