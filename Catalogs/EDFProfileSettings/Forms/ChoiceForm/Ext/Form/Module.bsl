////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - Form commands actions

&AtClient
Procedure Open1CTaxcomServiceConnectionAssistant(Command)
	
	ElectronicDocumentsClient.ConnectionAssistant1CTaxcomService();
	
EndProcedure

&AtClient
Procedure OpenDirectExchangeConnectionAssistant(Command)
	
	ElectronicDocumentsClient.DirectExchangeConnectionAssistant();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshStateED" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure
