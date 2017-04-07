
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	LaunchLocation = Parameters.LaunchLocation;
	
	// Form filling with required parameters.
	FillForm();
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
		Items.HeaderGroupRegNumbers.Representation = UsualGroupRepresentation.None;
		Items.ContentGroupRegNumber.Representation = UsualGroupRepresentation.None;
	EndIf;
	
	DoNotRemindAboutAuthorizationBeforeDate = OnlineUserSupportServerCall.SettingValueDoNotRemindAboutAuthorizationBefore();
	If DoNotRemindAboutAuthorizationBeforeDate <> '00010101'
		AND CurrentSessionDate() > DoNotRemindAboutAuthorizationBeforeDate Then
			OnlineUserSupportServerCall.CustomizeSettingDoNotRemindAboutAuthorizationBefore(False);
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
Procedure UserLogoutLabelRegNumberClick(Item)
	
	OnlineUserSupportClient.HandleUserExit(InteractionContext, ThisObject);
	
EndProcedure

&AtClient
Procedure RegisteredProductsListRegNumberClick(Item)
	
	RefAddress       = "https://1c-dn.com/user/updates/registration/";
	AddressSupplement = OnlineUserSupportClientServer.SessionParameterValue(
		InteractionContext.COPContext,
		"authUrlPassword");
	AddressSupplement = String(AddressSupplement);
	RefAddress       = AddressSupplement + RefAddress;
	
	PageTitle = NStr("en='List of registered products';ru='Список зарегистрированных продуктов'");
	OnlineUserSupportClient.OpenInternetPage(
		RefAddress,
		PageTitle);
	
EndProcedure

&AtClient
Procedure RegisterProductRegNumberClick(Item)
	
	QueryParameters = New Array;
	QueryParameters.Add(New Structure("Name, Value", "registerProduct", "true"));
	
	OnlineUserSupportClient.ServiceCommandsDataProcessor(InteractionContext, ThisObject, QueryParameters);
	
EndProcedure

&AtClient
Procedure HeaderExplanationRegNumberNavigationRefProcessing(Item, URL, StandardProcessing)
	
	If URL = "TechSupport" Then
		
		StandardProcessing = False;
		OnlineUserSupportClient.OpenDialogForSendingEmail(
			InteractionContext,
			MessageParametersToTechicalSupport());
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DoNotRemindAboutAuthorizationBefore1OnChange(Item)
	
	CustomizeSettingDoNotRemindAboutAuthorizationBeforeServer(DoNotRemindAboutAuthorizationBefore);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OKRegNumber(Command)
	
	If Not FieldsAreFilledCorrectly() Then
		Return;
	EndIf;
	
	OnlineUserSupportClientServer.WriteContextParameter(
		InteractionContext.COPContext,
		"regnumber",
		RegistrationNumberRegNumber);
	
	QueryParameters = New Array;
	QueryParameters.Add(New Structure("Name, Value", "regnumber", RegistrationNumberRegNumber));
	
	OnlineUserSupportClient.ServiceCommandsDataProcessor(InteractionContext, ThisObject, QueryParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Performs initial filling of the form fields
&AtServer
Procedure FillForm()
	
	If Parameters.OnStart Then
		ShowSettingDateDoNotRemindAboutAuthorizationBefore();
	Else
		Items.DoNotRemindAboutAuthorizationBefore.Visible = False;
	EndIf;
	
	UserTitle = NStr("en='Login:';ru='Авторизоваться:'") + " " + Parameters.login;
	
	Items.UserLoginLabelRegNumber.Title = UserTitle;
	RegistrationNumberRegNumber = Parameters.regNumber;
	
	StorePassword = True;
	
EndProcedure

&AtServer
Procedure ShowSettingDateDoNotRemindAboutAuthorizationBefore()
	
	CommonCheckBoxTitle = NStr("en='Do not remind of the connection for seven days';ru='Не напоминать о подключении семь дней'");
	
	SettingValue = OnlineUserSupportServerCall.SettingValueDoNotRemindAboutAuthorizationBefore();
	DoNotRemindAboutAuthorizationBefore = ?(SettingValue = '00010101', False, True);
	
	CheckBoxLine = CommonCheckBoxTitle
		+ ?(SettingValue = '00010101',
			"",
			" " + NStr("en='(to';ru='(o'") + " " + Format(SettingValue, "DF=dd.MM.yyyy") + ")");
	
	Items.DoNotRemindAboutAuthorizationBefore.Title = CheckBoxLine;
	
EndProcedure

&AtServer
Procedure CustomizeSettingDoNotRemindAboutAuthorizationBeforeServer(Value)
	
	OnlineUserSupportServerCall.CustomizeSettingDoNotRemindAboutAuthorizationBefore(Value);
	ShowSettingDateDoNotRemindAboutAuthorizationBefore();
	
EndProcedure

&AtClient
Function FieldsAreFilledCorrectly()
	
	Result = True;
	
	If IsBlankString(RegistrationNumberRegNumber) Then
		
		Message = New UserMessage;
		Message.Text = NStr("en='Registration Number field is not filled';ru='Не заполнено поле ""Регистрационный номер""'");
		Message.Field  = "RegistrationNumberRegNumber";
		Message.Message();
		
		Result = False;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Function MessageParametersToTechicalSupport()
	
	Result = New Structure;
	Result.Insert("Subject", NStr("en='Online support. Registration number entry.';ru='Интернет-поддержка. Ввод регистрационного номера.'"));
	
	MessageText = NStr("en='Hello!
		|I can not enter registration number for the software product
		|to connect to Online Support.
		|Please help me to solve this issue.
		|
		|Login: %1.
		|Registration number: %2.
		|%TechnicalParameters%
		|-----------------------------------------------
		|Kind Regards, .';ru='Здравствуйте!
		|У меня не получается ввести регистрационный номер программного продукта
		|для подключения Интернет-поддержки.
		|Прошу помочь разобраться с проблемой.
		|
		|Логин: %1.
		|Регистрационный номер: %2.
		|
		|%ТехническиеПараметры%
		|-----------------------------------------------
		|С уважением, .'");
	
	UserLogin = OnlineUserSupportClientServer.SessionParameterValue(
		InteractionContext.COPContext,
		"login");
	
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		MessageText,
		UserLogin,
		RegistrationNumberRegNumber);
	
	Result.Insert("MessageText", MessageText);
	
	Return Result;
	
EndFunction

#EndRegion
