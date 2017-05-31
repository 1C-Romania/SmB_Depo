// Function search data in contact information by e-mail addresses
//
// Parameters
//  ContactInformationPresentationTable - table with source data for contact information search
//  ByObjectName - Boolean, perform searching by name or e-mail
//
// Return value:
//   QueryTable - ValueTable, search result
//
Function SearchInContactInformation(ContactInformationPresentationTable, ByObjectName = False) Export

	Query = New Query;
	
	ConditionString = "";
	ConditionStringWhere = "";
	ConditionIndex = 0;
	For each TableRow In ContactInformationPresentationTable Do
		ConditionStringIndex = StrReplace(String(ConditionIndex), Chars.NBSp, "");
		If NOT ByObjectName Then
			If IsBlankString(TableRow.ObjectPresentation) AND IsBlankString(TableRow.EmailAddress) Then
				Continue;
			EndIf; 
			If NOT IsBlankString(ConditionString) Then
				ConditionString = ConditionString + Chars.LF + " OR " + Chars.LF;
			EndIf;
			If NOT IsBlankString(TableRow.ObjectPresentation) AND NOT IsBlankString(TableRow.EmailAddress) Then
				ConditionString = ConditionString + "(Description LIKE &ContactInformationPresentationAddress" + ConditionStringIndex + 
												" AND Object.Description LIKE &ContactInformationPresentation" + ConditionStringIndex + ")";
				Query.SetParameter(("ContactInformationPresentationAddress" + ConditionStringIndex), (TrimAll(String(TableRow.EmailAddress)) + "%"));
				Query.SetParameter(("ContactInformationPresentation" + ConditionStringIndex), (TrimAll(String(TableRow.ObjectPresentation)) + "%"));
			ElsIf NOT IsBlankString(TableRow.ObjectPresentation) AND IsBlankString(TableRow.EmailAddress) Then
				ConditionString = ConditionString + "(Object.Description LIKE &ContactInformationPresentation" + ConditionStringIndex + ")";
				Query.SetParameter(("ContactInformationPresentation" + ConditionStringIndex), (TrimAll(String(TableRow.ObjectPresentation)) + "%"));
			ElsIf IsBlankString(TableRow.ObjectPresentation) AND NOT IsBlankString(TableRow.EmailAddress) Then
				ConditionString = ConditionString + "Description LIKE &ContactInformationPresentationAddress" + ConditionStringIndex;
				Query.SetParameter(("ContactInformationPresentationAddress" + ConditionStringIndex), (TrimAll(String(TableRow.EmailAddress)) + "%"));
			EndIf; 
		Else
			If NOT IsBlankString(ConditionStringWhere) Then
				ConditionStringWhere = ConditionStringWhere + Chars.LF + " OR " + Chars.LF;
			EndIf;
			ConditionStringWhere = ConditionStringWhere + "CONTACTINFORMATION.Object.Description LIKE &ContactInformationPresentation" + ConditionStringIndex +
							   " OR CONTACTINFORMATION.Description LIKE &ContactInformationPresentation" + ConditionStringIndex;
			Query.SetParameter(("ContactInformationPresentation" + ConditionStringIndex), (TrimAll(String(TableRow.ObjectPresentation)) + "%"));
		EndIf;
		ConditionIndex = ConditionIndex + 1;
	EndDo;
	
	If NOT IsBlankString(ConditionString) Then
		ConditionString = " AND (" + ConditionString + ")";
	EndIf; 
	
	Query.SetParameter("Type"                , Enums.ContactInformationTypes.Email);
	Query.SetParameter("SliceDate"          , CurrentDate());
	
	Query.Text = "
	|SELECT ALLOWED
	|	CONTACTINFORMATION.Object.Description AS ObjectPresentation,
	|	CONTACTINFORMATION.Object              AS Object,
	|	CONTACTINFORMATION.ContactInformationType                 AS Type,
	|	CONTACTINFORMATION.Description       AS Presentation
	|FROM
	|	InformationRegister.CONTACTINFORMATION AS CONTACTINFORMATION
	|WHERE
	|	CONTACTINFORMATION.ContactInformationType = &Type" + ConditionString + "
	|";
	
	If Not IsBlankString(ConditionStringWhere) Then
		Query.Text = Query.Text + "
		|AND
		|	(" + ConditionStringWhere + ")
		|";
	EndIf; 
	
	QueryTable = Query.Execute().Unload();
	
	For each Row In QueryTable Do
		Row.ObjectPresentation = StrReplace(Row.ObjectPresentation, ",", "");
		Row.Presentation        = StrReplace(Row.Presentation, ",", "");
	EndDo; 
	
	Return QueryTable;

EndFunction 

Function ConvertHTMLIntoSimpleText(TextInHTMLFormat) Export

	NewHTMLDocument = New COMObject("HtmlFile");
	NewHTMLDocument.open("text/HTML");
	NewHTMLDocument.write(TextInHTMLFormat);
	NewHTMLDocument.close();
	
	FoundAndAddPrefixInTag(NewHTMLDocument.all, "BLOCKQUOTE");
	
	Return StrReplace(NewHTMLDocument.all.item(0).innerText, Char(13), "");

EndFunction

Procedure FoundAndAddPrefixInTag(Structure, TagName)

	a = 0;
	FoundIndents = 0;
	While a < Structure.length Do
		If Structure.item(a).nodeName = TagName Then
			FoundIndents = FoundIndents + 1;
			FoundAndAddPrefixInTag(Structure.item(a).all, TagName);
			TextForReplace = Structure.item(a).innerText;
			Structure.item(a).innerText = "> " + StrReplace(TextForReplace, Chars.LF, (Chars.LF + "> "));
		EndIf; 
		a = a + 1;
	EndDo; 
	
EndProcedure

Function SendEMail(User,Mail,TryToUseCommonProfile = False) Export
	
	If Mail.RecipientTP.Count()<=0 Then
		Common.ErrorMessage(Nstr("en='There is no recipients!!!';pl='Nie podano odbiorców wiadomości!'"), Nstr("en='E-mail was not send';pl='Wiadomość nie została wysłana'"));
		Return False;
	EndIf;	
	
	MailMessage = New InternetMailMessage;
	MailProfile = ReturnUserMailProfile(User);
	If MailProfile = Undefined Then
		If TryToUseCommonProfile Then
			MailProfile = ReturnUserMailProfile(Catalogs.Users.EmptyRef());
			If MailProfile = Undefined Then
				Return False;
			EndIf;	
		Else	
			Return False;
		EndIf;	
	EndIf;
	
	If ValueIsNotFilled(Mail.MailCharset) Then
		MailCharset = "utf-8";
	Else
		MailCharset = Mail.MailCharset;
	EndIf; 
	
	MailMessage.Encoding = MailCharset;
	
	MailMessage.SenderName = Mail.SenderName;
	
	MailMessage.From = Mail.SenderEmailAddress;
	
	// To
	For each ListItem In Mail.RecipientTP Do
		If ValueIsFilled(ListItem.EmailAddress) Then
			Recipient       = MailMessage.To.Add();
			Recipient.Address     = ListItem.EmailAddress;
			Recipient.DisplayName = ListItem.Presentation;
			Recipient.Encoding    = MailCharset;
		EndIf; 
	EndDo; 
	
	// Cc
	For each ListItem In Mail.CCTP Do
		If ValueIsFilled(ListItem.EmailAddress) Then
			Recipient       = MailMessage.Cc.Add();
			Recipient.Address     = ListItem.EmailAddress;
			Recipient.DisplayName = ListItem.Presentation;
			Recipient.Encoding    = MailCharset;
		EndIf; 
	EndDo;
	
	// Bcc
	For each ListItem In Mail.BCCTP Do
		If ValueIsFilled(ListItem.EmailAddress) Then
			Recipient       = MailMessage.Bcc.Add();
			Recipient.Address     = ListItem.EmailAddress;
			Recipient.DisplayName = ListItem.Presentation;
			Recipient.Encoding    = MailCharset;
		EndIf; 
	EndDo;

	MailMessageText          = MailMessage.Texts.Add();
	MailMessageText.Text     = Mail.MailText;
	MailMessageText.Encoding = MailCharset;
	
	If Mail.MailTextKind = Enums.EmailTextKind.HTML
		OR Mail.MailTextKind = Enums.EmailTextKind.HTMLWithPictures Then
		MailMessageText.TextType = InternetMailTextType.HTML;
	Else
		MailMessageText.TextType = InternetMailTextType.PlainText;
	EndIf; 
	
	MailMessage.Subject = Mail.Subject;
	
	For each ListItem In Mail.Files Do
		NewAttachment =  MailMessage.Attachments.Add(ListItem.ValueStorage.Get(),ListItem.Description);
		NewAttachment.CID = ListItem.CID;
		NewAttachment.Name = ListItem.FileName;
		If Not ListItem.FileName = "" Then
			NewAttachment.Encoding = MailCharset;
		EndIf;
	EndDo; 
	
	MailBox = New InternetMail;
	Try
		MailBox.Logon(MailProfile.MailProfile);
	Except
		Common.ErrorMessage(ErrorDescription(), Nstr("en='E-mail was not send';pl='Wiadomość nie została wysłana'"));
		Return False;
	EndTry;
	
	Try
		MailMessage.ProcessTexts();
		MailBox.Send(MailMessage);
	Except
		Common.ErrorMessage(ErrorDescription(), Nstr("en='E-mail was not send';pl='Wiadomość nie została wysłana'"));
		Return False;
	EndTry;
	
	MailBox.Logoff();
	
	Return True;
	
EndFunction

Function ReturnUserMailProfile(User) Export
	
	Query = New Query();
	Query.Text =  "SELECT
	              |	EmailAccounts.EmailAddress,
	              |	EmailAccounts.SMTPPort,
	              |	EmailAccounts.SMTPServer,
	              |	EmailAccounts.SMTPSSLConnection,
	              |	EmailAccounts.SMTPUserLogin,
	              |	EmailAccounts.SMTPUserPassword,
	              |	EmailAccounts.UserName,
	              |	EmailAccounts.UseSMTPAuthentication,
	              |	EmailAccounts.UserSignature,
	              |	EmailAccounts.POP3Port,
	              |	EmailAccounts.POP3Server
	              |FROM
	              |	InformationRegister.EmailAccounts AS EmailAccounts
	              |WHERE
	              |	EmailAccounts.User = &User";
	Query.SetParameter("User",User);
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Common.ErrorMessage(Nstr("en='There is no e-mail profile for current user!';pl='Bieżący użytkownik nie posiada profilu poczty elektronicznej!'"));
		Return Undefined;
	EndIf;
	Selection = QueryResult.Select();
	Selection.Next();
	MailProfile = New InternetMailProfile();
	If Find(Selection.EmailAddress,"@")>0 Then	
		MailProfile.User = Left(Selection.EmailAddress,Find(Selection.EmailAddress,"@")-1);
	Else
		Common.ErrorMessage(Nstr("en='Wrong e-mail address in e-mail profile for current user!';pl='Błędny adres email w profilu poczty elektronicznej bieżącego użytkownika!'"));
		Return Undefined;
	EndIf;
	If NOT Selection.UseSMTPAuthentication Then
		MailProfile.SMTPAuthentication = SMTPAuthenticationMode.None;
	Else
		MailProfile.SMTPAuthentication = SMTPAuthenticationMode.Default;
	EndIf;	
	MailProfile.SMTPUser = Selection.SMTPUserLogin;
	If Not Selection.SMTPUserLogin = "" Then
		MailProfile.SMTPPassword = Selection.SMTPUserPassword;
	EndIf;
	MailProfile.POP3ServerAddress = Selection.POP3Server;
	MailProfile.POP3Port = Selection.POP3Port;
	MailProfile.SMTPServerAddress = Selection.SMTPServer;
	MailProfile.SMTPPort = Selection.SMTPPort;
	MailProfile.Password = Selection.SMTPUserPassword;
	MailProfile.SMTPUseSSL = Selection.SMTPSSLConnection;
	Return New Structure("MailProfile, UserSignature",MailProfile,Selection.UserSignature);
	
EndFunction	

Function GetAvailableEMailsFromObject(Object) Export
	
	If Object = Undefined Then
		Return Undefined;
	EndIf;
	
	IsDocument = Documents.AllRefsType().ContainsType(TypeOf(Object));
	IsCatalog = Catalogs.AllRefsType().ContainsType(TypeOf(Object));
	
	If IsDocument OR IsCatalog Then
		
		BusinessPartnersArray = New Array();
		ContactPersonsArray = New Array();
		
		If IsDocument Then
			If CommonAtServer.IsDocumentAttribute("Supplier", Object.Metadata()) Then
				BusinessPartnersArray.Add(Object.Supplier);
			EndIf;	
			If CommonAtServer.IsDocumentAttribute("Customer", Object.Metadata()) Then
				BusinessPartnersArray.Add(Object.Customer);
			EndIf;	
			If CommonAtServer.IsDocumentAttribute("DeliveryPoint", Object.Metadata()) Then
				BusinessPartnersArray.Add(Object.DeliveryPoint);	
			EndIf;	
			If CommonAtServer.IsDocumentAttribute("CustomerContactPerson", Object.Metadata()) AND ValueIsFilled(Object.CustomerContactPerson) Then
				ContactPersonsArray.Add(Object.CustomerContactPerson);		
			EndIf;	
			If CommonAtServer.IsDocumentAttribute("DeliveryPointContactPerson", Object.Metadata()) AND ValueIsFilled(Object.DeliveryPointContactPerson) Then
				ContactPersonsArray.Add(Object.DeliveryPointContactPerson);
			EndIf;	
			If CommonAtServer.IsDocumentAttribute("ContactPerson", Object.Metadata()) AND ValueIsFilled(Object.ContactPerson) Then
				ContactPersonsArray.Add(Object.ContactPerson);	
			EndIf;	
		ElsIf IsCatalog Then
			BusinessPartnersArray.Add(Object);
		EndIf;	
		
		Query = New Query;
		
		Query.Text = "SELECT ALLOWED
		             |	ContactInformation.Object.Description AS Name,
		             |	ContactInformation.Description AS EMailAddress,
		             |	ContactInformation.Object AS Object,
		             |	TRUE AS Use,
		             |	ContactInformation.ContactInformationProfile
		             |FROM
		             |	InformationRegister.ContactInformation AS ContactInformation
		             |WHERE
		             |	ContactInformation.Object IN(&ContactPersonsArray)
		             |	AND ContactInformation.ContactInformationType = &Type
		             |
		             |UNION ALL
		             |
		             |SELECT
		             |	ContactInformation.Object.Description,
		             |	ContactInformation.Description,
		             |	ContactInformation.Object,
		             |	FALSE,
		             |	ContactInformation.ContactInformationProfile
		             |FROM
		             |	InformationRegister.ContactInformation AS ContactInformation
		             |WHERE
		             |	(ContactInformation.Object IN (&BusinessPartnersArray)
		             |			OR ContactInformation.Object IN
		             |				(SELECT
		             |					ContactPersons.Ref
		             |				FROM
		             |					Catalog.ContactPersons AS ContactPersons
		             |				WHERE
		             |					ContactPersons.Owner IN (&BusinessPartnersArray)
		             |					AND NOT ContactPersons.Ref IN (&ContactPersonsArray)))
		             |	AND ContactInformation.ContactInformationType = &Type";
		
		Query.SetParameter("BusinessPartnersArray", BusinessPartnersArray);
		Query.SetParameter("ContactPersonsArray", ContactPersonsArray);
		Query.SetParameter("Type"   , Enums.ContactInformationTypes.EMail);
		
		SliceTable = Query.Execute().Unload();
		
		Return  SliceTable;
		
	EndIf;	
	
	Return Undefined;
	
EndFunction	

#If Client Then

Function GeneratePDFForEMail(Val SpreadSheet,Fail) Export
	
	Timeout = 300;
	FileInPDFFormat = GetTempFileName("PDF");
	CatalogName = "";
	FileName = "";
	AdditionalInformationRepository.GetDirectoryAndFileName(FileInPDFFormat,CatalogName,FileName);
	StatusFileName = FileInPDFFormat + ".status";
	
	SpreadSheet.Copies = 1;
	Status(Nstr("en = 'Pdf generating, please wait...'; pl = 'Trwa generowanie Pdf, proszę czekać...'"));
	SpreadSheet.Write(FileInPDFFormat, SpreadsheetDocumentFileType.PDF);
	TimeoutDate = CurrentDate() + Timeout;
	StatusFile = New File(FileInPDFFormat);
	While NOT (StatusFile.Exist() OR (CurrentDate()>=TimeoutDate)) Do
		
	EndDo;
	
	Timeout = 10;
	TimeoutDate = CurrentDate() + Timeout;
	
	TimeoutDate = CurrentDate() + Timeout;
	While StatusFile.Exist() AND CurrentDate()< TimeoutDate Do
		Try
			DeleteFiles(StatusFileName);
		Except
		EndTry;
	EndDo;
	
	Status();
	
	Return FileInPDFFormat;
	
EndFunction	

#EndIf

Function GetBinaryData(FileName,DoNotDeletFiles = False) Export

	File = New File(FileName);
	
	If File.Exist() Then
		Data = New BinaryData(FileName);
		
		If NOT DoNotDeletFiles Then
			Try
				DeleteFiles(FileName);
			Except
			EndTry;
		EndIf;	
		Return Data;
	Else
		Return Undefined;
	EndIf; 
	

EndFunction

Function GenerateHTMLFile(Spreadsheet) Export
	
	FileInHTMLFormat = GetTempFileName("HTM");
	Spreadsheet.Output = UseOutput.Enable;
	Spreadsheet.Write(FileInHTMLFormat, SpreadsheetDocumentFileType.HTML);
	Return FileInHTMLFormat;
	
EndFunction	

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WITH CHARSET LIST

// Function returns table with charset names
//
// Parameters
//  NONE
//
// Return value:
//   Value table
//
Function GetCharsetTable() Export

	CharsetTable = New ValueTable;
	CharsetTable.Columns.Add("Name");
	CharsetTable.Columns.Add("Presentation");
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "ibm852";
	NewRow.Presentation ="ibm852 ("+ Nstr("en='Central europe';pl='Europa Środkowa'")+ " DOS)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "ibm866";
	NewRow.Presentation = "ibm866 ("+Nstr("en='Cyrillic';pl='Cyrylica'")+" DOS)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "iso-8859-1";
	NewRow.Presentation = "iso-8859-1 ("+Nstr("en='Westeuropian';pl='Zachodni'")+" ISO)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "iso-8859-2";
	NewRow.Presentation = "iso-8859-2 ("+Nstr("en='Central europe';pl='Europa Środkowa'")+" ISO)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "iso-8859-3";
	NewRow.Presentation = "iso-8859-3 ("+Nstr("en='Latin';pl='Latinica'")+" 3 ISO)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "iso-8859-4";
	NewRow.Presentation = "iso-8859-4 ("+Nstr("en='Baltic';pl='Bałtycki'")+" ISO)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "iso-8859-5";
	NewRow.Presentation = "iso-8859-5 ("+Nstr("en='Cyrillic';pl='Cyrylica'")+" ISO)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "iso-8859-7";                                    
	NewRow.Presentation = "iso-8859-7 ("+Nstr("en='Greek';pl='Grecki'")+" ISO)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "iso-8859-9";
	NewRow.Presentation = "iso-8859-9 ("+Nstr("en='Turkish';pl='Turecki'")+" ISO)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "iso-8859-15";
	NewRow.Presentation = "iso-8859-15 ("+Nstr("en='Latin';pl='Latinica'")+" 9 ISO)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "koi8-r";
	NewRow.Presentation = "koi8-r ("+Nstr("en='Cyrillic';pl='Cyrylica'")+" KOI8-R)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "koi8-u";
	NewRow.Presentation = "koi8-u ("+Nstr("en='Cyrillic';pl='Cyrylica'")+" KOI8-U)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "us-ascii";
	NewRow.Presentation = "us-ascii "+Nstr("en='USA';pl='USA'");
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "utf-8";
	NewRow.Presentation = "utf-8 ("+Nstr("en='Unicode';pl='Unicode'")+" UTF-8)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "windows-1250";
	NewRow.Presentation = "windows-1250 ("+Nstr("en='Central europe';pl='Europa Środkowa'")+" Windows)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "windows-1251";
	NewRow.Presentation = "windows-1251 ("+Nstr("en='Cyrillic';pl='Cyrylica'")+" Windows)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "windows-1252";
	NewRow.Presentation = "windows-1252 ("+Nstr("en='Westeuropian';pl='Zachodni'")+" Windows)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "windows-1253";
	NewRow.Presentation = "windows-1253 ("+Nstr("en='Greek';pl='Grecki'")+" Windows)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "windows-1254";
	NewRow.Presentation = "windows-1254 ("+Nstr("en='Turkish';pl='Turecki'")+" Windows)";
	
	NewRow = CharsetTable.Add();
	NewRow.Name           = "windows-1257";
	NewRow.Presentation = "windows-1257 ("+Nstr("en='Baltic';pl='Bałtycki'")+" Windows)";
	
	Return CharsetTable;

EndFunction

// Function returns charset list
//
// Parameters
//  NONE
//
// Return value:
//   ValueList
//
Function GetCharsetList() Export
	
	ValueList = New ValueList;
	
	CharsetTable = GetCharsetTable();
	For each TableRow In CharsetTable Do
		ValueList.Add(TableRow.Name, TableRow.Presentation);
	EndDo;
	
	Return ValueList;
	
EndFunction

Function CreateMailMessageObject(Email, tempDir = "") Export
	
	Query = New Query;
	Query.Text = "SELECT
	             |	Files.Ref,
	             |	Files.Data as ValueStorage,
	             |	Files.Description as FileName,
	             |	Files.Description as Description
	             |FROM
	             |	Catalog.Files AS Files
	             |WHERE
	             |	Files.RefObject = &Owner";
	
	Query.SetParameter("Owner", Email);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	TableAtt = Result.Unload();
	For Each RowTableAtt In TableAtt Do 
		Data = RowTableAtt.ValueStorage.Get();
		If TypeOf(Data) = Type("TextDocument") Then
			Data.Write(AdditionalInformationRepository.GetDirectoryName() + "\" + RowTableAtt.FileName, TextEncoding.ANSI);
		Else
			Data.Write(AdditionalInformationRepository.GetDirectoryName() + "\" + RowTableAtt.FileName);
		EndIf;
		RowTableAtt.ValueStorage = New ValueStorage(AdditionalInformationRepository.GetDirectoryName() + "\" + RowTableAtt.FileName);
	EndDo;
	
	NewEMail = DataProcessors.EMail.Create();
	
	NewEMail.Files = TableAtt;
	NewEMail.Recipient = Email.Recipient;
	NewEMail.MailText = Email.Text;
	NewEMail.Subject = Email.Description;
	NewEMail.User = SessionParameters.CurrentUser;
		
	RecordManager = InformationRegisters.EmailAccounts.CreateRecordManager();
	RecordManager.User = NewEMail.User;
	RecordManager.Read();
	
	If ValueIsFilled(RecordManager.EmailAddress) Then
		
		NewEMail.SenderPresentation = RecordManager.UserName + " <" + RecordManager.EmailAddress + ">";
		NewRow = NewEMail.BCCTP.Add();
		NewEMail.SenderName = RecordManager.UserName;
		NewEMail.SenderEmailAddress = RecordManager.EmailAddress;
		NewRow.EmailAddress = RecordManager.EmailAddress;
		NewRow.Presentation = RecordManager.UserName;
		
		NewRow.Object = NewEMail.User;
		
	Else	
		
		Return Undefined;
		
	EndIf;	
	
	Recipients = TrimAll(Email.Recipient);
	While Recipients <> "" Do
		Position = Find(Recipients, ";");
		If Position = 0 Then
			Recipient = Recipients;
			Recipients = "";
		Else
			Recipient = TrimR(Left(Recipients, Position - 1));
			Recipients = TrimL(Mid(Recipients, Position + 1));
		EndIf;
		If Recipient <> "" Then
			NewRecipient = NewEMail.RecipientTP.Add();
			NewRecipient.EmailAddress = Recipient;
			NewRecipient.Presentation = Recipient;
		EndIf;
	EndDo;

	Return NewEMail;
EndFunction

// Send an e-mail.
//
// Parameters:
// Email - CatalogRef.OutgoingEmails - e-mail to send.
//
// Returns:
// True - the e-mail sent successfully.
// False - the e-mail server description profile is not created.
Function SendEmailFromCatalog(Email, tempDir = "") Export
	MessageObject = CreateMailMessageObject(Email, tempDir);
	If MessageObject = Undefined Then
		Return False;
	EndIf;

	If SendEMail(SessionParameters.CurrentUser, MessageObject) Then
		RS = InformationRegisters.OutgoingEmailsState.CreateRecordSet();
		RS.Filter.Email.Set(Email);
		Write = RS.Add();
		Write.Email = Email;
		Write.Sent = True;
		RS.Write();
		Return True;
	Else
		Return False;
	EndIf;
EndFunction

Function SendMailsReports(ReportsGeneratingScheduleRef,GeneratedReportsValueTable) Export
		
	RecipientsCount = ReportsGeneratingScheduleRef.RecipientsTable.Count();
	If RecipientsCount = 0 Then
		Return False;
	EndIf;	
	
	MailMessage = New InternetMailMessage;
	MailProfile = ReturnUserMailProfile(ReportsGeneratingScheduleRef.User);
	If MailProfile = Undefined Then
		Return False;
	EndIf;
	
	MailCharset 			 = "utf-8";
	MailMessage.Encoding 	 = MailCharset;
	MailMessage.SenderName 	 = ReportsGeneratingScheduleRef.User.Description;
	
	ReplyTo       = MailMessage.ReplyTo.Add();
	RecordManager = InformationRegisters.EmailAccounts.CreateRecordManager();
	If ReportsGeneratingScheduleRef.MailAccount = Enums.ReportsGeneratingSchedulesMailAccount.PrivateAccount Then
		RecordManager.User = ReportsGeneratingScheduleRef.User;
	ElsIf ReportsGeneratingScheduleRef.MailAccount = Enums.ReportsGeneratingSchedulesMailAccount.CompanyAccount Then
		RecordManager.User = Catalogs.Users.EmptyRef();
	EndIf;	
	RecordManager.Read();
	
	SenderEmailAddress =RecordManager.EmailAddress;
	UserSignatureText = RecordManager.UserSignature.Get();
	
	ReplyTo       = MailMessage.ReplyTo.Add();
	ReplyTo.Address = SenderEmailAddress;
	ReplyTo.DisplayName = RecordManager.UserName;
	
	MailMessage.From  = SenderEmailAddress;
	
	MailMessage.Subject = ReportsGeneratingScheduleRef.Topic;

	AddToContent = "";
	For Each GeneratedReportsValueTableRow In GeneratedReportsValueTable Do
		
		If GeneratedReportsValueTableRow.AttachmentType = Enums.AttachmentType.AddToContent Then
			
			TmpFileName = GetTempFileName();
			BinaryData = GeneratedReportsValueTableRow.ValueStorage.Get();
			BinaryData.Write(TmpFileName);
			TextDocument = New TextDocument;
			TextDocument.Read(TmpFileName);
			AddToContent = AddToContent + "<br><br>" +
			"<hr>" +
			AdditionalInformationRepository.GenerateFileName(GeneratedReportsValueTableRow.FileName) +
			"<br><br>" + TextDocument.GetText();
			File = New File(TmpFileName);
			If File.Exist() Then
				Try
					DeleteFiles(TmpFileName);
				Except
				EndTry;
			EndIf;							
		Else
			NewAttachment =  MailMessage.Attachments.Add(GeneratedReportsValueTableRow.ValueStorage.Get(),GeneratedReportsValueTableRow.FileName);
			NewAttachment.Name = GeneratedReportsValueTableRow.FileName;
			NewAttachment.Encoding = MailCharset;
		EndIf;
		
	EndDo;
	
	MailMessageText          = MailMessage.Texts.Add();
	MailMessageText.Text     = ReportsGeneratingScheduleRef.MailText + Chars.LF + AddToContent + Chars.LF + UserSignatureText;
	MailMessageText.Encoding = MailCharset;
	MailMessageText.TextType = InternetMailTextType.HTML;
	
	MailBox = New InternetMail;
	Try
		MailBox.Logon(MailProfile.MailProfile);
	Except
		Common.ErrorMessage(ErrorDescription(), Nstr("en='E-mail was not send';pl='Wiadomość nie została wysłana'"));
		Return False;
	EndTry;
	
	RecipientsCount = ReportsGeneratingScheduleRef.RecipientsTable.Count();
	
	#If Client Then
		ExchangeProcessingForm = GetCommonForm("DataProcessingProgress");
		ProgressBar = 1;
	#EndIf
	
	// To
	For each ListItem In ReportsGeneratingScheduleRef.RecipientsTable Do
		
		MailMessage.To.Clear();
		If ValueIsFilled(ListItem.EmailAddress) Then
			Recipient       = MailMessage.To.Add();
			Recipient.Address     = ListItem.EmailAddress;
			Recipient.DisplayName = ListItem.Presentation;
			Recipient.Encoding    = MailCharset;
		EndIf; 
		
		Try
			MailBox.Send(MailMessage);
		Except
			Common.ErrorMessage(ErrorDescription(), Nstr("en='E-mail was not send';pl='Wiadomość nie została wysłana'"));
			Return False;
		EndTry;
		
		#If Client Then
			
			If RecipientsCount = 1 Then
				MailsCount = String(ProgressBar) + " / " + String(RecipientsCount) + " " + NStr("en = 'message'; pl = 'wiadomość'");
			Else
				MailsCount = String(ProgressBar) + " / " + String(RecipientsCount) + " " + NStr("en = 'messages'; pl = 'wiadomości'");
			EndIf;
			
			
			ExchangeProcessingForm.DataProcessingName = Nstr("en='Sending mails status';pl='Status wysyłania maili'");
			ExchangeProcessingForm.DataProcessingComment = MailsCount;
			ExchangeProcessingForm.Value = ProgressBar;
			ExchangeProcessingForm.MaxValue = RecipientsCount;
			
			If Not ExchangeProcessingForm.Isopen() Then
				ExchangeProcessingForm.Open();
			EndIf;
			
			ProgressBar = ProgressBar + 1;
		#EndIf
		
	EndDo; 
	
	#If Client Then
		If RecipientsCount>0 Then
			ExchangeProcessingForm.Close();
		EndIf;	
	#EndIf
	
	MailBox.Logoff();
	
	Return True;
	
EndFunction


