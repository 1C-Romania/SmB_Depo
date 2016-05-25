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
