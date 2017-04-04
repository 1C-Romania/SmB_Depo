
#Region FormEventHandlers

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "GLAccountsChanged" Then
		Object.GLAccount		= Parameter.GLAccount;
		Object.GLExpenseAccount	= Parameter.GLExpenseAccount;
		Modified	= True;
	EndIf;
	
EndProcedure

#EndRegion

