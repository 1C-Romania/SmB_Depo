
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"Catalog.EmailAccounts.ObjectForm",
		New Structure("Key, LockOwner", UserAccount(), True),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function UserAccount()
	
	Return EmailOperations.SystemAccount();
	
EndFunction

#EndRegion
