////////////////////////////////////////////////////////////////////////////////
// Subsystem "Configuration update".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Outdated.
//
Procedure OnTransitionToAssistantsPage(PreviousPage, NextPage, Cancel) Export
	
EndProcedure

// The handler is called before system exit when you update the configuration with the assistant.
//
// Example of implementation:
// #If Client
// 	  Then maAskConfirmationOnClosing = False;
// #EndIf
//
Procedure BeforeExit() Export
	
EndProcedure

// Outdated. Use WhenCheckingReadinessForConfigurationUpdate.
//
Function ReadinessForConfigurationUpdate(Val OutputMessages) Export
	
EndFunction

// Check if the infobase can be updated.
// For example if configuration update fails or some problems are detected during the update, the user receives a warning and is prompted to eliminate the causes by themselves and try again.
//
// Parameters
// ConfigurationIsReadyForUpdate - Boolean - shows that IB is ready for update.
//
// Example of implementation:
//
// ConfigurationIsReadyForUpdate = CheckDataCorrectness();
// If Not ConfigurationIsReadyForUpdate And
// 	MessagesOutput Then Warning ("Configuration can not be updated due to ...");
// EndIf;
//
Procedure WhenDeterminingConfigurationReadinessForUpdate(ConfigurationIsReadyForUpgrade) Export
	
EndProcedure

// Outdated. Use WhenDeterminingPageAddressForAccessToUpdateWebsite.
//
Function InfoAboutObtainingAccessToUserSitePageAddress() Export
	
EndFunction

// Get web page address with information on how to get the access to custom section on the website of configuration vendor.
//
// Parameters:
// PageAddress - String - web page address.
//
Procedure WhenDeterminingPageAddressForAccessToUpdateWebsite(PageAddress) Export
	PageAddress = "http://v8.1c.ru/";
EndProcedure

// Outdated. Use WhenCheckingUpdatesForNextPlatformVersion.
// 
Function CheckUpdateForNextPlatformVersion() Export
	
EndFunction

// Checks if it is necessary to check for updates for the next platform version.
// It is recommended to set value True only under the following conditions:
// - The update from 1C: Enterprise user support website is used for the configuration.
// - New version of the platform is released.
// - Configuration supports direct update to the new version which uses new platform version.
// 
// If the procedure sets value True, then if no updates are found
// for the current platform version on user support website, the application will automatically
// check for updates for the next platform version.
// 
// Parameters:
// CheckUpdate - Boolean - Shows that it is required to check for updates for next version.
//
Procedure WhenCheckingUpdatesForNextPlatformVersion(CheckUpdate) Export
	
EndProcedure

// Outdated. Use WhenCheckingUpdatesExportLegalityCheckUse.
//
Function UseUpdateExportLegalityCheck() Export
	
EndFunction

// Shows that it is required to use the check of updates export legality.
// It is recommended to set the value
// True if the configuration supports updates from user support website.
//
Procedure WhenCheckingUpdatesExportLegality(CheckLegality) Export
	
EndProcedure

#EndRegion
