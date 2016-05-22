﻿#Region FormEventsHandlers

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