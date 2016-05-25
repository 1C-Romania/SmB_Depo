
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Information = Parameters.Information;
	Title =  Parameters.Title;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Yes(Command)
	ReturnStructure = New Structure("ApplyToAll, ReturnCode", 
		ApplyToAll, DialogReturnCode.Yes);
	Close(ReturnStructure);
EndProcedure

&AtClient
Procedure No(Command)
	ReturnStructure = New Structure("ApplyToAll, ReturnCode", 
		ApplyToAll, DialogReturnCode.No);
	Close(ReturnStructure);
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
