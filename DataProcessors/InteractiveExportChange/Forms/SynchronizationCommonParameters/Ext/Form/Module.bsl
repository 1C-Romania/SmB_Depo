
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
