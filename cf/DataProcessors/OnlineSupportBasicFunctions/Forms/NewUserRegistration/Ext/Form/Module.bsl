
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
		Items.DecorationHeaderName.Width = 8;
		Items.DecorationHeaderCity.Width = 8;
		Items.GroupHeaderExplanations.Representation = UsualGroupRepresentation.None;
		Items.GroupContent.Representation = UsualGroupRepresentation.None;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OnlineUserSupportClient.HandleFormOpening(InteractionContext, ThisObject);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If Not SoftwareClosing Then
		OnlineUserSupportClient.EndBusinessProcess(InteractionContext);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure LoginOnChange(Item)
	
	Login = TrimAll(Login);
	
EndProcedure

&AtClient
Procedure EmailOnChange(Item)
	
	Email = TrimAll(Email);
	
EndProcedure

&AtClient
Procedure HeaderExplanationTwoNavigationRefProcessing(Item, URL, StandardProcessing)
	
	If URL = "TechSupport" Then
		
		StandardProcessing = False;
		OnlineUserSupportClient.OpenDialogForSendingEmail(
			InteractionContext,
			MessageParametersToTechicalSupport());
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RegisterAndLogin(Command)
	
	If Not FieldsAreFilledCorrectly() Then
		Return;
	EndIf;
	
	QueryParameters = New Array;
	QueryParameters.Add(New Structure("Name, Value", "login"      , Login));
	QueryParameters.Add(New Structure("Name, Value", "password"   , Password));
	QueryParameters.Add(New Structure("Name, Value", "email"      , Email));
	QueryParameters.Add(New Structure("Name, Value", "SecondName" , Surname));
	QueryParameters.Add(New Structure("Name, Value", "FirstName"  , Name));
	QueryParameters.Add(New Structure("Name, Value", "MiddleName" , Patronymic));
	QueryParameters.Add(New Structure("Name, Value", "City"       , City));
	QueryParameters.Add(New Structure("Name, Value", "PhoneNumber", Phone));
	QueryParameters.Add(New Structure("Name, Value", "workPlace"  , Workplace));
	
	OnlineUserSupportClient.ServiceCommandsDataProcessor(InteractionContext, ThisObject, QueryParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure MessageToUser(MessageText, FieldName, Cancel)
	
	Cancel = True;
	Message = New UserMessage;
	Message.Text = MessageText;
	Message.Field  = FieldName;
	Message.Message();
	
EndProcedure

// Checks form fields filling
//
// Return value: Boolean. True - Fields are
// 	filled Incorrectly, False - otherwise.
//
&AtClient
Function FieldsAreFilledCorrectly()
	
	Cancel = False;
	
	If IsBlankString(Login) Then
		MessageToUser(
			NStr("en='Field ""login"" not filled.';ru='Поле ""Логин"" не заполнено.'"),
			"Login",
			Cancel);
	EndIf;
	
	If IsBlankString(Password) Then
		MessageToUser(
			NStr("en='Password field is not filled.';ru='Поле ""Пароль"" не заполнено.'"),
			"Password",
			Cancel);
	ElsIf Password <> PasswordConfirmation Then
		MessageToUser(
			NStr("en='Password and the confirmation do not match.';ru='Не совпадают пароль и его подтверждение.'"),
			"PasswordConfirmation",
			Cancel);
	EndIf;
	
	If IsBlankString(Email) Then
		MessageToUser(
			NStr("en='Email field is not filled.';ru='Поле ""E-mail"" не заполнено.'"),
			"Email",
			Cancel);
	EndIf;
	
	Return (NOT Cancel);
	
EndFunction

&AtClient
Function MessageParametersToTechicalSupport()
	
	Result = New Structure;
	Result.Insert("Subject"  , NStr("en='Online support. Registration of a new user';ru='Интернет-поддержка. Регистрация нового пользователя.'"));
	Result.Insert("FromWhom", Email);
	
	MessageText = NStr("en='Dear Sir or Madam, I can not register a new user to connect Internet Support. Please help me to solve the issue. Login: %1 Email: %2 Last name: %3 Name: %4 Patronymic: %5 City: %6 Phone: %7 Place of employment: %8. %TechnicalParameters% ----------------------------------------------- Best regards, .';ru='Здравствуйте! У меня не получается зарегистрировать нового пользователя для подключения Интернет-поддержки. Прошу помочь разобраться с проблемой. Логин: %1 E-mail: %2 Фамилия: %3 Имя: %4 Отчество: %5 Город: %6 Телефон: %7 Место работы: %8. %ТехническиеПараметры% ----------------------------------------------- С уважением, .'");
	
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		MessageText,
		Login,
		Email,
		Surname,
		Name,
		Patronymic,
		City,
		Phone,
		Workplace);
	
	Result.Insert("MessageText", MessageText);
	
	Return Result;
	
EndFunction

#EndRegion














