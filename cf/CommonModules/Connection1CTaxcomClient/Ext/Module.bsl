
////////////////////////////////////////////////////////////////////////////////
// 1C Taxcom Connection subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Launch mechanism to work with the EDF operator service
//
// Parameters:
// DSCertificate - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - DS certificate;
// Company - Arbitrary - company, company associated
// 	with the certificate;
// BusinessProcessOption - String - name of EDF action.Possible values:
// 	taxcomGetID  - launch the receiving registration)
// 	of a new taxcomPrivat identifier - enter EDF subscriber's personal account.
// CompanyID - String - company identifier in the EDF system;
// DSCertificatePassword - String, Undefined - password
// 	of a password used to avoid repeated input;
// FormUUID (UUID) - identifier of the form from which the method was called. Used as an
// event source when alerting the form initiator about the result.
//
Procedure StartWorkWithEDFOperatorMechanism(
	DSCertificate,
	Company,
	BusinessProcessOption,
	CompanyID = "",
	DSCertificatePassword = Undefined,
	FormUUID = Undefined) Export
	
	// Check if required fields are filled
	ErrorText      = "";
	MessageText   = "";
	ErrorsCount = 0;
	
	If Not ValueIsFilled(DSCertificate) Then
		
		ErrorText = NStr("en='Subscriber certificate';ru='""Сертификат абонента""'");
		ErrorsCount = ErrorsCount + 1;
		
	EndIf;
	
	If Not ValueIsFilled(Company) Then
		
		If Not IsBlankString(ErrorText) Then
			ErrorText = ErrorText + " " + NStr("en='and';ru='а также'") + " ";
		EndIf;
		
		ErrorText = ErrorText + NStr("en='Company';ru='Организация'");
		ErrorsCount = ErrorsCount + 1;
		
	EndIf;
	
	// Check of other parameters duplicates the EDF library check.
	// During the collaboration with EDF library these checks
	// will always be with the True value
	If ErrorsCount > 0 Then
		
		If ErrorsCount = 1 Then
			AdditText = NStr("en='Please fill in the field';ru='Пожалуйста, заполните поле'") + " ";
		Else
			AdditText = NStr("en='Please fill in the fields';ru='Пожалуйста, заполните поля'") + " ";
		EndIf;
		
		MessageText = AdditText + ErrorText;
		
		If BusinessProcessOption = "taxcomGetID" Then
			MessageText = MessageText
				+ " " + NStr("en='before receiving a unique ididentifier of ED exchange participant';ru='до получения уникального идентификатора участника обмена ЭД'");
		ElsIf BusinessProcessOption = "taxcomPrivat" Then
			MessageText = MessageText + " " + NStr("en='before going to personal account';ru='до перехода в личный кабинет'");
		EndIf;
		
		ShowMessageBox(, MessageText);
		Return;
		
	EndIf;
	
	// Mechanism launch
	If BusinessProcessOption = "taxcomGetID" Then
		
		If IsBlankString(CompanyID) Then
			// This is an ididentifier receipt
			UserNotificationText = 
			NStr("en='You can receive a unique identifier of"
						"ED exchange member after connecting to the users"
						"online support service and checking the authenticity of the owner specified in the subscriber certificate agreement."
						"Continue?';
				 |ru='Получение уникального идентификатора"
						"участника обмена ЭД будет доступно после подключения"
						"к сервису Интернет-поддержки пользователей и проверки подлинности владельца указанного в соглашении сертификата абонента."
						"Продолжить?'");
		Else
			UserNotificationText =
			NStr("en='You can add a new certificate"
						"into an agreement after connecting to users online"
						"support service and checking the authenticity of the owner specified in the subscriber certificate agreement."
						"Continue?';
				 |ru='Добавление нового сертификата в соглашение будет выполнено"
						"после подключения к сервису Интернет-поддержки пользователей и проверки"
						"подлинности владельца указанного в соглашении сертификата абонента."
						"Продолжить?'");
		EndIf;
		
	ElsIf BusinessProcessOption = "taxcomPrivat" Then
		
		UserNotificationText = 
		NStr("en='You can log in the personal account"
					"of the ED exchange participant after connecting to"
					"the users online support and checking the authenticity of the owner specified in the subscriber certificate agreement."
					"Continue?';
			 |ru='Вход в личный кабинет участника"
					"обмена ЭД будет доступен после подключения"
					"к сервису Интернет-поддержки пользователей и проверки подлинности владельца указанного в соглашении сертификата абонента."
					"Продолжить?'");
		
	Else
		
		WarningText = StrReplace(
			NStr("en='Error occurred inserting users online support mechanism."
						"An incorrect version of the business process is specified (%1).';
				 |ru='Ошибка встраивания механизма Интернет-поддержки пользователей."
						"Указан неверный вариант бизнес-процесса (%1).'"),
			"%1",
			BusinessProcessOption);
		ShowMessageBox(, WarningText);
		Return;
		
	EndIf;
	
	LaunchEDFParameters = New Structure;
	LaunchEDFParameters.Insert("IDDSCertificate"   , DSCertificate);
	LaunchEDFParameters.Insert("IDOrganizationED"  , Company);
	LaunchEDFParameters.Insert("identifierTaxcomED", CompanyID);
	
	If DSCertificatePassword <> Undefined Then
		LaunchEDFParameters.Insert("passwordDSCertificate", DSCertificatePassword);
	EndIf;
	
	If FormUUID <> Undefined Then
		LaunchEDFParameters.Insert("IDParentForm", FormUUID);
	EndIf;
	
	If Not IsBlankString(CompanyID) AND BusinessProcessOption = "taxcomGetID" Then
		LaunchEDFParameters.Insert("ToAddCert", "YES");
	EndIf;
	
	AdditNotificationParameters = New Structure("BusinessProcessVariant, EDFLaunchParameters",
		BusinessProcessOption,
		LaunchEDFParameters);
	
	NotifyDescription = New NotifyDescription("OnReplyQuestionAboutEDFBusinessProcessBeginning",
		ThisObject,
		AdditNotificationParameters);
	
	ShowQueryBox(NOTifyDescription, UserNotificationText, QuestionDialogMode.YesNo);
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Business processes handlers

// Execute IPP servervice command on 1C:Enterprise client side.
// Called from UsersOnlineSupportClient.ExecuteServiceCommand()
//
// Parameters:
// InteractionContext - see description
// 	of the UsersOnlineSupportServerCall.NewInteractionContext() function;
// CurrentForm - ManagedForm - form, from which the call is executed;
// CommandStructure - see description
// 	of the UsersOnlineSupportClientServer.OutlineServerAnswer() function;
// HandlerContext - see description
// 	of
// the UsersOnlineSupportClientServer.NewCommandsHandlerContext() BreakCommandsProcessing function - Boolean - shows that you
// 	need to stop executing commands if an asynchronous action appears is returned in the parameter.
//
Procedure RunServiceCommand(
	InteractionContext,
	CurrentForm,
	CommandStructure,
	HandlerContext,
	BreakCommandProcessing) Export
	
	CommandName = CommandStructure.CommandName;
	
	If CommandName = "setcodesregion" Then
		
		Connection1CTaxcomClientServer.SaveInStateCodesParameters(
			InteractionContext.COPContext,
			CommandStructure);
		
	ElsIf CommandName = "performtheaction.decode" Then
		
		BreakCommandProcessing = True;
		DecryptControlDSMarkerServer(
			InteractionContext,
			CommandStructure,
			HandlerContext,
			CurrentForm);
		
	EndIf;
	
EndProcedure

// Called when forming parameters of
// business process form opening sent to the GetForm() method.
// Called from UsersOnlineSupportClient.GenerateFormOpeningParameters()
//
// Parameters:
// COPContext - see the
// 	UsersOnlineSupportServerCall.NewInteractionContext()
// function OpeningFormName - String - full name of opened form;
// Parameters - Structure - fill form opening parameters
//
Procedure FormOpenParameters(COPContext, OpenableFormName, Parameters) Export
	
	If OpenableFormName = "DataProcessor.Connection1CTaxcom.Form.SubscriberUUID" Then
		Parameters.Insert("requestStatusED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "requestStatusED"));
		Parameters.Insert("numberRequestED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "numberRequestED"));
		Parameters.Insert("identifierTaxcomED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "identifierTaxcomED"));
		Parameters.Insert("dateRequestED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "dateRequestED"));
		Parameters.Insert("IDDSCertificate",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "IDDSCertificate"));
		Parameters.Insert("IDOrganizationED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "IDOrganizationED"));
		Parameters.Insert("ToAddCert",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "ToAddCert"));
		
	ElsIf OpenableFormName = "DataProcessor.Connection1CTaxcom.Form.ApplicationForSubscriberRegistration" Then
		Parameters.Insert("statusApplicationFormED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "statusApplicationFormED"));
		Parameters.Insert("numberRequestED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "numberRequestED"));
		Parameters.Insert("dateRequestED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "dateRequestED"));
		Parameters.Insert("requestStatusED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "requestStatusED"));
		Parameters.Insert("nameDSCertificate",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "nameDSCertificate"));
		Parameters.Insert("orgindED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "orgindED"));
		Parameters.Insert("postindexED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "postindexED"));
		Parameters.Insert("addressregionED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "addressregionED"));
		Parameters.Insert("coderegionED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "codregionED"));
		Parameters.Insert("addresstownshipED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "addresstownshipED"));
		Parameters.Insert("addresscityED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "addresscityED"));
		Parameters.Insert("addresslocalityED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "addresslocalityED"));
		Parameters.Insert("addressstreetED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "addressstreetED"));
		Parameters.Insert("addressbuildingED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "addressbuildingED"));
		Parameters.Insert("addresshousingED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "addresshousingED"));
		Parameters.Insert("addressapartmentED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "addressapartmentED"));
		Parameters.Insert("addressphoneED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "addressphoneED"));
		Parameters.Insert("agencyED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "agencyED"));
		Parameters.Insert("tinED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "tinED"));
		Parameters.Insert("kppED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "kppED"));
		Parameters.Insert("ogrnED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "ogrnED"));
		Parameters.Insert("codeimnsED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "codeimnsED"));
		Parameters.Insert("lastnameED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "lastnameED"));
		Parameters.Insert("firstnameED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "firstnameED"));
		Parameters.Insert("middlenameED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "middlenameED"));
		Parameters.Insert("identifierTaxcomED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "identifierTaxcomED"));
		Parameters.Insert("IDDSCertificate",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "IDDSCertificate"));
		
	ElsIf OpenableFormName = "DataProcessor.Connection1CTaxcom.Form.ChangeTariff" Then
		Parameters.Insert("freePackagesED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "freePackagesED"));
		Parameters.Insert("unallocatedPackagesED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "unallocatedPackagesED"));
		Parameters.Insert("begindatetarifED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "begindatetarifED"));
		Parameters.Insert("enddatetarifED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "enddatetarifED"));
		Parameters.Insert("dateRequestED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "dateRequestED"));
		Parameters.Insert("numberRequestED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "numberRequestED"));
		Parameters.Insert("requestStatusED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "requestStatusED"));
		Parameters.Insert("codeErrorED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "codeErrorED"));
		Parameters.Insert("textErrorED",
			OnlineUserSupportClientServer.SessionParameterValue(COPContext, "textErrorED"));
		
	EndIf;
	
EndProcedure

#EndRegion


#Region ServiceProceduresAndFunctions

// Processes the response of the user to question from StartWorkMechanismWithEDFOperator().
//
Procedure OnReplyQuestionAboutEDFBusinessProcessBeginning(QuestionResult, AdditParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	OnlineUserSupportClient.RunScript(
		AdditParameters.BusinessProcessOption,
		AdditParameters.LaunchEDFParameters);
	
EndProcedure

// Decrypting the marker returned by
// the IPP service to confirm the authenticity of the certificate owner. Codegram is stored in
// the session parameter under the markerED name.
//
// Parameters:
// InteractionContext - Structure - see the
// 	UsersOnlineSupportServerCall.NewInteractionContext()
// function CommandStructure Structure - data of the service IPP commands.
// HandlerContext - Structure - see the
// 	UsersOnlineSupportServerCall.NewCommandsHandlerContext()
// function CurrentForm - ManagedForm - IPP current form;
//
Procedure DecryptControlDSMarkerServer(
	InteractionContext,
	CommandStructure,
	HandlerContext,
	CurrentForm)
	
	ErrorMessageForUser = NStr("en='Error checking certificate password.
		|For more details see the event log.';ru='Ошибка при проверке пароля сертификата.
		|Подробнее см в журнале регистрации.'");
	
	// Receive the required session parameters to execute decryption operation
	ParametersForDecryption = OnlineUserSupportClientServer.SessionParametersForDecryption(
		InteractionContext.COPContext);
	
	If ParametersForDecryption.markerED = Undefined Then
		// Business process error: markerED mandatory parameter is not available
		OnlineUserSupportClient.EndBusinessProcess(InteractionContext);
		OnlineUserSupportServerCall.WriteErrorInEventLogMonitor(
			NStr("en='Error occurred checking the certificate owner authenticity. Authentication marker is not available (markerED)';ru='Ошибка при проверке подлинности владельца сертификата. Отсутствует маркер аутентификации (markerED)'"));
		ShowMessageBox(, ErrorMessageForUser);
		Return;
	EndIf;
	
	Try
		MarkerBinaryData = Base64Value(ParametersForDecryption.markerED);
	Except
		// Error occurred receiving marker binary data from base64 row
		OnlineUserSupportClient.EndBusinessProcess(InteractionContext);
		MessageForRegistrationLog = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Error occurred checking the certificate owner authenticity. Unable to receive marker binary data.
		|%1';ru='Ошибка при проверке подлинности владельца сертификата. Не удалось получить двоичные данные маркера (markerED).
		|%1'"),
			DetailErrorDescription(ErrorInfo()));
		OnlineUserSupportServerCall.WriteErrorInEventLogMonitor(MessageForRegistrationLog);
		ShowMessageBox(, ErrorMessageForUser);
		Return;
	EndTry;
	
	// Get internal presentation of the certificate reference
	If ValueIsFilled(ParametersForDecryption.IDDSCertificate_Dop) Then
		
		// Ref of an additional certificate
		DSCertificate = ParametersForDecryption.IDDSCertificate_Dop;
		
		DeletedParameters = New Array;
		DeletedParameters.Add(New Structure("Name", "IDDSCertificate_Dop"));
		OnlineUserSupportClientServer.DeleteContextParameters(
			InteractionContext.COPContext,
			DeletedParameters,
			HandlerContext);
		
	ElsIf ValueIsFilled(ParametersForDecryption.IDDSCertificate) Then
		
		// Reference of the main certificate
		DSCertificate = ParametersForDecryption.IDDSCertificate;
		
	Else
		
		// Unable to receive certificate ref - end business process
		OnlineUserSupportClient.EndBusinessProcess(InteractionContext);
		OnlineUserSupportServerCall.WriteErrorInEventLogMonitor(
			NStr("en='Error occurred checking the certificate owner authenticity. Certificate is not specified (IDDSCertificate, IDDSCertificate_Dop)';ru='Ошибка при проверке подлинности владельца сертификата. Не указан сертификат (IDCertificateED, IDCertificateED_Dop)'"));
		ShowMessageBox(, ErrorMessageForUser);
		Return;
		
	EndIf;
	
	// Call the StandardSubsystems.DigitalSignature
	// applicationming interface Forming description of data for decryption
	DataDescription = New Structure;
	DataDescription.Insert("Operation", NStr("en='Certificate password check';ru='Проверка пароля сертификата'"));
	DataDescription.Insert("DataTitle", "");
	
	DataDescription.Insert("ItIsAuthentication"        , True);
	DataDescription.Insert("Data"                   , MarkerBinaryData);
	DataDescription.Insert("EncryptionCertificates"    , New Array);
	DataDescription.Insert("WithoutConfirmation"         , True);
	DataDescription.Insert("NotifyAboutCompletion"      , False);
	DataDescription.Insert("EnableRememberPassword", True);
	
	FilterCertificates = New Array;
	FilterCertificates.Add(DSCertificate);
	DataDescription.Insert("FilterCertificates", FilterCertificates);
	
	// Additional parameters for an alert handler
	AdditHandlerParameters = New Structure;
	AdditHandlerParameters.Insert("CommandStructure"      , CommandStructure);
	AdditHandlerParameters.Insert("HandlerContext"   , HandlerContext);
	AdditHandlerParameters.Insert("CurrentForm"          , CurrentForm);
	AdditHandlerParameters.Insert("InteractionContext", InteractionContext);
	
	// Call the StandardSubsystems.DigitalSignature
	// application interface for decrypting the control marker
	DigitalSignatureClient.Decrypt(
		DataDescription,
		,
		New NotifyDescription("DecryptionEnd", ThisObject, AdditHandlerParameters));
	
EndProcedure

// Complete decryption of control marker processing
Procedure DecryptionEnd(DecryptionResult, AdditParameters) Export
	
	If DecryptionResult.Success Then
		
		// Record of the decrypted marker into the session parameters
		OnlineUserSupportClientServer.WriteContextParameter(
			AdditParameters.InteractionContext.COPContext,
			"openMarkerED",
			DecryptionResult.DecryptedData,
			"sessionParameter");
		
		// Continue executing business process
		OnlineUserSupportClient.ServiceCommandsDataProcessor(
			AdditParameters.InteractionContext,
			AdditParameters.CurrentForm,
			,
			AdditParameters.HandlerContext,
			,
			,
			True);
		
	Else
		
		// End business process as Cannot continue the business process
		OnlineUserSupportClient.EndBusinessProcess(AdditParameters.InteractionContext);
		
	EndIf;
	
EndProcedure

// See the reason of declining EDF request in the warning dialog.
//
Procedure ShowEDFApplicationRejection(InteractionContext) Export
	
	ReasonDescription = GetReasonForApplicationRejection(InteractionContext);
	
	MessageText = "";
	If Not IsBlankString(ReasonDescription.ErrorCode) Then
		MessageText = NStr("en='Error code: %1';ru='Код ошибки: %1'");
		MessageText = StrReplace(MessageText, "%1", ReasonDescription.ErrorCode);
	EndIf;
	
	If Not IsBlankString(ReasonDescription.ErrorText) Then
		
		If Not IsBlankString(MessageText) Then
			MessageText = MessageText + Chars.LF;
		EndIf;
		
		MessageText = MessageText + ReasonDescription.ErrorText;
		
	EndIf;
	
	If IsBlankString(ReasonDescription.ErrorText) Then
		MessageText = NStr("en='Unknown error. Contact support.';ru='Неизвестная ошибка. Обратитесь в службу техподдержки.'");
	EndIf;
	
	ShowMessageBox(, MessageText);
	
EndProcedure

// Read the reasons of rejecting EDF application from session parameters.
//
Function GetReasonForApplicationRejection(InteractionContext)
	
	Result = New Structure;
	
	Result.Insert("ErrorCode",
		OnlineUserSupportClientServer.SessionParameterValue(
			InteractionContext.COPContext,
			"codeErrorED"));
	Result.Insert("ErrorText",
		OnlineUserSupportClientServer.SessionParameterValue(
			InteractionContext.COPContext,
			"textErrorED"));
	
	Return Result;
	
EndFunction

// Returns a the text of EDF technical parameters to
// create an email to tech service. support.
//
Function TechnicalEDFParametersText(InteractionContext, Val Certificate = Undefined) Export
	
	TechnicalParameters = NStr("en='Parameters of ED
		|
		|exchange participant - the certificate thumbprint: %1';ru='Параметры
		|
		|участника обмена ЭД: - отпечаток сертификата: %1'");
	
	If Not ValueIsFilled(Certificate) Then
		Certificate = OnlineUserSupportClientServer.SessionParameterValue(
			InteractionContext.COPContext,
			"IDDSCertificate");
	EndIf;
	
	If ValueIsFilled(Certificate) Then
		CertificateThumbprint = Connection1CTaxcomServerCall.CertificateThumbprint(Certificate);
	Else
		CertificateThumbprint = "";
	EndIf;
	
	TechnicalParameters = StringFunctionsClientServer.PlaceParametersIntoString(
		TechnicalParameters,
		CertificateThumbprint);
	
	ErrorCode = OnlineUserSupportClientServer.SessionParameterValue(
		InteractionContext.COPContext,
		"codeErrorED");
	ErrorText = OnlineUserSupportClientServer.SessionParameterValue(
		InteractionContext.COPContext,
		"textErrorED");
	
	If Not IsBlankString(ErrorCode) Then
		
		ErrorDataPage = Chars.LF + NStr("en='- error code:
		|%1, - error description: %2';ru='- код
		|ошибки: %1, - описание ошибки: %2'");
		
		TechnicalParameters = TechnicalParameters
			+ StringFunctionsClientServer.PlaceParametersIntoString(
				ErrorDataPage,
				ErrorCode,
				ErrorText);
		
	EndIf;
	
	Return TechnicalParameters;
	
EndFunction

#EndRegion
