
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Property("VariantPresentation") AND ValueIsFilled(Parameters.VariantPresentation) Then
		AutoTitle = False;
		Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Report setting change ""%1""';ru='Изменение настроек отчета ""%1""'"),
			Parameters.VariantPresentation);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersSettingComposerUserSettings

&AtClient
Procedure SettingsComposerUserSettingsOnChange(Item)
	UserSettingsModified = True;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure FinishEdit(Command)
	If ModalMode
		Or WindowOpeningMode = FormWindowOpeningMode.LockWholeInterface
		Or FormOwner = Undefined Then
		Close(True);
	Else
		ChoiceResult = New Structure;
		ChoiceResult.Insert("VariantModified", False);
		ChoiceResult.Insert("UserSettingsModified", False);
		
		If VariantModified Then
			ChoiceResult.VariantModified = True;
			ChoiceResult.Insert("DCSettings", Report.SettingsComposer.Settings);
		EndIf;
		
		If VariantModified Or UserSettingsModified Then
			ChoiceResult.UserSettingsModified = True;
			ChoiceResult.Insert("DCUserSettings", Report.SettingsComposer.UserSettings);
		EndIf;
		
		NotifyChoice(ChoiceResult);
	EndIf;
EndProcedure

#EndRegion
