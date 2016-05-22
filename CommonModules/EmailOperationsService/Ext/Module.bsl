////////////////////////////////////////////////////////////////////////////////
// Subsystem "Work with emails".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"EmailOperationsService");
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillingKindsOfRestrictionsRightsOfMetadataObjects"].Add(
			"EmailOperationsService");
	
		ServerHandlers["StandardSubsystems.AccessManagement\OnFillAccessKinds"].Add(
			"EmailOperationsService");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromSubordinate"].Add(
		"EmailOperationsService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromMaster"].Add(
		"EmailOperationsService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenFillingOutPermitsForAccessToExternalResources"].Add(
		"EmailOperationsService");
	
EndProcedure

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.EmailAccounts.FullName(), "EditedAttributesInGroupDataProcessing");
EndProcedure

// Fills out a list of queries for external permissions that must be provided when creating an infobase or updating a application.
//
// Parameters:
//  PermissionsQueries - Array - list of values returned by the function.
//                      WorkInSafeMode.QueryOnExternalResourcesUse().
//
Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export

	If CommonUseReUse.DataSeparationEnabled() AND Not CommonUse.UseSessionSeparator() Then
		Return;
	EndIf;
	
	UserAccountsPermissions = Catalogs.EmailAccounts.UserAccountsPermissions();
	For Each PermissionsDescription IN UserAccountsPermissions Do
		PermissionsQueries.Add(
			WorkInSafeMode.QueryOnExternalResourcesUse(PermissionsDescription.Value, PermissionsDescription.Key));
	EndDo;

EndProcedure

// Converts internal formats of the attachments into binary data.
//
Function ConvertAttachmentForEmailing(Attachment) Export
	If TypeOf(Attachment) = Type("String") AND IsTempStorageURL(Attachment) Then
		Attachment = GetFromTempStorage(Attachment);
		ConvertAttachmentForEmailing(Attachment);
		Return True;
	ElsIf TypeOf(Attachment) = Type("Picture") Then
		Attachment = Attachment.GetBinaryData();
		Return True;
	ElsIf TypeOf(Attachment) = Type("File") AND Attachment.Exist() AND Attachment.IsFile() Then
		Attachment = New BinaryData(Attachment.DescriptionFull);
		Return True;
	EndIf;
	Return False;
EndFunction

// Verifies that a predefined system email
// account is available for use.
//
Function CheckSystemAccountAvailable() Export
	
	If Not AccessRight("Read", Metadata.Catalogs.EmailAccounts) Then
		Return False;
	EndIf;
	
	QueryText =
		"SELECT ALLOWED
		|	EmailAccounts.Ref AS Ref
		|FROM
		|	Catalog.EmailAccounts AS EmailAccounts
		|WHERE
		|	EmailAccounts.Ref = &Ref";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.Parameters.Insert("Ref", EmailOperations.SystemAccount());
	If Query.Execute().IsEmpty() Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Sending function - direct implementation
// of mechanics of emails sending.
//
// The function that executes the mechanics of sending emails.
//
// Parameters:
// UserAccount - CatalogRef.EmailAccounts - link
//                 to email account.
// EmailParameters - structure - contains all the necessary information about the letter:
//                   contains the following keys:
//    To*      - Array of structures, string - Internet address of recipient.
//                 Address         - String - mail address.
//                 Presentation - String - name of addressee.
//    Cc      - Array of structures, string - Internet addresses
//                 of letter recipients are used when the
//                 letter is formed for cc field in case of the array of structures, each structure format:
//                 Address         - String - email address (must be filled).
//                 Presentation - String - name of addressee.
//    Bcc - Array of structures, string - Internet addresses
//                 of letter recipients are used when the letter
//                 is formed for hidden copies field in case of the array of structures, each structure format:
//                 Address         - String - email address (must be filled).
//                 Presentation - String - name of addressee.
//
//    Subject      - String - email subject.
//    Body      - body of mail message (plain text in win-1251 encoding).
//    Importance   - InternetMailImportance
//    Attachments   - Correspondance
//                 key     - AttachmentDescription - String - Attachments
//                 name value - BinaryData,Structure - either binary data of the
//                            attachment or a structure containing the following properties:
//                            "BinaryData" - BinaryData - binary data
//                            of the attachment "Identifier" - String - identifier of the attachment
//                                                       used for storage of images displayed in the message body.
//
// Additional structure keys that can be used:
//    ReplyTo - Map - see such fields as same and to whom.
//    Password      - String - password for access to user account.
//    BasisIDs - String - identifiers of the email basis.
//    ProcessTexts  - Boolean - need to process email text when sending.
//    RequestDeliveryReceipt  - Boolean - necessity of delivery notification request.
//    RequestReadReceipt - Boolean - need to request the read notification.
//    TextType   - String / Enumeration.EmailTextTypes/MailMessageTextType specifies
//                  the type of the sent test acceptable values:
//                  HTML/EmailTextsTypes.HTML - text of email in HTML format.
//                  PlainText/EmailTextsTypes.PlainText - simple text of email.
//                                                                          Displayed "as
//                                                                          is" (value by default).
//                  TaggedText/EmailTextsTypes.TaggedText - text of mail message
//                                                                                  in Rich Text format.
//
//    Note: parameters of the letter marked with
//           '*' are mandatory, i.e. it is considered that they are already filled by the time of function activation.
// Join - InternetMail - existing connection with mail server is installed in
//                              the body of the function, unless stated otherwise.
//
// Returns:
// String - identifier of sent email at the smtp server.
//
// Note: the function can throw an exception which is required to handle.
//
Function SendMessage(Val UserAccount,
	                       Val EmailParameters,
	                       Join = Undefined) Export
	
	// Declaration of variables before the
	// first use as method parameter Structure property EmailParameters.
	// Variables contain the values of the parameters sent to the function.
	Var Whom, Subject, Body, Attachments, ReplyTo, TextType, Cc, Bcc, Password;
	
	If Not EmailParameters.Property("Subject", Subject) Then
		Subject = "";
	EndIf;
	
	If Not EmailParameters.Property("Body", Body) Then
		Body = "";
	EndIf;
	
	Whom = EmailParameters.Whom;
	
	If TypeOf(Whom) = Type("String") Then
		Whom = CommonUseClientServer.ParseStringWithPostalAddresses(Whom);
	EndIf;
	
	EmailParameters.Property("Attachments", Attachments);
	
	CurEmail = New InternetMailMessage;
	CurEmail.Subject = Subject;
	
	// Form the address of recipient.
	For Each RecipientEmailAddress IN Whom Do
		Recipient = CurEmail.To.Add(RecipientEmailAddress.Address);
		Recipient.DisplayName = RecipientEmailAddress.Presentation;
	EndDo;
	
	If EmailParameters.Property("Cc", Cc) Then
		// Form address of recipient in Cc field.
		For Each CcRecipientEmailAddress IN Cc Do
			Recipient = CurEmail.Cc.Add(CcRecipientEmailAddress.Address);
			Recipient.DisplayName = CcRecipientEmailAddress.Presentation;
		EndDo;
	EndIf;
	
	If EmailParameters.Property("Bcc", Bcc) Then
		// Form address of recipient in Cc field.
		For Each BccRecipientEmailAddress IN Bcc Do
			Recipient = CurEmail.Bcc.Add(BccRecipientEmailAddress.Address);
			Recipient.DisplayName = BccRecipientEmailAddress.Presentation;
		EndDo;
	EndIf;
	
	// Form address for response if required.
	If EmailParameters.Property("ReplyTo", ReplyTo) Then
		For Each ReplyToEmailAddress IN ReplyTo Do
			ReplyToEmail = CurEmail.ReplyTo.Add(ReplyToEmailAddress.Address);
			ReplyToEmail.DisplayName = ReplyToEmailAddress.Presentation;
		EndDo;
	EndIf;
	
	// Get details on the sender.
	SenderAttributes = CommonUse.ObjectAttributesValues(UserAccount, "UserName,EmailAddress");
	
	// Add sender name to email.
	CurEmail.SenderName              = SenderAttributes.UserName;
	CurEmail.From.DisplayName = SenderAttributes.UserName;
	CurEmail.From.Address           = SenderAttributes.EmailAddress;
	
	// Add attachments to the letter.
	If Attachments <> Undefined Then
		For Each Attachment IN Attachments Do
			If TypeOf(Attachment) = Type("Structure") Then
				NewAttachment = CurEmail.Attachments.Add(GetFromTempStorage(Attachment.AddressInTemporaryStorage), Attachment.Presentation);
				If Not IsBlankString(Attachment.Encoding) Then
					NewAttachment.Encoding = Attachment.Encoding;
				EndIf;
			Else // Backward compatibility support with 2.2.1.
				If TypeOf(Attachment.Value) = Type("Structure") Then
					NewAttachment = CurEmail.Attachments.Add(Attachment.Value.BinaryData, Attachment.Key);
					NewAttachment.CID = Attachment.Value.ID;
					If Attachment.Value.Property("Encoding") Then
						NewAttachment.Encoding = Attachment.Value.Encoding;
					EndIf;
				Else
					CurEmail.Attachments.Add(Attachment.Value, Attachment.Key);
				EndIf;
			EndIf;
		EndDo;
	EndIf;

	// Set the row with grounds identifiers.
	If EmailParameters.Property("BasisIDs") Then
		CurEmail.SetField("References", EmailParameters.BasisIDs);
	EndIf;
	
	// add text
	Text = CurEmail.Texts.Add(Body);
	If EmailParameters.Property("TextType", TextType) Then
		If TypeOf(TextType) = Type("String") Then
			If      TextType = "HTML" Then
				Text.TextType = InternetMailTextType.HTML;
			ElsIf TextType = "RichText" Then
				Text.TextType = InternetMailTextType.RichText;
			Else
				Text.TextType = InternetMailTextType.PlainText;
			EndIf;
		ElsIf TypeOf(TextType) = Type("EnumRef.EmailTextsTypes") Then
			If      TextType = Enums.EmailTextsTypes.HTML
				  OR TextType = Enums.EmailTextsTypes.HTMLWithPictures Then
				Text.TextType = InternetMailTextType.HTML;
			ElsIf TextType = Enums.EmailTextsTypes.RichText Then
				Text.TextType = InternetMailTextType.RichText;
			Else
				Text.TextType = InternetMailTextType.PlainText;
			EndIf;
		Else
			Text.TextType = TextType;
		EndIf;
	Else
		Text.TextType = InternetMailTextType.PlainText;
	EndIf;

	// Set importance
	Importance = Undefined;
	If EmailParameters.Property("Importance", Importance) Then
		CurEmail.Importance = Importance;
	EndIf;
	
	// Set encoding
	Encoding = Undefined;
	If EmailParameters.Property("Encoding", Encoding) Then
		CurEmail.Encoding = Encoding;
	EndIf;

	If EmailParameters.Property("ProcessTexts") AND Not EmailParameters.ProcessTexts Then
		ProcessMessageText =  InternetMailTextProcessing.DontProcess;
	Else
		ProcessMessageText =  InternetMailTextProcessing.Process;
	EndIf;
	
	If EmailParameters.Property("RequestDeliveryReceipt") Then
		CurEmail.RequestDeliveryReceipt = EmailParameters.RequestDeliveryReceipt;
		CurEmail.DeliveryReceiptAddresses.Add(SenderAttributes.EmailAddress);
	EndIf;
	
	If EmailParameters.Property("RequestReadReceipt") Then
		CurEmail.RequestReadReceipt = EmailParameters.RequestReadReceipt;
		CurEmail.ReadReceiptAddresses.Add(SenderAttributes.EmailAddress);
	EndIf;
	
	If TypeOf(Join) <> Type("InternetMail") Then
		EmailParameters.Property("Password", Password);
		Profile = InternetMailProfile(UserAccount);
		Join = New InternetMail;
		Join.Logon(Profile);
	EndIf;

	Join.Send(CurEmail, ProcessMessageText);
	
	Return CurEmail.MessageID;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Function of mail viewing - direct implementation
// of mechanics of emails sending.
//
// The function that implements the mechanics of messages
// import from the mail server for the specified email account.
//
// Parameters:
// UserAccount - CatalogRef.EmailAccounts - link
//                 to email account.
//
// ExportParameters - structure
// key "Column" - array - array of column
//                  name rows column headers should correspond to the object fields.
//                  InternetMailMessage 
// key "TestingMode" - Boolean - If True then the call was made
//                            in the account test mode - IN such case emails
//                            are selected but they are not reflected in the
//                            return value; the
// test mode is disabled by default key "HeaderReceiving" - Boolean - If True then the returned set
//                                       has only email headers.
// HeadersIDs - array - headers or message
//                                    identifiers, full messages by which it is required to get.
// CastMessagesToType - Boolean - returns the set
//                                    of received mail messages in the form
//                                    of values table with simple types by default True.
//
// Key "Password" - String - password for POP3 access of.
//
// Returns:
// MessagesSet*- a values table, contains an adapted list of messages on the server.
//                 Columns of values table (by default):
//                 Importance, Attachments**, DateSent, DateReceived,
//                 Title, SenderName, ID, Copies, Return address, Sender, Recipients,
//                 Size, Texts, Encoding,
//                 ASCIISymbolsEncodingMethod, Partial is filled if the status is True.
//
// Note * - it is not involved in the creation of the return value in the test mode.
// Note ** - if other emails are attached, they are not returned, only the attachments are returned - binary
//            data and its texts in the form of binary data, recursively.
//
Function ImportMessages(Val UserAccount,
                           Val ExportParameters = Undefined) Export
	
	// Used to check the possibility to login to mailbox.
	Var TestMode;
	
	// Receive only the headers of emails.
	Var GetHeaders;
	
	// Bring mail messages to a simple type;
	Var CastMessagesToType;
	
	// Headers or identifiers of letters by which full messages are required to receive.
	Var HeadersIDs;
	
	If ExportParameters.Property("TestMode") Then
		TestMode = ExportParameters.TestMode;
	Else
		TestMode = False;
	EndIf;
	
	If ExportParameters.Property("GetHeaders") Then
		GetHeaders = ExportParameters.GetHeaders;
	Else
		GetHeaders = False;
	EndIf;
	
	Profile = InternetMailProfile(UserAccount, True);
	
	If ExportParameters.Property("HeadersIDs") Then
		HeadersIDs = ExportParameters.HeadersIDs;
	Else
		HeadersIDs = New Array;
	EndIf;
	
	MessageSetToDelete = New Array;
	
	Join = New InternetMail;
	
	Protocol = InternetMailProtocol.POP3;
	If CommonUse.ObjectAttributeValue(UserAccount, "IncomingMailProtocol") = "IMAP" Then
		Protocol = InternetMailProtocol.IMAP;
	EndIf;
	
	Join.Logon(Profile, Protocol);
	
	If TestMode OR GetHeaders Then
		
		MessageSet = Join.GetHeaders();
		
	Else
		TransportSettings = CommonUse.ObjectAttributesValues(UserAccount, "IncomingMailProtocol,LeaveMessageCopiesOnServer,ServerEmailStoragePeriod");
		If TransportSettings.IncomingMailProtocol = "IMAP" Then
			TransportSettings.LeaveMessageCopiesOnServer = True;
			TransportSettings.ServerEmailStoragePeriod = 0;
		EndIf;
		
		If TransportSettings.LeaveMessageCopiesOnServer Then
			If HeadersIDs.Count() = 0 AND TransportSettings.ServerEmailStoragePeriod > 0 Then
				Headers = Join.GetHeaders();
				MessageSetToDelete = New Array;
				For Each ItemHeader IN Headers Do
					CurrentDate = CurrentSessionDate();
					DATEDIFFerence = (CurrentDate - ItemHeader.PostDating) / (3600*24);
					If DATEDIFFerence >= TransportSettings.ServerEmailStoragePeriod Then
						MessageSetToDelete.Add(ItemHeader);
					EndIf;
				EndDo;
			EndIf;
			AutomaticallyDeleteMessagesOnChoiceFromServer = False;
		Else
			AutomaticallyDeleteMessagesOnChoiceFromServer = True;
		EndIf;
		
		MessageSet = Join.Get(AutomaticallyDeleteMessagesOnChoiceFromServer, HeadersIDs);
		
		If MessageSetToDelete.Count() > 0 Then
			Join.DeleteMessages(MessageSetToDelete);
		EndIf;
		
	EndIf;
	
	Join.Logoff();
	
	If TestMode Then
		Return True;
	EndIf;
	
	If ExportParameters.Property("CastMessagesToType") Then
		CastMessagesToType = ExportParameters.CastMessagesToType;
	Else
		CastMessagesToType = True;
	EndIf;
	
	If CastMessagesToType Then
		If ExportParameters.Property("Columns") Then
			MessageSet = GetAdaptedMessagesSet(MessageSet, ExportParameters.Columns);
		Else
			MessageSet = GetAdaptedMessagesSet(MessageSet);
		EndIf;
	EndIf;
	
	Return MessageSet;
	
EndFunction

// Sets connection with email server.
// Parameters:
// Profile       - InternetMailProfile - Profile of the email account through which it is required to connect.
//
// Returns:
// Connection (InternetMail type)
//
Function SetConnectionWithMailServer(Profile) Export
	
	Join = New InternetMail;
	Join.Logon(Profile);
	
	Return Join;
	
EndFunction

// Creates the profile of transferred account for connection to the mail server.
//
// Parameters:
//  UserAccount - CatalogRef.EmailAccounts - account.
//
// Returns:
//  InternetMailProfile - Account profile;
//  Undefined - failed to get an account through the link.
//
Function InternetMailProfile(UserAccount, ForReceiving = False) Export
	
	QueryText =
	"SELECT ALLOWED
	|	EmailAccounts.IncomingMailServer AS IMAPServerAddress,
	|	EmailAccounts.IncomingMailServerPort AS IMAPPort,
	|	EmailAccounts.UseSecureConnectionForIncomingMail AS IMAPUseSSL,
	|	EmailAccounts.User AS IMAPUser,
	|	EmailAccounts.Password AS IMAPPassword,
	|	EmailAccounts.UseSecureLogonToIncomingMailServer AS IMAPSecureAuthenticationOnly,
	|	EmailAccounts.IncomingMailServer AS POP3ServerAddress,
	|	EmailAccounts.IncomingMailServerPort AS POP3Port,
	|	EmailAccounts.UseSecureConnectionForIncomingMail AS POP3UseSSL,
	|	EmailAccounts.User AS User,
	|	EmailAccounts.Password AS Password,
	|	EmailAccounts.UseSecureLogonToIncomingMailServer AS POP3SecureAuthenticationOnly,
	|	EmailAccounts.OutgoingMailServer AS SMTPServerAddress,
	|	EmailAccounts.OutgoingMailServerPort AS SMTPPort,
	|	EmailAccounts.UseSecureConnectionForOutgoingMail AS SMTPUseSSL,
	|	EmailAccounts.RequiredServerLogonBeforeSending AS POP3BeforeSMTP,
	|	EmailAccounts.SMTPUser AS SMTPUser,
	|	EmailAccounts.SMTPPassword AS SMTPPassword,
	|	EmailAccounts.UseSecureLogonToOutgoingMailServer AS SMTPSecureAuthenticationOnly,
	|	EmailAccounts.Timeout AS Timeout,
	|	EmailAccounts.IncomingMailProtocol AS Protocol
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.Ref = &Ref";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", UserAccount);
	Selection = Query.Execute().Select();
	
	Result = Undefined;
	If Selection.Next() Then
		PropertiesListIMAP = "IMAPServerAddress,IMAPPort,IMAPUseSSL,IMAPUser,IMAPPassword,IMAPSecureAuthenticationOnly";
		PropertiesListPOP3 = "POP3ServerAddress,POP3Port,POP3UseSSL,User,Password,POP3SecureAuthenticationOnly";
		PropertiesListSMTP = "SMTPServerAddress,SMTPPort,SMTPUseSSL,SMTPUser,SMTPPassword,SMTPSecureAuthenticationOnly";
		
		RequiredProperties = Undefined;
		ExcludedProperties = Undefined;
		
		If ForReceiving Then
			If Selection.Protocol = "IMAP" Then
				RequiredProperties = PropertiesListIMAP;
			Else
				RequiredProperties = PropertiesListPOP3;
			EndIf;
		Else
			RequiredProperties = PropertiesListSMTP;
			If Selection.Protocol <> "IMAP" AND Selection.POP3BeforeSMTP Then
				RequiredProperties = RequiredProperties + ",POP3BeforeSMTP," + PropertiesListPOP3;
			EndIf;
		EndIf;
		RequiredProperties = RequiredProperties + ",Timeout";
		
		Result = New InternetMailProfile;
		FillPropertyValues(Result, Selection, RequiredProperties);
	EndIf;
	
	Return Result;
	
EndFunction

// The function writes an adapted set of emails by transferred columns.
// Types of column values not supported for operation on
// the client are converted to string display.
//
Function GetAdaptedMessagesSet(Val MessageSet, Val Columns = Undefined)
	
	Result = CreateAdaptedMessageDescription(Columns);
	
	For Each Email IN MessageSet Do
		NewRow = Result.Add();
		For Each ColumnDescription IN Columns Do
			LetterField = Email[ColumnDescription];
			
			If TypeOf(LetterField) = Type("String") Then
				LetterField = CommonUseClientServer.DeleteInadmissibleCharsXML(LetterField);
			ElsIf TypeOf(LetterField) = Type("InternetMailAddresses") Then
				LetterField = AddressesPresentation(LetterField);
			ElsIf TypeOf(LetterField) = Type("InternetMailAddress") Then
				LetterField = AddressPresentation(LetterField);
			ElsIf TypeOf(LetterField) = Type("InternetMailAttachments") Then
				Attachments = New Map;
				For Each Attachment IN LetterField Do
					AttachmentName = Attachment.Name;
					If TypeOf(Attachment.Data) = Type("BinaryData") Then
						Attachments.Insert(AttachmentName, Attachment.Data);
					Else
						FillAttachedAttachments(Attachments, AttachmentName, Attachment.Data);
					EndIf;
				EndDo;
				LetterField = Attachments;
			ElsIf TypeOf(LetterField) = Type("InternetMailTexts") Then
				Texts = New Array;
				For Each NextText IN LetterField Do
					TextDescription = New Map;
					TextDescription.Insert("Data", NextText.Data);
					TextDescription.Insert("Encoding", NextText.Encoding);
					TextDescription.Insert("Text", CommonUseClientServer.DeleteInadmissibleCharsXML(NextText.Text));
					TextDescription.Insert("TextType", String(NextText.TextType));
					Texts.Add(TextDescription);
				EndDo;
				LetterField = Texts;
			ElsIf TypeOf(LetterField) = Type("InternetMailMessageImportance")
				Or TypeOf(LetterField) = Type("InternetMailMessageNonASCIISymbolsEncodingMode") Then
				LetterField = String(LetterField);
			EndIf;
			
			NewRow[ColumnDescription] = LetterField;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

Function AddressPresentation(InternetMailAddress)
	Result = InternetMailAddress.Address;
	If Not IsBlankString(InternetMailAddress.DisplayName) Then
		Result = InternetMailAddress.DisplayName + " <" + Result + ">";
	EndIf;
	Return Result;
EndFunction

Function AddressesPresentation(InternetMailAddresses)
	Result = "";
	For Each InternetMailAddress IN InternetMailAddresses Do
		Result = ?(IsBlankString(Result), "", Result + "; ") + AddressPresentation(InternetMailAddress);
	EndDo;
	Return Result;
EndFunction

Procedure FillAttachedAttachments(Attachments, AttachmentName, InternetMailMessage)
	
	For Each InternetMailAttachment IN InternetMailMessage.Attachments Do
		AttachmentName = InternetMailAttachment.Name;
		If TypeOf(InternetMailAttachment.Data) = Type("BinaryData") Then
			Attachments.Insert(AttachmentName, InternetMailAttachment.Data);
		Else
			FillAttachedAttachments(Attachments, AttachmentName, InternetMailAttachment.Data);
		EndIf;
	EndDo;
	
	IndexOf = 0;
	
	For Each InternetMailTexts IN InternetMailMessage.Texts Do
		
		If      InternetMailTexts.TextType = InternetMailTextType.HTML Then
			Extension = "html";
		ElsIf InternetMailTexts.TextType = InternetMailTextType.PlainText Then
			Extension = "txt";
		Else
			Extension = "rtf";
		EndIf;
		AttachmentsTextName = "";
		While AttachmentsTextName = "" Or Attachments.Get(AttachmentsTextName) <> Undefined Do
			IndexOf = IndexOf + 1;
			AttachmentsTextName = StringFunctionsClientServer.PlaceParametersIntoString("%1 - (%2).%3", AttachmentName, IndexOf, Extension);
		EndDo;
		Attachments.Insert(AttachmentsTextName, InternetMailTexts.Data);
	EndDo;
	
EndProcedure

// The function prepares the table which
// will subsequently store the messages from the mail server.
// 
// Parameters:
// Columns - String - list of email fields separated by
//                    commas that should be recorded in the table. The parameter changes type to array.
// Return value ValuesTable - empty table of values with columns.
//
Function CreateAdaptedMessageDescription(Columns = Undefined)
	
	If Columns <> Undefined
	   AND TypeOf(Columns) = Type("String") Then
		Columns = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Columns, ",");
		For IndexOf = 0 To Columns.Count()-1 Do
			Columns[IndexOf] = TrimAll(Columns[IndexOf]);
		EndDo;
	EndIf;
	
	DefaultColumnArray = New Array;
	DefaultColumnArray.Add("Importance");
	DefaultColumnArray.Add("Attachments");
	DefaultColumnArray.Add("PostDating");
	DefaultColumnArray.Add("DateReceived");
	DefaultColumnArray.Add("Title");
	DefaultColumnArray.Add("SenderName");
	DefaultColumnArray.Add("ID");
	DefaultColumnArray.Add("Cc");
	DefaultColumnArray.Add("ReplyTo");
	DefaultColumnArray.Add("Sender");
	DefaultColumnArray.Add("Recipients");
	DefaultColumnArray.Add("Size");
	DefaultColumnArray.Add("Subject");
	DefaultColumnArray.Add("Texts");
	DefaultColumnArray.Add("Encoding");
	DefaultColumnArray.Add("NonASCIISymbolsEncodingMode");
	DefaultColumnArray.Add("Partial");
	
	If Columns = Undefined Then
		Columns = DefaultColumnArray;
	EndIf;
	
	Result = New ValueTable;
	
	For Each ColumnDescription IN Columns Do
		Result.Columns.Add(ColumnDescription);
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Initial filling and update of IB.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "EmailOperationsService.FillSystemAccount";
	Handler.Version = "1.0.0.1";
	
	Handler = Handlers.Add();
	Handler.Procedure = "EmailOperationsService.FillAccountNewAttributes";
	Handler.Version = "2.2.2.5";
	
EndProcedure

// Fills system account with default values.
//
Procedure FillSystemAccount() Export
	
	UserAccount = EmailOperations.SystemAccount().GetObject();
	UserAccount.FillObjectByDefaultValues();
	InfobaseUpdate.WriteData(UserAccount);
	
EndProcedure

// Fills new attributes of the catalog EmailAccounts.
Procedure FillNewAccountAttributes() Export
	
	QueryText = 
	"SELECT
	|	""POP"" AS IncomingMailProtocol,
	|	CASE
	|		WHEN EmailAccounts.SMTPAuthentication = VALUE(Enum.SMTPAuthenticationOptions.POP3BeforeSMTP)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RequiredServerLogonBeforeSending,
	|	CASE
	|		WHEN EmailAccounts.POP3AuthenticationMode <> VALUE(Enum.POP3AuthenticationMethods.Ordinary)
	|				AND EmailAccounts.POP3AuthenticationMode <> VALUE(Enum.POP3AuthenticationMethods.EmptyRef)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS UseSecureLogonToIncomingMailServer,
	|	CASE
	|		WHEN EmailAccounts.SMTPAuthenticationMode = VALUE(Enum.SMTPAuthenticationMethods.CramMD5)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS UseSecureLogonToOutgoingMailServer,
	|	EmailAccounts.Ref AS Ref
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.DeletionMark = FALSE";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		UserAccount = Selection.Ref.GetObject();
		FillPropertyValues(UserAccount, Selection, , "Ref");
		InfobaseUpdate.WriteData(UserAccount);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
//
// Check email account
//

// Returns whether the password is specified in the user account or not.
//
Function PasswordIsAssigned(UserAccount) Export
	
	Return ValueIsFilled(CommonUse.ObjectAttributeValue(UserAccount, "Password"));
	
EndFunction

// Service function is used to check email account.
//
Procedure CheckPossibilityOfSendingAndReceivingOfEmails(UserAccount, PasswordParameter, ErrorInfo, AdditionalMessage) Export
	
	AccountSettings = CommonUse.ObjectAttributesValues(UserAccount, "UseForSending,UseForReceiving");
	
	ErrorInfo = "";
	AdditionalMessage = "";
	
	If AccountSettings.UseForSending Then
		Try
			CheckPossibilityOfSendingTestMessages(UserAccount, PasswordParameter);
		Except
			ErrorInfo = StringFunctionsClientServer.PlaceParametersIntoString(
									NStr("en = 'Error when sending a message: %1'"),
									BriefErrorDescription(ErrorInfo()) );
		EndTry;
		If Not AccountSettings.UseForReceiving Then
			AdditionalMessage = Chars.LF + NStr("en = '(Verification of the email sending is completed.)'");
		EndIf;
	EndIf;
	
	If AccountSettings.UseForReceiving Then
		Try
			CheckLoginToIncomingMailServer(UserAccount, PasswordParameter);
		Except
			If ValueIsFilled(ErrorInfo) Then
				ErrorInfo = ErrorInfo + Chars.LF;
			EndIf;
			
			ErrorInfo = ErrorInfo
								+ StringFunctionsClientServer.PlaceParametersIntoString(
										NStr("en = 'Access error to the incoming message server: %1'"),
										BriefErrorDescription(ErrorInfo()) );
		EndTry;
		If Not AccountSettings.UseForSending Then
			AdditionalMessage = Chars.LF + NStr("en = '(Verification of the email receiving is completed.)'");
		EndIf;
	EndIf;
	
EndProcedure

// Procedure to check if it is
// possible to send messages through the account.
//
// Parameters:
// UserAccount - CatalogRef.EmailAccounts - account
//                 that shall be checked.
//
// Return value structure key "status" - Boolean if True - successfully logged
//                 in to pop3 server if False - error when you log
// on to pop3 server key "MessageAboutError" - String - if status is False - contains message about an error.
//
Procedure CheckPossibilityOfSendingTestMessages(Val UserAccount, Val Password = Undefined)
	
	EmailParameters = New Structure;
	
	EmailParameters.Insert("Subject", NStr("en = '""1C:Enterprise"" test message'"));
	EmailParameters.Insert("Body", NStr("en = 'The email is sent using ""1C:Enterprise"" service'"));
	EmailParameters.Insert("Whom", CommonUse.ObjectAttributeValue(UserAccount, "EmailAddress"));
	If Password <> Undefined Then
		EmailParameters.Insert("Password", Password);
	EndIf;
	
	EmailOperations.SendE_Mail(UserAccount, EmailParameters);
	
EndProcedure

// The procedure checks if it is
// possible to receive messages through the account.
//
// Parameters:
// UserAccount - CatalogRef.EmailAccounts - account
//                 that shall be checked.
//
// Return value structure key "status" - Boolean if True - successfully logged
//                 in to pop3 server if False - error when you log
// on to pop3 server key "MessageAboutError" - String - if status is False - contains message about an error.
//
Procedure CheckLoginToIncomingMailServer(Val UserAccount, Val Password = Undefined)
	
	ExportParameters = New Structure("TestMode", True);
	
	If Password <> Undefined Then
		ExportParameters.Insert("Password", Password);
	EndIf;
	
	Try
		EmailOperations.ImportEMails(UserAccount, ExportParameters);
	Except
		WriteLogEvent(EventLogMonitorEvent(), EventLogLevel.Error,,
			UserAccount, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Function EventLogMonitorEvent()
	Return NStr("en = 'Email account check'", CommonUseClientServer.MainLanguageCode());
EndFunction

// DIB 

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of the event handler WhenDataIsReceivedFromSecondary() in the syntax helper.
// 
Procedure OnReceiveDataFromSubordinate(DataItem, ItemReceive, SendBack, Sender) Export
	
	OnReceiveData(DataItem, ItemReceive, SendBack, Sender);
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//
// Parameters:
// see Description of event handler WhenDataIsReceivedFromMain() in syntax helper.
// 
Procedure OnReceiveDataFromMaster(DataItem, ItemReceive, SendBack, Sender) Export
	
	OnReceiveData(DataItem, ItemReceive, SendBack, Sender);
	
EndProcedure

// The procedure is a handler of the
// events WhenDataIsReceivedFromMain and WhenDataIsReceivedFromSecondary which occur at data exchange in distributed infobase.
//
// Parameters:
// see Description of the relevant event handlers in syntax helper.
// 
Procedure OnReceiveData(DataItem, ItemReceive, SendBack, Sender)
	
	If TypeOf(DataItem) = Type("CatalogObject.EmailAccounts") Then
		If DataItem.IsNew() Then
			DataItem.UseForReceiving = False;
			DataItem.UseForSending = False;
		Else
			DataItem.UseForReceiving = CommonUse.ObjectAttributeValue(DataItem.Ref, "UseForReceiving");
			DataItem.UseForSending = CommonUse.ObjectAttributeValue(DataItem.Ref, "UseForSending");
		EndIf;
	EndIf;
	
EndProcedure

// Disables all accounts. Used at the initial setup of DIB node.
Procedure DisableAccountsUse() Export
	QueryText =
	"SELECT
	|	EmailAccounts.Ref
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	(EmailAccounts.UseForSending
	|			OR EmailAccounts.UseForReceiving)";
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		UserAccount = Selection.Ref.GetObject();
		UserAccount.UseForSending = False;
		UserAccount.UseForReceiving = False;
		UserAccount.DataExchange.Load = True;
		UserAccount.Write();
	EndDo;
EndProcedure

// Access management

// Fills the content of access kinds used when metadata objects rights are restricted.
// If the content of access kinds is not filled, "Access rights" report will show incorrect information.
//
// Only the access types clearly used
// in access restriction templates must be filled, while
// the access types used in access values sets may be
// received from the current data register AccessValueSets.
//
//  To prepare the procedure content
// automatically, you should use the developer tools for subsystem.
// Access management.
//
// Parameters:
//  Description     - String, multiline string in format <Table>.<Right>.<AccessKind>[.Object table].
//                 For
//                           example,
//                           Document.SupplierInvoice.Read.Companies
//                           Document.SupplierInvoice.Read.Counterparties
//                           Document.SupplierInvoice.Change.Companies
//                           Document.SupplierInvoice.Change.Counterparties
//                           Document.Emails.Read.Object.Document.Emails
//                           Document.Emails.Change.Object.Document.Emails
//                           Document.Files.Read.Object.Catalog.FileFolders
//                           Document.Files.Read.Object.Document.Email
//                 Document.Files.Change.Object.Catalog.FileFolders Document.Files.Change.Object.Document.Email Access type Object is predefined as literal, it is not included into predefined elements.
//                 ChartsOfCharacteristicTypesRef.AccessKinds. This kind of access is used in
//                 the templates of access restrictions, such as "link" to another object by which the table is limited.
//                 When access type "Object" is assigned, you shall also indicate the
//                 types of tables used for this type of access.I.e. you
//                 shall list the types that correspond to the field used in the template of access restriction and paired with access type "Object".
//                 When listing the types by access type "Object", you should list only
//                 those types of flieds that the field InformationRegisters.AccessValueSets.Object has, the rest of types is irrelevant.
// 
Procedure OnFillingKindsOfRestrictionsRightsOfMetadataObjects(Description) Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	ModuleAccessManagementService = CommonUse.CommonModule("AccessManagementService");
	
	If ModuleAccessManagementService.AccessKindExists("EmailAccounts") Then
		
		Description = Description +
		"
		|Catalog.EmailAccounts.Read.EmailAccounts
		|";
		
	EndIf;
	
EndProcedure

// Fills kinds of access used by access rights restriction.
// Access types Users and ExternalUsers are complete.
// They can be deleted if they are not used for access rights restriction.
//
// Parameters:
//  AccessKinds - ValuesTable with fields:
//  - Name                    - String - a name used in
//                             the description of delivered access groups profiles and ODD texts.
//  - Presentation          - String - introduces an access type in profiles and access groups.
//  - ValuesType            - Type - Type of access values reference.       For example, Type("CatalogRef.ProductsAndServices").
//  - ValueGroupType       - Type - Reference type of access values groups. For
//  example, Type("CatalogRef.ProductsAndServicesAccessGroups").
//  - SeveralGroupsOfValues - Boolean - True shows that for access value
//                             (ProductsAndServices) several value groups can be selected (Products and services access group).
//
Procedure OnFillAccessKinds(AccessKinds) Export
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name = "EmailAccounts";
	AccessKind.Presentation = NStr("en = 'Email accounts'");
	AccessKind.ValuesType   = Type("CatalogRef.EmailAccounts");
	
EndProcedure

#EndRegion
