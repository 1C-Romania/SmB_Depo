////////////////////////////////////////////////////////////////////////////////
// Subsystem "Configuration update".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Outdated. Use WhenDeterminingConfigurationShortName.
//
Function ConfigurationShortName() Export
	
EndFunction

// Determines the short name (identifier) of the configuration.
//
// Parameters:
// ShortName - String- short name of the configuration.
//
Procedure WhenDeterminingConfigurationShortName(ShortName) Export
	
	ShortName = "SmallBusiness";
	
EndProcedure

// Outdated. Use WhenDeterminingServerAddressForUpdatesCheck.
//
Function ServerAddressForVerificationOfUpdateAvailability() Export
	
EndFunction

// Receives the address of configuration vendor
// web server on which there is the information about available updates ("open" section of the website).
//
// Parameters:
// ServerAddress - String - web server address.
//
// Examples of implementation:
// ServerAddress = "localhost"; //local web server for testing.
//
Procedure WhenDeterminingServerAddressForUpdatesCheck(ServerAddress) Export
	ServerAddress = "exports.1c.en";
EndProcedure

// Outdated. Use WhenDeterminingResourceAddressForUpdatesCheck.
//
Function AddressOfResourceForVerificationOfUpdateAvailability() Export
	
EndFunction

// Get resource address on the web server
// for updates check (in "open" section of the website).
//
// Parameters:
// ResourceAddress - String - Address of the resource for updates check.
//
Procedure WhenDeterminingResourceAddressForUpdatesCheck(ResourceAddress) Export
	ResourceAddress = "/ipp/ITSREPV/V8Update/Configs/";
EndProcedure

// Outdated. Use WhenDeterminingUpdatesDirectory.
//
Function UpdatesDirectory() Export
	
EndFunction

// Receives website address with updates directory ("closed" part of the website).
//
// Parameters:
// UpdateCatalogAddress - String - Address of updates directory.
//
// Examples of implementation:
// UpdatesDirectoryAddress = "localhost/tmplts"; // local web server for testing.
//
Procedure WhenDeterminingUpdatesDirectoryAddress(UpdateCatalogAddress) Export
	UpdateCatalogAddress = "https://1c-dn.com/user/profile/";
EndProcedure

#EndRegion
