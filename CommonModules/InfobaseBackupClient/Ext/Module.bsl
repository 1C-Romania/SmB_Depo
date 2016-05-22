////////////////////////////////////////////////////////////////////////////////
// Subsystem "IB backup".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// The procedure checks the necessity
// of the backup copying or displaying the required info message to the user.
//
Procedure OnStart(Parameters) Export
	
	If CommonUseClientServer.IsLinuxClient() Or CommonUseClientServer.ThisIsWebClient() Then
		Return;
	EndIf;
	
	WorkParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If WorkParameters.DataSeparationEnabled Then
		Return;
	EndIf;
	
	FixedParametersOfInfobaseBackup = Undefined;
	If Not WorkParameters.Property("InfobaseBackup", FixedParametersOfInfobaseBackup) Then
		Return;
	EndIf;
	If TypeOf(FixedParametersOfInfobaseBackup) <> Type("FixedStructure") Then
		Return;
	EndIf;
	
	// Filling global variables.
	FillInValuesOfGlobalVariables(FixedParametersOfInfobaseBackup);
	
	CheckInfobaseBackup(FixedParametersOfInfobaseBackup);
	
	If FixedParametersOfInfobaseBackup.RecoverHasBeenPerformed Then
		NotificationText = NStr("en = 'Data recovery has been successfully performed.'");
		ShowUserNotification(NStr("en = 'Data is restored.'"), , NotificationText);
	EndIf;
	
	VariantNotifications = FixedParametersOfInfobaseBackup.NotificationParameter;
	
	If VariantNotifications = "DoNotNotify" Then
		Return;
	EndIf;
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ShowMessageBox = False;
		InfobaseBackupClientOverridable.WhenDeterminingWhetherToDisplayWarningsAboutBackingUp(ShowMessageBox);
	Else
		ShowMessageBox = True;
	EndIf;
	
	If ShowMessageBox
		AND (VariantNotifications = "Overdue" Or VariantNotifications = "YetNotConfigured") Then
		NotifyUserAboutBackingUp(VariantNotifications);
	EndIf;
	
	EnableBackupWaitHandler();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Filling global variables.
Procedure FillInValuesOfGlobalVariables(FixedParametersOfInfobaseBackup) Export
	
	ParameterName = "StandardSubsystems.IBBackupParameters";
	ApplicationParameters.Insert(ParameterName, New Structure);
	ApplicationParameters[ParameterName].Insert("ProcessIsRunning");
	ApplicationParameters[ParameterName].Insert("MinimumDateOfNextAutomaticBackup");
	ApplicationParameters[ParameterName].Insert("DateOfLastBackup");
	ApplicationParameters[ParameterName].Insert("NotificationParameter");
	
	FillPropertyValues(ApplicationParameters[ParameterName], FixedParametersOfInfobaseBackup);
	ApplicationParameters[ParameterName].Insert("ScheduleValue", CommonUseClientServer.StructureIntoSchedule(FixedParametersOfInfobaseBackup.CopyingSchedule));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of SSL subsystems internal events.

// Checks possibility of backup in user mode.
//
// Parameters:
//  Result - Boolean (return value).
//
Procedure WhenVerifyingBackupPossibilityInUserMode(Result) Export
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase Then
		
		Result = True;
		
	EndIf;
	
EndProcedure

// Appears when the user is offered to create a backup.
//
Procedure WhenUserIsOfferedToBackup() Export
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase Then
		
		OpenBackupForm();
		
	EndIf;
	
EndProcedure

// Defines the list of warnings to the user before the completion of the system work.
//
// Parameters:
//  Warnings - Array - you can add items of the Structure type to the array, //                     its properties see  StandardSubsystemsClient.WarningOnWorkEnd.
//
Procedure OnGetListOfWarningsToCompleteJobs(Warnings) Export
	
	If CommonUseClientServer.IsLinuxClient() Then
		Return;
	EndIf;
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParameters();
	
	If ClientWorkParameters.DataSeparationEnabled Or Not ClientWorkParameters.FileInfobase Then
		Return;
	EndIf;
	
	If CheckBackupPresence() <> True Then
		Return;
	EndIf;
	
	WarningParameters = StandardSubsystemsClient.AlertOnEndWork();
	WarningParameters.FlagText = NStr("en = 'Perform the backup'");
	WarningParameters.Priority = 50;
	
	ActionIfMarked = WarningParameters.ActionIfMarked;
	ActionIfMarked.Form = "DataProcessor.InfobaseBackup.Form.DataBackup";
	FormParameters = New Structure();
	FormParameters.Insert("RunMode", "ExecuteOnExit");
	ActionIfMarked.FormParameters = FormParameters;
	
	Warnings.Add(WarningParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Export service procedures and functions.

// Returns the name of the backup copying settings form depending on the operation mode.
//
Function BackupSettingsFormName() Export
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase Then
		
		Return "DataProcessor.InfobaseBackupSetup.Form.Form";
		
	Else
		
		Return "DataProcessor.InfobaseBackupSetup.Form.ReminderClientServer";
		
	EndIf;
	
EndFunction

// Opens the form to start the backup copying process.
// Parameters:
//     Owner              - Arbitrary - Owner for the opening form.
//     FormOpenParameters - Structure - Window parameters, see OpenForm().
//
Function OpenBackupForm(Val Owner = Undefined, Val FormOpenParameters = Undefined) Export
	
	Parameters = New Structure("Parameters, Owner, Uniqueness, Window, URL, ClosingNotificationDescription, WindowOpeningMode");
	If FormOpenParameters <> Undefined Then
		FillPropertyValues(Parameters, FormOpenParameters);
	EndIf;
	
	FormOwner = ?(Owner = Undefined, Parameters.Owner, Owner);
	
	OpenForm("DataProcessor.InfobaseBackup.Form.DataBackup",
		Parameters.Parameters, FormOwner, 
		Parameters.Uniqueness, Parameters.Window, Parameters.URL, Parameters.OnCloseNotifyDescription, 
		Parameters.WindowOpeningMode);
		
EndFunction

// Checks the necessity to start
// automatic backup copying while user working and also to repeat the notification after ignoring the first one.
//
Procedure HandlerWaitingLaunch() Export
	
	If CommonUseClientServer.IsLinuxClient() Or CommonUseClientServer.ThisIsWebClient() Then
		Return;
	EndIf;
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase
		AND NecessityOfAutomaticBackup() Then
		PerformBackup();
	EndIf;
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ShowMessageBox = False;
		InfobaseBackupClientOverridable.WhenDeterminingWhetherToDisplayWarningsAboutBackingUp(ShowMessageBox);
	Else
		ShowMessageBox = True;
	EndIf;
	
	VariantNotifications = ApplicationParameters["StandardSubsystems.IBBackupParameters"].NotificationParameter;
	If ShowMessageBox
		AND (VariantNotifications = "Overdue" Or VariantNotifications = "YetNotConfigured") Then
		NotifyUserAboutBackingUp(VariantNotifications);
	EndIf;
	
EndProcedure

// Checks the necessity of automatic backup copying.
//
// Returns - Boolean - True if necessary, False - else.
//
Function NecessityOfAutomaticBackup() Export
	Var ScheduleValue;
	
	InfobaseBackupParameters = ApplicationParameters["StandardSubsystems.IBBackupParameters"];
	If InfobaseBackupParameters = Undefined Then
		Return False;
	EndIf;
	
	If InfobaseBackupParameters.ProcessIsRunning
		OR Not InfobaseBackupParameters.Property("MinimumDateOfNextAutomaticBackup")
		OR Not InfobaseBackupParameters.Property("ScheduleValue", ScheduleValue)
		OR Not InfobaseBackupParameters.Property("DateOfLastBackup") Then
		Return False;
	EndIf;
	
	If ScheduleValue = Undefined Then
		Return False;
	EndIf;
	
	CheckDate = CommonUseClient.SessionDate();
	If InfobaseBackupParameters.MinimumDateOfNextAutomaticBackup = '29990101' Then
		Return False;
	EndIf;
	
	Return ScheduleValue.ExecutionRequired(CheckDate, InfobaseBackupParameters.DateOfLastBackup);
EndFunction

// Starts backup copying based on the schedule.
// 
Procedure PerformBackup()
	
	// Then backup copying.
	DatesOfNextAutomaticCopy = InfobaseBackupServerCall.GenerateDatesOfNextAutomaticCopy();
	FillPropertyValues(ApplicationParameters["StandardSubsystems.IBBackupParameters"],
		DatesOfNextAutomaticCopy);
	
	FormParameters = New Structure("RunMode", "ExecuteNow");
	OpenForm("DataProcessor.InfobaseBackup.Form.DataBackup", FormParameters);
	
EndProcedure

// Deletes backup copies by the specified settings.
//
Procedure DeleteBackupsBySetting() Export
	
	// Clearing archive with the copies.
	FixedParametersOfInfobaseBackup = StandardSubsystemsClientReUse.ClientWorkParameters().InfobaseBackup;
	StoringDirectory = FixedParametersOfInfobaseBackup.DirectoryStorageOfBackupCopies;
	DeletionParameters = FixedParametersOfInfobaseBackup.DeletionParameters;
	
	If DeletionParameters.RestrictionType <> "StoreAll" AND StoringDirectory <> Undefined Then
		
		Try
			File = New File(StoringDirectory);
			If Not File.IsDirectory() Then
				Return;
			EndIf;
			
			FilesArray = FindFiles(StoringDirectory, "backup*.zip", False);
			ListOfFilesForDeletion = New Array;
			
			// Delete backup copies.
			If DeletionParameters.RestrictionType = "ByPeriod" Then
				For Each ItemFile IN FilesArray Do
					CurrentDate = CommonUseClient.SessionDate();
					ValueInSeconds = NumberOfSecondsInPeriod(DeletionParameters.ValueInMeasurementUnits, DeletionParameters.PeriodMeasurementUnit);
					PerformDeletion = ((CurrentDate - ValueInSeconds) > ItemFile.GetModificationTime());
					If PerformDeletion Then
						ListOfFilesForDeletion.Add(ItemFile);
					EndIf;
				EndDo;
				
			ElsIf FilesArray.Count() >= DeletionParameters.CopiesCount Then
				FileList = New ValueList;
				FileList.LoadValues(FilesArray);
				
				For Each File IN FileList Do
					File.Value = File.Value.GetModificationTime();
				EndDo;
				
				FileList.SortByValue(SortDirection.Desc);
				DateOfLastBackup = FileList[DeletionParameters.CopiesCount-1].Value;
				
				For Each ItemFile IN FilesArray Do
					
					If ItemFile.GetModificationTime() <= DateOfLastBackup Then
						ListOfFilesForDeletion.Add(ItemFile);
					EndIf;
					
				EndDo;
				
			EndIf;
			
			For Each FileForDeletion IN ListOfFilesForDeletion Do
				DeleteFiles(FileForDeletion.DescriptionFull);
			EndDo;
			
		Except
			
			EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(), "Error",
				NStr("en = 'Failed to clear the directory with the backup copies.'") + Chars.LF 
				+ DetailErrorDescription(ErrorInfo()),,True);
			
		EndTry;
		
	EndIf;
	
EndProcedure

// When starting the system it checks if it is the first start after backup copying. 
// If yes - displays the handler form with the backup copying results.
//
// Parameters:
//  Parameters - Structure - backup parameters.
//
Procedure CheckInfobaseBackup(Parameters)
	
	If Not Parameters.CopyingHasBeenPerformed Then
		Return;
	EndIf;
	
	If Parameters.LastBackupManualLaunch Then
		
		FormParameters = New Structure();
		FormParameters.Insert("RunMode", ?(Parameters.CopyingResult, "ExecutedSuccessfully", "NotCompleted"));
		FormParameters.Insert("BackupFileName", Parameters.BackupFileName);
		OpenForm("DataProcessor.InfobaseBackup.Form.DataBackup", FormParameters);
		
	Else
		
		ShowUserNotification(NStr("en = 'Backup'"),
			"e1cib/command/CommonCommand.ShowBackupResult",
			NStr("en = 'Backup has been successfully performed'"), PictureLib.Information32);
		InfobaseBackupServerCall.SetSettingValue("CopyingHasBeenPerformed", False);
		
	EndIf;
	
EndProcedure

// Based on the results of the backup copying parameter analysis it issues the corresponding notification.
//
// Parameters: 
//   VariantNotifications - String - result of the notification sending check.
//
Procedure NotifyUserAboutBackingUp(VariantNotifications) Export
	
	ExplanationText = "";
	If VariantNotifications = "Overdue" Then
		
		ExplanationText = NStr("en = 'Automatic backup was not executed.'"); 
		ShowUserNotification(NStr("en = 'Backup'"),
			"e1cib/app/DataProcessor.InfobaseBackup", ExplanationText, PictureLib.Warning32);
		
	ElsIf VariantNotifications = "YetNotConfigured" Then
		
		SettingsFormName = "e1cib/app/%1";
		SettingsFormName = StringFunctionsClientServer.PlaceParametersIntoString(
			SettingsFormName, BackupSettingsFormName());
			
		ExplanationText = NStr("en = 'Recommended to set info base backup.'"); 
		ShowUserNotification(NStr("en = 'Backup'"),
			SettingsFormName, ExplanationText, PictureLib.Warning32);
			
	EndIf;
	
	CurrentDate = CommonUseClient.SessionDate();
	InfobaseBackupServerCall.SetLastReminderDate(CurrentDate);
	
EndProcedure

// Receives the file directory by the name.
//
// Parameters: PathToFile - String, path to the specified file.
//
// Return value: String, path to the directory with the specified file.
//
Function GetFileDir(Val PathToFile) Export
	CharPosition = GetNumberOfLastChar(PathToFile, "\"); 
	If CharPosition > 1 Then
		Return Mid(PathToFile, 1, CharPosition - 1); 
	Else
		Return "";
	EndIf;
EndFunction

// Returns the log event type for this subsystem.
//
// Returns - String - log event type.
//
Function EventLogMonitorEvent() Export
	
	Return NStr("en = 'Info base backup'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// Returns the script parameters for the backup copying.
//
// Returns - Structure - structure of the backup copying script.
//
Function ClientParametersOfBackup() Export
	#If Not WebClient Then
		
		ParametersStructure = New Structure();
		ParametersStructure.Insert("UpdateDateTimeIsSet", False);
		ParametersStructure.Insert("ApplicationFileName", StandardSubsystemsClient.ApplicationExecutedFileName());
		ParametersStructure.Insert("EventLogMonitorEvent", NStr("en = 'Infobase backup'"));
		
		// Determine temporary files directory.
		CurrentDate = CommonUseClient.SessionDate();
		ParametersStructure.Insert("UpdateTempFilesDir"	, TempFilesDir() + "1Cv8Backup." + Format(CurrentDate, "DF=yyMMddHHmmss") + "\");
		
		Return ParametersStructure;
	#EndIf
EndFunction

// Returns information of the authentication parameters.
//
Function AdministratorAuthenticationParametersUpdate(AdministratorPassword) Export
	
	Result = New Structure("UserName,
	|UserPassword,
	|ConnectionString,
	|AuthenticationParameters,
	|InfobaseConnectionString",
	Undefined, "", "", "", "", "");
	
	CurrentConnections = InfobaseConnectionsServerCall.ConnectionInformation(True, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
	Result.InfobaseConnectionString = CurrentConnections.InfobaseConnectionString;
	// Diagnostics of the case when the role security is not provided in the system. 
	// It means a situation when any user "may" do everything in the system.
	If Not CurrentConnections.AreActiveUsers Then
		Return Result;
	EndIf;
	
	User = StandardSubsystemsClientReUse.ClientWorkParameters().UserInfo.Name;
	
	Result.UserName			= User;
	Result.UserPassword		= AdministratorPassword;
	Result.ConnectionString			= "Usr=""" + User + """;Pwd=""" + AdministratorPassword + """;";
	Result.AuthenticationParameters	= "/N""" + User + """ /P""" + AdministratorPassword + """ /WA-";
	Return Result;
	
EndFunction

// Checks the possibility of connection to the infobase.
//
Function ValidateAccessToInformationBase(AdministratorPassword) Export
	
	// In basic versions the connection is not checked;
	// in case of incorrect name and password entry the update fails.
	If StandardSubsystemsClientReUse.ClientWorkParameters().ThisIsBasicConfigurationVersion Then
		Return True;
	EndIf;
	
	CommonUseClient.RegisterCOMConnector(False);
	
	ConnectionParameters = CommonUseClientServer.ExternalConnectionParameterStructure();
	ConnectionParameters.InfobaseDirectory = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(InfobaseConnectionString(), """")[1];
	ConnectionParameters.UserName = StandardSubsystemsClientReUse.ClientWorkParameters().UserInfo.Name;
	ConnectionParameters.UserPassword = AdministratorPassword;
	
	Result = CommonUseClientServer.InstallOuterDatabaseJoin(ConnectionParameters);
	
	If Result.ErrorAttachingAddIn Then
		
		EventLogMonitorClient.AddMessageForEventLogMonitor(
			EventLogMonitorEvent(),"Error", Result.DetailedErrorDescription, , True);
		
	EndIf;
	
	Return Not Result.ErrorAttachingAddIn;
	
EndFunction

// Enable global standby handler.
//
Procedure EnableBackupWaitHandler() Export
	
	AttachIdleHandler("BackupActionsHandler", 60);
	
EndProcedure

// Disable global standby handler.
//
Procedure DisableBackupWaitHandler() Export
	
	DetachIdleHandler("BackupActionsHandler");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local service procedures and functions.

// The function checks the backup copying settings.
//
// Returns:
//  Undefined - if backup copying is not planned,
//  Date      - if backup copying is planned on a specific date, 
//  Boolean   - if backup copying is planned immediately at logout.
//
Function CheckBackupPresence() 
#If WebClient Then
	Return Undefined;
#EndIf

	Parameters = StandardSubsystemsClient.ClientWorkParametersOnComplete();
	If Not Parameters.InfobaseBackup.NotificationRolesAvailability Then
		Return Undefined;
	EndIf;
	
	Return Parameters.InfobaseBackup.ExecuteOnWorkCompletion;
	
EndFunction

// Returns the position of the last transferred character.
//	
// Parameters:
//  SourceLine - String - String used for searching.
//  SearchChar - String - search char.
//	
// Returns - Number - position character.
//
Function GetNumberOfLastChar(Val SourceLine, Val SearchChar)
	CharPosition = StrLen(SourceLine);
	While CharPosition >= 1 Do
		
		If Mid(SourceLine, CharPosition, 1) = SearchChar Then
			Return CharPosition; 
		EndIf;
		
		CharPosition = CharPosition - 1;	
	EndDo;
	Return 0;
EndFunction

Function NumberOfSecondsInPeriod(Period, PeriodType)
	
	If PeriodType = "Day" Then
		Factor = 3600 * 24;
	ElsIf PeriodType = "Week" Then
		Factor = 3600 * 24 * 7; 
	ElsIf PeriodType = "Month" Then
		Factor = 3600 * 24 * 30;
	ElsIf PeriodType = "Year" Then
		Factor = 3600 * 24 * 365;
	EndIf;
	
	Return Factor * Period;
	
EndFunction

#EndRegion
