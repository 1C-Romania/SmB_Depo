////////////////////////////////////////////////////////////////////////////////
// Subsystem "Receiving files from the Internet".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// It returns the InternetProxy object for Internet access.
//
// Parameters:
//   URLOrProtocol - String - URL in the format [Protocol://]<Server>/<Path to
//                            the file on the server> or the protocol identifier (http, ftp, ...).
//
// Returns:
//   InternetProxy
//
Function GetProxy(Val URLOrProtocol) Export
	
#If Client Then
	ProxyServerSetting = StandardSubsystemsClientReUse.ClientWorkParameters().ProxyServerSettings;
#Else
	ProxyServerSetting = GetFilesFromInternet.ProxySettingsOnServer();
#EndIf
	If Find(URLOrProtocol, "://") > 0 Then
		Protocol = SplitURL(URLOrProtocol).Protocol;
	Else
		Protocol = Lower(URLOrProtocol);
	EndIf;
	Return GenerateInternetProxy(ProxyServerSetting, Protocol);
	
EndFunction

// It divides the URL into parts: protocol, server, path to resource.
//
// Parameters:
//  URL - String - resource reference in the Internet.
//
// Returns:
//  Structure:
//             Protocol            - String - resource access protocol.
//             ServerName          - String - server on which the resource is located.
//             PathToFileAtServer  - String - path to the resource on the server.
//
Function SplitURL(Val URL) Export
	
	URLStructure = CommonUseClientServer.URLStructure(URL);
	
	Result = New Structure;
	Result.Insert("Protocol", ?(IsBlankString(URLStructure.Schema), "http", URLStructure.Schema));
	Result.Insert("ServerName", URLStructure.ServerName);
	Result.Insert("PathToFileAtServer", URLStructure.PathAtServer);
	
	Return Result;
	
EndFunction

// Dissembles URI string and returns it as a structure.
//
Function URLStructure(Val URLString) Export
	
	Return CommonUseClientServer.URLStructure(URLString);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export service procedures and functions.

// The function used to receive the file from the Internet.
//
// Parameters:
// URL           - String - file url in the format.:
// ReceivingSettings   - Structure with properties.
//     PathForSave       - String  - path on server (including attachment file name) to save imported file.
//     User              - String  - user on whose behalf the connection is established.
//     Password          - String  - password of the user from which the connection is set.
//     Port              - Number  - server port with which the connection is set.
//     Timeout           - Number  - timeout on receiving file in seconds.
//     SecureConnection  - Boolean - in case of http import
//                                  the flaf shows that the connection should be executed via https.
//     PassiveConnection - Boolean - for the ftp import, the
//                                     flag shows that connection must be passive (or active).
//     Headers           - Map - see the description of the Titles parameter of the HTTPRequest object.
//
// SaveSetting - Map - contains parameters for saving
//                 the exported file keys:
//                 Storage - String - may contain
//                        "Client" - client,
//                        "Server" - server,
//                        "TempStorage" - temporary storage.
//                 Path    - String (optional parameter) - 
//                           path to directory on the client or server or the address
//                           in the temporary storage if it is not set automatically generated.
//
// Returns:
// structure  
// success - Boolean - operation success or failure 
// string  - String  - in case of success either path-string
//                     for the file saving or
//                     address in the temporary storage, in case of failure the message of an error.
//
Function PrepareFileReceiving(Val URL, Val ReceivingSettings, Val SaveSetting, Val RecordError = True) Export
	
	ConnectionOptions = New Map;
	ConnectionOptions.Insert("User", ReceivingSettings.User);
	ConnectionOptions.Insert("Password",       ReceivingSettings.Password);
	ConnectionOptions.Insert("Port",         ReceivingSettings.Port);
	ConnectionOptions.Insert("Timeout",      ReceivingSettings.Timeout);
	ConnectionOptions.Insert("SecureConnection", ReceivingSettings.SecureConnection);
	
	Protocol = SplitURL(URL).Protocol;
	
	If Protocol = "ftp" Or Protocol = "ftps" Then
		ConnectionOptions.Insert("PassiveConnection", ReceivingSettings.PassiveConnection);
	Else
		ConnectionOptions.Insert("Headers",    ReceivingSettings.Headers);
	EndIf;
	
#If Client Then
	ProxyServerSetting = StandardSubsystemsClientReUse.ClientWorkParameters().ProxyServerSettings;
#Else
	ProxyServerSetting = GetFilesFromInternet.ProxySettingsOnServer();
#EndIf
	
	Return GetFileFromInternet(URL, SaveSetting, ConnectionOptions,
		ProxyServerSetting, RecordError);
	
EndFunction

Function StructureParametersReceivingFile() Export
	
	ReceivingParameters = New Structure;
	ReceivingParameters.Insert("PathForSave", Undefined);
	ReceivingParameters.Insert("User", Undefined);
	ReceivingParameters.Insert("Password", Undefined);
	ReceivingParameters.Insert("Port", Undefined);
	ReceivingParameters.Insert("Timeout", Undefined);
	ReceivingParameters.Insert("SecureConnection", Undefined);
	ReceivingParameters.Insert("PassiveConnection", Undefined);
	ReceivingParameters.Insert("Headers", New Map());
	
	Return ReceivingParameters;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local service procedures and functions.

// The function used to receive the file from the Internet.
//
// Parameters:
// URL - String - file URL in the format: [Protocol://]<Server>/<File path on the server>.
//
// ConnectionOptions - Map -
// 	SecuredConnection* - Boolean - secured connection.
// 	PassiveConnection*  - Boolean - secured connection.
// 	User - String - user on whose behalf the connection is established.
// 	Password       - String - password of the user from which the connection is set.
// 	Port           - Number - server port with which the connection is set
// 	* - mutually exclusive keys.
//
// ProxySettings - Map:
// 	UseProxy - whether to use a proxy server.
// 	BypassProxyOnLocal - whether to use a proxy server for local addresses.
// 	UseSystemSettings - whether to use proxy server system settings.
// 	Server   - proxy server address.
// 	Port     - proxy server port.
// 	User     - user name for authorization on a proxy server.
// 	Password - user's password.
//
// SaveSetting - Map - contains parameters for saving the exported file.
// 	StoragePlace - String - may contain 
//    "Client" - client,
// 		"Server" - server,
// 		"TempStorage" - temporary storage.
// 	Path - String (optional parameter) - path to the directory on client or server, or the address in the temprorary storage if it is not set automatically generated.
//
// Returns:
// structure  
// success - Boolean - operation success or failure
// string - String - in case of success either path-string
//                   for the file saving or
//                   address in the temporary storage, in case of failure the message of an error.
//
Function GetFileFromInternet(Val URL, Val SaveSetting, Val ConnectionOptions = Undefined,
	Val ProxySettings = Undefined, Val RecordError = True)
	
	// Variable declaration as the Property
	// method parameter before first use when analyzing parameters
	// of file receiving from ReceivingParameters. It contains values of the transferred parameters for the file receiving.
	Var ServerName, UserName, Password, Port,
	      SecureConnection,PassiveConnection,
	      PathToFileAtServer, Protocol;
	
	URLSplitted = SplitURL(URL);
	
	ServerName           = URLSplitted.ServerName;
	PathToFileAtServer  = URLSplitted.PathToFileAtServer;
	Protocol             = URLSplitted.Protocol;
	
	SecureConnection = ConnectionOptions.Get("SecureConnection");
	PassiveConnection  = ConnectionOptions.Get("PassiveConnection");
	
	UserName      = ConnectionOptions.Get("User");
	UserPassword   = ConnectionOptions.Get("Password");
	Port                 = ConnectionOptions.Get("Port");
	Timeout              = ConnectionOptions.Get("Timeout");
	Headers            = ConnectionOptions.Get("Headers");
	
	If (Protocol = "https" Or Protocol = "ftps") AND SecureConnection = Undefined Then
		SecureConnection = True;
	EndIf;
	
	If SecureConnection = True Then
		SecureConnection = New OpenSSLSecureConnection;
	ElsIf SecureConnection = False Then
		SecureConnection = Undefined;
	// Else SecureConnection parameter was explicitly set.
	EndIf;
	
	If Port = Undefined Then
		FullURLStructure = CommonUseClientServer.URLStructure(URL);
		If Not IsBlankString(FullURLStructure.Port) Then
			ServerName = FullURLStructure.Host;
			Port = FullURLStructure.Port;
		EndIf;
	EndIf;
	
	Proxy = ?(ProxySettings <> Undefined, GenerateInternetProxy(ProxySettings, Protocol), Undefined);
	FTPProtocolIsUsed = (Protocol = "ftp" Or Protocol = "ftps");
	
	If FTPProtocolIsUsed Then
		Try
			Join = New FTPConnection(ServerName, Port, UserName, UserPassword,
				Proxy, PassiveConnection, Timeout, SecureConnection);
		Except
			ErrorInfo = ErrorInfo();
			ErrorInfo = NStr("en='Cannot establish FTP connection with server %1:';ru='Не удалось установить FTP-соединение с сервером %1:'") + Chars.LF + "%2";
			
			WriteErrorInEventLogMonitor(StringFunctionsClientServer.SubstituteParametersInString(
				ErrorInfo, ServerName, DetailErrorDescription(ErrorInfo)));
			ErrorInfo = StringFunctionsClientServer.SubstituteParametersInString(ErrorInfo, ServerName,
					BriefErrorDescription(ErrorInfo));
			Return GenerateResult(False, ErrorInfo);
		EndTry;
		
	Else
		
		Try
			Join = New HTTPConnection(ServerName, Port, UserName, UserPassword, Proxy, Timeout, SecureConnection);
		Except
			ErrorInfo = ErrorInfo();
			ErrorInfo = NStr("en='Cannot establish HTTP connection with the %1 server:';ru='Не удалось установить HTTP-соединение с сервером %1:'") + Chars.LF + "%2";
			WriteErrorInEventLogMonitor(
				StringFunctionsClientServer.SubstituteParametersInString(ErrorInfo, ServerName, 
					DetailErrorDescription(ErrorInfo)));
			ErrorInfo = StringFunctionsClientServer.SubstituteParametersInString(ErrorInfo, ServerName, 
					BriefErrorDescription(ErrorInfo));
			Return GenerateResult(False, ErrorInfo);
		EndTry;
	EndIf;
	
	If SaveSetting["Path"] <> Undefined Then
		PathForSave = SaveSetting["Path"];
	Else
		#If Not WebClient Then
			PathForSave = GetTempFileName();
		#EndIf
	EndIf;
	
	Try
		
		If FTPProtocolIsUsed Then
			Join.Get(PathToFileAtServer, PathForSave);
			ResponseHeaders = Undefined;
		Else
			
			HTTPResponse = GetHTTPResponse(PathToFileAtServer, PathForSave, Join, Headers);
			
			If HTTPResponse.StatusCode < 200 Or HTTPResponse.StatusCode >= 300 Then
				ResponseFile = New TextReader(PathForSave, TextEncoding.UTF8);
				Raise StringFunctionsClientServer.ExtractTextFromHTML(ResponseFile.Read(5 * 1024));
			EndIf;
			
			ResponseHeaders = HTTPResponse.Headers;
			
		EndIf;
		
	Except
		ErrorInfo = ErrorInfo();
		ErrorInfo = NStr("en='Cannot receive the file from server %1:';ru='Не удалось получить файл с сервера %1:'") + Chars.LF + "%2";
		If RecordError Then
			WriteErrorInEventLogMonitor(
				StringFunctionsClientServer.SubstituteParametersInString(ErrorInfo, ServerName, 
				DetailErrorDescription(ErrorInfo)));
		EndIf;
		Return GenerateResult(False, BriefErrorDescription(ErrorInfo));
	EndTry;
	
	// If the file is saved based on the setting.
	If SaveSetting["StoragePlace"] = "TempStorage" Then
		UniqueKey = New UUID;
		Address = PutToTempStorage (New BinaryData(PathForSave), UniqueKey);
		Return GenerateResult(True, Address, ResponseHeaders);
	ElsIf SaveSetting["StoragePlace"] = "Client"
	      OR SaveSetting["StoragePlace"] = "Server" Then
		Return GenerateResult(True, PathForSave, ResponseHeaders);
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function GetHTTPResponse(PathToFileAtServer, PathForSave, Join, Headers)
	
	HTTPRequest = New HTTPRequest(PathToFileAtServer, Headers);
	HTTPRequest.Headers.Insert("Accept-Charset", "utf-8");
	HTTPResponse = Join.Get(HTTPRequest, PathForSave);
	
	If HTTPResponse.StatusCode = 301 Then
		PathToFileAtServer = HTTPResponse.Headers["Location"];
		HTTPResponse = GetHTTPResponse(PathToFileAtServer, PathForSave, Join, Headers);
	EndIf;
	
	Return HTTPResponse;
	
EndFunction


// It returns the proxy based on ProxyServerSetting settings for the specified Protocol protocol.
// 
// Parameters:
//   ProxyServerSetting - Map:
// 	UseProxy - whether to use a proxy server.
// 	BypassProxyOnLocal - whether to use a proxy server for local addresses.
// 	UseSystemSettings - whether to use proxy server system settings.
// 	Server   - proxy server address.
// 	Port     - proxy server port.
// 	User     - user name for authorization on a proxy server.
// 	Password - user's password.
//   Protocol - String - the protocol for which the proxy server parameters are
//                       set, for example, http, https, ftp.
// 
// Returns:
//   InternetProxy
// 
Function GenerateInternetProxy(ProxyServerSetting, Protocol)
	
	If ProxyServerSetting = Undefined Then
		// Proxy server system settings.
		Return Undefined;
	EndIf;	
	
	UseProxy = ProxyServerSetting.Get("UseProxy");
	If Not UseProxy Then
		// Do not use proxy server.
		Return New InternetProxy(False);
	EndIf;
	
	UseSystemSettings = ProxyServerSetting.Get("UseSystemSettings");
	If UseSystemSettings Then
		// System proxy settings.
		Return New InternetProxy(True);
	EndIf;
			
	// Proxy server settings defined manually.
	Proxy = New InternetProxy;
	
	// Definition of the address and proxy server port.
	AdditionalSettings = ProxyServerSetting.Get("ProxyAdditionalSettings");
	ProxyByProtocol = Undefined;
	If TypeOf(AdditionalSettings) = Type("Map") Then
		ProxyByProtocol = AdditionalSettings.Get(Protocol);
	EndIf;
	
	If TypeOf(ProxyByProtocol) = Type("Structure") Then
		Proxy.Set(Protocol, ProxyByProtocol.Address, ProxyByProtocol.Port);
	Else
		Proxy.Set(Protocol, ProxyServerSetting["Server"], ProxyServerSetting["Port"]);
	EndIf;
	
	Proxy.BypassProxyOnLocal = ProxyServerSetting["BypassProxyOnLocal"];
	Proxy.User = ProxyServerSetting["User"];
	Proxy.Password       = ProxyServerSetting["Password"];
	
	ExceptionsAddresses = ProxyServerSetting.Get("BypassProxyOnAddresses");
	If TypeOf(ExceptionsAddresses) = Type("Array") Then
		For Each ExceptionAddress IN ExceptionsAddresses Do
			Proxy.BypassProxyOnAddresses.Add(ExceptionAddress);
		EndDo;
	EndIf;
			
	Return Proxy;
	
EndFunction

// The function filling the structure based on the parameters.
//
// Parameters:
//  OperationSuccess - Boolean - operation success or failure.
//  MessagePath      - String - 
//
// Returns - structure:
//          success field - Boolean 
//          path field    - String.
//
Function GenerateResult(Val Status, Val MessagePath, ResponseHeaders = Undefined)
	
	Result = New Structure("Status", Status);
	
	If Status Then
		Result.Insert("Path", MessagePath);
	Else
		Result.Insert("ErrorInfo", MessagePath);
	EndIf;
	
	If ResponseHeaders <> Undefined Then
		
		Result.Insert("Headers", ResponseHeaders);
		
	EndIf;
	
	Return Result;
	
EndFunction

// It writes the error event to the log. "Receive
// files from the Internet" event name.
// Parameters:
//   ErrorInfo - error message string.
// 
Procedure WriteErrorInEventLogMonitor(Val ErrorInfo) Export
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	WriteLogEvent(
		EventLogMonitorEvent(),
		EventLogLevel.Error, , ,
		ErrorInfo);
#Else
	EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(),
		"Error", ErrorInfo,,True);
#EndIf
	
EndProcedure

Function EventLogMonitorEvent() Export
	
	Return NStr("en='Receive files from the Internet';ru='Получение файлов из Интернет'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

#EndRegion
