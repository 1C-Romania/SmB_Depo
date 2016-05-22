////////////////////////////////////////////////////////////////////////////////
// Subsystem "Additional reports and data processors", safe mode extension.
// 
////////////////////////////////////////////////////////////////////////////////

#Region OutdatedApplicationInterface

// Creates object ReadXML and initializes it with data of the
// file placed in a temporary storage with an address passed as a value of parameter BinaryDataAddress.
//
// Parameters:
//  BinaryDataAddress - String, address in a temporary storage
//    where binary file data is placed, 
//  ReadParameters - XMLReadParameters that will be used when reading.
//
// Return value: XMLReader.
//
Function XMLReaderFromBinaryData(Val BinaryDataAddress, Val ReadingParameters = Undefined) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	String = AdditionalReportsAndDataProcessorsInSafeModeServerCall.AStringOfBinaryData(
		BinaryDataAddress);
	
	XMLReader = New XMLReader();
	XMLReader.SetString(String);
	
	Return XMLReader;
	
EndFunction

// Writes content of the XMLWriter object to a temporary file, places binary
// data to a temporary storage and returns an address of binary file data to the temporary storage.
//
// Parameters:
//  XMLWriter - object of type XMLWriter or CanonicalXMLWriter content of which it is required to write.
//  Address - String or UUID, address in temporary storage to which data
//    or unique form identifier must be put, in temporary storage of which
//    must be put the data and return the new address, see global context method description, PutToTempStorage.
//    IN syntax helper.
//
// Returns - String, address in the temporary storage.
//
Function XMLWriterToBinaryData(Val XMLWriter, Val Address) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	String = XMLWriter.Close();
	Return AdditionalReportsAndDataProcessorsInSafeModeServerCall.StringToBinaryData(
		String,
		,
		,
		,
		Address);
	
EndFunction

// Creates object XMLReader and initializes it with the file data
// that is placed to a temporary storage with an address passed as a value of parameter BinaryDataAddress.
//
// Parameters:
//  BinaryDataAddress - String, address in the temporary storage,
//    at which was placed the binary data,
//  Encoding - String, specifies an encoding that will
//    be used in the HTML parsing for conversion.
//
// Return value: XMLReader.
//
Function HTMLReadFromBinaryData(Val BinaryDataAddress, Val Encoding = Undefined) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	String = AdditionalReportsAndDataProcessorsInSafeModeServerCall.AStringOfBinaryData(
		BinaryDataAddress);
	
	HTMLReader = New HTMLReader();
	HTMLReader.SetString(String);
	
	Return HTMLReader;
	
EndFunction

// Writes content of object HTMLWriter to a temporary file, places binary data
// to a temporary storage and returns an address of binary file data to the temporary storage.
//
// Parameters:
//  HTMLWriter - object of type WriteHTML which content it is required to write.
//  Address - String or UUID, address in temporary storage to which data
//    or unique form identifier must be put, in temporary storage of which
//    must be put the data and return the new address, see global context method description, PutToTempStorage.
//    IN syntax helper.
//
// Returns - String, address in the temporary storage.
//
Function RecordHTMLToBinaryData(Val HTMLWriter, Val Address) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	String = HTMLWriter.Close();
	Return AdditionalReportsAndDataProcessorsInSafeModeServerCall.StringToBinaryData(
		String,
		,
		,
		,
		Address);
	
EndFunction

// Creates object ReadFastInfoset and initializes it with the file data
// that is placed to a temporary storage with an address passed as a value of parameter BinaryDataAddress.
//
// Parameters:
//  BinaryDataAddress - String, address in the temporary storage
//    to which the file binary data was placed.
//
// Return value: FastInfosetReader.
//
Function FastInfosetReadingFromBinaryData(Val BinaryDataAddress) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	Data = GetFromTempStorage(BinaryDataAddress);
	FastInfosetReader = New FastInfosetReader();
	FastInfosetReader.SetBinaryData(Data);
	
	Return FastInfosetReader;
	
EndFunction

// Writes content of object WriteFastInfoSet to a temporary file, places binary data
// to a temporary storage and returns an address of binary file data to the temporary storage.
//
// Parameters:
//  RecordFastInfoSet - object of type WriteFastInfoSet which content it is required to write.
//  Address - String or UUID, address in temporary storage to which data
//    or unique form identifier must be put, in temporary storage of which
//    must be put the data and return the new address, see global context method description, PutToTempStorage.
//    IN syntax helper.
//
// Returns - String, address in the temporary storage.
//
Function RecordFastInfosetToBinaryData(Val FastInfosetWriter, Val Address) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	Data = FastInfosetWriter.Close();
	Address = PutToTempStorage(Data, Address);
	
	Return Address;
	
EndFunction

// The fucntion generates a COM object to use
// it in additional reports and processors executed in the server context.
//
// Permission must be granted to the object that calls a function.
// {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/1.0.0.1}CreateComObject
//
// Parameters:
//  SessionKey - UUID, extension session key of safe mode;
//  ProgId - String, ProgID of COM class with which it is registered in the system.
//    For example, "Excel.Application".
//
// Result:
//  COMObject
//
Function CreateComObject(Val SessionKey, Val ProgId) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	AdditionalReportsAndDataProcessorsInSafeModeService.CheckLegitimacyOfExecutionOperations(SessionKey,
		AdditionalReportsAndDataProcessorsInSafeModeInterface.PermissionCreatingCOMObject(
			ProgId));
	
	Return New COMObject(ProgId);
	
EndFunction

// The function connects an external component from the
// general configuration template to use it in additional reports and
// processors executed in the server context.
//  
// Permission must be granted to the object that calls a function.
// {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/1.0.0.1}AttachAddin
//  
// Parameters:
//  SessionKey - UUID, extension session key of safe mode;
//  CommonTemplateName - String, name of a general configuration
//    template where an external component is located. ForExample, "BarcodePrintingComponent", 
//  SymbolicName - String, a symbolic name of the connected external component, 
//  ComponentType - ExternalComponentType.
//  
// Result: Boolean, True - connection has been successfully established.
//  
//
Function ConnectExternalComponentFromCommonConfigurationTemplate(Val SessionKey, Val CommonTemplateName, Val SymbolicName, Val ComponentType) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	AdditionalReportsAndDataProcessorsInSafeModeService.CheckLegitimacyOfExecutionOperations(SessionKey,
		AdditionalReportsAndDataProcessorsInSafeModeInterface.PermissionConnectionOfExternalComponentsOfGeneralTemplateConfiguration(
			CommonTemplateName));
	
	Return AttachAddIn(
		"CommonTemplate." + CommonTemplateName,
		SymbolicName,
		ComponentType);
	
EndFunction

// The function connects an external component from the configuration
// metadata object template to use it in additional reports and
// processors executed in the server context.
//  
// Permission must be granted to the object that calls a function.
// {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/1.0.0.1}AttachAddin
//  
// Parameters:
//  SessionKey - UUID, session key of the safe mode extension,
//  MetadataObject, MetadataObject that owns a template with an external component,
//  TemplateName - String, configuration template name
//    in which an external component is located. ForExample,
//  "BarcodePrintingComponent", SymbolicName - String, a symbolic name of
//  the connected external component, ComponentType - ExternalComponentType.
//  
// Result: Boolean, True - connection has been successfully established.
//  
//
Function ConnectExternalComponentFromConfigurationTemplate(Val SessionKey, Val MetadataObject, Val TemplateName, Val SymbolicName, Val ComponentType) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	AdditionalReportsAndDataProcessorsInSafeModeService.CheckLegitimacyOfExecutionOperations(SessionKey,
		AdditionalReportsAndDataProcessorsInSafeModeInterface.PermissionConnectionOfExternalComponentsFromTemplateConfiguration(
			MetadataObject, TemplateName));
	
	Return AttachAddIn(
		MetadataObject.FullName() + ".Template." + TemplateName,
		SymbolicName,
		ComponentType);
	
EndFunction

// Receives a file from the external object, places the received file to a temporary storage
// and returns an address of binary data of the received file to the temporary storage.
//
// Permission must be granted to the object that calls a function.
// {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/1.0.0.1}GetFileFromExternalSoftware
//
// Parameters:
//  SessionKey - UUID, extension session key of safe mode;
//  ExternalObject - ExternalObject, external object from which it is required to get a file, 
//  MethodName - String, method name of the external object to
//    call to get a file from the external object,
//  Parameters - Array(Optional), parameters of the method call to receive a file from the external object.
//    For a parameter for which a attachment file name is passed in the file system,
//    add ObjectXDTO to the array.
//    {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}InternalFileHandler.
//  Address - String or UUID, address in temporary storage to which data
//    or unique form identifier must be put, in temporary storage of which
//    must be put the data and return the new address, see global context method description, PutToTempStorage.
//    IN syntax helper.
//
// Returns:
//  String, address in the temporary storage.
//
Function GetFileFromExternalObject(Val SessionKey, ExternalObject, Val MethodName, Val Parameters, Val Address = Undefined) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	AdditionalReportsAndDataProcessorsInSafeModeService.CheckLegitimacyOfExecutionOperations(SessionKey,
		AdditionalReportsAndDataProcessorsInSafeModeInterface.PermissionGetFileFromExternalObject());
	
	CheckCorrectnessOfMethodNameOfExternalObject(MethodName);
	
	TempFile = GetTempFileName();
	ParameterString = GenerateStringParametersForMethodOfExternalObject(Parameters);
	Execute("ExternalObject." + MethodName + "(" + ParameterString + ");");
	
	Address = PutToTempStorage(New BinaryData(TempFile), Address);
	DeleteFiles(TempFile);
	
	Return Address;
	
EndFunction

// Receives a file from the temporary storage and passes it to the external object.
//
// Permission must be granted to the object that calls a function.
// {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/1.0.0.1}SendFileToExternalSoftware
//
// Parameters:
//  SessionKey - UUID, extension session key of safe mode;
//  ExternalObject - ExternalObject, external object from which  it is required to get a file, 
//  BinaryDataAddress - String, address in the temporary storage
//    to which the file binary data was placed.
//  MethodName - String, name of the method to be called
//    to pass a file to an external object,
//  Parameters - Array(Optional), parameters of a method call to pass a file to an external object.
//    For a parameter for which a attachment file name is passed in the file system,
//    add ObjectXDTO to the array.
//    {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/a.b.c.d}InternalFileHandler.
//
Procedure TransferFileToExternalObject(Val SessionKey, ExternalObject, Val BinaryDataAddress, Val MethodName, Val Parameters) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	AdditionalReportsAndDataProcessorsInSafeModeService.CheckLegitimacyOfExecutionOperations(SessionKey,
		AdditionalReportsAndDataProcessorsInSafeModeInterface.PermissionFileTransferIntoExternalObject());
	
	CheckCorrectnessOfMethodNameOfExternalObject(MethodName);
	
	TempFile = AdditionalReportsAndDataProcessorsInSafeModeService.GetFileFromTemporaryStore(BinaryDataAddress);
	ParameterString = GenerateStringParametersForMethodOfExternalObject(Parameters);
	Execute("ExternalObject." + MethodName + "(" + ParameterString + ");");
	
	Try
		DeleteFiles(TempFile);
	Except
		AdditionalReportsAndDataProcessors.WriteWarning(
			Undefined,
			NStr("en = 'Cannot delete temporary file
			|""%1"": %2'"),
			TempFile,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
EndProcedure

// The function receives a file from the Internet via protocols HTTP(S)/FTP.
//
// Permission must be granted to the object that calls a function.
// {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/1.0.0.1}GetFileFromInternet
//
// Parameters:
//  SessionKey - UUID, extension session key of safe mode;
//  URL - String, URL of the file to be imported, 
//  Port - number, network port number,
//  UserName - String, username to log on to
//    the remote server (specify it only if it is required
//    to log on to get a file by the specified URL),
//  Password - String, user password to log on
//    to a remote server (specify it only if it is required
//    to log on to get a file by specified URL),
//  Timeout - timeout for the operation execution in seconds, by default - 20 seconds, 
//    maximum value - 10 minutes.
//
// Result:
//  String, an address in a temporary storage in which the
//    file received by the specified URL was placed.
//
Function GetFileFromInternet(Val SessionKey, Val URL, Val Port = 0, Val UserName = "", Val Password = "", Val Timeout = 20,Val SecureConnection = Undefined, Val PassiveConnection = Undefined) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Raise NStr("en = 'This configuration does not support the funcrion AdditionalReportsAndDataProcessorsInSafeMode.GetFileFromInternet!'");
	EndIf;
	
	ModuleGetFilesFromInternetClientServer = CommonUse.CommonModule("GetFilesFromInternetClientServer");
	
	If Port = 0 Then
		
		FullURLStructure = CommonUseClientServer.URLStructure(URL);
		
		If Not IsBlankString(FullURLStructure.Port) Then
			ServerName = FullURLStructure.Host;
			Port = FullURLStructure.Port;
		EndIf;
		
	EndIf;
	
	If Timeout > 600 Then
		Timeout = 600;
	EndIf;
	
	URLStructure = ModuleGetFilesFromInternetClientServer.SplitURL(URL);
	Protocol = URLStructure.Protocol;
	ServerName = URLStructure.ServerName;
	PathToFileAtServer  = URLStructure.PathToFileAtServer;
	
	If Port = 0 Then
		
		If Upper(Protocol) = "HTTP" Then
			Port = 80;
		ElsIf Upper(Protocol) = "FTP" Then
			Port = 21;
		ElsIf Upper(Protocol) = "HTTPS" Then
			Port = 443;
		EndIf;
		
	EndIf;
	
	AdditionalReportsAndDataProcessorsInSafeModeService.CheckLegitimacyOfExecutionOperations(SessionKey,
		AdditionalReportsAndDataProcessorsInSafeModeInterface.PermissionDataGetFromInternet(
			Upper(Protocol), ServerName, Port));
	
	If Upper(Protocol) = "HTTPS" Then
		SecureConnection = True;
	EndIf;
	
	Proxy = ModuleGetFilesFromInternetClientServer.GetProxy(Protocol);
	
	If Upper(Protocol) = "FTP" Then
		Try
			Join = New FTPConnection(ServerName, Port, UserName, Password, Proxy, PassiveConnection, Timeout);
		Except
			ErrorInfo = ErrorInfo();
			ErrorInfo = NStr("en = 'Error while creating FTP-connection with server %1'") + Chars.LF + "%2";
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				ErrorInfo, ServerName, DetailErrorDescription(ErrorInfo));
		EndTry;
			
	Else
		If SecureConnection = True Then
			SecureConnection = New OpenSSLSecureConnection;
		Else
			SecureConnection = Undefined;
		EndIf;
		
		Try
			Join = New HTTPConnection(ServerName, Port, UserName, Password, Proxy, Timeout, SecureConnection);
		Except
			ErrorInfo = ErrorInfo();
			ErrorInfo = NStr("en = 'Error when creating the HTTP-conection with the server %1:'") + Chars.LF + "%2";
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(ErrorInfo, ServerName, 
				DetailErrorDescription(ErrorInfo));
		EndTry;
	EndIf;
	
	TempFile = GetTempFileName();
	
	Try
		Join.Get(PathToFileAtServer, TempFile);
	Except
		ErrorInfo = ErrorInfo();
		ErrorInfo = NStr("en = 'Error while receiving file form server %1:'") + Chars.LF + "%2";
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(ErrorInfo, ServerName, 
			DetailErrorDescription(ErrorInfo));
	EndTry;
	
	Return PutToTempStorage(New BinaryData(TempFile));
	
EndFunction

// The function passes a file to the Internet via protocols HTTP(S)/FTP.
//
// Permission must be granted to the object that calls a function.
// {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/1.0.0.1}SendFileToInternet
//
// Parameters:
//  SessionKey - UUID, extension session key of safe mode;
//  BinaryDataAddress - String, an address in a temporary
//    storage in which binary file data to pass to the Internet was placed.
//  URL - String, URL of the file to be imported, 
//  Port - number, network port number, 
//  UserName - String, username to log on to
//    the remote server (specify it only if it is required
//    to log on to get a file by the specified URL),
// Password - String, user password to log on
//    to a remote server (specify it only if it is required
//    to log on to get a file by specified URL),
// Timeout - timeout for the operation execution in seconds, by default - 20 seconds,
//    maximum value - 10 minutes.
//
Function ImportFileInInternet(Val SessionKey, Val BinaryDataAddress, Val URL, Val Port = 0, Val UserName = "", Val Password = "", Val Timeout = 20,Val SecureConnection = Undefined, Val PassiveConnection = Undefined) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Raise NStr("en = 'This configuration does not support the AdditionalReportsAndDataProcessorsInSafeMode.ImportFileInInternet function call!'");
	EndIf;
	
	ModuleGetFilesFromInternetClientServer = CommonUse.CommonModule("GetFilesFromInternetClientServer");
	
	If Port = 0 Then
		
		FullURLStructure = CommonUseClientServer.URLStructure(URL);
		
		If Not IsBlankString(FullURLStructure.Port) Then
			ServerName = FullURLStructure.Host;
			Port = FullURLStructure.Port;
		EndIf;
		
	EndIf;
	
	If Timeout > 600 Then
		Timeout = 600;
	EndIf;
	
	URLStructure = ModuleGetFilesFromInternetClientServer.SplitURL(URL);
	Protocol = URLStructure.Protocol;
	ServerName = URLStructure.ServerName;
	PathToFileAtServer  = URLStructure.PathToFileAtServer;
	
	AdditionalReportsAndDataProcessorsInSafeModeService.CheckLegitimacyOfExecutionOperations(SessionKey,
		AdditionalReportsAndDataProcessorsInSafeModeInterface.PermissionTransferDataToInternet(
			Upper(Protocol), ServerName, Port));
	
	TempFile = AdditionalReportsAndDataProcessorsInSafeModeService.GetFileFromTemporaryStore(BinaryDataAddress);
	
	If Upper(Protocol) = "HTTPS" Then
		SecureConnection = True;
	EndIf;
	
	Proxy = ModuleGetFilesFromInternetClientServer.GetProxy(Protocol);
	
	If Upper(Protocol) = "FTP" Then
		Try
			Join = New FTPConnection(ServerName, Port, UserName, Password, Proxy, PassiveConnection, Timeout);
		Except
			ErrorInfo = ErrorInfo();
			ErrorInfo = NStr("en = 'Error while creating FTP-connection with server %1'") + Chars.LF + "%2";
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				ErrorInfo, ServerName, DetailErrorDescription(ErrorInfo));
		EndTry;
			
	Else
		If SecureConnection = True Then
			SecureConnection = New OpenSSLSecureConnection;
		Else
			SecureConnection = Undefined;
		EndIf;
		
		Try
			Join = New HTTPConnection(ServerName, Port, UserName, Password, Proxy, Timeout, SecureConnection);
		Except
			ErrorInfo = ErrorInfo();
			ErrorInfo = NStr("en = 'Error when creating the HTTP-conection with the server %1:'") + Chars.LF + "%2";
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(ErrorInfo, ServerName, 
				DetailErrorDescription(ErrorInfo));
		EndTry;
	EndIf;
	
	Try
		Join.Write(TempFile, PathToFileAtServer);
	Except
		ErrorInfo = ErrorInfo();
		ErrorInfo = NStr("en = 'An error occurred when transferring the file to server %1:'") + Chars.LF + "%2";
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(ErrorInfo, ServerName, 
			DetailErrorDescription(ErrorInfo));
	EndTry;
	
EndFunction

// The function creates object WSProxy for connection to the Web service.
//
// Permission must be granted to the object that calls a function.
// {http://www.1c.ru/1CFresh/ApplicationExtensions/Permissions/1.0.0.1}SoapConnect
//
// Parameters:
//  SessionKey   - UUID, extension session key of safe mode;
//  WSDLAddress  - String - wsdl location.
//  NamespaceURI - String - URI spaces of the web-service names.
//  ServiceName  - String - service name.
//  EndpointName - String - if it is not specified, it is generated as <ServiceName>Soap.
//  UserName - String - user name for the website login.
//  Password - String - user's password.
//  Timeout  - Number - timeout for operations executed via the received proxy.
//
// Return value: WSProxy.
//
Function WSConnection(Val SessionKey, Val WSDLAddress, Val NamespaceURI, Val ServiceName, Val EndpointName = "", Val UserName = "", Val Password = "", Val Timeout = 20) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	If Timeout > 600 Then
		Timeout = 600;
	EndIf;
	
	AdditionalReportsAndDataProcessorsInSafeModeService.CheckLegitimacyOfExecutionOperations(SessionKey,
		AdditionalReportsAndDataProcessorsInSafeModeInterface.PermissionWSConnection(
			WSDLAddress));
	
	Return CommonUse.WSProxy(
		WSDLAddress,
		NamespaceURI,
		ServiceName,
		EndpointName,
		UserName,
		Password,
		Timeout);
	
EndFunction

// The function writes documents with posting / canceling posting.
//
// Parameters:
//  SessionKey - UUID, extension session key of safe mode;
//  ProcessedDocuments - Array(DocumentObject), array of documents to be written, 
//  WriteMode - DocumentWriteMode, mode in which it is required to write documents.
//  PostingMode - PostingDocumentMode, mode in which it is required to post documents.
//
Function PostingDocuments(Val SessionKey, ProcessedDocuments, Val WriteMode = Undefined, Val PostingMode = Undefined) Export
	
	WriteParameters = New Structure;
	
	If WriteMode <> Undefined Then
		
		WriteParameters.Insert("WriteMode", WriteMode);
		
	EndIf;
	
	If PostingMode <> Undefined Then
		
		WriteParameters.Insert("PostingMode", PostingMode);
		
	EndIf;
	
	WriteObjects(SessionKey, ProcessedDocuments, WriteParameters);
	
EndFunction

// Function - writes objects
// 
// Parameters:
//  SessionKey            - UUID  - extension session key of safe mode 
//  ProcessedObjects      - Array - objects that are to be written 
//                              Valid types:
//                                  CatalogObject;
//                                  ConstantValueManager;
//                                  ChartOfCharacteristicTypesObject;
//                                  ChartOfAccountsObject;
//                                  ChartOfCalculationTypesObject;
//                                  ExchangePlanObject;
//                                  BusinessProcessObject;
//                                  TaskObject;
//                                  DocumentObject;
//                                  InformationRegisterRecordSet;
//                                  AccumulationRegisterRecordSet;
//                                  SequenceRecordSet;
//                                  AccountingRegisterRecordSet;
//                                  CalculationRegisterRecordSet.
//  WriteParameters       - Structure - object record parameters (optional)
//                                  <WriteMode> (optional). Type: DocumentWriteMode. Default value: Record.
//                                  <PostingMode> (optional). Type: DocumentPostingMode. Default value: Regular.
//                                  <Replace> (optional). Type: Boolean. Default value: True.
//                                  <OnlyRecord> (optional). Type: Boolean. Default value: False.
//                                  <WriteActualValidityPeriod> (optional). Type: Boolean. Default value: True.
//                                  <WriteRecalculation> (optional). Type: Boolean. Default value: True.
// 
// Returns:
//   - 
//
Function WriteObjects(Val SessionKey, ProcessedObjects, Val WriteParameters = Undefined) Export
	
	CheckCorrectnessOfCallOnEnvironment();
	
	// Initialization of the parameters sent to method "Record".
	If WriteParameters = Undefined Then
		
		WriteParameters = New Structure;
		
	EndIf;
	
	// Parameters for documents.
	If Not WriteParameters.Property("WriteMode") Then
		
		WriteParameters.Insert("WriteMode", DocumentWriteMode.Write);
		
	EndIf;
	
	If Not WriteParameters.Property("PostingMode") Then
		
		WriteParameters.Insert("PostingMode", DocumentPostingMode.Regular);
		
	EndIf;
	
	// Parameters for registers and sequences.
	If Not WriteParameters.Property("ToReplace") Then
		
		WriteParameters.Insert("ToReplace", True);
		
	EndIf;
	
	// Parameters for calculation registers.
	If Not WriteParameters.Property("WriteOnly") Then
		
		WriteParameters.Insert("WriteOnly", False);
		
	EndIf;
	
	If Not WriteParameters.Property("WriteActualActionPeriod") Then
		
		WriteParameters.Insert("WriteActualActionPeriod", True);
		
	EndIf;
	
	If Not WriteParameters.Property("WriteRecalculations") Then
		
		WriteParameters.Insert("WriteRecalculations", True);
		
	EndIf;
	
	// Writing objects.
	For Each ProcessedObject IN ProcessedObjects Do
		
		BeginTransaction();
		
		Try
			
			MetadataObjectBeingProcessed = ProcessedObject.Metadata();
			
			// CatalogObject, ConstantValueManager, ChartOfCharacteristicTypesObject,
			// ChartOfAccountsObject, ChartOfCalculationTypesObject, ExchangePlanObject, BusinessProcessObject, TaskObject.
			If CommonUse.ThisIsCatalog(MetadataObjectBeingProcessed)
				OR CommonUse.ThisIsConstant(MetadataObjectBeingProcessed)
				OR CommonUse.ThisIsChartOfCharacteristicTypes(MetadataObjectBeingProcessed)
				OR CommonUse.ThisIsChartOfAccounts(MetadataObjectBeingProcessed)
				OR CommonUse.ThisIsChartOfCalculationTypes(MetadataObjectBeingProcessed)
				OR CommonUse.ThisIsExchangePlan(MetadataObjectBeingProcessed)
				OR CommonUse.ThisIsBusinessProcess(MetadataObjectBeingProcessed)
				OR CommonUse.ThisIsTask(MetadataObjectBeingProcessed) Then
				
				ProcessedObject.Write();
				
			// DocumentObject.
			ElsIf CommonUse.ThisIsDocument(MetadataObjectBeingProcessed) Then
				
				ProcessedObject.Write(WriteParameters.WriteMode, WriteParameters.PostingMode);
				
			// InformationRegisterRecordSet,
			// AccumulationRegisterRecordSet, SequenceRecordSet, AccountingRegisterRecordSet.
			ElsIf CommonUse.ThisIsInformationRegister(MetadataObjectBeingProcessed)
				OR CommonUse.ThisIsAccumulationRegister(MetadataObjectBeingProcessed)
				OR CommonUse.ThisSequence(MetadataObjectBeingProcessed)
				OR CommonUse.ThisIsAccountingRegister(MetadataObjectBeingProcessed) Then
				
				ProcessedObject.Write(WriteParameters.ToReplace);
				
			// CalculationRegisterRecordSet.
			ElsIf CommonUse.ThisIsCalculationRegister(MetadataObjectBeingProcessed) Then
				
				ProcessedObject.Write(
					WriteParameters.ToReplace,
					WriteParameters.WriteOnly,
					WriteParameters.WriteActualActionPeriod,
					WriteParameters.WriteRecalculations
				);
				
			EndIf;
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			Raise;
			
		EndTry;
		
	EndDo;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure CheckCorrectnessOfMethodNameOfExternalObject(Val MethodName)
	
	ForbiddenSymbols = New Array();
	ForbiddenSymbols.Add(",");
	ForbiddenSymbols.Add("(");
	ForbiddenSymbols.Add(")");
	ForbiddenSymbols.Add(";");
	
	For Each ForbiddenSymbol IN ForbiddenSymbols Do
		
		If Find(MethodName, ForbiddenSymbol) > 0 Then
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = '%1 is not a correct method name for the COM-object or the external component object!'"),
				MethodName);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GenerateStringParametersForMethodOfExternalObject(Val Parameters)
	
	ParameterString = "";
	Iterator = 0;
	For Each Parameter IN Parameters Do
		
		If Not IsBlankString(ParameterString) Then
			ParameterString = ParameterString + ", ";
		EndIf;
		
		FileTransfer = False;
		If TypeOf(Parameter) = Type("XDTOObjectType") Then
			If Parameter = AdditionalReportsAndDataProcessorsInSafeModeInterface.ParameterTransferredFile() Then
				FileTransfer = True;
			EndIf;
		EndIf;
		
		If FileTransfer Then
			ParameterString = ParameterString + "TempFile";
		Else
			ParameterString = ParameterString + "Parameters[" + Format(Iterator, "NFD=0; NZ=0; NG=0") + "]";
		EndIf;
		
		Iterator = Iterator + 1;
		
	EndDo;
	
	Return ParameterString;
	
EndFunction

Procedure CheckCorrectnessOfCallOnEnvironment()
	
	If Not AdditionalReportsAndDataProcessorsInSafeModeService.CheckCorrectnessOfCallOnEnvironment() Then
		
		Raise NStr("en = 'Incorrect function call of common module AdditionalReportsAndDataProcessorsInSafeMode.
                                |Exported functions of the module to be used in the
                                |safe mode must be called only from the script.'");
		
	EndIf;
	
EndProcedure

#EndRegion
