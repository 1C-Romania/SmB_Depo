
////////////////////////////////////////////////////////////////////////////////
// Subsystem "Online User Support".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the version of the OnlineUserSupport subsystem.
// Returns:
// String - version of the current library.
//
Function LibraryVersion() Export
	
	Return "2.1.3.1";
	
EndFunction

// Returns version of
// the interaction supported by API library with the server part.
//
// Returns:
// String - version of API supported by the library
//
Function InteractionAPIVersion() Export
	
	Return "1.0.1.1";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Export procedures and functions for work with the online support web service.

// Returns URL of the online user support web service.
//
// Returns:
// String - URL of the OUS web-service.
//
Function WSDefinitionName() Export
	
	Return "";
	
EndFunction

// Define URI name of UOS web service.
//
// Returns:
// String - of URI service.
//
Function URIServiceName() Export
	
	Return "https://ws.webits.onec.ru";
	
EndFunction

// Returns the structure-specifier of online user support resource.
// Used for filling in access permissions to the external resources.
//
// Returns:
// Structure - description of the online user support resource:
// * Protocol - String - connection protocol (http or https);
// * Address    - String - server address;
// * Port     - Number  - port on the online support server;
// *Description - String - String description of the resource;
//
Function OnlineSupportResourceDescription() Export
	
	Return New Structure("Protocol, Address, Port, Description",
		"HTTPS",
		"webits.1c.en",
		443,
		NStr("en='Online user support';ru='Интернет-поддержка пользователей'"));
	
EndFunction

// Returns structure with fields-parameters
// passed
// to the OnlineUserSupportPredefined.OnDefineOnlineSupportUserData() and OnlineUserSupportPredefined.OnAuthorizationUsersInOnlineSupport()procedures
//
// Returns:
// Structure - with parameter-fields:
// * Login  - String - user's login;
// * Password - String - user's password;
//
Function NewOnlineSupportUserData() Export
	
	Result = New Structure;
	Result.Insert("Login" , "");
	Result.Insert("Password", "");
	
	Return Result;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Check if it is possible to launch
// the online support according to the parameters and location (button) of launch. Returns a control
// structure that describes the actions that are required to be executed.
//
// Parameters:
// LaunchLocation - String - launch location (button name) of the mechanism;
// InternetSupportParameters - Structure - Online
// 	support work parameters
// 	(see function OnlineUserSupport.ContextCreationParameters()).
//
// Returns:
// Structure - if the launch in the current work mode is forbidden:
// * Action  - String - action that should be executed;
// * Message - String - if execution of action implies
// 					   displaying of message to a user;
// Undefined - if start is allowed.
//
Function DefineStartPossibilityByLocationAndParameters(LaunchLocation, InternetSupportParameters) Export
	
	// Check the launch possibility
	OnStart = InternetSupportParameters.OnStart;
	
	Result = Undefined;
	
	// Standard processor when you get started to work with the application
	If OnStart Then
		
		If Not InternetSupportParameters.UseOnlineSupport
			OR Not InternetSupportParameters.LaunchAllowed Then
			
			Result = New Structure("Action", "Return");
			
		EndIf;
		
	ElsIf Not InternetSupportParameters.UseOnlineSupport Then
		
		Result = New Structure;
		Result.Insert("Action", "ShowMessage");
		Result.Insert("Message",
			NStr("en='Online user support cannot be used in the current work mode.';ru='Использование Интернет-поддержки пользователей запрещено в текущем режиме работы.'"));
		
	ElsIf Not InternetSupportParameters.LaunchAllowed Then
		
		Result = New Structure;
		Result.Insert("Action" , "ShowMessage");
		Result.Insert("Message",
			NStr("en='You have no rights to launch online user support. Contact your administrator.';ru='Недостаточно прав для запуска Интернет-поддержки пользователей. Обратитесь к администратору.'"));
		
	EndIf;
	
	If Result = Undefined Then
		// Processor of the current business process with the handler
		Handler = BusinessProcessHandler(LaunchLocation, "DefineLaunchPossibility");
		If Handler <> Undefined Then
			
			ActionsDetails = New Structure;
			Handler.DefineLaunchPossibility(
				LaunchLocation,
				InternetSupportParameters,
				ActionsDetails);
			
			If ActionsDetails.Count() > 0 Then
				Result = ActionsDetails;
			EndIf;
			
		EndIf;
	EndIf;
	
	If Result <> Undefined Then
		Result.Insert("OnStart", OnStart);
	EndIf;
	
	Return Result;
	
EndFunction

#If Not WebClient Then

// Check if the online user
// support service is available using the isReady() method call.
//
// Parameters:
// OUSServiceDescription - Structure - specifier of connection to UOS web-service:
// see	the NewUOSServiceDescription() function.
//
// Returns:
// Boolean - True if the service is available, False - if an exception appeared
// 	while contacting service;
// String - description of reason why the service returned by service is unavailable;
//
Function AccessToWebServiceIsAvailable(OUSServiceDescription) Export
	
	Try
		
		ServerResponse = OUSService_IsReady(OUSServiceDescription);
		
		If Lower(TrimAll(ServerResponse)) = "ready" Then
			Return True;
		Else
			Return ServerResponse;
		EndIf;
		
	Except
		
		OnlineUserSupportServerCall.WriteErrorInEventLogMonitor(
			DetailErrorDescription(ErrorInfo()));
		Return False;
		
	EndTry;
	
EndFunction

// Check if the configuration in online
// support service is registered.
//
// Parameters:
// AccesToWebServiceError - Boolean - the True value is
// 	returned in the parameter if during the process of
// 	contacting the web service an exception is thrown, an error is written to the events log monitor;
// OUSServiceDescription - Structure - OUS service desciption
// 	(see function NewOUSServiceDescription());
// OUSParameters - Structure - parameters for work with
// 	UOS service, received earlier;
//
// Returns:
// Boolean - True if the configuration is registered
// 	in the OUS service, False - if the configuration is not registered
// 	or an exception is thrown during accessing UOS service.
//
Function ConfigurationIsRegisteredInOUSService(
	WebServiceCallError = False,
	OUSServiceDescription = Undefined,
	OUSParameters = Undefined) Export
	
	Try
		
		If OUSServiceDescription = Undefined Then
			OUSServiceDescription = NewOUSServiceDescription(, OUSParameters);
		EndIf;
		
		// Configuration name is passed as the method parameter
		ServerResponse = OUSService_isConfigurationSupported(
			ConfigurationName(),
			OUSServiceDescription);
		
		Return (ServerResponse = True OR ServerResponse = "true");
		
	Except
		WebServiceCallError = True;
		OnlineUserSupportServerCall.WriteErrorInEventLogMonitor(
			DetailErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for
// work with web service of online user support on the "low level".

// Generates the description of the web service
// from WSDL-document to  work with UOS web service.
//
// Parameters:
// WSDLAddress - String, Undefined - URL of WSDL-document location;
// 	If it is not specified, then WSDefinitionName() is used;
// OUSNetworkParameters - Structure - network parameters of the online support:
// 	(see UsersOnlineSupportServerCall.OnlineSupportNetworkParameters());
// WSDLDescriptionsCache - Map, Undefined - cache of services WSDL-descriptions;
// 	used for saving WSDL-descriptions in the
// 	process of interaction with UOS services. Key - URL of WSDL-document, value - String - address
// 	of the WSDL-description text in the temporary storage;
//
// Returns:
// Structure - description of connection to UOS service:
// * WSDLAddress - String - WSDL-document URL;
// * NetworkTimeout - Number - network connection timeout;
// * XDTOFactory - XDTOFactory - Web-service XDTO factory;
// * OfURIService - String - URI of the OUS web-service;
// * PortConnection - HTTPConnection - connection
// 	to service port to call web service methods;
// * InternetProxy - InternetProxy - connection of the proxy server;
// * ConnectionToPortParameters -Structure - see the
// 	NewDocumentReceivingParameters() function;
//	
Function NewOUSServiceDescription(
	WSDLAddress = Undefined,
	NetworkParameters = Undefined,
	WSDLDescriptionsCache = Undefined) Export
	
	If WSDLAddress = Undefined Then
		WSDLAddress = WSDefinitionName();
	EndIf;
	
	Result = New Structure("WSDLAddress", WSDLAddress);
	
	If NetworkParameters = Undefined Then
		NetworkParameters = OnlineUserSupportServerCall.OnlineSupportNetworkParameters();
	EndIf;
	
	Result.Insert("NetworkTimeout", NetworkParameters.NetworkTimeout);
	
	WSDLText     = Undefined;
	DescriptionAddress = Undefined;
	If WSDLDescriptionsCache <> Undefined Then
		DescriptionAddress = WSDLDescriptionsCache.Get(WSDLAddress);
		If DescriptionAddress <> Undefined Then
			WSDLText = GetFromTempStorage(DescriptionAddress);
		EndIf;
	EndIf;
	
	If WSDLText = Undefined Then
		
		// Receive and parse WSDL-document
		WSDLReceptionParameters = NewReceivingDocumentParameters(WSDLAddress);
		
		InternetProxy = GetFilesFromInternetClientServer.GetProxy(
			?(WSDLReceptionParameters.SafeConnection, "https", "http"));
		
		HTTP = New HTTPConnection(
			WSDLReceptionParameters.Server,
			WSDLReceptionParameters.Port,
			WSDLReceptionParameters.UserName,
			WSDLReceptionParameters.Password,
			InternetProxy,
			Result.NetworkTimeout,
			?(WSDLReceptionParameters.SafeConnection,
				New OpenSSLSecureConnection,
				Undefined));
		
		Try
			
			HTTPRequest = New HTTPRequest(WSDLReceptionParameters.Path);
			Response = HTTP.Get(HTTPRequest);
			WSDLText = Response.GetBodyAsString();
			
		Except
			ErrorMessage = StrReplace(
				NStr("en='An error occurred while creating the description of the web service.
		|Unable to receive WSDL-description from the online user support server (%1).';ru='Ошибка при создании описания веб-сервиса.
		|Не удалось получить WSDL-описание с сервера Интернет-поддержки пользователей (%1).'"),
					"%1",
					WSDLAddress)
				+ " " + DetailErrorDescription(ErrorInfo());
			Raise ErrorMessage;
		EndTry;
		
	EndIf;
	
	If WSDLDescriptionsCache <> Undefined AND DescriptionAddress = Undefined Then
		// Put WSDL description to the temporary storage
		DescriptionAddress = PutToTempStorage(WSDLText, New UUID);
		WSDLDescriptionsCache.Insert(WSDLAddress, DescriptionAddress);
		// Data from the temporary storage is
		// removed when the business process of online user support ends
	EndIf;
	
	XMLReader = New XMLReader;
	XMLReader.SetString(WSDLText);
	
	DOMBuilder = New DOMBuilder;
	Try
		DOMDocument = DOMBuilder.Read(XMLReader);
	Except
		ErrorMessage = StrReplace(
				NStr("en='An error occurred while describing web service (%1).
		|An error occurred during reading WSDL-description of the online user support web service:';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка чтения WSDL-описания веб-сервиса Интернет-поддержки пользователей:'"),
				"%1",
				WSDLAddress)
			+ " " + DetailErrorDescription(ErrorInfo());
		Raise ErrorMessage;
	EndTry;
	
	// Create XDTO factory of UOS service
	
	SchemeNodes = DOMDocument.GetElementByTagName("wsdl:types");
	If SchemeNodes.Count() = 0 Then
		
		ErrorMessage = StrReplace(NStr("en='An error occurred while describing web service (%1).
		|An error occurred during reading WSDL-description of the online user support web service:';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка чтения WSDL-описания веб-сервиса Интернет-поддержки пользователей:'"),
				"%1",
				WSDLAddress)
			+ Chars.LF
			+ NStr("en='Data type description item is missing (<wsdl:types ...>).';ru='Отсутствует элемент описания типов данных (<wsdl:types ...>).'");
		
		Raise ErrorMessage;
		
	EndIf;
	
	SchemeDescriptionNode = SchemeNodes[0].FirstSubsidiary;
	If SchemeDescriptionNode = Undefined Then
		
		ErrorMessage = StrReplace(NStr("en='An error occurred while describing web service (%1).
		|An error occurred during reading WSDL-description of the online user support web service:';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка чтения WSDL-описания веб-сервиса Интернет-поддержки пользователей:'"),
				"%1",
				WSDLAddress)
			+ " " + NStr("en='Data type description item is missing (<xs:schema ...>)';ru='Отсутствует элемент описания типов данных (<xs:schema ...>)'");
		
		Raise ErrorMessage;
		
	EndIf;
	
	SchemeBuilder = New XMLSchemaBuilder;
	
	Try
		ServiceDataScheme = SchemeBuilder.CreateXMLSchema(SchemeDescriptionNode);
	Except
		ErrorMessage = StrReplace(NStr("en='An error occurred while describing web service (%1).
		|An error occurred during creating the data scheme from WSDL-description of the online user support web service.';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка при создании схемы данных из WSDL-описания веб-сервиса Интернет-поддержки пользователей:'"),
				"%1",
				WSDLAddress)
			+ " " + DetailErrorDescription(ErrorInfo());
		Raise ErrorMessage;
	EndTry;
	
	SchemaSet = New XMLSchemaSet;
	SchemaSet.Add(ServiceDataScheme);
	
	Try
		ServiceFactory = New XDTOFactory(SchemaSet);
	Except
		ErrorMessage = StrReplace(NStr("en='An error occurred while describing web service (%1).
		|An error occurred during creating XDTO factory from WSDL-description of the web service of online user support:';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка при создании фабрики XDTO из WSDL-описания веб-сервиса Интернет-поддержки пользователей:'"),
				"%1",
				WSDLAddress)
			+ " " + DetailErrorDescription(ErrorInfo());
		Raise ErrorMessage;
	EndTry;
	
	// Define the parameters of connection to the service port
	
	RootElement = DOMDocument.FirstSubsidiary;
	
	Result.Insert("XDTOFactory", ServiceFactory);
	
	OfURIService = DOMNodeAttributeValue(RootElement, "targetNamespace");
	If Not ValueIsFilled(OfURIService) Then
		
		ErrorMessage = StrReplace(NStr("en='An error occurred while describing web service (%1).
		|An error occurred during reading WSDL-description of the online user support web service:';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка чтения WSDL-описания веб-сервиса Интернет-поддержки пользователей:'"),
				"%1",
				WSDLAddress)
			+ " " + NStr("en='Names space URI in WSDL description is missing.';ru='Отсутствует URI пространства имен в WSDL-описании.'");
		
		Raise ErrorMessage;
		
	EndIf;
	
	Result.Insert("OfURIService", OfURIService);
	
	// Define the address of the web service port
	ServicesNodes = RootElement.GetElementByTagName("wsdl:service");
	If ServicesNodes.Count() = 0 Then
		ErrorMessage = StrReplace(NStr("en='An error occurred while describing web service (%1).
		|An error occurred during reading WSDL-description of the online user support web service:';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка чтения WSDL-описания веб-сервиса Интернет-поддержки пользователей:'"),
				"%1",
				WSDLAddress)
			+ " " + NStr("en='Description of the web services is missing in WSDL description (<wsdl:service ...>).';ru='Отсутствует описание веб-сервисов в WSDL-описании (<wsdl:service ...>).'");
		
		Raise ErrorMessage;
	EndIf;
	
	ServiceNode = ServicesNodes[0];
	
	ServiceName = DOMNodeAttributeValue(ServiceNode, "name");
	
	PortsNodes = ServiceNode.GetElementByTagName("wsdl:port");
	
	If PortsNodes.Count() = 0 Then
		ErrorMessage = StrReplace(NStr("en='An error occurred while describing web service (%1).
		|An error occurred during reading WSDL-description of the online user support web service:';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка чтения WSDL-описания веб-сервиса Интернет-поддержки пользователей:'"),
				"%1",
				WSDLAddress)
			+ " " + NStr("en='No description of ports in WSDL description (<wsdl:port ...>).';ru='Отсутствует описание портов в WSDL-описании (<wsdl:port ...>).'");
		
		Raise ErrorMessage;
	EndIf;
	
	PortNode = PortsNodes[0];
	PortName  = DOMNodeAttributeValue(PortNode, "name");
	
	If Not ValueIsFilled(PortName) Then
		
		ErrorMessage = StrReplace(NStr("en='An error occurred while describing web service (%1).
		|An error occurred during reading WSDL-description of the online user support web service:';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка чтения WSDL-описания веб-сервиса Интернет-поддержки пользователей:'"),
				"%1",
				WSDLAddress)
			+ " " + StrReplace(NStr("en='Cannot define name of the service port (%1).';ru='Не удалось определить имя порта сервиса (%1).'"),
				"%1",
				ServiceName);
		
		Raise ErrorMessage;
		
	EndIf;
	
	PortAddress = Undefined;
	AddressNodes = PortNode.GetElementByTagName("soap:address");
	If AddressNodes.Count() > 0 Then
		PortAddress = DOMNodeAttributeValue(AddressNodes[0], "location");
	EndIf;
	
	If Not ValueIsFilled(PortAddress) Then
		
		ErrorMessage = StrReplace(NStr("en='An error occurred while describing web service (%1).
		|An error occurred during reading WSDL-description of the online user support web service:';ru='Ошибка при создании описания веб-сервиса (%1).
		|Ошибка чтения WSDL-описания веб-сервиса Интернет-поддержки пользователей:'"),
				"%1",
				WSDLAddress)
			+ " " + StrReplace(NStr("en='Cannot detect URL of the defined service port (%1).';ru='Не удалось определить URL заданного порта сервиса (%1).'"),
				"%1",
				PortName);
		
		Raise ErrorMessage;
		
	EndIf;
	
	// Create the connection to the web service port
	ConnectionToPortParameters = NewReceivingDocumentParameters(PortAddress);
	
	InternetProxy = GetFilesFromInternetClientServer.GetProxy(
		?(ConnectionToPortParameters.SafeConnection, "https", "http"));
	
	PortConnection = New HTTPConnection(
		ConnectionToPortParameters.Server,
		ConnectionToPortParameters.Port,
		ConnectionToPortParameters.UserName,
		ConnectionToPortParameters.Password,
		InternetProxy,
		Result.NetworkTimeout,
		?(ConnectionToPortParameters.SafeConnection,
			New OpenSSLSecureConnection,
			Undefined));
	
	Result.Insert("InternetProxy"            , InternetProxy);
	Result.Insert("ConnectionToPortParameters", ConnectionToPortParameters);
	Result.Insert("PortConnection"           , PortConnection);
	
	Return Result;
	
EndFunction

// Changes the timeout of contacting service in the current connection with UOS service.
//
// Parameters:
// OUSServiceDescription - Structure - see the NewUOSServiceDescription() function;
// TimeoutValue - Number - value of the set timeout in seconds;
//
Procedure ChangeCallTimeout(OUSServiceDescription, TimeoutValue) Export
	
	OUSServiceDescription.NetworkTimeout = TimeoutValue;
	
	// You can assign the timeout
	// in HTTP-connection only in the constructor,
	// that is why it is required to recreate the port connection
	
	ConnectionToPortParameters = OUSServiceDescription.ConnectionToPortParameters;
	PortConnection = New HTTPConnection(
		ConnectionToPortParameters.Server,
		ConnectionToPortParameters.Port,
		ConnectionToPortParameters.UserName,
		ConnectionToPortParameters.Password,
		OUSServiceDescription.InternetProxy,
		TimeoutValue,
		?(ConnectionToPortParameters.SafeConnection,
			New OpenSSLSecureConnection,
			Undefined));
	
	OUSServiceDescription.PortConnection = PortConnection;
	
EndProcedure

// Proxy-function for calling the isReady() method of UOS web service.
//
// Parameters:
// OUSServiceDescription - Structure - For more
// 	information on UOS web service, see NewUOSServiceDescription();
//
// Returns:
// String - value returned using the isReady() method of UOS web server;
//
Function OUSService_isReady(OUSServiceDescription) Export
	
	EnvelopeRecord = NewSOAPEnvelopeRecord();
	EnvelopeText  = TextInSOAPEnvelope(EnvelopeRecord);
	
	Try
		ResponseBody = SendSOAPQuery(EnvelopeText, OUSServiceDescription);
	Except
		
		ErrorMessage = StrReplace(NStr("en='An error occurred while calling the isReady operation of service (%1):';ru='Ошибка при вызове операции isReady сервиса (%1):'"),
				"%1",
				OUSServiceDescription.WSDLAddress)
			+ " " + DetailErrorDescription(ErrorInfo());
		Raise ErrorMessage;
		
	EndTry;
	
	ObjectType = UOSServiceFactoryRootPropertyValueType("isReadyResponse", OUSServiceDescription);
	If ObjectType = Undefined Then
		ErrorMessage = StrReplace(NStr("en='An error occurred while calling the isReady operation of service (%1).
		|Unable to define the type of the isReadyResponse root property.';ru='Ошибка при вызове операции isReady сервиса (%1).
		|Не удалось определить тип корневого свойства isReadyResponse.'"),
			"%1",
			OUSServiceDescription.WSDLAddress);
		Raise ErrorMessage;
	EndIf;
	
	Try
		Value = ReadResponseInSOAPEnvelope(ResponseBody, OUSServiceDescription, ObjectType);
	Except
		ErrorMessage = StrReplace(NStr("en='An error occurred when calling operation isReady of service (%1).';ru='Ошибка при вызове операции isReady сервиса (%1).'"),
			"%1",
			OUSServiceDescription.WSDLAddress)
			+ Chars.LF
			+ DetailErrorDescription(ErrorInfo())
			+ Chars.LF + Chars.LF
			+ NStr("en='Query body:';ru='Тело запроса:'")
			+ Chars.LF
			+ EnvelopeText;
		
		Raise ErrorMessage;
	EndTry;
	
	If TypeOf(Value) = Type("Structure") Then
		
		// Description of SOAP exception is returned
		ErrorMessage = StrReplace(NStr("en='An error occurred while calling the isReady operation of service (%1).
		|SOAP error:';ru='Ошибка при вызове операции isReady сервиса (%1).
		|Ошибка SOAP:'"),
			"%1",
			OUSServiceDescription.WSDLAddress)
			+ " " + DescriptionSOAPExceptionToRow(Value);
		
		Raise ErrorMessage;
		
	ElsIf TypeOf(Value) = Type("XDTODataValue") Then
		Return Value.Value;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Proxy-function for calling the isConfigurationSupported() method of UOS web service.
//
// Parameters:
// ConfigurationName - String - Current configuration name;
// OUSServiceDescription - Structure - For more
// 	information on UOS web service, see NewUOSServiceDescription();
//
// Returns:
// Boolean - value returned using
// 	the isConfigurationSupported() method of UOS web service;
//
Function OUSService_isConfigurationSupported(ConfigurationName, OUSServiceDescription) Export
	
	EnvelopeRecord = NewSOAPEnvelopeRecord();
	
	PropertyValueType = UOSServiceFactoryRootPropertyValueType("isConfigurationSupported",
		OUSServiceDescription);
	
	If PropertyValueType = Undefined Then
		ErrorMessage = StrReplace(NStr("en='An error occurred during calling the isConfigurationSupported operation of (%1) service.
		|Unable to define the type of the isConfigurationSupported root property.';ru='Ошибка при вызове операции isConfigurationSupported сервиса (%1).
		|Не удалось определить тип корневого свойства isConfigurationSupported.'"),
			"%1",
			OUSServiceDescription.WSDLAddress);
		Raise ErrorMessage;
	EndIf;
	
	XDTODataValue = OUSServiceDescription.XDTOFactory.Create(PropertyValueType, ConfigurationName);
	
	OUSServiceDescription.XDTOFactory.WriteXML(EnvelopeRecord,
		XDTODataValue,
		"isConfigurationSupported",
		,
		XMLForm.Element,
		XMLTypeAssignment.Explicit);
	
	EnvelopeText = TextInSOAPEnvelope(EnvelopeRecord);
	
	Try
		ResponseBody = SendSOAPQuery(EnvelopeText, OUSServiceDescription);
	Except
		
		ErrorMessage = StrReplace(NStr("en='An error occurred when calling the isConfigurationSupported operation of the (%1) service:';ru='Ошибка при вызове операции isConfigurationSupported сервиса (%1):'"),
			"%1",
			OUSServiceDescription.WSDLAddress)
			+ " " + DetailErrorDescription(ErrorInfo());
		
		Raise ErrorMessage;
		
	EndTry;
	
	ObjectType = UOSServiceFactoryRootPropertyValueType("isConfigurationSupportedResponse", OUSServiceDescription);
	If ObjectType = Undefined Then
		ErrorMessage = StrReplace(NStr("en='An error occurred during calling the isConfigurationSupported operation of (%1) service.
		|Unable to define the type of the isConfigurationSupportedResponse root property.';ru='Ошибка при вызове операции isConfigurationSupported сервиса (%1).
		|Не удалось определить тип корневого свойства isConfigurationSupportedResponse.'"),
			"%1",
			OUSServiceDescription.WSDLAddress);
		Raise ErrorMessage;
	EndIf;
	
	Try
		Value = ReadResponseInSOAPEnvelope(ResponseBody, OUSServiceDescription, ObjectType);
	Except
		ErrorMessage = StrReplace(NStr("en='An error occurred when calling the isConfigurationSupported operation of the (%1) service.';ru='Ошибка при вызове операции isConfigurationSupported сервиса (%1).'"),
			"%1",
			OUSServiceDescription.WSDLAddress)
			+ Chars.LF
			+ DetailErrorDescription(ErrorInfo())
			+ Chars.LF + Chars.LF
			+ NStr("en='Query body:';ru='Тело запроса:'")
			+ Chars.LF
			+ EnvelopeText;
		
		Raise ErrorMessage;
	EndTry;
	
	If TypeOf(Value) = Type("XDTODataValue") Then
		Return Value.Value;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Proxy-function for calling the process() method of UOS web service.
//
// Parameters:
// QueryParameters - XDTODataObject - parameters of the process() method query;
// OUSServiceDescription - Structure - For more
// 	information on UOS web service, see NewUOSServiceDescription();
//
// Returns:
// XDTODataObject - value returned using the process() method of UOS web server;
//
Function OUSService_process(QueryParameters, OUSServiceDescription) Export
	
	EnvelopeRecord = NewSOAPEnvelopeRecord();
	
	EnvelopeRecord.WriteStartElement("m:processRequest");
	EnvelopeRecord.WriteAttribute("xmlns:m", OUSServiceDescription.OfURIService);
	
	OUSServiceDescription.XDTOFactory.WriteXML(
		EnvelopeRecord,
		QueryParameters,
		"parameters",
		,
		XMLForm.Element,
		XMLTypeAssignment.Explicit);
	
	EnvelopeRecord.WriteEndElement(); // </m:processRequest>
	
	EnvelopeText = TextInSOAPEnvelope(EnvelopeRecord);
	
	Try
		ResponseBody = SendSOAPQuery(EnvelopeText, OUSServiceDescription);
	Except
		
		ErrorMessage = StrReplace(NStr("en='An error occurred while calling the process operation of service (%1):';ru='Ошибка при вызове операции process сервиса (%1):'"),
			"%1",
			OUSServiceDescription.WSDLAddress)
			+ " " + DetailErrorDescription(ErrorInfo());
		
		Raise ErrorMessage;
		
	EndTry;
	
	ObjectType = UOSServiceFactoryRootPropertyValueType("processResponse", OUSServiceDescription);
	If ObjectType = Undefined Then
		ErrorMessage = StrReplace(NStr("en='An error occurred while calling the process operation of service (%1).
		|Unable to define the type of the processResponse root property.';ru='Ошибка при вызове операции process сервиса (%1).
		|Не удалось определить тип корневого свойства processResponse.'"),
			"%1",
			OUSServiceDescription.WSDLAddress);
		Raise ErrorMessage;
	EndIf;
	
	Try
		Value = ReadResponseInSOAPEnvelope(ResponseBody, OUSServiceDescription, ObjectType);
	Except
		
		ErrorMessage = StrReplace(NStr("en='An error occurred when calling operation process of service (%1).';ru='Ошибка при вызове операции process сервиса (%1).'"),
			"%1",
			OUSServiceDescription.WSDLAddress)
			+ Chars.LF
			+ DetailErrorDescription(ErrorInfo())
			+ Chars.LF + Chars.LF
			+ NStr("en='Query body:';ru='Тело запроса:'")
			+ Chars.LF
			+ EnvelopeText;
		
		Raise ErrorMessage;
		
	EndTry;
	
	If TypeOf(Value) = Type("XDTODataObject") Then
		Return Value.commands;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Proxy-function for calling the sendmailtonet() method of UOS web service
//
// Parameters:
// QueryParameters - XDTODataObject - parameters of the sendmailtonet() method query;
// OUSServiceDescription - Structure - For more
// 	information on UOS web service, see NewUOSServiceDescription();
//
// Returns:
// XDTODataObject - value returned using the process() method of UOS web server;
//
Function OUSService_sendmailtonet(QueryParameters, OUSServiceDescription) Export
	
	EnvelopeRecord = NewSOAPEnvelopeRecord();
	
	OUSServiceDescription.XDTOFactory.WriteXML(
		EnvelopeRecord,
		QueryParameters,
		"sendmailParams",
		OUSServiceDescription.OfURIService,
		XMLForm.Element,
		XMLTypeAssignment.Explicit);
	
	EnvelopeText = TextInSOAPEnvelope(EnvelopeRecord);
	
	Try
		ResponseBody = SendSOAPQuery(EnvelopeText, OUSServiceDescription);
	Except
		
		ErrorMessage = StrReplace(NStr("en='An error occurred while calling the sendmailtonet operation of service (%1).';ru='Ошибка при вызове операции sendmailtonet сервиса (%1).'"),
			"%1",
			OUSServiceDescription.WSDLAddress)
			+ " " + DetailErrorDescription(ErrorInfo());
		
		Raise ErrorMessage;
		
	EndTry;
	
	ObjectType = UOSServiceFactoryRootPropertyValueType("processResponse", OUSServiceDescription);
	If ObjectType = Undefined Then
		ErrorMessage = StrReplace(NStr("en='An error occurred during calling the sendmailtonet operation of service (%1).
		|Unable to define the type of the processResponse root property.';ru='Ошибка при вызове операции sendmailtonet сервиса (%1).
		|Не удалось определить тип корневого свойства processResponse.'"),
			"%1",
			OUSServiceDescription.WSDLAddress);
		Raise ErrorMessage;
	EndIf;
	
	Try
		Value = ReadResponseInSOAPEnvelope(ResponseBody, OUSServiceDescription, ObjectType);
	Except
		
		ErrorMessage = StrReplace(NStr("en='An error occurred when calling operation process of service (%1).';ru='Ошибка при вызове операции process сервиса (%1).'"),
			"%1",
			OUSServiceDescription.WSDLAddress)
			+ Chars.LF
			+ DetailErrorDescription(ErrorInfo())
			+ Chars.LF + Chars.LF
			+ NStr("en='Query body:';ru='Тело запроса:'")
			+ Chars.LF
			+ EnvelopeText;
		
		Raise ErrorMessage;
		
	EndTry;
	
	If TypeOf(Value) = Type("XDTODataObject") Then
		Return Value.commands;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Returns a row value of the DOM-document node attribute.
//
// Parameters:
// DOMNode - DOMNode - DOM-document node;
// AttributeName - String - full name of the attribute;
// ValueIfNotFound - Arbitrary - value that
// 	is required to be returned if the attribute is not found;
//
// Returns:
// String - String value of the node attribute;
//
Function DOMNodeAttributeValue(DOMNode, AttributeName, ValueIfNotFound = Undefined)
	
	Attribute = DOMNode.Attributes.GetNamedItem(AttributeName);
	
	If Attribute = Undefined Then
		Return ValueIfNotFound;
	Else
		Return Attribute.Value;
	EndIf;
	
EndFunction

// Returns the value type of the
// root property of the UOS web service XDTO factory pack.
//
// Parameters:
// PropertyName - String - name of the root property;
// OUSServiceDescription - Structure - For more
// 	information on UOS web service, see NewUOSServiceDescription();
//
// Returns:
// XDTOValueType, XDTOObjectType, Undefined - return
// 	type of the root property, Undefined - if the root property is unavailable.
//
Function UOSServiceFactoryRootPropertyValueType(PropertyName, OUSServiceDescription)
	
	Package            = OUSServiceDescription.XDTOFactory.packages.Get(OUSServiceDescription.OfURIService);
	RootProperty = Package.RootProperties.Get(PropertyName);
	If RootProperty = Undefined Then
		Return Undefined;
	Else
		Return RootProperty.Type;
	EndIf;
	
EndFunction

// Generates object the XMLWriter type with the written SOAP-titles;
//
// Returns:
// XMLWriter - object of XML record with the written SOAP-titles;
//
Function NewSOAPEnvelopeRecord()
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	
	XMLWriter.WriteStartElement("soap:Envelope");
	XMLWriter.WriteAttribute("xmlns:soap", "http://schemas.xmlsoap.org/soap/envelope/");
	XMLWriter.WriteStartElement("soap:Header");
	XMLWriter.WriteEndElement(); // </soap:Header>
	XMLWriter.WriteStartElement("soap:Body");
	
	Return XMLWriter;
	
EndFunction

// Finalizes the record of SOAP-envelope and returns the envelope text.
//
// Parameters:
// EnvelopeRecord - XMLWriter - object to which the envelope is written;
//
// Returns:
// String - SOAP envelope text;
//
Function TextInSOAPEnvelope(EnvelopeRecord)
	
	EnvelopeRecord.WriteEndElement(); // </soap:Body>
	EnvelopeRecord.WriteEndElement(); // </soap:Envelope>
	
	Return EnvelopeRecord.Close();
	
EndFunction

// Pass SOAP-envelope to UOS web-service and receive a response SOAP-envelope.
//
// Parameters:
// EnvelopeText - String - query-envelope text;
// OUSServiceDescription - Structure - For more
// 	information on UOS web service, see NewUOSServiceDescription();
//
// Returns:
// String - text of SOAP-envelope-response;
//
Function SendSOAPQuery(EnvelopeText, OUSServiceDescription)
	
	DesignerParameters = New Array;
	DesignerParameters.Add(OUSServiceDescription.ConnectionToPortParameters.Path);
	HTTPRequest = New(Type("HTTPRequest"), DesignerParameters);
	HTTPRequest.Headers["Content-Type"] = "text/xml;charset=UTF-8";
	
	HTTPRequest.SetBodyFromString(EnvelopeText);
	
	Try
		HTTPResponse = OUSServiceDescription.PortConnection.Post(HTTPRequest);
	Except
		ErrorMessage = NStr("en='An error of the network connection occurred while sending the request.';ru='Ошибка сетевого соединения при отправке запроса.'")
			+ Chars.LF
			+ DetailErrorDescription(ErrorInfo());
		Raise ErrorMessage;
	EndTry;
	
	ResponseBody = HTTPResponse.GetBodyAsString();
	
	Return ResponseBody;
	
EndFunction

// Read object or value in the response
// SOAP-envelope according to the types factory of XDTO web service.
//
// Parameters:
// ResponseBody - String - tags of SOAP-envelope-response;
// OUSServiceDescription - Structure - For more
// 	information on UOS web service, see NewUOSServiceDescription();
// ValueType - XDTOValueType, XDTOObjectType - read value type;
//
// Returns:
// XDTOValue, XDTOObject - read service response.
//
Function ReadResponseInSOAPEnvelope(ResponseBody, OUSServiceDescription, ValueType)
	
	ResponseReading = New XMLReader;
	ResponseReading.SetString(ResponseBody);
	
	URISOAP = "http://schemas.xmlsoap.org/soap/envelope/";
	
	Try
		
		// Transition to the response body
		While Not (Lower(ResponseReading.LocalName) = "body"
			AND ResponseReading.NamespaceURI = URISOAP) Do
			If Not ResponseReading.Read() Then
				Break;
			EndIf;
		EndDo;
		
		// Transfer to the description of the response object
		ResponseReading.Read();
		
	Except
		
		ErrorMessage = NStr("en='An error occurred while reading SOAP response:';ru='Ошибка чтения ответа SOAP:'")
			+ " " + DetailErrorDescription(ErrorInfo())
			+ Chars.LF
			+ NStr("en='Response body:';ru='Тело ответа:'")
			+ Chars.LF
			+ ResponseBody;
		
		Raise ErrorMessage;
		
	EndTry;
	
	If ResponseReading.NodeType = XMLNodeType.StartElement
		AND Upper(ResponseReading.LocalName) = "FAULT"
		AND ResponseReading.NamespaceURI = URISOAP Then
		
		// It is the exception of the web service
		Try
			ExceptionDetails = ReadServiceExceptionsDescription(ResponseReading);
		Except
			
			ErrorMessage = NStr("en='An error occurred while reading SOAP response:';ru='Ошибка чтения ответа SOAP:'")
				+ " " + DetailErrorDescription(ErrorInfo())
				+ Chars.LF
				+ NStr("en='Response body:';ru='Тело ответа:'")
				+ Chars.LF
				+ ResponseBody;
			
			Raise ErrorMessage;
			
		EndTry;
		
		ErrorMessage = NStr("en='An error of SOAP Server occurred while processing the query:';ru='Ошибка SOAP-Сервера при обработке запроса:'")
			+ " " + DescriptionSOAPExceptionToRow(ExceptionDetails);
		
		Raise ErrorMessage;
		
	EndIf;
	
	Try
		Value = OUSServiceDescription.XDTOFactory.ReadXML(ResponseReading, ValueType);
	Except
		
		ErrorMessage = StrReplace(NStr("en='An error occurred while reading object (%1) in SOAP envelope:';ru='Ошибка чтения объекта (%1) в конверте SOAP:'"),
				"%1",
				String(ValueType))
			+ " " + DetailErrorDescription(ErrorInfo())
			+ Chars.LF
			+ NStr("en='Response body:';ru='Тело ответа:'")
			+ Chars.LF
			+ ResponseBody;
			
		Raise ErrorMessage;
		
	EndTry;
	
	Return Value;
	
EndFunction

// If the response SOAP-envelope contains an
// error description, then the error description is read.
//
// Parameters:
// ResponseReading - XMLReader - object used for
// 	reading the response SOAP-envelope. At the time of the
// 	call it is positioned at the SOAP exception description;
//
// Returns:
// Structure - description of SOAP-server exception:
// * FaultCode - String - error code;
// * FaultString - String - String description of an error;
// * FaultActor - String - Error source;
//
Function ReadServiceExceptionsDescription(ResponseReading)
	
	DetailsExceptions = New Structure("FaultCode, FaultString, FaultActor", "", "", "");
	
	URISOAP = "http://schemas.xmlsoap.org/soap/envelope/";
	
	While Not (Upper(ResponseReading.LocalName) = "BODY"
		AND ResponseReading.NamespaceURI = URISOAP
		AND ResponseReading.NodeType = XMLNodeType.EndElement) Do
		
		If ResponseReading.NodeType = XMLNodeType.StartElement Then
			NodeNameInReg = Upper(ResponseReading.LocalName);
			
			If NodeNameInReg = "FAULTCODE"
				OR NodeNameInReg = "FAULTSTRING"
				OR NodeNameInReg = "FAULTACTOR" Then
				
				ResponseReading.Read(); // Read the node text
				
				If ResponseReading.NodeType = XMLNodeType.Text Then
					DetailsExceptions[NodeNameInReg] = ResponseReading.Value;
				EndIf;
				
				ResponseReading.Read(); // Read the end of item
				
			EndIf;
			
		EndIf;
		
		If Not ResponseReading.Read() Then
			Break;
		EndIf;
		
	EndDo;
	
	Return DetailsExceptions;
	
EndFunction

// Convert the structure-specifier
// of SOAP exception to the row for a custom presentation;
//
// Parameters:
// ExceptionSOAP - Structure - see ReadServiceExceptionsDescription();
//
// Returns:
// String - custom presentation of SOAP exception;
//
Function DescriptionSOAPExceptionToRow(ExceptionSOAP)
	
	Result = "";
	If Not IsBlankString(ExceptionSOAP.FaultCode) Then
		Result = ExceptionSOAP.FaultCode;
	EndIf;
	
	If Not IsBlankString(ExceptionSOAP.FaultString) Then
		Result = Result
			+ ?(IsBlankString(Result), "", " - ")
			+ ExceptionSOAP.FaultString;
	EndIf;
	
	If Not IsBlankString(ExceptionSOAP.FaultActor) Then
		Result = Result + ?(IsBlankString(Result), "", Chars.LF + NStr("en='Error source:';ru='Источник ошибки:'") + " ")
			+ ExceptionSOAP.FaultActor;
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of the common purpose for work with the Internet

// Breaks web-document URL into required parameters.
// Parameters:
// URL (String) - web-document URL;
//
// Returns:
// Structure with properties-values;
//
Function NewReceivingDocumentParameters(URL)
	
	Result    = New Structure;
	URLStructure = CommonUseClientServer.URLStructure(URL);
	
	Result.Insert("Server", URLStructure.Host);
	Result.Insert("Path"  , URLStructure.PathAtServer);
	
	If IsBlankString(URLStructure.Schema) Then
		Result.Insert("SafeConnection", False);
	Else
		Result.Insert("SafeConnection", (Upper(URLStructure.Schema) = "HTTPS"));
	EndIf;
	
	If URLStructure.Port = Undefined OR IsBlankString(URLStructure.Port) Then
		Result.Insert("Port", ?(Result.SafeConnection, 443, 80));
	Else
		Result.Insert("Port", Number(URLStructure.Port));
	EndIf;
	
	Result.Insert("UserName",
		?(IsBlankString(URLStructure.Login),
			Undefined,
			URLStructure.Login));
	
	Result.Insert("Password",
		?(IsBlankString(URLStructure.Password),
			Undefined,
			URLStructure.Password));
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for converting service commands to internal structures

// Converts an answer of the process() operation
// of UOS service to the sequence of commands in an internal presentation.
//
// Parameters:
// MainParameters - Structure - main parameters of the interaction context;
// ServerResponse - XDTODataObject - server response returned by the process() operation;
// HandlerContext - - Structure - context of
// 	command client-server handler (see function NewCommandsHandlerContext());
//
// Returns:
// Array - service commands array in the internal presentation.
//
Function StructureServerResponse(
	MainParameters,
	ServerResponse,
	HandlerContext) Export
	
	ResponseArray = New Array;
	
	Try
		
		For Each ServerCommand IN ServerResponse.command Do
			
			CommandStructure = Undefined;
			
			CurrentCommandName = Lower(TrimAll(ServerCommand.name));
			
			If CurrentCommandName = "ui.open" Then
				CommandStructure = StructureFormOpening(
					MainParameters,
					ServerCommand);
					
			ElsIf CurrentCommandName = "store.put" Then
				CommandStructure = StructureParametersRecord(ServerCommand);
			
			ElsIf CurrentCommandName = "store.get" Then
				CommandStructure = StructureParametersReading(ServerCommand);
				
			ElsIf CurrentCommandName = "store.delete" Then
				CommandStructure = StructureParametersDeletion(ServerCommand);
				
			ElsIf CurrentCommandName = "ui.close" Then
				CommandStructure = StructureFormClosing(
				MainParameters,
				ServerCommand);
				
			ElsIf CurrentCommandName = "system.halt" Then
				CommandStructure = StructureMechanismStop(ServerCommand);
				
			ElsIf CurrentCommandName = "launchservice" Then
				CommandStructure = StructureServerResponseOnBusinessProcessTransfer(ServerCommand);
				
			ElsIf CurrentCommandName = "message.show" OR CurrentCommandName = "question.show" Then
				CommandStructure = StructureMessageOrQuestionToUser(ServerCommand);
				
			ElsIf CurrentCommandName = "input.field" Then
				CommandStructure = StructureDataEntry(ServerCommand);
				
			ElsIf CurrentCommandName = "store.putorganizations" Then
				CommandStructure = StructuredUserCompaniesRecord(ServerCommand);
				
			ElsIf CurrentCommandName = "store.putadressclassifier" Then
				CommandStructure = StructureAddressClassifierRecord(ServerCommand);
				
			Else
				
				AdditHandler = BusinessProcessHandler(
					MainParameters.LaunchLocation,
					"StructureServiceCommand");
				If AdditHandler <> Undefined Then
					
					AdditHandler.StructureServiceCommand(
						CurrentCommandName,
						ServerCommand,
						CommandStructure);
					
				EndIf;
				
			EndIf;
			
			If CommandStructure <> Undefined Then
				
				If Not CommandStructure.Property("CommandName") Then
					CommandStructure.Insert("CommandName", CurrentCommandName);
				EndIf;
				
				ResponseArray.Add(CommandStructure);
				
			EndIf;
			
			If HandlerContext.ErrorOccurred Then
				Return Undefined;
			EndIf;
			
		EndDo;
		
	Except
		
		HandlerContext.ErrorOccurred = True;
		HandlerContext.FullErrorDescription = DetailErrorDescription(ErrorInfo());
		HandlerContext.ActionsOnErrorForServer.Add("CreateLogRegistrationRecord");
		
		HandlerContext.UserErrorDescription =
			NStr("en='Unknown error.For more information, see the event log.';ru='Неизвестная ошибка.См. подробности в журнале регистрации.'");
		HandlerContext.ActionOnErrorForClient = "ShowMessage";
		
		Return Undefined;
		
	EndTry;
	
	If ResponseArray.Count() > 0 Then
		
		For Each CommandStructure IN ResponseArray Do
			CommandStructure.CommandName = Lower(TrimAll(CommandStructure.CommandName));
		EndDo;
		
		Return ResponseArray;
		
	Else
		
		Return Undefined;
		
	EndIf;
	
EndFunction

// Convert the Message to user and
// Question to user commands to an internal presentation.
//
Function StructureMessageOrQuestionToUser(ServerCommand) Export
	
	CommandStructure = New Structure;
	
	ButtonList = New ValueList;
	CurrentResponseButtonDescription = New Structure;
	For Each Parameter IN ServerCommand.parameters.parameter Do
		
		CurrParameterName = Lower(TrimAll(Parameter.name));
		
		If CurrParameterName = "caption" Then
			CommandStructure.Insert("Title", String(Parameter.value));
			
		ElsIf CurrParameterName = "formmessage"
			OR CurrParameterName = "messagetext" Then
			CommandStructure.Insert("MessageText", String(Parameter.value));
			
		ElsIf CurrParameterName = "messagetype" OR CurrParameterName = "questiontype" Then
			CommandStructure.Insert("Type", Lower(TrimAll(String(Parameter.value))));
			
		ElsIf CurrParameterName = "button" Then
			ButtonList.Add(Lower(TrimAll(String(Parameter.value))));
			
		ElsIf CurrParameterName = "buttonvalue" Then
			CurrentResponseButtonDescription.Insert("ButtonValue", String(Parameter.value));
			
		ElsIf CurrParameterName = "buttontext" Then
			CurrentResponseButtonDescription.Insert("ButtonText", String(Parameter.value));
			
		EndIf;
		
		If CurrentResponseButtonDescription.Property("ButtonValue")
			AND CurrentResponseButtonDescription.Property("ButtonText") Then
			// If description of another button is received, then add it to the buttons list
			ButtonList.Add(
				CurrentResponseButtonDescription.ButtonValue,
				CurrentResponseButtonDescription.ButtonText);
			CurrentResponseButtonDescription = New Structure;
		EndIf;
		
	EndDo;
	
	If Not CommandStructure.Property("Title") OR IsBlankString(CommandStructure.Title) Then
		CommandStructure.Insert("Title", NStr("en='Online user support';ru='Интернет-поддержка пользователей'"));
	EndIf;
	
	If ButtonList.Count() > 0 Then
		CommandStructure.Insert("Buttons", ButtonList);
	EndIf;
	
	Return CommandStructure;
	
EndFunction

// Convert the Data input command to the internal presentation.
//
Function StructureDataEntry(ServerCommand) Export
	
	CommandStructure = New Structure;
	
	If ServerCommand.parameters = Undefined Then
		Return Undefined;
	EndIf;
	
	FormParameters = New Structure;
	For Each Parameter IN ServerCommand.parameters.parameter Do
		
		CurrParameterName = Lower(TrimAll(Parameter.name));
		
		If CurrParameterName = "caption" Then
			FormParameters.Insert("HeaderText", String(Parameter.value));
			
		ElsIf CurrParameterName = "explanationtext" Then
			FormParameters.Insert("ExplanationText", String(Parameter.value));
			
		ElsIf CurrParameterName = "datatype" Then
			FormParameters.Insert("DataType", String(Parameter.value));
			
		ElsIf CurrParameterName = "precision" Then
			FormParameters.Insert("FigurePrecision", String(Parameter.value));
			
		EndIf;
		
	EndDo;
	
	CommandStructure.Insert("FormParameters", FormParameters);
	
	Return CommandStructure;
	
EndFunction

// Convert the Write parameters command to the internal presentation.
//
Function StructureParametersRecord(ServerCommand) Export
	
	CommandStructure = New Structure;
	
	If ServerCommand.parameters.parameter.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	ParameterArray = New Array;
	
	For Each Parameter in ServerCommand.parameters.parameter Do
		ParameterStructure = New Structure("Name, BusinessProcess, Value, Scope",
												TrimAll(Parameter.name),
												TrimAll(Parameter.bp),
												TrimAll(Parameter.value),
												TrimAll(Parameter.type));
		
		ParameterArray.Add(ParameterStructure);
	EndDo;
	
	CommandStructure.Insert("Parameters" , ParameterArray);
	CommandStructure.Insert("CommandName", ServerCommand.name);
	
	Return CommandStructure;
	
EndFunction

// Convert the Read parameters command to the internal presentation.
//
Function StructureParametersReading(ServerCommand) Export
	
	CommandStructure = New Structure;
	
	If ServerCommand.parameters.parameter.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	ParameterArray = New Array;
	
	For Each Parameter in ServerCommand.parameters.parameter Do
		
		If Lower(TrimAll(Parameter.type)) = "startup" Then
			ParameterStructure = New Structure("Name, Scope",
				TrimAll(Parameter.name),
				TrimAll(Parameter.type));
		Else
			ParameterStructure = New Structure("Name, BusinessProcess, Scope",
				TrimAll(Parameter.name),
				TrimAll(Parameter.bp),
				TrimAll(Parameter.type));
		EndIf;
		
		ParameterArray.Add(ParameterStructure);
		
	EndDo;
	
	CommandStructure.Insert("Parameters", 	ParameterArray);
	CommandStructure.Insert("CommandName", ServerCommand.name);
	
	Return CommandStructure;
	
EndFunction

// Convert the Delete parameters command to the internal presentation.
//
Function StructureParametersDeletion(ServerCommand) Export
	
	CommandStructure = New Structure;
	
	If ServerCommand.parameters.parameter.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	ParameterArray = New Array;
	
	For Each Parameter in ServerCommand.parameters.parameter Do
	
		ParameterStructure = New Structure("Name, Scope",
			TrimAll(Parameter.name),
			TrimAll(Parameter.type));
		
		ParameterArray.Add(ParameterStructure);
		
	EndDo;
	
	CommandStructure.Insert("Parameters" , ParameterArray);
	CommandStructure.Insert("CommandName", ServerCommand.name);
	
	Return CommandStructure;
	
EndFunction

// Convert the Open form command to the internal presentation.
//
Function StructureFormOpening(MainParameters, ServerCommand) Export
	
	CommandStructure = New Structure;
	
	// Read the common parameters of the form opening
	For Each Parameter in ServerCommand.parameters.parameter Do
		
		If Lower(TrimAll(Parameter.name)) = "indexform" Then
			FormParameters = InternalFormParameters(
				TrimAll(Parameter.value),
				MainParameters.LaunchLocation);
			
			If FormParameters.Count() = 0 Then
				Return Undefined;
			EndIf;
			
			CommandStructure.Insert("FormParameters", FormParameters);
		EndIf;
		
		If Lower(TrimAll(Parameter.name)) = "caption" Then
			CommandStructure.Insert("Title", TrimAll(Parameter.value));
		EndIf;
		
		If Lower(TrimAll(Parameter.name)) = "text" Then
			CommandStructure.Insert("Text", TrimAll(Parameter.value));
		EndIf;
		
		If Lower(TrimAll(Parameter.name)) = "formmessage" Then
			CommandStructure.Insert("Text", TrimAll(Parameter.value));
		EndIf;
		
		If Lower(TrimAll(Parameter.name)) = "url" Then
			CommandStructure.Insert("URL", TrimAll(Parameter.value));
		EndIf;
		
	EndDo;
	
	If CommandStructure.Count() > 0 Then
		CommandStructure.Insert("CommandName", ServerCommand.name); 
		Return CommandStructure;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Convert the Close form command to the internal presentation.
//
Function StructureFormClosing(MainParameters, ServerCommand) Export
	
	CommandStructure = New Structure;
	
	For Each Parameter in ServerCommand.parameters.parameter Do
		
		If Lower(TrimAll(Parameter.name)) = "indexform" Then
			FormParameters = InternalFormParameters(
				TrimAll(Parameter.value),
				MainParameters.LaunchLocation);
			
			If FormParameters.Count() = 0 Then 
				Return Undefined;
			EndIf;
			
			CommandStructure.Insert("FormParameters", FormParameters);
		EndIf;
		
	EndDo;
	
	If CommandStructure.Count() > 0 Then 
		CommandStructure.Insert("CommandName", ServerCommand.name);
		Return CommandStructure;
	Else
		Return Undefined;
	EndIf;

EndFunction

// Helper function for formatting the parameters
// of internal form when the Open internal form and Close internal form commands are being run.
//
Function InternalFormParameters(FormIndex, LaunchLocation) Export
	
	FormParameters = New Structure;
	
	If FormIndex = "f2" Then
		FormParameters.Insert("OpenableFormName",
			"DataProcessor.OnlineSupportBasicFunctions.Form.OnlineSupportProductNotAvailable");
		
	ElsIf FormIndex = "f3" Then
		FormParameters.Insert("OpenableFormName",
			"DataProcessor.OnlineSupportBasicFunctions.Form.EmailSending");
	
	ElsIf FormIndex = "f4" OR FormIndex = "1" Then
		FormParameters.Insert("OpenableFormName",
			"DataProcessor.OnlineSupportBasicFunctions.Form.CommonAuthorization");
		
	ElsIf FormIndex = "f5" OR FormIndex = "13" Then
		FormParameters.Insert("OpenableFormName",
			"DataProcessor.OnlineSupportBasicFunctions.Form.PasswordRecovery");
		
	ElsIf FormIndex = "f6" OR FormIndex = "2" Then
		FormParameters.Insert("OpenableFormName",
			"DataProcessor.OnlineSupportBasicFunctions.Form.CommonRegNumber");
		
	ElsIf FormIndex = "f7" Then
		FormParameters.Insert("OpenableFormName",
			"DataProcessor.OnlineSupportBasicFunctions.Form.CommonPinCode");
		
	ElsIf FormIndex = "f9" OR FormIndex = "18" Then
		FormParameters.Insert("OpenableFormName",
			"DataProcessor.OnlineSupportBasicFunctions.Form.NewUserRegistration");
		
	ElsIf FormIndex = "f10" OR FormIndex = "19" Then
		FormParameters.Insert("OpenableFormName",
			"DataProcessor.OnlineSupportBasicFunctions.Form.AdditionalInformation");
		
	ElsIf FormIndex = "f11" Then
		FormParameters.Insert("OpenableFormName",
			"DataProcessor.OnlineSupportBasicFunctions.Form.SimplifiedAuthorization");
		
	ElsIf FormIndex = "c20" Then
		FormParameters.Insert("OpenableFormName",
			"DataProcessor.OnlineSupportBasicFunctions.Form.ActionNotSupported");
		
	ElsIf FormIndex = "bh1" Then
		FormParameters.Insert("Title", NStr("en='Online user support';ru='Интернет-поддержка пользователей'"));
		FormParameters.Insert("OpenableFormName", "PopupToolTip");
		FormParameters.Insert("BusinessProcessSuccessfulCompletion", True);
		
	Else
		
		AdditHandler = BusinessProcessHandler(LaunchLocation, "FillInternalFormParameters");
		
		If AdditHandler <> Undefined Then
			AdditHandler.FillInternalFormParameters(FormIndex, FormParameters);
		EndIf;
		
		If Not FormParameters.Property("OpenableFormName") Then
			FormParameters.Insert("OpenableFormName", Undefined);
		EndIf;
		
	EndIf;
	
	Return FormParameters;
	
EndFunction

// Convert the Stop mechanism command to the internal presentation.
//
Function StructureMechanismStop(ServerCommand) Export
	
	CommandStructure = New Structure;
	
	ParameterArray = New Array;
	Try
		
		If ServerCommand.parameters <> Undefined
			AND ServerCommand.parameters.parameter.Count() > 0 Then
			
			For Each Parameter in ServerCommand.parameters.parameter Do 
				
				ParameterStructure = Undefined;
				
				If Lower(TrimAll(Parameter.name)) = "errorcode" Then 
					ParameterStructure = New Structure("errorCode", TrimAll(Parameter.value));
					ParameterArray.Add(ParameterStructure);
				EndIf;
				
				If ParameterStructure <> Undefined Then
					ParameterArray.Add(ParameterStructure);
				EndIf;
				
			EndDo;
			
		EndIf;
		
	Except
	EndTry;
	
	CommandStructure.Insert("Parameters" , ParameterArray);
	CommandStructure.Insert("CommandName", ServerCommand.name);
	
	Return CommandStructure;
	
EndFunction

// Convert the Change business process command to the external presentation.
//
Function StructureServerResponseOnBusinessProcessTransfer(ServerCommand) Export
	
	CommandStructure = New Structure;
	
	If ServerCommand.parameters.parameter.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	ParameterArray = New Array;
	
	For Each Parameter in ServerCommand.parameters.parameter Do
		
		ParameterStructure = New Structure(Parameter.name, Parameter.value);
		ParameterArray.Add(ParameterStructure);
		
	EndDo;
	
	CommandStructure.Insert("Parameters" , ParameterArray);
	CommandStructure.Insert("CommandName", ServerCommand.name); 
	
	Return CommandStructure;
	
EndFunction

// Transform the Write address
// classifier command to the internal presentation.
//
Function StructureAddressClassifierRecord(ServerCommand) Export
	
	If ServerCommand.parameters = Undefined Then
		Return Undefined;
	EndIf;
	
	CommandStructure = New Structure;
	
	CountriesList  = New ValueList;
	CountryStates = New Map;
	
	CommandParameters = ServerCommand.parameters.parameter;
	
	If CommandParameters.Count() > 0 Then
		CountriesListParameters = CommandParameters[0].parameters.parameter;
	Else
		CountriesListParameters = Undefined;
	EndIf;
	
	If CountriesListParameters <> Undefined Then
		
		For Each Parameter IN CountriesListParameters Do
			
			CurrParameterName = Lower(TrimAll(Parameter.name));
			If CurrParameterName = "country" Then
				
				CountryName       = String(Parameter.value);
				EmbeddedParameters   = Parameter.parameters.parameter;
				CountryIdentifier  = Undefined;
				CountryStatesList = New ValueList;
				
				If EmbeddedParameters = Undefined Then
					Continue;
				EndIf;
				
				For Each EmbeddedParameter IN EmbeddedParameters Do
					
					CurrentEmbeddedParameterName = Lower(TrimAll(EmbeddedParameter.name));
					If CurrentEmbeddedParameterName = "id" Then
						
						CountryIdentifier = String(EmbeddedParameter.value);
						
					ElsIf CurrentEmbeddedParameterName = "region" Then
						
						StateName            = String(EmbeddedParameter.value);
						StatesInsertedParameters = EmbeddedParameter.parameters.parameter;
						StateIdentifier       = Undefined;
						
						If StatesInsertedParameters = Undefined Then
							Continue;
						EndIf;
						
						For Each EmbeddedStateParameter IN StatesInsertedParameters Do
							CurrentStateEmbeddedParameterName = Lower(TrimAll(EmbeddedStateParameter.name));
							If CurrentStateEmbeddedParameterName = "id" Then
								StateIdentifier = String(EmbeddedStateParameter.value);
								Break;
							EndIf;
						EndDo;
						
						If StateIdentifier <> Undefined Then
							CountryStatesList.Add(StateIdentifier, StateName);
						EndIf;
						
					EndIf;
					
				EndDo;
				
				If CountryIdentifier <> Undefined Then
					CountriesList.Add(CountryIdentifier, CountryName);
					CountryStatesList.Insert(0, "-1", NStr("en='<Not selected>';ru='<не выбран>'"));
					CountryStates[CountryIdentifier] = CountryStatesList;
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	CountriesList.Insert(0, "-1", NStr("en='<not selected>';ru='<не выбрана>'"));
	
	CommandStructure.Insert("Countries"      , CountriesList);
	CommandStructure.Insert("CountryStates", CountryStates);
	
	Return CommandStructure;
	
EndFunction

// Convert the Write company data
// command to the internal presentation.
//
Function StructuredUserCompaniesRecord(ServerCommand) Export
	
	If ServerCommand.parameters = Undefined Then
		Return Undefined;
	EndIf;
	
	CommandStructure = New Structure;
	
	CompaniesList = New ValueList;
	CompanyData = New Map;
	CommandParameters  = ServerCommand.parameters.parameter;
	
	ParametersCompaniesList = Undefined;
	If CommandParameters.Count() > 0 Then
		InsertedParametersObject = CommandParameters[0].parameters;
		If InsertedParametersObject <> Undefined Then
			ParametersCompaniesList = InsertedParametersObject.parameter;
		EndIf;
	EndIf;
	
	If ParametersCompaniesList <> Undefined Then
		
		For Each Parameter IN ParametersCompaniesList Do
			
			CurrParameterName = Lower(TrimAll(Parameter.name));
			If CurrParameterName = "organization" Then
				
				CompanyName      = String(Parameter.value);
				CompanyID = Undefined;
				CompanyCurrentData     = New Structure;
				
				If Parameter.parameters = Undefined Then
					Continue;
				EndIf;
				
				EmbeddedParameters = Parameter.parameters.parameter;
				
				For Each EmbeddedParameter IN EmbeddedParameters Do
					
					CurrentEmbeddedParameterName = Lower(TrimAll(EmbeddedParameter.name));
					If CurrentEmbeddedParameterName = "id" Then
						CompanyID = String(EmbeddedParameter.value);
					Else
						CompanyCurrentData.Insert(CurrentEmbeddedParameterName, String(EmbeddedParameter.value));
					EndIf;
					
				EndDo;
				
				If CompanyID <> Undefined Then
					CompaniesList.Add(CompanyID, CompanyName);
					CompanyCurrentData.Insert("CompanyName", CompanyName);
					CompanyData[CompanyID] = CompanyCurrentData;
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	CompaniesList.Insert(0, "-1", NStr("en='<add a new company>';ru='<добавить новую организацию>'"));
	
	CommandStructure.Insert("CompaniesList", CompaniesList);
	CommandStructure.Insert("CompanyData", CompanyData);
	
	Return CommandStructure;
	
EndFunction

#EndIf

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for service commands dataprocessors

// Running the Write parameters command.
//
Procedure ParametersRecordCommandExecution(COPContext, CommandStructure, HandlerContext) Export
	
	If TypeOf(CommandStructure) = Type("Structure") Then
		ParametersRecorded = CommandStructure.Parameters;
	Else
		ParametersRecorded = CommandStructure;
	EndIf;
	
	CommonStartParameters = New Map; // Parameters written to IR
	For Each Parameter IN ParametersRecorded Do
		
		// Save parameters as session parameters
		WriteContextParameter(
			COPContext,
			Parameter.Name,
			Parameter.Value,
			Parameter.Scope,
			CommonStartParameters);
		
	EndDo;
	
	If CommonStartParameters.Count() > 0 Then
		OnlineUserSupportServerCall.WriteCommonStartParametersVRSOUS(CommonStartParameters);
		AuthorizedUserLogin = CommonStartParameters.Get("login");
		If AuthorizedUserLogin <> Undefined Then
			HandlerContext.AdditProperties.Insert("UserLoginChanged",
				AuthorizedUserLogin);
		EndIf;
	EndIf;
	
EndProcedure

// Running the Read parameters command. Parameters
// are being read and sent to service by calling the process() method.
//
Procedure ReadParametersCommandExecution(
	InteractionContext,
	CommandStructure,
	HandlerContext,
	ExecutionOnServer) Export
	
	ParameterArray = CommandStructure.Parameters;
	QueryParameters = New Array;
	
	COPContext        = InteractionContext.COPContext;
	MainParameters = COPContext.MainParameters;
	
	For Each Parameter IN ParameterArray Do
		
		If Parameter.Name = "session_id" Then
			SessionNumberAlreadyExists = True;
		EndIf;
		
		ParameterValue = SessionParameterValue(COPContext, Parameter.Name);
		
		TransferredPapameter = New Structure("Name, Value, BusinessProcess, Scope",
			Parameter.Name,
			ParameterValue,
			MainParameters.WSDefinitionName,
			Parameter.Scope);
		
		QueryParameters.Add(TransferredPapameter);
		
	EndDo;
	
	AddSessionParametersToQuery(COPContext, , QueryParameters);
	
	If ExecutionOnServer Then
		OnlineUserSupportServerCall.AddServiceCommands(
			MainParameters,
			QueryParameters,
			HandlerContext);
	Else
		#If Client Then
		// Access the web service for commands and write them to the commands stack
		OnlineUserSupportClient.AddServiceCommands(
			InteractionContext,
			QueryParameters,
			HandlerContext);
		#EndIf
	EndIf;
	
EndProcedure

// Run the Write address classifier command.
//
Procedure WriteAddressClassifier(COPContext, CommandStructure) Export
	
	COPContext.RegistrationContext.Insert("Countries"      , CommandStructure.Countries);
	COPContext.RegistrationContext.Insert("CountryStates", CommandStructure.CountryStates);
	
EndProcedure

// Running the Write companies data command.
//
Procedure WriteCompaniesList(COPContext, CommandStructure) Export
	
	COPContext.RegistrationContext = New Structure;
	COPContext.RegistrationContext.Insert("CompaniesList", CommandStructure.CompaniesList);
	COPContext.RegistrationContext.Insert("CompanyData", CommandStructure.CompanyData);
	
EndProcedure

// Returns the command type - client or server.
//
// Parameters:
// CommandStructure - Structure - UOS service in the internal presentation.
//
// Returns:
// Number - command type: -1 - unknown type of command, 0 - executed
// 	on server, 1 - executed on client.
//
Function CommandType(CommandStructure, CallFromServer, LaunchLocation) Export
	
	If CommandStructure = Undefined Then
		Return -1; // Unknown command type
	EndIf;
	
	CommandName = Lower(TrimAll(CommandStructure.CommandName));
	
	If CommandName = "store.put"
		OR CommandName = "store.get"
		OR CommandName = "store.delete"
		OR CommandName = "launchservice"
		OR CommandName = "store.putorganizations"
		OR CommandName = "store.putadressclassifier" Then
		
		Return ?(CallFromServer, 0, 1);
		
	ElsIf CommandStructure.CommandName = "ui.open"
		OR CommandName = "ui.close"
		OR CommandName = "performtheaction.decode"
		OR CommandName = "message.show"
		OR CommandName = "question.show"
		OR CommandName = "input.field"
		OR CommandName = "system.halt" Then
		
		Return 1;
		
	Else
		
		Result = -1;
		Handler = BusinessProcessHandler(LaunchLocation, "CommandExecutionContext");
		If Handler <> Undefined Then
			Handler.CommandExecutionContext(CommandName, CallFromServer, Result);
		EndIf;
		
		Return Result;
		
	EndIf;
	
EndFunction

// Function creates and returns context specifier of the service commands handler.
//
// Returns:
// Structure - structure with properties:
// * Commands - Array - stack of service commands in the internal presentation;
// * MakeStop - Boolean - if True, then you
// 	need to stop the UOS mechanism;
// * ErrorOccurred - Boolean - an error occurred during accessing cycle
// 	of the UOS web service;
// * FullErrorDescription - String - full description of the
// 	error for the events log monitor;
// * CustomErrorDescription - String - error
// 	presentation for a user;
// * ActionsOnErrorForServer - Array - Item array of the String type -
// 	names of action that are required to be executed on 1C: Enterprise server;
// ActionOnErrorForClient - String - action that should be
// 	executed on the side of the 1C:Enterprise client if an error occurs;
// * AdditProperties - Structure - structure with additional
// 	data of the commands handler;
//
Function NewCommandsHandlerContext() Export
	
	HandlerContext = New Structure;
	HandlerContext.Insert("Commands"                       , New Array);
	HandlerContext.Insert("MakeStop"            , False);
	HandlerContext.Insert("ErrorOccurred"               , False);
	HandlerContext.Insert("FullErrorDescription"          , "");
	HandlerContext.Insert("UserErrorDescription", "");
	HandlerContext.Insert("ActionsOnErrorForServer"   , New Array);
	HandlerContext.Insert("ActionOnErrorForClient"   , "");
	HandlerContext.Insert("ExchangeLog"                , "");
	HandlerContext.Insert("AdditProperties"                   , New Structure);
	
	Return HandlerContext;
	
EndFunction

#If Not WebClient Then

// Calls the process() operation of UOS service. All necessary
// query parameters are passed during a call.
//
// Parameters:
// WSDefinition - Structure - see the NewUOSServiceDescription() function.
// TransferedQueryParameters - Array - array of Structure-type items:
// * Value - String, BinaryData, Undefined - parameter value;
// * Scope - String - parameter visible area;
// * BusinessProcess - String - name of the business process;
// HandlerContext - Structure - see the NewCommandsHandlerContext function();
// MainParameters - Structure - main parameters of the interaction context;
//
Procedure AddServiceCommands(
	WSDefinition,
	TransferedQueryParameters,
	HandlerContext,
	MainParameters) Export
	
	OfURIService = WSDefinition.OfURIService;
	
	TypeQuery       = WSDefinition.XDTOFactory.Type(OfURIService, "Parameters");
	QueryParameters = WSDefinition.XDTOFactory.Create(TypeQuery);
	
	AnswerType        = WSDefinition.XDTOFactory.Type(OfURIService, "ProcessResponseType");
	ServerResponse     = WSDefinition.XDTOFactory.Create(AnswerType);
	
	TypeParameter = WSDefinition.XDTOFactory.Type(OfURIService, "Parameter");
	
	// Add the query parameters
	If TransferedQueryParameters <> Undefined Then
		
		ParameterIndex = 0;
		BinaryDataType = Type("BinaryData");
		For Each TransferredParameter IN TransferedQueryParameters Do
			
			If TypeOf(TransferredParameter.Value) <> BinaryDataType Then
				ParameterValue = TrimAll(String(TransferredParameter.Value));
			Else
				Try
					ParameterValue = TextInBinaryData(TransferredParameter.Value);
				Except
					InfError = ErrorInfo();
					ErrorMessage = StrReplace(NStr("en='An error occurred while converting transferred data. %1';ru='Ошибка при преобразовании передаваемых данных. %1'"),
						"%1",
						DetailErrorDescription(InfError));
					Raise ErrorMessage;
				EndTry;
			EndIf;
			
			// Define object of the parameter (XDTO Object).
			Parameter = WSDefinition.XDTOFactory.Create(TypeParameter);
			
			Parameter.name  = TrimAll(TransferredParameter.Name);
			Parameter.value = ParameterValue;
			Parameter.index = ParameterIndex;
			
			BusinessProcess = Undefined;
			TransferredParameter.Property("BusinessProcess", BusinessProcess);
			If BusinessProcess <> Undefined Then 
				Parameter.bp = TrimAll(BusinessProcess);
			EndIf;
			
			If TransferredParameter.Property("EmbeddedParameters")
				AND TypeOf(TransferredParameter.EmbeddedParameters) = Type("Array") Then
				AddInsertedParameters(
					Parameter,
					TransferredParameter.EmbeddedParameters,
					WSDefinition,
					TypeParameter,
					TypeQuery);
			EndIf;
			
			QueryParameters.parameter.Add(Parameter);
			
			ParameterIndex = ParameterIndex + 1;
			
		EndDo;
		
	EndIf;
	
	ServerResponse = Undefined;
	
	// Execution of the process method of the WEB-Service.
	ServerResponse = OUSService_process(QueryParameters, WSDefinition);
	
	// If there is no context, do not structure anything as commands will
	// not be executed as there is no need for feedback (used, for
	// example, to close business process to release resources on server).
	If HandlerContext = Undefined Then
		Return;
	EndIf;
	
	// Convert server response from the XDTO object to the structures array
	CommandsStructureArray = StructureServerResponse(
		MainParameters,
		ServerResponse,
		HandlerContext);
	
	If HandlerContext.ErrorOccurred Then
		Return;
	EndIf;
	
	If CommandsStructureArray = Undefined OR CommandsStructureArray.Count() = 0 Then
		Raise NStr("en='Empty server response.';ru='Пустой ответ сервера.'");
	EndIf;
	
	// Insert commands to the beginning of the commands stack
	ServerCommandsNumber = CommandsStructureArray.Count();
	For ReverseIndex = 1 To ServerCommandsNumber Do
		HandlerContext.Commands.Insert(0, CommandsStructureArray[ServerCommandsNumber - ReverseIndex]);
	EndDo;
	
EndProcedure

#EndIf

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for work with parameters in the interaction context

// Creates description of UOS parameter.
// Parameters:
// Name - String - parameter name;
// Value - String - parameter value;
// Scope - String - area of the
// 	parameter visible (session or launch);
//
// Returns:
// Structure - description of the parameter with fields:
// * Name - String - parameter name;
// * Value - String - parameter value;
// * Scope - String - parameter visible area;
//
Function NewParameterOUS(Name, Value, Scope) Export
	
	Return New Structure("Name, Value, Scope",
		Name,
		Value,
		Scope);
	
EndFunction

// Write session or launch parameter. Launch parameters
// are also written to the OnlineUserSupportParameters information register.
//
Procedure WriteContextParameter(
	COPContext,
	ParameterName,
	ParameterValue,
	Scope = "",
	CommonStartParameters = Undefined) Export
	
	ThisIsStartupParameter = (Lower(Scope) = "startup");
	SessionalParameters = COPContext.SessionalParameters;
	
	Parameter = SessionalParameters.Get(ParameterName);
	
	RecordedScope = ?(ThisIsStartupParameter, "startUp", "");
	
	If Parameter <> Undefined Then
		Parameter.Value = ParameterValue;
		Parameter.Scope = RecordedScope;
	Else
		Parameter = NewParameterOUS(ParameterName, ParameterValue, RecordedScope);
		SessionalParameters.Insert(ParameterName, Parameter);
	EndIf;
	
	// If it is the launch parameter, it
	// is saved for all users to the information register
	If ThisIsStartupParameter AND CommonStartParameters <> Undefined Then
		CommonStartParameters.Insert(ParameterName, ParameterValue);
	EndIf;
	
EndProcedure

// Delete the context parameters. Launch parameters are also
// removed from the OnlineUserSupportParameters information register.
//
Procedure DeleteContextParameters(COPContext, CommandStructure, HandlerContext) Export
	
	SessionalParameters = COPContext.SessionalParameters;
	
	If TypeOf(CommandStructure) = Type("Structure") Then
		If CommandStructure.Property("Parameters") Then
			ParameterArray = CommandStructure.Parameters;
		Else
			ParameterArray = New Array;
			ParameterArray.Add(CommandStructure);
		EndIf;
	ElsIf TypeOf(CommandStructure) = Type("Array") Then
		ParameterArray = CommandStructure;
	Else
		Return;
	EndIf;
	
	DeletedFromRS = New Map;
	
	For Each CommandParameter IN ParameterArray Do
		
		If CommandParameter = Undefined Then
			Continue;
		EndIf;
		
		SessionalParameters.Delete(CommandParameter.Name);
		
		// If it is the launch parameter, then it is removed from the UOS parameters register
		If CommandParameter.Property("Scope") AND Lower(CommandParameter.Scope) = "startup" Then
			DeletedFromRS.Insert(CommandParameter.Name, True);
		EndIf;
		
	EndDo;
	
	If DeletedFromRS.Count() > 0 Then
		
		If DeletedFromRS.Get("login") = True Then
			HandlerContext.AdditProperties.Insert("UserLoginChanged", "");
		EndIf;
		
		OnlineUserSupportServerCall.DeleteParametersFromRegister(DeletedFromRS);
		
	EndIf;
	
EndProcedure

// Returns the value of the context parameter.
//
Function SessionParameterValue(COPContext, ParameterName) Export
	
	SessionalParameters = COPContext.SessionalParameters;
	MainParameters   = COPContext.MainParameters;
	
	ParameterValue = Undefined;
	
	If ParameterName = "libraryVersion" Then
		ParameterValue = LibraryVersion();
		
	ElsIf ParameterName = "APIVersion" Then
		ParameterValue = InteractionAPIVersion();
		
	ElsIf ParameterName = "versionPlatform" Then
		SysInfo = New SystemInfo;
		ParameterValue = SysInfo.AppVersion;
		
	ElsIf ParameterName = "nameConfiguration" Then
		ParameterValue = OnlineUserSupportClientServer.ConfigurationName();
		
	ElsIf ParameterName = "versionConfiguration" Then
		ParameterValue = OnlineUserSupportClientServer.ConfigurationVersion();
		
	ElsIf ParameterName = "language" Then
		ParameterValue = OnlineUserSupportClientServer.CurrentLocalisationCode();
		
	ElsIf ParameterName = "enterPoint" Then
		ParameterValue = TrimAll(MainParameters.LaunchLocation);
		
	ElsIf ParameterName = "versionUpdateConfiguration" Then
		
		ParameterValue = OnlineUserSupportClientServer.UpdateProcessorVersion();
		
	Else
		
		ParameterSpecifier = SessionalParameters.Get(ParameterName);
		If ParameterSpecifier <> Undefined Then
			Return ParameterSpecifier.Value;
		EndIf;
		
	EndIf;
	
	Return ParameterValue;
	
EndFunction

// Adds the inserted parameters to the query parameters.
//
Procedure AddInsertedParameters(
	Parameter,
	EmbeddedParametersArray,
	WSDefinition,
	TypeParameter,
	TypeParameters) Export
	
	Parameter.parameters = WSDefinition.XDTOFactory.Create(TypeParameters);
	
	IndexOf = 0;
	For Each TransferredParameter IN EmbeddedParametersArray Do
		
		EmbeddedParameter = WSDefinition.XDTOFactory.Create(TypeParameter);
		
		EmbeddedParameter.name  = TrimAll(TransferredParameter.Name);
		EmbeddedParameter.value = TrimAll(TransferredParameter.Value);
		EmbeddedParameter.index = IndexOf;
		
		If TransferredParameter.Property("BusinessProcess") Then
			Parameter.bp = TrimAll(TransferredParameter.BusinessProcess);
		EndIf;
		
		Parameter.parameters.parameter.Add(EmbeddedParameter);
		
		If TransferredParameter.Property("EmbeddedParameters")
			AND TypeOf(TransferredParameter.EmbeddedParameters) = Type("Array") Then
			
			AddInsertedParameters(
				EmbeddedParameter,
				TransferredParameter.EmbeddedParameters,
				WSDefinition,
				TypeParameter,
				TypeParameters);
			
		EndIf;
		
		IndexOf = IndexOf + 1;
		
	EndDo;
	
EndProcedure

// Returns session parameters required
// for decrypting control DS marker.
//
Function SessionParametersForDecryption(COPContext) Export
	
	Result = New Structure;
	Result.Insert("markerED",
		SessionParameterValue(COPContext, "markerED"));
	Result.Insert("IDDSCertificate_Dop",
		SessionParameterValue(COPContext, "IDDSCertificate_Dop"));
	Result.Insert("IDDSCertificate",
		SessionParameterValue(COPContext, "IDDSCertificate"));
	
	Return Result;
	
EndFunction

// Add the session parameters to the query parameters
// when the process()operation of UOS service is called.
//
Procedure AddSessionParametersToQuery(
	COPContext,
	SessionParametersNames = Undefined,
	QueryParameters) Export
	
	If QueryParameters = Undefined Then
		QueryParameters = New Array;
	EndIf;
	
	MainParameters = COPContext.MainParameters;
	
	SessionIdentifierAdded = False;
	If SessionParametersNames <> Undefined Then
		
		For Each ParameterName IN SessionParametersNames Do
			
			ParameterValue = SessionParameterValue(COPContext, ParameterName);
			
			SessionalParameter = New Structure("Name, BusinessProcess, Value, Scope",
				ParameterName,
				MainParameters.WSDefinitionName,
				ParameterValue,
				"sessionParameter");
			
			QueryParameters.Add(SessionalParameter);
			
			If ParameterName = "session_id" Then
				SessionIdentifierAdded = True;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Not SessionIdentifierAdded Then
		
		OUSSessionIdentifier = SessionParameterValue(COPContext, "session_id");
		
		SessionalParameter = New Structure("Name, BusinessProcess, Value, Scope",
			"session_id",
			MainParameters.WSDefinitionName,
			OUSSessionIdentifier,
			"sessionParameter");
		
		QueryParameters.Add(SessionalParameter);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions for interaction with UOS service

#If Not WebClient Then

// Sending email to the support.
//
Function SendEmailThroughService(MessageStructure, OUSNetworkParameters) Export
	
	Try
		MailOUSServiceDescription = NewOUSServiceDescription(WSDefinitionName(), OUSNetworkParameters);
		
		TypeQuery       = MailOUSServiceDescription.XDTOFactory.Type(MailOUSServiceDescription.OfURIService, "Parameters");
		QueryParameters = MailOUSServiceDescription.XDTOFactory.Create(TypeQuery);
		
		TypeParameter = MailOUSServiceDescription.XDTOFactory.Type(MailOUSServiceDescription.OfURIService, "Parameter");
		
		// Initialization of the email parameters
		Parameter2 = MailOUSServiceDescription.XDTOFactory.Create(TypeParameter);
		Parameter3 = MailOUSServiceDescription.XDTOFactory.Create(TypeParameter);
		Parameter4 = MailOUSServiceDescription.XDTOFactory.Create(TypeParameter);
		
		Parameter2.name  = "subject";
		Parameter2.value = MessageStructure.Subject;
		QueryParameters.parameter.Add(Parameter2);
		
		Parameter3.name  = "text";
		Parameter3.value = MessageStructure.Message;
		QueryParameters.parameter.Add(Parameter3);
		
		Parameter4.name  = "from";
		Parameter4.value = MessageStructure.FromWhom;
		QueryParameters.parameter.Add(Parameter4);
		
		ConditionalRecipientName = Undefined;
		If MessageStructure.Property("ConditionalRecipientName", ConditionalRecipientName) Then
			Parameter5 = MailOUSServiceDescription.XDTOFactory.Create(TypeParameter);
			Parameter5.name  = "aliasto";
			Parameter5.value = ConditionalRecipientName;
			QueryParameters.parameter.Add(Parameter5);
		EndIf;
		
		Response = OUSService_sendmailtonet(QueryParameters, MailOUSServiceDescription);
	Except
		OnlineUserSupportServerCall.WriteErrorInEventLogMonitor(
			NStr("en='An error occurred while sending the email.';ru='Ошибка при отправке электронного письма.'")
				+ " " + DetailErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

#EndIf

////////////////////////////////////////////////////////////////////////////////
// Other service procedures and functions

// Returns the configuration name.
Function ConfigurationName() Export
	
	#If Client Then
	OUSParameters = StandardSubsystemsClientReUse.ClientWorkParameters().OnlineUserSupport;
	Return OUSParameters.ConfigurationName;
	#Else
	Return Metadata.Name;
	#EndIf
	
EndFunction

// Returns the configuration version.
Function ConfigurationVersion() Export
	
	#If Client Then
	OUSParameters = StandardSubsystemsClientReUse.ClientWorkParameters().OnlineUserSupport;
	Return OUSParameters.ConfigurationVersion;
	#Else
	Return Metadata.Version;
	#EndIf
	
EndFunction

// Returns the current localization code.
Function CurrentLocalisationCode() Export
	
	#If Client Then
	OUSParameters = StandardSubsystemsClientReUse.ClientWorkParameters().OnlineUserSupport;
	Return OUSParameters.LocaleCode;
	#Else
	Return CurrentLocaleCode();
	#EndIf
	
EndFunction

// It returns DataProcessors version for the configuration update.
Function UpdateProcessorVersion() Export
	
	#If Client Then
	OUSParameters = StandardSubsystemsClientReUse.ClientWorkParameters().OnlineUserSupport;
	Return OUSParameters.UpdateProcessorVersion;
	#Else
	Return OnlineUserSupport.UpdateProcessorVersion();
	#EndIf
	
EndFunction

// Defines if the business process on the
// specified entry point is processed with the basic functionality ISL.
//
// Parameters:
// LaunchLocation - String - entry point to the business process.
//
// Returns:
// Boolean - True if the business process processes
// 	OSL using the base functionality, False - otherwise.
//
Function ThisIsBaseBusinessProcess(LaunchLocation) Export
	
	Return (LaunchLocation = "connectIPP");
	
EndFunction

// Returns the specified handler of the
// business process in the current context (client or server)
//
Function BusinessProcessHandler(LaunchLocation, EventName)
	
	#If Client Then
	Return OnlineUserSupportClient.BusinessProcessClientHandler(
		LaunchLocation,
		EventName);
	#Else
	Return OnlineUserSupport.BusinessProcessServerHandler(
		LaunchLocation,
		EventName);
	#EndIf
	
EndFunction

#If Not WebClient Then

// Receives the content of binary data in the form of text.
// Parameters:
// BinaryData - BinaryData - binary data the
// content of which is required to be received in the form of text.
//
// Returns:
// String - text in binary data;
//
Function TextInBinaryData(BinaryData) Export
	
	Result = "";
	
	If TypeOf(BinaryData) <> Type("BinaryData") Then
		Return "";
	EndIf;
	
	TempFileName = GetTempFileName("txt");
	BinaryData.Write(TempFileName);
	TexDoc = New TextDocument;
	TexDoc.Read(TempFileName, , "");
	Result = TexDoc.GetText();
	
	Try
		DeleteFiles(TempFileName);
	Except
	EndTry;
	
	Return Result;
	
EndFunction

#EndIf

#EndRegion
