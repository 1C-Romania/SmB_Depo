////////////////////////////////////////////////////////////////////////////////
// Subsystem "Work with emails".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Returns whether the password is specified in the user account or not.
//
// See Description of the function EmailOperationsService.PasswordIsAssigned.
//
Function PasswordIsAssigned(UserAccount) Export
	
	Return EmailOperationsService.PasswordIsAssigned(UserAccount);
	
EndFunction

// Check of email account.
//
// See Description of the procedure EmailOperationsService.CheckPossibilityOfEmailsSendingAndReceiving.
//
Procedure CheckPossibilityOfSendingAndReceivingOfEmails(UserAccount, PasswordParameter, ErrorInfo, AdditionalMessage) Export
	
	EmailOperationsService.CheckPossibilityOfSendingAndReceivingOfEmails(UserAccount, PasswordParameter, ErrorInfo, AdditionalMessage);
	
EndProcedure

// Returns True if the current user has access to at least one account for sending.
Function IsAvailableAccountsToSend() Export
	Return EmailOperations.AvailableAccounts(True).Count() > 0;
EndFunction

// Checks if the user can add new accounts.
Function AvailableRightToAddUserAccounts() Export 
	Return AccessRight("Insert", Metadata.Catalogs.EmailAccounts);
EndFunction

Function UserAccountIsConfigured(UserAccount) Export
	Return Catalogs.EmailAccounts.UserAccountIsConfigured(UserAccount);
EndFunction
	
#EndRegion
