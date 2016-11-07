////////////////////////////////////////////////////////////////////////////////
// Subsystem "IB backup".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Sets the setting to backup parameters. 
// 
// Parameters: 
// ItemName - String - parameter name.
// 	ItemValue - Arbitrary type - value of the parameter.
//
Procedure SetSettingValue(ItemName, ItemValue) Export
	
	InfobaseBackupServer.SetSettingValue(ItemName, ItemValue);
	
EndProcedure

// Creates a value of the next automatic backup in accordance with the schedule.
//
// Parameters:
// InitialSetting - Boolean - flag of initial setup.
//
Function GenerateDatesOfNextAutomaticCopy(InitialSetting = False) Export
	
	Return InfobaseBackupServer.GenerateDatesOfNextAutomaticCopy(InitialSetting);
	
EndFunction

// Sets the date of last notification of user.
//
// Parameters: 
// DateReminders - Date - date and time of last user notification about
//                          the need to back up.
//
Procedure SetLastReminderDate(DateReminders) Export
	
	InfobaseBackupServer.SetLastReminderDate(DateReminders);
	
EndProcedure

// Returns the flag showing that the user has full rights.
//
// Returns - Boolean - True if this is a full user.
//
Function HasRightsToAlertAboutBackupConfiguration() Export
	
	Return InfobaseBackupServer.HasRightsToAlertAboutBackupConfiguration();
	
EndFunction

// Saves backup parameters.
//
// Parameters:
//  ParametersStructure - Structure - backup parameters.
//
Procedure SetBackupParameters(ParametersStructure) Export
	
	InfobaseBackupServer.SetBackupParameters(ParametersStructure);
	
EndProcedure

#EndRegion
