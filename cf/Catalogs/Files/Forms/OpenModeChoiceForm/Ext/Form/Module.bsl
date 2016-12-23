
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	DontAskAgain = False;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OpenFile(Command)
	If DontAskAgain = True Then
		CommonUseServerCall.CommonSettingsStorageSaveAndRefreshReusableValues(
			"OpenFileSettings",
			"PromptForEditModeOnOpenFile",
			False);
	EndIf;
	
	ChoiceResult = New Structure;
	ChoiceResult.Insert("DontAskAgain", DontAskAgain);
	ChoiceResult.Insert("HowToOpen", HowToOpen);
	NotifyChoice(ChoiceResult);
EndProcedure

&AtClient
Procedure Cancel(Command)
	NotifyChoice(DialogReturnCode.Cancel);
EndProcedure

#EndRegion














