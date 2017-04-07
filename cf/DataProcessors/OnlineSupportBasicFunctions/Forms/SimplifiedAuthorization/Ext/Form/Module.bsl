
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ThisDataProcessor = DataProcessorObject();
	
	LaunchLocation = Parameters.LaunchLocation;
	
	// Form filling with required parameters.
	FillForm();
	
	// If login and password are empty, user name and
	// password filling are overridden by default.
	If IsBlankString(Login) Then
		UserData = OnlineUserSupportClientServer.NewOnlineSupportUserData();
		OnlineUserSupportOverridable.OnDefineOnlineSupportUserData(
			UserData);
		If TypeOf(UserData) = Type("Structure") Then
			If UserData.Property("Login") Then
				Login = UserData.Login;
				If UserData.Property("Password") Then
					Password = UserData.Password;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
		Items.HeaderExplanationGroupAuthorization.Representation = UsualGroupRepresentation.None;
		Items.AuthorizationContentFillGroup.Representation = UsualGroupRepresentation.None;
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
Procedure SiteUsersConnectionAuthorizationClick(Item)
	
	PageAddress = "https://1c-dn.com/user/profile/";
	PageTitle = NStr("en='Support of 1C:Enterprise 8 system users';ru='Поддержка пользователей системы 1С:Предприятие 8'");
	OnlineUserSupportClient.OpenInternetPage(
		PageAddress,
		PageTitle);
	
EndProcedure

&AtClient
Procedure PasswordRecoveryLabelAuthorizationClick(Item)
	
	QueryParameters = New Array;
	QueryParameters.Add(New Structure("Name, Value", "remindPassword", "true"));
	
	OnlineUserSupportClient.ServiceCommandsDataProcessor(InteractionContext, ThisObject, QueryParameters);
	
EndProcedure

&AtClient
Procedure HeaderExplanationAuthorizationNavigationRefProcessing(Item, URL, StandardProcessing)
	
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
Procedure LoginAuthorization(Command)
	
	If Not FieldsAreFilledCorrectly() Then
		Return;
	EndIf;
	
	OnlineUserSupportClientServer.WriteContextParameter(
		InteractionContext.COPContext,
		"login",
		Login);
	OnlineUserSupportClientServer.WriteContextParameter(
		InteractionContext.COPContext,
		"password",
		Password);
	OnlineUserSupportClientServer.WriteContextParameter(
		InteractionContext.COPContext,
		"savePassword",
		?(StorePassword, "true", "false"));
	
	// User login and password saving, in
	// case of successful authorizaion
	// they are transferred to UserInternetSupportOverridden method. AtUserAuthorizationInInternetSupport()
	
	InteractionContext.COPContext.Login  = Login;
	
	QueryParameters = New Array;
	QueryParameters.Add(New Structure("Name, Value", "login", Login));
	QueryParameters.Add(New Structure("Name, Value", "password", Password));
	QueryParameters.Add(New Structure("Name, Value", "savePassword", ?(StorePassword, "true", "false")));
	
	OnlineUserSupportClient.ServiceCommandsDataProcessor(InteractionContext, ThisObject, QueryParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns the value of the external handling.
//
// Return value: object of ExternalProcessor type - External handling.
//
&AtServer
Function DataProcessorObject()
	
	Return FormAttributeToValue("Object");
	
EndFunction

// Performs initial filling of form fields
&AtServer
Procedure FillForm()
	
	UserTitle = NStr("en='Login:';ru='Авторизоваться:'") + " " + Parameters.login;
	
	Login  = Parameters.login;
	Password = Parameters.password;
	
	StorePassword = (Parameters.savePassword <> "false");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Field filling check.

// Checks Username and Password fields filling
//
// Return value: Boolean. True - Fields are
// 	filled Inorrectly, False - otherwise.
//
&AtClient
Function FieldsAreFilledCorrectly()
	
	If IsBlankString(Login) Then
		
		Message = New UserMessage;
		Message.Text = NStr("en='Login field is not filled';ru='Не заполнено поле ""Логин""'");
		Message.Field  = "Login";
		Message.Message();
		Return False;
		
	EndIf;
	
	If IsBlankString(Password) Then
		
		Message = New UserMessage;
		Message.Text = NStr("en='Password field is not filled';ru='Не заполнено поле ""Пароль""'");
		Message.Field  = "Password";
		Message.Message();
		
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

&AtClient
Function MessageParametersToTechicalSupport()
	
	Result = New Structure;
	Result.Insert("Subject", NStr("en='Online support. Authorization.';ru='Интернет-поддержка. Авторизация.'"));
	
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en=""Hello! I can't authorize and connect Online support. My login and password are entered correctly. Please, help me to solve the problem. Login: %1. %TechnicalParameters% ----------------------------------------------- Yours sincerely, ."";ru='Здравствуйте! У меня не получается пройти авторизацию и подключить Интернет-поддержку. Логин и пароль мной введены правильно. Прошу помочь разобраться с проблемой. Логин: %1. %ТехническиеПараметры% ----------------------------------------------- С уважени'"),
		Login);
	
	Result.Insert("MessageText", MessageText);
	
	Return Result;
	
EndFunction

#EndRegion
