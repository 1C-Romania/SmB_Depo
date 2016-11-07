////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Subsystem "Address classifier".
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// The set of levels for queries in compatibility mode with KLADR.
//
// Returns:
//     FixedArray - the set of numeric levels.
//
Function AddressClassifierLevels() Export
	
	Return AddressClassifierClientServer.AddressClassifierLevels();
	
EndFunction

// The set of levels for FIAS queries.
//
// Returns:
//     FixedArray - the set of numeric levels.
//
Function FIASClassifierLevels() Export
	
	Return AddressClassifierClientServer.FIASClassifierLevels();
	
EndFunction

// WSproxy for call 1C web-ervice.
//
// Returns:
//     WSProxy - the object for the service invocation.
//
Function ClassifierService1C() Export

	Authorization = StandardSubsystemsServer.AuthenticationParametersOnSite();
	If Authorization = Undefined Then
		Login  = Undefined;
		Password = Undefined;
	Else
		Login  = Authorization.Login;
		Password = Authorization.Password;
	EndIf;
	
	CurrentURLWebService = CommonUse.CommonSettingsStorageImport("AddressClassifier", "URLClassifierService1C");
	If CurrentURLWebService = Undefined Then
		CurrentURLWebService = "#EMPTY LINK#";
	EndIf;
	
	Return CommonUse.WSProxy(CurrentURLWebService,
		"http://www.v8.1c.ru/ssl/AddressSystem", "AddressSystem", "AddressSystemSoap12", Login, Password, 10);
		
EndFunction

#EndRegion