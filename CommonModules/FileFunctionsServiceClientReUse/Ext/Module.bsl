////////////////////////////////////////////////////////////////////////////////
// Subsystem "File functions".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Returns a form that informs users 
// of locking and editing files
// in web client.
//
Function GetFormOfReminderOnEditing() Export
	
	Return GetForm("CommonForm.ReminderOnEditing");
	
EndFunction

// Returns the structure containing personal settings.
Function PersonalFileOperationsSettings() Export
	
	PersonalSettings = StandardSubsystemsClientReUse.ClientWorkParameters(
		).PersonalFileOperationsSettings;
	
	// Check and update settings saved
	// on the server that are calculated in the client.
	
	Return PersonalSettings;
	
EndFunction

// Returns the structure containing personal settings.
Function FileOperationsCommonSettings() Export
	
	CommonSettings = StandardSubsystemsClientReUse.ClientWorkParameters(
		).FileOperationsCommonSettings;
	
	// Check and update settings saved
	// on the server that are calculated in the client.
	
	Return CommonSettings;
	
EndFunction

// Returns a parameter of session PathToUserWorkingDirectory.
Function UserWorkingDirectory() Export
	
	ParameterName = "StandardSubsystems.AccessToWorkingDirectoryCheckExecuted";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, False);
	EndIf;
	
	DirectoryName = StandardSubsystemsClientReUse.ClientWorkParameters(
		).PersonalFileOperationsSettings.PathToFilesLocalCache;
	
	// Already set.
	If DirectoryName <> Undefined
		AND Not IsBlankString(DirectoryName)
		AND ApplicationParameters["StandardSubsystems.AccessToWorkingDirectoryCheckExecuted"] Then
		
		Return DirectoryName;
	EndIf;
	
	If DirectoryName = Undefined Then
		DirectoryName = FileFunctionsServiceClient.SelectPathToUserDataDirectory();
		If Not IsBlankString(DirectoryName) Then
			FileFunctionsServiceClient.SetUserWorkingDirectory(DirectoryName);
		Else
			ApplicationParameters["StandardSubsystems.AccessToWorkingDirectoryCheckExecuted"] = True;
			Return ""; // Web client without an extension to work with files.
		EndIf;
	EndIf;
	
#If Not WebClient Then
	
	// Create a file directory.
	Try
		CreateDirectory(DirectoryName);
		TestDirectoryName = DirectoryName + "CheckAccess\";
		CreateDirectory(TestDirectoryName);
		DeleteFiles(TestDirectoryName);
	Except
		// You are not authorized to create a directory
		// or this path does not exist, then default settings are set.
		DirectoryName = FileFunctionsServiceClient.SelectPathToUserDataDirectory();
		FileFunctionsServiceClient.SetUserWorkingDirectory(DirectoryName);
	EndTry;
	
#EndIf
	
	ApplicationParameters["StandardSubsystems.AccessToWorkingDirectoryCheckExecuted"] = True;
	
	Return DirectoryName;
	
EndFunction

// See procedure with the same name in common module FileFunctionsServiceClient.
Procedure GetUserWorkingDirectory(Notification) Export
	
	ParameterName = "StandardSubsystems.AccessToWorkingDirectoryCheckExecuted";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, False);
	EndIf;
	
	DirectoryName = StandardSubsystemsClientReUse.ClientWorkParameters(
		).PersonalFileOperationsSettings.PathToFilesLocalCache;
	
	// Already set.
	If DirectoryName <> Undefined
		AND Not IsBlankString(DirectoryName)
		AND ApplicationParameters["StandardSubsystems.AccessToWorkingDirectoryCheckExecuted"] Then
		
		Result = New Structure;
		Result.Insert("Directory", DirectoryName);
		Result.Insert("ErrorDescription", "");
		
		ExecuteNotifyProcessing(Notification, Result);
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("Directory", DirectoryName);
	
	FileFunctionsServiceClient.ReceiveUserDataWorkingDirectory(New NotifyDescription(
		"GetUserWorkingDirectoryAfterObtainingDataDirectorya", ThisObject, Context));
	
EndProcedure

// Continue procedure GetUserWorkingDirectory.
Procedure GetUserWorkingDirectoryAfterObtainingDataDirectorya(Result, Context) Export
	
	If ValueIsFilled(Result.ErrorDescription) Then
		ExecuteNotifyProcessing(Context.Notification, Result);
		Return;
	EndIf;
	
#If Not WebClient Then
	
	If Result.Directory <> Context.Directory Then
		// Create a file directory.
		Try
			CreateDirectory(Context.Directory);
			TestDirectoryName = Context.Directory + "CheckAccess\";
			CreateDirectory(TestDirectoryName);
			DeleteFiles(TestDirectoryName);
		Except
			// You are not authorized to create a directory
			// or this path does not exist, then default settings are set.
			Context.Directory = Undefined;
		EndTry;
	EndIf;
	
#EndIf
	
	ApplicationParameters["StandardSubsystems.AccessToWorkingDirectoryCheckExecuted"] = True;
	
	If Context.Directory = Undefined Then
		FileFunctionsServiceClient.SetUserWorkingDirectory(Result.Directory);
	Else
		Result.Directory = Context.Directory;
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure

#EndRegion
