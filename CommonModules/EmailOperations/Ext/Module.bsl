////////////////////////////////////////////////////////////////////////////////
// Subsystem "Work with emails".
//
// /////////////////////////////////////////////////////////////////////////////
//

#Region ProgramInterface

// Function for sending messages. It verifies the
// accuracy of account filling and call function implemented sending mechanics.
// 
// See parameters of function SendMessage.
// 
// Note: instead of binary data parameter EmailParameters.Attachments can
//   contain adresses of storing data in temporary storage.
//
Function SendE_Mail(Val UserAccount,
	                               Val EmailParameters,
	                               Val Join = Undefined) Export
	
	If TypeOf(UserAccount) <> Type("CatalogRef.EmailAccounts")
		Or Not ValueIsFilled(UserAccount) Then
		Raise NStr("en = 'Account is unfilled or filled incorrectly.'");
	EndIf;
	
	If EmailParameters = Undefined Then
		Raise NStr("en = 'The sending parameters are not specified.'");
	EndIf;
	
	TypeOfRecipient = ?(EmailParameters.Property("Whom"), TypeOf(EmailParameters.Whom), Undefined);
	TypeOfCc = ?(EmailParameters.Property("Cc"), TypeOf(EmailParameters.Cc), Undefined);
	TypeOfBcc = ?(EmailParameters.Property("Bcc"), TypeOf(EmailParameters.Bcc), Undefined);
	
	If TypeOfRecipient = Undefined AND TypeOfCc = Undefined AND TypeOfBcc = Undefined Then
		Raise NStr("en = 'No recipients have been specified.'");
	EndIf;
	
	If TypeOfRecipient = Type("String") Then
		EmailParameters.Whom = CommonUseClientServer.ParseStringWithPostalAddresses(EmailParameters.Whom);
	ElsIf TypeOfRecipient <> Type("Array") Then
		EmailParameters.Insert("Whom", New Array);
	EndIf;
	
	If TypeOfCc = Type("String") Then
		EmailParameters.Cc = CommonUseClientServer.ParseStringWithPostalAddresses(EmailParameters.Cc);
	ElsIf TypeOfCc <> Type("Array") Then
		EmailParameters.Insert("Cc", New Array);
	EndIf;
	
	If TypeOfBcc = Type("String") Then
		EmailParameters.Bcc = CommonUseClientServer.ParseStringWithPostalAddresses(EmailParameters.Bcc);
	ElsIf TypeOfBcc <> Type("Array") Then
		EmailParameters.Insert("Bcc", New Array);
	EndIf;
	
	If EmailParameters.Property("ReplyTo") AND TypeOf(EmailParameters.ReplyTo) = Type("String") Then
		EmailParameters.ReplyTo = CommonUseClientServer.ParseStringWithPostalAddresses(EmailParameters.ReplyTo);
	EndIf;
	
	If EmailParameters.Property("Attachments") Then
		If TypeOf(EmailParameters.Attachments) = Type("Map") Then
			For Each Attachment IN EmailParameters.Attachments Do
				DataAttachments = Attachment.Value;
				If EmailOperationsService.ConvertAttachmentForEmailing(DataAttachments) Then
					EmailParameters.Attachments.Insert(Attachment.Key, DataAttachments);
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	Return EmailOperationsService.SendMessage(UserAccount, EmailParameters, Join);
	
EndFunction

// Function for import messages. It verifies accuracy
// of account filling and call function implemented mechanics of message import.
// 
// Parameters to a function see in the function ImportMessages.
//
Function ImportEMails(Val UserAccount,
                                   Val ImportParameters = Undefined) Export
	
	UseForReceiving = CommonUse.ObjectAttributeValue(UserAccount, "UseForReceiving");
	If Not UseForReceiving Then
		Raise NStr("en = 'An account is inappropriate for receiving the messages.'");
	EndIf;
	
	If ImportParameters = Undefined Then
		ImportParameters = New Structure;
	EndIf;
	
	Result = EmailOperationsService.ImportMessages(UserAccount, ImportParameters);
	
	Return Result;
	
EndFunction

// Receive available email accounts.
// Parameters:
// ForSending - Boolean - If it is True, choose only accounts which you can use for email sending.
// ForReceiving   - Boolean - If it is True, choose only accounts which you can use for email receiving.
// IncludingSystemEmailAccount - Boolean - start system account if it is available.
//
// Returns:
// AvailableAccounts - ValueTable - With columns:
//    Ref         - CatalogRef.EmailAccounts - Ref to the Name.
//    Description - String - Account.
//    Address     - String - Email address.
//
Function AvailableAccounts(Val ForSending = Undefined,
										Val ForReceiving  = Undefined,
										Val IncludingSystemEmailAccount = True) Export
	
	If Not AccessRight("Read", Metadata.Catalogs.EmailAccounts) Then
		Return New ValueTable;
	EndIf;
	
	QueryText = 
	"SELECT ALLOWED
	|	EmailAccounts.Ref AS Ref,
	|	EmailAccounts.Description AS Description,
	|	EmailAccounts.EmailAddress AS Address
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.DeletionMark = FALSE
	|	AND CASE
	|			WHEN &ForSending = UNDEFINED
	|				THEN TRUE
	|			ELSE EmailAccounts.UseForSending = &ForSending
	|		END
	|	AND CASE
	|			WHEN &ForReceiving = UNDEFINED
	|				THEN TRUE
	|			ELSE EmailAccounts.UseForReceiving = &ForReceiving
	|		END
	|	AND CASE
	|			WHEN &IncludingSystemEmailAccount
	|				THEN TRUE
	|			ELSE EmailAccounts.Ref <> VALUE(Catalog.EmailAccounts.SystemEmailAccount)
	|		END";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.Parameters.Insert("ForSending", ForSending);
	Query.Parameters.Insert("ForReceiving", ForReceiving);
	Query.Parameters.Insert("IncludingSystemEmailAccount", IncludingSystemEmailAccount);
	
	Return Query.Execute().Unload();
	
EndFunction

// It receives a reference to account by type of account function.
//
// Returns:
//  UserAccount - CatalogRef.EmailAccounts - ref
//                  to account description.
//
Function SystemAccount() Export
	
	Return Catalogs.EmailAccounts.SystemEmailAccount;
	
EndFunction

// It verifies that the system account is available (may be used).
//
Function CheckSystemAccountAvailable() Export
	
	Return EmailOperationsService.CheckSystemAccountAvailable();
	
EndFunction

// It returns True if there is at least one account for email sending.
Function AvailableEmailSending() Export
	Return AvailableAccounts(True).Count() > 0 
		Or AccessRight("Update", Metadata.Catalogs.EmailAccounts);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Outdated procedures and functions.

// Outdated. You shall use SendEmail.
//
// It sends emails.
//
// Parameters:
// UserAccount - CatalogRef.EmailAccounts - link
//                 to email account.
// EmailParameters - structure - contains all the necessary information about the letter:
//                   contains the following keys:
//    To*        - Array of structures, string - Internet address of recipient.
//                 Address            - String - mail address.
//                 Presentation       - String - name of addressee.
//
//    Subject     - String - email subject.
//    Body        - body of mail message (plain text in win-1251 encoding).
//    Attachments - map
//                  key   - AttachmentDescription - String - Attachments name
//                  value - BinaryData - DS attachments.
//
// Additional structure keys that can be used:
//    ReplyTo    - Map - see such fields as same and to whom.
//    Password   - String - password for access to user account.
//    TextType   - String / Enumeration. EmailTextTypes identifies
//                 type passed test acceptable values:
//                 HTML/EmailTextsTypes.HTML - text of email in HTML format.
//                 PlainText/EmailTextsTypes.PlainText - simple text of email.
//                                                       Displayed "as is" 
//                                                       (value by default).
//                 TaggedText/EmailTextsTypes.TaggedText - text of mail message
//                                                         in Rich Text format.
//
//    Note: email parameters with '*' are automatic,
//          so it is already filled by start of function work.
//
// Returns:
//  String - identifier of sent email at the smtp server.
//
// Note: the function can throw an exception which is required to handle.
//
Function SendMessage(Val UserAccount, Val EmailParameters) Export
	
	Return SendE_Mail(UserAccount, EmailParameters);
	
EndFunction

// Outdated. You shall use AvailableAccounts.
Function GetAvailableAccountRecords(Val ForSending = Undefined,
										Val ForReceiving  = Undefined,
										Val IncludingSystemEmailAccount = True) Export
	
	Return AvailableAccounts(ForSending, ForReceiving, IncludingSystemEmailAccount);
	
EndFunction

// Outdated. You shall use SystemAccount.
Function GetSystemAccount() Export
	
	Return SystemAccount();
	
EndFunction

#EndRegion
