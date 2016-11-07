////////////////////////////////////////////////////////////////////////////////
// Subsystem "Work with emails".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Opens the form of new email.
//  
// Parameters:
//  SendingParameters - Structure - parameters to be filled in the form of a new email (all optional):
//    * Sender - CatalogRef.EmailAccounts - account which you can use for sending email;
//                  - ValueList - list of accounts available for selection on the form:
//                      ** Presentation - String - account name;
//                      ** Value - CatalogRef.EmailAccounts - account.
//    
//    * Recipient - list of mail addresses.
//        - String - mailing list in format:
//            [RecipientIntroductiom1] <Address1>; [[RecipientIntroduction2] <Address2>;...]
//        - ValueList - Mailing list.
//            ** Presentation - String - recipient introduction,
//            ** Value        - String - mail address.
//    
//    * Subsject - String - email subject.
//    
//    * Text     - String - email body.
//    
//    * Attachments - Array - files that you need to enclose to email (descriptions in the form of structures):
//        ** Structure - attachment description:
//             *** Presentation - String - attachment file name;
//             *** AddressInTemporaryStorage - String - address binary data attachments in temporary storage.
//             *** Encoding - String - attachment encoding (used if it differs from the email encoding).
//    
//    * DeleteFilesAfterSend - Boolean - delete temporary files after sending message.
//  
//  FormClosingAlert - NotifyDescription - procedure to which you need to pass the contol after closing the email sending form.
//                           
//
Procedure CreateNewEmail(SendingParameters = Undefined, FormClosingAlert = Undefined) Export
	
	If SendingParameters = Undefined Then
		SendingParameters = New Structure;
	EndIf;
	SendingParameters.Insert("FormClosingAlert", FormClosingAlert);
	
	NotifyDescription = New NotifyDescription("CreatEmailAccountPerformedVerification", ThisObject, SendingParameters);
	VerifyAccountForEmailSending(NOTifyDescription);
	
EndProcedure

// If user does not have configured account for sending emails  that depending on rights there is setup assistent of account or message about impossibility of sending.
// 
// It is used for the scripts for which it is required to configure an account before requesting the additional parameters of sending.
// 
//
// Parameters:
//  ResultHandler - AlertDescription - procedure to which you need to pass the code execution after the check.
//
Procedure VerifyAccountForEmailSending(ResultHandler) Export
	If EmailOperationsServerCall.IsAvailableAccountsToSend() Then
		ExecuteNotifyProcessing(ResultHandler, True);
	Else
		If EmailOperationsServerCall.AvailableRightToAddUserAccounts() Then
			OpenForm("Catalog.EmailAccounts.Form.AccountSetupAssistant", 
				New Structure("ContextMode", True), , , , , ResultHandler);
		Else	
			MessageText = NStr("en='To send an email, you need to configure the email account.
		|Contact your administrator.';ru='Для отправки письма требуется настройка учетной записи электронной почты.
		|Обратитесь к администратору.'");
			NotifyDescription = New NotifyDescription("VerifyAccountForEmailSendingEnd", ThisObject, ResultHandler);
			ShowMessageBox(NOTifyDescription, MessageText);
		EndIf;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OUTDATED PROCEDURES AND FUNCTIONS

// Outdated. You should use CreateNewEmail.
//
// Interface client function which supports simple call of the form for editing new email.
// 
// Parameters:
// Sender*  - ValueList, CatalogRef.EmailAccounts - account which you can use for sending an email. 
//             If the type is values list, then presentation - account name, value - ref to account.
//                           
// Recipient      - ValueList, String:
//                   if value list, then notation - recipient name value  
//                                                - mail address
//                   if row then list of email addresses, 
//                   in format of correct email address*
//
// Subject        - String - email subject.
// Text           - String - email body.
//
// Attachments        - ValuesList, where
//                   presentation  - String - Attachments name 
//                   value         - BinaryData - attachment binary data.
//                                 - String - file address in temporary storage.
//                                 - String - file path on client
//
// DeleteFilesAfterSend - Boolean - delete temporary files after sending message.
// SaveEmailMessage     - Boolean - whether an email should be saved (used only if the Interactions subsystem is embedded).
//                                      
//
Procedure OpenEmailMessageSendForm(Val Sender = Undefined, Val Recipient = Undefined, Val Subject = "",
	Val Text = "", Val Attachments = Undefined, Val DeleteFilesAfterSend = False, Val SaveEmailMessage = True) Export
	
	SendingParameters = New Structure;
	SendingParameters.Insert("Sender", Sender);
	SendingParameters.Insert("Recipient", Recipient);
	SendingParameters.Insert("Subject", Subject);
	SendingParameters.Insert("Text", Text);
	SendingParameters.Insert("Attachments", Attachments);
	SendingParameters.Insert("DeleteFilesAfterSend", DeleteFilesAfterSend);
	SendingParameters.Insert("SaveEmailMessage", SaveEmailMessage);
	
	CreateNewEmail(SendingParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Continuation of procedure CreateEmail.
Procedure CreatEmailAccountPerformedVerification(UserAccountIsConfigured, SendingParameters) Export
	Var Sender, Recipient, Attachments, Subject, Text, DeleteFilesAfterSend;
	
	If UserAccountIsConfigured <> True Then
		Return;
	EndIf;
	
	SendingParameters.Property("Sender", Sender);
	SendingParameters.Property("Recipient", Recipient);
	SendingParameters.Property("Subject", Subject);
	SendingParameters.Property("Text", Text);
	SendingParameters.Property("Attachments", Attachments);
	SendingParameters.Property("DeleteFilesAfterSend", DeleteFilesAfterSend);
	
	FormClosingAlert = SendingParameters.FormClosingAlert;
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.Interactions") 
		AND StandardSubsystemsClientReUse.ClientWorkParameters().UseEmailClient Then
			ModuleInteractionsClient = CommonUseClient.CommonModule("InteractionsClient");
			ModuleInteractionsClient.OpenEmailMessageSendForm(Sender,
				Recipient, Subject, Text, Attachments, FormClosingAlert);
	// SB. Begin
	ElsIf True Then
		BasisDocuments = Undefined;
		SendingParameters.Property("BasisDocuments", BasisDocuments);
		SmallBusinessClient.OpenEmailMessageSendForm(Sender, Recipient,
			Subject, Text, Attachments, BasisDocuments, DeleteFilesAfterSend, FormClosingAlert);
	// SB. End
	Else
		OpenSimpleFormOfEmailSending(Sender, Recipient,
			Subject,Text, Attachments, DeleteFilesAfterSend, FormClosingAlert);
	EndIf;
	
EndProcedure

// Interface client function which supports simple call of the form for editing new email.
// When you send an email using simple form, the messages are not saved in the infobase.
//
// See the parameters description to the CreateNewEmail function.
//
Procedure OpenSimpleFormOfEmailSending(Sender,
			Recipient, Subject,Text, FileList, DeleteFilesAfterSend, OnCloseNotifyDescription)
	
	EmailParameters = New Structure;
	
	EmailParameters.Insert("UserAccount", Sender);
	EmailParameters.Insert("Whom", Recipient);
	EmailParameters.Insert("Subject", Subject);
	EmailParameters.Insert("Body", Text);
	EmailParameters.Insert("Attachments", FileList);
	EmailParameters.Insert("DeleteFilesAfterSend", DeleteFilesAfterSend);
	
	OpenForm("CommonForm.MessageSending", EmailParameters, , , , , OnCloseNotifyDescription);
EndProcedure

// It checks the account.
//
// Parameters:
// UserAccount - CatalogRef.EmailAccounts - account you need to check.
// 				
//
Procedure CheckAccount(Val UserAccount) Export
	
	ClearMessages();
	
	Status(NStr("en='Check email account';ru='Проверка учетной записи'"),,NStr("en='Account is being checked. Please wait...';ru='Выполняется проверка учетной записи. Пожалуйста, подождите..'"));
	
	If EmailOperationsServerCall.PasswordIsAssigned(UserAccount) Then
		CheckPossibilityOfSendingAndReceivingOfEmails(Undefined, UserAccount, Undefined);
	Else
		FormParameters = New Structure;
		FormParameters.Insert("UserAccount", UserAccount);
		FormParameters.Insert("CheckAbilityToSendAndReceive", True);
		OpenForm("CommonForm.AccountPasswordConfirmation", FormParameters);
	EndIf;
	
EndProcedure

// Check of email account.
//
// See Description of the procedure EmailOperationsService.CheckPossibilityOfEmailsSendingAndReceiving.
//
Procedure CheckPossibilityOfSendingAndReceivingOfEmails(ResultHandler, UserAccount, PasswordParameter) Export
	
	ErrorInfo = "";
	AdditionalMessage = "";
	EmailOperationsServerCall.CheckPossibilityOfSendingAndReceivingOfEmails(UserAccount, PasswordParameter, ErrorInfo, AdditionalMessage);
	
	If ValueIsFilled(ErrorInfo) Then
		ShowMessageBox(ResultHandler, StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Account parameters have been checked
		|with errors: %1';ru='Проверка параметров учетной
		|записи завершилась с ошибками: %1'"), ErrorInfo ),,
			NStr("en='Check email account';ru='Проверка учетной записи'"));
	Else
		ShowMessageBox(ResultHandler, StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Account parameters have been checked successfully. %1';ru='Проверка параметров учетной записи завершилась успешно. %1'"),
			AdditionalMessage),,
			NStr("en='Check email account';ru='Проверка учетной записи'"));
	EndIf;
	
EndProcedure

Procedure VerifyAccountForEmailSendingEnd(ResultHandler) Export
	ExecuteNotifyProcessing(ResultHandler, False);
EndProcedure

#EndRegion
