
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Parameters.ProgrammOpening Then
		Raise
			NStr("en = 'Data processor is not aimed for being used directly'");
	EndIf;
	
	SkipRestart = Parameters.SkipRestart;
	
	TemplateDocument = DataProcessors.SoftwareUpdateLegality.GetTemplate(
		"TermsOfUpdatesDistribution");
	
	WarningText = TemplateDocument.GetText();
	ChoiceConfirmation = 0; // User has to select clearly one of the variants.
	Items.Note.Visible = Parameters.ShowWarningAboutRestart;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure FormMainActionsContinue(Command)
	
	Result = ChoiceConfirmation = 1;
	
	If Result <> True Then
		If Parameters.ShowWarningAboutRestart AND Not SkipRestart Then
			Terminate();
		EndIf;
	Else
		WriteUpdatesReceiveLegalityConfirmation();
	EndIf;
	
	Close(Result);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If Result <> True Then
		If Parameters.ShowWarningAboutRestart AND Not SkipRestart Then
			Terminate();
		EndIf;
	Else
		WriteUpdatesReceiveLegalityConfirmation();
	EndIf;
	
	Notify("SoftwareUpdateLegality", Result);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Procedure WriteUpdatesReceiveLegalityConfirmation()
	
	SetPrivilegedMode(True);
	
	InfobaseUpdateService.WriteUpdatesReceiveLegalityConfirmation();
	
EndProcedure

#EndRegion
