
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	HTMLDocumentField = OfflineWorkService.InstructionTextFromTemplate(Parameters.TemplateName);
	
	Title = Parameters.Title;
	
EndProcedure

#EndRegion














