
////////////////////////////////////////////////////////////////////////////////
// 1C Taxcom Connection subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Adds description of events handlers realized by the subsystem.
//
// Description of the procedures-processers format
// see in the description of the OnlineUserSupportServiceReUse function.EventsHandlers().
//
// Parameters:
// ServerHandlers - Structure - server handlers;
// 	* ClientWorkParametersOnStart - Array - the Row type elements -
// 		name of the modules that process
// 		<STRONG>the filling client work parameters at launch</STRONG>;
// 	* ClearIPPUserSettings - the Row type elements -
// 		name of modules that process users
// 		settings removal when an authorized user exits UOS;
// 	*BusinessProcesses - Map - server
// 		handlers of business processes:
// 		** Key - String - business process entry point;
// 		** Value - String - name of the
// 			server mode realising business process handler;
// ClientHandlers - Structure - client handlers;
// 	* OnStartSystemWork - the Row type elements -
// 		name of the client
// 		modules processing the On begin
// 	of system work event *BusinessProcesses - Map - client
// 		handlers of business processes:
// 		** Key - String - business process entry point;
// 		** Value - String - name of the
// 			client mode realising business process handler;
//
Procedure AddEventsHandlers(ServerHandlers, ClientHandlers) Export
	
	BusinessProcessesServer = ServerHandlers.BusinessProcesses;
	
	BusinessProcessesServer.Insert("taxcomGetID\ContextCreationParameters",
		"Connection1CTaxcom");
	BusinessProcessesServer.Insert("taxcomGetID\OnCreateInteractionContext",
		"Connection1CTaxcom");
	BusinessProcessesServer.Insert("taxcomGetID\CommandExecutionContext",
		"Connection1CTaxcomClientServer");
	BusinessProcessesServer.Insert("taxcomGetID\ExecuteServiceCommand",
		"Connection1CTaxcom");
	BusinessProcessesServer.Insert("taxcomGetID\StructureServiceCommand",
		"Connection1CTaxcomClientServer");
	BusinessProcessesServer.Insert("taxcomGetID\FillInternalFormParameters",
		"Connection1CTaxcomClientServer");
	
	BusinessProcessesServer.Insert("taxcomPrivat\ContextCreationParameters",
		"Connection1CTaxcom");
	BusinessProcessesServer.Insert("taxcomPrivat\OnCreateInteractionContext",
		"Connection1CTaxcom");
	BusinessProcessesServer.Insert("taxcomPrivat\CommandExecutionContext",
		"Connection1CTaxcomClientServer");
	BusinessProcessesServer.Insert("taxcomPrivat\ExecuteServiceCommand",
		"Connection1CTaxcom");
	BusinessProcessesServer.Insert("taxcomPrivat\StructureServiceCommand",
		"Connection1CTaxcomClientServer");
	BusinessProcessesServer.Insert("taxcomPrivat\FillInternalFormParameters",
		"Connection1CTaxcomClientServer");
	
	BusinessProcessesClient = ClientHandlers.BusinessProcesses;
	
	BusinessProcessesClient.Insert("taxcomGetID\CommandExecutionContext",
		"Connection1CTaxcomClientServer");
	BusinessProcessesClient.Insert("taxcomGetID\ExecuteServiceCommand",
		"Connection1CTaxcomClient");
	BusinessProcessesClient.Insert("taxcomGetID\GenerateFormOpeningParameters",
		"Connection1CTaxcomClient");
	BusinessProcessesClient.Insert("taxcomGetID\StructureServiceCommand",
		"Connection1CTaxcomClientServer");
	BusinessProcessesClient.Insert("taxcomGetID\FillInternalFormParameters",
		"Connection1CTaxcomClientServer");
	
	BusinessProcessesClient.Insert("taxcomPrivat\CommandExecutionContext",
		"Connection1CTaxcomClientServer");
	BusinessProcessesClient.Insert("taxcomPrivat\ExecuteServiceCommand",
		"Connection1CTaxcomClient");
	BusinessProcessesClient.Insert("taxcomPrivat\GenerateFormOpeningParameters",
		"Connection1CTaxcomClient");
	BusinessProcessesClient.Insert("taxcomPrivat\StructureServiceCommand",
		"Connection1CTaxcomClientServer");
	BusinessProcessesClient.Insert("taxcomPrivat\FillInternalFormParameters",
		"Connection1CTaxcomClientServer");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Business processes processing

// Called during filling of business process context creation parameters.See
// the UsersOnlineSupportServeerCall procedure.ContextCreationParameters().
//
// Parameters:
// Parameters - Structure - refilled parameters:
// *LaunchPlace - String - business process entry point;
// * OnStartSystemWork - Boolean - True if
// 	business processor is launched at the system start;
// * UseOnlineSupport - Boolean - True if
// 	you are allowed to use UOS for a current IB mode;
// * StartAllowed - Boolean - True if the current
// 	user is allowed to launch IPP;
// BreakProcessing - Boolean - shows that further processing
// 	is returned in the parameter if you know
// 	that further processing is not required.
//
Procedure ContextCreationParameters(Parameters, BreakProcessing) Export
	
	If Not Users.RolesAvailable("Use1CTaxcomService", , False) Then
		Parameters.LaunchAllowed = False;
	EndIf;
	
EndProcedure

// Adds required parameters to a
// created context of business process.
//
// Parameters:
// Context - see the
//		UsersOnlineSupportServerCall.NewInteractionContext() function
Procedure OnCreateInteractionContext(Context) Export
	
	LaunchLocation = Context.COPContext.MainParameters.LaunchLocation;
	If LaunchLocation = "taxcomGetID" Then
		Context.Insert("MessageActionsUnavailable",
			NStr("en='Get a unique identifier of the Taxcom is unavailable for this configuration subscriber.';ru='Получение уникального идентификатора абонента Такском недоступно для этой конфигурации.'"));
	ElsIf LaunchLocation = "taxcomPrivat" Then
		Context.Insert("MessageActionsUnavailable",
			NStr("en='Work with a personal account of the Taxcom is unavailable for this configuration subscriber.';ru='Работа с личным кабинетом абонента Такском недоступна для этой конфигурации.'"));
	EndIf;
	
EndProcedure

// Command execution of the UOS servervice from 1C:Enterprise server
// Parameters:
// COPContext - see description
// 	of the UsersOnlineSupportServerCall.NewInteractionContext() function;
// CommandStructure - see description
// 	of the UsersOnlineSupportClientServer.OutlineServerAnswer() function;
// HandlerContext - see description
// 	of the UsersOnlineSupportClientServer.NewCommandsHandlerProcess() function
//
Procedure RunServiceCommand(COPContext, CommandStructure, HandlerContext) Export
	
	CommandName = CommandStructure.CommandName;
	If CommandName = "performtheaction.getcertificate" Then
		PrepareDSCertificateForSending(COPContext, HandlerContext);
		
	ElsIf CommandName = "performtheaction.getinformationaboutorganization" Then
		PrepareDataAboutCompanies(COPContext, HandlerContext);
		
	ElsIf CommandName = "performtheaction.findcertificatefingerprint" Then
		PrepareCertificateDataByThumbprint(COPContext, HandlerContext);
		
	ElsIf CommandName = "setcodesregion" Then
		Connection1CTaxcomClientServer.SaveInStateCodesParameters(COPContext, CommandStructure);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns binary data of the certificate.
//
// Parameters:
// Certificate - CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates
// 	certificates catalog reference.
//
// Returns:
// BinaryData - certificate binary data;
// Undefined - if the certificate is not found in the certificates catalog.
//
Function CertificateBinaryData(Certificate) Export
	
	CertificateData = CommonUse.ObjectAttributeValue(Certificate, "CertificateData");
	Return ?(CertificateData = Undefined, Undefined, CertificateData.Get());
	
EndFunction

// Returns a link to certificates catalog
// item by server thumbprint.
//
// Parameters:
// Imprint - String - certificate thumbprint;
//
// Returns:
// CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates - refs
// 	to the certificate found by the thumbprint;
// Undefined - if certificate is not found by the thumbprint.
//
Function FindCertificateByThumbprint(Imprint) Export
	
	Query = New Query(
	"SELECT TOP 1
	|	DigitalSignaturesAndEncryptionKeyCertificates.Ref
	|FROM
	|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS DigitalSignaturesAndEncryptionKeyCertificates
	|WHERE
	|	DigitalSignaturesAndEncryptionKeyCertificates.Imprint = &Imprint");
	
	Query.SetParameter("Imprint", Imprint);
	
	Selection = Query.Execute().Select();
	
	Return ?(Selection.Next(), Selection.Ref, Undefined);
	
EndFunction

// Writes user's certificate binary data into the context
//	session parameters as Base64 rows.
//
Procedure PrepareDSCertificateForSending(COPContext, HandlerContext)
	
	// When starting mechanism the certificate was written as a
	// internal presentation row in a register as ED starting parameter in the SaveEDStartingParameters procedure.
	
	// Receive certificate reference and its binary data
	DSCertificate = OnlineUserSupportClientServer.SessionParameterValue(
		COPContext,
		"IDDSCertificate");
	
	If DSCertificate = Undefined Then
		
		HandlerContext.ErrorOccurred = True;
		HandlerContext.UserErrorDescription =
			NStr("en='Unable to receive binary data of the certificate. Certificate is not found in the list of parameters.';ru='Не удалось получить двоичные данные сертификата. Сертификат не обнаружен в списке параметров.'");
		HandlerContext.ActionOnErrorForClient = "ShowMessage";
		HandlerContext.ActionsOnErrorForServer.Add("BreakBusinessProcess");
		Return;
		
	EndIf;
	
	CertificateBinaryData = Connection1CTaxcom.CertificateBinaryData(DSCertificate);
	If CertificateBinaryData = Undefined Then
		
		MessageForRegistrationLog = NStr("en='Error receiving binary data of the certificate. There is no certificate binary data or the certificate was deleted.';ru='Ошибка при получении двоичных данных сертификата. Двоичные данные сертификата отсутствуют, либо сертификат был удален.'");
		OnlineUserSupportServerCall.WriteErrorInEventLogMonitor(
			MessageForRegistrationLog, DSCertificate);
		
		HandlerContext.ErrorOccurred                = True;
		HandlerContext.FullErrorDescription           = MessageForRegistrationLog;
		HandlerContext.ActionsOnErrorForServer.Add("CreateLogRegistrationRecord");
		HandlerContext.ActionsOnErrorForServer.Add("BreakBusinessProcess");
		HandlerContext.UserErrorDescription =
			NStr("en='Error receiving certificate data. For more details see the event log.';ru='Ошибка при получении данных сертификата. Подробнее см. в журнале регистрации.'");
		HandlerContext.ActionOnErrorForClient = "ShowMessage";
		Return;
		
	EndIf;
	
	// Write the certificate binary data to the register to send to the server
	StringBase64 = Base64String(CertificateBinaryData);
	
	OnlineUserSupportClientServer.WriteContextParameter(
		COPContext,
		"certificateED",
		StringBase64);
	
EndProcedure

// Prepares and saves information about organization to the session parameters.
//
Procedure PrepareDataAboutCompanies(COPContext, HandlerContext)
	
	// When starting mechanism the reference to organization was written
	// as a row of an internal presentation as ED starting parameter
	
	Company = OnlineUserSupportClientServer.SessionParameterValue(COPContext,
		"IDOrganizationED");
	
	If Company = Undefined Then
		Return;
	EndIf;
	
	CompanyDataStructure = New Structure;
	
	Try
		Connection1CTaxcomOverridable.FillCompanyRegistrationData(
			Company,
			CompanyDataStructure);
	Except
		
		HandlerContext.ErrorOccurred = True;
		HandlerContext.FullErrorDescription =
			NStr("en='Unable to receive company registration data.';ru='Не удалось получить регистрационные данные организации.'")
			+ " " + DetailErrorDescription(ErrorInfo());
		HandlerContext.ActionsOnErrorForServer.Add("CreateLogRegistrationRecord");
		HandlerContext.ActionsOnErrorForServer.Add("BreakBusinessProcess");
		
		HandlerContext.UserErrorDescription =
			NStr("en='Error receiving company data."
"See more in the registration log';ru='Ошибка при получении данных организации."
"Подробнее см. в журнале регистрации'");
		HandlerContext.ActionOnErrorForClient = "ShowMessage";
		Return;
		
	EndTry;
	
	If CompanyDataStructure = Undefined Then
		Return;
	EndIf;
	
	IndexOf          = "";
	Region          = "";
	District           = "";
	City           = "";
	Settlement = "";
	Street           = "";
	Building             = "";
	Section          = "";
	Apartment        = "";
	Phone         = "";
	Description    = "";
	TIN             = "";
	KPP             = "";
	OGRN            = "";
	TaxOfficeCode         = "";
	LegalEntityIndividual       = "";
	Surname         = "";
	Name             = "";
	Patronymic        = "";
	
	CompanyDataStructure.Property("IndexOf"         , IndexOf);
	CompanyDataStructure.Property("Region"         , Region);
	CompanyDataStructure.Property("District"          , District);
	CompanyDataStructure.Property("City"          , City);
	CompanyDataStructure.Property("Settlement", Settlement);
	CompanyDataStructure.Property("Street"          , Street);
	CompanyDataStructure.Property("Building"            , Building);
	CompanyDataStructure.Property("Section"         , Section);
	CompanyDataStructure.Property("Apartment"       , Apartment);
	CompanyDataStructure.Property("Phone"        , Phone);
	CompanyDataStructure.Property("Description"   , Description);
	CompanyDataStructure.Property("TIN"            , TIN);
	CompanyDataStructure.Property("KPP"            , KPP);
	CompanyDataStructure.Property("OGRN"           , OGRN);
	CompanyDataStructure.Property("TaxOfficeCode"        , TaxOfficeCode);
	CompanyDataStructure.Property("LegalEntityIndividual"      , LegalEntityIndividual);
	CompanyDataStructure.Property("Surname"        , Surname);
	CompanyDataStructure.Property("Name"            , Name);
	CompanyDataStructure.Property("Patronymic"       , Patronymic);
	
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "postindexED", IndexOf);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "addressregionED", Region);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "addresscoderegionED", "");
	OnlineUserSupportClientServer.WriteContextParameter(COPContext,
		"addresstownshipED",
		District);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "addresscityED", City);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext,
		"addresslocalityED",
		Settlement);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "addressstreetED", Street);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "addressbuildingED", Building);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext,
		"addresshousingED",
		Section);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext,
		"addressapartmentED",
		Apartment);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "addressphoneED", Phone);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "agencyED", Description);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "orgindED", LegalEntityIndividual);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "tinED", TIN);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "kppED", KPP);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "ogrnED", OGRN);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "codeimnsED", TaxOfficeCode);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "lastnameED", Surname);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "firstnameED", Name);
	OnlineUserSupportClientServer.WriteContextParameter(COPContext, "middlenameED", Patronymic);
	
EndProcedure

// Search certificate by a thumbprint stored
// in the session parameters and reference record, and certificate in the session parameters.
//
Procedure PrepareCertificateDataByThumbprint(COPContext, HandlerContext)
	
	// Certificate thumbprint should be transferred into the session parameters.
	
	CertificateThumbprint = OnlineUserSupportClientServer.SessionParameterValue(
		COPContext,
		"certificatefingerprintED");
	
	DSCertificate = Undefined;
	If CertificateThumbprint <> Undefined Then
		DSCertificate = Connection1CTaxcom.FindCertificateByThumbprint(CertificateThumbprint);
	EndIf;
	
	If DSCertificate <> Undefined Then
		OnlineUserSupportClientServer.WriteContextParameter(
			COPContext,
			"IDDSCertificate",
			DSCertificate);
	EndIf;
	
EndProcedure

#EndRegion