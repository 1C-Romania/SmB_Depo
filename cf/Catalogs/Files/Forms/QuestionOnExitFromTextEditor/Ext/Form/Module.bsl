
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("QuestionText", QuestionText);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure GoBack(Command)
	NotifyChoice("GoBack");
EndProcedure

&AtClient
Procedure DontSave(Command)
	NotifyChoice("DontSave");
EndProcedure

&AtClient
Procedure SaveAndEndEditing(Command)
	NotifyChoice("SaveAndEndEditing");
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	NotifyChoice("SaveChanges");
EndProcedure

#EndRegion














