
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Form filling with required parameters.
	FillForm();
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
		Items.HeaderExplanationGroupPinCode.Representation = UsualGroupRepresentation.None;
		Items.ContentFillGroupPinCode.Representation = UsualGroupRepresentation.None;
		Items.ContentPictureGroupPinCode.Representation   = UsualGroupRepresentation.None;
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
Procedure UserLogoutLabelPinCodeClick(Item)
	
	OnlineUserSupportClient.HandleUserExit(InteractionContext, ThisObject);
	
EndProcedure

&AtClient
Procedure HeaderExplanationPinCodeNavigationRefProcessing(Item, URL, StandardProcessing)
	
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
Procedure Back(Command)
	
	QueryParameters = New Array;
	QueryParameters.Add(New Structure("Name, Value", "backRegistration", "true"));
	
	OnlineUserSupportClient.ServiceCommandsDataProcessor(InteractionContext, ThisObject, QueryParameters);
	
EndProcedure

&AtClient
Procedure OKPinCode(Command)
	
	If Not FieldsAreFilledCorrectly() Then
		Return;
	EndIf;
	
	QueryParameters = New Array;
	QueryParameters.Add(New Structure("Name, Value", "regnumber", RegistrationNumberPinCode));
	QueryParameters.Add(New Structure("Name, Value", "pincode", StrReplace(PinCode, "-", "")));
	
	OnlineUserSupportClient.ServiceCommandsDataProcessor(InteractionContext, ThisObject, QueryParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Performs initial filling of the form fields
&AtServer
Procedure FillForm()
	
	UserTitle = NStr("en='Authorize:';ru='Авторизоваться:'") + " " + Parameters.login;
	
	Items.UserLoginLabelPinCode.Title = UserTitle;
	RegistrationNumberPinCode = Parameters.regNumber;
	PinCode                     = Parameters.pincode;
	
EndProcedure

// Checks filling of RegNumber and PINCode fields.
//
// Return value: Boolean. True - Fields are
// 	filled Incorrectly, False - otherwise.
//
&AtClient
Function FieldsAreFilledCorrectly()
	
	Result = True;
	
	If IsBlankString(RegistrationNumberPinCode) Then
		
		Message = New UserMessage;
		Message.Text = NStr("en='Registration number is not filled in';ru='Не заполнено поле ""Регистрационный номер""'");
		Message.Field  = "RegistrationNumberPinCode";
		Message.Message();
		
		Result = False;
		
	EndIf;
	
	If IsBlankString(PinCode) Then
		
		Message = New UserMessage;
		Message.Text = NStr("en='PIN code is not filled in';ru='Не заполнено поле ""Пинкод""'");
		Message.Field  = "PinCode";
		Message.Message();
		
		Result = False;
		
	EndIf;
	
	PinCodePage = StrReplace(StrReplace(PinCode, "-", ""), " ", "");
	If StrLen(PinCodePage) <> 16 Then
		
		Message = New UserMessage;
		Message.Text = NStr("en='PIN code should contain 16 digits.';ru='Пин-код должен состоять из 16 цифр.'");
		Message.Field  = "PinCode";
		Message.Message();
		
		Result = False;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Function MessageParametersToTechicalSupport()
	
	Result = New Structure;
	Result.Insert("Subject", NStr("en='Online support. Product registration.';ru='Интернет-поддержка. Регистрация продукта.'"));
	
	UserLogin = OnlineUserSupportClientServer.SessionParameterValue(
		InteractionContext.COPContext,
		"login");
	
	MessageText = NStr("en='Hello!
		|I can not register the software product
		|to connect to the online support. Please help to solve this issue.
		|
		|Login: %1.
		|Registration number: %2.
		|PIN: %3.
		|
		|%TechnicalParameters%
		|-----------------------------------------------
		|Best regards, .';ru='Здравствуйте!
		|У меня не получается зарегистрировать программный продукт
		|для подключения Интернет-поддержки. Прошу помочь разобраться с проблемой.
		|
		|Логин: %1.
		|Регистрационный номер: %2.
		|Пинкод: %3.
		|
		|%ТехническиеПараметры%
		|-----------------------------------------------
		|С уважением, .'");
	
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		MessageText,
		UserLogin,
		RegistrationNumberPinCode,
		PinCode);
	
	Result.Insert("MessageText", MessageText);
	
	Return Result;
	
EndFunction

#EndRegion
