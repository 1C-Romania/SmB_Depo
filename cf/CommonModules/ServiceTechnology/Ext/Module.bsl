#Region ApplicationInterface

// Returns the version of 1C: Service Technology Library
//
// Return value: a string, the library version in the following format: RR.{P|PP}.ZZ.SS.
//
Function LibraryVersion() Export
	
	Return "1.0.6.1";
	
EndFunction

#EndRegion

#Region ServiceApplicationInterface

// Announces service events of the service technology library subsystem.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Called up at generating the configuration manifest.
	//
	// Parameters:
	//  AdvancedInformation - Array, inside handler procedure it is
	//    required to add to this array objects of
	//    the type ObjectXDTO with TypeXDTO derived from {http:www.1c.ru/1CFresh/Application/Manifest/a.b.c.d}ExtendedInfoItem.
	//
	// Syntax:
	// The AtConfigurationManifestGeneration Procedure (AdvancedInformation) Export
	//
	ServerEvents.Add(
		"ServiceTechnology.BasicFunctionality\WhenGeneratingConfigurationManifest");
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnEnableSeparationByDataAreas"].Add(
		"ServiceTechnology");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SSL subsystems event handlers

// Called up at enabling data classification into data fields.
//
Procedure OnEnableSeparationByDataAreas() Export
	
	CheckPossibilityToUseConfigurationSaaS();
	
EndProcedure

// Adds to the Handlers
// list update handler procedures required to this subsystem.
//
// Parameters:
//   Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.Procedure = "ServiceTechnology.CheckPossibilityToUseConfigurationSaaS";
		Handler.SharedData = True;
		Handler.ExecuteUnderMandatory = True;
		Handler.Priority = 99;
		Handler.ExclusiveMode = False;
		
	EndIf;
	
EndProcedure

// Called up at setting session parameters.
//
// Parameters:
//  SessionParameterNames - Array, Undefined.
//
Procedure PerformActionsAtSettingSessionParameters(Parameters) Export
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("ServiceTechnology.SaaS.UsersSaaS") Then
		
		ModuleUsersServiceSaaSSTL = ServiceTechnologyIntegrationWithSSL.CommonModule("UsersServiceSaaSSTL");
		ModuleUsersServiceSaaSSTL.AtSettingSessionParameters(Parameters);
		
	EndIf;
	
EndProcedure

// Checks possibility to use the configuration in the service model.
//  When it is not possible to use - an exception is issued
//  with indication of the reason why it is not possible to use the configuration in the service model.
//
Procedure CheckPossibilityToUseConfigurationSaaS() Export
	
	SubsystemDescriptions = StandardSubsystemsreuse.SubsystemDescriptions().ByNames;
	SSLDescription = SubsystemDescriptions.Get("StandardSubsystems");
	
	If SSLDescription = Undefined Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='The configuration does not include embedded 1C:Standard Subsystems Library.
		|The configuration can not be used in the service model if this library is not embedded.
		|
		|To use this configuration in the service model, it
		|is required to embed the library 1C:Standard Subsystems Library of version %1 or older version!';ru='В конфигурацию не внедрена библиотека ""1С:Библиотека стандартных подсистем"".
		|Без внедрения этой библиотеки конфигурация не может испольоваться в модели сервиса.
		|
		|Для использования этой конфигурации в модели
		|сервиса требуется внедрить библиотеку ""1С:Библиотека стандартных подсистем"" версии не младше %1!'", Metadata.DefaultLanguage.LanguageCode),
			RequiredSSLVersion());
		
	Else
		
		SSLVersion = SSLDescription.Version;
		
		If CommonUseClientServer.CompareVersions(SSLVersion, RequiredSSLVersion()) < 0 Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='To use the configuration in the service model with
		|the current version of 1C:Service Technology Library,
		|update the used version of 1C:Standard Subsystem Library!
		|
		|Version in use: %1, a version not older than %2 is required!';ru='Для использования конфигурации в модели сервиса с
		|текущей версией библиотеки ""1С:Библиотека технологии сервиса""
		|требуется обновить используемую версию библиотеки ""1С:Библиотека стандартных подсистем""!
		|
		|Используемая версия: %1, требуется версия не младше %2!'", Metadata.DefaultLanguage.LanguageCode),
				SSLVersion, RequiredSSLVersion());
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Generates error details for transfer through web service
//
// Parameters:
//  ErrorInfo - ErrorInfo - information
//   about error based on which details have to be generated
//
// Returns:
//  XDTODataObject - {http://www.1c.ru/SaaS/ServiceCommon}ErrorDescription
//   Error description for transfer through the web-service
//
Function GetWebServiceErrorDescription(ErrorInfo) Export
	
	WriteLogEvent(NStr("en='Web service operation in progress';ru='Выполнение операции web-сервиса'"), EventLogLevel.Error, , ,
		DetailErrorDescription(ErrorInfo));
	
	ErrorDescription = XDTOFactory.Create(
		XDTOFactory.Type("http://www.1c.ru/SaaS/ServiceCommon", "ErrorDescription"));
		
	ErrorDescription.BriefErrorDescription = BriefErrorDescription(ErrorInfo);
	ErrorDescription.DetailErrorDescription = DetailErrorDescription(ErrorInfo);
	
	Return ErrorDescription;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns the minimal supported version of 1C:Standard Subsystems Library.
//
// Return value: a string, the library version in the following format: RR.{P|PP}.ZZ.SS.
//
Function RequiredSSLVersion()
	
	Return "2.2.2.44";
	
EndFunction

#EndRegion
