
#Region FormEventsHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	CloseOnOwnerClose = True;
	
	If ValueIsFilled(Parameters.InfobaseNode) Then
		CommonParametersStringSynchronization = DataExchangeServer.DataSynchronizationRulesDescription(Parameters.InfobaseNode);
		NodeName = String(Parameters.InfobaseNode);
	Else
		NodeName = "";
	EndIf;
	
	Title = StrReplace(Title, "%1", NodeName);
	
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
