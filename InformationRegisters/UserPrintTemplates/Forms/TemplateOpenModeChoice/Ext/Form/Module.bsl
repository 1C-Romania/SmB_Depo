
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Value = CommonUse.CommonSettingsStorageImport(
		"SettingOpeningTemplates", 
		"AskTemplateOpeningMode");
	
	If Value = Undefined Then
		DontAskAgain = False;
	Else
		DontAskAgain = Not Value;
	EndIf;
	
	Value = CommonUse.CommonSettingsStorageImport(
		"SettingOpeningTemplates", 
		"TemplateOpeningModeView");
	
	If Value = Undefined Then
		HowToOpen = 0;
	Else
		If Value Then
			HowToOpen = 0;
		Else
			HowToOpen = 1;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	AskTemplateOpeningMode = Not DontAskAgain;
	TemplateOpeningModeView = ?(HowToOpen = 0, True, False);
	
	SaveSettingsOfTemplateOpeningMode(AskTemplateOpeningMode, TemplateOpeningModeView);
	
	NotifyChoice(New Structure("DontAskAgain, OpeningModeView",
							DontAskAgain,
							TemplateOpeningModeView) );
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Procedure SaveSettingsOfTemplateOpeningMode(AskTemplateOpeningMode, TemplateOpeningModeView)
	
	CommonUse.CommonSettingsStorageSave(
		"SettingOpeningTemplates", 
		"AskTemplateOpeningMode", 
		AskTemplateOpeningMode);
	
	CommonUse.CommonSettingsStorageSave(
		"SettingOpeningTemplates", 
		"TemplateOpeningModeView", 
		TemplateOpeningModeView);
	
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
