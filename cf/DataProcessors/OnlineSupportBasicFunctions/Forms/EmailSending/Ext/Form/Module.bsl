
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Create email document depending on the transferred parameters
	WriteEmail(Parameters);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OnlineUserSupportClient.HandleFormOpening(InteractionContext, ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Send(Command)
	
	// Check field filling
	If IsBlankString(Email) Then
		UserMessage = New UserMessage;
		UserMessage.Text = NStr("en='""Email for feedback"" field is not filled.';ru='Поле ""E-mail для обратной связи"" не заполнено.'");
		UserMessage.Field  = "Email";
		UserMessage.Message();
		Return;
	EndIf;
	
	If IsBlankString(Subject) Then
		UserMessage = New UserMessage;
		UserMessage.Text = NStr("en='""Email Subject"" field is not filled.';ru='Поле ""Тема сообщения"" не заполнено.'");
		UserMessage.Field  = "Subject";
		UserMessage.Message();
		Return;
	EndIf;
	
	If IsBlankString(Message) Then
		UserMessage = New UserMessage;
		UserMessage.Text = NStr("en='Letter text is not entered.';ru='Не заполнен тест письма.'");
		UserMessage.Field  = "Message";
		UserMessage.Message();
		Return;
	EndIf;
	
	EmailParameters = New Structure("FromWhom, Subject, Message", Email, Subject, Message);
	If Not IsBlankString(ConditionalRecipientName) Then
		EmailParameters.Insert("ConditionalRecipientName", ConditionalRecipientName);
	EndIf;
	
	Status(NStr("en='sending';ru='Отправка'")
		,
		,
		NStr("en='Email sending to technical support.';ru='Выполняется отправка электронного письма в службу тех. поддержки.'"),
		PictureLib.OnlineUserSupportSendingLetter);
	
	SendingResult = OnlineUserSupportClient.SendEmailToSupportService(
		EmailParameters,
		InteractionContext);
	
	Status();
	
	If Not SendingResult Then
		ShowMessageBox(,
			NStr("en='An error occurred while sending email.
		|For more details see the event log.';ru='При отправке письма произошла ошибка.
		|Подробнее см. в журнале регистрации.'"));
	Else
		Close();
		ShowMessageBox(, NStr("en='Message is sent successfully.';ru='Сообщение успешно отправлено.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Fills in email template depending on the parameters value.
//
// Parameters:
// - Parameters (FormDataStructure, Structure) - Parameters of template creation.
//
&AtServer
Procedure WriteEmail(Parameters)
	
	Subject = Parameters.Subject;
	
	Message = StrReplace(
		Parameters.MessageText,
		"%TechnicalParameters%",
		TechnicalParametersText(Parameters.OnStart));
	
	If IsBlankString(Parameters.Whom) Then
		EMailForSending = "webits-info@1c.ru";
	Else
		EMailForSending = Parameters.Whom;
	EndIf;
	
	Items.TitleExplanation.Title = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Email will be send to user technical support to the address %1';ru='Письмо будет отправлено в техподдержку пользователей на адрес %1'"),
		EMailForSending);
	
	If Not IsBlankString(Parameters.FromWhom) Then
		Email = Parameters.FromWhom;
	EndIf;
	
	ConditionalRecipientName = Parameters.ConditionalRecipientName;
	
	If IsBlankString(Subject) Then
		Subject = NStr("en='<Enter email subject>';ru='<Укажите тему сообщения>'");
	EndIf;
	
	If IsBlankString(Message) Then
		Message = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='<Enter email content>,
		|
		|Login: %1
		|Kind Regards, .';ru='<Заполните
		|
		|содержимое письма>,
		|Логин: %1 С уважением, .'"),
			Parameters.Login);
	EndIf;
	
EndProcedure

// Creates template for the text of technical parameters.
//
// Return value - String - template of technical parameters.
//
&AtServer
Function TechnicalParametersText(OnStart)
	
	SysInfo = New SystemInfo;
	
	If OnStart Then
		CallServicePosition = NStr("en='automatic';ru='автоматический'");
	Else
		CallServicePosition = NStr("en='manual';ru='руководство'");
	EndIf;
	
	TechnicalParameters = NStr("en='Technical parameters of connection:
		|(needed to simulate the described issue) 
		|
		|- configuration name: %1,
		|- configuration version: %2,
		|- platform version: %3,
		|- online support library version: %4,
		|- user language: %5,
		|- application kind: managed,
		|- service call: %6.';ru='Технические параметры подключения:
		|(нужны для воспроизведения описанной проблемы)
		|
		|- имя конфигурации: %1,
		|- номер версии конфигурации: %2,
		|- номер версии платформы: %3,
		|- версия библиотеки Интернет-поддержки: %4,
		|- язык пользователя: %5,
		|- вид приложения: управляемый,
		|- вызов сервиса: %6.'")
		+ Chars.LF;
	
	TechnicalParameters = StringFunctionsClientServer.PlaceParametersIntoString(
		TechnicalParameters,
		String(OnlineUserSupportClientServer.ConfigurationName()),
		String(OnlineUserSupportClientServer.ConfigurationVersion()),
		String(SysInfo.AppVersion),
		OnlineUserSupportClientServer.LibraryVersion(),
		CurrentLocaleCode(),
		CallServicePosition);
	
	Return TechnicalParameters;
	
EndFunction

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
