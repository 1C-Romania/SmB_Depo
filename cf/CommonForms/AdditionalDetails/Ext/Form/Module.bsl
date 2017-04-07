
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Template = GetCommonTemplate(Parameters.TemplateName);
	
	HTMLDocumentField = Template.GetText();
	
	Title = Parameters.Title;
	
EndProcedure

#EndRegion
