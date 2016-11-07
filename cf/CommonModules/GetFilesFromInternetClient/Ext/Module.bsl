////////////////////////////////////////////////////////////////////////////////
// Subsystem "Receiving files from the Internet".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Receives the file from the Internet using http(s), or ftp, and saves it to the specified path on the client.
//
// Parameters:
//   URL                 - String - file url in the format [Protocol://]<Server>/<Path to the file on the server>.
//   ReceivingParameters - Structure with properties:
//      * PathForSave        - String       - path on server (including attachment file name) to save imported file.
//      * User               - String       - user on whose behalf the connection is established.
//      * Password           - String       - password of the user from which the connection is set.
//      * Port               - Number       - server port with which the connection is set.
//      * Timeout            - Number       - timeout on receiving file in seconds.
//      * SecureConnection   - Boolean      - the sign of using secure connection ftps or https.
//                           - SecureConnection - see description of
//                             the SecureConnection property of the FTPConnection and HTTPConnection objects.
//                           - Undefined - in case if the secure connection is not used.
//      * PassiveConnection  - Boolean   - for the ftp import, the flag shows that connection
//                                              must be passive (or active).
//      * Titles             - Map - see the description of the Titles parameter of the HTTPRequest object.
//   RecordError   - Boolean - The flag showing that it is necessary to write an error to the event log when receiving a file.
//
// Returns:
//   Structure - Structure with properties:
//      * Status       - Boolean - the result of receiving a file.
//      * Path         - String  - file path on server, key is used only if status is True.
//      * ErrorMessage - String  - error message if the state is False.
//      * Titles       - Map     - see the description of the Titles parameter of the HTTPResponse object.
//
Function ExportFileAtClient(Val URL, Val ReceivingParameters = Undefined, Val RecordError = True) Export
	
	ReceivingSettings = GetFilesFromInternetClientServer.StructureParametersReceivingFile();
	
	If ReceivingParameters <> Undefined Then
		
		FillPropertyValues(ReceivingSettings, ReceivingParameters);
		
	EndIf;
	
	SaveSetting = New Map;
	SaveSetting.Insert("StoragePlace", "Client");
	SaveSetting.Insert("Path", ReceivingSettings.PathForSave);
	
	Return GetFilesFromInternetClientServer.PrepareFileReceiving(URL, ReceivingSettings, SaveSetting, RecordError);
	
EndFunction

// Opens form for proxy server parameters input.
//
Procedure OpenProxyServerParameterForm() Export
	
	OpenForm("CommonForm.ProxyServerParameters");
	
EndProcedure

#EndRegion
