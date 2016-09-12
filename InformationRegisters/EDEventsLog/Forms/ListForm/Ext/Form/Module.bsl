
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ElectronicDocumentsOverridable.HasRightToOpenEventLogMonitor() Then
		MessageText = NStr("en='Insufficient rights to view the event log.';ru='Недостаточно прав для просмотра журнала регистрации.'");
		CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
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
