#Region FormEventsHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	If FormOwner = Undefined Then
		WindowOpeningMode = FormWindowOpeningMode.LockWholeInterface;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	NotifyChoice(ServiceUserPassword);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	ServiceUserPassword = Password;
	Close();
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close();
	
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
