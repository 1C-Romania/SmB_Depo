////////////////////////////////////////////////////////////////////////////////
// Subsystem "Receiving files from the Internet".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Receives file from the Internet by protocol http(s), either ftp and keeps it on specified path at server.
//
// Parameters:
//   URL                   - String - file url in the format [Protocol://]<Server>/<Path to the file on the server>.
//   ReceivingParameters   - Structure with properties:
//      * PathForSave      - String        - path on server (including attachment file name) to save imported file.
//      * User             - String        - user on whose behalf the connection is established.
//      * Password         - String        - password of the user from which the connection is set.
//      * Port             - Number        - server port with which the connection is set.
//      * Timeout          - Number        - timeout on receiving file in seconds.
//      * SecureConnection - Boolean       - the flag of using secure connection ftps or https.
//                         - SecureConnection - see description of  the SecureConnection property of the 
//                           FTPConnection and HTTPConnection objects.
//                         - Undefined - in case if the secure connection is not used.
//      * PassiveConnection  - Boolean       - for the ftp import, the flag shows that connection
//                                              must be passive (or active).
//      * Titles             - Map           - see the description of the Titles parameter of the HTTPRequest object.
//   RecordError   - Boolean - The flag showing that it is necessary to write an error to the event log when receiving a file.
//
// Returns:
//   Structure - Structure with properties:
//      * Status       - Boolean - the result of receiving a file.
//      * Path         - String  - file path on server, key is used only if status is True.
//      * ErrorMessage - String  - error message if the state is False.
//      * Titles       - Map     - see the description of the Titles parameter of the HTTPResponse object.
//
Function ExportFileAtServer(Val URL, ReceivingParameters = Undefined, Val RecordError = True) Export
	
	ReceivingSettings = GetFilesFromInternetClientServer.StructureParametersReceivingFile();
	
	If ReceivingParameters <> Undefined Then
		
		FillPropertyValues(ReceivingSettings, ReceivingParameters);
		
	EndIf;
	
	SaveSetting = New Map;
	SaveSetting.Insert("StoragePlace", "Server");
	SaveSetting.Insert("Path", ReceivingSettings.PathForSave);
	
	Return GetFilesFromInternetClientServer.PrepareFileReceiving(URL,
		ReceivingSettings, SaveSetting, RecordError);
	
EndFunction

// Receives file from the Internet either by http(s) or ftp protocol, and stores it in a temporary storage.
//
// Parameters:
//   URL                 - String - file url in the format [Protocol://]<Server>/<Path to the file on the server>.
//   ReceivingParameters - Structure with properties:
//      * User             - String       - user on whose behalf the connection is established.
//      * Password         - String       - password of the user from which the connection is set.
//      * Port             - Number       - server port with which the connection is set.
//      * Timeout          - Number       - timeout on receiving file in seconds.
//      * SecureConnection - Boolean      - the sign of using secure connection ftps or https.
//                             - SecureConnection - see description of
//                             the SecureConnection property of the FTPConnection and HTTPConnection objects.
//                             - Undefined - in case if the secure connection is not used.
//      * PassiveConnection - Boolean       - for the ftp import, the flag shows that connection
//                                            must be passive (or active).
//      * Titles            - Map - see the description of the Titles parameter of the HTTPRequest object.
//   RecordError   - Boolean - The flag showing that it is necessary to write an error to the event log when receiving a file.
//
// Returns:
//   Structure - Structure with properties:
//      * Status       - Boolean  - the result of receiving a file.
//      * Path         - String   - temporary storage address with file binary data, key is
//                                  used only if status is True.
//      * ErrorMessage - String   - error message if the state is False.
//      * Titles       - Map      - see the description of the Titles parameter of the HTTPResponse object.
//
Function ExportFileToTemporaryStorage(Val URL, ReceivingParameters = Undefined, Val RecordError = True) Export
	
	ReceivingSettings = GetFilesFromInternetClientServer.StructureParametersReceivingFile();
	
	If ReceivingParameters <> Undefined Then
		
		FillPropertyValues(ReceivingSettings, ReceivingParameters);
		
	EndIf;
	
	SaveSetting = New Map;
	SaveSetting.Insert("StoragePlace", "TempStorage");
	
	Return GetFilesFromInternetClientServer.PrepareFileReceiving(URL,
		ReceivingSettings, SaveSetting, RecordError);
	
EndFunction

// Returns the proxy server setting for Internet
// access from the client for current user.
//
// Returns:
//   Map - properties:
// 	UseProxy - whether to use a proxy server.
// 	BypassProxyOnLocal - whether to use a proxy server for local addresses.
// 	UseSystemSettings - whether to use proxy server system settings.
// 	Server            - proxy server address.
// 	Port              - proxy server port.
// 	User              - user name for authorization on a proxy server.
// 	Password          - user's password.
//
Function ProxySettingsAtClient() Export
	
	Return CommonUse.CommonSettingsStorageImport("ProxyServerSetting");
	
EndFunction

// Returns proxy server settings on the side of 1C:Enterprise server.
//
// Returns:
//   Map - properties:
// 	UseProxy - whether to use a proxy server.
// 	BypassProxyOnLocal - whether to use a proxy server for local addresses.
// 	UseSystemSettings - whether to use proxy server system settings.
// 	Server            - proxy server address.
// 	Port              - proxy server port.
// 	User              - user name for authorization on a proxy server.
// 	Password          - user's password.
//
Function ProxySettingsOnServer() Export
	
	If CommonUseReUse.ApplicationRunningMode().File Then
		Return ProxySettingsAtClient();
	Else
		SetPrivilegedMode(True);
		ProxySettingsOnServer = Constants.ProxyServerSetting.Get().Get();
		Return ?(TypeOf(ProxySettingsOnServer) = Type("Map"),
				  ProxySettingsOnServer,
				  Undefined);
	EndIf;
	
EndFunction

// Outdated. You shall use ProxySettingsAtServer.
//
Function GetProxySettingsAt1CEnterpriseServer() Export
	
	Return ProxySettingsOnServer();
	
EndFunction	

// Outdated. You shall use ProxySettingsAtClient.
//
Function GetProxyServerSetting() Export
	
	Return ProxySettingsAtClient();
	
EndFunction

#EndRegion
