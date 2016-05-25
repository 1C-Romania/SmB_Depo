// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("WorkSchedule") Then
		Record.WorkSchedule = Parameters.WorkSchedule;
	EndIf;
	
EndProcedure // OnCreateAtServer()



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
