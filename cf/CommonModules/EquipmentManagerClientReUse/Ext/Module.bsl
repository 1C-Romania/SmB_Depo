
#Region ProgramInterface

// Function returns the driver handler object by its description.
//
Function GetDriverHandler(DriverHandler, ImportedDriver) Export
	
	Return EquipmentManagerClientOverridable.GetDriverHandler(DriverHandler, ImportedDriver);
	
EndFunction

// The functions returns the list of activated peripherals in the catalog
//
Function GetEquipmentList(EETypes = Undefined, ID = Undefined, Workplace = Undefined) Export

	Return EquipmentManagerServerCall.GetEquipmentList(EETypes, ID, Workplace);

EndFunction

// Returns the parameters structure of a specific device.
// Gets previously saved parameters from the database when called for the first time.
Function GetDeviceParameters(ID) Export

	Return EquipmentManagerServerCall.GetDeviceParameters(ID);

EndFunction

// Function returns a structure
// with device data (with values of catalog item attributes).
Function GetDeviceData(ID) Export

	Return EquipmentManagerServerCall.GetDeviceData(ID);

EndFunction

// Returns the driver handler setting form name.
// Returns the name created on server when called for the first time.
Function GetParametersSettingFormName(DriverHandlerDescription) Export

	SettingFormName = 
	    StrReplace(EquipmentManagerServerCall.GetInstanceDriverName(DriverHandlerDescription),
	                "Handler",
	                "SettingsForm");

	Return SettingFormName;

EndFunction

// Returns the client computer name.
// Gets computer name from variable of the session when called for the first time.
Function GetClientWorkplace() Export

	Return EquipmentManagerServerCall.GetClientWorkplace();

EndFunction

// Returns the client computer name.
// Gets computer name from variable of the session when called for the first time.
Function FindWorkplacesById(ClientID) Export

	Return EquipmentManagerServerCall.FindWorkplacesById(ClientID);

EndFunction

// Returns slip check template by the template name.
//
Function GetSlipReceipt(TemplateName, SlipReceiptWidth, Parameters, PINAuthorization = False) Export

	Return EquipmentManagerServerCall.GetSlipReceipt(TemplateName, SlipReceiptWidth, Parameters, PINAuthorization);

EndFunction

// Function returns the name of Enums from its metadata.
//
Function GetEquipmentTypeName(EquipmentType) Export

	Return EquipmentManagerServerCall.GetEquipmentTypeName(EquipmentType);

EndFunction

// Returns True if the client application is started managed by Linux OS.
//
Function IsLinuxClient() Export
	
	SystemInfo = New SystemInfo;
	
	IsLinuxClient = SystemInfo.PlatformType = PlatformType.Linux_x86
	             OR SystemInfo.PlatformType = PlatformType.Linux_x86_64;
	
	Return IsLinuxClient;
	
EndFunction

#EndRegion