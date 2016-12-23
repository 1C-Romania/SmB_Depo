
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	CommonUseClientServer.SetFilterDynamicListItem(List, 
		"Recipient", MessageExchangeInternal.ThisNode() );
EndProcedure

#EndRegion














