
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Login            = Parameters.login;
	Email = Parameters.email;
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
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
Procedure HeaderExplanationNavigationRefProcessing(Item, URL, StandardProcessing)
	
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
Procedure RestorePassword(Command)
	
	If Not FieldsAreFilledCorrectly() Then
		Return;
	EndIf;
	
	OnlineUserSupportClientServer.WriteContextParameter(
		InteractionContext.COPContext,
		"login",
		Login);
	OnlineUserSupportClientServer.WriteContextParameter(
		InteractionContext.COPContext,
		"email",
		Email);
	
	QueryParameters = New Array;
	QueryParameters.Add(New Structure("Name, Value", "login", Login));
	QueryParameters.Add(New Structure("Name, Value", "email", Email));
	
	OnlineUserSupportClient.ServiceCommandsDataProcessor(InteractionContext, ThisObject, QueryParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Checks the correctness of the form field filling.
//
// Return value: Boolean - True if fields are filled Inorrectly,
// 	 False - otherwise.
//
&AtClient
Function FieldsAreFilledCorrectly()
	
	If IsBlankString(Login) Then
		
		ShowMessageBox(, NStr("en='Please enter login.';ru='Пожалуйста, введите логин.'"), , NStr("en='Filling error';ru='Ошибка заполнения'"));
		Return False;
		
	EndIf;
	
	If IsBlankString(Email) Then
		
		ShowMessageBox(, NStr("en='Please enter email.';ru='Пожалуйста, введите e-mail.'"), , NStr("en='Filling error';ru='Ошибка заполнения'"));
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

&AtClient
Function MessageParametersToTechicalSupport()
	
	Result = New Structure;
	Result.Insert("Subject"       , NStr("en='Online support. Password recovery.';ru='Интернет-поддержка. Восстановление пароля.'"));
	Result.Insert("FromWhom"     , Email);
	
	MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en=""Dear Sir! I can't recover my password to connect InternetSupport. Please help me to solve the problem. Login: %1. Email: %2. %TechnicalParameters% ----------------------------------------------- Yours sincerely, ."";ru='Здравствуйте!
		|У меня не получается восстановить свой пароль для подключения
		|Интернет-поддержки.
		|Прошу помочь разобраться с проблемой.
		|
		|Логин: %1.
		|E-mail: %2.
		|
		|%ТехническиеПараметры%
		|-----------------------------------------------
		|С уважением, .'"),
		Login,
		Email);
	
	Result.Insert("MessageText", MessageText);
	
	Return Result;
	
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
