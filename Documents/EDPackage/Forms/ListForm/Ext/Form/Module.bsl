////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS

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
