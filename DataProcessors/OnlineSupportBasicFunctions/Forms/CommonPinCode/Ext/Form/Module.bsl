﻿
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
	
	UserTitle = NStr("en = 'Login:'") + " " + Parameters.login;
	
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
		Message.Text = NStr("en = 'Registration Number field is not filled'");
		Message.Field  = "RegistrationNumberPinCode";
		Message.Message();
		
		Result = False;
		
	EndIf;
	
	If IsBlankString(PinCode) Then
		
		Message = New UserMessage;
		Message.Text = NStr("en = 'Pin-code field is not filled.'");
		Message.Field  = "PinCode";
		Message.Message();
		
		Result = False;
		
	EndIf;
	
	PinCodePage = StrReplace(StrReplace(PinCode, "-", ""), " ", "");
	If StrLen(PinCodePage) <> 16 Then
		
		Message = New UserMessage;
		Message.Text = NStr("en = 'PIN shall consist of 16 digits.'");
		Message.Field  = "PinCode";
		Message.Message();
		
		Result = False;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Function MessageParametersToTechicalSupport()
	
	Result = New Structure;
	Result.Insert("Subject", NStr("en = 'Online support. Product registration.'"));
	
	UserLogin = OnlineUserSupportClientServer.SessionParameterValue(
		InteractionContext.COPContext,
		"login");
	
	MessageText = NStr("en = 'Hello!
  |I can not register the software product
  |to connect to the online support. Please help to solve this issue.
  |
  |Login: %1.
  |Registration number: %2.
  |PIN: %3.
  |
  |%TechnicalParameters%
  |-----------------------------------------------
  |Best regards, .'");
	
	MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
		MessageText,
		UserLogin,
		RegistrationNumberPinCode,
		PinCode);
	
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
