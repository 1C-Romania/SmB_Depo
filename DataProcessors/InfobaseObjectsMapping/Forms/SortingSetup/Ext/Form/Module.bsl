
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	SortTable.Load(Parameters.SortTable.Unload());
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Apply(Command)
	
	NotifyChoice(SortTable);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	NotifyChoice(Undefined);
	
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
