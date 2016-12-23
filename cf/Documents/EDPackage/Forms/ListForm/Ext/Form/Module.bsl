////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshStateED" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

















