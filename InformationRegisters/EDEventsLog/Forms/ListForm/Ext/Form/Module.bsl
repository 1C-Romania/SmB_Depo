
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ElectronicDocumentsOverridable.HasRightToOpenEventLogMonitor() Then
		MessageText = NStr("en = 'Insufficient rights to view the event log.'");
		CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
	EndIf;

EndProcedure