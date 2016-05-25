
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
