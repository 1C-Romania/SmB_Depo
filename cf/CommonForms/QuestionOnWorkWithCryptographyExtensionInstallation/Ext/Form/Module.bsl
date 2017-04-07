
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not IsBlankString(Parameters.QuestionTitle) Then
		Title = Parameters.QuestionTitle;
	EndIf;
	
	If Not IsBlankString(Parameters.QuestionText) Then
		Items.Explanation.Title = Parameters.QuestionText;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure InstallAndContinue(Command)
	
	Close(DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close();
	
EndProcedure

#EndRegion
