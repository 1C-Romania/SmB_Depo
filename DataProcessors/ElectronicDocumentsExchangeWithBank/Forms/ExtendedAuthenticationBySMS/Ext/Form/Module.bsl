&AtClient
Var ExternalAttachableModule;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	BankApplication = CommonUse.ObjectAttributeValue(Parameters.EDAgreement, "BankApplication");
	
	If BankApplication = Enums.BankApplications.AsynchronousExchange Then
		If Not ValueIsFilled(Parameters.Phone) Then
			Items.Phone.Visible = False;
		EndIf;
		Phone = Parameters.Phone;
		SessionID = Parameters.SessionID;
	Else
		Items.Phone.Visible = False;
	EndIf
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor")
		OR BankApplication = PredefinedValue("Enum.BankApplications.iBank2") Then
		
		SendSMS();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Done(Command)
	
	If IsBlankString(Password) Then
		MessageText = NStr("en='Enter one-time password to continue.';ru='Для продолжения укажите одноразовый пароль.'");
		CommonUseClientServer.MessageToUser(MessageText, , "Password");
		Return;
	EndIf;
	
	If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor")
		OR BankApplication = PredefinedValue("Enum.BankApplications.iBank2") Then

		ExtendedAuthenticationData = New Structure("Method, Session, Password");
		ExtendedAuthenticationData.Method = "SMS";
		ExtendedAuthenticationData.Session = Parameters.Session;
		ExtendedAuthenticationData.Password = Password;

		Try
			If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
				ExternalAttachableModule.ExtendedAuthentication(Parameters.Certificate, ExtendedAuthenticationData);
			Else
				ExtendedXMLAuthenticationData = ElectronicDocumentsServiceClient.SerializedData(ExtendedAuthenticationData);
				ExternalAttachableModule.ExtendedAuthentication(ExtendedXMLAuthenticationData);
			EndIf;
			Close(True);
		Except
			ErrorTemplate = NStr("en='SMS authentication error."
"Error code:"
"%1 %2';ru='Ошибка SMS аутентификации."
"Код"
"ошибки: %1 %2'");
			If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
				ErrorDetails = ExternalAttachableModule.ErrorDetails();
			Else
				ErrorDetails = ElectronicDocumentsServiceClient.InformationAboutErroriBank2();
			EndIf;
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
								ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
			Operation = NStr("en='SMS authentication';ru='SMS аутентификация'");
			DetailErrorDescription = DetailErrorDescription(ErrorInfo());
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
								Operation, DetailErrorDescription, MessageText, 1);
			Items.FormButtonDone.Enabled = False;
		EndTry;
		
	Else
		
		Close(Password);
		
	EndIf;

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SendSMS()
	
	SessionID = Parameters.Session.ID;

	If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
		ExternalAttachableModule = ElectronicDocumentsServiceClient.ExternalConnectedModuleThroughAdditionalDataProcessor(Parameters.EDAgreement);
	Else
		ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
		ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
			ExchangeWithBanksSubsystemsParameters.Get(ElectronicDocumentsServiceClient.iBankName2ComponentName()), Undefined);
	EndIf;
		
	Try
		If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
			ExternalAttachableModule.SendOneTimePasswordForExtendedSMSAuthentication(
														Parameters.Certificate, Parameters.Session);
		Else
			XMLSession = ElectronicDocumentsServiceClient.SerializedData(Parameters.Session);
			ExternalAttachableModule.SendExtendedSMSAuthenticationPassword(XMLSession);
		EndIf;
	Except
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ErrorTemplate = NStr("en='SMS authentication launch error."
"Error code:"
"%1 %2';ru='Ошибка запуска аутентификации по SMS."
"Код"
"ошибки: %1 %2'");
		If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
			ErrorDetails = ExternalAttachableModule.ErrorDetails();
		Else
			ErrorDetails = ElectronicDocumentsServiceClient.InformationAboutErroriBank2();
		EndIf;
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en='Making a connection';ru='Установка соединения'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
			Operation, DetailErrorDescription, MessageText, 1);
		Items.FormButtonDone.Visible = False;
	EndTry;

EndProcedure

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
