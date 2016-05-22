////////////////////////////////////////////////////////////////////////////////
// Subsystem "Configuration update".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Returns the structure of configuration update settings and updates them.
//
// Parameters:
// UpdateSettings - structure - old update settings that should be updated.
//
// Returns:
//   Structure   - structure of update settings.
//
Function GetUpdatedConfigurationUpdateSettings(UpdateSettings) Export
	
	If UpdateSettings = Undefined Then
		UpdateSettings = NewConfigurationUpdateOptions();
	Else
		NewSettings = NewConfigurationUpdateOptions();
		For Each Setting IN NewSettings Do
			If Not UpdateSettings.Property(Setting.Key) Then
				  UpdateSettings.Insert(Setting.Key, Setting.Value);
			EndIf;
		EndDo;
	EndIf;
	Return UpdateSettings;
	
EndFunction

// Fills in the structure of configuration update settings and returns them.
//
// Returns:
//   Structure   - structure of update settings.
//
Function NewConfigurationUpdateOptions() Export 
	
	Result = New Structure;
	Result.Insert("UpdateServerUserCode", "");
	Result.Insert("UpdatesServerPassword", "");
	Result.Insert("SaveUpdatesServerPassword", True);
	Result.Insert("CheckUpdateExistsOnStart", False);
	Result.Insert("UpdateSource", 0);
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Result.Insert("UpdateMode", ?(CommonUse.FileInfobase(), 0, 2));
	Result.Insert("UpdateDateTime", AddDays(BegOfDay(CurrentSessionDate()), 1));
#Else
	Result.Insert("UpdateMode", ?(StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase, 0, 2));
	Result.Insert("UpdateDateTime", AddDays(BegOfDay(CommonUseClient.SessionDate()), 1));
#EndIf
	Result.Insert("SendReportToEMail", False);
	Result.Insert("EmailAddress", "");
	Result.Insert("SchedulerTaskCode", 0);
	Result.Insert("ScheduleOfUpdateExistsCheck", Undefined);
	Result.Insert("SecondStart", False);
	Result.Insert("UpdateFileName", "");
	Result.Insert("NeedUpdateFile", 1);
	Result.Insert("CreateBackup", 1);
	Result.Insert("InfobaseBackupDirectoryName", "");
	Result.Insert("RestoreInfobase", True);
	Result.Insert("ServerAddressForVerificationOfUpdateAvailability", "");
	Result.Insert("UpdatesDirectory", "");
	Result.Insert("LegalityCheckServiceAddress", "");
	Result.Insert("ConfigurationShortName", "");
	Result.Insert("AddressOfResourceForVerificationOfUpdateAvailability", "");
	Result.Insert("ClusterRequiresAuthentication", False);
	Result.Insert("ClusterAdministratorName", "");
	Result.Insert("ClusterAdministratorPassword", "");
	Result.Insert("NonstandardServerPorts", False);
	Result.Insert("ServerAgentPort", 0);
	Result.Insert("ServerClusterPort", 0);
	Result.Insert("TimeOfLastUpdateCheck", Date(1, 1, 1));
	Return Result;

EndFunction	

// Adds the specified quantity of days to the date.
//
// Parameters:
//  Date		- Date	- Initial date.
//  NumberOfDays	- Number	- Number of days added to initial date.
//
Function AddDays(Val Date, Val NumberOfDays) Export
	
	If NumberOfDays > 0 Then
		Difference = Day(Date) + NumberOfDays - Day(EndOfMonth(Date));
		If Difference > 0 Then
			NewDate = AddMonth(Date, 1);	
			Return Date(Year(NewDate), Month(NewDate), Difference, 
				Hour(NewDate), Minute(NewDate), Second(NewDate));
		EndIf;
	ElsIf NumberOfDays < 0 Then
		Difference = Day(Date) + NumberOfDays - Day(BegOfMonth(Date));
		If Difference < 1 Then
			NewDate = AddMonth(Date, -1);	
			Return Date(Year(NewDate), Month(NewDate), Day(EndOfMonth(NewDate)) - Difference, 
				Hour(NewDate), Minute(NewDate), Second(NewDate));
		EndIf;
	EndIf; 
	Return Date(Year(Date), Month(Date), Day(Date) + NumberOfDays, Hour(Date), Minute(Date), Second(Date));
	
EndFunction

// Adds the end character-separator to the passed directory path if it is not available.
// If parameter "Platform" is not specified, a delimiter is selected from
// already existing delimiters in parameter "DirectoryPath".
//
// Parameters:
//  DirectoryPath - String - path to directory;
//  Platform - PlatformType - type of platform within which the operation is carried out (impacts on the choice of delimiter).
//
// Returns:
//  String   - path to directory with the end character-separator.
//
// Usage examples:
//  Result = AddFinalPathSeparator("C:\My directory");  returns "C://\My directory\".
//  Result = AddFinalPathSeparator("C:\My directory\");  returns "C:\My directory\".
//  Result = AddFinalPathSeparator("ftp://My directory");  returns "ftp://My directory/".
//
Function AddFinalPathSeparator(Val DirectoryPath) Export
	
	If IsBlankString(DirectoryPath) Then
		Return DirectoryPath;
	EndIf;
	
	CharToAdd = "\";
	If Find(DirectoryPath, "/") > 0 Then
		CharToAdd = "/";
	EndIf;
	
	If Right(DirectoryPath, 1) <> CharToAdd Then
		Return DirectoryPath + CharToAdd;
	Else
		Return DirectoryPath;
	EndIf;
	
EndFunction

// Returns a full name of main data processor form ConfigurationUpdate.
//
Function DataProcessorFormNameConfigurationUpdate() Export
	
	Return "DataProcessor.ConfigurationUpdate.Form.Form";
	
EndFunction

#EndRegion
