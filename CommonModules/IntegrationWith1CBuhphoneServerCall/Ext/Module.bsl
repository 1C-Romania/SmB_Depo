////////////////////////////////////////////////////////////////////////////////
// Subsystem "Integration with 1C:Buhphone".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// It receives the path to the executable file from the data register.
// 		
// Parameters:
// 	ClientID	- UUID - ID of 1C client (software).
// 		
// ReturnValue:
// 		String   - Path to the executable file on the current user PC.
//
Function ExecutableFileLocation(ClientID) Export
	
	Return CommonSettingsStorage.Load("ExecuteFilesPaths1CBuhphone", ClientID);
	
EndFunction

// It receives parameters to start 1C-Buhphone application from the data register.
//
// Parameters:
// 	User  - UUID - Current infobase user.
//
// ReturnValue:
// 	Structure  - User settings to start 1C-Buhphone application.
//
Function UserAccountSettings() Export 
	
	SettingsUser = IntegrationWith1CBuhphone.SettingsUser();
	UserSettingsStorage = CommonSettingsStorage.Load("UserAccounts1CBuhphone", "CredentialsSettings");
	
	If Not UserSettingsStorage = Undefined Then
		SettingsUser.Login 					= UserSettingsStorage.Login;
		SettingsUser.Password 					= UserSettingsStorage.Password;
		SettingsUser.UseLP 			= UserSettingsStorage.UseLP;
		SettingsUser.ButtonVisibile1CBuhphone 	= UserSettingsStorage.ButtonVisibile1CBuhphone;	
	EndIf;
	
	Return SettingsUser;
	
EndFunction
	
#EndRegion