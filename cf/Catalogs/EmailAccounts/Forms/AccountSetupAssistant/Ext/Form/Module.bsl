
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Items.GoToSettingsButton.Visible = False;
	SecurityProfilesAreUsed = GetFunctionalOption("SecurityProfilesAreUsed");
	Items.SettingsMethod.Visible = Not SecurityProfilesAreUsed;
	If SecurityProfilesAreUsed Then
		SettingsMethod = "Manually";
	Else
		SettingsMethod = "automatically";
	EndIf;
	
	ContextMode = Parameters.ContextMode;
	Items.UseAccount.Visible = Not ContextMode;
	Items.AccountSetupTitle.Title = ?(ContextMode,
		NStr("en='To send messages, set email account.';ru='Для отправки писем необходимо настроить учетную запись электронной почты'"),
		NStr("en='Enter account parameters';ru='Введите параметры учетной записи'"));
		
	If Not ContextMode Then
		Title = NStr("en='Create email account';ru='Создание учетной записи электронной почты'");
	Else
		Title = NStr("en='Email account setting';ru='Настройка учетной записи электронной почты'");
	EndIf;
	
	UseForReceiving = Not ContextMode;
	UseForSending = True;
	Items.Pages.CurrentPage = Items.AccountSetup;
	
	WindowOptionsKey = ?(ContextMode, "ContextMode", "NoncontextMode");
	
	If Parameters.Property("Key") Then
		UserAccountRefs = Parameters.Key;
		QueryText =
		"SELECT
		|	EmailAccounts.EmailAddress AS EmailAddress,
		|	EmailAccounts.UserName AS EmailSenderName,
		|	EmailAccounts.Description AS AccountDescription
		|FROM
		|	Catalog.EmailAccounts AS EmailAccounts
		|WHERE
		|	EmailAccounts.Ref = &Ref";
		Query = New Query(QueryText);
		Query.SetParameter("Ref", Parameters.Key);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			FillPropertyValues(ThisObject, Selection);
		EndIf;
	Else
		NewAccountRefs = Catalogs.EmailAccounts.GetRef();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetCurrentPageItems()
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If ClosingFormConfirmationRequired Then
		Cancel = True;
		AttachIdleHandler("ShowQuestionBoxBeforeClosingForm", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure PasswordOnChange(Item)
	PasswordForSendingEmails = PasswordForReceivingEmails;
EndProcedure

&AtClient
Procedure KeepEmailCopiesOnServerOnChange(Item)
	RefreshDaysBeforeDeletionSettingAvailability();
EndProcedure

&AtClient
Procedure EmailAddressOnChange(Item)
	SettingsAreFilled = False;
	ClosingFormConfirmationRequired = True;
EndProcedure

&AtClient
Procedure EmailSenderNameOnChange(Item)
	ClosingFormConfirmationRequired = True;
EndProcedure

&AtClient
Procedure SetupMethodOnChange(Item)
	SetCurrentPageItems();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient

Procedure Next(Command)
	
	GoToNextPage();
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	CurrentPage = Items.Pages.CurrentPage;
	
	PreviousPage = Undefined;
	If CurrentPage = Items.OutgoingMailServerSetup Then
		PreviousPage = Items.AccountSetup;
	ElsIf CurrentPage = Items.IncomingMailServerSetup Then
		If UseForSending Then
			PreviousPage = Items.OutgoingMailServerSetup;
		Else
			PreviousPage = Items.AccountSetup;
		EndIf;
	ElsIf CurrentPage = Items.AdditionalSettings Then
		If UseForReceiving Or RequiredServerLogonBeforeSending Then
			PreviousPage = Items.IncomingMailServerSetup;
		ElsIf UseForSending Then
			PreviousPage = Items.OutgoingMailServerSetup;
		Else
			PreviousPage = Items.AccountSetup;
		EndIf;
	ElsIf CurrentPage = Items.CheckingAccountSettings Then
		PreviousPage = Items.AccountSetup;
	EndIf;
	
	If PreviousPage <> Undefined Then
		Items.Pages.CurrentPage = PreviousPage;
	EndIf;
	
	SetCurrentPageItems()
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ShowQuestionBoxBeforeClosingForm()
	QuestionText = NStr("en='Entered data has not been written. Close the form?';ru='Введенные данные не записаны. Закрыть форму?'");
	NotifyDescription = New NotifyDescription("FormClosingConfirmed", ThisObject);
	Buttons = New ValueList;
	Buttons.Add("Close", NStr("en='Close';ru='Закрыть'"));
	Buttons.Add(DialogReturnCode.Cancel, NStr("en='Do not close';ru='Не закрывать'"));
	ShowQueryBox(NOTifyDescription, NStr("en='Entered data has not been written. Close the form?';ru='Введенные данные не записаны. Закрыть форму?'"), Buttons,,
		DialogReturnCode.Cancel, NStr("en='Account setup';ru='Настройка учетной записи'"));
EndProcedure

&AtClient
Procedure FormClosingConfirmed(QuestionResult, AdditionalParameters = Undefined) Export
	
	If QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	ClosingFormConfirmationRequired = False;
	Close(False);
	
EndProcedure

&AtClient
Procedure GoToNextPage()
	
	Cancel = False;
	CurrentPage = Items.Pages.CurrentPage;
	
	NextPage = Undefined;
	If CurrentPage = Items.AccountSetup Then
		CheckFillingOnPageAccountSetting(Cancel);
		If Not Cancel AND Not SettingsAreFilled Then
			FillAccountSettings();
		EndIf;
		If SettingsMethod = "automatically" Or CheckingCompletedWithErrors Then
			NextPage = Items.CheckingAccountSettings;
		Else
			If UseForSending Then
				NextPage = Items.OutgoingMailServerSetup;
			ElsIf UseForReceiving Then
				NextPage = Items.IncomingMailServerSetup;
			Else
				NextPage = Items.AdditionalSettings;
			EndIf;
		EndIf;
	ElsIf CurrentPage = Items.OutgoingMailServerSetup Then
		If Not ContextMode Or RequiredServerLogonBeforeSending Then
			NextPage = Items.IncomingMailServerSetup;
		Else
			NextPage = Items.AdditionalSettings;
		EndIf;
	ElsIf CurrentPage = Items.IncomingMailServerSetup Then
		NextPage = Items.AdditionalSettings;
	ElsIf CurrentPage = Items.AdditionalSettings Then
		NextPage = Items.CheckingAccountSettings;
	ElsIf CurrentPage = Items.CheckingAccountSettings Then
		If CheckingCompletedWithErrors Then
			NextPage = Items.AccountSetup;
		Else
			NextPage = Items.AccountConfiguredSuccessfully;
		EndIf;
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	If NextPage = Undefined Then
		Close(True);
	Else
		Items.Pages.CurrentPage = NextPage;
		SetCurrentPageItems();
	EndIf;
	
	If Items.Pages.CurrentPage = Items.CheckingAccountSettings Then
		If SettingsMethod = "automatically" Then
			AttachIdleHandler("ConfigureConnectionParametersAutomatically", 0.1, True);
		Else
			AttachIdleHandler("CheckSettings", 0.1, True);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckSettings()
	Query = CreateQueryOnExternalResourcesUse();
	ClosingAlert = New NotifyDescription("CheckSettingsPermissionsQueryCompleted", ThisObject);
	
	WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(
		CommonUseClientServer.ValueInArray(Query), ThisObject, ClosingAlert);
EndProcedure

&AtClient
Procedure CheckSettingsPermissionsQueryCompleted(QueryResult, AdditionalParameters) Export
	If Not QueryResult = DialogReturnCode.OK Then
		Return;
	EndIf;
	
	CheckAccountSettings();
	If ValueIsFilled(UserAccountRefs) Then 
		NotifyChanged(TypeOf(UserAccountRefs));
	EndIf;
	GoToNextPage();
EndProcedure

&AtServer
Function CreateQueryOnExternalResourcesUse()
	
	Return WorkInSafeMode.QueryOnExternalResourcesUse(
		permissions(), NewAccountRefs);
	
EndFunction

&AtServer
Function permissions()
	
	Result = New Array;
	
	If UseForSending Then
		Result.Add(
			WorkInSafeMode.PermissionForWebsiteUse(
				"SMTP",
				OutgoingMailServer,
				OutgoingMailServerPort,
				NStr("en='Email.';ru='Эл. адрес.'")));
	EndIf;
	
	If UseForReceiving Then
		Result.Add(
			WorkInSafeMode.PermissionForWebsiteUse(
				Protocol,
				IncomingMailServer,
				IncomingMailServerPort,
				NStr("en='Email.';ru='Эл. адрес.'")));
	EndIf;
	
	Return Result;
	
EndFunction


&AtClient
Procedure CheckFillingOnPageAccountSetting(Cancel)
	
	If IsBlankString(EmailAddress) Then
		CommonUseClientServer.MessageToUser(NStr("en='Enter email address';ru='Введите адрес электронной почты'"), , "EmailAddress", , Cancel);
	ElsIf Not CommonUseClientServer.EmailAddressMeetsRequirements(EmailAddress, True) Then
		CommonUseClientServer.MessageToUser(NStr("en='Email address you have typed is incorrect.';ru='Адрес электронной почты введен неверно'"), , "EmailAddress", , Cancel);
	EndIf;
	
	If IsBlankString(PasswordForReceivingEmails) Then
		CommonUseClientServer.MessageToUser(NStr("en='Enter password';ru='Введите пароль'"), , "PasswordForReceivingEmails", , Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetCurrentPageItems()
	
	CurrentPage = Items.Pages.CurrentPage;
	
	// ButtonNext
	If CurrentPage = Items.AccountConfiguredSuccessfully Then
		If ContextMode Then
			NextButtonTitle = NStr("en='Continue';ru='Продолжить'");
		Else
			NextButtonTitle = NStr("en='Close';ru='Закрыть'");
		EndIf;
	Else
		If CurrentPage = Items.AccountSetup
			AND CheckingCompletedWithErrors Then
				NextButtonTitle = NStr("en='Retry';ru='Повторить'");
		ElsIf CurrentPage = Items.AccountSetup
			AND SettingsMethod = "automatically" Then
			If ContextMode Then
				NextButtonTitle = NStr("en='Configure';ru='Настроить'");
			Else
				NextButtonTitle = NStr("en='Create';ru='Сформировать отчет'");
			EndIf;
		Else
			NextButtonTitle = NStr("en='Next >';ru='Далее  >'");
		EndIf;
	EndIf;
	Items.ButtonNext.Title = NextButtonTitle;
	Items.ButtonNext.Enabled = CurrentPage <> Items.CheckingAccountSettings;
	Items.ButtonNext.Visible = CurrentPage <> Items.CheckingAccountSettings;
	
	// ButtonBack
	Items.ButtonBack.Visible = CurrentPage <> Items.AccountSetup
		AND CurrentPage <> Items.AccountConfiguredSuccessfully
		AND CurrentPage <> Items.CheckingAccountSettings;
	
	// ButtonCancel
	Items.ButtonCancel.Visible = CurrentPage <> Items.AccountConfiguredSuccessfully;
	
	// GoToSettingsButton
	Items.GoToSettingsButton.Visible = Not SecurityProfilesAreUsed AND (CurrentPage = Items.AccountSetup
		AND CheckingCompletedWithErrors Or Not ContextMode AND CurrentPage = Items.AccountConfiguredSuccessfully);
		
	If Not ContextMode AND CurrentPage = Items.AccountConfiguredSuccessfully Then
		Items.GoToSettingsButton.Title = NStr("en='Go to account';ru='Перейти к учетной записи'");
	Else
		Items.GoToSettingsButton.Title = NStr("en='Configure connection parameters manually';ru='Настроить параметры подключения вручную'");
	EndIf;
	
	If CurrentPage = Items.AccountSetup Then
		Items.FailedToLogonPictureAndLabel.Visible = CheckingCompletedWithErrors;
		Items.SettingsMethod.Visible = Not CheckingCompletedWithErrors AND Not SecurityProfilesAreUsed;
	EndIf;
	
	If CurrentPage = Items.IncomingMailServerSetup Then
		RefreshDaysBeforeDeletionSettingAvailability()
	EndIf;
	
	If CurrentPage = Items.AccountConfiguredSuccessfully Then
		Items.LabelAccountConfiguredSuccessfully.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Account parameters
		|setting is complete.';ru='Настройка
		|параметров учетной записи %1 завершена.'"), EmailAddress);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshDaysBeforeDeletionSettingAvailability()
	Items.DeleteEmailsFromServerAfter.Enabled = KeepEmailCopiesOnServer;
	Items.LabelDays.Enabled = Items.DeleteEmailsFromServerAfter.Enabled;
EndProcedure

&AtClient
Procedure GoToSettings(Command)
	CurrentPage = Items.Pages.CurrentPage;
	If Not ContextMode AND CurrentPage = Items.AccountConfiguredSuccessfully Then
		ShowValue(,UserAccountRefs);
		Close(True);
	Else
		If SettingsMethod = "automatically" Then
			SettingsMethod = "Manually";
		EndIf;
		Items.Pages.CurrentPage = Items.OutgoingMailServerSetup;
		SetCurrentPageItems();
	EndIf;
EndProcedure

&AtClient
Procedure FillAccountSettings()
	FillPropertyValues(ThisObject, DefaultSettings(EmailAddress, PasswordForReceivingEmails));
	If IsBlankString(AccountDescription) Then
		AccountDescription = EmailAddress;
	EndIf;

	SettingsAreFilled = True;
EndProcedure

&AtClientAtServerNoContext
Function DefaultSettings(EmailAddress, Password)
	
	Position = Find(EmailAddress, "@");
	ServerNameInAccount = Mid(EmailAddress, Position + 1);
	
	Settings = New Structure;
	
	Settings.Insert("UserNameForReceivingEmails", EmailAddress);
	Settings.Insert("UserNameForSendingEmails", EmailAddress);
	
	Settings.Insert("PasswordForSendingEmails", Password);
	Settings.Insert("PasswordForReceivingEmails", Password);
	
	Settings.Insert("Protocol", "POP");
	Settings.Insert("IncomingMailServer", "pop." + ServerNameInAccount);
	Settings.Insert("IncomingMailServerPort", 995);
	Settings.Insert("UseSecureConnectionForIncomingMail", True);
	Settings.Insert("UseSecureLogonToIncomingMailServer", False);
	
	Settings.Insert("OutgoingMailServer", "smtp." + ServerNameInAccount);
	Settings.Insert("OutgoingMailServerPort", 465);
	Settings.Insert("UseSecureConnectionForOutgoingMail", True);
	Settings.Insert("UseSecureLogonToOutgoingMailServer", False);
	
	Settings.Insert("ServerTimeout", 30);
	Settings.Insert("KeepEmailCopiesOnServer", False);
	Settings.Insert("DeleteEmailsFromServerAfter", 10);
	
	Return Settings;
EndFunction

&AtServer
Function CheckConnectionToIncomingMailServer()
	
	Profile = InternetMailProfile(True);
	InternetMail = New InternetMail;
	
	UsedProtocol = InternetMailProtocol.POP3;
	If Protocol = "IMAP" Then
		UsedProtocol = InternetMailProtocol.IMAP;
	EndIf;
	
	ErrorText = "";
	Try
		InternetMail.Logon(Profile, UsedProtocol);
		InternetMail.GetHeaders();
	Except
		ErrorText = BriefErrorDescription(ErrorInfo());
	EndTry;
	
	InternetMail.Logoff();
	
	Return ErrorText;
	
EndFunction

&AtServer
Function CheckConnectionToOutgoingMailServer()
	
	EmailParameters = New Structure;
	
	Subject = NStr("en='""1C:Enterprise"" test message';ru='Тестовое сообщение 1С:Предприятие'");
	Body = NStr("en='The email is sent using ""1C:Enterprise"" service';ru='Это сообщение отправлено подсистемой электронной почты 1С:Предприятие'");
	
	CurEmail = New InternetMailMessage;
	CurEmail.Subject = Subject;
	
	Recipient = CurEmail.To.Add(EmailAddress);
	Recipient.DisplayName = EmailSenderName;
	
	CurEmail.SenderName = EmailSenderName;
	CurEmail.From.DisplayName = EmailSenderName;
	CurEmail.From.Address = EmailAddress;
	
	Text = CurEmail.Texts.Add(Body);
	Text.TextType = InternetMailTextType.PlainText;

	Profile = InternetMailProfile();
	InternetMail = New InternetMail;
	
	ErrorText = "";
	Try
		InternetMail.Logon(Profile);
		InternetMail.Send(CurEmail);
	Except
		ErrorText = BriefErrorDescription(ErrorInfo());
	EndTry;
	
	InternetMail.Logoff();
	
	Return ErrorText;
	
EndFunction

&AtServer
Procedure CheckAccountSettings()
	
	CheckingCompletedWithErrors = False;
	
	IncomingMailServerMessage = "";
	If UseForReceiving Then
		IncomingMailServerMessage = CheckConnectionToIncomingMailServer();
	EndIf;
	
	OutgoingMailServerMessage = "";
	If UseForSending Then
		OutgoingMailServerMessage = CheckConnectionToOutgoingMailServer();
	EndIf;
	
	ErrorText = "";
	If Not IsBlankString(OutgoingMailServerMessage) Then
		ErrorText = NStr("en='Unable to connect to the outgoing mail server:';ru='Не удалось подключиться к серверу исходящей почты:'" + Chars.LF)
			+ OutgoingMailServerMessage + Chars.LF;
	EndIf;
	
	If Not IsBlankString(IncomingMailServerMessage) Then
		ErrorText = ErrorText
			+ NStr("en='Unable to connect to the incoming mail server:';ru='Не удалось подключиться к серверу входящей почты:'" + Chars.LF)
			+ IncomingMailServerMessage;
	EndIf;
	
	ErrorMessages = TrimAll(ErrorText);
			
	If Not IsBlankString(ErrorText) Then
		CheckingCompletedWithErrors = True;
	Else
		CreateAccount();
	EndIf;
	
EndProcedure

&AtServer
Procedure CreateAccount()
	If ContextMode AND IsBlankString(CommonUse.ObjectAttributeValue(Catalogs.EmailAccounts.SystemEmailAccount, "EmailAddress")) Then
		UserAccount = Catalogs.EmailAccounts.SystemEmailAccount.GetObject();
	Else
		If UserAccountRefs.IsEmpty() Then
			UserAccount = Catalogs.EmailAccounts.CreateItem();
			UserAccount.SetNewObjectRef(NewAccountRefs);
		Else
			UserAccount = UserAccountRefs.GetObject();
		EndIf;
	EndIf;
	FillPropertyValues(UserAccount, ThisObject);
	UserAccount.UserName = EmailSenderName;
	UserAccount.User = UserNameForReceivingEmails;
	UserAccount.Password = PasswordForReceivingEmails;
	UserAccount.SMTPUser = UserNameForSendingEmails;
	UserAccount.SMTPPassword = PasswordForSendingEmails;
	UserAccount.Timeout = ServerTimeout;
	UserAccount.LeaveMessageCopiesOnServer = KeepEmailCopiesOnServer;
	UserAccount.ServerEmailStoragePeriod = DeleteEmailsFromServerAfter;
	UserAccount.IncomingMailProtocol = Protocol;
	UserAccount.Description = AccountDescription;
	UserAccount.Write();
	UserAccountRefs = UserAccount.Ref;
	ClosingFormConfirmationRequired = False;
EndProcedure

&AtServer
Function InternetMailProfile(ForReceiving = False)
	
	Profile = New InternetMailProfile;
	If ForReceiving Or RequiredServerLogonBeforeSending Then
		If Protocol = "IMAP" Then
			Profile.IMAPServerAddress = IncomingMailServer;
			Profile.IMAPUseSSL = UseSecureConnectionForIncomingMail;
			Profile.IMAPPassword = PasswordForReceivingEmails;
			Profile.IMAPUser = UserNameForReceivingEmails;
			Profile.IMAPPort = IncomingMailServerPort;
			Profile.IMAPSecureAuthenticationOnly = UseSecureLogonToIncomingMailServer;
		Else
			Profile.POP3ServerAddress = IncomingMailServer;
			Profile.POP3UseSSL = UseSecureConnectionForIncomingMail;
			Profile.Password = PasswordForReceivingEmails;
			Profile.User = UserNameForReceivingEmails;
			Profile.POP3Port = IncomingMailServerPort;
			Profile.POP3SecureAuthenticationOnly = UseSecureLogonToIncomingMailServer;
		EndIf;
	EndIf;
	
	If Not ForReceiving Then
		Profile.POP3BeforeSMTP = RequiredServerLogonBeforeSending;
		Profile.SMTPServerAddress = OutgoingMailServer;
		Profile.SMTPUseSSL = UseSecureConnectionForOutgoingMail;
		Profile.SMTPPassword = PasswordForSendingEmails;
		Profile.SMTPUser = UserNameForSendingEmails;
		Profile.SMTPPort = OutgoingMailServerPort;
		Profile.SMTPSecureAuthenticationOnly = UseSecureLogonToOutgoingMailServer;
	EndIf;
	
	Profile.Timeout = ServerTimeout;
	
	Return Profile;
	
EndFunction

&AtServer
Function UserNameVariants()
	
	Position = Find(EmailAddress, "@");
	UserNameInAccount = Left(EmailAddress, Position - 1);
	
	Result = New Array;
	Result.Add(EmailAddress);
	Result.Add(UserNameInAccount);
	
	Return Result;
	
EndFunction

&AtServer
Function ConnectionSettingsToIMAPServerVariants()
	
	Position = Find(EmailAddress, "@");
	UserNameInAccount = Left(EmailAddress, Position - 1);
	ServerNameInAccount = Mid(EmailAddress, Position + 1);
	
	Result = New ValueTable;
	Result.Columns.Add("IncomingMailServer");
	Result.Columns.Add("IncomingMailServerPort");
	Result.Columns.Add("UseSecureConnectionForIncomingMail");
	
	// Standard setting appropriate for gmail, yandex and mail mailboxes.ru
	// server name with "imap prefix.", secure connection.
	SettingVariant = Result.Add();
	SettingVariant.IncomingMailServer = "imap." + ServerNameInAccount;
	SettingVariant.IncomingMailServerPort = 993;
	SettingVariant.UseSecureConnectionForIncomingMail = True;
	
	// Server name with "mail prefix.", secure connection.
	SettingVariant = Result.Add();
	SettingVariant.IncomingMailServer = "mail." + ServerNameInAccount;
	SettingVariant.IncomingMailServerPort = 993;
	SettingVariant.UseSecureConnectionForIncomingMail = True;
	
	// Server name without "imap prefix.", secure connection.
	SettingVariant = Result.Add();
	SettingVariant.IncomingMailServer = ServerNameInAccount;
	SettingVariant.IncomingMailServerPort = 993;
	SettingVariant.UseSecureConnectionForIncomingMail = True;
	
	// Server name with "imap prefix.", nonsecure connection.
	SettingVariant = Result.Add();
	SettingVariant.IncomingMailServer = "imap." + ServerNameInAccount;
	SettingVariant.IncomingMailServerPort = 143;
	SettingVariant.UseSecureConnectionForIncomingMail = False;
	
	// Server name with "mail prefix.", nonsecure connection.
	SettingVariant = Result.Add();
	SettingVariant.IncomingMailServer = "mail." + ServerNameInAccount;
	SettingVariant.IncomingMailServerPort = 143;
	SettingVariant.UseSecureConnectionForIncomingMail = False;
	
	// Server name without "imap prefix.", nonsecure connection.
	SettingVariant = Result.Add();
	SettingVariant.IncomingMailServer = ServerNameInAccount;
	SettingVariant.IncomingMailServerPort = 143;
	SettingVariant.UseSecureConnectionForIncomingMail = False;
	
	Return Result;
	
EndFunction

&AtServer
Function ConnectionSettingsToPOPServerVariants()
	
	Position = Find(EmailAddress, "@");
	ServerNameInAccount = Mid(EmailAddress, Position + 1);
	
	Result = New ValueTable;
	Result.Columns.Add("IncomingMailServer");
	Result.Columns.Add("IncomingMailServerPort");
	Result.Columns.Add("UseSecureConnectionForIncomingMail");
	
	// Standard setting appropriate for gmail, yandex and mail mailboxes.ru
	// server name with "pop prefix.", secure connection.
	SettingVariant = Result.Add();
	SettingVariant.IncomingMailServer = "pop." + ServerNameInAccount;
	SettingVariant.IncomingMailServerPort = 995;
	SettingVariant.UseSecureConnectionForIncomingMail = True;
	
	// Server name with "pop3 prefix.", secure connection.
	SettingVariant = Result.Add();
	SettingVariant.IncomingMailServer = "pop3." + ServerNameInAccount;
	SettingVariant.IncomingMailServerPort = 995;
	SettingVariant.UseSecureConnectionForIncomingMail = True;
	
	// Server name with "mail prefix.", secure connection.
	SettingVariant = Result.Add();
	SettingVariant.IncomingMailServer = "mail." + ServerNameInAccount;
	SettingVariant.IncomingMailServerPort = 995;
	SettingVariant.UseSecureConnectionForIncomingMail = True;
	
	// Server name without prefixes, secure connection.
	SettingVariant = Result.Add();
	SettingVariant.IncomingMailServer = ServerNameInAccount;
	SettingVariant.IncomingMailServerPort = 995;
	SettingVariant.UseSecureConnectionForIncomingMail = True;
	
	// Server name with "pop prefix.", nonsecure connection.
	SettingVariant = Result.Add();
	SettingVariant.IncomingMailServer = "pop." + ServerNameInAccount;
	SettingVariant.IncomingMailServerPort = 110;
	SettingVariant.UseSecureConnectionForIncomingMail = False;
	
	// Server name with prefix, nonsecure connection.
	SettingVariant = Result.Add();
	SettingVariant.IncomingMailServer = "pop3." + ServerNameInAccount;
	SettingVariant.IncomingMailServerPort = 110;
	SettingVariant.UseSecureConnectionForIncomingMail = False;
	
	// Server name with "mail prefix.", nonsecure connection.
	SettingVariant = Result.Add();
	SettingVariant.IncomingMailServer = "mail." + ServerNameInAccount;
	SettingVariant.IncomingMailServerPort = 110;
	SettingVariant.UseSecureConnectionForIncomingMail = False;
	
	// Server name without prefixes, nonsecure connection.
	SettingVariant = Result.Add();
	SettingVariant.IncomingMailServer = ServerNameInAccount;
	SettingVariant.IncomingMailServerPort = 110;
	SettingVariant.UseSecureConnectionForIncomingMail = False;
	
	Return Result;
	
EndFunction

&AtServer
Function ConnectionSettingsToSMTPServerVariants()
	
	Position = Find(EmailAddress, "@");
	ServerNameInAccount = Mid(EmailAddress, Position + 1);
	
	Result = New ValueTable;
	Result.Columns.Add("OutgoingMailServer");
	Result.Columns.Add("OutgoingMailServerPort");
	Result.Columns.Add("UseSecureConnectionForOutgoingMail");
	
	// Standard setting appropriate for gmail, yandex and mail mailboxes.ru
	// server name with "smtp prefix.", secure connection, port 465.
	SettingVariant = Result.Add();
	SettingVariant.OutgoingMailServer = "smtp." + ServerNameInAccount;
	SettingVariant.OutgoingMailServerPort = 465;
	SettingVariant.UseSecureConnectionForOutgoingMail = True;
	
	// Server name with "mail prefix.", secure connection, port 465.
	SettingVariant = Result.Add();
	SettingVariant.OutgoingMailServer = "mail." + ServerNameInAccount;
	SettingVariant.OutgoingMailServerPort = 465;
	SettingVariant.UseSecureConnectionForOutgoingMail = True;
	
	// Server name without prefixes, nonsecure connection, port 465.
	SettingVariant = Result.Add();
	SettingVariant.OutgoingMailServer = ServerNameInAccount;
	SettingVariant.OutgoingMailServerPort = 465;
	SettingVariant.UseSecureConnectionForOutgoingMail = True;
	
	// Server name with "smtp prefix.", secure connection, port 587.
	SettingVariant = Result.Add();
	SettingVariant.OutgoingMailServer = "smtp." + ServerNameInAccount;
	SettingVariant.OutgoingMailServerPort = 587;
	SettingVariant.UseSecureConnectionForOutgoingMail = True;
	
	// Server name with "mail prefix.", secure connection, port 587.
	SettingVariant = Result.Add();
	SettingVariant.OutgoingMailServer = "mail." + ServerNameInAccount;
	SettingVariant.OutgoingMailServerPort = 587;
	SettingVariant.UseSecureConnectionForOutgoingMail = True;
	
	// Server name without prefixes, nonsecure connection, port 587.
	SettingVariant = Result.Add();
	SettingVariant.OutgoingMailServer = ServerNameInAccount;
	SettingVariant.OutgoingMailServerPort = 587;
	SettingVariant.UseSecureConnectionForOutgoingMail = True;
	
	// Server name with "smtp prefix.", nonsecure connection.
	SettingVariant = Result.Add();
	SettingVariant.OutgoingMailServer = "smtp." + ServerNameInAccount;
	SettingVariant.OutgoingMailServerPort = 25;
	SettingVariant.UseSecureConnectionForOutgoingMail = False;
	
	// Server name with "mail prefix.", nonsecure connection.
	SettingVariant = Result.Add();
	SettingVariant.OutgoingMailServer = "mail." + ServerNameInAccount;
	SettingVariant.OutgoingMailServerPort = 25;
	SettingVariant.UseSecureConnectionForOutgoingMail = False;
	
	// Server name without prefixes, nonsecure connection.
	SettingVariant = Result.Add();
	SettingVariant.OutgoingMailServer = ServerNameInAccount;
	SettingVariant.OutgoingMailServerPort = 25;
	SettingVariant.UseSecureConnectionForOutgoingMail = False;
	
	Return Result;
	
EndFunction

&AtServer
Function PickAccountSettings()
	
	IncomingMailServerSettingsFound = False;
	OutgoingMailServerSettingsFound = False;
	
	FillPropertyValues(ThisObject, DefaultSettings(EmailAddress, PasswordForReceivingEmails));
	
	If UseForReceiving Then
		ConnectionCompleted = False;
		AuthenticationError = False;
		ConnectionSettingsVariant = Undefined;
		
		// Search IMAP settings
		Protocol = "IMAP";
		For Each UserName IN UserNameVariants() Do
			UserNameForReceivingEmails = UserName;
			If AuthenticationError Then
				ErrorInfo = CheckConnectionToIncomingMailServer();
				ConnectionCompleted = IsBlankString(ErrorInfo);
			Else
				For Each ConnectionSettingsVariant IN ConnectionSettingsToIMAPServerVariants() Do
					FillPropertyValues(ThisObject, ConnectionSettingsVariant);
					ErrorInfo = CheckConnectionToIncomingMailServer();
					ConnectionCompleted = IsBlankString(ErrorInfo);
					AuthenticationError = Find(ErrorInfo, "authenticat") > 0;
					If ConnectionCompleted Or AuthenticationError Then
						Break;
					EndIf;
				EndDo;
			EndIf;
			If ConnectionCompleted Or Not AuthenticationError Then
				Break;
			EndIf;
		EndDo;
		
		IncomingMailServerSettingsFound = ConnectionCompleted;
		
		If Not IncomingMailServerSettingsFound Then
			// Search POP settings
			ConnectionCompleted = False;
			AuthenticationError = False;
			ConnectionSettingsVariant = Undefined;
			
			Protocol = "POP";
			For Each UserName IN UserNameVariants() Do
				UserNameForReceivingEmails = UserName;
				If AuthenticationError Then
					ErrorInfo = CheckConnectionToIncomingMailServer();
					ConnectionCompleted = IsBlankString(ErrorInfo);
				Else
					For Each ConnectionSettingsVariant IN ConnectionSettingsToPOPServerVariants() Do
						FillPropertyValues(ThisObject, ConnectionSettingsVariant);
						ErrorInfo = CheckConnectionToIncomingMailServer();
						ConnectionCompleted = IsBlankString(ErrorInfo);
						AuthenticationError = Find(ErrorInfo, "authenticat") > 0;
						If ConnectionCompleted Or AuthenticationError Then
							Break;
						EndIf;
					EndDo;
				EndIf;
				If ConnectionCompleted Or Not AuthenticationError Then
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	If UseForSending Then
		// Search SMTP settings
		ConnectionCompleted = False;
		AuthenticationError = False;
		ConnectionSettingsVariant = Undefined;
		
		For Each UserName IN UserNameVariants() Do
			UserNameForSendingEmails = UserName;
			If AuthenticationError Then
				ErrorInfo = CheckConnectionToOutgoingMailServer();
				ConnectionCompleted = IsBlankString(ErrorInfo);
			Else
				For Each ConnectionSettingsVariant IN ConnectionSettingsToSMTPServerVariants() Do
					FillPropertyValues(ThisObject, ConnectionSettingsVariant);
					ErrorInfo = CheckConnectionToOutgoingMailServer();
					ConnectionCompleted = IsBlankString(ErrorInfo);
					AuthenticationError = Find(ErrorInfo, "authenticat") > 0;
					If ConnectionCompleted Or AuthenticationError Then
						Break;
					EndIf;
				EndDo;
			EndIf;
			If ConnectionCompleted Or Not AuthenticationError Then
				Break;
			EndIf;
		EndDo;
		
		OutgoingMailServerSettingsFound = ConnectionCompleted;
	EndIf;
	
	Return (NOT UseForSending Or OutgoingMailServerSettingsFound)
		AND (NOT UseForReceiving Or IncomingMailServerSettingsFound);
	
EndFunction

&AtClient
Procedure ConfigureConnectionParametersAutomatically()
	PickSettingsAndCreateAccount();
	
	If ValueIsFilled(UserAccountRefs) Then 
		NotifyChanged(TypeOf(UserAccountRefs));
	EndIf;
	
	GoToNextPage();
EndProcedure

&AtServer
Procedure PickSettingsAndCreateAccount()
	CheckingCompletedWithErrors = Not PickAccountSettings();
	If Not CheckingCompletedWithErrors Then
		CreateAccount();
	Else
		ErrorMessages = NStr("en='Unable to determine connection settings. 
		|Set connection parameters manually.';ru='Не удалось определить настройки подключения. 
		|Настройте параметры подключения вручную.'");
			
		// Settings by default.
		FillPropertyValues(ThisObject, DefaultSettings(EmailAddress, PasswordForReceivingEmails));
	EndIf;
EndProcedure

#EndRegion
