
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	DontShowAgain = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SystemInfo = New SystemInfo;
	
	If Find(SystemInfo.UserAgentInformation, "Firefox") <> 0 Then
		Items.Additions.CurrentPage = Items.MozillaFireFox;
	Else
		Items.Additions.CurrentPage = Items.Empty;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ContinueExecute(Command)
	If DontShowAgain = True Then
		CommonUseServerCall.CommonSettingsStorageSaveAndRefreshReusableValues(
			"ApplicationSettings",
			"ShowFileEditTips",
			False);
	EndIf;
	Close(DontShowAgain);
EndProcedure

#EndRegion














