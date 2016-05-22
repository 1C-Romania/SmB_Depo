// ------------------------------------------------------------------------------
// PARAMETER SPECIFICATION PASSED TO FORM
//
// UserAccount  - CatalogRef.EmailAccounts
//
// RETURN VALUE
//
// Undefined - user refused to enter the password.
// Structure  - 
//            key "Status", Boolean - true or false depending on the
//            success of call key "Password", string - in case if the True status
//            contains the password key "ErrorMessage" - in case if the True status
//                                       contains the message text about an error.
//
// ------------------------------------------------------------------------------
// FORM FUNCTIONING SPECIFICATION
//
//   If in the passed accounts list there is more, than
// one record, then the possibility of account selection will
// appear on the form, that will sent an email message.
//
// ------------------------------------------------------------------------------

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("CheckAbilityToSendAndReceive", CheckAbilityToSendAndReceive);
	
	If Parameters.UserAccount.IsEmpty() Then
		Cancel = True;
		Return;
	EndIf;
	
	UserAccount = Parameters.UserAccount;
	Result = ImportPassword();
	
	If ValueIsFilled(Result) Then
		Password = Result;
		PasswordConfirmation = Result;
		StorePassword = True;
	Else
		Password = "";
		PasswordConfirmation = "";
		StorePassword = False;
	EndIf;
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Items.StorePassword.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SavePasswordAndContinueExecute()
	
	If Password <> PasswordConfirmation Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Password and password confirmation are different'"), , "Password");
		Return;
	EndIf;
	
	If StorePassword Then
		SavePassword(Password);
	Else
		SavePassword(Undefined);
	EndIf;
	
	If CheckAbilityToSendAndReceive Then
		NotifyDescription = New NotifyDescription("SavePasswordAndContinueToExecuteEnd", ThisObject, Password);
		EmailOperationsClient.CheckPossibilityOfSendingAndReceivingOfEmails(NOTifyDescription, UserAccount, Password);
		Return;
	EndIf;
	
	SavePasswordAndContinueToExecuteEnd(Password);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SavePassword(Value)
	
	CommonUse.CommonSettingsStorageSave(
		"AccountPasswordConfirmationForm",
		UserAccount,
		Value);
	
EndProcedure

&AtServer
Function ImportPassword()
	
	Return CommonUse.CommonSettingsStorageImport("AccountPasswordConfirmationForm", UserAccount);
	
EndFunction

&AtClient
Procedure SavePasswordAndContinueToExecuteEnd(Password) Export
	
	NotifyChoice(Password);
	
EndProcedure

#EndRegion
